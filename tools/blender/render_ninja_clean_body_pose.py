"""Render a modest R15 joint-bend check of the clean Sentry proportion trial."""
from pathlib import Path
import math

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials/SciFiSentryCleanBody"
bpy.ops.wm.open_mainfile(filepath=str(TRIAL / "SciFiSentryCleanBody.blend"))


def pivot_rotate(prefix, pivot, angle):
    translation = Matrix.Translation(Vector(pivot))
    rotation = Matrix.Rotation(math.radians(angle), 4, "X")
    inverse = Matrix.Translation(-Vector(pivot))
    transform = translation @ rotation @ inverse
    for obj in bpy.data.objects:
        if obj.name.startswith(prefix):
            obj.matrix_world = transform @ obj.matrix_world


# All armor parts use the same R15 segment prefix as their body guide.
pivot_rotate("LeftLowerArm", (-1.13, 0, 3.20), 35)
pivot_rotate("LeftHand", (-1.13, 0, 3.20), 35)
pivot_rotate("RightLowerArm", (1.13, 0, 3.20), -35)
pivot_rotate("RightHand", (1.13, 0, 3.20), -35)
pivot_rotate("LeftLowerLeg", (-.43, 0, 1.46), -24)
pivot_rotate("LeftFoot", (-.43, 0, 1.46), -24)
pivot_rotate("RightUpperLeg", (.43, 0, 2.55), 18)
pivot_rotate("RightLowerLeg", (.43, 0, 2.55), 18)
pivot_rotate("RightFoot", (.43, 0, 2.55), 18)

scene = bpy.context.scene
bpy.ops.object.camera_add(location=(7, -11, 6))
camera = bpy.context.object
camera.name = "Pose review camera"
camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 6.7
scene.camera = camera
scene.render.filepath = str(TRIAL / "joint-bend.png")
bpy.ops.render.render(write_still=True)
print("SAVED", scene.render.filepath)
