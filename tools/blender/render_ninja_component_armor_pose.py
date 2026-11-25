"""Pose preserved scan components by their assigned rigid body region."""
from pathlib import Path
import math

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials/SciFiSentryComponentArmor"
bpy.ops.wm.open_mainfile(filepath=str(TRIAL / "SciFiSentryComponentArmor.blend"))

def rotate_regions(names, pivot, angle):
    transform = (Matrix.Translation(Vector(pivot))
                 @ Matrix.Rotation(math.radians(angle), 4, "X")
                 @ Matrix.Translation(-Vector(pivot)))
    for obj in bpy.data.objects:
        if any(obj.name.startswith(name) for name in names):
            obj.matrix_world = transform @ obj.matrix_world

# Mild animation stress: elbow flexes and opposing step. Source components
# stay whole within each assigned section; the test exposes large strays.
rotate_regions(("LeftLowerArm", "LeftHand"), (-1.05, 0, 3.18), 35)
rotate_regions(("RightLowerArm", "RightHand"), (1.05, 0, 3.18), -35)
rotate_regions(("LeftLowerLeg", "LeftFoot"), (-.90, 0, 1.47), -24)
rotate_regions(("RightUpperLeg", "RightLowerLeg", "RightFoot"), (.90, 0, 2.55), 18)

scene = bpy.context.scene
bpy.ops.object.camera_add(location=(7, -11, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 6.7
scene.camera = camera
scene.render.filepath = str(TRIAL / "joint-bend.png")
bpy.ops.render.render(write_still=True)
print("SAVED", scene.render.filepath)
