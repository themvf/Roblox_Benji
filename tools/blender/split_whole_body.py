"""Cut one whole-body character model into the 15 blocky R15 parts, in the review rest pose.

    blender -b -noaudio --python tools/blender/split_whole_body.py -- <spec.json>

Run by `python tools/kit_look.py whole`. Why: a look made piece by piece from separate pictures
came out as "a lot of random pieces put together" (the Bouncer, 2026-11-19). One model made from
one picture shares one texture, so its parts match; this cuts it where R15 bends.

spec.json:
  source     the GLB (Tripo faces +X; `turn` -90 makes it face -Y like the review body)
  out        folder for <Part>.glb and split.json
  grid       optional: only render a front view with the model's measured frame to this png
  marks      the joints, measured on the grid render in the model's own units after it is
             stood on z=0 and centred: neck, waist, hip, knee, ankle (heights); shoulder, elbow,
             wrist ([x, z] of the arm's middle line on the character's left, +X); armRadius
             (how far from that line still counts as arm); armInner (optional: nothing nearer
             the middle than this is arm, for arms that hang against the body); legOuter
             (optional: below the hip, nothing nearer the middle than this is arm, for gloves
             hanging beside the thighs); handLength (how far past the wrist the hand reaches, 0.2
             by default). The right side is the mirror.
             Reshaping and joints (all optional): remove (boxes of faces to delete, e.g. a zip
             fin Tripo stood off the chest), collar ({z, rMin, scaleZ, flare}: stretch a collar
             ring taller; it stays on the torso), handScale (oversized fists), overlap (how far a
             child part also carries its parent's surface past each cut, 0.025; closes tears in
             the walking pose), tuck (pushes those copies just under the surface, 0.0015),
             decimate ({Part: ratio}, after welding), caps (lids on cuts; off, see below).

The arms of an A-pose are swung down to hang straight, then every height is mapped piecewise
onto the R15 joint heights (ankle 0.3, knee 1.5, hip 2.7, waist 3.1, neck 4.7; shoulder 4.55,
elbow 3.5, wrist 2.4 along the arm), so neighbouring parts still meet at the cuts and each part
turns about the joint the game turns it about. Widths keep the model's proportions.
Blender axes: Z up, the character faces -Y, its left is +X. 1 unit = 1 stud.
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

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=spec["source"])
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.context.view_layer.update()
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
body = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
body.data.transform(Matrix.Rotation(math.radians(spec.get("turn", -90)), 4, "Z"))

# Stand it on z = 0, centred on x and y. Marks are measured in this frame.
xs, ys, zs = ([v.co[i] for v in body.data.vertices] for i in range(3))
shift = Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs)))
body.data.transform(Matrix.Translation(shift))
height = max(zs) - min(zs)
width = max(xs) - min(xs)

if spec.get("grid"):
    # A flat front view, orthographic, so a pixel maps straight to model units.
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.resolution_x = scene.render.resolution_y = 1024
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.9, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(70), 0, math.radians(-15))  # from the front, a little high
    scene.collection.objects.link(sun)
    side = max(width, height) * 1.08
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = side
    cam.data.clip_end = side * 20
    cam.location = (0, -side * 5, height / 2)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.filepath = spec["grid"]
    bpy.ops.render.render(write_still=True)
    Path(spec["grid"]).with_suffix(".json").write_text(json.dumps(
        {"centre": [0, height / 2], "side": side, "pixels": 1024, "height": height, "width": width}))
    print("GRID", spec["grid"], "height", round(height, 4), "width", round(width, 4))
    sys.exit(0)

m = spec["marks"]
R15 = {"ankle": 0.3, "knee": 1.5, "hip": 2.7, "waist": 3.1, "neck": 4.7}
ARM = {"shoulder": 4.55, "elbow": 3.5, "wrist": 2.4}

# Horizontal scale: the model's sole-to-neck height onto R15's.
scale = R15["neck"] / m["neck"]


def side_marks(sign):
    def flip(p):
        return Vector((p[0] * sign, 0, p[1]))
    key = "right" if sign < 0 else "left"
    own = spec.get("marksRight", {}) if sign < 0 else {}
    return {k: flip(own.get(k, m[k])) for k in ("shoulder", "elbow", "wrist")} | {"key": key}


arms = {s: side_marks(s) for s in (1, -1)}

# Cut along every plane first, so each face then lies wholly in one part.
bm = bmesh.new()
bm.from_mesh(body.data)
# Weld Tripo's texture seams: its mesh arrives as ~2,700 loose patches (one per UV island), so
# every patch edge looked like a cut and got a lid, 7,000 triangles of them. UVs live on the
# corners, so welding keeps the texture.
before = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=height * 1e-5)
print("WELD", before, "->", len(bm.verts), "verts;", sum(e.is_boundary for e in bm.edges), "open edges")
band = m.get("overlap", 0.025)  # how far a child part reaches back over its parent (model units)
collar_layer = bm.faces.layers.int.new("collar")

# Reshape first, in the model's own frame.
# `remove`: faces to delete, by box (x, y, z ranges). Tripo made the Bouncer's zip a free fin
# standing half a stud off his chest with a spike below the hem; a Neon strip replaces it.
for box in m.get("remove", []):
    doomed = [f for f in bm.faces if all(box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1]
                                        for k in ("x", "y", "z") if k in box)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    print("REMOVED", len(doomed), "faces in", box)
# `collar`: stretch a collar ring taller and flare it (the concept's popped collar came out of
# Tripo as a low ring). Its faces stay on the torso, so the head can turn inside it.
collar = m.get("collar")
if collar:
    lo, hi = collar["z"]
    for f in bm.faces:
        c = f.calc_center_median()
        if lo <= c.z <= hi and math.hypot(c.x, c.y) > collar["rMin"]:
            f[collar_layer] = 1
    moved = {v for f in bm.faces if f[collar_layer] for v in f.verts}
    for v in moved:
        k = max(0.0, min(1.0, (v.co.z - lo) / (hi - lo)))
        flare = 1 + (collar.get("flare", 1.0) - 1) * k
        v.co = Vector((v.co.x * flare, v.co.y * flare, lo + (v.co.z - lo) * collar.get("scaleZ", 1.0)))


def cut(co, no, keep):
    """Cut only the faces `keep` says the plane is for. Cutting every face with every plane
    added about 6,000 triangles to the Bouncer (hip planes through the arms and so on)."""
    faces = [f for f in bm.faces if keep(f.calc_center_median())]
    edges = list({e for f in faces for e in f.edges})
    verts = list({v for f in faces for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=verts + edges + faces, plane_co=co, plane_no=no)


def arm_part(c):
    """Which arm part a face centre belongs to, or None."""
    if abs(c.x) < m.get("armInner", 0):  # arms hanging against the body: the jacket side stays torso
        return None
    if c.z < m["hip"] and abs(c.x) < m.get("legOuter", 0):  # a glove hanging beside the thigh
        return None
    a = arms[1 if c.x >= 0 else -1]
    side = "Left" if c.x >= 0 else "Right"
    upper = a["elbow"] - a["shoulder"]
    lower = a["wrist"] - a["elbow"]
    flat = Vector((c.x, 0, c.z))
    t = (flat - a["shoulder"]).dot(upper.normalized())
    if t <= 0:
        return None
    # distance from the arm's middle line (shoulder -> elbow -> wrist and on past the hand)
    if t < upper.length:
        foot = a["shoulder"] + upper.normalized() * t
    else:
        foot = a["elbow"] + lower.normalized() * max(0.0, (flat - a["elbow"]).dot(lower.normalized()))
    if (flat - foot).length > m["armRadius"]:
        return None
    if t < upper.length:
        return side + "UpperArm"
    past_wrist = (flat - a["wrist"]).dot(lower.normalized())
    if past_wrist < 0:
        return side + "LowerArm"
    if past_wrist > m.get("handLength", 0.2):  # the arm's line runs on into the boots
        return None
    return side + "Hand"


def core(c):
    return arm_part(c) is None


def arm_coords(c):
    """(side sign, distance along the arm from the shoulder, distance from the arm's line)."""
    sign = 1 if c.x >= 0 else -1
    a = arms[sign]
    upper = (a["elbow"] - a["shoulder"]).normalized()
    flat = Vector((c.x, 0, c.z))
    t = (flat - a["shoulder"]).dot(upper)
    foot = a["shoulder"] + upper * t
    return sign, t, (flat - foot).length


for level in ("neck", "waist", "hip", "knee", "ankle"):
    cut((0, 0, m[level]), (0, 0, 1), core)
cut((0, 0, 0), (1, 0, 0), lambda c: core(c) and c.z < m["hip"] + 0.02)
for s, a in arms.items():
    def mine(c, s=s):
        return arm_part(c) is not None and (c.x >= 0) == (s > 0)
    cut(a["shoulder"], (a["elbow"] - a["shoulder"]).normalized(), lambda c, s=s: (c.x >= 0) == (s > 0) and abs(c.x) >= m.get("armInner", 0))
    cut(a["elbow"], (a["wrist"] - a["elbow"]).normalized(), mine)
    cut(a["wrist"], (a["wrist"] - a["elbow"]).normalized(), mine)
# Overlap bands: a second cut a little way into the parent, so the strip between can also ride
# the child. The cut model tore open at hip, knee and hem in the walking pose (second audit,
# 2026-11-19); a child that carries a band of its parent's surface closes that gap as it turns.
# (Not the ankle: R15 barely turns it, and its band doubled the dense boot strap, +500 each.)
hip_band = m.get("overlapHip", band)  # a stride turns the thigh furthest: a wedge opened there
for level, offset in (("knee", band), ("hip", hip_band), ("waist", -band)):
    cut((0, 0, m[level] + offset), (0, 0, 1), core)
for s, a in arms.items():
    up = (a["elbow"] - a["shoulder"]).normalized()
    down = (a["wrist"] - a["elbow"]).normalized()

    def mine(c, s=s):
        return arm_part(c) is not None and (c.x >= 0) == (s > 0)
    cut(a["elbow"] - up * band, up, mine)
    cut(a["wrist"] - down * band, down, mine)
    cut(a["shoulder"] - up * band, up, lambda c, s=s: (c.x >= 0) == (s > 0) and abs(c.x) >= m.get("armInner", 0))
bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])


