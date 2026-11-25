import bpy
from pathlib import Path
import sys

p = Path(__file__).resolve().parents[2] / "assets/models/white-sniper/exports/WhiteSniper.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p))
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        print("CHECK", o.name, len(o.data.polygons), o.hide_render, o.visible_get(), o.location[:], o.dimensions[:], [m.name for m in o.data.materials])
print("BOUNDS", [(min((o.matrix_world @ v.co)[i] for o in bpy.context.scene.objects if o.type == "MESH" for v in o.data.vertices), max((o.matrix_world @ v.co)[i] for o in bpy.context.scene.objects if o.type == "MESH" for v in o.data.vertices)) for i in range(3)])
for m in bpy.data.materials:
    print("MATERIAL", m.name, m.blend_method, m.diffuse_color[:])
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            print("ALPHA", n.inputs["Alpha"].default_value, [(l.from_node.name, l.from_socket.name) for l in n.inputs["Alpha"].links])
        if n.type == "TEX_IMAGE":
            print("IMAGE", n.name, n.image.name if n.image else None, n.image.size[:] if n.image else None)
world = bpy.data.worlds.new("Preview")
bpy.context.scene.world = world
world.color = (0.5, 0.5, 0.5)
cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
bpy.context.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 7
bpy.context.scene.camera = cam
bpy.context.scene.render.engine = "CYCLES"
bpy.context.scene.cycles.samples = 8
for name, location, rotation in (
    ("side", (12, 0, 0), (1.57, 0, 1.57)),
    ("front", (0, -12, 0), (1.57, 0, 0)),
    ("rear", (0, 12, 0), (1.57, 0, 3.14159)),
):
    cam.location = location
    cam.rotation_euler = rotation
    bpy.context.scene.render.resolution_x = 1024
    bpy.context.scene.render.resolution_y = 512
    bpy.context.scene.render.filepath = str(p.parent.parent / f"review/{name}.png")
    bpy.ops.render.render(write_still=True)
