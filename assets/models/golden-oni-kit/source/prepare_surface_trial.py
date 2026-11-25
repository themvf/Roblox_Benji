"""Prepare a whole-body kit model for Roblox Studio's Avatar Setup, fitted to the match body.

    blender -b -noaudio --python tools/blender/prepare_avatar_setup.py -- <spec.json>

Run by `python tools/kit_look.py skinned <Kit>`. The match body (docs/design/kits/MATCH_BODY.md)
is one skeleton for every kit: ankle 0.3, knee 1.5, hip 2.7, waist 3.1, neck 4.7 studs. Avatar
Setup wants (create.roblox.com/docs/avatar-setup/auto-setup-requirements): an upright A- or
T-pose with no limb hiding another from the front, the front facing -Z, a contiguous,
watertight body, and no hair or accessories in it.

A Tripo model is none of that: the Bouncer arrived as 25 overlapping shells (hair, visor,
headset, collar, head, torso, each leg and glove). So:

1. Shells that start above the neck, other than the head, come off as rigid accessories
   (hair; shades and headset), keeping their own texture.
2. Every vertex is fitted to the match body: heights mapped piecewise onto its joint heights,
   arms swung out to an A-pose about the shoulder (blended in, so the armpit stretches rather
   than tears) and carried at the model's own scale.
3. The body shells are fused into one watertight shell (voxel remesh), reduced, unwrapped and
   the original paint baked onto it.
4. Turned to face -Z in glTF/Roblox terms, written as GLB, with a front/side preview. The FBX is
   written from the GLBs by write_fbx.py, which checks its size and front.

spec.json: source, out, turn (-90 for Tripo), marks (as split_whole_body.py: neck, waist, hip,
knee, ankle, shoulder, elbow, wrist, armRadius, armInner, legOuter, handLength, remove),
swing (degrees, 20), voxel (model units, 0.004), faces (target triangles, 12000),
texture (1024), hairMinFaces (the largest above-neck shell counts as hair above this),
minAccessoryFaces (300: smaller above-neck shells are dropped as debris), cage (bake, in voxels),
accessoryFaces (4000), cleanHairFlecks (true), headgearIsHair (false: what is left above the neck joins
the hair, for a character with no headgear). Marks may add hairCut (everything above it is hair)
and paint ([{x, y, z, color}] boxes repainted flat before the bake; color "hair" takes the hair's median).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

spec = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
OUT = Path(spec["out"])
OUT.mkdir(parents=True, exist_ok=True)
m = spec["marks"]
report = {}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=spec["source"])
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    world = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = world
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
source = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
source.data.transform(Matrix.Rotation(math.radians(spec.get("turn", -90)), 4, "Z"))
xs, ys, zs = ([v.co[i] for v in source.data.vertices] for i in range(3))
source.data.transform(Matrix.Translation(Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs)))))

# ---------------------------------------------------------------- 1. shells
bm = bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
for box in m.get("remove", []):  # the Bouncer's zip fin
    doomed = [f for f in bm.faces if all(box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1]
                                        for k in ("x", "y", "z") if k in box)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.faces.ensure_lookup_table()
bm.faces.index_update()
shells, seen = [], set()  # face indices: holding BMFace objects across the walk was unreliable
for f in bm.faces:
    if f.index in seen:
        continue
    stack, shell = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        shell.append(g.index)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    shells.append(shell)
layer = bm.faces.layers.int.new("group")  # 0 body, 1 hair, 2 headgear
faces = bm.faces
above = [s for s in shells if min(v.co.z for i in s for v in faces[i].verts) >= m["neck"]]
hair = max(above, key=len) if above else []
debris = kept_small = 0
model_h = max(v.co.z for v in bm.verts)
for s in above:
    group = 1 if (s is hair and len(s) >= spec.get("hairMinFaces", 1000)) else 2
    # TRELLIS leaves slivers of brow and hair strand around the head as tiny shells; as an
    # accessory they float round the head (the DarkArmour trial's "headgear" was all slivers).
    # A small shell with real area is a real part, not a sliver: Tripo's purple hair lock was 71
    # faces at an area of 66e-4 of the height squared, and dropping it left the brown skin under it
    # showing. TRELLIS slivers measured at most 15e-4 (DarkArmourAuto, BouncerAuto, 2026-11-20).
    # Kept shells sit on the head, so they join the body and the remesh fuses them on.
    if group == 2 and len(s) < spec.get("minAccessoryFaces", 300):
        if sum(faces[i].calc_area() for i in s) >= spec.get("keepShellArea", 30e-4) * model_h ** 2:
            group, kept_small = 0, kept_small + len(s)
        else:
            group, debris = 3, debris + len(s)
    elif group == 2 and spec.get("headgearIsHair"):  # a character with no headgear: split-off hair locks
        group = 1
    for i in s:
        faces[i][layer] = group
report["debrisFacesDropped"] = debris
report["smallShellFacesKept"] = kept_small
# TRELLIS fuses the hair onto the head as one shell, so it cannot be picked by shell. `hairCut`
# (model units) moves everything above that height into the hair; the remesh caps the head under it.
if m.get("hairCut"):
    for f in faces:
        if f[layer] == 0 and f.calc_center_median().z >= m["hairCut"]:
            f[layer] = 1
# `paint` boxes (model units, before the turn to -Z: front is -Y) repaint whatever lies inside
# them a flat colour before the bake. The DarkArmour trial's back of head was painted skin where the
# hair should wrap down to the neck.
def hair_colour():
    """The median colour of the source texture under the hair (faces above hairCut), so a painted
    patch matches the hair instead of standing out as a band."""
    import numpy as np

    uv = bm.loops.layers.uv.active
    samples = []
    for f in faces:
        if f[layer] != 1:
            continue
        mat = source.data.materials[f.material_index]
        tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if mat else None
        if not tex:
            continue
        img = tex.image
        if img.name not in img_px:
            img_px[img.name] = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        px = img_px[img.name]
        for loop in f.loops:
            u, v = loop[uv].uv
            samples.append(px[int((v % 1) * (img.size[1] - 1)), int((u % 1) * (img.size[0] - 1)), :3])
    if not samples:
        return (0.01, 0.01, 0.02)
    # image.pixels holds an sRGB texture's stored (gamma) values; Base Color wants linear
    srgb = np.median(np.array(samples), axis=0)
    return tuple(float(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in srgb)


def face_colour(f):
    """The source texture's sRGB colour at a face's corners, averaged; None if it has no texture."""
    import numpy as np

    uv = bm.loops.layers.uv.active
    mat = source.data.materials[f.material_index] if f.material_index < len(source.data.materials) else None
    tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if mat else None
    if not tex or uv is None:
        return None
    img = tex.image
    if img.name not in img_px:
        img_px[img.name] = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    px = img_px[img.name]
    return np.mean([px[int((l[uv].uv[1] % 1) * (img.size[1] - 1)), int((l[uv].uv[0] % 1) * (img.size[0] - 1)), :3]
                    for l in f.loops], axis=0)


def skin_like(c):
    """Warm, fairly bright: the skin TRELLIS paints where hair should be. Dark hair, armour and purple
    glow all fail it, so a paint box no longer flattens real hair texture into one colour (the
    Tripo DarkArmour's back of head, which Tripo had painted as hair, came out a flat dark block)."""
    return c is not None and c[0] > 0.35 and c[0] > c[1] > c[2] and c[0] - c[2] > 0.12


img_px = {}
for n, box in enumerate(m.get("paint", [])):
    mat = bpy.data.materials.new(f"Paint{n}")
    mat.use_nodes = True
    colour = hair_colour() if box["color"] == "hair" else tuple(box["color"])
    report[f"paint{n}Colour"] = [round(c, 3) for c in colour]
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
    source.data.materials.append(mat)
    slot = len(source.data.materials) - 1
    inside = [f for f in faces if f[layer] != 3 and all(
        box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1] for k in ("x", "y", "z") if k in box)]
    skin = [f for f in inside if skin_like(face_colour(f))] if box.get("onlySkin", True) else inside
    # The box is for skin painted where hair should be: TRELLIS put skin over most of the back of the
    # head. When skin is only a small share of the box (a Tripo head, whose hair is painted, with the
    # backs of its ears inside the box), there is nothing to fix, and repainting turned the ears dark
    # with orange rims. Area share, so a few big faces count for what they cover.
    area_in = sum(f.calc_area() for f in inside) or 1.0
    share = sum(f.calc_area() for f in skin) / area_in
    report[f"paint{n}SkinShare"] = round(share, 3)
    if share < box.get("minSkinShare", 0.35):
        skin = []
    for f in skin:
        f.material_index = slot
    report[f"paint{n}Faces"] = len(skin)
