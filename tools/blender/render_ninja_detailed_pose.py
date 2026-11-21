"""Render the saved segmented GLB with rigid limbs moved to reveal seam risks."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
variant = sys.argv[sys.argv.index("--") + 1]
source = PKG / "trials" / f"{variant}DetailedSegmented.glb"
output = PKG / "review" / f"{variant}-detailed-pose.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
scene = bpy.context.scene

under = bpy.data.materials.new("Dark R15 underlayer")
under.use_nodes = True
under.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.015, .018, .022, 1)
under.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .75


def add_body(anchor, location, size, sphere=False):
    if sphere:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8)
    else:
        bpy.ops.mesh.primitive_cube_add()
    obj = bpy.context.object
    obj.name = anchor + "__underlayer"
    obj.location = location
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(under)


add_body("Head", (0, 0, 4.78), (1.0, .93, 1.0), True)
add_body("UpperTorso", (0, 0, 3.75), (1.54, .67, 1.21))
add_body("LowerTorso", (0, 0, 2.85), (1.32, .63, .72))
for side, x in (("Left", -1.23), ("Right", 1.23)):
    for anchor, z, size in (("UpperArm", 3.66, (.42, .43, .89)),
                            ("LowerArm", 2.79, (.39, .41, .81)),
                            ("Hand", 2.10, (.37, .39, .31))):
        add_body(side + anchor, (x, 0, z), size, True)
for side, x in (("Left", -.53), ("Right", .53)):
    for anchor, z, size in (("UpperLeg", 1.91, (.55, .56, .88)),
                            ("LowerLeg", 1.03, (.46, .49, .82)),
                            ("Foot", .38, (.62, .83, .27))):
        add_body(side + anchor, (x, 0, z), size, True)


def rotate_group(obj, pivot, angle):
    center = Vector(pivot)
    matrix = Matrix.Translation(center) @ Matrix.Rotation(math.radians(angle), 4, "Y") @ Matrix.Translation(-center)
    obj.matrix_world = matrix @ obj.matrix_world


for obj in scene.objects:
    if obj.type != "MESH":
        continue
    attach = obj.name.split("__", 1)[0]
    if attach.startswith("Left") and "Arm" in attach or attach == "LeftHand":
        rotate_group(obj, (-1.44, 0, 4.05), 28)
    elif attach.startswith("Right") and "Arm" in attach or attach == "RightHand":
        rotate_group(obj, (1.44, 0, 4.05), -28)
    elif attach.startswith("Left") and ("Leg" in attach or "Foot" in attach):
        rotate_group(obj, (-.53, 0, 2.45), 11)
    elif attach.startswith("Right") and ("Leg" in attach or "Foot" in attach):
        rotate_group(obj, (.53, 0, 2.45), -11)

floor = bpy.data.materials.new("Floor")
floor.diffuse_color = (.5, .52, .55, 1)
floor.use_nodes = True
floor.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.5, .52, .55, 1)
bpy.ops.mesh.primitive_plane_add(size=100)
bpy.context.object.location.z = -.06
bpy.context.object.data.materials.append(floor)
world = bpy.data.worlds.new("Neutral")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.65, .67, .7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
scene.collection.objects.link(sun)
sun.rotation_euler = (.8, .2, .6)
sun.data.energy = 3
camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(camera)
scene.camera = camera
camera.location = (0, -12, 3.0)
camera.rotation_euler = (Vector((0, 0, 2.75)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 7.2
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(output)
bpy.ops.render.render(write_still=True)
print("RENDERED", output)
