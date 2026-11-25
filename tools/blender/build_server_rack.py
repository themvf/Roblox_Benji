"""Author the reviewed mesh-front rack. Run with Blender --factory-startup -b.

The dense TRELLIS model remains a reference. Surface details are recreated in a
shared PNG atlas; no distorted source geometry or photographic lighting is baked.
"""
from pathlib import Path
import json
import math
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/server-rack'
bpy.ops.wm.read_factory_settings(use_empty=True)
for sub in ('source', 'textures', 'exports', 'review'):
    (OUT / sub).mkdir(parents=True, exist_ok=True)

# One texture/material set. Pixels are authored bottom-up for Blender UV space.
rng = np.random.default_rng(26)
color = np.ones((1024, 1024, 4), dtype=np.float32)
color[:, :, :3] = (0.07, 0.085, 0.10)
rough = np.full((1024, 1024, 4), 0.42, dtype=np.float32)
metal = np.full((1024, 1024, 4), 0.70, dtype=np.float32)
rough[:, :, 3] = metal[:, :, 3] = 1
palette = [(0.075, .095, .12), (.17, .21, .25), (.115, .145, .18),
           (.03, .04, .052), (.12, .15, .18), (.045, .057, .067),
           (.38, .43, .46), (.06, .63, .88)]
for i, rgb in enumerate(palette):
    color[:128, i*128:(i+1)*128, :3] = rgb
    rough[:128, i*128:(i+1)*128, :3] = [.4, .32, .48, .5, .42, .52, .28, .25][i]
    metal[:128, i*128:(i+1)*128, :3] = .05 if i == 7 else .75

# A reusable server fascia: intake vents, drive bays, switches and status lamps.
color[256:768, :, :3] = (.13, .16, .19)
color[270:282, 24:1000, :3] = (.23, .27, .30)
color[737:752, 24:1000, :3] = (.035, .045, .055)
for x in range(52, 566, 22):
    color[322:710, x:x+9, :3] = (.02, .027, .035)
    color[322:710, x+9:x+12, :3] = (.23, .26, .29)
for x in (624, 768):
    color[326:706, x:x+122, :3] = (.035, .045, .056)
    color[338:692, x+9:x+113, :3] = (.105, .13, .155)
    color[360:667, x+86:x+98, :3] = (.22, .25, .28)
color[383:435, 931:954, :3] = (.025, .40, .60)
color[530:557, 931:954, :3] = (.045, .65, .83)
color[618:640, 931:954, :3] = (.11, .27, .18)
# Powder-coated panels: gentle grain, perimeter seams and restrained edge wear.
color[800:, :, :3] = (.115, .145, .175)
grain = rng.normal(0, .003, (224, 1024, 1)).astype(np.float32)
color[800:, :, :3] += grain
for x in (22, 998):
    color[810:1014, x:x+3, :3] = (.055, .07, .085)
for y in (810, 1010):
    color[y:y+3, 22:1001, :3] = (.055, .07, .085)

