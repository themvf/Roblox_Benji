"""Render saved skinned Sentry in rest and articulated poses."""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if args and args[0] == "--rebuild":
    TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials/SciFiSentryRebuiltArmor"
    blend = TRIAL / "SciFiSentryRebuiltArmor.blend"
else:
    density = int(args[0]) if args else 3
    TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials" / ("SciFiSentrySkinnedScan" + ("10" if density == 10 else ""))
    blend = TRIAL / "SciFiSentrySkinnedScan.blend"
bpy.ops.wm.open_mainfile(filepath=str(blend))
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 760
scene.render.resolution_y = 760
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
world = bpy.data.worlds.new("Neutral skin review")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.32, .37, .43, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8

for name, location, power, size in (("Key", (-3, -5, 8), 850, 5),
                                    ("Rim", (3, 3, 7), 1050, 4),
                                    ("Fill", (4, -4, 4), 350, 5)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0, 0, 2.7)) - light.location).to_track_quat("-Z", "Y").to_euler()

def render(label, location):
    bpy.ops.object.camera_add(location=location)
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.7
    scene.camera = camera
    scene.render.filepath = str(TRIAL / (label + ".png"))
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

render("front", (7, -11, 6))
render("side", (12, 0, 5))
render("rear", (7, 11, 6))

rig = bpy.data.objects["SciFiSentryR15"]
for name, degrees in (("LeftLowerArm", 35), ("RightLowerArm", -35),
                      ("LeftLowerLeg", -22), ("RightUpperLeg", 18)):
    bone = rig.pose.bones[name]
    bone.rotation_mode = "XYZ"
    bone.rotation_euler.x = math.radians(degrees)
bpy.context.view_layer.update()
render("joint-bend", (7, -11, 6))
print("RENDERED", TRIAL)
