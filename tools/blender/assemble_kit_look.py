"""Put a kit's generated pieces on a blocky R15 body and render the review views.

    blender -b -noaudio --python tools/blender/assemble_kit_look.py -- <scene.json>

Run by `python tools/kit_look.py review`, which writes scene.json: the output folder, the
body colour, and each piece with its body part, box, turn and mirror flag. Writes
front/quarter/side/back/head/pose/dark .png and report.json (triangles per piece) there.

Each piece is scaled to fit its box (keeping its proportions), centred in it, and hung
from its body part's joint, so the walking pose shows whether it follows the limb.
Blender axes: Z up, the character faces -Y, its left is +X. 1 unit = 1 stud.
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

scene_file = Path(sys.argv[sys.argv.index("--") + 1])
spec = json.loads(scene_file.read_text(encoding="utf-8"))
OUT = Path(spec["out"])

BODY = {
    "Head": ((0, 0, 5.3), (1.2, 1.2, 1.2)),
    "UpperTorso": ((0, 0, 3.9), (2, 1, 1.6)),
    "LowerTorso": ((0, 0, 2.9), (2, 1, 0.4)),
    "RightUpperArm": ((-1.5, 0, 4.1), (1, 1, 1.2)),
    "LeftUpperArm": ((1.5, 0, 4.1), (1, 1, 1.2)),
    "RightLowerArm": ((-1.5, 0, 2.95), (1, 1, 1.1)),
    "LeftLowerArm": ((1.5, 0, 2.95), (1, 1, 1.1)),
    "RightHand": ((-1.5, 0, 2.15), (1, 1, 0.5)),
    "LeftHand": ((1.5, 0, 2.15), (1, 1, 0.5)),
    "RightUpperLeg": ((-0.5, 0, 2.1), (1, 1, 1.2)),
    "LeftUpperLeg": ((0.5, 0, 2.1), (1, 1, 1.2)),
    "RightLowerLeg": ((-0.5, 0, 0.9), (1, 1, 1.2)),
    "LeftLowerLeg": ((0.5, 0, 0.9), (1, 1, 1.2)),
    "RightFoot": ((-0.5, -0.1, 0.15), (1, 1.2, 0.3)),
    "LeftFoot": ((0.5, -0.1, 0.15), (1, 1.2, 0.3)),
}
JOINTS = {  # part: (pivot, parent)
    "LowerTorso": ((0, 0, 2.9), None),
    "UpperTorso": ((0, 0, 3.1), "LowerTorso"),
    "Head": ((0, 0, 4.7), "UpperTorso"),
    "RightUpperArm": ((-1.5, 0, 4.55), "UpperTorso"),
    "LeftUpperArm": ((1.5, 0, 4.55), "UpperTorso"),
    "RightLowerArm": ((-1.5, 0, 3.5), "RightUpperArm"),
    "LeftLowerArm": ((1.5, 0, 3.5), "LeftUpperArm"),
    "RightHand": ((-1.5, 0, 2.4), "RightLowerArm"),
    "LeftHand": ((1.5, 0, 2.4), "LeftLowerArm"),
    "RightUpperLeg": ((-0.5, 0, 2.7), "LowerTorso"),
    "LeftUpperLeg": ((0.5, 0, 2.7), "LowerTorso"),
    "RightLowerLeg": ((-0.5, 0, 1.5), "RightUpperLeg"),
    "LeftLowerLeg": ((0.5, 0, 1.5), "LeftUpperLeg"),
    "RightFoot": ((-0.5, 0, 0.3), "RightLowerLeg"),
    "LeftFoot": ((0.5, 0, 0.3), "LeftLowerLeg"),
}


def linear(hex_colour):
    channels = (int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)


def flat(name, colour, roughness=0.6):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*linear(colour), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

pivots = {}
for name, (joint, _) in JOINTS.items():
    pivot = bpy.data.objects.new("Pivot_" + name, None)
    scene.collection.objects.link(pivot)
    pivots[name] = pivot
for name, (joint, parent) in JOINTS.items():
    if parent:
        pivots[name].parent = pivots[parent]
        pivots[name].location = Vector(joint) - Vector(JOINTS[parent][0])
    else:
        pivots[name].location = joint


def attach(obj, part):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = pivots[part]
    obj.matrix_world = world


body_mat = flat("body", spec["bodyColor"])
bodies = {}
for name, (centre, size) in BODY.items():
    bpy.ops.mesh.primitive_cube_add(location=centre)
    obj = bpy.context.object
    obj.name = "Body_" + name
    obj.dimensions = [v - 0.04 for v in size]  # a hairline gap, so bare limbs read as limbs
    obj.data.materials.append(body_mat)
    attach(obj, name)
    bodies[name] = obj


LIMB_OVERRUN = 1.3
LIMB_WIDEN = 1.8


def stand_upright(obj, flip):
    """Rotate a limb piece so its long axis is vertical. Pictures of a forearm or shin are
    often drawn diagonally, and Tripo keeps the picture's angle. `flip` turns it upside down
    when the long axis came out the wrong way round."""
    import numpy as np

    count = len(obj.data.vertices)
    points = np.empty(count * 3)
    obj.data.vertices.foreach_get("co", points)
    points = points.reshape(-1, 3)
    points -= points.mean(axis=0)
    _, vectors = np.linalg.eigh(np.cov(points.T))
    axis = Vector(vectors[:, -1])  # the direction it is longest in
    if axis.z < 0:
        axis = -axis  # keep whichever end was already nearer the top
    rotation = axis.rotation_difference(Vector((0, 0, 1)))
    obj.data.transform(rotation.to_matrix().to_4x4())
    if flip:
        obj.data.transform(Matrix.Rotation(math.pi, 4, "X"))
    obj.data.update()


def trim_top(obj, keep):
    """Keep only the bottom `keep` fraction of a piece's height. A boot Midjourney drew
    calf-high is cut down to the ankle; the shin piece covers the cut."""
    import bmesh

    zs = [v.co.z for v in obj.data.vertices]
    cut = min(zs) + (max(zs) - min(zs)) * keep
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, 0, cut), plane_no=(0, 0, 1), clear_outer=True)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def keep_back_half(obj):
    """A cloak drawn all the way round would cover the chest armour; keep the half behind."""
    import bmesh

    ys = [v.co.y for v in obj.data.vertices]
    middle = (min(ys) + max(ys)) / 2
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                           plane_co=(0, middle, 0), plane_no=(0, 1, 0), clear_inner=True)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def import_fitted(path, turn, centre, box, mirror, upright=False, flip=False, trim=None, footprint=False,
                  cape=False, fill_width=None, fill_height=None, asis=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.context.view_layer.update()
    for o in meshes:  # keep each mesh where the file put it, then drop the file's empties
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if asis:  # already cut and placed on the R15 rest pose (tools/blender/split_whole_body.py)
        return obj
    if upright:
        stand_upright(obj, flip)
    elif flip:
        obj.data.transform(Matrix.Rotation(math.pi, 4, "X"))
    if trim:
        trim_top(obj, trim)
    obj.rotation_mode = "XYZ"  # the glTF importer leaves quaternions, which ignore rotation_euler
    obj.rotation_euler = (0, 0, math.radians(turn))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if cape:
        keep_back_half(obj)
    # Measure the vertices themselves: bound_box goes stale after a bmesh cut (a halved
    # cloak was placed by its uncut size and hung 1.2 studs too far back).
    points = [v.co for v in obj.data.vertices]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    size = [max(high[i] - low[i], 1e-6) for i in range(3)]
    if cape:
        # Fit the cape's width and length; its depth is whatever the cloth needs.
        scale = min(box[0] / size[0], box[2] / size[2])
    elif footprint:
        # A boot covers the foot: fit its length and width; any height left after the trim
        # rises under the shin piece.
        scale = min(box[0] / size[0], box[1] / size[1])
    elif upright:
        # A limb guard replaces the limb (see `covers`): fit its width, and let it run a little
        # past the body part's length (armour overlaps at elbows and knees), at most
        # LIMB_OVERRUN times the box. Uncapped, the knight's forearm guard reached the shoulder.
        scale = min(box[0] / size[0], box[1] / size[1], box[2] * LIMB_OVERRUN / size[2])
        # A long, thin drawing (the knight's shin guard came out 0.58 studs wide on a 1-stud
        # leg) is widened toward the box, up to LIMB_WIDEN times: chunky reads as BedWars.
        widen = min(LIMB_WIDEN, max(1.0, box[0] * 0.9 / (size[0] * scale), box[1] * 0.9 / (size[1] * scale)))
    else:
        scale = min(box[i] / size[i] for i in range(3))
    flip = -1 if mirror else 1
    if not upright:
        widen = 1.0
    # `fillWidth` stretches a piece sideways to that width: the knight's breastplate was fitted by
    # its height and came out narrower than the shoulders, leaving a gap beside the chest.
    wide = max(1.0, fill_width / (size[0] * scale * widen)) if fill_width else 1.0
    # `fillHeight` does the same downward: the Bouncer's vest was fitted by its depth and stopped
    # above the belt, leaving a band of bare body at the waist.
    tall = max(1.0, fill_height / (size[2] * scale)) if fill_height else 1.0
    obj.scale = (flip * scale * widen * wide, scale * widen, scale * tall)
    obj.location = Vector(centre) - Vector((flip * widen * wide, widen, tall)) * scale * ((low + high) / 2)
    if cape:  # front edge on the back of the box (behind the chest piece), top at the shoulders
        obj.location.y += (size[1] * scale - box[1]) / 2
        obj.location.z += (box[2] - size[2] * scale) / 2
    if footprint:  # stand on the sole, not on the box's middle: extra height goes up the shin
        obj.location.z += (size[2] * scale - box[2]) / 2
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mirror:  # a negative scale turns the faces inside out
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
    return obj


triangles = {}
for piece in spec["pieces"]:
    # A mirrored slot is drawn as the left; `handed: right` says the drawing is a right-hand piece
    # (the knight's fist), so the left gets the mirror image instead and thumbs end up in front.
    swap = piece.get("handed") == "right"
    jobs = [(piece["part"], piece["centre"], swap)]
    if piece.get("mirror"):
        c = piece["centre"]
        jobs.append((piece["part"].replace("Left", "Right"), [-c[0], c[1], c[2]], not swap))
    for part, centre, mirror in jobs:
        obj = import_fitted(piece["file"], piece["turn"], centre, piece["box"], mirror,
                            piece.get("upright", False), piece.get("flip", False), piece.get("trim"),
                            piece.get("fit") == "footprint", piece.get("fit") == "cape", piece.get("fillWidth"),
                            piece.get("fillHeight"), piece.get("fit") == "asis")
        obj.name = f"{part}__{piece['name']}"
        triangles[piece["name"]] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        attach(obj, part)
        if piece.get("covers"):  # the piece is the body part now; in game the part goes transparent
            bodies[part].hide_render = True

# Glows: small emissive plates over painted lights (the helmet's eyes). Roblox cannot make a
# texture glow, so in game each is a Neon part; here an emission material stands in for it.
glows = []
# `turn` (degrees about the vertical) lets a slat follow a curved visor; a turn of t here is a
# turn of t about Roblox's Y (Blender x, y, z is Roblox -x, z, y). `color: "team"` is the
# player's team colour in game (KitLookService) and `teamPreview` here; a team band is plain
# paint (`neon: false`), a glow is Neon.
for i, glow in enumerate(spec.get("glows", [])):
    bpy.ops.mesh.primitive_cube_add(location=glow["centre"])
    obj = bpy.context.object
    obj.name = f"Glow_{i}"
    obj.dimensions = glow["size"]
    obj.rotation_euler = (0, 0, math.radians(glow.get("turn", 0)))
    colour = spec.get("teamPreview", "#C83C3C") if glow["color"] == "team" else glow["color"]
    mat = bpy.data.materials.new(f"glow_{i}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*linear(colour), 1)
    if glow.get("neon", True):
        bsdf.inputs["Emission Color"].default_value = (*linear(colour), 1)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    obj.data.materials.append(mat)
    attach(obj, glow["part"])
    offset = Vector(glow["centre"]) - Vector(BODY[glow["part"]][0])
    size = glow["size"]
    glows.append({"part": glow["part"], "color": glow["color"],
                  "offset": [round(-offset.x, 4), round(offset.z, 4), round(offset.y, 4)],
                  "size": [size[0], size[2], size[1]], "turn": glow.get("turn", 0),
                  "neon": glow.get("neon", True)})

# A sleeve stands in for a hidden part a piece does not wrap (see `sleeve` in kit_look.py).
sleeves = []
for piece in spec["pieces"]:
    sleeve = piece.get("sleeve")
    if not sleeve:
        continue
    parts = [piece["part"]] + ([piece["part"].replace("Left", "Right")] if piece.get("mirror") else [])
    for part in parts:
        centre = Vector(BODY[part][0]) - Vector((0, 0, sleeve["drop"]))
        bpy.ops.mesh.primitive_cube_add(location=centre)
        obj = bpy.context.object
        obj.name = "Sleeve_" + part
        obj.dimensions = sleeve["size"]
        obj.data.materials.append(body_mat)
        attach(obj, part)
        size = sleeve["size"]
        sleeves.append({"part": part, "offset": [0, -sleeve["drop"], 0], "size": [size[0], size[2], size[1]]})

# Gaps: sky showing through the torso and arms. The knight's first review sheets looked fine and
# the gap between chest and shoulder plates was only seen in Studio, so it is measured here.
# Rays go straight through the character from the front and from behind, over the shoulder-to-
# waist band where blocky R15 arms touch the torso; on each row, a ray that misses between the
# first and last hit is a hole. Only what renders counts: hidden body parts are not hit.
GAP_STEP = 0.02


def gap_scan():
    bpy.context.view_layer.update()
    solid = [o for o in bpy.data.objects if o.type == "MESH" and not o.hide_render]
    inverse = {o: o.matrix_world.inverted() for o in solid}
    lowest = BODY["UpperTorso"][0][2] - BODY["UpperTorso"][1][2] / 2 + 0.2
    highest = BODY["LeftUpperArm"][0][2] + BODY["LeftUpperArm"][1][2] / 2 - 0.1
    found = {}
    for side, (y, direction) in {"front": (-8, Vector((0, 1, 0))), "back": (8, Vector((0, -1, 0)))}.items():
        holes = []
        z = lowest
        while z <= highest:
            row = []
            x = -2.6
            while x <= 2.6:
                start = Vector((x, y, z))
                hit = False
                for obj in solid:
                    local = inverse[obj]
                    ok, *_ = obj.ray_cast(local @ start, (local.to_3x3() @ direction).normalized())
                    if ok:
                        hit = True
                        break
                row.append((x, hit))
                x += GAP_STEP
            hits = [i for i, (_, h) in enumerate(row) if h]
            if hits:
                holes += [[round(row[i][0], 2), round(z, 2)] for i in range(hits[0], hits[-1]) if not row[i][1]]
            z += GAP_STEP
        found[side] = {"area": round(len(holes) * GAP_STEP * GAP_STEP, 3), "holes": holes[:400]}
    return found


gaps = {} if spec.get("export") else gap_scan()
for side, gap in gaps.items():
    print("GAPS", side, gap["area"], "sq studs")

OUT.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "assembled.blend"))
(OUT / "report.json").write_text(json.dumps({"triangles": triangles, "gaps": gaps}, indent=2), encoding="utf-8")

# ------------------------------------------------------------------ game export
# With "export" in the scene: write every fitted piece, in the rest pose, into one GLB for
# upload, plus where each sits relative to its body part. Then stop (no renders).
if spec.get("export"):
    bpy.context.view_layer.update()
    pieces = [o for o in bpy.data.objects if "__" in o.name and o.type == "MESH"]
    manifest = []
    bpy.ops.object.select_all(action="DESELECT")
    for obj in pieces:
        part, piece_name = obj.name.split("__", 1)
        # Roblox names an imported MeshPart after the glTF *mesh*, not the object; Tripo's mesh
        # names (tripo_mesh_<uuid>) left every piece unfindable in game. Give each its own name.
        obj.data.name = obj.name
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        middle = Vector([(min(p[i] for p in points) + max(p[i] for p in points)) / 2 for i in range(3)])
        size = [max(p[i] for p in points) - min(p[i] for p in points) for i in range(3)]
        # Blender (x, y, z) is Roblox (-x, z, y): Z up, the character faces -Y here and -Z there.
        offset = middle - Vector(BODY[part][0])
        manifest.append({
            "mesh": obj.name, "part": part, "piece": piece_name,
            "offset": [round(-offset.x, 4), round(offset.z, 4), round(offset.y, 4)],
            "size": [round(size[0], 4), round(size[2], 4), round(size[1], 4)],
            "covers": bodies[part].hide_render,
            "triangles": sum(len(f.vertices) - 2 for f in obj.data.polygons),
        })
    hidden = sorted({m["part"] for m in manifest if m["covers"]})
    bpy.ops.export_scene.gltf(filepath=spec["export"], export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True)
    Path(spec["export"]).with_suffix(".json").write_text(json.dumps({
        "pieces": sorted(manifest, key=lambda m: m["mesh"]),
        "hides": hidden,
        "sleeves": sleeves,
        "glows": glows,
        "template": {name: {"centre": c, "size": s} for name, (c, s) in BODY.items()},
    }, indent=2), encoding="utf-8")
    print("EXPORTED", spec["export"], len(manifest), "pieces")
    sys.exit(0)

# ------------------------------------------------------------------ lights and views
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
background = world.node_tree.nodes["Background"]
bpy.ops.mesh.primitive_plane_add(size=60)
floor = bpy.context.object
floor_mat = flat("floor", "#D9DCE0", 0.8)
floor.data.materials.append(floor_mat)


def light(name, location, energy, size, colour=(1, 1, 1), target=(0, 0, 3)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.color = energy, size, colour
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)
    return obj


studio = [light("key", (-6, -8, 9), 1400, 6), light("fill", (8, -6, 5), 500, 6), light("rim", (2, 9, 7), 700, 5)]
# Kit-screen look: soft front light, strong coloured rims from behind on both sides.
dark = [light("dkey", (-3, -10, 6), 600, 8), light("drimL", (-6, 5, 6), 2200, 3, (1.0, 0.6, 0.35)),
        light("drimR", (6, 5, 6), 2200, 3, (0.45, 0.6, 1.0)), light("dtop", (0, 2, 12), 400, 4)]

cam_data = bpy.data.cameras.new("cam")
cam_data.clip_start, cam_data.clip_end = 0.1, 300
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 1100
scene.view_settings.view_transform = "Standard"

POSE = {
    "RightUpperArm": (-70, 0, -10), "RightLowerArm": (-60, 0, 0),
    "LeftUpperArm": (35, 0, 15), "LeftLowerArm": (-45, 0, 0),
    "RightUpperLeg": (-40, 0, 0), "RightLowerLeg": (55, 0, 0),
    "LeftUpperLeg": (25, 0, 0), "LeftLowerLeg": (20, 0, 0),
    "Head": (0, 0, 20), "UpperTorso": (0, 0, -12),
}
VIEWS = {  # name: (camera, target, lens, posed, dark)
    "front": ((0, -16, 3.6), (0, 0, 3.3), 50, False, False),
    "quarter": ((-9.5, -11.5, 5.4), (0, 0, 3.3), 50, False, False),
    "side": ((16, 0, 3.6), (0, 0, 3.3), 50, False, False),
    "back": ((0, 16, 3.6), (0, 0, 3.3), 50, False, False),
    "head": ((-2.6, -5.2, 6.4), (0, 0, 5.5), 50, False, False),
    "hands": ((5.2, -5.6, 3.2), (1.5, 0, 2.6), 50, False, False),  # close-up: fists, forearms, sleeve
    "pose": ((-8.5, -12.5, 4.8), (0, 0, 3.0), 50, True, False),
    "dark": ((-8, -12.5, 4.6), (0, 0, 3.3), 50, False, True),
}
for view, (location, target, lens, posed, is_dark) in VIEWS.items():
    for name, pivot in pivots.items():
        pivot.rotation_euler = [math.radians(v) for v in POSE.get(name, (0, 0, 0))] if posed else (0, 0, 0)
    for obj in studio:
        obj.hide_render = is_dark
    for obj in dark:
        obj.hide_render = not is_dark
    background.inputs[0].default_value = (0.012, 0.014, 0.03, 1) if is_dark else (0.82, 0.84, 0.87, 1)
    background.inputs[1].default_value = 1.0 if is_dark else 0.6
    floor_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        (*linear("#10121C"), 1) if is_dark else (*linear("#D9DCE0"), 1))
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens
    scene.render.filepath = str(OUT / f"{view}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", view)
