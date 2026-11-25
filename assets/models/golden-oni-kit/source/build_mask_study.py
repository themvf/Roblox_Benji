"""Build a local mask fitting study. This is not a Marketplace export."""
import json
import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

root = Path(__file__).resolve().parent
review = root.parent / 'review'
bpy.ops.wm.open_mainfile(filepath=str(root / 'oni-body-base.blend'))
with bpy.data.libraries.load(str(root / 'rebuilt-mask-trial.blend'), link=False) as (src, dst):
    if 'MaskRetopologyTrial' not in src.objects:
        raise RuntimeError('Rebuilt mask trial missing')
    dst.objects = ['MaskRetopologyTrial']
mask = dst.objects[0]
bpy.context.collection.objects.link(mask)
mask.name = 'OniMask_Study'
mask.scale = (0.94, 0.94, 0.94)
mask.location = (0, -0.52, 2.95)
bpy.context.view_layer.update()
head = bpy.data.objects['Head_Geo']
armature = bpy.data.objects['Armature']
world = mask.matrix_world.copy()
mask.parent = armature
mask.parent_type = 'BONE'
mask.parent_bone = 'Head'
mask.matrix_world = world
head.data.materials.clear()
head.data.materials.append(bpy.data.materials['Oni outfit - preliminary black'])

# Project approved concept details onto the clean body for a local visual test.
# This is not a final bake: the back and sides lack authoritative reference views.
reference = bpy.data.images.load(str(root / 'tpose-reference.png'), check_existing=True)
reference.pack()
textured = bpy.data.materials.new('Concept projection study')
textured.use_nodes = True
nodes = textured.node_tree.nodes
image_node = nodes.new('ShaderNodeTexImage')
image_node.image = reference
textured.node_tree.links.new(image_node.outputs['Color'], nodes['Principled BSDF'].inputs['Base Color'])
nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.8

def remap(v, a, b, c, d):
    return c + max(0.0, min(1.0, (v - a) / (b - a))) * (d - c)

for obj in [o for o in bpy.data.objects if o.type == 'MESH' and o.name.endswith('_Geo')]:
    name = obj.name
    if name in ('Head_Geo', 'LeftHand_Geo', 'RightHand_Geo') or 'UpperLeg' in name:
        continue
    obj.data.materials.clear()
    obj.data.materials.append(textured)
    obj.data.materials.append(bpy.data.materials['Oni outfit - preliminary black'])
    layer = obj.data.uv_layers.new(name='ConceptProjection')
    obj.data.uv_layers.active = layer
    layer.active_render = True
    for poly in obj.data.polygons:
        normal = (obj.matrix_world.to_3x3() @ poly.normal).normalized()
        poly.material_index = 0 if normal.y < -0.3 else 1
        for li in poly.loop_indices:
            co = obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co
            if name == 'UpperTorso_Geo':
                px = remap(co.x, -1, 1, 485, 770)
                py = remap(co.z, 0.4, 2.0, 705, 490)
            elif name == 'LowerTorso_Geo':
                px = remap(co.x, -1, 1, 470, 785)
                py = remap(co.z, 0, 0.4, 748, 700)
            elif 'Arm_Geo' in name:
                left = name.startswith('Left')
                top, bottom = (1.95, 0.78) if 'UpperArm' in name else (1.3, 0.25)
                start, end = ((790, 920) if 'UpperArm' in name else (910, 1060)) if left else ((465, 330) if 'UpperArm' in name else (340, 190))
                px = remap(co.z, bottom, top, end, start)
                py = remap(co.x, 1 if left else -2, 2 if left else -1, 575, 455)
            else:
                left = name.startswith('Left')
                xa, xb = (0, 1) if left else (-1, 0)
                px = remap(co.x, xa, xb, 690 if left else 405, 840 if left else 560)
                py = remap(co.z, -2.0, 0.18, 1130, 750)
            layer.data[li].uv = (px / 1254, 1 - py / 1254)

