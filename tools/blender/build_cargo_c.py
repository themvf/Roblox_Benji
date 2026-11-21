"""Author the wrecked cargo unit. Run with Blender --factory-startup -b.

Third of the Cargo set, after tools/blender/build_cargo.py (destroyed, dark) and
tools/blender/build_cargo_b.py (intact, white). Same optimize-and-bake method, with
one extra step this source forces.

THE GROUND DISC. This TRELLIS output is not just the container: it sits on a wide
circular snow/ice disc with debris scattered across it (see review/source-a..d.png).
That cannot ship inside a placeable prop. It would z-fight whatever floor it is put
on, lock the asset to snowy maps, and spend a large share of both the triangle budget
and the UV atlas on a flat plate. Ground the player stands on is Terrain data in the
map module, not mesh.

The disc cannot be removed by selecting loose parts: the source is 46,141
disconnected components, measured by trials/probe_parts.py, so there is no single
container shell to keep. It is removed by a plane instead. trials/probe_slices.py
measured where that plane goes: from z = -0.3439 up to about -0.2754 the XY footprint
is 0.84 to 0.98 wide and carries tens of thousands of vertices, which is the disc, the
snow mound around the base and the debris. Above -0.2754 the footprint settles to the
container's own 0.606 x 0.760 and stays there for the rest of the height. So the cut
is at -0.2754. It may clip a sliver of the container's own underside, which is hidden
against the floor once placed on a bottom pivot.

Set KEEP_GROUND = True to ship the disc anyway, for a snow-only placement.

Source axes after the rotation: X length, Y depth, Z up. scene_kit fits height.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
import mathutils

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/cargo-c'
# NO COLLAPSE. This is the decision that makes the asset work, and it was reached the
# expensive way. Collapsing the remesh down to a single-mesh budget destroys the flat
# panels, and the damage shows up in the UV atlas rather than in any triangle count:
# with no coplanar regions left, smart_project emits about one island per triangle, the
# atlas comes out as confetti at 53% pure black, and every baked map is noise. Two
# prototypes shaded like a block of ice before trials/probe_uv.py measured why.
# assets/models/cargo/README.md records the same failure on the destroyed unit.
#
# Measured island counts and atlas coverage (trials/probe_uv.py):
#   voxel 0.008 collapsed to 32,000  4,874 islands  29.2%
#   voxel 0.013 collapsed to 32,000  2,144 islands  43.5%
#   voxel 0.013 no collapse          1,995 islands  51.4%
#   voxel 0.018 no collapse          1,135 islands  50.2%  <- used here
#
# So the remesh output ships as-is and scene_kit tiles it. A coarser voxel rounds the
# torn edges a little; that is a far cheaper loss than a noise-textured wreck.
VOXEL = 0.018
# How many meshes scene_kit splits the result into; must match `tile` in scenes.json.
# The Roblox 10,000-triangle limit is per mesh, so this is the budget multiplier.
TILES = 4
# Bake ray budget, expressed against the voxel, because that is what sets how far the
# remeshed surface can sit from the source. Absolute numbers copied from the
# closed-box siblings were wrong here in both directions: 0.03 sampled through the
# thin walls, and 0.004 missed entirely and left black patches.
CAGE_EXTRUSION = VOXEL * 0.6
MAX_RAY_DISTANCE = VOXEL * 1.8
SMOOTH_DEG = 20.0
# Tight, from the same probe: a wide margin is what turns many small islands into a
# mostly-empty sheet.
ISLAND_MARGIN = 0.001
# Drop remesh shells under this fraction of the largest shell's face count. See
# prune_shells: without it the collapse floors at 16,472 triangles and breaches the cap.
SHELL_KEEP_RATIO = 0.02
KEEP_GROUND = False
GROUND_CUT_Z = -0.2754  # measured by trials/probe_slices.py
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

    Not `ob.dimensions`: that is derived from a cached bound_box which does not
    refresh after a mesh-data edit, so a working transform looks like a no-op.
    Verified in Blender 4.3.2."""
    co = [v.co for v in ob.data.vertices]
    return tuple(round(max(c[i] for c in co) - min(c[i] for c in co), 4) for i in range(3))


def prune_shells(ob, keep_ratio):
    """Delete remesh shells smaller than `keep_ratio` of the largest one.

    Why this exists: the source is 46,141 disconnected components, so the voxel
    remesh does not produce one shell. It produces the container plus thousands of
    tiny closed blobs, one per cluster of stray triangles. That matters for a hard
    reason, not just tidiness: Blender's Collapse decimate cannot reduce a closed
    shell below four faces, so thousands of blobs put a floor under the triangle
    count. The first run of this generator stalled at 16,472 triangles against a
    7,500 target and blew the 10,000 Roblox cap.

    Union-find over edges rather than a recursive flood fill: at roughly a million
    faces, recursion depth and per-vertex Python calls both become the bottleneck.
    """
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    parent = list(range(len(bm.verts)))

    def find(i):
        root = i
        while parent[root] != root:
            root = parent[root]
        while parent[i] != root:  # path compression, iterative
            parent[i], i = root, parent[i]
        return root

    bm.verts.index_update()
    for edge in bm.edges:
        a, b = find(edge.verts[0].index), find(edge.verts[1].index)
        if a != b:
            parent[a] = b
    counts = {}
    for face in bm.faces:
        root = find(face.verts[0].index)
        counts[root] = counts.get(root, 0) + 1
    if not counts:
        bm.free()
        return
    largest = max(counts.values())
    floor = max(4, int(largest * keep_ratio))
    doomed_roots = {root for root, n in counts.items() if n < floor}
    doomed = [v for v in bm.verts if find(v.index) in doomed_roots]
    print('SHELLS %d, largest %d faces, dropping %d below %d faces'
          % (len(counts), largest, len(doomed_roots), floor), flush=True)
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


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
raw_tris = tris(high)

