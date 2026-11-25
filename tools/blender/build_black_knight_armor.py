"""Black Knight kit armour, built from shapes on a blocky R15 body.

    blender -b -noaudio --python tools/blender/build_black_knight_armor.py -- [--team red|blue] [--views a,b]

Every piece belongs to one R15 body part, so the armour bends with the player instead of
tearing at the joints (a generated statue cut into pieces did: see ninja-soldier-skins).
Reference: docs/design/kits/blackknight/reference.jpg, without the hammer.

Writes assets/models/black-knight-armor/review/*.png and source/BlackKnightArmor.blend.
Coordinates are studs, Blender Z up; the character faces -Y. The player's right is -X.
Trim pieces marked TEAM take the team colour in game.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/black-knight-armor"
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return args[args.index(name) + 1] if name in args else default


TEAM_COLOURS = {"red": "#C8433A", "blue": "#3D74D8"}
TEAM = TEAM_COLOURS[arg("--team", "red")]
VIEWS = arg("--views", "front,quarter,side,back,helmet,pose,quarter_blue").split(",")

# Palette taken from the reference: blue-grey plate, darker under-layer, near-black visor.
PLATE = "#3B4A5B"
PLATE_LIGHT = "#55687D"
UNDER = "#222A35"
BODY = "#1A1D21"
VISOR = "#08090B"
EYE = "#FF5A12"

# Blocky R15 body: name -> (centre, size). Sizes follow Roblox's blocky avatar.
BODY_PARTS = {
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
# Where each part turns, and what it hangs from.
JOINTS = {
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

PIECES = []  # (part, name, shape, centre, size, colour, bevel, tilt_deg_about_y, material)


def add(part, name, shape, centre, size, colour, bevel=0.0, tilt=0.0, material="plate"):
    PIECES.append((part, name, shape, centre, size, colour, bevel, tilt, material))


def both(part, name, shape, centre, size, colour, bevel=0.0, tilt=0.0, material="plate"):
    """A pair: `centre` is given for the LEFT side (+X); the right is mirrored."""
    x, y, z = centre
    left, right = (part, part) if part in BODY_PARTS else ("Left" + part, "Right" + part)
    add(left, "left-" + name, shape, (x, y, z), size, colour, bevel, tilt, material)
    add(right, "right-" + name, shape, (-x, y, z), size, colour, bevel, -tilt, material)


# ---- helmet: a big box helm, crest over the top, black visor band with two orange slits
add("Head", "helm", "box", (0, 0.03, 5.36), (1.78, 1.66, 1.46), PLATE, 0.2)
add("Head", "helm-cap", "box", (0, 0.06, 6.12), (1.46, 1.4, 0.22), PLATE_LIGHT, 0.09)
add("Head", "crest", "box", (0, 0.12, 6.3), (0.17, 1.15, 0.36), UNDER, 0.05)
add("Head", "crest-prow", "box", (0, -0.5, 6.18), (0.19, 0.36, 0.5), UNDER, 0.05)
add("Head", "brow", "box", (0, -0.84, 5.74), (1.62, 0.16, 0.2), PLATE_LIGHT, 0.06)
add("Head", "brow-ridge", "box", (0, -0.86, 5.98), (0.2, 0.14, 0.34), PLATE_LIGHT, 0.05)
add("Head", "visor", "box", (0, -0.81, 5.36), (1.46, 0.08, 0.6), VISOR, 0.02, material="visor")
add("Head", "chin-guard", "box", (0, -0.82, 4.86), (1.5, 0.2, 0.34), UNDER, 0.07)
for side in (1, -1):
    add("Head", ("left" if side > 0 else "right") + "-eye", "box", (side * 0.34, -0.86, 5.38),
        (0.34, 0.03, 0.12), EYE, 0.0, side * -9, "glow")
    add("Head", ("left" if side > 0 else "right") + "-ear-disc", "disc", (side * 0.92, 0.05, 5.3),
        (0.18, 0.7, 0.7), PLATE_LIGHT, 0.04)
    add("Head", ("left" if side > 0 else "right") + "-ear-core", "disc", (side * 1.02, 0.05, 5.3),
        (0.06, 0.38, 0.38), UNDER)
    add("Head", ("left" if side > 0 else "right") + "-ear-fin", "box", (side * 0.97, 0.22, 5.95),
        (0.1, 0.24, 0.95), UNDER, 0.03, side * -8)

# ---- torso: breastplate with a lighter centre plate, collar, back plate, belt
add("UpperTorso", "breastplate", "box", (0, 0, 3.93), (2.16, 1.2, 1.66), PLATE, 0.11)
# Two chest plates tipped into a V, as in the reference, over two stomach bands.
both("UpperTorso", "pec", "box", (0.47, -0.63, 4.18), (0.84, 0.1, 0.7), PLATE_LIGHT, 0.05, -12)
add("UpperTorso", "sternum", "box", (0, -0.66, 4.02), (0.16, 0.1, 0.62), UNDER, 0.03)
add("UpperTorso", "ab-band-1", "box", (0, -0.63, 3.6), (1.24, 0.08, 0.2), PLATE_LIGHT, 0.03)
add("UpperTorso", "ab-band-2", "box", (0, -0.63, 3.33), (1.1, 0.08, 0.2), PLATE_LIGHT, 0.03)
both("UpperTorso", "flank", "box", (0.86, -0.62, 3.46), (0.34, 0.06, 0.5), UNDER, 0.02)
add("UpperTorso", "collar", "box", (0, 0, 4.78), (1.3, 1.0, 0.16), UNDER, 0.05)
add("UpperTorso", "back-plate", "box", (0, 0.63, 3.98), (1.6, 0.08, 1.24), PLATE_LIGHT, 0.04)
add("LowerTorso", "belt", "box", (0, 0, 2.9), (2.1, 1.14, 0.44), UNDER, 0.07)
add("LowerTorso", "buckle", "box", (0, -0.6, 2.9), (0.52, 0.06, 0.28), TEAM, 0.02, material="team")
both("LowerTorso", "tasset", "box", (0.55, -0.6, 2.72), (0.62, 0.08, 0.38), PLATE, 0.04)

# ---- arms: layered pauldrons with a team stripe, gauntlets, armoured fists
both("UpperArm", "pauldron", "box", (1.6, 0, 4.5), (1.36, 1.36, 0.56), PLATE, 0.13)
both("UpperArm", "pauldron-band", "box", (1.62, 0, 4.17), (1.24, 1.24, 0.2), PLATE_LIGHT, 0.06)
both("UpperArm", "pauldron-stripe", "box", (1.6, -0.69, 4.52), (1.04, 0.04, 0.12), TEAM, material="team")
both("UpperArm", "sleeve", "box", (1.5, 0, 3.85), (1.05, 1.05, 0.72), UNDER, 0.06)
both("LowerArm", "gauntlet", "box", (1.5, 0, 2.95), (1.2, 1.2, 1.0), PLATE, 0.11)
both("LowerArm", "cuff", "box", (1.5, 0, 3.38), (1.28, 1.28, 0.15), PLATE_LIGHT, 0.05)
both("Hand", "fist", "box", (1.5, -0.04, 2.13), (1.06, 1.1, 0.6), UNDER, 0.12)
both("Hand", "knuckles", "box", (1.5, -0.6, 2.22), (0.9, 0.08, 0.28), PLATE_LIGHT, 0.03)

# ---- legs: thigh plates, knee blocks, greaves, heavy boots
# Each leg's plate is narrower than the leg and set outward, so a dark seam runs between the
# legs and they read as two legs, not one block.
both("UpperLeg", "thigh", "box", (0.56, 0, 2.15), (0.9, 1.06, 1.1), PLATE, 0.09)
both("UpperLeg", "thigh-plate", "box", (0.58, -0.56, 2.22), (0.66, 0.06, 0.72), PLATE_LIGHT, 0.03)
both("UpperLeg", "thigh-band", "box", (0.56, 0, 1.68), (0.94, 1.1, 0.12), UNDER, 0.03)
both("LowerLeg", "knee", "box", (0.56, -0.56, 1.42), (0.72, 0.28, 0.44), PLATE_LIGHT, 0.09)
both("LowerLeg", "greave", "box", (0.56, 0, 0.98), (0.94, 1.08, 0.98), PLATE, 0.1)
both("LowerLeg", "shin-ridge", "box", (0.56, -0.56, 1.0), (0.2, 0.08, 0.7), PLATE_LIGHT, 0.03)
both("LowerLeg", "strap", "box", (0.56, 0, 0.6), (0.98, 1.12, 0.12), UNDER, 0.03)
both("Foot", "boot", "box", (0.57, -0.1, 0.24), (1.0, 1.36, 0.42), PLATE, 0.11)
both("Foot", "toe-cap", "box", (0.57, -0.7, 0.2), (0.86, 0.22, 0.3), PLATE_LIGHT, 0.06)
both("Foot", "sole", "box", (0.57, -0.1, 0.04), (1.06, 1.44, 0.08), BODY, 0.02)


# ------------------------------------------------------------------ scene
def linear(hex_colour):
    channels = (int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)


materials = {}


def material(colour, kind):
    key = (colour, kind)
    if key not in materials:
        mat = bpy.data.materials.new(f"{kind}_{colour[1:]}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*linear(colour), 1)
        # Roughly what Roblox's Metal material reads like: some sheen, never mirror.
        bsdf.inputs["Roughness"].default_value = {"plate": 0.42, "team": 0.5, "visor": 0.18, "glow": 0.5}.get(kind, 0.6)
        bsdf.inputs["Metallic"].default_value = 0.35 if kind == "plate" else 0.0
        if kind == "glow":
            bsdf.inputs["Emission Color"].default_value = (*linear(colour), 1)
            bsdf.inputs["Emission Strength"].default_value = 2.2
        materials[key] = mat
    return materials[key]


def make(name, shape, centre, size, colour, bevel, tilt, kind):
    if shape == "disc":  # a cylinder lying along X: size is (thickness, diameter, diameter)
        bpy.ops.mesh.primitive_cylinder_add(vertices=24)
        obj = bpy.context.object
        obj.dimensions = (size[1], size[2], size[0])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.rotation_euler = (0, math.pi / 2, 0)
    else:
        bpy.ops.mesh.primitive_cube_add()
        obj = bpy.context.object
        obj.dimensions = size
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.rotation_euler = (0, math.radians(tilt), 0)
    obj.location = centre
    obj.data.materials.append(material(colour, kind))
    for face in obj.data.polygons:
        face.use_smooth = False
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Body parts as pivots at their joints, so a pose turns everything hanging from them.
pivots = {}
for name in ["LowerTorso"] + list(JOINTS):
    joint = JOINTS.get(name, ((0, 0, 2.9), None))[0]
    pivot = bpy.data.objects.new("Pivot_" + name, None)
    scene.collection.objects.link(pivot)
    pivot.location = joint
    pivots[name] = pivot
for name, (joint, parent) in JOINTS.items():
    pivots[name].parent = pivots[parent]
    pivots[name].location = Vector(joint) - Vector(JOINTS.get(parent, ((0, 0, 2.9), None))[0])


def attach(obj, part):
    pivot = pivots[part]
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = pivot
    obj.matrix_world = world


for name, (centre, size) in BODY_PARTS.items():
    attach(make("Body_" + name, "box", centre, size, BODY, 0.04, 0, "body"), name)
triangles = {}
for part, name, shape, centre, size, colour, bevel, tilt, kind in PIECES:
    obj = make(f"{part}__{name}", shape, centre, size, colour, bevel, tilt, kind)
    triangles[part] = triangles.get(part, 0) + sum(len(p.vertices) - 2 for p in obj.data.polygons)
    attach(obj, part)

# ------------------------------------------------------------------ generated pieces
# `--helmet <glb>` / `--pauldron <glb>` swap the shape pieces for a generated model. Each
# model is fitted into the box the shape pieces filled and hung from the same body part, so
# it stays rigid on one limb. Generated GLBs face glTF +Z, which Blender imports as -Y:
# the character's front. `--turn <deg>` spins them about Z if a generator faced them away.
SWAPS = {
    # flag: (body part, shape-piece name prefixes it replaces, box centre, box size)
    "--helmet": ("Head", ("helm", "crest", "brow", "visor", "chin", "left-e", "right-e"),
                 (0, 0.0, 5.62), (2.5, 2.7, 2.8)),
    "--pauldron": ("LeftUpperArm", ("left-pauldron",), (1.62, 0, 4.4), (1.6, 1.6, 1.0)),
}


def import_fitted(path, centre, size, mirror=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in [o for o in bpy.data.objects if o not in before and o.type != "MESH"]:
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.parent = None
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.rotation_mode = "XYZ"  # the glTF importer leaves quaternions, which ignore rotation_euler
    obj.rotation_euler = (0, 0, math.radians(float(arg("--turn", "0"))))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    low = Vector([min(c[i] for c in corners) for i in range(3)])
    high = Vector([max(c[i] for c in corners) for i in range(3)])
    scale = min(size[i] / max(high[i] - low[i], 1e-6) for i in range(3))
    obj.scale = (-scale if mirror else scale, scale, scale)
    obj.location = Vector(centre) - (low + high) / 2 * scale * Vector((-1 if mirror else 1, 1, 1))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mirror:  # a negative scale turns faces inside out
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
    return obj


for flag, (part, prefixes, centre, size) in SWAPS.items():
    if flag not in args:
        continue
    path = arg(flag, "")
    jobs = [(part, prefixes, centre, False)]
    if flag == "--pauldron":  # the right shoulder is the left one mirrored
        jobs.append(("RightUpperArm", ("right-pauldron",), (-centre[0], centre[1], centre[2]), True))
    for body_part, names, where, mirror in jobs:
        for obj in list(bpy.data.objects):
            if obj.name.startswith(body_part + "__") and obj.name.split("__", 1)[1].startswith(names):
                bpy.data.objects.remove(obj)
        fitted = import_fitted(path, where, size, mirror)
        fitted.name = f"{body_part}__generated"
        if flag == "--helmet":  # a closed helm hides the head; in game Head goes transparent
            bpy.data.objects["Body_Head"].hide_render = True
        triangles[body_part] = sum(len(p.vertices) - 2 for p in fitted.data.polygons)
        attach(fitted, body_part)
        print("SWAPPED", flag, body_part, triangles[body_part], "triangles")

PKG.joinpath("source").mkdir(parents=True, exist_ok=True)
PKG.joinpath("review").mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(PKG / "source/BlackKnightArmor.blend"))
print("PIECES", len(PIECES), "TRIANGLES", sum(triangles.values()))
for part in sorted(triangles):
    print(f"  {part:16s} {triangles[part]:5d}")

# ------------------------------------------------------------------ render
# `--backdrop dark` is a kit-screen look (dark navy, coloured rim light); the default grey
# studio shows the true colours for judging the model itself.
DARK = arg("--backdrop", "studio") == "dark"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.013, 0.025, 1) if DARK else (0.82, 0.84, 0.87, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0 if DARK else 0.6

bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
floor = bpy.context.object
floor.data.materials.append(material("#141621" if DARK else "#D9DCE0", "floor"))


def light(name, kind, location, energy, size=4):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 3)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)


light("key", "AREA", (-6, -8, 9), 1100 if DARK else 1400, 6)
light("fill", "AREA", (8, -6, 5), 250 if DARK else 500, 6)
light("rim", "AREA", (2, 9, 7), 2200 if DARK else 700, 5)
if DARK:  # a warm rim from behind on each side, picking out the silhouette like a kit screen
    for x in (-5, 5):
        light("rim" + str(x), "AREA", (x, 6, 6), 1600, 3)
        bpy.data.lights["rim" + str(x)].color = (1.0, 0.55, 0.25)

cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 60
cam_data.clip_start, cam_data.clip_end = 0.1, 200
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 900, 1100
scene.view_settings.view_transform = "Standard"


def aim(location, target, lens=60):
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens


def set_pose(posed):
    rest = {name: (0, 0, 0) for name in pivots}
    if posed:  # mid-stride with arms up: shows the pieces follow their limbs
        rest.update({
            "RightUpperArm": (math.radians(-70), 0, math.radians(-10)),
            "RightLowerArm": (math.radians(-60), 0, 0),
            "LeftUpperArm": (math.radians(35), 0, math.radians(15)),
            "LeftLowerArm": (math.radians(-45), 0, 0),
            "RightUpperLeg": (math.radians(-40), 0, 0),
            "RightLowerLeg": (math.radians(55), 0, 0),
            "LeftUpperLeg": (math.radians(25), 0, 0),
            "LeftLowerLeg": (math.radians(20), 0, 0),
            "Head": (0, 0, math.radians(20)),
            "UpperTorso": (0, 0, math.radians(-12)),
        })
    for name, rotation in rest.items():
        pivots[name].rotation_euler = rotation


def set_team(colour):
    for (c, kind), mat in materials.items():
        if kind == "team":
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*linear(colour), 1)


SHOTS = {
    "front": ((0, -15, 3.4), (0, 0, 3.1), 50),
    "quarter": ((-9, -11, 5.2), (0, 0, 3.1), 50),
    "side": ((15, 0, 3.4), (0, 0, 3.1), 50),
    "back": ((0, 15, 3.4), (0, 0, 3.1), 50),
    "helmet": ((-2.2, -4.2, 6.0), (0, 0, 5.4), 50),
    "pose": ((-8, -12, 4.6), (0, 0, 2.9), 50),
    "quarter_blue": ((9, -11, 5.2), (0, 0, 3.1), 50),
}
for view in VIEWS:
    location, target, lens = SHOTS[view]
    set_pose(view == "pose")
    set_team(TEAM_COLOURS["blue"] if view.endswith("_blue") else TEAM)
    aim(location, target, lens)
    scene.render.filepath = str(PKG / "review" / f"{view}{arg('--suffix', '')}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
