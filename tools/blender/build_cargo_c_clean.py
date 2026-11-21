"""Clean hard-surface rebuild of the wrecked cargo unit.

Reference: assets/models/cargo-c/source/design-reference.png. The dense
TRELLIS model is retained for provenance; this generator recreates its visual
features without a voxel remesh. Blender axes: +X blown doorway, Z up.
"""
from pathlib import Path
import math
import random

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/cargo-c"
N = 1024
random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

# One atlas material with paint wear, soot, rust and exposed metal.
swatches = {
    "white": ((.78,.84,.86), .58, .17),
    "white_high": ((.91,.94,.94), .48, .13),
    "white_low": ((.61,.70,.74), .67, .20),
    "blue": ((.115,.27,.36), .56, .27),
    "blue_light": ((.22,.42,.52), .5, .25),
    "seam": ((.12,.18,.21), .76, .21),
    "steel": ((.29,.35,.37), .48, .68),
    "burn": ((.045,.056,.064), .9, .12),
    "rust": ((.28,.17,.105), .81, .16),
    "glass": ((.035,.11,.16), .24, .12),
    "yellow": ((.93,.65,.075), .47, .30),
}
color=np.ones((N,N,4),dtype=np.float32)
rough=np.ones((N,N,4),dtype=np.float32)
metal=np.ones((N,N,4),dtype=np.float32)
slots={}
rng=np.random.default_rng(13)
tile=256
for i,(name,(rgb,r,m)) in enumerate(swatches.items()):
    x=(i%4)*tile; y=(i//4)*tile
    macro=rng.normal(0,1,(16,16))
    macro=np.repeat(np.repeat(macro,16,axis=0),16,axis=1)
    for _ in range(5):
        macro=(macro+np.roll(macro,1,0)+np.roll(macro,-1,0)+
               np.roll(macro,1,1)+np.roll(macro,-1,1))/5
    fine=rng.normal(0,.022,(tile,tile))
    weathered=np.array(rgb)[None,None,:]+macro[:,:,None]*.045+fine[:,:,None]
    patch=color[y:y+tile,x:x+tile,:3]
    patch[:]=np.clip(weathered,0,1)
    rough[y:y+tile,x:x+tile,:3]=np.clip(r+.08*macro[:,:,None],.08,1)
    metal[y:y+tile,x:x+tile,:3]=m
    if name in ("white","white_high","white_low","blue","blue_light"):
        # Paint chips, rusty pinholes, broad dirty smears and fine scrape lines.
        yy,xx=np.ogrid[:tile,:tile]
        for j in range(95 if name.startswith("white") else 60):
            cx=int(rng.integers(9,tile-9)); cy=int(rng.integers(9,tile-9))
            sx=int(rng.integers(1,8)); sy=int(rng.integers(1,5))
            mask=((xx-cx)/sx)**2+((yy-cy)/sy)**2<1
            chip=(.22,.25,.25) if j%5 else (.29,.16,.08)
            patch[mask]=chip
            rough[y:y+tile,x:x+tile,:3][mask]=.80
            metal[y:y+tile,x:x+tile,:3][mask]=.42 if j%5 else .18
        for j in range(23):
            cy=int(rng.integers(5,tile-5)); cx=int(rng.integers(8,tile-35))
            length=int(rng.integers(12,58)); thick=1 if j%4 else 2
            patch[cy:cy+thick,cx:cx+length]=(.35,.39,.39) if j%3 else (.39,.23,.13)
        for j in range(7):
            cx=int(rng.integers(22,tile-22)); cy=int(rng.integers(22,tile-22))
            radius=int(rng.integers(12,30))
            mask=((xx-cx)/radius)**2+((yy-cy)/(radius*.68))**2<1
            patch[mask]*=.82
    slots[name]=(x,y,tile)

def image(name,data,noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name="Non-Color"
    im.pixels.foreach_set(data.ravel())
    im.filepath_raw=str(OUT/"textures"/(name+".png"))
    im.file_format="PNG"; im.save()
    return im

mat=bpy.data.materials.new("CargoWrecked_CleanAtlas")
mat.use_nodes=True
bsdf=mat.node_tree.nodes.get("Principled BSDF")
for name,data,socket,noncolor in (("CargoC_Clean_Color",color,"Base Color",False),
                                  ("CargoC_Clean_Roughness",rough,"Roughness",True),
                                  ("CargoC_Clean_Metalness",metal,"Metallic",True)):
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=image(name,data,noncolor)
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs[socket])

source=bpy.data.collections.new("SOURCE")
bpy.context.scene.collection.children.link(source)
parts=[]

def finish(ob,name,surface):
    ob.name=name
    for coll in list(ob.users_collection): coll.objects.unlink(ob)
    source.objects.link(ob)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    x,y,span=slots[surface]
    inset=7
    uv_corners=((x+inset,y+inset),(x+span-inset,y+inset),
                (x+span-inset,y+span-inset),(x+inset,y+span-inset))
    rotation=random.randrange(4)
    for face in ob.data.polygons:
        for index,loop_index in enumerate(face.loop_indices):
            px,py=uv_corners[(index+rotation)%4]
            uv.data[loop_index].uv=(px/N,py/N)
    parts.append(ob)
    return ob

def box(name,loc,size,surface="white",bevel=0,rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob=bpy.context.object; ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new("Chamfer","BEVEL")
        mod.width=min(bevel,min(size)/3); mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new("Normals","WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location=loc
    if rot: ob.rotation_euler=rot
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

def polygon(name,verts,surface="white"):
    """Irregular sheet with a deliberate broken silhouette."""
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[tuple(range(len(verts)))])
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(ob)
    return finish(ob,name,surface)

def beam(name,a,b,width,depth,surface):
    mid=(np.array(a)+np.array(b))/2
    delta=np.array(b)-np.array(a)
    ob=box(name,tuple(mid),(width,depth,float(np.linalg.norm(delta))),surface,.025)
    # Use direct geometry rotation; this object is already a mesh.
    from mathutils import Vector
    direction=Vector(tuple(delta)).normalized()
    ob.data.transform(Vector((0,0,1)).rotation_difference(direction).to_matrix().to_4x4())
    return ob

def cable(name,a,b,radius=.027,surface="seam"):
    from mathutils import Vector
    start,end=Vector(a),Vector(b)
    direction=end-start
    bpy.ops.mesh.primitive_cylinder_add(vertices=7,radius=radius,depth=direction.length)
    ob=bpy.context.object
    ob.rotation_euler=Vector((0,0,1)).rotation_difference(direction).to_euler()
    ob.location=(start+end)*.5
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

# Closed shell with a real, unobstructed blown front. The rear wall and floor
# prevent the inside from reading as a hollow white cube.
box("FloorSteel",(0,0,.10),(7.45,5.85,.2),"steel")
box("FloorInset",(0,0,.22),(7.03,5.35,.11),"blue")
box("RearWall",(-3.62,0,3.0),(.20,5.80,5.70),"blue")
box("RearExterior",(-3.76,0,3.0),(.09,5.48,5.43),"white")
for y in (-1.69,0,1.69):
    box(f"RearPanelBorder_{y}",(-3.821,y,3.0),(.045,1.52,5.13),"white_low",.028)
    box(f"RearPanel_{y}",(-3.851,y,3.0),(.035,1.35,4.94),"white_high",.025)
    for z in (1.03,4.98):
        box(f"RearPanelMark_{y}_{z}",(-3.873,y,z),(.012,1.08,.034),"seam")
for z in (.25,5.77):
    box(f"RearHorizontal_{z}",(-3.875,0,z),(.08,5.55,.19),"white_low",.025)
box("Roof",(0,0,5.83),(7.50,5.94,.24),"white",.04)
box("RoofUnderside",(0,0,5.65),(7.06,5.42,.07),"blue")
for y in (-2.82,2.82):
    if y > 0:
        box(f"SideWall_{y}",(0,y,3),(7.25,.20,5.62),"white")
        box(f"SideInside_{y}",(0,y*.94,3),(7.0,.035,5.36),"blue")
    else:
        # A real missing area in the near side, not a flat painted scorch.
        # The gap spans X 1.33..2.72 and Z .90..3.75.
        for suffix,x,width,z,height in (("Rear",-1.155,4.97,3,5.62),
                                        ("Front",3.19,.86,3,5.62),
                                        ("Upper",2.025,1.39,4.755,2.11),
                                        ("Lower",2.025,1.39,.545,.71)):
            box(f"SideWall_{suffix}",(x,y,z),(width,.20,height),"white")
            box(f"SideInside_{suffix}",(x,y*.94,z),(width,.035,height),"blue")
for x in (-3.58,3.58):
    for y in (-2.81,2.81):
        box(f"CornerPost_{x}_{y}",(x,y,3),(.29,.32,5.89),"white_low",.055)
        for z in (.20,5.80):
            box(f"CornerCap_{x}_{y}_{z}",(x,y,z),(.43,.45,.39),"white_high",.065)
for y in (-2.88,2.88):
    for z in (.20,5.79):
        box(f"SideRail_{y}_{z}",(0,y,z),(7.51,.24,.25),"white_low",.035)

# Exterior side facing the quarter camera (-Y): recessed white panels, a
# diagonal dark window and smaller side vents. Real geometry keeps edges crisp.
for x in (-2.52,-.53):
    box(f"NearPanelBorder_{x}",(x,-2.943,3.07),(1.76,.055,4.94),"white_low",.05)
    box(f"NearPanel_{x}",(x,-2.980,3.07),(1.57,.032,4.70),"white_high",.04)
    for z in (.90,5.22):
        box(f"PanelSeam_{x}_{z}",(x,-3.001,z),(1.47,.013,.035),"seam")
box("NearDamagedUpperPanel",(2.02,-2.980,4.76),(1.20,.032,1.66),"white_high",.03)
box("NearDamagedLowerPanel",(2.02,-2.980,.55),(1.20,.032,.59),"white_high",.025)
for z in (2.0,3.9):
    box(f"SideHorizontalRear_{z}",(-1.33,-3.018,z),(4.51,.07,.085),"white_low",.02)
    box(f"SideHorizontalFront_{z}",(3.14,-3.018,z),(.74,.07,.085),"white_low",.02)
# Broken angled viewport at the rear half.
polygon("WindowDark",[(-2.83,-3.033,3.51),(-1.87,-3.033,4.32),(-1.08,-3.033,4.38),
                       (-1.62,-3.033,3.43)],"seam")
polygon("WindowGlass",[(-2.67,-3.045,3.59),(-1.81,-3.045,4.22),(-1.27,-3.045,4.25),
                        (-1.73,-3.045,3.55)],"glass")
for z in (4.71,4.80,4.89):
    box(f"SideVent_{z}",(-2.69,-3.048,z),(.55,.014,.025),"seam")

# Charred jagged rim around the opening and bent sheet-metal lips.
polygon("BurnLeft",[(1.17,-3.065,.68),(1.48,-3.065,1.05),(1.39,-3.065,1.72),
                    (1.62,-3.065,2.51),(1.42,-3.065,3.55),(1.14,-3.065,3.94)],"burn")
polygon("BurnRight",[(2.52,-3.065,.82),(2.88,-3.065,1.51),(2.66,-3.065,2.18),
                     (2.90,-3.065,2.95),(2.59,-3.065,3.87),(2.88,-3.065,3.82)],"burn")
polygon("BurnTop",[(1.14,-3.068,3.77),(1.65,-3.068,3.44),(2.12,-3.068,3.73),
                   (2.62,-3.068,3.54),(2.90,-3.068,3.97)],"burn")
polygon("BurnBottom",[(1.18,-3.068,.70),(1.67,-3.068,1.05),(2.21,-3.068,.81),
                      (2.83,-3.068,.73)],"burn")
for i,(x,z,r) in enumerate(((1.59,1.17,-.2),(1.77,2.36,.35),(2.54,2.51,-.45),
                            (2.13,3.12,.65),(3.04,1.31,.4))):
    box(f"TornWhite_{i}",(x,-3.075,z),(.64,.035,.17),"white_low",.015,(0,r,0))
for i,(x,z) in enumerate(((1.55,.84),(1.78,1.44),(2.88,2.71),(2.19,3.52))):
    box(f"BurnedLip_{i}",(x,-3.09,z),(.34,.027,.12),"rust",0,(0,.3,0))

# Blue interior: raised wall panels, side rails, floor strips and a few marks.
for y in (-1.78,0,1.78):
    box(f"BackPanelFrame_{y}",(-3.47,y,3),(.065,1.48,4.94),"seam")
    box(f"BackPanel_{y}",(-3.41,y,3),(.065,1.32,4.76),"blue_light")
    for z in (1.36,3.65,4.89):
        box(f"BackPanelSeam_{y}_{z}",(-3.363,y,z),(.02,1.14,.035),"blue")
for y in (-2.53,2.53):
    for z in (.85,2.4,4.8):
        box(f"InteriorRail_{y}_{z}",(0,y,z),(6.96,.10,.11),"blue_light")
for y in np.linspace(-2.3,2.3,7):
    box(f"FloorGroove_{y:.1f}",(0,float(y),.292),(6.73,.018,.02),"seam")
for z in (1.1,1.29,1.48):
    box(f"BackVent_{z}",(-3.32,-1.9,z),(.02,.66,.055),"seam")
box("InteriorWarning",(-3.30,.91,1.02),(.025,.09,.20),"yellow")

# The unit has been searched and stripped. Two cases are tipped open, a wall
# panel has fallen in, shelf sections sag, and conduit hangs from the roof.
box("LootCaseA",(-1.73,-1.26,.61),(1.21,.90,.56),"white_low",.055,
    (0,.10,math.radians(21)))
box("LootCaseAOpenTop",(-1.73,-1.26,.93),(1.02,.72,.016),"burn",.004,
    (0,.10,math.radians(21)))
box("LootCaseALid",(-2.35,-1.45,1.07),(1.15,.10,.60),"white_high",.028,
    (0,math.radians(-32),math.radians(20)))
box("LootCaseB",(.04,1.30,.56),(.98,.77,.49),"blue_light",.035,
    (math.radians(12),math.radians(-16),math.radians(-29)))
box("LootCaseBExposed",(.05,1.30,.84),(.78,.58,.015),"burn",.004,
    (math.radians(12),math.radians(-16),math.radians(-29)))
box("LooseDrawer",(1.74,.72,.42),(.86,.74,.18),"white_low",.025,
    (0,math.radians(9),math.radians(37)))
box("DrawerInterior",(1.74,.72,.52),(.67,.57,.015),"seam",.002,
    (0,math.radians(9),math.radians(37)))
box("FallenWallPanel",(-.47,2.12,1.37),(1.57,.09,2.03),"blue_light",.035,
    (math.radians(22),math.radians(-20),math.radians(23)))
box("PanelBrokenBacking",(-.43,2.00,1.40),(1.34,.04,1.84),"steel",.02,
    (math.radians(22),math.radians(-20),math.radians(23)))
for i,(x,y,z,rz) in enumerate(((1.10,-2.24,2.38,.24),(-.39,2.20,3.05,-.37),
                                (1.92,2.19,3.58,.48))):
    box(f"BentShelf_{i}",(x,y,z),(1.44,.16,.10),"steel",.02,
        (0,math.radians(10+i*8),rz))
for i,points in enumerate((
    ((2.70,-2.07,5.56),(2.27,-2.13,4.77),(1.82,-1.94,4.39)),
    ((.86,2.13,5.54),(1.11,2.02,4.90),(1.43,1.88,4.60)),
)):
    for j in range(len(points)-1):
        cable(f"HangingConduit_{i}_{j}",points[j],points[j+1],.027,"seam")
for i,(x,y,z,rz) in enumerate(((2.60,-.87,.34,-.42),(2.42,.16,.32,.29),
                                (.94,-.25,.33,.81),(-.84,.42,.33,-.6))):
    box(f"ScatteredScrap_{i}",(x,y,z),(.36,.18,.045),
        "steel" if i%2 else "white_low",.009,(0,0,rz))

# Front frame (+X). It is truly open; the inner top and left are irregular,
# with dark cut metal and several sharp pale shards. Four large rails give a
# deliberate manufactured silhouette despite the destroyed right jamb.
box("DoorSill",(3.68,0,.24),(.35,5.76,.45),"white_low",.05)
box("SillWear",(3.88,0,.50),(.11,5.15,.055),"steel")
box("LeftJamb",(3.69,-2.70,3),(.32,.48,5.64),"white_low",.055)
box("RightJamb",(3.69,2.70,3),(.32,.42,5.64),"white_low",.055)
box("TopLintel",(3.69,0,5.53),(.33,5.5,.55),"white_low",.04)
for y in (-2.53,2.53):
    box(f"InnerJamb_{y}",(3.87,y,3),(.14,.12,5.00),"burn")
box("InnerLintel",(3.87,0,5.24),(.15,5.00,.12),"burn")
# Scorched asymmetrical rupture across left jamb and lintel.
polygon("FrontScorch",[(3.904,-2.84,.91),(3.904,-2.32,1.24),(3.904,-2.55,2.28),
                         (3.904,-2.24,2.99),(3.904,-2.72,3.74),(3.904,-2.37,4.83),
                         (3.904,-1.25,5.12),(3.904,-.60,5.67),(3.904,-3.01,5.67)],"burn")
for i,(y,z,dy,dz) in enumerate(((-2.43,1.45,.43,.70),(-2.37,2.74,-.28,.52),
                                (-2.28,4.07,.35,.72),(-1.72,5.06,.61,.28),
                                (-.78,5.23,-.52,.22))):
    polygon(f"SharpTear_{i}",[(3.93,y-.08,z-.14),(4.02,y+dy,z+dz),
                              (3.93,y+.19,z+.08)],"white_high")
    polygon(f"TearSteel_{i}",[(3.94,y+.02,z-.12),(4.03,y+dy*.68,z+dz*.75),
                              (3.94,y+.12,z+.06)],"steel")
# Dropped threshold fragments are attached to the prop, above the floor.
for i,(x,y,z,rx,ry) in enumerate(((3.80,-.9,.13,.39,.19),(4.02,.37,.08,.31,.17),
                                   (3.85,1.27,.12,.24,.17))):
    box(f"FloorShard_{i}",(x,y,z),(rx,ry,.10),"white_low",.018,(0,.22,random.uniform(-.5,.5)))

# Hinged door on the right of the opening. The panel is rotated outwards,
# leaving a view into the blue interior, and its free edge is shattered.
door_rot=(0,0,math.radians(-28))
box("OpenDoorCoreLower",(4.61,3.80,2.37),(.19,2.72,4.04),"white_high",.065,door_rot)
box("OpenDoorCoreUpperHinge",(4.44,3.48,4.79),(.19,2.00,.88),"white_high",.055,door_rot)
box("OpenDoorInsetLower",(4.715,3.84,2.50),(.055,2.28,3.79),"white_low",.025,door_rot)
box("OpenDoorInsetUpperHinge",(4.56,3.52,4.75),(.055,1.55,.70),"white_low",.025,door_rot)
for z in (.85,2.00,3.62,4.73):
    if z < 4.5:
        box(f"OpenDoorCrossrail_{z}",(4.75,3.85,z),(.065,2.40,.075),"white",.02,door_rot)
    else:
        box(f"OpenDoorCrossrail_{z}",(4.59,3.54,z),(.065,1.72,.075),"white",.02,door_rot)
box("OpenDoorVentFrame",(4.78,3.90,2.97),(.035,1.16,1.46),"steel",.025,door_rot)
for i in range(9):
    box(f"OpenDoorVent_{i}",(4.81,3.90,2.38+i*.14),(.023,.94,.035),"seam",0,door_rot)
for z in (1.01,2.72,4.60):
    box(f"DoorHinge_{z}",(3.97,2.70,z),(.36,.22,.30),"steel",.04)
box("DoorBurnEdge",(5.31,4.91,2.43),(.045,.34,2.85),"burn",.01,door_rot)
for i,z in enumerate((1.47,2.94,4.10)):
    box(f"DoorTear_{i}",(5.32,4.94,z),(.09,.40,.18),"white_low",.01,
        (0,random.uniform(-.3,.3),math.radians(-28)))
polygon("DoorMissingCornerLip",[(5.04,4.60,4.25),(5.26,4.86,4.54),
                                (5.11,4.67,4.79),(4.96,4.46,4.48)],"steel")
polygon("DoorMissingCornerShard",[(5.03,4.64,4.39),(5.38,4.94,4.72),
                                  (4.94,4.53,4.69)],"white_low")

# Far side is intentionally calmer, with structural panel breaks.
for x in (-2.5,-.5,1.5):
    box(f"FarPanel_{x}",(x,2.95,3.03),(1.72,.045,4.97),"white_high",.04)
for z in (2.0,4.04):
    box(f"FarSideRail_{z}",(0,3.01,z),(6.90,.07,.08),"white_low")
for x in (-3.28,3.26):
    box(f"RoofScuff_{x}",(x,0,5.97),(.20,5.06,.025),"steel")

# The editable pieces remain in SOURCE. Export only a joined, one-material mesh.
source.hide_render=True
export=bpy.data.collections.new("EXPORT")
bpy.context.scene.collection.children.link(export)
copies=[]
for ob in parts:
    dup=ob.copy(); dup.data=ob.data.copy(); export.objects.link(dup); copies.append(dup)
bpy.ops.object.select_all(action="DESELECT")
for ob in copies: ob.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
final=bpy.context.object; final.name="CargoWrecked"
assert len(final.data.polygons)<10000,len(final.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/CargoC_Clean.blend"))
bpy.ops.object.select_all(action="DESELECT")
final.select_set(True); bpy.context.view_layer.objects.active=final
bpy.ops.export_scene.gltf(filepath=str(OUT/"exports/CargoWrecked.glb"),
                          export_format="GLB",export_image_format="AUTO",
                          use_selection=True,export_apply=True)
print("source polygons",len(final.data.polygons))
