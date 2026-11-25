"""Reusable Blender pipeline for turning bought or scanned art into game-ready
Roblox meshes. Driven by tools/blender/scenes.json, so adding an asset is a config
entry rather than a code change.

    blender -b -noaudio --python tools/blender/scene_kit.py -- --list
    blender -b -noaudio --python tools/blender/scene_kit.py -- --asset glacier
    blender -b -noaudio --python tools/blender/scene_kit.py -- --all
    blender -b -noaudio --python tools/blender/scene_kit.py -- --asset glacier \
        --set exaggerate=4 --set fit.size=3600 --out /tmp/try.glb

One Blender unit is one stud (ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md section 3).
Operations run in this order, because each depends on the last:

    import -> cull -> exaggerate -> fit -> decimate -> tile -> pivot -> textures -> export
          -> optimize

`cull` runs first, on the source as it arrived, so its numbers are in source units and
stay valid however the asset is later scaled. It deletes junk that image-to-3D copies in
from the reference photo (floor cables, a mat, loose props); see op_cull.

`exaggerate` runs before `fit` so vertical stretch is expressed in source
proportions while `fit` still lands the final width exactly. `pivot` runs after
`tile` so every tile is shifted by the same offset and the whole set can be placed
with a single CFrame. `optimize` runs after `export`, on the written file, because
the simplifier it uses is a Node CLI (see tools/gltf_post.py) and because the
artifact that gets uploaded is the thing worth verifying.

Two ways to shed triangles, and they are not interchangeable. `decimate` is
Blender's Collapse modifier: it works on anything, including flat-shaded
hard-surface art, and it is rough with panels and thin structures. `optimize.tris`
is meshoptimizer: it holds a silhouette far better and is the right tool for a
dense generated mesh, but it will not collapse across split vertices, so on
flat-shaded art it stalls and says so. Reach for meshopt first and fall back.

Every run prints the numbers a map author actually needs -- final size in Roblox
axes, the Y range about the pivot, the worst tile -- and fails loudly if a mesh
would breach a Roblox limit, rather than leaving that to a failed import later.
"""

import argparse
import json
import math
import os
import shutil
import subprocess
import sys

import bpy
import mathutils

MESH_TRI_LIMIT = 10000  # Roblox rejects a mesh above this at import
MESH_STUD_LIMIT = 2048  # per-axis MeshPart cap
AXES = {"x": 0, "y": 1, "z": 2}
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


