"""Author a subtle human-shaped shadow inside a separate clean blue tube.

The original cyan core is opaque. The shadow therefore sits on its front surface,
inside the transparent glass wall, rather than being hidden behind the core.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/bluetube-glossy"
BASE = PKG / "exports/BlueTube_Glossy.glb"
OUT = PKG / "exports/BlueTube_FaintOccupant.glb"
BLEND = PKG / "source/FaintOccupantTube.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE))

# Measured from the saved clean GLB; all coordinates use Blender Z-up.
CX, CY = 1.3376073, .1605129
SHADOW_DEPTH = 2.455

shadow = bpy.data.materials.new("Faint submerged human shadow")
shadow.use_nodes = True
bsdf = shadow.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (.018, .082, .105, 1)
bsdf.inputs["Roughness"].default_value = .85
bsdf.inputs["Alpha"].default_value = .22
shadow.blend_method = "BLEND"
shadow.use_backface_culling = False


def on_core(x, z):
    # A narrow plane remains between the opaque core and transparent glass.
    return Vector((CX + x * .61, CY - SHADOW_DEPTH, z))


def silhouette(name, outline):
    points = [on_core(x, z) for x, z in outline]
    # Triangulate the flat outline before positioning it inside the glass.
    triangles = tessellate_polygon([[Vector((x, z, 0)) for x, z in outline]])
    faces = [tuple(triangle) for triangle in triangles]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(p) for p in points], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(shadow)
    return obj


silhouette("Tube_Occupant_torso", [
    (-.36, 6.88), (-.69, 6.60), (-.63, 5.55), (-.50, 4.30),
    (.50, 4.30), (.63, 5.55), (.69, 6.60), (.36, 6.88),
])
silhouette("Tube_Occupant_left_arm", [
    (-.62, 6.56), (-.86, 6.40), (-1.05, 5.56), (-1.02, 4.52),
    (-.80, 4.50), (-.78, 5.54),
])
silhouette("Tube_Occupant_right_arm", [
    (.62, 6.56), (.86, 6.40), (1.05, 5.56), (1.02, 4.52),
    (.80, 4.50), (.78, 5.54),
])
silhouette("Tube_Occupant_left_leg", [
    (-.47, 4.34), (-.02, 4.34), (-.09, 2.61), (-.20, 1.85),
    (-.62, 1.85), (-.61, 2.28),
])
silhouette("Tube_Occupant_right_leg", [
    (.02, 4.34), (.47, 4.34), (.61, 2.28), (.62, 1.85),
    (.20, 1.85), (.09, 2.61),
])

head = []
for i in range(32):
    angle = 2 * math.pi * i / 32
    head.append((.01 + .46 * math.cos(angle), 7.48 + .59 * math.sin(angle)))
silhouette("Tube_Occupant_faint_head_shadow", head)

BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

# One imported part for the whole silhouette keeps Studio assembly simple.
pieces = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"
          and obj.data.materials and obj.data.materials[0] == shadow]
bpy.ops.object.select_all(action="DESELECT")
for obj in pieces:
    obj.select_set(True)
bpy.context.view_layer.objects.active = pieces[0]
bpy.ops.object.join()
pieces[0].name = "Tube_Faint_human_shadow"
pieces[0].data.name = pieces[0].name

bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True)
print("EXPORTED", OUT)