def image(name, data, data_map=False):
    img = bpy.data.images.new(name, width=1024, height=1024, alpha=True)
    if data_map:
        img.colorspace_settings.name = 'Non-Color'
    img.pixels.foreach_set(np.clip(data, 0, 1).ravel())
    img.filepath_raw = str(OUT / 'textures' / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    return img

mat = bpy.data.materials.new('Rack_SharedAtlas')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes.get('Principled BSDF')
for name, data, socket, is_data in [('Rack_Color', color, 'Base Color', False),
                                     ('Rack_Roughness', rough, 'Roughness', True),
                                     ('Rack_Metalness', metal, 'Metallic', True)]:
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = image(name, data, is_data)
    links.new(tex.outputs['Color'], bsdf.inputs[socket])

source = bpy.data.collections.new('SOURCE')
bpy.context.scene.collection.children.link(source)
parts = []

def finish(ob, name, swatch, front=False, panel=False):
    ob.name = name
    for collection in list(ob.users_collection):
        collection.objects.unlink(ob)
    source.objects.link(ob)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
    lo = Vector([min(v.co[i] for v in ob.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in ob.data.vertices) for i in range(3)])
    for polygon in ob.data.polygons:
        for loop in polygon.loop_indices:
            co = ob.data.vertices[ob.data.loops[loop].vertex_index].co
            u = (co.x-lo.x) / max(hi.x-lo.x, 1e-6)
            v = (co.z-lo.z) / max(hi.z-lo.z, 1e-6)
            if front and polygon.normal.y < -.95:
                uv.data[loop].uv = (.015+u*.97, (266+v*492)/1024)
            elif panel and abs(polygon.normal.x) > .95:
                u = (co.y-lo.y) / max(hi.y-lo.y, 1e-6)
                uv.data[loop].uv = (.008+u*.984, (804+v*215)/1024)
            else:
                uv.data[loop].uv = ((swatch*128+64)/1024, 64/1024)
    parts.append(ob)
    return ob

def box(name, size, loc, swatch=0, bevel=.018, front=False, panel=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('Machined edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(ob, name, swatch, front, panel)

def bolt(name, x, y, z):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=.029, depth=.014,
                                      location=(x,y,z), rotation=(math.pi/2,0,0))
    ob=bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(ob,name,6)

# Width 3.2, depth 3.6, height 8 studs. Front faces Blender -Y (glTF +Z).
box('Roof', (3.2,3.6,.18), (0,0,7.91),1,.025)
box('Plinth', (3.2,3.6,.24), (0,0,.32),0,.025)
for x in (-1.30,1.30):
    for y in (-1.48,1.48):
        box('RubberFoot',(.25,.28,.20),(x,y,.10),3,.025)
for x in (-1.49,1.49):
    for y in (-1.66,1.66):
        box('CornerPost',(.18,.23,7.38),(x,y,4.13),1,.023)
for x in (-1.475,1.475):
    box('InsetSide',(.07,3.05,7.16),(x,0,4.11),2,.012,panel=True)
    for z in (.62,7.60):
        box('SideSeam',(.084,3.0,.035),(x,0,z),3,.005)
box('RearPanel',(2.77,.10,7.16),(0,1.65,4.11),2,.012)
# Recessed drawers occupy the dark interior behind a closed mesh door.
box('DarkInterior',(2.76,2.9,7.02),(0,.12,4.06),3,.01)
for i in range(22):
    z=.75+i*.311
    box('Server_%02d'%i,(2.54,.22,.277),(0,-1.46,z),4,.012,front=True)
    if i%3==0:
        box('StatusLED',(.025,.014,.025),(.97,-1.579,z+.025),7,.002)
for x in (-1.29,1.29):
    box('DoorUpright',(.15,.10,7.14),(x,-1.775,4.12),0,.016)
for z in (.60,7.64):
    box('DoorRail',(2.73,.10,.17),(0,-1.775,z),0,.016)
# Real opaque grille geometry avoids layered transparency and sorting artifacts.
for i in range(27):
    x=-1.16+i*(2.32/26)
    box('MeshVertical',(.009,.014,6.83),(x,-1.811,4.12),5,0)
for i in range(70):
    z=.72+i*(6.79/69)
    box('MeshHorizontal',(2.34,.014,.009),(0,-1.814,z),5,0)
box('DoorHandle',(.065,.09,.57),(1.28,-1.865,3.97),3,.018)
for z in (3.72,4.22):
    box('HandleMount',(.085,.08,.075),(1.28,-1.815,z),1,.01)
for z in (1.12,4.1,7.10):
    box('Hinge',(.115,.12,.19),(-1.39,-1.78,z),1,.014)
for z in (.60,7.64):
    for x in (-1.23,1.23):
        bolt('DoorBolt',x,-1.835,z)
for z in (.34,7.91):
    for x in (-1.45,-1.05,1.05,1.45):
        bolt('FrameBolt',x,-1.812,z)
box('InventoryPlate',(.37,.018,.08),(-.88,-1.825,7.64),6,.004)

export_collection=bpy.data.collections.new('EXPORT')
bpy.context.scene.collection.children.link(export_collection)
bpy.ops.object.select_all(action='DESELECT')
copies=[]
for ob in parts:
    dup=ob.copy(); dup.data=ob.data.copy()
    export_collection.objects.link(dup)
    dup.select_set(True); copies.append(dup)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
export=bpy.context.object
export.name='ServerRack_MeshFront'
bpy.context.scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
export['CanCollide']=False
export['CanTouch']=False
export['CanQuery']=False
export['Anchored']=True
export['Role']='Background decoration; mesh-front cabinet'
source.hide_render=True
source.hide_viewport=True
bpy.context.view_layer.update()
triangles=sum(len(p.vertices)-2 for p in export.data.polygons)
assert triangles < 5000, triangles
assert abs(export.dimensions.z-8)<1e-5, export.dimensions[:]
assert len(export.data.materials)==1
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/ServerRack.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'source/ServerRack_Authored.glb'),
    export_format='GLB',use_selection=True,export_yup=True,export_apply=True,
    export_extras=True,export_materials='EXPORT',export_image_format='AUTO')
(OUT/'source/build-metrics.json').write_text(json.dumps({
    'triangles':triangles,'blenderDimensions':list(export.dimensions),
    'heightStuds':8,'front':'glTF +Z','role':'background decoration',
    'materialCount':1,'surfaceDetail':'recreated PNG atlas, not source GLB bake',
    'sourceComponents':len(parts)},indent=2)+'\n')
print('RACK BUILD:',triangles,'triangles;',list(export.dimensions),'Blender dimensions')