# --- scene helpers -------------------------------------------------------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit("unsupported source format: " + ext)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bounds(objs):
    mn = mathutils.Vector((1e30,) * 3)
    mx = mathutils.Vector((-1e30,) * 3)
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(corner)
            mn = mathutils.Vector([min(mn[i], w[i]) for i in range(3)])
            mx = mathutils.Vector([max(mx[i], w[i]) for i in range(3)])
    return mn, mx


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def select(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def apply_transform(ob):
    select([ob])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def join(objs, name):
    select(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


# --- operations ----------------------------------------------------------


def op_cull(ob, rules):
    """Delete faces by position, before anything is scaled. Source units, Blender Z up.

    Each rule is a dict of filters that must ALL match a face's centroid; the first rule
    that matches takes the face. Filters, all optional:

        below / above   z <  n  /  z >  n
        x, y, z         [lo, hi] inclusive range on that axis
        outside         {center: [cx, cy], radius: r}  further than r from the axis
        inside          {center: [cx, cy], radius: r}  within r of the axis
        name            only used in the report

    Positions are read off orthographic renders of the one file, which is why this is
    data in the manifest rather than a heuristic: no automatic measure told a cable
    tangle from an intended rubble pile (a floor-clutter metric was tried and flagged both
    walls and the helicopter while giving the junk-ridden tube 3%). Look at views.png,
    write the rule, check the result."""
    if not rules:
        return
    import bmesh
    import math

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()

    def hit(rule, c):
        if "below" in rule and not c.z < rule["below"]:
            return False
        if "above" in rule and not c.z > rule["above"]:
            return False
        for axis in "xyz":
            if axis in rule and not rule[axis][0] <= getattr(c, axis) <= rule[axis][1]:
                return False
        for key, want_outside in (("outside", True), ("inside", False)):
            if key in rule:
                cx, cy = rule[key]["center"]
                far = math.hypot(c.x - cx, c.y - cy) > rule[key]["radius"]
                if far != want_outside:
                    return False
        return True

    removed, counts = [], {}
    for f in bm.faces:
        c = f.calc_center_median()
        for i, rule in enumerate(rules):
            if hit(rule, c):
                removed.append(f)
                label = rule.get("name", "rule %d" % i)
                counts[label] = counts.get(label, 0) + 1
                break
    total = len(bm.faces)
    bmesh.ops.delete(bm, geom=removed, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    print("  cull     removed %s of %s faces: %s" % (format(len(removed), ","), format(total, ","), counts))


def op_orient(ob, up):
    """Rotate so the source's up axis becomes Blender Z, then bake it.

    Everything downstream assumes a Z-up scene: `export_yup` maps Blender Z to
    glTF Y, which is what Roblox reads as up. Skipping this step exports a file
    whose height is on glTF Z, and the asset then lies on its side in game -- which
    is exactly what happened to the glacier, whose OBJ source arrives Y-up."""
    if up == 2:
        return
    ob.rotation_euler = (math.radians(90), 0, 0) if up == 1 else (0, math.radians(-90), 0)
    select([ob])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def op_exaggerate(ob, factor, up):
    """Vertical stretch along the asset's own up axis. A terrain scan is often far
    flatter than it needs to be to read as relief from a distance; this is the
    honest lever for that. Applied in source proportions, before any fit."""
    if not factor or factor == 1:
        return
    scale = [1.0, 1.0, 1.0]
    scale[up] = factor
    ob.scale = tuple(scale)
    apply_transform(ob)


def op_fit(ob, axis, size):
    """Uniform scale so `axis` spans `size` studs."""
    index = {"x": 0, "y": 1, "z": 2}[axis]
    mn, mx = bounds([ob])
    span = (mx - mn)[index]
    if span <= 0:
        raise SystemExit("cannot fit a zero-width axis")
    factor = size / span
    ob.scale = (factor, factor, factor)
    apply_transform(ob)


def op_weld(ob):
    """Merge coincident vertices. Meshy delivers every triangle as its own three vertices; Collapse then
    shrinks each triangle on its own and the surface tears into shards (hand-cannon, 2026-11-22: 9.9%
    see-through). UVs live on the corners, so texture seams survive the merge."""
    mn, mx = bounds([ob])
    select([ob])
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5 * max(mx - mn))
    bpy.ops.object.mode_set(mode="OBJECT")


def op_repair_normals(ob):
    """Weld, then turn every face to point outward. Roblox draws one side only, so a patch
    Meshy wound inward shows as a see-through hole (halcyon-rifle, 2026-11-22). Opt-in with
    `repairNormals: true`; it cannot help a real hole or a one-sided sheet."""
    op_weld(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def op_yaw(ob, degrees):
    """Turn about the up axis, so a held or driven model's front lands on Blender +Y (Roblox -Z)."""
    if not degrees:
        return
    # On the mesh itself: glTF imports in quaternion mode, where setting rotation_euler does nothing.
    from mathutils import Matrix

    ob.data.transform(Matrix.Rotation(math.radians(degrees), 4, "Z"))
    ob.data.update()


def op_split(final, spec):
    """Move the faces inside a cylinder into their own mesh, origin on the cylinder's axis, so game code can
    spin it (the Hand Cannon's drum, 2026-11-22). spec: name, axis x|y|z, center [x, y, z] and radius and
    halfLength in studs, in the exported model's frame after `pivot`. Runs last, so tiles never cut it."""
    if not spec:
        return final
    if isinstance(spec, list):
        # Several splits in turn, e.g. one Neon mesh per glow colour (the Halcyon's strip).
        for one in spec:
            final = op_split(final, one)
        return final
    if "colour" in spec:
        return op_split_colour(final, spec)
    import bmesh
    from mathutils import Matrix, Vector

    body = final[0]
    axis = "xyz".index(spec.get("axis", "y"))
    centre = Vector(spec["center"])
    radius, half = spec["radius"], spec["halfLength"]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    picked = []
    for face in bm.faces:
        offset = face.calc_center_median() - centre
        along = offset[axis]
        across = sum(offset[i] ** 2 for i in range(3) if i != axis) ** 0.5
        face.select = abs(along) <= half and across <= radius
        if face.select:
            picked.append(face.index)
    bm.to_mesh(body.data)
    bm.free()
    if not picked:
        raise SystemExit("split %s: no faces inside the cylinder" % spec["name"])
    select([body])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    part = next(o for o in bpy.context.selected_objects if o is not body)
    part.name = part.data.name = spec["name"]
    # origin on the axis: the mesh moves by -centre, the object by +centre, so nothing moves in the world
    part.data.transform(Matrix.Translation(-centre))
    part.location = part.location + centre
    print("  split    %s: %s triangles, origin %s" % (spec["name"], format(tris([part]), ","),
                                                     [round(c, 3) for c in centre]))
    return final + [part]


def op_extra_parts(final, path):
    """Add hand-modelled pieces to a scanned asset: the parts a generator gets wrong and shapes get right,
    such as a round bore or a ring that must be its own mesh to glow (the Quantum Cannon's muzzle,
    2026-11-22). path is a Python file whose add(final) returns new mesh objects, built in the exported
    model's frame after `pivot`. Their triangles count toward the brief's budget like any other mesh."""
    if not path:
        return final
    import importlib.util

    module_spec = importlib.util.spec_from_file_location("extra_parts", resolve(path))
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    added = module.add(final)
    for ob in added:
        print("  extra    %s: %s triangles" % (ob.name, format(tris([ob]), ",")))
    return list(final) + list(added)


def op_split_colour(final, spec):
    """Move every face whose texture colour falls in a hue/saturation/value window into its own mesh,
    gathered from all tiles, so Studio can give that part its own material. The Prism Blaster's crystal
    is painted lavender by Meshy and only glows as a separate Neon MeshPart (2026-11-22).
    spec: name, colour {hue: [lo, hi] in degrees, sat: [lo, hi], val: [lo, hi]}, minFaces (default 50)."""
    import colorsys

    import bmesh

    window = spec["colour"]
    hue = window.get("hue", [0, 360])
    sat = window.get("sat", [0, 1])
    val = window.get("val", [0, 1])
    # Optional [[min x, y, z], [max x, y, z]] in the exported frame: the colour alone also took stray
    # lavender slivers on the Prism Blaster's bezel rim and grip.
    box = spec.get("box")

    def texture_of(ob):
        for slot in ob.material_slots:
            mat = slot.material
            if mat and mat.use_nodes:
                for node in mat.node_tree.nodes:
                    if node.type == "TEX_IMAGE" and node.image:
                        return node.image
        return None

    pieces = []
    for body in final:
        image = texture_of(body)
        if image is None:
            continue
        w, h = image.size
        px = list(image.pixels[:])  # byte images hold their sRGB values as stored, scaled to 0..1
        bm = bmesh.new()
        bm.from_mesh(body.data)
        uv = bm.loops.layers.uv.active
        count = 0
        for face in bm.faces:
            u = sum(l[uv].uv.x for l in face.loops) / len(face.loops)
            v = sum(l[uv].uv.y for l in face.loops) / len(face.loops)
            x = min(w - 1, max(0, int((u % 1.0) * w)))
            y = min(h - 1, max(0, int((v % 1.0) * h)))
            o = (y * w + x) * 4
            hh, ss, vv = colorsys.rgb_to_hsv(px[o], px[o + 1], px[o + 2])
            hh *= 360
            face.select = hue[0] <= hh <= hue[1] and sat[0] <= ss <= sat[1] and val[0] <= vv <= val[1]
            if face.select and box:
                c = face.calc_center_median()
                face.select = all(box[0][i] <= c[i] <= box[1][i] for i in range(3))
            count += face.select
        bm.to_mesh(body.data)
        bm.free()
        if not count:
            continue
        select([body])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        pieces += [o for o in bpy.context.selected_objects if o is not body]
    picked = tris(pieces) if pieces else 0
    if picked < spec.get("minFaces", 50):
        raise SystemExit("split %s: only %d faces in the colour window %s" % (spec["name"], picked, window))
    select(pieces)
    bpy.context.view_layer.objects.active = pieces[0]
    if len(pieces) > 1:
        bpy.ops.object.join()
    part = bpy.context.view_layer.objects.active
    part.name = part.data.name = spec["name"]
    print("  split    %s by colour: %s triangles" % (spec["name"], format(tris([part]), ",")))
    return final + [part]


def op_decimate(ob, target):
    """target is a triangle count, or {"tris": n, "weld": false}. Welding first joins the copies of
    each vertex that sit on a UV seam, so the collapse then pulls texture across seams; on the Prism
    Blaster that smeared the white shell with dark blotches (2026-11-22). weld false keeps seams."""
    weld = True
    if isinstance(target, dict):
        weld = target.get("weld", True)
        target = target.get("tris")
    current = tris([ob])
    if not target or current <= target:
        return
    if weld:
        op_weld(ob)
    modifier = ob.modifiers.new("dec", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = target / current
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def op_tile(ob, nx, ny, up):
    """Bisect into an nx*ny grid so each mesh clears the triangle cap. Bisect is
    exact, so neighbouring tiles stay watertight against each other. Cells that cut
    empty are dropped, since a source heightfield rarely fills its own square."""
    mn, mx = bounds([ob])
    # Cut the two axes that are NOT up, so tiles divide the ground plane.
    a, b = [i for i in range(3) if i != up]
    out = []
    for ix in range(nx):
        for iy in range(ny):
            part = ob.copy()
            part.data = ob.data.copy()
            part.name = "%s_%d%d" % (ob.name, ix, iy)
            bpy.context.scene.collection.objects.link(part)
            lo_a = mn[a] + (mx[a] - mn[a]) * ix / nx
            hi_a = mn[a] + (mx[a] - mn[a]) * (ix + 1) / nx
            lo_b = mn[b] + (mx[b] - mn[b]) * iy / ny
            hi_b = mn[b] + (mx[b] - mn[b]) * (iy + 1) / ny
            planes = []
            for axis, value, sign in ((a, lo_a, 1), (a, hi_a, -1), (b, lo_b, 1), (b, hi_b, -1)):
                co = [0.0, 0.0, 0.0]
                no = [0.0, 0.0, 0.0]
                co[axis] = value
                no[axis] = sign
                planes.append((tuple(co), tuple(no)))
            for co, no in planes:
                select([part])
                bpy.ops.object.mode_set(mode="EDIT")
                bpy.ops.mesh.select_all(action="SELECT")
                bpy.ops.mesh.bisect(plane_co=co, plane_no=no, clear_inner=True)
                bpy.ops.object.mode_set(mode="OBJECT")
            out.append(part)
    empty = [p for p in out if not p.data.polygons]
    kept = [p for p in out if p.data.polygons]
    select([ob] + empty)
    bpy.ops.object.delete()
    return kept


def op_pivot(objs, mode, up):
    """Move geometry so the chosen point sits at the origin. Every tile is shifted
    by the SAME offset, so a tiled set keeps its layout and places with one CFrame."""
    if mode == "origin":
        return mathutils.Vector((0, 0, 0))
    mn, mx = bounds(objs)
    centre = (mn + mx) / 2
    if mode == "center":
        offset = centre
    elif mode in ("bottom", "top"):
        # "bottom" sits the asset on the floor once placed.
        offset = mathutils.Vector(centre)
        offset[up] = mn[up] if mode == "bottom" else mx[up]
    else:
        raise SystemExit("unknown pivot mode: " + repr(mode))
    shift = mathutils.Matrix.Translation(-offset)
    for o in objs:
        o.data.transform(shift)
        o.location = (0, 0, 0)
        apply_transform(o)
    return offset


def keep_detail(ob, spec):
    """Copy the full-detail mesh before `decimate`, for `bakeNormals` to read from later."""
    if not spec:
        return None
    hi = ob.copy()
    hi.data = ob.data.copy()
    hi.name = ob.name + "_detail"
    bpy.context.scene.collection.objects.link(hi)
    return hi


def op_bake_normals(final, hi, spec):
    """Bake the full-detail mesh's surface into a tangent-space normal map on the decimated one, so
    panel edges and bevels the triangle budget cannot keep still catch the light. The map shares the
    scan's UV atlas and is wired into its material, which glTF exports as normalTexture and the
    Roblox importer turns into a SurfaceAppearance (the Plasma Blaster, 2026-11-23).
    spec: true or {size: 1024, extrusion: 0.015, distance: 0.04} (studs). Hand-made extra parts keep
    their own materials and are skipped; any piece sharing the scan's material gets baked."""
    if not spec or hi is None:
        return
    spec = spec if isinstance(spec, dict) else {}
    size = int(spec.get("size", 1024))
    scan_mats = {s.material.name for s in final[0].material_slots if s.material}  # the scan body is first
    targets = []
    for ob in final:
        mats = [s.material for s in ob.material_slots if s.material and s.material.name in scan_mats]
        if mats and mats[0].use_nodes:
            targets.append((ob, mats[0]))
    if not targets:
        raise SystemExit("bakeNormals: no textured mesh to bake onto")
    image = bpy.data.images.new("baked_normal", size, size, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    image.generated_color = (0.5, 0.5, 1.0, 1.0)
    wired = set()
    for _, mat in targets:
        if mat.name in wired:
            continue
        wired.add(mat.name)
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.name = "baked_normal"
        nmap = nodes.new("ShaderNodeNormalMap")
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        links.new(tex.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = float(spec.get("extrusion", 0.015))
    bake.max_ray_distance = float(spec.get("distance", 0.04))
    bake.normal_space = "TANGENT"
    bake.margin = 4
    bake.use_clear = False
    for ob, mat in targets:
        for node in mat.node_tree.nodes:
            node.select = False
        mat.node_tree.nodes.active = mat.node_tree.nodes["baked_normal"]
        bpy.ops.object.select_all(action="DESELECT")
        hi.select_set(True)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type="NORMAL")
        print("  bake     normals onto %s (%dx%d)" % (ob.name, size, size))
    image.pack()
    bpy.data.objects.remove(hi, do_unlink=True)


def op_textures(tex_dir):
    """Point every image at the downscaled copy of the same name, so the export
    embeds the 1024 texture Roblox would downscale to anyway. Pair with
    tools/blender/resize_textures.py, which produces that directory."""
    if not tex_dir:
        return
    for img in bpy.data.images:
        if not img.filepath:
            continue
        candidate = os.path.join(tex_dir, os.path.basename(img.filepath))
        if os.path.exists(candidate):
            img.filepath = candidate
            img.source = "FILE"
            img.reload()


def check(objs, defer_tris=False):
    """Fail before export on anything Roblox would reject at import.

    `defer_tris` is set when the manifest has an `optimize` block: meshoptimizer
    runs on the exported file and is expected to bring the count down, so an
    over-cap mesh here is a note rather than a verdict. The stud span is never
    deferred, because no amount of simplification changes how big a thing is."""
    problems = []
    pending = []
    for o in objs:
        count = tris([o])
        if count > MESH_TRI_LIMIT:
            message = "%s: %s triangles > %s" % (o.name, format(count, ","), format(MESH_TRI_LIMIT, ","))
            (pending if defer_tris else problems).append(message)
        mn, mx = bounds([o])
        for i, axis in enumerate("xyz"):
            span = (mx - mn)[i]
            if span > MESH_STUD_LIMIT:
                problems.append("%s: %s span %.0f > %d studs" % (o.name, axis, span, MESH_STUD_LIMIT))
    for note in pending:
        print("  over cap, optimize will reduce: " + note)
    if problems:
        for problem in problems:
            print("  FAIL " + problem)
        raise SystemExit(1)


def op_optimize(path, spec, tiled):
    """Hand the exported GLB to tools/gltf_post.py, as a SEPARATE process.

    Not an import: Blender ships its own Python, and that interpreter has no
    Pillow, so a tint would die on `from PIL import Image` after the mesh work
    had already succeeded. Shelling out to the system interpreter also means the
    pipeline does not care which Python Blender was built against.

    This runs after export, on the written file, because the simplifier is a Node
    CLI and because verifying the finished artifact is worth more than verifying
    the scene that produced it -- the file is what gets uploaded. Bisected tiles
    get their borders locked so neighbouring tiles stay watertight; a seam that
    tears is invisible here and obvious in game.
    """
    interpreter = shutil.which("python") or shutil.which("python3")
    if not interpreter:
        raise SystemExit("no system python on PATH for tools/gltf_post.py")
    command = [interpreter, os.path.join(ROOT, "tools", "gltf_post.py"), "optimize", path, path]
    if spec.get("tris"):
        command += ["--tris", str(spec["tris"])]
    if spec.get("texture"):
        command += ["--texture", str(spec["texture"])]
    if spec.get("error"):
        command += ["--error", str(spec["error"])]
    if spec.get("lockBorder", tiled):
        command.append("--lock-border")
    if spec.get("tint"):
        command += ["--tint", ",".join(str(v) for v in spec["tint"])]
    if spec.get("lift"):
        command += ["--lift", str(spec["lift"])]
    if spec.get("gamma"):
        command += ["--gamma", str(spec["gamma"])]
    sys.stdout.flush()  # or Blender's buffered output lands after the child's
    if subprocess.call(command) != 0:
        raise SystemExit("gltf_post failed; the exported file is left as-is")


def export(out):
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
    )


# --- driver --------------------------------------------------------------


def resolve(path):
    return path if os.path.isabs(path) else os.path.join(ROOT, path)


def apply_overrides(spec, overrides):
    for item in overrides:
        key, _, raw = item.partition("=")
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            value = raw
        target = spec
        parts = key.split(".")
        for part in parts[:-1]:
            target = target.setdefault(part, {})
        target[parts[-1]] = value
    return spec


def build(name, spec, out_override=None):
    print("[" + name + "]")
    reset()
    objs = load(resolve(spec["source"]))
    mn, mx = bounds(objs)
    print("  source   tris=%s size=%s" % (format(tris(objs), ","), [round((mx - mn)[i], 2) for i in range(3)]))

    up = AXES[spec.get("up", "z")]
    ob = join(objs, spec.get("name", name.title()))
    # Importers leave an axis-conversion rotation on the object, so its local axes
    # are not the world axes. Bake that in before anything indexes an axis,
    # otherwise a local-Y scale silently lands on world Z.
    apply_transform(ob)
    # From here on the scene is Z-up regardless of how the source arrived, so every
    # axis-indexed operation below can assume it.
    op_orient(ob, up)
    up = 2
    op_yaw(ob, spec.get("yaw"))
    if spec.get("repairNormals"):
        op_repair_normals(ob)
    op_cull(ob, spec.get("cull"))
    op_exaggerate(ob, spec.get("exaggerate"), up)
    fit = spec.get("fit")
    if fit:
        op_fit(ob, fit.get("axis", "x"), fit["size"])
    hi = keep_detail(ob, spec.get("bakeNormals"))
    op_decimate(ob, spec.get("decimate"))

    tile = spec.get("tile")
    final = op_tile(ob, tile[0], tile[1], up) if tile else [ob]
    offset = op_pivot(final, spec.get("pivot", "center"), up)
    if hi is not None:
        hi.data.transform(mathutils.Matrix.Translation(-offset))
    final = op_split(final, spec.get("split"))
    final = op_extra_parts(final, spec.get("extraParts"))
    op_bake_normals(final, hi, spec.get("bakeNormals"))
    op_textures(resolve(spec["textures"]) if spec.get("textures") else None)

    mn, mx = bounds(final)
    # Report in Roblox axes, because that is what the map data will talk about:
    # Blender (x, y, z) exports to Roblox (x, z, -y).
    ground = [i for i in range(3) if i != up]
    span = mx - mn
    print("  result   meshes=%d tris=%s" % (len(final), format(tris(final), ",")))
    print("           roblox size  wide=%.1f  deep=%.1f  tall=%.1f studs"
          % (span[ground[0]], span[ground[1]], span[up]))
    print("           height span %.1f .. %.1f about the pivot" % (mn[up], mx[up]))
    print("           relief ratio %.3f (under ~0.2 reads flat from a distance)"
          % (span[up] / max(span[ground[0]], 1e-9)))
    if len(final) > 1:
        worst = max(final, key=lambda o: tris([o]))
        print("           largest tile %s at %s tris" % (worst.name, format(tris([worst]), ",")))
    optimize = spec.get("optimize")
    check(final, defer_tris=bool(optimize and optimize.get("tris")))

    out = resolve(out_override or spec["out"])
    export(out)
    print("  wrote    %s (%.2f MB)" % (out, os.path.getsize(out) / 1e6))
    if optimize:
        op_optimize(out, optimize, tiled=bool(tile))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="scene_kit")
    parser.add_argument("--manifest", default=os.path.join(os.path.dirname(__file__), "scenes.json"))
    parser.add_argument("--asset")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--out", help="override the output path, for trying a variant")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                        help="override a manifest field, e.g. --set exaggerate=4 --set fit.size=3600")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args(argv)

    with open(args.manifest, encoding="utf-8") as handle:
        manifest = json.load(handle)["assets"]

    if args.list or not (args.asset or args.all):
        for name, spec in manifest.items():
            print("%-12s %s" % (name, spec.get("description", "")))
        return

    names = list(manifest) if args.all else [args.asset]
    for name in names:
        if name not in manifest:
            raise SystemExit("no asset %r in manifest; --list to see them" % name)
        build(name, apply_overrides(dict(manifest[name]), args.set), args.out if not args.all else None)


main()
