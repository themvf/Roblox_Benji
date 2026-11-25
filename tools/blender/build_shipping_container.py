"""Reproducible clean container, referenced from Crates/0_1.png and its TRELLIS GLB.

Blender: X length, Y width (doors at +X), Z up. One stud per Blender unit.
"""
from pathlib import Path
import math

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/shipping-container"
N = 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for folder in ("source", "textures", "exports", "review"):
    (OUT / folder).mkdir(parents=True, exist_ok=True)

swatches = {
    "side": ((.145,.142,.139), .63, .38),
    "side_light": ((.22,.215,.205), .57, .43),
    "shell": ((.275,.295,.295), .51, .52),
    "panel": ((.35,.375,.375), .52, .47),
    "edge": ((.095,.11,.115), .61, .38),
    "seam": ((.055,.063,.067), .76, .22),
    "gold": ((.78,.43,.085), .31, .78),
    "gold_light": ((1.0,.62,.17), .25, .82),
    "yellow": ((.98,.74,.05), .43, .3),
}
color = np.ones((N,N,4), dtype=np.float32)
rough = np.ones((N,N,4), dtype=np.float32)
metal = np.ones((N,N,4), dtype=np.float32)
slots = {}
for i,(name,(rgb,r,m)) in enumerate(swatches.items()):
    x=(i%8)*128; y=(i//8)*128
    color[y:y+128,x:x+128,:3]=rgb
    rough[y:y+128,x:x+128,:3]=r
    metal[y:y+128,x:x+128,:3]=m
    slots[name]=((x+64)/N,(y+64)/N)

def image(name, data, noncolor=False):
    im=bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name="Non-Color"
    im.pixels.foreach_set(data.ravel())
    im.filepath_raw=str(OUT/"textures"/(name+".png"))
    im.file_format="PNG"; im.save()
    return im

mat=bpy.data.materials.new("ShippingContainer_Atlas")
mat.use_nodes=True
bsdf=mat.node_tree.nodes.get("Principled BSDF")
for name,data,socket,noncolor in (("Container_Color",color,"Base Color",False),
                                  ("Container_Roughness",rough,"Roughness",True),
                                  ("Container_Metalness",metal,"Metallic",True)):
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image=image(name,data,noncolor)
    mat.node_tree.links.new(tex.outputs["Color"],bsdf.inputs[socket])

coll=bpy.data.collections.new("SOURCE")
bpy.context.scene.collection.children.link(coll)
parts=[]

def finish(ob,name,surface):
    ob.name=name
    for c in list(ob.users_collection): c.objects.unlink(ob)
    coll.objects.link(ob)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    for loop in uv.data: loop.uv=slots[surface]
    parts.append(ob)
    return ob

def box(name,loc,size,surface="shell",bevel=0.0,angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob=bpy.context.object
    ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new("Edges","BEVEL")
        mod.width=min(bevel,min(size)/3); mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new("Normals","WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location=loc; ob.rotation_euler[0]=angle
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

def rod(name,loc,radius,length,surface="gold",axis="Z",vertices=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=length)
    ob=bpy.context.object
    if axis=="X": ob.rotation_euler[1]=math.pi/2
    if axis=="Y": ob.rotation_euler[0]=math.pi/2
    ob.location=loc
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

L=22.0; W=7.8; H=10.8
# Core shell and the dark, raised ribs of a 20-foot container.
box("Shell",(0,0,H/2),(21.65,7.36,10.22),"side")
box("Roof",(0,0,10.52),(21.58,7.35,.12),"side_light")
box("FloorSkid",(0,0,.16),(21.74,7.6,.32),"edge")
for side in (-1,1):
    y=side*3.76
    box("SideSheet",(0,y,5.4),(21.2,.12,9.48),"side")
    for i in range(42):
        x=-10.24+i*.5
        box(f"SideRib_{side}_{i}",(x,side*3.875,5.43),(.16,.19,9.34),
            "side_light" if i%5==0 else "side",.025)
    for z in (.24,10.52):
        box(f"SideRail_{side}_{z}",(0,side*3.91,z),(21.78,.22,.22),"edge",.035)
    # Small painted ID label; visible on the near side in the source.
    if side==-1:
        box("SideID",(8.4,-4.016,1.24),(.30,.012,.78),"gold")
        for i in range(4):
            box(f"IDMark_{i}",(8.4,-4.028,1.02+i*.13),(.19,.012,.028),"seam")

for end in (-1,1):
    x=end*10.82
    for y in (-3.65,3.65):
        box(f"CornerPost_{end}_{y}",(x,y,5.4),(.36,.38,10.68),"edge",.055)
        for z in (.17,10.61):
            box(f"CornerCasting_{end}_{y}_{z}",(x,y,z),(.53,.61,.34),"edge",.045)
            # Open-looking lifting eye, shown as a black inset in the casting.
            box(f"CornerSocket_{end}_{y}_{z}",(end*11.096,y,z),(.01,.22,.13),"seam")
    for z in (.19,10.62):
        box(f"EndRail_{end}_{z}",(x,0,z),(.34,7.75,.28),"edge",.025)

# Plain far end, with stamped ribs and frame.
box("BlindEnd",(-10.78,0,5.4),(.13,7.0,9.75),"shell")
for y in np.linspace(-3.2,3.2,13):
    box(f"BlindRib_{y:.1f}",(-10.87,float(y),5.4),(.11,.13,9.25),"side_light")

# Double doors on the +X end. The near leaf is negative Y.
for leaf,cy in enumerate((-1.81,1.81)):
    x=10.83
    box(f"DoorLeaf_{leaf}",(x,cy,5.4),(.19,3.47,9.79),"shell")
    # Framed stamped panels make two rows of stepped sheet-metal relief.
    for z in (1.88,4.15,6.42,8.69):
        box(f"PanelRecess_{leaf}_{z}",(10.942,cy,z),(.035,3.04,1.87),"edge",.015)
        box(f"PanelFace_{leaf}_{z}",(10.971,cy,z),(.045,2.84,1.65),"panel",.09)
        box(f"PanelStep_{leaf}_{z}",(11.003,cy,z-.67),(.035,2.68,.11),"shell",.025)
    for y in (cy-1.67,cy+1.67):
        box(f"DoorJamb_{leaf}_{y}",(10.985,y,5.4),(.23,.13,9.83),"edge")
    # Two full-height gold locking bars per door, with collars and handles.
    for j,y in enumerate((cy-.58,cy+.58)):
        rod(f"LockBar_{leaf}_{j}",(11.115,y,5.42),.061,9.81,"gold_light",vertices=10)
        for z in (.64,2.87,5.40,7.91,10.12):
            rod(f"LockCollar_{leaf}_{j}_{z}",(11.12,y,z),.10,.22,"gold",vertices=10)
        box(f"LatchHandle_{leaf}_{j}",(11.20,y-.26,3.17),(.15,.72,.085),"gold_light",.02)
        rod(f"LatchKnob_{leaf}_{j}",(11.23,y-.57,3.17),.09,.19,"gold",axis="X")
    for z in (1.0,3.45,5.85,8.25,10.10):
        box(f"Hinge_{leaf}_{z}",(11.04,cy+(-1.75 if leaf==0 else 1.75),z),
            (.23,.21,.27),"edge",.025)

# Yellow/black warning panels across the upper door frame.
for y in (-3.0,3.0):
    box(f"HazardBack_{y}",(11.025,y,10.43),(.036,1.12,.18),"yellow")
    for k in range(5):
        box(f"HazardStripe_{y}_{k}",(11.05,y-.48+k*.22,10.43),
            (.018,.075,.2),"seam",angle=-.48)

coll.hide_render=True
export=bpy.data.collections.new("EXPORT")
bpy.context.scene.collection.children.link(export)
copies=[]
for ob in parts:
    dup=ob.copy(); dup.data=ob.data.copy(); export.objects.link(dup); copies.append(dup)
bpy.ops.object.select_all(action="DESELECT")
for ob in copies: ob.select_set(True)
bpy.context.view_layer.objects.active=copies[0]
bpy.ops.object.join()
final=bpy.context.object; final.name="ShippingContainer"
assert len(final.data.polygons)<10000, len(final.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/ShippingContainer.blend"))
bpy.ops.object.select_all(action="DESELECT"); final.select_set(True)
bpy.context.view_layer.objects.active=final
bpy.ops.export_scene.gltf(filepath=str(OUT/"exports/ShippingContainer.glb"),
                          export_format="GLB",export_image_format="AUTO",
                          use_selection=True,export_apply=True)
print("source polygons",len(final.data.polygons))