def part_of(c, collar_face=False):
    arm = arm_part(c)
    if arm:
        return arm
    if collar_face:
        return "UpperTorso"
    if c.z > m["neck"]:
        return "Head"
    if c.z > m["waist"]:
        return "UpperTorso"
    if c.z > m["hip"]:
        return "LowerTorso"
    side = "Left" if c.x >= 0 else "Right"
    if c.z > m["knee"]:
        return side + "UpperLeg"
    if c.z > m["ankle"]:
        return side + "LowerLeg"
    return side + "Foot"


def extras(c, part):
    """The children whose overlap band this face also belongs to."""
    side = "Left" if c.x >= 0 else "Right"
    more = []
    if part.endswith("UpperLeg") and c.z < m["knee"] + band:
        more.append(side + "LowerLeg")
    if part == "LowerTorso" and c.z < m["hip"] + hip_band:
        more.append(side + "UpperLeg")
    if part == "LowerTorso" and c.z > m["waist"] - band:
        more.append("UpperTorso")
    if part in ("UpperTorso", "LowerTorso") and abs(c.x) >= m.get("armInner", 0):
        sign, t, off = arm_coords(c)
        if -band <= t <= 0 and off <= m["armRadius"]:
            more.append(side + "UpperArm")
    if part.endswith("UpperArm"):
        sign, t, off = arm_coords(c)
        if t > (arms[sign]["elbow"] - arms[sign]["shoulder"]).length - band:
            more.append(side + "LowerArm")
    if part.endswith("LowerArm"):
        a = arms[1 if c.x >= 0 else -1]
        down = (a["wrist"] - a["elbow"]).normalized()
        if (Vector((c.x, 0, c.z)) - a["wrist"]).dot(down) > -band:
            more.append(side + "Hand")
    return more


