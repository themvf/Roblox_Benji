"""Post-export conditioning for game-ready glTF, wrapping the glTF-Transform CLI.

Blender is good at authoring and weak at the last mile. Its Decimate modifier
collapses flat panels and thin structures, which is most of what a hard-surface
asset is made of -- a vehicle, a wreck, a machine. meshoptimizer's simplifier
holds the silhouette far better for the same triangle budget, and glTF-Transform
exposes it as a CLI over the .glb scene_kit already writes.

    python tools/gltf_post.py inspect assets/models/jumppad/JumpPad.glb
    python tools/gltf_post.py optimize in.glb out.glb --tris 9000 --texture 1024

The audit reads the GLB container with the standard library, no third-party
Python and no npx round-trip, so it works on any file -- including one an
image-to-3D generator produced that never went through Blender at all.

Requires Node (npx). The CLI version is pinned for the same reason rokit.toml
pins every other tool: a silent upgrade that changes mesh output is a bug nobody
would think to look for.
"""

import argparse
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile

CLI_VERSION = "4.5.0"
MESH_TRI_LIMIT = 10000  # Roblox rejects a mesh above this at import
TEXTURE_LIMIT = 1024  # Roblox downscales anything larger anyway

# meshoptimizer quits before the target ratio when it would exceed --error, so a
# single pass at a tight bound often lands above the cap. Escalate deliberately
# and say which rung worked, rather than opening with a loose bound that throws
# away detail the mesh could have kept.
ERROR_LADDER = (0.01, 0.03, 0.08, 0.15)

# --ratio is a share of VERTICES; the triangle count that falls out of it is
# close but never exact. Landing a hair over the target is the ratio being
# approximate, not the simplifier giving up, so allow a little slack before
# escalating. The cap, checked against the finished file, is the real bar.
RATIO_TOLERANCE = 1.02

GLB_MAGIC = b"glTF"
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942

# What Roblox's importer will read. Anything else has to be converted, and the
# conversion is not optional: a generator that writes WebP puts EXT_texture_webp
# in extensionsRequired, and a loader without that extension must refuse the whole
# file rather than just dropping the texture.
NATIVE_MIMES = ("image/png", "image/jpeg")
FOREIGN_TEXTURE_EXTENSIONS = {"EXT_texture_webp", "EXT_texture_avif", "KHR_texture_basisu"}


# --- reading -------------------------------------------------------------


def read_glb(path):
    """Return (glTF JSON, binary chunk). The chunk is None for a .gltf."""
    with open(path, "rb") as handle:
        if handle.read(4) != GLB_MAGIC:
            handle.seek(0)
            return json.loads(handle.read().decode("utf-8")), None
        handle.seek(12)  # magic, version, total length
        doc = blob = None
        while True:
            header = handle.read(8)
            if len(header) < 8:
                break
            length, kind = struct.unpack("<II", header)
            payload = handle.read(length)
            if kind == CHUNK_JSON:
                doc = json.loads(payload.decode("utf-8"))
            elif kind == CHUNK_BIN:
                blob = payload
        if doc is None:
            raise SystemExit("%s: GLB has no JSON chunk" % path)
        return doc, blob


def read_doc(path):
    return read_glb(path)[0]


def image_size(data):
    """(width, height) from a PNG, JPEG or WebP header, or None if unreadable."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    if data[:2] == b"\xff\xd8":  # JPEG: walk segments to a start-of-frame marker
        i = 2
        while i + 9 < len(data):
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
                height, width = struct.unpack(">HH", data[i + 5:i + 9])
                return width, height
            i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
        return None
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        kind = data[12:16]
        if kind == b"VP8X":
            return (int.from_bytes(data[24:27], "little") + 1,
                    int.from_bytes(data[27:30], "little") + 1)
        if kind == b"VP8 ":
            width, height = struct.unpack("<HH", data[26:30])
            return width & 0x3FFF, height & 0x3FFF
        if kind == b"VP8L":
            bits = int.from_bytes(data[21:25], "little")
            return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    return None


def texture_info(doc, blob):
    """[(mimeType, (width, height) or None)] for every embedded image."""
    views = doc.get("bufferViews", [])
    out = []
    for image in doc.get("images", []):
        size = None
        if blob is not None and "bufferView" in image:
            view = views[image["bufferView"]]
            start = view.get("byteOffset", 0)
            size = image_size(blob[start:start + view["byteLength"]])
        out.append((image.get("mimeType", "?"), size))
    return out


def foreign_textures(doc):
    """True when a texture is in a format Roblox's importer will not read."""
    if set(doc.get("extensionsRequired", [])) & FOREIGN_TEXTURE_EXTENSIONS:
        return True
    return any(i.get("mimeType") not in NATIVE_MIMES for i in doc.get("images", []))


