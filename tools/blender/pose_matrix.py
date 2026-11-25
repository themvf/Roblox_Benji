"""Pose matrix for a skinned body prepared for Avatar Setup (tools/kit_look.py skinned).

    blender -b -noaudio --python tools/blender/pose_matrix.py -- <folder> [<folder> ...] --out <dir>

Each folder holds Body.glb, Hair.glb, Headgear.glb and prepare-spec.json. An R15 skeleton is built
at the match body's joint heights (docs/design/kits/MATCH_BODY.md), arms following the body's own
pose (A or T, from the spec's swing and marks). The body is skinned with Blender's automatic
(heat) weights, accessories ride the head, and it is posed through the moves the game uses,
holding a rifle the size of the game's AssaultRifle: each pose reports how many rifle/body
triangle pairs intersect (front: receiver and barrel; stock, which may rest on the shoulder).
The Weapons Kit's shoulder camera (2.25 right, 2.25 up, 10.5 back from the root part, FOV 70)
renders idle and aim, and reports how much of the screen centre, where the crosshair sits, the
character covers (crosshairCovered). Body faces within GRIP_CLEAR of the grip are the hand.

This is a stand-in for Studio's Avatar Setup, which skins with its own method: a body that tears
here will very likely tear there, but passing here does not prove Studio. Per pose it reports the
share of triangles stretched past 2x or crushed under 0.35x of their rest area, and renders front
and side. Writes <out>/pose-matrix.png and <out>/pose-matrix.json.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = os.path.abspath(argv[argv.index("--out") + 1])
folders = [a for a in argv[: argv.index("--out")]]
os.makedirs(out_dir, exist_ok=True)

R15 = {"ankle": 0.3, "knee": 1.5, "hip": 2.7, "waist": 3.1, "neck": 4.7}
SHOULDER = 4.55
# studs (the body is scaled to the match body first): coarser than the gaps between clothing layers, finer
# than the gap between the thighs. 0 turns the stand-in off and weights the body directly.
PROXY_VOXEL = float(os.environ.get("POSE_PROXY_VOXEL", "0.06"))

# Each pose: (bone, world axis, degrees) applied in order, about the bone's head, on top of what
# its parent already did. The front is +Y, so +X rotation swings a hanging limb forward. Every pose
# but "bind" starts from "idle": arms brought down to the sides, as the game's idle holds them,
# which is the hardest case for a T-pose body (the armpit folds 90 degrees).
L, R = ".L", ".R"
POSES = {
    "bind": [],
    "idle": [],
    "walk": [("UpperLeg" + L, "X", 30), ("LowerLeg" + L, "X", -20), ("UpperLeg" + R, "X", -30),
             ("LowerLeg" + R, "X", -45), ("UpperArm" + L, "X", -30), ("UpperArm" + R, "X", 30),
             ("LowerArm" + L, "X", 20), ("LowerArm" + R, "X", 20)],
    "run": [("UpperTorso", "X", 12), ("UpperLeg" + L, "X", 55), ("LowerLeg" + L, "X", -70),
            ("UpperLeg" + R, "X", -40), ("LowerLeg" + R, "X", -90), ("UpperArm" + L, "X", -55),
            ("UpperArm" + R, "X", 55), ("LowerArm" + L, "X", 80), ("LowerArm" + R, "X", 80)],
    "crouch": [("UpperTorso", "X", 20), ("UpperLeg" + L, "X", 80), ("LowerLeg" + L, "X", -110),
               ("UpperLeg" + R, "X", 80), ("LowerLeg" + R, "X", -110), ("Foot" + L, "X", 30),
               ("Foot" + R, "X", 30)],
    "aim": [("Head", "Z", 20), ("UpperArm" + R, "X", 85), ("UpperArm" + L, "X", 70), ("UpperArm" + L, "Z", -25),
            ("LowerArm" + L, "X", 30)],
    "jump": [("UpperLeg" + L, "X", 70), ("LowerLeg" + L, "X", -100), ("UpperLeg" + R, "X", 20),
             ("LowerLeg" + R, "X", -60), ("UpperArm" + L, "Y", -120), ("UpperArm" + R, "Y", 120)],
    "headturn": [("UpperTorso", "Z", -15), ("Head", "Z", 50)],
}


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o != obj and o.name in bpy.data.objects and o.type != "MESH":
            bpy.data.objects.remove(o)
    return obj


def tri_areas(obj, depsgraph):
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    areas = [t.area for t in me.loop_triangles]
    ev.to_mesh_clear()
    return areas


def build(folder, offset_x):
    spec = json.load(open(os.path.join(folder, "prepare-spec.json")))
    m = spec["marks"]
    scale = R15["neck"] / m["neck"]
    swing = math.radians(spec.get("swing", 20))
    body = load(os.path.join(folder, "Body.glb"))
    # glTF splits vertices at UV seams; heat weighting needs the closed surface back
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.to_mesh(body.data)
    bm.free()
    # glTF import of a -Z-facing file: the front is Blender -Y again; measure where the legs are
    vs = [body.matrix_world @ v.co for v in body.data.vertices]
    knee_band = [v for v in vs if R15["ankle"] < v.z < R15["knee"]]
    leg_x = sum(abs(v.x) for v in knee_band) / max(1, len(knee_band))
    front_sign = 1  # prepare_avatar_setup writes the front as glTF -Z, which imports as Blender +Y

    arm = bpy.data.armatures.new("R15")
    rig = bpy.data.objects.new("R15", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        return b

    top = max(v.z for v in vs)
    bone("LowerTorso", (0, 0, R15["hip"]), (0, 0, R15["waist"]))
    bone("UpperTorso", (0, 0, R15["waist"]), (0, 0, R15["neck"] - 0.15), "LowerTorso")
    bone("Head", (0, 0, R15["neck"]), (0, 0, top), "UpperTorso")
    sx = m["shoulder"][0] * scale
    for side, s in (("L", 1), ("R", -1)):
        # the arm direction in the prepared body: the model's own shoulder->wrist, swung out by `swing`
        d = Vector(((m["wrist"][0] - m["shoulder"][0]) * s, 0, m["wrist"][1] - m["shoulder"][1])).normalized()
        d = Matrix.Rotation(-s * swing, 3, "Y") @ d
        sh = Vector((s * sx, 0, SHOULDER))
        upper = (Vector((m["elbow"][0], 0, m["elbow"][1])) - Vector((m["shoulder"][0], 0, m["shoulder"][1]))).length * scale
        lower = (Vector((m["wrist"][0], 0, m["wrist"][1])) - Vector((m["elbow"][0], 0, m["elbow"][1]))).length * scale
        hand = m.get("handLength", 0.15) * scale
        el = sh + d * upper
        wr = el + d * lower
        bone(f"UpperArm.{side}", sh, el, "UpperTorso")
        bone(f"LowerArm.{side}", el, wr, f"UpperArm.{side}")
        bone(f"Hand.{side}", wr, wr + d * hand, f"LowerArm.{side}")
        bone(f"UpperLeg.{side}", (s * leg_x, 0, R15["hip"]), (s * leg_x, 0, R15["knee"]), "LowerTorso")
        bone(f"LowerLeg.{side}", (s * leg_x, 0, R15["knee"]), (s * leg_x, 0, R15["ankle"]), f"UpperLeg.{side}")
        bone(f"Foot.{side}", (s * leg_x, 0, R15["ankle"]), (s * leg_x, front_sign * 0.6, 0.05), f"LowerLeg.{side}")
    bpy.ops.object.mode_set(mode="OBJECT")

    for o in bpy.data.objects:
        o.select_set(o in (body, rig))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if PROXY_VOXEL:
        proxy_weights(body, rig)
    unweighted = sum(1 for v in body.data.vertices if not v.groups)
    lost = [v.co for v in body.data.vertices if not v.groups]
    if lost:  # where heat weighting gave up, to say why in the report
        print("UNWEIGHTED", len(lost), "z", round(min(c.z for c in lost), 2), round(max(c.z for c in lost), 2),
              "x", round(min(c.x for c in lost), 2), round(max(c.x for c in lost), 2))
    method = "heat"
    if unweighted > len(body.data.vertices) * 0.05:
        for g in list(body.vertex_groups):
            body.vertex_groups.remove(g)
        nearest_bone_weights(body, rig)
        method = "nearest bone (heat weighting found no solution)"

    parts = [body]
    for acc in ("Hair", "Headgear"):
        p = os.path.join(folder, f"{acc}.glb")
        if os.path.exists(p):
            a = load(p)
            if len(a.data.polygons) == 0:
                bpy.data.objects.remove(a)
                continue
            rig.data.bones.active = rig.data.bones["Head"]
            for o in bpy.data.objects:
                o.select_set(o in (a, rig))
            bpy.context.view_layer.objects.active = rig
            bpy.ops.object.parent_set(type="BONE", keep_transform=True)
            parts.append(a)
    rig.location.x = offset_x
    return {"name": os.path.basename(folder.rstrip("/\\")), "rig": rig, "body": body, "parts": parts,
            "swing": swing, "unweighted": unweighted, "method": method, "frontSign": front_sign, "dir": spec}


def proxy_weights(body, rig):
    """Weight a solid stand-in and copy its weights onto the body, so layers lying on each other move as one.
    Heat weighting reaches a jacket but not the shirt and tie under it, so the layers took different weights
    and slid through each other in every pose: the tie and the dark inner walls showed as black patches on
    the grey suit and over the black coat's eyes (2026-11-22). The stand-in is the body voxel-remeshed
    coarser than the gaps between layers; each body vertex takes the weights of the nearest point on it."""
    proxy = body.copy()
    proxy.data = body.data.copy()
    proxy.name = "WeightProxy"
    bpy.context.scene.collection.objects.link(proxy)
    for g in list(proxy.vertex_groups):
        proxy.vertex_groups.remove(g)
    proxy.modifiers.clear()
    proxy.parent = None
    fuse = proxy.modifiers.new("fuse", "REMESH")
    fuse.mode, fuse.voxel_size, fuse.adaptivity = "VOXEL", PROXY_VOXEL, 0
    smooth = proxy.modifiers.new("smooth", "SMOOTH")
    smooth.factor, smooth.iterations = 0.5, 4
    bpy.context.view_layer.objects.active = proxy
    for o in bpy.data.objects:
        o.select_set(o is proxy)
    bpy.ops.object.modifier_apply(modifier="fuse")
    bpy.ops.object.modifier_apply(modifier="smooth")
    for o in bpy.data.objects:
        o.select_set(o in (proxy, rig))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if sum(1 for v in proxy.data.vertices if not v.groups) > 0.05 * len(proxy.data.vertices):
        bpy.data.objects.remove(proxy)  # heat failed on the stand-in too: keep the body's own weights
        return
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    for g in proxy.vertex_groups:
        body.vertex_groups.new(name=g.name)
    move = body.modifiers.new("weights", "DATA_TRANSFER")
    move.object = proxy
    move.use_vert_data = True
    move.data_types_verts = {"VGROUP_WEIGHTS"}
    move.vert_mapping = "POLYINTERP_NEAREST"
    move.layers_vgroup_select_src = "ALL"
    move.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = body
    for o in bpy.data.objects:
        o.select_set(o is body)
    # the armature modifier from parenting sits first; the transfer must run before it
    bpy.ops.object.modifier_move_to_index(modifier="weights", index=0)
    bpy.ops.object.modifier_apply(modifier="weights")
    bpy.data.objects.remove(proxy)
    fill_unweighted(body)
    # The stand-in's coarse voxels hand weights over in steps, which tore the black suit's jacket hem into
    # teeth over the raised thigh in the run pose (2026-11-23). Off by default: 4 passes barely helped, 12 smoothed
    # the hem but tore the sleeve and opened the knee, and stretch rose from 3.5% to 9.4%. POSE_WEIGHT_SMOOTH=n tries it.
    # (Done here: bpy.ops.object.vertex_group_smooth refuses to run outside weight-paint mode in a script.)
    me = body.data
    links = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        links[a].append(b)
        links[b].append(a)
    w = [{g.group: g.weight for g in v.groups if g.weight > 1e-4} for v in me.vertices]
    for _ in range(int(os.environ.get("POSE_WEIGHT_SMOOTH", "0"))):
        nxt = []
        for i, own in enumerate(w):
            if not links[i]:
                nxt.append(own)
                continue
            mean = {}
            for j in links[i]:
                for g, x in w[j].items():
                    mean[g] = mean.get(g, 0.0) + x / len(links[i])
            mixed = {g: 0.5 * own.get(g, 0.0) + 0.5 * mean.get(g, 0.0) for g in set(own) | set(mean)}
            total = sum(mixed.values()) or 1.0
            nxt.append({g: x / total for g, x in mixed.items() if x / total > 1e-3})
        w = nxt
    for g in body.vertex_groups:
        g.remove(list(range(len(me.vertices))))
    for i, ws in enumerate(w):
        for g, x in ws.items():
            body.vertex_groups[g].add([i], x, "REPLACE")


def fill_unweighted(body):
    """A vertex whose nearest stand-in point carried no weight stays where the T-pose put it while the arm
    around it moves, and draws out a thin wire: the black coat's left shoulder in idle, run and crouch
    (2026-11-23). Each such vertex takes the mean of its weighted neighbours, spreading inward ring by ring."""
    me = body.data
    groups = {v.index: {g.group: g.weight for g in v.groups if g.weight > 1e-4} for v in me.vertices}
    links = {i: set() for i in groups}
    for e in me.edges:
        a, b = e.vertices
        links[a].add(b)
        links[b].add(a)
    empty = {i for i, w in groups.items() if sum(w.values()) < 0.05}
    filled = 0
    while empty:
        done = {}
        for i in empty:
            ws = [groups[j] for j in links[i] if j not in empty]
            if ws:
                mean = {}
                for w in ws:
                    for g, x in w.items():
                        mean[g] = mean.get(g, 0.0) + x / len(ws)
                done[i] = mean
        if not done:
            break
        for i, w in done.items():
            groups[i] = w
            for g, x in w.items():
                body.vertex_groups[g].add([i], x, "REPLACE")
        empty -= set(done)
        filled += len(done)
    print(f"proxy weights: {filled} unweighted vertices filled from their neighbours, {len(empty)} left")


def nearest_bone_weights(body, rig):
    """Fallback when heat weighting finds no solution: each vertex to its nearest one or two bones."""
    bones = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones]
    for v in body.data.vertices:
        ds = []
        for name, h, t in bones:
            seg = t - h
            k = max(0.0, min(1.0, (v.co - h).dot(seg) / max(seg.length_squared, 1e-9)))
            ds.append(((v.co - (h + seg * k)).length, name))
        ds.sort()
        near = [d for d in ds[:2] if d[0] < ds[0][0] * 1.4 + 0.05]
        ws = [1 / max(d, 1e-3) ** 4 for d, _ in near]
        for (d, name), w in zip(near, ws):
            group = body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
            group.add([v.index], w / sum(ws), "REPLACE")


def rotate(pb, axis, deg):
    """Rotate a posed bone about a world axis through its head, on top of its current pose."""
    current = pb.matrix.copy()
    pivot = current.translation.copy()
    r = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-pivot)
    pb.matrix = r @ current
    bpy.context.view_layer.update()


def apply_pose(entry, pose):
    rig = entry["rig"]
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    if pose != "bind":
        # arms down to the sides: from the body's own arm direction to hanging, slightly out
        for side, s in (("L", 1), ("R", -1)):
            pb = rig.pose.bones[f"UpperArm.{side}"]
            rest_dir = (pb.bone.tail_local - pb.bone.head_local).normalized()
            hang = Vector((s * 0.12, 0, -1)).normalized()
            q = rest_dir.rotation_difference(hang)
            pivot = pb.matrix.translation.copy()
            pb.matrix = Matrix.Translation(pivot) @ q.to_matrix().to_4x4() @ Matrix.Translation(-pivot) @ pb.matrix
            bpy.context.view_layer.update()
    for name, axis, deg in POSES[pose]:
        rotate(rig.pose.bones[name], axis, deg)


# The game's AssaultRifle is 4.73 studs long, 1.05 tall and 0.19 wide (assets/weapons/tools). The
# reference rifle is boxes of that size: grip at the right hand, barrel forward, stock behind.
RIFLE = {"front": [((0, 0.7, 0.25), (0.2, 1.4, 0.55)), ((0, 2.35, 0.3), (0.12, 1.9, 0.14))],
         "stock": [((0, -0.7, 0.2), (0.18, 1.4, 0.45))]}
WEAPON_POSES = {"idle", "walk", "run", "crouch", "aim", "jump"}
# With a gun held the Weapons Kit's shoulder camera owns the view (tools/wsrc/Libraries_ShoulderCamera.lua):
# from the HumanoidRootPart, 2.25 studs to the character's right, 2.25 up, 10.5 back, FOV 70.
# The R15 root part's centre stands about 3 studs above the feet.
CAMERA = {"right": 2.25, "up": 2.25, "back": 10.5, "fov": 70, "rootHeight": 3.0}
GRIP_CLEAR = 0.8  # body faces this close to the grip are the hand holding it, not clipping


def box_mesh(name, boxes):
    verts, faces = [], []
    for (cx, cy, cz), (sx, sy, sz) in boxes:
        base = len(verts)
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    verts.append((cx + dx * sx, cy + dy * sy, cz + dz * sz))
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            faces.append(tuple(base + i for i in q))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new(name + "Mat")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.55, 0.1, 1)
    me.materials.append(mat)
    return obj


def world_bvh(obj, depsgraph, centres=False):
    from mathutils.bvhtree import BVHTree

    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    verts = [obj.matrix_world @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    tree = BVHTree.FromPolygons(verts, polys)
    if centres:
        return tree, [sum((verts[i] for i in p), Vector()) / len(p) for p in polys]
    return tree


def place_rifle(entry):
    rig = entry["rig"]
    pb = rig.pose.bones["Hand.R"]
    grip = rig.matrix_world @ ((pb.head + pb.tail) / 2)
    for part in entry["rifle"].values():
        part.location = grip
        part.hide_render = False

# ------------------------------------------------------------------ run
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 12
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.64, 0.68, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-25))
scene.collection.objects.link(sun)

GAP = 9.0
entries = [build(f, i * GAP) for i, f in enumerate(folders)]
for e in entries:
    e["rifle"] = {k: box_mesh(f"Rifle-{k}-{e['name']}", v) for k, v in RIFLE.items()}
    e["parts"] = e["parts"] + list(e["rifle"].values())
depsgraph = bpy.context.evaluated_depsgraph_get()
for e in entries:
    apply_pose(e, "bind")
depsgraph.update()
rest = {e["name"]: tri_areas(e["body"], depsgraph) for e in entries}
# stretch is measured against the bind pose, so "idle" shows what lowering the arms costs

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 8.5
cam.data.clip_start = 0.1
cam.data.clip_end = 200
scene.render.resolution_x, scene.render.resolution_y = 520, 620

report = {e["name"]: {"weights": e["method"], "unweightedByHeat": e["unweighted"], "vertices": len(e["body"].data.vertices), "poses": {}} for e in entries}
tiles = []
for pose in POSES:
    for e in entries:
        apply_pose(e, pose)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    for e in entries:
        now = tri_areas(e["body"], depsgraph)
        base = rest[e["name"]]
        stretched = sum(1 for a, b in zip(now, base) if b > 1e-9 and a / b > 2.0)
        crushed = sum(1 for a, b in zip(now, base) if b > 1e-9 and a / b < 0.35)
        report[e["name"]]["poses"][pose] = {"stretchedOver2x": round(stretched / len(base), 4),
                                            "crushedUnder035": round(crushed / len(base), 4)}
        for other in entries:
            for part in other["parts"]:
                part.hide_render = other is not e
        if pose in WEAPON_POSES:
            # the rifle held at the right hand, pointing forward: where does it pass through the body?
            place_rifle(e)
            bpy.context.view_layer.update()
            body_tree, centres = world_bvh(e["body"], depsgraph, centres=True)
            pb = e["rig"].pose.bones["Hand.R"]
            grip = e["rig"].matrix_world @ ((pb.head + pb.tail) / 2)
            clip = {}
            for k, o in e["rifle"].items():
                hits = {i for i, _ in body_tree.overlap(world_bvh(o, depsgraph))}
                clip[k] = sum(1 for i in hits if (centres[i] - grip).length > GRIP_CLEAR)
            report[e["name"]]["poses"][pose]["rifleThroughBody"] = clip
        else:
            for part in e["rifle"].values():
                part.hide_render = True
        for view in ("front", "side"):
            fs = e["frontSign"]
            x0 = e["rig"].location.x
            if view == "front":
                cam.location = (x0, fs * 30, 3.0)
                cam.rotation_euler = (math.radians(90), 0, math.radians(180 if fs > 0 else 0))
            else:
                cam.location = (x0 + 30, 0, 3.0)
                cam.rotation_euler = (math.radians(90), 0, math.radians(90))
            path = os.path.join(out_dir, f"{e['name']}-{pose}-{view}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            tiles.append((e["name"], pose, view, path))

# The player's own view: the game camera behind the character, for idle and aim with the rifle.
# A collar, hair spike or shoulder plate over the screen centre blocks the crosshair.
cam.data.type = "PERSP"
cam.data.sensor_fit = "VERTICAL"
cam.data.angle_y = math.radians(CAMERA["fov"])
scene.render.resolution_x, scene.render.resolution_y = 960, 540
scene.render.film_transparent = True
for pose in ("idle", "aim"):
    for e in entries:
        apply_pose(e, pose)
    bpy.context.view_layer.update()
    for e in entries:
        for other in entries:
            for part in other["parts"]:
                part.hide_render = other is not e
        place_rifle(e)
        x0 = e["rig"].location.x
        # front is +Y and the character's left is +X, so its right is -X
        cam.location = (x0 - CAMERA["right"], -CAMERA["back"], CAMERA["rootHeight"] + CAMERA["up"])
        cam.rotation_euler = (math.radians(90), 0, 0)
        path = os.path.join(out_dir, f"{e['name']}-{pose}-camera.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        w, h = img.size
        px = img.pixels[:]
        r = int(h * 0.03)
        cover = [px[((y * w) + x) * 4 + 3] for y in range(h // 2 - r, h // 2 + r) for x in range(w // 2 - r, w // 2 + r)]
        report[e["name"]]["poses"][pose]["crosshairCovered"] = round(sum(1 for a in cover if a > 0.5) / len(cover), 3)
        bpy.data.images.remove(img)
        tiles.append((e["name"], pose, "camera", path))
scene.render.film_transparent = False

with open(os.path.join(out_dir, "pose-matrix.json"), "w") as f:
    json.dump({"poses": list(POSES), "bodies": report, "tiles": tiles}, f, indent=1)
print("POSEMATRIX", json.dumps(report))
