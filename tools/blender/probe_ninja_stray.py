"""Locate a visible isolated shard in the skinned pose review image."""
from pathlib import Path
import math
import sys
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DENSITY = int(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else 3
TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials" / ("SciFiSentrySkinnedScan" + ("10" if DENSITY == 10 else ""))
bpy.ops.wm.open_mainfile(filepath=str(TRIAL / "SciFiSentrySkinnedScan.blend"))
rig = bpy.data.objects["SciFiSentryR15"]
for name, degrees in (("LeftLowerArm", 35), ("RightLowerArm", -35),
                      ("LeftLowerLeg", -22), ("RightUpperLeg", 18)):
    bone = rig.pose.bones[name]
    bone.rotation_mode = "XYZ"
    bone.rotation_euler.x = math.radians(degrees)
bpy.context.view_layer.update()
bpy.ops.object.camera_add(location=(7, -11, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 6.7
bpy.context.scene.camera = camera
target = (225/760, 1-505/760)
closest = []
for obj in [o for o in bpy.data.objects if o.name.startswith("SciFiSentrySkinnedMesh_")]:
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    for face in mesh.polygons:
        center = sum((mesh.vertices[i].co for i in face.vertices), Vector()) / len(face.vertices)
        xy = world_to_camera_view(bpy.context.scene, camera, evaluated.matrix_world @ center)
        distance = (xy.x-target[0])**2 + (xy.y-target[1])**2
        closest.append((distance, obj.name, face.index, tuple(round(v, 3) for v in center),
                        (round(xy.x, 3), round(xy.y, 3))))
    evaluated.to_mesh_clear()
print("CLOSEST", sorted(closest)[:12])