# ---- drop the snow disc, the mound and the debris ----
# Delete vertices below the plane and let their faces go with them. The resulting
# ragged bottom edge does not matter: the remesh closes it, and it ends up against
# the floor. A bisect would be tidier on clean topology and is pointless on soup.
if not KEEP_GROUND:
    bm = bmesh.new()
    bm.from_mesh(high.data)
    doomed = [v for v in bm.verts if v.co.z < GROUND_CUT_Z]
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    bm.to_mesh(high.data)
    bm.free()
    high.data.update()
    print('GROUND CUT', raw_tris, '->', tris(high), 'at z', GROUND_CUT_Z, flush=True)
    assert tris(high) > raw_tris * 0.3, 'ground cut removed too much; recheck GROUND_CUT_Z'

# ---- put the long horizontal axis on X ----
# Rotate the MESH DATA, not the object: the glTF importer leaves rotation_mode on
# QUATERNION, so setting rotation_euler is a silent no-op and transform_apply then
# reports FINISHED while the vertices never move. Verified in Blender 4.3.2.
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
low.name = 'CargoUnit_Wrecked'
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
prune_shells(low, SHELL_KEEP_RATIO)
print('PRUNED  ->', tris(low), flush=True)
# No planar dissolve and no collapse. The dissolve would shed triangles while keeping
# flats, but probe_uv.py measured this exact configuration without it, so the shipped
# build matches what was validated rather than something adjacent to it.
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SMOOTH_DEG))
low.data.uv_layers.new(name='UVMap')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=ISLAND_MARGIN)
bpy.ops.object.mode_set(mode='OBJECT')
low_tris = tris(low)
# The authored mesh is deliberately over the 10,000 per-mesh cap. scene_kit's
# `tile` splits it, and its own check() fails if any single tile still breaches the
# cap. The ceiling here is what TILES tiles can absorb.
assert low_tris < 10000 * TILES, (low_tris, TILES)

# ---- bake maps from the dense source ----
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
bake = scene.render.bake
bake.use_selected_to_active = True
# Much tighter than the closed-box siblings, which use 0.008 / 0.03. Those numbers
# are wrong for this asset and produced a first prototype that shaded like a block of
# ice (crystalline facets across flat panels, mirror highlights). This is a hollow
# shell of thin torn sheets with an open front, so a long ray cast from the low mesh
# sails through the near wall and samples whatever it meets next -- the interior face,
# or the far side of the container. Those wrong hits land in the normal and roughness
# maps as noise, and noise in a normal map reads exactly like shattered glass.
# The remesh voxel is 0.003, so the real surface is always within about one voxel.
bake.cage_extrusion = CAGE_EXTRUSION
bake.max_ray_distance = MAX_RAY_DISTANCE
bake.margin = 8

bake_mat = bpy.data.materials.new('CargoC_Bake')
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


normal = bake_map('CargoC_Normal', 'NORMAL')
rough = bake_map('CargoC_Roughness', 'ROUGHNESS')


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
color = bake_map('CargoC_Color', 'EMIT', data=False)
emit_input('Metallic')
metal = bake_map('CargoC_Metalness', 'EMIT')

# ---- delivery material from the baked maps ----
mat = bpy.data.materials.new('CargoC_Baked')
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
low['Role'] = 'Wrecked cargo unit (role provisional, awaiting approval)'

source = bpy.data.collections.new('SOURCE')
scene.collection.children.link(source)
scene.collection.objects.unlink(high)
source.objects.link(high)
source.hide_render = source.hide_viewport = True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source/CargoC.blend'))
select_only([low])
bpy.ops.export_scene.gltf(filepath=str(OUT / 'source/CargoC_Authored.glb'),
    export_format='GLB', use_selection=True, export_yup=True, export_apply=True,
    export_extras=True, export_materials='EXPORT', export_image_format='AUTO')
(OUT / 'source/build-metrics.json').write_text(json.dumps({
    'rawTriangles': raw_tris, 'sourceTriangles': tris(high), 'triangles': low_tris,
    'keptGround': KEEP_GROUND, 'groundCutZ': GROUND_CUT_Z,
    'arrivedDimensions': list(arrived), 'sourceDimensions': list(spans(high)),
    'voxelSize': VOXEL, 'shellKeepRatio': SHELL_KEEP_RATIO, 'tiles': TILES,
    'cageExtrusion': CAGE_EXTRUSION, 'maxRayDistance': MAX_RAY_DISTANCE,
    'smoothDegrees': SMOOTH_DEG, 'islandMargin': ISLAND_MARGIN, 'collapsed': False,
    'method': 'ground-disc plane cut, voxel remesh, small-shell prune, NO collapse, then '
              'selected-to-active bake (colour, normal, roughness, metalness); '
              'scene_kit tiles the result because the Roblox cap is per mesh',
    'textureSize': SIZE, 'materialCount': 1}, indent=2) + '\n')
print('CARGO-C BUILD:', low_tris, 'triangles from', tris(high))
