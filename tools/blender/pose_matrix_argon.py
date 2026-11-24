"""Pose matrix and gameplay readability check for the Tripo Argon pipeline.

    blender -b -noaudio --python tools/blender/pose_matrix_argon.py -- <folder> [<folder> ...] --out <dir>

Duplicates pose_matrix.py for the Tripo Argon pipeline with four improvements:
1. Hand-rotated rifle proxy (`place_rifle(entry, pose)`): in `aim`, the rifle aims straight forward;
   in `idle`, `walk`, `run`, `crouch` and `jump`, the rifle rotates with `Hand.R` (carried along the
   hand/forearm angle instead of floating horizontally along world +Y through the thighs in crouch).
2. Cross-leg heat-weight isolation below the crotch: vertices on the left side (`x > 0.02`) below
   the hip cannot receive weight from Right leg bones (and vice versa), preventing long coat tails
   from stretching across the stride.
3. Loads `BodyNormal.png` and `BodyRoughness.png` when present so renders show the full PBR surface.
4. Renders Red vs Blue team-readability tiles and 50-stud distant bright/dark backdrop tiles.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir = os.path.abspath(argv[argv.index("--out") + 1])
folders = [a for a in argv[: argv.index("--out")]]
os.makedirs(out_dir, exist_ok=True)

R15 = {"ankle": 0.3, "knee": 1.5, "hip": 2.7, "waist": 3.1, "neck": 4.7}
SHOULDER = 4.55

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
               ("Foot" + R, "X", 30), ("UpperArm" + R, "X", 45), ("LowerArm" + R, "X", 35)],
    "aim": [("Head", "Z", 20), ("UpperArm" + R, "X", 85), ("UpperArm" + L, "X", 70), ("UpperArm" + L, "Z", -25),
            ("LowerArm" + L, "X", 30)],
    "jump": [("UpperLeg" + L, "X", 70), ("LowerLeg" + L, "X", -100), ("UpperLeg" + R, "X", 20),
             ("LowerLeg" + R, "X", -60), ("UpperArm" + L, "Y", -120), ("UpperArm" + R, "Y", 120)],
    "headturn": [("UpperTorso", "Z", -15), ("Head", "Z", 50)],
}


def load(path, folder=None, part_name=None):
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
    if folder and part_name and obj.data.materials:
        tree = obj.data.materials[0].node_tree
        bsdf = tree.nodes.get("Principled BSDF") if tree else None
        n_path = os.path.join(folder, f"{part_name}Normal.png")
        r_path = os.path.join(folder, f"{part_name}Roughness.png")
        e_path = os.path.join(folder, f"{part_name}Emission.png")
        if bsdf and os.path.exists(n_path):
            nh = tree.nodes.new("ShaderNodeTexImage")
            nh.image = bpy.data.images.load(n_path)
            nh.image.colorspace_settings.name = "Non-Color"
            nm = tree.nodes.new("ShaderNodeNormalMap")
            nm.inputs["Strength"].default_value = 0.85
            tree.links.new(nh.outputs["Color"], nm.inputs["Color"])
            tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        if bsdf and os.path.exists(r_path):
            rh = tree.nodes.new("ShaderNodeTexImage")
            rh.image = bpy.data.images.load(r_path)
            rh.image.colorspace_settings.name = "Non-Color"
            tree.links.new(rh.outputs["Color"], bsdf.inputs["Roughness"])
        if bsdf and os.path.exists(e_path):
            eh = tree.nodes.new("ShaderNodeTexImage")
            eh.image = bpy.data.images.load(e_path)
            tree.links.new(eh.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 4.5
    return obj


def tri_areas(obj, depsgraph):
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    areas = [t.area for t in me.loop_triangles]
    ev.to_mesh_clear()
    return areas


def clean_cross_leg_weights(body):
    """Ensure vertices on the left leg/skirt (x > 0.02, z < R15['hip'] - 0.08) do not carry
    weights from Right leg bones, and vice versa. Prevents coat tails from stretching across the stride."""
    g_names = {g.index: g.name for g in body.vertex_groups}
    name_to_g = {g.name: g for g in body.vertex_groups}
    leg_stems = ("UpperLeg", "LowerLeg", "Foot")
    cleaned = 0
    for v in body.data.vertices:
        if v.co.z >= R15["hip"] - 0.08 or abs(v.co.x) < 0.015:
            continue
        wrong_suffix = ".R" if v.co.x > 0 else ".L"
        right_suffix = ".L" if v.co.x > 0 else ".R"
        transfers = []
        for ge in v.groups:
            gn = g_names.get(ge.group, "")
            for stem in leg_stems:
                if gn == stem + wrong_suffix and ge.weight > 1e-4:
                    transfers.append((gn, stem + right_suffix, ge.weight))
        if transfers:
            cleaned += 1
            for old_n, new_n, w in transfers:
                name_to_g[old_n].remove([v.index])
                target_g = name_to_g.get(new_n) or body.vertex_groups.new(name=new_n)
                name_to_g[new_n] = target_g
                # add to existing weight on target_g
                cur = 0.0
                for ge in v.groups:
                    if ge.group == target_g.index:
                        cur = ge.weight
                        break
                target_g.add([v.index], min(1.0, cur + w), "REPLACE")
    return cleaned


def build(folder, offset_x):
    spec = json.load(open(os.path.join(folder, "prepare-spec.json")))
    m = spec["marks"]
    scale = R15["neck"] / m["neck"]
    swing = math.radians(spec.get("swing", 20))
    body = load(os.path.join(folder, "Body.glb"), folder=folder, part_name="Body")
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.to_mesh(body.data)
    bm.free()
    vs = [body.matrix_world @ v.co for v in body.data.vertices]
    knee_band = [v for v in vs if R15["ankle"] < v.z < R15["knee"]]
    leg_x = sum(abs(v.x) for v in knee_band) / max(1, len(knee_band))
    front_sign = 1

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
    model_h = max(m["neck"] / 0.68, 0.7)
    safe_arm_inner = max(m.get("armInner", 0), 0.12 * model_h)
    safe_sh_x = max(m["shoulder"][0], safe_arm_inner + 0.015 * model_h)
    sx = safe_sh_x * scale
    for side, s in (("L", 1), ("R", -1)):
        d = Vector(((m["wrist"][0] - safe_sh_x) * s, 0, m["wrist"][1] - m["shoulder"][1])).normalized()
        d = Matrix.Rotation(-s * swing, 3, "Y") @ d
        sh = Vector((s * sx, 0, SHOULDER))
        upper = max(0.45, (Vector((m["elbow"][0], 0, m["elbow"][1])) - Vector((safe_sh_x, 0, m["shoulder"][1]))).length * scale)
        lower = max(0.45, (Vector((m["wrist"][0], 0, m["wrist"][1])) - Vector((m["elbow"][0], 0, m["elbow"][1]))).length * scale)
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
    unweighted = sum(1 for v in body.data.vertices if not v.groups)
    method = "heat"
    if unweighted > len(body.data.vertices) * 0.05:
        for g in list(body.vertex_groups):
            body.vertex_groups.remove(g)
        nearest_bone_weights(body, rig)
        method = "nearest bone (heat weighting found no solution)"
    cross_cleaned = clean_cross_leg_weights(body)

    parts = [body]
    for acc in ("Hair", "Headgear"):
        p = os.path.join(folder, f"{acc}.glb")
        if os.path.exists(p):
            a = load(p, folder=folder, part_name=acc)
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
            "swing": swing, "unweighted": unweighted, "method": method, "crossLegVerticesCleaned": cross_cleaned,
            "frontSign": front_sign, "dir": spec}


def nearest_bone_weights(body, rig):
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


RIFLE = {"front": [((0, 0.7, 0.25), (0.2, 1.4, 0.55)), ((0, 2.35, 0.3), (0.12, 1.9, 0.14))],
         "stock": [((0, -0.7, 0.2), (0.18, 1.4, 0.45))]}
WEAPON_POSES = {"idle", "walk", "run", "crouch", "aim", "jump"}
CAMERA = {"right": 2.25, "up": 2.25, "back": 10.5, "fov": 70, "rootHeight": 3.0}
GRIP_CLEAR = 0.85


def box_mesh(name, boxes, color=(0.9, 0.55, 0.1, 1)):
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
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
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


def place_rifle(entry, pose="aim"):
    """Orient the rifle with Hand.R instead of leaving it world-aligned along +Y in non-aim poses."""
    rig = entry["rig"]
    pb = rig.pose.bones["Hand.R"]
    grip = rig.matrix_world @ ((pb.head + pb.tail) / 2)
    hand_dir = (pb.tail - pb.head).normalized()
    if pose == "aim":
        # Aiming down sights: barrel points straight forward (+Y)
        rot = Euler((0.0, 0.0, 0.0), "XYZ")
    else:
        # Low-ready / carry: barrel aligns with the forearm/hand forward swing and tilts slightly
        # outward (-X, away from the right thigh) so a hanging hand carries the rifle naturally.
        forward = Vector((-0.18, max(0.35, hand_dir.y + 0.45), min(-0.25, hand_dir.z * 0.55))).normalized()
        q = Vector((0.0, 1.0, 0.0)).rotation_difference(forward)
        rot = q.to_euler("XYZ")
    for part in entry["rifle"].values():
        part.location = grip
        part.rotation_euler = rot
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

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 8.5
cam.data.clip_start = 0.1
cam.data.clip_end = 200
scene.render.resolution_x, scene.render.resolution_y = 520, 620

report = {e["name"]: {"weights": e["method"], "unweightedByHeat": e["unweighted"],
                      "crossLegVerticesCleaned": e["crossLegVerticesCleaned"],
                      "vertices": len(e["body"].data.vertices), "poses": {}} for e in entries}
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
            place_rifle(e, pose)
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

# Shoulder camera views (idle and aim)
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
        place_rifle(e, pose)
        x0 = e["rig"].location.x
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

# Argon team-color & 50-stud distant silhouette readability checks
scene.render.resolution_x, scene.render.resolution_y = 420, 520
for e in entries:
    apply_pose(e, "idle")
    place_rifle(e, "idle")
    bpy.context.view_layer.update()
    for other in entries:
        for part in other["parts"]:
            part.hide_render = other is not e
    x0 = e["rig"].location.x
    # Add temporary team armband rings on UpperArm.L/R for Red vs Blue readability
    pb_l = e["rig"].pose.bones["UpperArm.L"]
    pb_r = e["rig"].pose.bones["UpperArm.R"]
    pos_l = e["rig"].matrix_world @ ((pb_l.head * 0.6 + pb_l.tail * 0.4))
    pos_r = e["rig"].matrix_world @ ((pb_r.head * 0.6 + pb_r.tail * 0.4))
    bands = [box_mesh("TeamBandL", [((pos_l.x, pos_l.y, pos_l.z), (0.85, 0.85, 0.24))]),
             box_mesh("TeamBandR", [((pos_r.x, pos_r.y, pos_r.z), (0.85, 0.85, 0.24))])]
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 8.2
    cam.location = (x0, 30, 3.1)
    cam.rotation_euler = (math.radians(90), 0, math.radians(180))
    for team_name, rgba in (("team-red", (0.92, 0.16, 0.16, 1)), ("team-blue", (0.16, 0.45, 0.95, 1))):
        for b in bands:
            b.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.22, 0.25, 0.30, 1)
        path = os.path.join(out_dir, f"{e['name']}-{team_name}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append((e["name"], team_name, "front", path))
    for b in bands:
        bpy.data.objects.remove(b)

    # 50-stud distant silhouette check (dark night map vs bright day map)
    cam.data.type = "PERSP"
    cam.data.angle_y = math.radians(35)  # zoom crop of 50-stud combat distance
    cam.location = (x0, 28, 3.2)
    cam.rotation_euler = (math.radians(90), 0, math.radians(180))
    for env_name, bg, sun_e in (("50stud-dark", (0.06, 0.07, 0.11, 1), 1.4),
                                ("50stud-bright", (0.76, 0.80, 0.86, 1), 3.0)):
        world.node_tree.nodes["Background"].inputs[0].default_value = bg
        sun.data.energy = sun_e
        path = os.path.join(out_dir, f"{e['name']}-{env_name}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        tiles.append((e["name"], env_name, "front", path))
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.64, 0.68, 1)
    sun.data.energy = 2.5

with open(os.path.join(out_dir, "pose-matrix.json"), "w") as f:
    json.dump({"poses": list(POSES), "bodies": report, "tiles": tiles, "pipeline": "tripo-argon"}, f, indent=1)
print("POSEMATRIX_ARGON", json.dumps(report))
