"""Rebuild a low-poly mask surface and bake detail from the Hunyuan reference.

This produces an authoring trial, not a Roblox or Marketplace deliverable.
"""
import json
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

root = Path(__file__).resolve().parent
review = root.parent / 'review'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'hunyuan-mask-reference.glb'))
source = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
source.name = 'HighResolutionReference'
# Bake the source's albedo through emission: diffuse baking a metallic surface
# captures nearly black diffuse energy instead of its gold base color.
for mat in source.data.materials:
    if not mat or not mat.use_nodes:
        continue
    nodes = mat.node_tree.nodes
    shader = nodes.get('Principled BSDF')
    output = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if not shader or not output:
        continue
    emission = nodes.new('ShaderNodeEmission')
    color = shader.inputs['Base Color']
    if color.is_linked:
        mat.node_tree.links.new(color.links[0].from_socket, emission.inputs['Color'])
    else:
        emission.inputs['Color'].default_value = color.default_value
    mat.node_tree.links.new(emission.outputs[0], output.inputs['Surface'])
bpy.context.view_layer.objects.active = source
source.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
low = source.copy()
low.data = source.data.copy()
bpy.context.collection.objects.link(low)
low.name = 'MaskRetopologyTrial'
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active = low
low.data.remesh_voxel_size = 0.016
bpy.ops.object.voxel_remesh()
dec = low.modifiers.new('Triangle study budget', 'DECIMATE')
dec.ratio = min(1, 1900 / max(1, len(low.data.polygons)))
bpy.ops.object.modifier_apply(modifier=dec.name)
for face in low.data.polygons:
    face.use_smooth = True
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')
material = bpy.data.materials.new('Mask baked trial')
material.use_nodes = True
principled = material.node_tree.nodes.get('Principled BSDF')
principled.inputs['Metallic'].default_value = 0.65
principled.inputs['Roughness'].default_value = 0.38
low.data.materials.clear()
low.data.materials.append(material)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = 0.06
scene.render.bake.max_ray_distance = 0.18
scene.render.bake.margin = 8
bpy.ops.object.select_all(action='DESELECT')
source.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
results = {}
for kind, bake_type in [('color', 'EMIT'), ('normal', 'NORMAL')]:
    img = bpy.data.images.new('OniMask_' + kind, width=1024, height=1024, alpha=False)
    img.colorspace_settings.name = 'Non-Color' if kind == 'normal' else 'sRGB'
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = img
    material.node_tree.nodes.active = node
    if kind == 'color':
        scene.render.bake.use_pass_direct = False
        scene.render.bake.use_pass_indirect = False
        scene.render.bake.use_pass_color = True
    bpy.ops.object.bake(type=bake_type)
    img.filepath_raw = str(root / ('mask-trial-' + kind + '.png'))
    img.file_format = 'PNG'
    img.save()
    img.pack()
    if kind == 'color':
        material.node_tree.links.new(node.outputs['Color'], principled.inputs['Base Color'])
    else:
        normal_node = material.node_tree.nodes.new('ShaderNodeNormalMap')
        material.node_tree.links.new(node.outputs['Color'], normal_node.inputs['Color'])
        material.node_tree.links.new(normal_node.outputs['Normal'], principled.inputs['Normal'])
    results[kind] = img.filepath_raw
bm = bmesh.new()
bm.from_mesh(low.data)
report = {'triangles': sum(len(f.verts)-2 for f in bm.faces),
          'boundaryEdges': sum(e.is_boundary for e in bm.edges),
          'nonManifoldEdges': sum(not e.is_manifold for e in bm.edges),
          'textures': results, 'status': 'Unapproved geometry and texture baking trial'}
bm.free()
source.hide_render = True
world = bpy.data.worlds.new('Studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.35, 0.35, 0.35, 1)
scene.world = world
bpy.ops.object.light_add(type='AREA', location=(0, -5, 6))
bpy.context.object.data.energy = 500
bpy.context.object.data.size = 5
bpy.ops.object.camera_add(location=(0, -6, 0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.5
scene.camera = camera
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.filepath = str(review / 'rebuilt-mask-front.png')
bpy.ops.render.render(write_still=True)
camera.location = (5, -4, 0.5)
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(review / 'rebuilt-mask-quarter.png')
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(root / 'rebuilt-mask-trial.blend'), compress=True)
(review / 'rebuilt-mask-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('MASK REBUILD', report)