# Two shaped cloth shells follow the upper-leg bones independently.  This is a
# fitting prototype; the final garment still needs material and motion review.
cloth = bpy.data.materials.new('Robe fabric study')
cloth.diffuse_color = (0.025, 0.026, 0.032, 1)
cloth.use_nodes = True
cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = cloth.diffuse_color
cloth.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.8
garment = []
# The short overlapping waist layer stays with the torso as the legs turn.
waist_verts = []
waist_faces = []
for z, w, d in [(0.52, 1.02, 0.53), (0.05, 1.10, 0.57)]:
    for k in range(32):
        a = 2 * math.pi * k / 32
        c, s = math.cos(a), math.sin(a)
        waist_verts.append((w * math.copysign(abs(c) ** 0.5, c), d * math.copysign(abs(s) ** 0.5, s), z))
for k in range(32):
    waist_faces.append((k, (k + 1) % 32, (k + 1) % 32 + 32, k + 32))
waist_mesh = bpy.data.meshes.new('WaistRobeStudyMesh')
waist_mesh.from_pydata(waist_verts, [], waist_faces)
waist_mesh.update()
waist = bpy.data.objects.new('WaistRobeStudy', waist_mesh)
bpy.context.collection.objects.link(waist)
waist.data.materials.append(cloth)
solid = waist.modifiers.new('Fabric thickness', 'SOLIDIFY')
solid.thickness = 0.025
bpy.context.view_layer.update()
world = waist.matrix_world.copy()
waist.parent = armature
waist.parent_type = 'BONE'
waist.parent_bone = 'LowerTorso'
waist.matrix_world = world
garment.append(waist)
for side, x, bone_name in [('Left', 0.5, 'LeftUpperLeg'), ('Right', -0.5, 'RightUpperLeg')]:
    vertices = []
    faces = []
    n = 32
    for row in range(9):
        t = row / 8
        z = 0.36 - 1.10 * t
        width = 0.48 + 0.10 * t
        depth = 0.51 + 0.08 * t
        for k in range(n):
            angle = 2 * math.pi * k / n
            # Squared silhouette with gentle radial folds toward the hem.
            c, s = math.cos(angle), math.sin(angle)
            fold = 0.02 * math.sin(8 * angle) * (0.25 + t)
            vertices.append((x + math.copysign(0.10 * t, x) + (width + fold) * math.copysign(abs(c) ** 0.5, c),
                             (depth + fold) * math.copysign(abs(s) ** 0.5, s), z))
    for row in range(8):
        for k in range(n):
            a = row * n + k
            b = row * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(reversed(range(n))))
    mesh = bpy.data.meshes.new(side + '_RobeStudyMesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(side + '_RobeStudy', mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(cloth)
    solid = obj.modifiers.new('Fabric thickness', 'SOLIDIFY')
    solid.thickness = 0.025
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = 'BONE'
    obj.parent_bone = bone_name
    obj.matrix_world = world
    garment.append(obj)

# Front wrap seams are separate fitted cloth strips, attached to the torso.
seam_mat = bpy.data.materials.new('Wrap seam study')
seam_mat.diffuse_color = (0.045, 0.046, 0.052, 1)
seam_mat.use_nodes = True
seam_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = seam_mat.diffuse_color
for i, (x0, x1) in enumerate([]):
    width = 0.075
    verts = [(x0-width, -0.525, 1.95), (x0+width, -0.525, 1.95),
             (x1+width, -0.525, 0.44), (x1-width, -0.525, 0.44)]
    mesh = bpy.data.meshes.new('WrapStudyMesh' + str(i))
    mesh.from_pydata(verts, [], [(0, 1, 2, 3)])
    mesh.update()
    obj = bpy.data.objects.new('WrapStudy' + str(i), mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(seam_mat)
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = 'BONE'
    obj.parent_bone = 'UpperTorso'
    obj.matrix_world = world
    garment.append(obj)
bm = bmesh.new()
bm.from_mesh(mask.data)
bm.faces.ensure_lookup_table()
triangles = sum(len(f.verts)-2 for f in bm.faces)
open_edges = sum(1 for e in bm.edges if e.is_boundary)
nonmanifold = sum(1 for e in bm.edges if not e.is_manifold)
bm.free()
report = {'triangles': triangles, 'openEdges': open_edges, 'nonManifoldEdges': nonmanifold,
          'purpose': 'Experimental fitting study only; no publication or Marketplace claim',
          'limitations': ['Unverified face fit and joint movement', 'Generated geometry requires visual review', 'Outfit, rigging, cages and marketplace validation incomplete']}
(review / 'mask-study-metrics.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
# Render only the actual body and study, excluding cages and attachment markers.
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        obj.hide_render = not (obj.name.endswith('_Geo') or obj == mask or obj in garment)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world.color = (0.35, 0.35, 0.35)
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.35, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.8
bpy.ops.object.light_add(type='AREA', location=(0, -8, 8))
bpy.context.object.data.energy = 1200
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 7
bpy.ops.object.camera_add(location=(0, -14, 1.0))
cam = bpy.context.object
cam.rotation_euler = (Vector((0, 0, 0.65)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 7.5
scene.camera = cam
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(review / 'mask-fitting-study.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root / 'oni-fitting-study.blend'), compress=True)
# A limited head-turn check, not a complete animation or fit test.
if armature.animation_data:
    armature.animation_data.action = None
bone = armature.pose.bones['Head']
bone.rotation_mode = 'XYZ'
bone.rotation_euler[1] = 0.45
bpy.context.view_layer.update()
scene.render.filepath = str(review / 'mask-head-turn-study.png')
bpy.ops.render.render(write_still=True)
print('MASK STUDY', report)
# One leg-forward pose probes whether the rigid garment follows the upper leg.
bone.rotation_euler[1] = 0
leg = armature.pose.bones['LeftUpperLeg']
leg.rotation_mode = 'XYZ'
leg.rotation_euler[0] = 0.55
bpy.context.view_layer.update()
scene.render.filepath = str(review / 'robe-leg-pose-study.png')
bpy.ops.render.render(write_still=True)
# Side and rear angles expose fit and clipping that the front view can hide.
leg.rotation_euler[0] = 0
bpy.context.view_layer.update()
for label, location in [('side', (14, 0, 1.0)), ('back', (0, 14, 1.0)),
                        ('three-quarter', (10, -10, 1.5))]:
    cam.location = location
    cam.rotation_euler = (Vector((0, 0, 0.65)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(review / ('robe-' + label + '-study.png'))
    bpy.ops.render.render(write_still=True)

# Additional local pose samples. They reveal gross clipping only; they are not
# Roblox animation, face-animation, cage, or gameplay validation.
cam.location = (10, -10, 1.5)
cam.rotation_euler = (Vector((0, 0, 0.65)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
poses = {
    'walk': {'LeftUpperLeg': (0.55, 0, 0), 'RightUpperLeg': (-0.4, 0, 0),
             'LeftUpperArm': (-0.35, 0, 0), 'RightUpperArm': (0.35, 0, 0)},
    'arms-raised': {'LeftUpperArm': (0, 0, 1.2), 'RightUpperArm': (0, 0, -1.2)},
    'crouch': {'LeftUpperLeg': (0.7, 0, 0), 'RightUpperLeg': (0.7, 0, 0),
               'LeftLowerLeg': (-1.0, 0, 0), 'RightLowerLeg': (-1.0, 0, 0)},
}
for label, rotations in poses.items():
    for pbone in armature.pose.bones:
        pbone.rotation_mode = 'XYZ'
        pbone.rotation_euler = (0, 0, 0)
    for name, rotation in rotations.items():
        armature.pose.bones[name].rotation_euler = rotation
    bpy.context.view_layer.update()
    scene.render.filepath = str(review / ('pose-' + label + '-study.png'))
    bpy.ops.render.render(write_still=True)
