"""Author a ransacked white cargo unit from the saved Midjourney/TRELLIS design.

The earlier voxel result rounded the panels and cannot show an opened interior.
This clean rebuild retains the reference proportions, ribs, corner caps and end
doors, then adds torn panels, a swung door, exposed contents and fallen pieces.
Blender coordinates: X length, Y depth, Z up. One unit is one Roblox stud.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/cargo-b'
N=1024
rng=np.random.default_rng(32)
random.seed(32)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
for folder in ('textures','exports','source','review','trials'):
    (OUT/folder).mkdir(parents=True,exist_ok=True)

swatches={
    'white':((.75,.80,.79),.66,.12),
    'light':((.88,.90,.86),.56,.12),
    'dirty':((.52,.58,.58),.78,.19),
    'dark':((.10,.17,.20),.83,.22),
    'steel':((.29,.34,.35),.59,.66),
    'rust':((.31,.17,.09),.88,.16),
    'soot':((.042,.052,.056),.94,.08),
    'inside':((.19,.30,.34),.76,.18),
    'yellow':((.83,.56,.055),.70,.20),
}
color=np.ones((N,N,4),dtype=np.float32)
rough=np.ones_like(color)
metal=np.ones_like(color)
slots={}
for i,(name,(rgb,r,m)) in enumerate(swatches.items()):
    x=(i%4)*256; y=(i//4)*256
    macro=rng.normal(0,1,(16,16))
    macro=np.repeat(np.repeat(macro,16,axis=0),16,axis=1)
    for _ in range(5):
        macro=(macro+np.roll(macro,1,0)+np.roll(macro,-1,0)+
               np.roll(macro,1,1)+np.roll(macro,-1,1))/5
    fine=rng.normal(0,.025,(256,256))
    patch=color[y:y+256,x:x+256,:3]
    patch[:]=np.clip(np.array(rgb)[None,None,:]+macro[:,:,None]*.055+
                     fine[:,:,None],0,1)
    rough[y:y+256,x:x+256,:3]=np.clip(r+macro[:,:,None]*.07,0,1)
    metal[y:y+256,x:x+256,:3]=m
    if name in ('white','light','dirty'):
        yy,xx=np.ogrid[:256,:256]
        for j in range(155):
            cx=int(rng.integers(7,249)); cy=int(rng.integers(7,249))
            sx=int(rng.integers(1,8)); sy=int(rng.integers(1,5))
            mask=((xx-cx)/sx)**2+((yy-cy)/sy)**2<1
            patch[mask]=(.28,.31,.30) if j%4 else (.34,.19,.11)
            rough[y:y+256,x:x+256,:3][mask]=.85
        for j in range(24):
            cx=int(rng.integers(8,205)); cy=int(rng.integers(6,250))
            patch[cy:cy+(1 if j%3 else 2),cx:cx+int(rng.integers(18,51))]=(
                (.34,.37,.35) if j%4 else (.38,.22,.12))
        for j in range(8):
            cx=int(rng.integers(20,236)); cy=int(rng.integers(20,236))
            radius=int(rng.integers(13,30))
            mask=((xx-cx)/radius)**2+((yy-cy)/(radius*.72))**2<1
            patch[mask]*=.78
    slots[name]=(x,y)

def write_image(name,array,noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(array.ravel())
    im.filepath_raw=str(OUT/'textures'/(name+'.png'))
    im.file_format='PNG'; im.save()
    return im

mat=bpy.data.materials.new('CargoB_Ransacked_Atlas')
mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF')
for name,array,socket,noncolor in (
    ('CargoB_Wreck_Color',color,'Base Color',False),
    ('CargoB_Wreck_Roughness',rough,'Roughness',True),
    ('CargoB_Wreck_Metalness',metal,'Metallic',True)):
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=write_image(name,array,noncolor)
    mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])

source=bpy.data.collections.new('AUTHORED_PARTS')
bpy.context.scene.collection.children.link(source)
parts=[]
def finish(ob,name,surface):
    ob.name=name
    for coll in list(ob.users_collection): coll.objects.unlink(ob)
    source.objects.link(ob)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
    x,y=slots[surface]
    corners=((x+7,y+7),(x+249,y+7),(x+249,y+249),(x+7,y+249))
    shift=random.randrange(4)
    for face in ob.data.polygons:
        for i,loop in enumerate(face.loop_indices):
            px,py=corners[(i+shift)%4]
            uv.data[loop].uv=(px/N,py/N)
    parts.append(ob)
    return ob

def box(name,loc,size,surface='white',bevel=0,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob=bpy.context.object; ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Chamfer','BEVEL')
        mod.width=min(bevel,min(size)/3); mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location=loc
    if rot: ob.rotation_euler=rot
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

def sheet(name,verts,surface):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[tuple(range(len(verts)))])
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(ob)
    return finish(ob,name,surface)

# Broad 8.2 x 4.8 x 6 form and deep end frame preserve the original design.
box('Base',(0,0,.16),(8.12,4.74,.32),'dark',.06)
box('Floor',(0,0,.36),(7.58,4.28,.11),'inside')
box('BackWall',(-3.89,0,3.00),(.20,4.44,5.44),'white')
box('BackInner',(-3.75,0,3),(.055,4.22,5.18),'inside')
box('FarWall',(0,2.26,3),(7.88,.16,5.40),'white')
box('FarInner',(0,2.12,3),(7.55,.04,5.17),'inside')
box('NearWallLeft',(-2.24,-2.26,3),(3.28,.16,5.40),'white')
box('NearWallRight',(3.46,-2.26,3),(1.03,.16,5.40),'white')
box('NearWallTop',(1.0,-2.26,5.13),(3.28,.16,1.14),'white')
box('NearWallBottom',(1.0,-2.26,.83),(3.28,.16,1.06),'white')
box('NearInnerLeft',(-2.24,-2.13,3),(3.1,.04,5.18),'inside')
box('NearInnerRight',(3.43,-2.13,3),(1.0,.04,5.18),'inside')
box('RoofRear',(-2.61,0,5.82),(2.89,4.54,.20),'dirty')
box('RoofFront',(3.32,0,5.82),(1.45,4.54,.20),'dirty')
box('RoofFar',(0,1.53,5.81),(7.78,1.46,.18),'white')
box('RoofNear',(0,-1.80,5.81),(7.78,.83,.18),'white')
for x in (-3.88,3.88):
    for y in (-2.24,2.24):
        box(f'Corner_{x}_{y}',(x,y,3),(.43,.44,5.83),'dirty',.07)
        for z in (.27,5.72):
            box(f'Cap_{x}_{y}_{z}',(x,y,z),(.58,.59,.47),'dark',.07)
for y in (-2.35,2.35):
    for z in (.32,5.70):
        box(f'SideRail_{y}_{z}',(0,y,z),(8.05,.20,.25),'dirty',.035)
for x in (-3.05,-1.73,2.98):
    box(f'NearRib_{x}',(x,-2.415,3),(.14,.16,5.28),'light',.025)
for x in (-3.08,-1.66,-.24,1.18,2.60):
    box(f'FarRib_{x}',(x,2.405,3),(.13,.15,5.25),'dirty',.024)
for x in (-3.12,-1.7):
    box(f'NearInset_{x}',(x,-2.408,3),(1.12,.022,4.85),'light',.022)
    for z in (1.22,4.76):
        box(f'NearInsetMark_{x}_{z}',(x,-2.43,z),(.93,.012,.035),'steel')
for x in (-3.08,-1.66,-.24,1.18,2.60):
    box(f'FarInset_{x}',(x,2.408,3),(1.12,.02,4.80),'white',.02)
for z in (1.13,4.90):
    box(f'NearDamageRail_{z}',(1.02,-2.432,z),(3.20,.055,.10),'steel',.016)

# A ragged side opening is cut into the actual wall, exposing cargo and floor.
sheet('BurnedLeft',[( -.65,-2.448,1.31),(-.28,-2.448,1.51),(-.44,-2.448,3.10),
                    (-.09,-2.448,4.70),(-.65,-2.448,4.72)],'soot')
sheet('BurnedTop',[(-.33,-2.45,4.58),(.40,-2.45,4.31),(1.02,-2.45,4.65),
                   (1.91,-2.45,4.27),(2.71,-2.45,4.59)],'soot')
sheet('BurnedRight',[(2.54,-2.45,4.55),(2.83,-2.45,4.04),(2.61,-2.45,3.00),
                     (2.87,-2.45,1.48),(2.58,-2.45,1.26)],'soot')
for i,(x,z,ang) in enumerate(((-.26,1.79,.34),(.12,3.12,-.26),
                              (2.73,2.68,.37),(1.50,4.49,-.37))):
    box(f'PriedLip_{i}',(x,-2.49,z),(.64,.065,.15),'steel',.017,(0,ang,0))
for i,(x,y,z) in enumerate(((.08,-2.49,4.19),(1.30,-2.50,4.40),
                            (2.42,-2.50,4.06))):
    sheet(f'JaggedEdge_{i}',[(x-.27,y,z),(x+.18,y-.23,z-.28),
                             (x+.37,y,z+.06)],'dirty')

# The +X double doors are opened and forced: a bent jamb, one swung door,
# one detached door lying in the interior. The aperture is genuinely open.
box('DoorSill',(3.93,0,.33),(.31,4.38,.45),'dark',.04)
box('DoorLeftJamb',(3.94,-2.01,3),(.34,.32,5.35),'dirty',.035)
box('DoorRightJamb',(3.94,2.01,3),(.34,.32,5.35),'dirty',.035)
box('DoorLintel',(3.94,0,5.64),(.34,4.15,.40),'dirty',.035)
box('DoorOpeningSoot',(4.13,-1.85,3.2),(.025,.08,4.67),'soot')
box('SwungDoor',(4.53,2.76,2.76),(.15,1.85,4.68),'light',.045,
    (0,0,math.radians(-39)))
box('SwungDoorInset',(4.63,2.83,2.78),(.035,1.53,4.34),'dirty',.018,
    (0,0,math.radians(-39)))
for z in (1.03,2.90,4.66):
    box(f'SwungDoorBrace_{z}',(4.67,2.84,z),(.055,1.65,.10),'steel',.01,
        (0,0,math.radians(-39)))
box('DetachedDoor',(1.57,.34,1.55),(.24,1.67,3.80),'light',.034,
    (math.radians(65),math.radians(-13),math.radians(23)))
box('DetachedDoorBack',(1.55,.30,1.57),(.12,1.40,3.48),'dirty',.016,
    (math.radians(65),math.radians(-13),math.radians(23)))
for z in (1.0,2.8,4.63):
    box(f'Hinge_{z}',(4.1,2.07,z),(.25,.24,.21),'steel',.03)

# Scavenged interior: opened cases, a collapsed rack, loose panels and scrap.
for i,(x,y,z,rz) in enumerate(((-2.18,-.82,.65,.28),(-.67,.76,.62,-.37))):
    box(f'Case_{i}',(x,y,z),(1.11,.82,.58),'dirty',.045,(0,.09,rz))
    box(f'CaseEmpty_{i}',(x,y,z+.31),(.91,.64,.018),'soot',.003,(0,.09,rz))
    box(f'CaseLid_{i}',(x-.54,y-.09,z+.56),(.85,.12,.54),'light',.018,
        (0,math.radians(-36),rz))
box('FallenRack',(1.09,1.56,1.65),(2.22,.11,2.29),'inside',.028,
    (math.radians(23),math.radians(-22),math.radians(16)))
for i,(x,y,z) in enumerate(((-1.30,1.83,3.89),(.36,1.85,3.34),
                            (1.82,1.78,2.73))):
    box(f'BentShelf_{i}',(x,y,z),(1.43,.44,.10),'steel',.02,
        (math.radians(9*i),math.radians(-13-i*7),math.radians(i*14)))
for i,(x,y,rz) in enumerate(((-2.63,-1.17,.22),(-1.27,.29,-.4),
                            (.13,-.75,.64),(2.04,-1.00,-.31),(2.86,.91,.52))):
    box(f'Scrap_{i}',(x,y,.42),(.58,.23,.07),
        'steel' if i%2 else 'rust',.012,(0,0,rz))
box('LoosePanel',(-2.86,-1.86,.88),(1.04,.075,1.26),'dirty',.022,
    (math.radians(16),math.radians(22),math.radians(-31)))
for i,(x,y,z) in enumerate(((-.44,-.44,5.64),(.65,.83,5.61),
                            (1.91,-.79,5.59))):
    box(f'TornRoof_{i}',(x,y,z),(1.10,.65,.11),'steel',.013,
        (math.radians(10+i*6),math.radians(-18+i*8),math.radians(i*17)))
for i,(x,y) in enumerate(((-3.14,-2.35),(-1.71,-2.35),(2.9,-2.35))):
    box(f'Scuff_{i}',(x,y,.64),(.34,.16,.11),'rust',.01)

# Editable parts and a joined one-material export; no source mesh is overwritten.
source.hide_render=True
export=bpy.data.collections.new('EXPORT')
bpy.context.scene.collection.children.link(export)
copies=[]
for ob in parts:
    dup=ob.copy(); dup.data=ob.data.copy(); export.objects.link(dup); copies.append(dup)
bpy.ops.object.select_all(action='DESELECT')
for ob in copies: ob.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
final=bpy.context.object; final.name='CargoUnit_Ransacked'
final['Role']='Decoration (provisional)'
assert len(final.data.polygons)<10000,len(final.data.polygons)
xs=[v.co.x for v in final.data.vertices]
ys=[v.co.y for v in final.data.vertices]
zs=[v.co.z for v in final.data.vertices]
cx=(min(xs)+max(xs))/2
cy=(min(ys)+max(ys))/2
base=min(zs)
height=max(zs)-base
for v in final.data.vertices:
    v.co.x-=cx
    v.co.y-=cy
    v.co.z=(v.co.z-base)*6/height
final.data.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/CargoB_Wreck.blend'))
bpy.ops.object.select_all(action='DESELECT')
final.select_set(True); bpy.context.view_layer.objects.active=final
bpy.ops.export_scene.gltf(filepath=str(OUT/'exports/CargoUnit.glb'),
                          export_format='GLB',export_image_format='AUTO',
                          use_selection=True,export_apply=True)
print('CARGO-B WRECK polygons:',len(final.data.polygons),flush=True)