bm.verts.index_update()
vertex_shell = {}
head_shells = set()
for n, s in enumerate(shells):
    if min(v.co.z for i in s for v in faces[i].verts) >= m['neck'] - 0.07:
        head_shells.add(n)
    for i in s:
        for v in faces[i].verts:
            vertex_shell[v.index] = n
report["shells"] = len(shells)
report["accessoryShells"] = len(above)
bm.to_mesh(source.data)
bm.free()

# ---------------------------------------------------------------- 2. fit to the match body
R15 = {"ankle": 0.3, "knee": 1.5, "hip": 2.7, "waist": 3.1, "neck": 4.7}
SHOULDER = 4.55
scale = R15["neck"] / m["neck"]
stops = [(0.0, 0.0)] + sorted((m[k], v) for k, v in R15.items())


def height(z):
    if z >= stops[-1][0]:
        return stops[-1][1] + (z - stops[-1][0]) * scale
    for (z0, r0), (z1, r1) in zip(stops, stops[1:]):
        if z <= z1:
            return r0 + (z - z0) * (r1 - r0) / (z1 - z0)
    return z * scale


def arm_weight(p):
    """0 on the body, rising to 1 along the arm past the shoulder (smoothly, so the armpit
    stretches instead of tearing). Uses the same arm tests as split_whole_body.py."""
    if abs(p.x) < m.get("armInner", 0) or (p.z < m["hip"] and abs(p.x) < m.get("legOuter", 0)):
        return 0.0
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
    wrist = Vector((m["wrist"][0] * sign, 0, m["wrist"][1]))
    axis = (wrist - shoulder).normalized()
    flat = Vector((p.x, 0, p.z))
    t = (flat - shoulder).dot(axis)
    length = (wrist - shoulder).length + m.get("handLength", 0.2)
    if t < -0.03 or t > length or (flat - (shoulder + axis * t)).length > m["armRadius"] * 1.15:
        return 0.0
    k = max(0.0, min(1.0, (t + 0.03) / 0.07))
    return k * k * (3 - 2 * k)