assign, bands = {}, {}
for f in bm.faces:
    c = f.calc_center_median()
    part = part_of(c, bool(f[collar_layer]))
    for name in [part] + extras(c, part):
        assign.setdefault(name, []).append(f.index)
        if name != part:
            bands.setdefault(name, set()).add(f.index)
bm.to_mesh(body.data)
bm.free()


def piecewise(z, stops):
    """Map a model height onto R15 heights through (model, r15) stops, linear in between and
    at the scale outside them."""
    stops = sorted(stops)
    if z <= stops[0][0]:
        return stops[0][1] + (z - stops[0][0]) * scale
    if z >= stops[-1][0]:
        return stops[-1][1] + (z - stops[-1][0]) * scale
    for (z0, r0), (z1, r1) in zip(stops, stops[1:]):
        if z0 <= z <= z1:
            return r0 + (z - z0) * (r1 - r0) / (z1 - z0)
    return z


BODY_STOPS = [(0, 0)] + [(m[k], R15[k]) for k in R15]

report = {}
for part, faces in assign.items():
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = part
    bpy.context.scene.collection.objects.link(obj)
    keep = set(faces)
    pb = bmesh.new()
    pb.from_mesh(obj.data)
    pb.faces.ensure_lookup_table()
    tucked = {v for f in pb.faces if f.index in bands.get(part, ()) for v in f.verts}
    bmesh.ops.delete(pb, geom=[f for f in pb.faces if f.index not in keep], context="FACES")
    # A band copy sits exactly on its parent's surface; the two flickered as dark bars at the
    # Bouncer's elbows and knees. Tuck the copy just under, so it only shows once the joint bends.
    pb.normal_update()
    for v in tucked:
        if v.is_valid:
            v.co -= v.normal * m.get("tuck", 0.0015)
    # No lids on the cuts: filled cut loops on the Bouncer were not flat rings, and one lid
    # stretched from ankle to knee and showed through the leg as a black bar. The overlap bands
    # (above) cover the joints instead. Turn on with `caps` to try again on a cleaner mesh.
    if m.get("caps"):
        capped = bmesh.ops.holes_fill(pb, edges=[e for e in pb.edges if e.is_boundary], sides=0)["faces"]
        uv_layer = pb.loops.layers.uv.active
        for f in bmesh.ops.triangulate(pb, faces=capped)["faces"] if capped else []:
            for loop in f.loops:
                loop[uv_layer].uv = spec.get("capUV", [0.5, 0.5])
    if "Arm" in part or "Hand" in part:
        a = arms[1 if part.startswith("Left") else -1]
        down = Vector((0, 0, -1))
        along = (a["wrist"] - a["shoulder"]).normalized()
        swing = along.rotation_difference(down).to_matrix()
        for v in pb.verts:  # swing the arm down about the shoulder, then map along the arm
            local = swing @ (v.co - a["shoulder"])
            elbow_t = (a["elbow"] - a["shoulder"]).length
            wrist_t = (a["wrist"] - a["shoulder"]).length
            t = -local.z
            r15 = piecewise(-t, [(-wrist_t, ARM["wrist"] - ARM["shoulder"]),
                                 (-elbow_t, ARM["elbow"] - ARM["shoulder"]), (0, 0)])
            # The arm stays at the model's own shoulder width: forced out to R15's 1.5 studs, a
            # slim test model showed daylight beside the chest. It still turns about R15's pivot.
            v.co = Vector((a["shoulder"].x * scale + local.x * scale, local.y * scale, ARM["shoulder"] + r15))
        if "Hand" in part and m.get("handScale", 1.0) != 1.0:
            # Oversized fists are a line of the bar; the picture's gloves were life-size.
            pivot = Vector((a["shoulder"].x * scale, 0, ARM["wrist"]))
            for v in pb.verts:
                v.co = pivot + (v.co - pivot) * m["handScale"]
    else:
        for v in pb.verts:
            v.co = Vector((v.co.x * scale, v.co.y * scale, piecewise(v.co.z, BODY_STOPS)))
    pb.to_mesh(obj.data)
    pb.free()
    obj.data.update()
    ratio = m.get("decimate", {}).get(part)
    if ratio:
        # Only on the welded mesh: earlier reductions tore Tripo meshes along their unwelded
        # texture seams. The Bouncer's hair alone was 8,900 of a 20,000 character.
        bpy.context.view_layer.objects.active = obj
        reduce = obj.modifiers.new("reduce", "DECIMATE")
        reduce.ratio = ratio
        reduce.delimit = {"SEAM", "UV"}
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier="reduce")
    report[part] = len(obj.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{part}.glb"), export_format="GLB", use_selection=True,
                              export_yup=True)

bpy.data.objects.remove(body)
(OUT / "split.json").write_text(json.dumps({"triangles": report, "scale": scale,
                                           "armX": round(arms[1]["shoulder"].x * scale, 3)}, indent=1))
print("SPLIT", json.dumps(report))
