"""Author the intact white cargo unit. Run with Blender --factory-startup -b.

Optimization path, same method as tools/blender/build_cargo.py and for the same
reason: the TRELLIS silhouette here is a plain rectangular box with corner caps, so
the shape survives reduction, but the raw mesh is near triangle soup and collapsing
it directly shatters the shading. So it is voxel-remeshed into one manifold shell,
planar-dissolved, collapsed, re-unwrapped, and colour / normal / roughness /
metalness are baked from the dense source onto it.

Two differences from the destroyed unit, both deliberate:

  * This source arrives with its long axis on Blender Y, not X. Everything
    downstream (scene_kit's `fit`, the preview camera positions, the map author
    reading "wide" off the build log) assumes length on X, so it is rotated 90
    degrees about Z here and the rotation is baked in. The rotation is measured,
    not hardcoded, so a re-run of TRELLIS with a different yaw still lands right.
  * The planar dissolve angle is tighter (2 degrees, against 4). This unit's whole
    design is flat panels meeting at crisp edges; a loose angle eats the panel
    ribs that are the only thing distinguishing it from a plain crate.

Source axes after the rotation: X length, Y depth, Z up. scene_kit fits height.
"""
from pathlib import Path
import json
import math
import bpy
import mathutils

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/cargo-b'
TARGET_TRIS = 7500
VOXEL = 0.0035  # source units; the unit is about 1.00 along its long axis
DISSOLVE_DEG = 2.0
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


def spans(ob):
    """Bounding-box spans read from the vertices, in object space.

    Not `ob.dimensions`: that is derived from a cached bound_box that does not
    refresh after a mesh-data transform, so it reports pre-rotation numbers and
    makes a working rotation look like a no-op. Verified in Blender 4.3.2."""
    co = [v.co for v in ob.data.vertices]
    return tuple(round(max(c[i] for c in co) - min(c[i] for c in co), 4) for i in range(3))


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

# ---- put the long horizontal axis on X ----
# Measured, not assumed: this TRELLIS run came out yawed 90 degrees from the
# destroyed unit's. Z is up in both, because the glTF importer converts Y-up.
#
# Rotate the MESH DATA, not the object. Setting `rotation_euler` here is a silent
# no-op: the glTF importer leaves rotation_mode on QUATERNION, so the euler is
# never read, and transform_apply then reports FINISHED and zeroes the euler while
# the vertices never move. Verified in Blender 4.3.2. A data-level transform has no
# rotation_mode, selection or context to get wrong, and it is the same idiom
# scene_kit's op_pivot uses.
arrived = spans(high)
if arrived[1] > arrived[0]:
    high.data.transform(mathutils.Matrix.Rotation(math.radians(90), 4, 'Z'))
    high.data.update()
oriented = spans(high)
print('ORIENTED', arrived, '->', oriented, flush=True)
assert oriented[0] > oriented[1], 'long axis is still not on X'

# ---- low-poly shape: remesh to one shell, flatten panels, collapse ----
low = high.copy()
low.data = high.data.copy()
scene.collection.objects.link(low)
low.name = 'CargoUnit_Intact'
select_only([low])
# Drop source UVs first: collapse preserves UV seams, which stalls it.
while low.data.uv_layers:
    low.data.uv_layers.remove(low.data.uv_layers[0])
welded = tris(low)
mod = low.modifiers.new('Shell', 'REMESH')
mod.mode = 'VOXEL'
mod.voxel_size = VOXEL
mod.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=mod.name)
print('REMESHED', welded, '->', tris(low), flush=True)
mod = low.modifiers.new('Planar', 'DECIMATE')
mod.decimate_type = 'DISSOLVE'
mod.angle_limit = math.radians(DISSOLVE_DEG)
bpy.ops.object.modifier_apply(modifier=mod.name)
mod = low.modifiers.new('Triangulate', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=mod.name)
planar = tris(low)
if planar > TARGET_TRIS:
    mod = low.modifiers.new('Collapse', 'DECIMATE')
    mod.ratio = TARGET_TRIS / planar
    bpy.ops.object.modifier_apply(modifier=mod.name)
print('DECIMATED', planar, '->', tris(low), flush=True)
# 20 degrees, not 30: this unit's panels meet at shallow chamfers that a wider
# angle smooths into a bulge, which is exactly the "clean lines" being bought.
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(20))
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

bake_mat = bpy.data.materials.new('CargoB_Bake')
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


normal = bake_map('CargoB_Normal', 'NORMAL')
rough = bake_map('CargoB_Roughness', 'ROUGHNESS')


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
color = bake_map('CargoB_Color', 'EMIT', data=False)
emit_input('Metallic')
metal = bake_map('CargoB_Metalness', 'EMIT')

# ---- delivery material from the baked maps ----
mat = bpy.data.materials.new('CargoB_Baked')
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
low['Role'] = 'Intact cargo unit (role provisional, awaiting approval)'

source = bpy.data.collections.new('SOURCE')
scene.collection.children.link(source)
scene.collection.objects.unlink(high)
source.objects.link(high)
source.hide_render = source.hide_viewport = True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source/CargoB.blend'))
select_only([low])
bpy.ops.export_scene.gltf(filepath=str(OUT / 'source/CargoB_Authored.glb'),
    export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
    export_extras=True, export_materials='EXPORT', export_image_format='AUTO')
(OUT / 'source/build-metrics.json').write_text(json.dumps({
    'sourceTriangles': tris(high), 'weldedTriangles': welded, 'triangles': low_tris,
    'arrivedDimensions': list(arrived),
    'sourceDimensions': list(spans(high)),
    'voxelSize': VOXEL, 'dissolveDegrees': DISSOLVE_DEG,
    'method': 'voxel remesh + planar dissolve + collapse, then selected-to-active bake '
              '(colour, normal, roughness, metalness)',
    'textureSize': SIZE, 'materialCount': 1}, indent=2) + '\n')
print('CARGO-B BUILD:', low_tris, 'triangles from', tris(high))