swing = math.radians(spec.get("swing", 20))
weights = [arm_weight(v.co) for v in source.data.vertices]
# A shell that is mostly arm (the Bouncer's gloves are shells of their own) moves whole: vertex
# by vertex, its edges fell outside the arm zone and stayed behind as shards at the hips.
by_shell = {}
for i, w in enumerate(weights):
    by_shell.setdefault(vertex_shell.get(i, -1), []).append(w)
whole_arm = {n for n, ws in by_shell.items() if n >= 0 and sorted(ws)[len(ws) // 2] > 0.5}
for v in source.data.vertices:
    p = v.co.copy()
    # The automatic arm envelope can overlap a large mask at neck height.
    # Head vertices must never use the separate shoulder-height arm transform.
    in_head = vertex_shell.get(v.index, -1) in head_shells
    w = 0.0 if in_head else (1.0 if vertex_shell.get(v.index, -1) in whole_arm else weights[v.index])
    body = Vector((p.x * scale, p.y * scale, height(p.z)))
    if w == 0:
        v.co = body
        continue
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
    # the arm at the model's own scale from the match shoulder, swung out by `swing`
    local = (p - shoulder) * scale
    turned = Matrix.Rotation(-sign * swing, 3, "Y") @ local
    arm = Vector((shoulder.x * scale, 0, SHOULDER)) + turned
    v.co = body.lerp(arm, w)
source.data.update()

# split accessories off into their own objects
def take(group, name):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    scene.collection.objects.link(obj)
    pb = bmesh.new()
    pb.from_mesh(obj.data)
    lay = pb.faces.layers.int["group"]
    bmesh.ops.delete(pb, geom=[f for f in pb.faces if f[lay] != group], context="FACES")
    pb.to_mesh(obj.data)
    pb.free()
    return obj


body_src = take(0, "BodySource")
accessories = {"Hair": take(1, "Hair"), "Headgear": take(2, "Headgear")}
for name in [n for n, o in accessories.items() if not o.data.polygons]:  # never ship an empty part
    bpy.data.objects.remove(accessories.pop(name))
    report[name + "Triangles"] = 0
bpy.data.objects.remove(source)
def fuse_and_bake(src, name, faces, voxel, texture):
    """A closed copy of `src` at `faces` triangles with its paint baked on (emission, so no
    lighting gets in). Thicken first: Tripo's jacket is an open surface, and a voxel remesh of an
    open surface kept only scraps of the Bouncer's torso and upper arms. The simplifier also cannot
    collapse TRELLIS's hair, whose internal fins share edges between three or more faces; the remesh
    removes them."""
    out = src.copy()
    out.data = src.data.copy()
    out.name = name
    scene.collection.objects.link(out)
    if spec.get("preserveSurfaceTrial"):
        # Experimental: preserve the artist's face instead of voxel-remeshing it.
        mesh = bmesh.new()
        mesh.from_mesh(out.data)
        bmesh.ops.remove_doubles(mesh, verts=mesh.verts[:], dist=1e-5)
        boundary = [e for e in mesh.edges if e.is_boundary]
        filled = bmesh.ops.holes_fill(mesh, edges=boundary, sides=0)["faces"]
        bmesh.ops.triangulate(mesh, faces=mesh.faces[:])
        bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces[:])
        report[name + "TrialFilledFaces"] = len(filled)
        report[name + "TrialNonManifoldEdges"] = sum(not e.is_manifold for e in mesh.edges)
        mesh.to_mesh(out.data)
        count = len(mesh.faces)
        mesh.free()
        out.data.validate(clean_customdata=False)
        out.data.update()
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        bpy.data.objects.remove(src)
        return out, count
    bpy.context.view_layer.objects.active = out
    for o in bpy.data.objects:
        o.select_set(o == out)
    thick = out.modifiers.new("thicken", "SOLIDIFY")
    thick.thickness = voxel * 2.5
    thick.offset = -1  # inward, so the outside stays where the paint is
    bpy.ops.object.modifier_apply(modifier="thicken")
    remesh = out.modifiers.new("fuse", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier="fuse")
    remeshed = sum(len(p.vertices) - 2 for p in out.data.polygons)
    reduce = out.modifiers.new("reduce", "DECIMATE")
    reduce.ratio = min(1.0, faces / max(1, remeshed))
    bpy.ops.object.modifier_apply(modifier="reduce")
    # The reduction leaves sliver triangles (areas near 1e-6 square studs), and lone faces float
    # off the surface. Slivers made Blender's heat skinning fail on the whole body (BouncerAuto and
    # the Tripo body) and are a risk for Studio's own skinning. Collapse edges shorter than a
    # quarter voxel, then drop islands of fewer than 50 faces.
    cleaned = bmesh.new()
    cleaned.from_mesh(out.data)
    bmesh.ops.triangulate(cleaned, faces=cleaned.faces[:])
    for _ in range(3):
        bmesh.ops.dissolve_degenerate(cleaned, edges=cleaned.edges[:], dist=voxel * 0.25)
        thin = [e for e in cleaned.edges if e.is_valid and e.calc_length() < voxel * 0.25]
        if not thin:
            break
        bmesh.ops.collapse(cleaned, edges=thin)
    cleaned.faces.ensure_lookup_table()
    seen, islands = set(), []
    for f in cleaned.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(island)
    bmesh.ops.delete(cleaned, geom=[f for i in islands if len(i) < 50 for f in i], context="FACES")
    bmesh.ops.triangulate(cleaned, faces=cleaned.faces[:])
    bmesh.ops.recalc_face_normals(cleaned, faces=cleaned.faces[:])
    cleaned.to_mesh(out.data)
    cleaned.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    # smart_project left DarkArmourAuto's 12k body using 29% of its 1024 texture (Roblox's cap), so the
    # paint projected from the picture came out mottled. Packing the islands by shape fills far more.
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, shape_method="CONCAVE", margin_method="FRACTION", margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    out.data.materials.clear()

    image = bpy.data.images.new(name + "Color", texture, texture, alpha=False)
    mat = bpy.data.materials.new(name + "Color")
    mat.use_nodes = True
    holder = mat.node_tree.nodes.new("ShaderNodeTexImage")
    holder.image = image
    mat.node_tree.links.new(holder.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    mat.node_tree.nodes.active = holder
    out.data.materials.append(mat)

    for slot in src.material_slots:
        slot.material = slot.material.copy()  # shared with the other parts, which keep their paint
        tree = slot.material.node_tree
        tex = next((n for n in tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
        emit = tree.nodes.new("ShaderNodeEmission")
        sink = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
        if tex:
            tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
        else:  # a flat `paint` colour
            emit.inputs["Color"].default_value = tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        tree.links.new(emit.outputs["Emission"], sink.inputs["Surface"])
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = voxel * spec.get("cage", 3)
    scene.render.bake.max_ray_distance = voxel * spec.get("cage", 3) * 2.7
    scene.render.bake.margin = 6
    for o in bpy.data.objects:
        o.select_set(o in (out, src))
    bpy.context.view_layer.objects.active = out
    bpy.ops.object.bake(type="EMIT")
    if name == "Hair" and spec.get("cleanHairFlecks", True):
        # TRELLIS paints pale flecks and highlights into dark hair; pull pale, grey texels down to
        # the hair's own median colour. Saturated streaks (a purple fringe) are kept.
        import numpy as np

        px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = px[:, :3]
        hi, lo = rgb.max(1), rgb.min(1)
        lum = rgb.mean(1)
        sat = (hi - lo) / np.maximum(hi, 1e-4)
        dark = lum < np.percentile(lum, 70)
        pale = (lum > np.percentile(lum, 70) * 1.8) & (sat < 0.35)
        if dark.any() and pale.any():
            rgb[pale] = np.median(rgb[dark], axis=0)
            px[:, :3] = rgb
            image.pixels[:] = px.ravel()
            report["hairFlecksCleaned"] = int(pale.sum())
    image.filepath_raw = str(OUT / f"{name}Color.png")
    image.file_format = "PNG"
    image.save()
    bpy.data.objects.remove(src)
    return out, remeshed


# ---------------------------------------------------------------- 3. one watertight shell
voxel = spec.get("voxel", 0.004) * scale
body, report["remeshTriangles"] = fuse_and_bake(body_src, "Body", spec.get("faces", 12000), voxel,
                                                spec.get("texture", 1024))
# Accessories over budget (TRELLIS's come at the generator's density: the Bouncer's hair was
# 35,000 triangles) get the same treatment at a finer voxel, which keeps spikes and strands.
for name in list(accessories):
    obj = accessories[name]
    limit = spec.get("accessoryFaces", 4000)
    if sum(len(p.vertices) - 2 for p in obj.data.polygons) > limit:
        obj.name = name + "Source"
        accessories[name], _ = fuse_and_bake(obj, name, limit, voxel * 0.6, spec.get("texture", 1024) // 2)

# ---------------------------------------------------------------- 4. face -Z, write, preview
flip = Matrix.Rotation(math.pi, 4, "Z")  # Blender -Y front -> +Y, which glTF and FBX write as -Z
for obj in [body, *accessories.values()]:
    obj.data.transform(flip)
    obj.data.update()

# measurements for the report: height, open edges, shells, triangles, arms clear of the body
pb = bmesh.new()
pb.from_mesh(body.data)
report["bodyTriangles"] = len(pb.faces)
report["bodyOpenEdges"] = sum(e.is_boundary for e in pb.edges)
pb.free()
report["height"] = round(max(v.co.z for v in body.data.vertices), 3)
for name, obj in accessories.items():
    report[name + "Triangles"] = len(obj.data.polygons)

for name, obj in [("Body", body), *accessories.items()]:
    for o in bpy.data.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True,
                              export_yup=True)
# The FBX for Studio is written from these GLBs by tools/blender/write_fbx.py (kit_look.py runs it next),
# which fixes its size and front and reads it back.

# preview: front and side, flat light
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.88, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.4
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(60), 0, math.radians(160))
scene.collection.objects.link(sun)
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y = 900, 1000
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 9
scene.collection.objects.link(cam)
scene.camera = cam
for view, location, rotation in (("front", (0, 30, 3.3), (math.pi / 2, 0, math.pi)),
                                 ("side", (30, 0, 3.3), (math.pi / 2, 0, math.pi / 2))):
    cam.location = location
    cam.rotation_euler = rotation
    scene.render.filepath = str(OUT / f"preview-{view}.png")
    bpy.ops.render.render(write_still=True)

(OUT / "prepare.json").write_text(json.dumps(report, indent=1))
print("PREPARED", json.dumps(report))
