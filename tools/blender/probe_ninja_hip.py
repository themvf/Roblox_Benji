"""Locate the scan surface visible at selected rendered hip pixels."""
from pathlib import Path
import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
blend = root / "assets/models/ninja-soldier-skins/trials/SciFiSentrySkinnedScan10/SciFiSentrySkinnedScan.blend"
bpy.ops.wm.open_mainfile(filepath=str(blend))
scene = bpy.context.scene
scene.render.resolution_x = 760
scene.render.resolution_y = 760
bpy.ops.object.camera_add(location=(7, -11, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 6.7
scene.camera = camera
deps = bpy.context.evaluated_depsgraph_get()
for px, py in ((280, 444), (305, 450), (337, 420), (320, 500), (418, 440)):
    cx = (px / 760 - .5) * 6.7
    cy = (.5 - py / 760) * 6.7
    origin = camera.matrix_world @ Vector((cx, cy, -1))
    direction = camera.matrix_world.to_quaternion() @ Vector((0, 0, -1))
    hit, loc, normal, index, obj, matrix = scene.ray_cast(deps, origin, direction)
    print("PIXEL", px, py, "HIT", hit, "OBJ", obj.name if obj else None,
          "FACE", index, "WORLD", tuple(round(v, 3) for v in loc) if hit else None)
