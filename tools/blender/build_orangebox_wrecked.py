"""Clean, ransacked rebuild of the small white/charcoal/orange cargo box.

Preserves the reference's broad proportions, orange latch and dark frame.
Authoring axes: Blender X length, Y depth, Z up; 1 unit = 1 Roblox stud.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/orangebox'
N=1024
random.seed(41)
rng=np.random.default_rng(41)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
for sub in ('source','exports','textures','review','trials'):
    (OUT/sub).mkdir(parents=True,exist_ok=True)

# Transfer fine luminance variation from the saved TRELLIS color atlas. Only
# high-frequency detail is reused: the atlas UV islands do not align with the
# rebuilt geometry, so large source shapes would print unrelated panels here.
trellis_image=bpy.data.images.load(str(OUT/'source/trellis-basecolor.png'))
source_pixels=np.empty(len(trellis_image.pixels),dtype=np.float32)
trellis_image.pixels.foreach_get(source_pixels)
source_rgba=source_pixels.reshape((trellis_image.size[1],
                                  trellis_image.size[0],4))
source_gray=(source_rgba[:,:,0]*.30+source_rgba[:,:,1]*.59+
             source_rgba[:,:,2]*.11)
source_blur=source_gray.copy()
for shift in (3,7,15):
    source_blur+=np.roll(source_gray,shift,axis=0)
    source_blur+=np.roll(source_gray,-shift,axis=0)
    source_blur+=np.roll(source_gray,shift,axis=1)
    source_blur+=np.roll(source_gray,-shift,axis=1)
source_blur/=13
source_detail=np.clip(source_gray-source_blur,-.20,.20)
del source_pixels,source_rgba,source_gray,source_blur

swatches={
    'white':((.73,.75,.72),.68,.13),
    'light':((.84,.85,.81),.61,.14),
    'dirty':((.52,.55,.52),.79,.18),
    'charcoal':((.11,.13,.14),.73,.37),
    'frame':((.24,.27,.27),.67,.57),
    'orange':((.82,.34,.055),.62,.20),
    'orange_worn':((.57,.22,.045),.77,.19),
    'soot':((.072,.067,.061),.94,.08),
    'steel':((.36,.40,.39),.60,.72),
    'interior':((.21,.25,.26),.79,.25),
    'amber':((.99,.59,.095),.54,.16),
    'rust':((.32,.16,.07),.88,.13),
}
color=np.ones((N,N,4),dtype=np.float32)
rough=np.ones_like(color)
metal=np.ones_like(color)
height=np.zeros((N,N),dtype=np.float32)
slots={}
for i,(name,(rgb,r,m)) in enumerate(swatches.items()):
    x=(i%4)*256; y=(i//4)*256
    macro=rng.normal(0,1,(16,16))
    macro=np.repeat(np.repeat(macro,16,0),16,1)
    for _ in range(5):
        macro=(macro+np.roll(macro,1,0)+np.roll(macro,-1,0)+
               np.roll(macro,1,1)+np.roll(macro,-1,1))/5
    fine=rng.normal(0,.010,(256,256))
    crop_x=int(rng.integers(0,source_detail.shape[1]-256))
    crop_y=int(rng.integers(0,source_detail.shape[0]-256))
    transferred=source_detail[crop_y:crop_y+256,crop_x:crop_x+256]
    patch=color[y:y+256,x:x+256,:3]
    patch[:]=np.clip(np.array(rgb)[None,None,:]+macro[:,:,None]*.026+
                     fine[:,:,None]+transferred[:,:,None]*.11,0,1)
    rough[y:y+256,x:x+256,:3]=np.clip(r+.045*macro[:,:,None],0,1)
    metal[y:y+256,x:x+256,:3]=m
    height_patch=height[y:y+256,x:x+256]
    height_patch[:]=macro*.010+fine*.25+transferred*.055
    if name in ('white','light','dirty','orange','orange_worn'):
        yy,xx=np.ogrid[:256,:256]
        # Small irregular patches where paint has been rubbed to bare metal.
        edge_distance=np.minimum.reduce(np.broadcast_arrays(
            xx-8,247-xx,yy-8,247-yy))
        edge_wear=(edge_distance>=0)&(edge_distance<
            (2.0+np.maximum(macro,0)*4.0+np.maximum(transferred,0)*9.0))
        patch[edge_wear]=(.35,.38,.37)
        rough[y:y+256,x:x+256,:3][edge_wear]=.72
        metal[y:y+256,x:x+256,:3][edge_wear]=.62
        height_patch[edge_wear]-=.018
        for j in range(72):
            cx=int(rng.integers(7,249));cy=int(rng.integers(7,249))
            sx=int(rng.integers(1,7));sy=int(rng.integers(1,4))
            mask=((xx-cx)/sx)**2+((yy-cy)/sy)**2<1
            patch[mask]=(.28,.31,.30) if j%5 else (.37,.18,.08)
            rough[y:y+256,x:x+256,:3][mask]=.83
            metal[y:y+256,x:x+256,:3][mask]=.54 if j%5 else .18
            height_patch[mask]-=.025
        for j in range(11):
            cx=int(rng.integers(10,210));cy=int(rng.integers(6,249))
            length=int(rng.integers(15,46))
            patch[cy:cy+1,cx:cx+length]=(
                (.32,.35,.34) if j%3 else (.38,.21,.09))
            height_patch[cy:cy+1,cx:cx+length]-=.012
    slots[name]=(x,y)

dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.5
dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.5
nx=-3.0*dx
ny=-3.0*dy
length=np.sqrt(nx*nx+ny*ny+1.0)
normal=np.ones_like(color)
normal[:,:,0]=.5+.5*nx/length
normal[:,:,1]=.5+.5*ny/length
normal[:,:,2]=.5+.5/length

def image(name,data,noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(data.ravel())
    im.filepath_raw=str(OUT/'textures'/(name+'.png'))
    im.file_format='PNG';im.save()
    return im

mat=bpy.data.materials.new('OrangeBox_Ransacked_Atlas')
mat.use_nodes=True
p=mat.node_tree.nodes.get('Principled BSDF')
for name,data,socket,noncolor in (
    ('OrangeBox_Color',color,'Base Color',False),
    ('OrangeBox_Roughness',rough,'Roughness',True),
    ('OrangeBox_Metalness',metal,'Metallic',True)):
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=image(name,data,noncolor)
    mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
normal_tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
normal_tex.image=image('OrangeBox_Normal',normal,True)
normal_node=mat.node_tree.nodes.new('ShaderNodeNormalMap')
normal_node.inputs['Strength'].default_value=.7
mat.node_tree.links.new(normal_tex.outputs['Color'],normal_node.inputs['Color'])
mat.node_tree.links.new(normal_node.outputs['Normal'],p.inputs['Normal'])

authored=bpy.data.collections.new('AUTHORED_PARTS')
bpy.context.scene.collection.children.link(authored)
parts=[]
def finish(ob,name,surface):
    ob.name=name
    for coll in list(ob.users_collection):coll.objects.unlink(ob)
    authored.objects.link(ob)
    ob.data.materials.clear();ob.data.materials.append(mat)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name='UVMap')
    x,y=slots[surface]
    corners=((x+8,y+8),(x+248,y+8),(x+248,y+248),(x+8,y+248))
    shift=random.randrange(4)
    for face in ob.data.polygons:
        for i,loop in enumerate(face.loop_indices):
            px,py=corners[(i+shift)%4]
            uv.data[loop].uv=(px/N,py/N)
    parts.append(ob)
    return ob

def box(name,loc,size,surface='white',bevel=0,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob=bpy.context.object;ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Chamfer','BEVEL')
        mod.width=min(bevel,min(size)/3);mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location=loc
    if rot:ob.rotation_euler=rot
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

def sheet(name,verts,surface):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[tuple(range(len(verts)))])
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(ob)
    return finish(ob,name,surface)

def bolt(name,loc,surface='steel',radius=.034,rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=.018)
    ob=bpy.context.object
    ob.location=loc
    if rot:ob.rotation_euler=rot
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

# Six-stud long crate with dark protective base and white sloped/chamfered
# manufactured panels. A real side aperture and opened end show the contents.
box('SkidBase',(0,0,.22),(5.92,4.00,.44),'charcoal',.10)
box('Floor',(0,0,.49),(5.52,3.59,.10),'interior')
for y in (-1.87,1.87):
    box(f'BaseRail_{y}',(0,y,.47),(5.77,.22,.18),'frame',.03)
for x in (-2.78,2.78):
    box(f'BaseRailEnd_{x}',(x,0,.47),(.24,3.77,.18),'frame',.03)
box('FarWall',(0,1.83,2.05),(5.65,.16,3.10),'white')
box('FarInner',(0,1.70,2.05),(5.40,.04,2.93),'interior')
box('LeftWall',(-2.75,0,2.05),(.18,3.68,3.10),'dirty')
box('LeftInner',(-2.62,0,2.05),(.04,3.41,2.89),'interior')
box('NearLeft',(-2.02,-1.83,2.05),(1.51,.16,3.10),'white')
box('NearRight',(2.54,-1.83,2.05),(.78,.16,3.10),'white')
# The blast broke the middle of the upper wall away; two short pieces remain.
box('NearTopLeft',(-.97,-1.83,3.31),(.76,.16,.58),'white')
box('NearTopRight',(1.76,-1.83,3.31),(.51,.16,.58),'dirty',.018,
    (0,math.radians(-11),0))
box('NearBottom',(.33,-1.83,.85),(3.36,.16,.71),'white')
box('NearInnerLeft',(-2.02,-1.70,2.05),(1.35,.04,2.89),'interior')
box('NearInnerRight',(2.52,-1.70,2.05),(.72,.04,2.89),'interior')
# Most of the lid has been pried off. Rear and side frame remain so the
# silhouette still reads as the reference's protected sci-fi cargo case.
box('LidRear',(0,1.00,3.62),(5.76,1.90,.25),'frame',.055)
box('LidLeft',(-2.21,-1.31,3.62),(1.22,.70,.25),'frame',.04)
box('LidRight',(2.35,-1.27,3.62),(.93,.76,.25),'frame',.04)
box('LidFrontRailLeft',(-1.98,-1.84,3.48),(1.81,.22,.25),
    'frame',.035)
box('LidFrontRailRight',(2.35,-1.84,3.48),(1.23,.22,.25),
    'frame',.035)
for x in (-2.70,2.70):
    for y in (-1.70,1.70):
        box(f'CornerPost_{x}_{y}',(x,y,2.00),(.34,.36,3.27),'dirty',.06)
        for z in (.28,3.55):
            box(f'CornerCap_{x}_{y}_{z}',(x,y,z),(.48,.46,.40),'charcoal',.065)
for x in (-2.13,-.72,.68,2.10):
    box(f'FarPanelFrame_{x}',(x,1.946,2.08),(1.20,.045,2.67),'dirty',.025)
    box(f'FarInset_{x}',(x,1.974,2.08),(1.03,.018,2.45),'light',.02)
for x in (-2.27,-1.42):
    box(f'NearPanelFrame_{x}',(x,-1.946,2.05),(.68,.045,2.61),'dirty',.02)
    box(f'NearInset_{x}',(x,-1.974,2.05),(.57,.018,2.45),'light',.012)
for y in (-1.22,0,1.22):
    box(f'LeftEndInset_{y}',(-2.866,y,2.10),(.045,.93,2.60),'light',.023)
for y in (-1.84,1.84):
    box(f'EndStripe_{y}',(0,y,3.40),(5.47,.035,.085),'charcoal')
for x in (-2.80,2.80):
    box(f'EndTrim_{x}',(x,0,3.40),(.05,3.43,.09),'charcoal')
for x in (-1.64,1.64):
    box(f'OrangeBaseLamp_{x}',(x,-1.963,.33),(.66,.03,.15),'orange',.018)

# Torn near side, orange latches and fractured lip.
sheet('SootLeft',[(-1.22,-1.997,1.08),(-.96,-1.997,1.32),
                  (-1.06,-1.997,2.66),(-.79,-1.997,3.10),
                  (-1.23,-1.997,3.10)],'soot')
sheet('SootTopLeft',[(-1.27,-1.999,3.50),(-.69,-1.999,3.38),
                     (-.52,-1.999,2.90),(-.91,-1.999,2.76)],'soot')
sheet('SootTopRight',[(1.39,-1.999,2.81),(1.70,-1.999,3.37),
                      (2.12,-1.999,3.50),(2.13,-1.999,2.91)],'soot')
sheet('SootRight',[(1.96,-1.999,2.95),(2.21,-1.999,2.67),
                   (2.06,-1.999,1.84),(2.23,-1.999,1.24),
                   (1.92,-1.999,1.10)],'soot')
for i,(x,z,a) in enumerate(((-.95,1.40,.3),(-.50,2.88,-.33),
                            (1.91,2.15,.4),(.80,1.10,-.24))):
    box(f'BentLip_{i}',(x,-2.03,z),(.49,.055,.11),'steel',.014,(0,a,0))
for i,(x,z) in enumerate(((-.42,2.86),(.63,2.91),(1.73,2.75))):
    sheet(f'TornShard_{i}',[(x-.19,-2.01,z),(x+.08,-2.26,z-.25),
                            (x+.26,-2.01,z+.04)],'dirty')
for x in (-1.49,1.75):
    box(f'OrangeHinge_{x}',(x,-2.02,3.15),(.20,.14,.25),'orange_worn',.028)

# End loading hatch (+X) forced open. One panel is swung away and the other
# lies inside. These are manufactured sections, not a black flat decal.
box('EndSill',(2.83,0,.56),(.24,3.45,.27),'frame',.035)
box('EndLeftJamb',(2.83,-1.62,2.03),(.22,.26,2.95),'frame',.035)
box('EndRightJamb',(2.83,1.62,2.03),(.22,.26,2.95),'frame',.035)
box('EndTop',(2.83,0,3.48),(.25,3.38,.25),'frame',.035)
box('EndOpenDoor',(3.34,2.18,2.01),(.13,1.54,2.61),'white',.045,
    (0,0,math.radians(-39)))
box('EndOpenInset',(3.44,2.22,2.00),(.03,1.31,2.32),'light',.018,
    (0,0,math.radians(-39)))
box('EndOrangeHandle',(3.48,2.21,2.00),(.04,.58,.40),'orange',.028,
    (0,0,math.radians(-39)))
box('EndHandleVoid',(3.51,2.23,2.00),(.012,.43,.24),'charcoal',.006,
    (0,0,math.radians(-39)))
for z in (.91,2.04,3.11):
    box(f'EndHinge_{z}',(2.95,1.58,z),(.23,.23,.19),'orange_worn',.028)

# Ransacked orange cartridges and containers, seen through both openings.
for i,(x,y,z,rz) in enumerate(((-1.12,-.34,.74,.18),
                              (.32,.49,.78,-.39),(1.54,-.64,.73,.51))):
    box(f'CargoCase_{i}',(x,y,z),(1.01,.66,.43),'orange_worn',.04,
        (0,math.radians(4+i*6),rz))
    box(f'CargoVoid_{i}',(x,y,z+.25),(.84,.50,.017),'soot',.003,
        (0,math.radians(4+i*6),rz))
    box(f'CargoLid_{i}',(x-.47,y-.04,z+.42),(.72,.09,.39),
        'orange' if i%2 else 'dirty',.02,
        (0,math.radians(-28-i*6),rz))
box('FallenDivider',(.40,1.14,1.27),(2.55,.10,1.51),'dirty',.028,
    (math.radians(20),math.radians(-16),math.radians(19)))
for i,(x,y,rz) in enumerate(((-1.61,-.97,.48),(-.53,.08,-.42),
                            (.92,-.81,.31),(1.86,.71,-.66))):
    box(f'LooseScrap_{i}',(x,y,.55),(.39,.16,.045),
        'steel' if i%2 else 'rust',.008,(0,0,rz))
box('DroppedHatch',(1.30,.54,1.07),(.10,1.31,1.90),'light',.026,
    (math.radians(61),math.radians(-10),math.radians(14)))
box('DroppedHatchOrange',(1.33,.55,1.11),(.025,.61,.36),'orange',.018,
    (math.radians(61),math.radians(-10),math.radians(14)))
for i,(x,y,z,ang) in enumerate(((-.43,-.23,3.56,.24),
                                (.77,-.38,3.57,-.28),
                                (1.88,.09,3.58,.39))):
    box(f'PeeledLid_{i}',(x,y,z),(.77,.42,.085),'frame',.015,(0,ang,0))
for x in (-1.80,1.82):
    box(f'OrangeLatch_{x}',(x,-1.995,3.43),(.22,.09,.28),'orange_worn',.018)

# Mechanical detail pass. Larger shapes remain readable at game distance;
# individual fasteners and scratches reward a close look without another
# material or a dense baked scan.
# Body panel reveals and locking rails on the damaged long side.
for x in (-2.27,-1.42):
    for z in (1.10,2.88):
        box(f'NearPanelReveal_{x}_{z}',(x,-1.991,z),(.48,.011,.027),
            'frame',.004)
    for z in (1.01,3.03):
        bolt(f'NearPanelBolt_{x}_{z}',(x-.23,-2.007,z),
             'steel',.026,(math.pi/2,0,0))
for z in (.99,1.23,2.82,3.04):
    box(f'OpeningRimLeft_{z}',(-1.14,-2.02,z),(.18,.07,.055),
        'charcoal',.01)
    box(f'OpeningRimRight_{z}',(2.08,-2.02,z),(.18,.07,.055),
        'charcoal',.01)
for x,z in ((-.87,3.08),(.13,3.06),(1.16,3.04),(2.03,3.03),
            (-1.10,1.07),(1.96,1.09)):
    bolt(f'RuptureBolt_{x}_{z}',(x,-2.055,z),'rust',.036,
         (math.pi/2,0,0))
box('LatchControlFrame',(-2.27,-2.011,2.02),(.39,.035,.62),
    'frame',.024)
box('LatchControlInset',(-2.27,-2.033,2.02),(.28,.012,.49),
    'charcoal',.008)
for i,z in enumerate((1.89,2.03,2.17)):
    box(f'LatchControlLight_{i}',(-2.27,-2.046,z),(.15,.009,.037),
        'amber' if i==0 else 'orange_worn',.003)

# Original reference's side latch pair, now bent and partly torn from the lid.
for i,x in enumerate((-1.78,1.81)):
    box(f'LatchHousing_{i}',(x,-1.994,3.29),(.35,.20,.46),
        'charcoal',.033)
    box(f'LatchTongue_{i}',(x,-2.102,3.18),(.18,.10,.47),
        'orange' if i==0 else 'orange_worn',.016,
        (math.radians(11 if i==0 else -18),0,0))
    bolt(f'LatchPin_{i}',(x,-2.168,3.31),'steel',.039,
         (math.pi/2,0,0))

# Vents, grilles and a small orange inspection port on the hinged door.
box('DoorControlFrame',(3.458,2.22,2.13),(.034,.93,.91),
    'frame',.026,(0,0,math.radians(-39)))
box('DoorControlFace',(3.481,2.23,2.13),(.020,.71,.68),
    'charcoal',.015,(0,0,math.radians(-39)))
for i,z in enumerate((1.42,1.55,1.68,2.61,2.74)):
    box(f'DoorVent_{i}',(3.493,2.22,z),(.019,.51,.036),
        'soot',.003,(0,0,math.radians(-39)))
for z in (.83,3.19):
    box(f'DoorCrossBrace_{z}',(3.482,2.21,z),(.033,1.34,.066),
        'steel',.009,(0,0,math.radians(-39)))
for z in (1.09,2.10,3.04):
    bolt(f'DoorHingePin_{z}',(2.972,1.61,z),'steel',.047,
         (math.pi/2,0,0))

# The quiet rear now has the vented instrument housing shown in the source.
box('RearInstrumentFrame',(-2.889,0,2.06),(.065,1.03,1.49),
    'charcoal',.035)
box('RearInstrumentInset',(-2.927,0,2.06),(.022,.83,1.29),
    'frame',.020)
box('RearOrangePort',(-2.948,0,1.75),(.014,.59,.47),
    'orange',.034)
box('RearPortVoid',(-2.960,0,1.75),(.010,.39,.29),
    'charcoal',.022)
for i,z in enumerate((2.39,2.49,2.59)):
    box(f'RearInstrumentVent_{i}',(-2.955,0,z),(.012,.62,.040),
        'soot',.003)
for y in (-1.37,1.37):
    for z in (.77,3.19):
        bolt(f'RearFastener_{y}_{z}',(-2.916,y,z),'steel',.037,
             (0,math.pi/2,0))

# Ribbed lid and a recessed orange service bar on the rear roof plate.
for x in (-2.10,-1.32,-.54,.24,1.02,1.80,2.47):
    box(f'RoofRib_{x}',(x,1.01,3.756),(.052,1.52,.038),
        'charcoal',.007)
box('RoofServicePocket',(-1.99,1.12,3.757),(.65,.75,.035),
    'charcoal',.01)
for y in (.86,1.08,1.30):
    box(f'RoofServiceSlat_{y}',(-1.99,y,3.778),(.43,.075,.016),
        'orange_worn',.005)
for x in (-2.44,2.44):
    for y in (.39,1.60):
        bolt(f'RoofFastener_{x}_{y}',(x,y,3.775),'steel',.032)

# Raised outlines and machine-screw points on the intact reverse side.
for x in (-2.13,-.72,.68,2.10):
    for z in (1.19,2.94):
        box(f'FarPanelSeam_{x}_{z}',(x,1.989,z),(.82,.012,.025),
            'frame',.003)
    for z in (.93,3.12):
        bolt(f'FarPanelBolt_{x}_{z}',(x-.42,1.998,z),
             'steel',.025,(math.pi/2,0,0))
for x in (-1.94,1.94):
    for z in (.21,.38):
        box(f'BaseVent_{x}_{z}',(x,-2.025,z),(.34,.016,.045),
            'soot',.004)
for x in (-2.66,2.66):
    for y in (-1.48,1.48):
        bolt(f'BaseCornerBolt_{x}_{y}',(x,y,.455),'steel',.042)

# Open-case closures, interior tie-downs, and tiny loose components.
for i,(x,y,z,rz) in enumerate(((-1.12,-.34,.74,.18),
                              (.32,.49,.78,-.39),(1.54,-.64,.73,.51))):
    box(f'CaseRim_{i}',(x,y,z+.23),(.91,.57,.035),
        'frame',.008,(0,math.radians(4+i*6),rz))
    for k,offset in enumerate((-.27,.27)):
        box(f'CaseClasp_{i}_{k}',(x+offset,y-.36,z+.06),
            (.12,.045,.16),'steel',.014,(0,0,rz))
for i,(x,y,rz) in enumerate(((-.84,-.93,.37),(.12,-.60,-.42),
                            (1.08,.27,.66),(1.89,-.13,-.22))):
    box(f'LooseOrangeCartridge_{i}',(x,y,.59),(.19,.11,.07),
        'amber' if i%2 else 'orange_worn',.012,(0,0,rz))
for x in (-1.88,0,1.88):
    box(f'FloorTieDown_{x}',(x,1.34,.554),(.35,.27,.035),
        'frame',.01)

# Localized blast pass: the charge vented through the near wall and tore the
# front lid rail. Keep the rest of the crate intact so this reads as a partial
# explosion rather than a fully destroyed container.
for i,(x,z,sx,sz) in enumerate((
    (-1.18,2.54,.21,.41),(-1.19,1.54,.17,.35),
    (2.06,2.50,.20,.40),(2.09,1.47,.16,.37),
    (-.94,3.30,.31,.23),(1.91,3.29,.28,.24),
    (-.42,1.09,.33,.15),(1.38,1.08,.32,.16))):
    box(f'BlastSoot_{i}',(x,-2.015,z),(sx,.019,sz),
        'soot',.010,(0,math.radians((-1)**i*13),0))
for i,verts in enumerate((
    [(-1.30,-2.035,2.47),(-.92,-2.037,2.27),(-1.19,-2.035,1.96)],
    [(-1.23,-2.037,1.75),(-.86,-2.039,1.49),(-1.10,-2.037,1.20)],
    [(2.16,-2.037,2.73),(1.84,-2.038,2.44),(2.08,-2.037,2.15)],
    [(2.15,-2.038,1.70),(1.80,-2.040,1.43),(2.09,-2.038,1.11)],
    [(-.91,-2.038,3.42),(-.56,-2.041,3.09),(-.39,-2.040,3.18)],
    [(1.47,-2.040,3.09),(1.76,-2.039,3.44),(2.06,-2.038,3.25)],
)):
    sheet(f'BlastFeather_{i}',verts,'rust' if i%3==0 else 'soot')

# Displaced white plating exposes hot rust and dark inner steel. The bent
# strips follow the ragged edge; nothing spans the opening like an intact lid.
for i,(x,y,z,rx,ry,rz,length) in enumerate((
    (-.73,-2.17,3.08,.12,-.29,.10,.73),
    (1.99,-2.15,2.81,-.12,.34,-.08,.61),
    (-1.04,-2.12,1.84,.16,.27,-.24,.65))):
    box(f'BlastBentPlate_{i}',(x,y,z),(length,.065,.14),
        'dirty' if i%2 else 'steel',.014,(rx,ry,rz))
    box(f'BlastHeatedEdge_{i}',(x,y-.046,z-.075),(length*.81,.018,.031),
        'rust',.004,(rx,ry,rz))
for i,(x,y,z,rz) in enumerate((
    (-.61,-2.31,.045,-.29),(.43,-2.32,.045,.44),
    (1.69,-2.29,.045,-.56),(2.14,-2.24,.045,.22))):
    box(f'BlastFloorShard_{i}',(x,y,z),(.46,.22,.065),
        'dirty' if i%2 else 'frame',.012,
        (math.radians(11),math.radians(8),rz))
for i,(x,z) in enumerate(((-1.09,2.28),(2.05,2.13),
                          (-.66,3.16),(1.61,3.26))):
    box(f'ExposedInnerRib_{i}',(x,-2.10,z),(.10,.21,.46),
        'charcoal',.011,(0,math.radians(18 if i%2 else -22),0))

# A sheared hinge and smoke-darkened near corner establish the blast origin.
box('ShearedHingeBase',(1.79,-2.12,3.35),(.29,.21,.17),
    'charcoal',.017,(0,math.radians(-21),0))
box('ShearedHingePin',(1.89,-2.25,3.28),(.31,.065,.065),
    'steel',.012,(math.radians(18),math.radians(22),math.radians(-28)))

# Keep editable objects and export only one joined atlas mesh.
authored.hide_render=True
export=bpy.data.collections.new('EXPORT')
bpy.context.scene.collection.children.link(export)
copies=[]
for ob in parts:
    dup=ob.copy();dup.data=ob.data.copy();export.objects.link(dup);copies.append(dup)
bpy.ops.object.select_all(action='DESELECT')
for ob in copies:ob.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
final=bpy.context.object;final.name='OrangeBox_Ransacked'
final['Role']='Decoration (provisional)'
assert len(final.data.polygons)<10000,len(final.data.polygons)
xs=[v.co.x for v in final.data.vertices]
ys=[v.co.y for v in final.data.vertices]
zs=[v.co.z for v in final.data.vertices]
cx=(min(xs)+max(xs))/2;cy=(min(ys)+max(ys))/2
base=min(zs);height=max(zs)-base
for v in final.data.vertices:
    v.co.x-=cx;v.co.y-=cy
    v.co.z=(v.co.z-base)*3.8/height
final.data.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/OrangeBox_Ransacked.blend'))
bpy.ops.object.select_all(action='DESELECT')
final.select_set(True);bpy.context.view_layer.objects.active=final
bpy.ops.export_scene.gltf(filepath=str(OUT/'exports/OrangeBoxRansacked.glb'),
                          export_format='GLB',export_image_format='AUTO',
                          use_selection=True,export_apply=True)
print('Orange box polygons:',len(final.data.polygons),flush=True)
