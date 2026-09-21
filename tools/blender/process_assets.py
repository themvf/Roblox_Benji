# Blender 4.3 asset processing for ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md.
# One Blender unit == one stud (spec section 3). Run headless, once per asset:
#   blender -b -noaudio --python tools/blender/process_assets.py -- <asset> <src> <out.glb>
# Every asset leaves here with evaluated transforms, a deliberate pivot and +Y up.
import bpy, sys, os, math, mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
asset, src, out = argv[0], argv[1], argv[2]
tex_dir = argv[3] if len(argv) > 3 else None


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.wm.obj_import(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def repoint_textures(tex_dir):
    """Swap every image for the downscaled copy of the same name, so the GLB embeds
    the 1024 texture Roblox would downscale to anyway instead of the 4K original."""
    if not tex_dir:
        return
    for img in bpy.data.images:
        if not img.filepath:
            continue
        cand = os.path.join(tex_dir, os.path.basename(img.filepath))
        if os.path.exists(cand):
            img.filepath = cand
            img.source = "FILE"
            img.reload()
            print(f"  texture -> {os.path.basename(cand)}")


def bounds(objs):
    mn = mathutils.Vector((1e30,) * 3)
    mx = mathutils.Vector((-1e30,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(c)
            mn = mathutils.Vector([min(mn[i], w[i]) for i in range(3)])
            mx = mathutils.Vector([max(mx[i], w[i]) for i in range(3)])
    return mn, mx


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


def apply_all(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def fit_and_pivot(ob, axis, target, pivot_z):
    """Uniformly scale so `axis` spans `target` studs, then place the pivot.
    pivot_z: "center" or "min" (min sits the asset on y=0 once Roblox flips to Y-up)."""
    mn, mx = bounds([ob])
    span = (mx - mn)[axis]
    s = target / span
    ob.scale = (s, s, s)
    apply_all(ob)
    mn, mx = bounds([ob])
    ctr = (mn + mx) / 2
    z = ctr.z if pivot_z == "center" else mn.z
    offset = mathutils.Vector((ctr.x, ctr.y, z))
    ob.data.transform(mathutils.Matrix.Translation(-offset))
    ob.location = (0, 0, 0)
    apply_all(ob)


def decimate(ob, target_tris):
    cur = tris([ob])
    if cur <= target_tris:
        return
    m = ob.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = target_tris / cur
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)


def tile(ob, nx, ny):
    """Bisect into an nx*ny grid so every MeshPart clears Roblox's 10k-triangle
    ceiling. Bisect is exact, so the tiles stay watertight against each other."""
    mn, mx = bounds([ob])
    out = []
    for ix in range(nx):
        for iy in range(ny):
            part = ob.copy()
            part.data = ob.data.copy()
            part.name = f"{ob.name}_{ix}{iy}"
            bpy.context.scene.collection.objects.link(part)
            x0 = mn.x + (mx.x - mn.x) * ix / nx
            x1 = mn.x + (mx.x - mn.x) * (ix + 1) / nx
            y0 = mn.y + (mx.y - mn.y) * iy / ny
            y1 = mn.y + (mx.y - mn.y) * (iy + 1) / ny
            for co, no in (((x0, 0, 0), (1, 0, 0)), ((x1, 0, 0), (-1, 0, 0)),
                           ((0, y0, 0), (0, 1, 0)), ((0, y1, 0), (0, -1, 0))):
                bpy.ops.object.select_all(action="DESELECT")
                part.select_set(True)
                bpy.context.view_layer.objects.active = part
                bpy.ops.object.mode_set(mode="EDIT")
                bpy.ops.mesh.select_all(action="SELECT")
                bpy.ops.mesh.bisect(plane_co=co, plane_no=no, clear_inner=True)
                bpy.ops.object.mode_set(mode="OBJECT")
            out.append(part)
    # The source heightfield does not fill its square, so some cells cut empty.
    empty = [p for p in out if not p.data.polygons]
    out = [p for p in out if p.data.polygons]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    for p in empty:
        p.select_set(True)
    bpy.ops.object.delete()
    return out


MESH_TRI_LIMIT = 10000


def check_limits(objs):
    """Roblox rejects a mesh over 10k triangles at import, so fail here instead."""
    over = [(o.name, tris([o])) for o in objs if tris([o]) > MESH_TRI_LIMIT]
    for name, n in over:
        print(f"  FAIL {name}: {n:,} triangles > {MESH_TRI_LIMIT:,}")
    if over:
        raise SystemExit(1)
    for o in sorted(objs, key=lambda o: o.name):
        print(f"    {o.name}: {tris([o]):,} tris")


def report(tag, objs):
    mn, mx = bounds(objs)
    print(f"  {tag}: objs={len(objs)} tris={tris(objs):,} "
          f"size={[round((mx - mn)[i], 3) for i in range(3)]} "
          f"min={[round(v, 3) for v in mn]} max={[round(v, 3) for v in mx]}")


def export(out):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_materials="EXPORT",
    )


reset()
objs = load(src)
print(f"[{asset}] imported")
report("source", objs)

if asset == "jetpack":
    # X is the wingspan, Z up, Y depth -- already the axes a back mount wants.
    # 4 studs of wingspan reads large without swallowing an R15 torso.
    ob = join(objs, "JetpackPack")
    fit_and_pivot(ob, 0, 4.0, "center")
    final = [ob]
elif asset == "jumppad":
    # Square pad; 8 studs matches the default `size` in layout LaunchPads data.
    # Pivot at the underside so the mesh sits on the floor, not half sunk in it.
    ob = join(objs, "JumpPad")
    fit_and_pivot(ob, 0, 8.0, "min")
    final = [ob]
elif asset == "glacier":
    # Scenic backdrop only. Playable bounds are +/-245 x, +/-185 z, so 2400 studs
    # of ridge line sits well outside them. Four tiles keep each MeshPart under
    # the 10k-triangle ceiling; the source is 712,818 triangles.
    ob = join(objs, "Glacier")
    decimate(ob, 32000)
    fit_and_pivot(ob, 0, 2400.0, "center")
    final = tile(ob, 4, 4)
else:
    raise SystemExit(f"unknown asset {asset}")

repoint_textures(tex_dir)
report("processed", final)
check_limits(final)
os.makedirs(os.path.dirname(out), exist_ok=True)
export(out)
print(f"[{asset}] wrote {out} ({os.path.getsize(out) / 1e6:.2f} MB)")
