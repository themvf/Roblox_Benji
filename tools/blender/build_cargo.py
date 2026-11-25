"""Author the destroyed cargo unit. Run with Blender --factory-startup -b.

Optimization path: the TRELLIS silhouette (including the torn top) survives a
collapse decimation, but its shading shatters (review/trellis-decimate-9000.png).
So the decimated shape is kept, re-unwrapped, and colour / normal / roughness /
metalness are baked from the dense source onto it. Source axes: X length,
Y depth, Z up; scene_kit fits height afterwards.
"""
from pathlib import Path
import json
import math
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/cargo'
TARGET_TRIS = 7500
VOXEL = 0.004  # source units; the unit is about 1.02 long
SIZE = 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
for sub in ('source', 'textures', 'exports', 'review'):
    (OUT / sub).mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene


def select_only(objects, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = active or objects[0]


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


bpy.ops.import_scene.gltf(filepath=str(OUT / 'source/trellis-original.glb'))
meshes = [o for o in scene.objects if o.type == 'MESH']
select_only(meshes)
if len(meshes) > 1:
    bpy.ops.object.join()
high = bpy.context.object
high.name = 'TRELLIS_High'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for ob in [o for o in scene.objects if o.type != 'MESH']:
    bpy.data.objects.remove(ob)

# ---- low-poly shape: weld split vertices, collapse, smooth by angle ----
low = high.copy()
low.data = high.data.copy()
scene.collection.objects.link(low)
low.name = 'CargoUnit_Destroyed'
select_only([low])
# Drop source UVs first: collapse keeps UV seams, which stalls it after welding.
while low.data.uv_layers:
    low.data.uv_layers.remove(low.data.uv_layers[0])
# The TRELLIS mesh is close to triangle soup: collapsing it directly leaves jagged
# shards (two failed rounds). Voxel-remesh into one manifold shell, flatten planar
# regions, then collapse. Detail returns through the baked maps.
welded = tris(low)
mod = low.modifiers.new('Shell', 'REMESH')
mod.mode = 'VOXEL'
mod.voxel_size = VOXEL
mod.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=mod.name)
print('REMESHED', welded, '->', tris(low), flush=True)
mod = low.modifiers.new('Planar', 'DECIMATE')
mod.decimate_type = 'DISSOLVE'
mod.angle_limit = math.radians(4)
bpy.ops.object.modifier_apply(modifier=mod.name)
mod = low.modifiers.new('Triangulate', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=mod.name)
planar = tris(low)
if planar > TARGET_TRIS:
    mod = low.modifiers.new('Collapse', 'DECIMATE')
    mod.ratio = TARGET_TRIS / planar
    bpy.ops.object.modifier_apply(modifier=mod.name)
print('DECIMATED', planar, '->', tris(low), flush=True)
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30))
low.data.uv_layers.new(name='UVMap')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.object.mode_set(mode='OBJECT')
low_tris = tris(low)
assert low_tris < 10000, low_tris

# ---- bake maps from the dense source ----
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
bake = scene.render.bake
bake.use_selected_to_active = True
bake.cage_extrusion = 0.008
bake.max_ray_distance = 0.03
bake.margin = 8

bake_mat = bpy.data.materials.new('Cargo_Bake')
bake_mat.use_nodes = True
low.data.materials.clear()
low.data.materials.append(bake_mat)
target = bake_mat.node_tree.nodes.new('ShaderNodeTexImage')
bake_mat.node_tree.nodes.active = target


def bake_map(name, bake_type, data=True, **kwargs):
    img = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=False)
    if data:
        img.colorspace_settings.name = 'Non-Color'
    target.image = img
    select_only([high, low], active=low)
    print('BAKE', name, flush=True)
    bpy.ops.object.bake(type=bake_type, **kwargs)
    img.filepath_raw = str(OUT / 'textures' / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    return img


normal = bake_map('Cargo_Normal', 'NORMAL')
rough = bake_map('Cargo_Roughness', 'ROUGHNESS')


def emit_input(name):
    """Route whatever drives a source BSDF input into emission, for a raw bake.
    A DIFFUSE colour bake is base colour x (1 - metallic): black on metal."""
    for mat in high.data.materials:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        p = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        emission = nodes.get('BakeEmission') or nodes.new('ShaderNodeEmission')
        emission.name = 'BakeEmission'
        socket = p.inputs[name]
        if socket.is_linked:
            links.new(socket.links[0].from_socket, emission.inputs['Color'])
        else:
            value = socket.default_value
            rgba = tuple(value) if hasattr(value, '__len__') else (value, value, value, 1)
            for link in list(emission.inputs['Color'].links):
                links.remove(link)
            emission.inputs['Color'].default_value = rgba
        links.new(emission.outputs[0], out.inputs['Surface'])


emit_input('Base Color')
color = bake_map('Cargo_Color', 'EMIT', data=False)
# The TRELLIS reconstruction pushes the gunmetal toward blue-black. Grade the
# baked pixels in linear space so the delivered texture stays portable to GLB
# and reads like the warm, scuffed Midjourney reference in Roblox.
pixels = np.empty(len(color.pixels), dtype=np.float32)
color.pixels.foreach_get(pixels)
rgba = pixels.reshape((-1, 4))
rgb = rgba[:, :3]
warm_rust = np.clip((rgb[:, 0] - rgb[:, 2]) * 3.0, 0.0, 1.0)
rgb *= np.array([1.62, 1.41, 1.14], dtype=np.float32)
rgb[:, 0] += warm_rust * 0.07
rgb[:, 1] += warm_rust * 0.018
rgb[:] = np.clip(rgb, 0.0, 1.0)
color.pixels.foreach_set(pixels)
color.update()
color.save()
emit_input('Metallic')
metal = bake_map('Cargo_Metalness', 'EMIT')

# ---- delivery material from the baked maps ----
mat = bpy.data.materials.new('Cargo_Baked')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
p = nodes.get('Principled BSDF')
for img, socket in ((color, 'Base Color'), (rough, 'Roughness'), (metal, 'Metallic')):
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = img
    links.new(tex.outputs['Color'], p.inputs[socket])
tex = nodes.new('ShaderNodeTexImage')
tex.image = normal
nmap = nodes.new('ShaderNodeNormalMap')
links.new(tex.outputs['Color'], nmap.inputs['Color'])
links.new(nmap.outputs['Normal'], p.inputs['Normal'])
low.data.materials.clear()
low.data.materials.append(mat)
low['Anchored'] = True
low['Role'] = 'Destroyed cargo unit (role provisional, awaiting approval)'

source = bpy.data.collections.new('SOURCE')
scene.collection.children.link(source)
scene.collection.objects.unlink(high)
source.objects.link(high)
source.hide_render = source.hide_viewport = True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source/Cargo.blend'))
select_only([low])
bpy.ops.export_scene.gltf(filepath=str(OUT / 'source/Cargo_Authored.glb'),
    export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
    export_extras=True, export_materials='EXPORT', export_image_format='AUTO')
(OUT / 'source/build-metrics.json').write_text(json.dumps({
    'sourceTriangles': tris(high), 'weldedTriangles': welded, 'triangles': low_tris,
    'sourceDimensions': [round(d, 4) for d in high.dimensions],
    'method': 'collapse decimation + selected-to-active bake (colour, normal, roughness, metalness)',
    'textureSize': SIZE, 'materialCount': 1}, indent=2) + '\n')
print('CARGO BUILD:', low_tris, 'triangles from', tris(high))