# --- writing -------------------------------------------------------------


def write_glb(path, doc, blob):
    """Write a .glb. Both chunks pad to a 4-byte boundary, as the spec requires."""
    body = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    body += b" " * (-len(body) % 4)
    blob = (blob or b"")
    blob += b"\x00" * (-len(blob) % 4)
    total = 12 + 8 + len(body) + (8 + len(blob) if blob else 0)
    with open(path, "wb") as handle:
        handle.write(GLB_MAGIC + struct.pack("<II", 2, total))
        handle.write(struct.pack("<II", len(body), CHUNK_JSON))
        handle.write(body)
        if blob:
            handle.write(struct.pack("<II", len(blob), CHUNK_BIN))
            handle.write(blob)


def base_color_image(doc):
    """Index of the image behind the first material's base colour, or None."""
    for material in doc.get("materials", []):
        slot = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if not slot:
            continue
        texture = doc["textures"][slot["index"]]
        if "source" in texture:
            return texture["source"]
        for payload in texture.get("extensions", {}).values():
            if "source" in payload:
                return payload["source"]
    return None


def tint_base_color(src, dst, tint, lift=0.0):
    """Multiply the base-colour texture by `tint` and write a new .glb.

    A multiply rather than a replace, because every panel line, streak and soot
    mark already in the atlas is detail worth keeping -- the wreck should end up
    weathered, not repainted. `lift` keeps the darkest areas off flat black.

    The new image is APPENDED to the binary chunk with a fresh bufferView
    pointing at it. Rewriting the image in place would change its length and
    shift every offset after it; appending leaves the rest of the file untouched
    at the cost of some dead bytes.
    """
    from PIL import Image  # only this path needs it, so do not import at module load

    doc, blob = read_glb(src)
    index = base_color_image(doc)
    if index is None:
        raise SystemExit("%s: no base colour texture to tint" % src)

    image = doc["images"][index]
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    original = blob[start:start + view["byteLength"]]

    picture = Image.open(io.BytesIO(original)).convert("RGB")
    bands = []
    for channel, factor in zip(picture.split(), tint):
        bands.append(channel.point(lambda v, f=factor: max(0, min(255, int(v * f + lift * 255)))))
    buffer = io.BytesIO()
    Image.merge("RGB", bands).save(buffer, format="PNG", optimize=True)
    encoded = buffer.getvalue()

    blob = blob + b"\x00" * (-len(blob) % 4)
    doc["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(encoded)})
    image["bufferView"] = len(doc["bufferViews"]) - 1
    image["mimeType"] = "image/png"
    blob += encoded
    doc["buffers"][0]["byteLength"] = len(blob) + (-len(blob) % 4)

    write_glb(dst, doc, blob)
    print("           base colour tinted by %s (lift %.2f), %s -> %s"
          % (", ".join("%.2f" % v for v in tint), lift,
             format(len(original), ","), format(len(encoded), ",")))


def mesh_triangles(doc):
    """[(name, triangles)] per glTF mesh.

    Roblox's 10k cap is per MeshPart and its importer makes one MeshPart per
    mesh, so per-mesh is the number that decides whether an import succeeds.
    A total under the cap with one fat mesh over it still fails."""
    accessors = doc.get("accessors", [])
    out = []
    for index, mesh in enumerate(doc.get("meshes", [])):
        total = 0
        for prim in mesh.get("primitives", []):
            if prim.get("mode", 4) != 4:  # 4 = TRIANGLES, and the glTF default
                continue
            if "indices" in prim:
                count = accessors[prim["indices"]]["count"]
            else:
                count = accessors[prim["attributes"]["POSITION"]]["count"]
            total += count // 3
        out.append((mesh.get("name") or "mesh%d" % index, total))
    return out


def report(path, label="file"):
    """Print the per-mesh triangle table and the textures, return the worst count."""
    doc, blob = read_glb(path)
    counts = mesh_triangles(doc)
    worst = max((n for _, n in counts), default=0)
    print("  %-8s %s (%.2f MB)" % (label, os.path.basename(path), os.path.getsize(path) / 1e6))
    for name, count in counts:
        flag = "  OVER CAP" if count > MESH_TRI_LIMIT else ""
        print("           %-28s %9s tris%s" % (name, format(count, ","), flag))
    if len(counts) > 1:
        print("           %-28s %9s tris (%d meshes)"
              % ("total", format(sum(n for _, n in counts), ","), len(counts)))
    for mime, size in texture_info(doc, blob):
        shape = "%dx%d" % size if size else "size unknown"
        native = "" if mime in NATIVE_MIMES else "  NOT READABLE BY ROBLOX"
        over = "  OVER %d" % TEXTURE_LIMIT if size and max(size) > TEXTURE_LIMIT else ""
        print("           %-28s %9s  %s%s%s" % ("texture", shape, mime, native, over))
    return worst


# --- the CLI -------------------------------------------------------------


def cli(*args):
    npx = shutil.which("npx")
    if not npx:
        raise SystemExit(
            "npx not found. glTF-Transform is a Node CLI; install Node 18+ "
            "and re-run, or drop the optimize block from the manifest entry."
        )
    command = [npx, "--yes", "@gltf-transform/cli@" + CLI_VERSION] + [str(a) for a in args]
    done = subprocess.run(command, capture_output=True, text=True)
    if done.returncode != 0:
        sys.stdout.write(done.stdout or "")
        sys.stderr.write(done.stderr or "")
        raise SystemExit("gltf-transform %s failed" % args[0])
    return done.stdout


# --- the pipeline --------------------------------------------------------


def optimize(src, dst, tris=None, texture=None, error=None, lock_border=False,
             tint=None, lift=0.0):
    """weld -> simplify -> resize, then verify what actually landed.

    Welding first is not optional: the simplifier is limited by split vertices,
    so an unwelded mesh stalls well above its target and looks like the ratio was
    ignored. Border locking keeps a bisected tile watertight against its
    neighbours, which matters because a seam that tears is invisible in Blender
    and obvious in game."""
    worst = report(src, "source")
    with tempfile.TemporaryDirectory() as work:
        current = welded = os.path.join(work, "welded.glb")
        cli("weld", src, current)

        # Do this before anything else touches textures. glTF-Transform's own
        # `resize` handles PNG and JPEG only, so on a WebP file it is a silent
        # no-op -- the run reports success and the texture is untouched. An
        # image-to-3D generator writing WebP is the common case, not the odd one.
        if foreign_textures(read_doc(current)):
            out = os.path.join(work, "native.glb")
            # --formats defaults to "png", which means "re-compress textures that
            # are ALREADY png" and quietly does nothing to a WebP one. "*" is what
            # makes this a conversion rather than a no-op.
            cli("png", current, out, "--formats", "*")
            print("           textures -> PNG (the source format is one Roblox cannot read)")
            current = welded = out

        if tris and worst > tris:
            # One global vertex ratio is applied to every mesh, so aim it at the
            # worst mesh; anything smaller lands further under the cap, which is
            # harmless. Triangles track vertices closely enough on a welded mesh.
            ratio = round(tris / worst, 4)
            ladder = [error] if error else list(ERROR_LADDER)
            allowed = int(tris * RATIO_TOLERANCE)
            previous = None
            for attempt, bound in enumerate(ladder, 1):
                out = os.path.join(work, "simplified%d.glb" % attempt)
                # Always simplify the welded source, never the previous attempt.
                # Re-simplifying an already simplified mesh applies the ratio a
                # second time and throws away the detail the looser error bound
                # was raised to keep.
                args = ["simplify", welded, out, "--ratio", ratio, "--error", bound]
                if lock_border:
                    args += ["--lock-border", "true"]
                cli(*args)
                landed = max((n for _, n in mesh_triangles(read_doc(out))), default=0)
                print("           simplify ratio=%.4f error=%-5s -> %s tris"
                      % (ratio, bound, format(landed, ",")))
                current = out
                if landed <= allowed:
                    break
                if previous is not None and landed >= previous:
                    # A looser bound changed nothing, so the error bound was never
                    # what limited this mesh: its vertices are split by flat
                    # shading or UV seams, weld merges only bitwise-identical
                    # ones, and the simplifier will not collapse across the seam.
                    print("           stalled at %s tris; a looser error bound does not move it."
                          % format(landed, ","))
                    print("           Split vertices (flat shading or UV seams) are the limit,"
                          " not the bound.")
                    print("           Use Blender `decimate` for this mesh, or `tile` it.")
                    break
                previous = landed
            else:
                print("           WARNING: %s tris still over the %s target at error=%s."
                      % (format(landed, ","), format(tris, ","), ladder[-1]))
                print("           Decimate in Blender first, or split it with `tile`.")

        if texture:
            out = os.path.join(work, "resized.glb")
            cli("resize", current, out, "--width", texture, "--height", texture)
            current = out

        # Last, so the tint runs over the fewest pixels and lands on the PNG that
        # actually ships rather than one a later step would re-encode.
        if tint:
            out = os.path.join(work, "tinted.glb")
            tint_base_color(current, out, tint, lift)
            # The tint appends its new image and orphans the old one, so the file
            # carries both until something drops the unreferenced bufferView.
            # Measured on the helicopter: 6.00 MB -> 3.61 MB.
            pruned = os.path.join(work, "pruned.glb")
            cli("prune", out, pruned)
            current = pruned

        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True)
        shutil.copyfile(current, dst)

    final = report(dst, "result")
    if final > MESH_TRI_LIMIT:
        raise SystemExit(
            "  FAIL %s tris in one mesh > %s; Roblox will reject this import"
            % (format(final, ","), format(MESH_TRI_LIMIT, ","))
        )
    return final


def main():
    parser = argparse.ArgumentParser(prog="gltf_post")
    sub = parser.add_subparsers(dest="command", required=True)

    look = sub.add_parser("inspect", help="print per-mesh triangle counts")
    look.add_argument("file")

    run = sub.add_parser("optimize", help="weld, simplify and resize a .glb")
    run.add_argument("src")
    run.add_argument("dst")
    run.add_argument("--tris", type=int, default=MESH_TRI_LIMIT - 1000,
                     help="per-mesh triangle target (default: %(default)s)")
    run.add_argument("--texture", type=int, default=None,
                     help="clamp embedded textures to this many pixels, e.g. %d" % TEXTURE_LIMIT)
    run.add_argument("--error", type=float, default=None,
                     help="fix the simplifier error bound instead of escalating it")
    run.add_argument("--lock-border", action="store_true",
                     help="keep mesh borders intact; use for bisected tiles")
    run.add_argument("--tint", type=lambda t: [float(v) for v in t.split(",")],
                     help="multiply the base colour by R,G,B, e.g. 0.42,0.40,0.38")
    run.add_argument("--lift", type=float, default=0.0,
                     help="add this much back so the darkest areas do not crush to black")
    args = parser.parse_args()

    if args.command == "inspect":
        worst = report(args.file, "file")
        raise SystemExit(1 if worst > MESH_TRI_LIMIT else 0)
    optimize(args.src, args.dst, tris=args.tris, texture=args.texture,
             error=args.error, lock_border=args.lock_border,
             tint=args.tint, lift=args.lift)


if __name__ == "__main__":
    main()
