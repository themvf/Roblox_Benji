"""Author the angular glossy black/orange cargo case from its visual reference.

Blender X is length, Y depth, Z up; one unit is one Roblox stud.
The 283k-triangle TRELLIS source is retained as reference, not reduced geometry.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/black-orange-newshape"
N = 1024
rng = np.random.default_rng(97)
random.seed(97)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for sub in ("source", "exports", "textures", "review", "trials"):
    (OUT/sub).mkdir(parents=True, exist_ok=True)

swatches = {
    "shell": ((.088,.096,.105), .15, .77),
    "panel": ((.055,.061,.070), .19, .66),
    "armor": ((.105,.114,.123), .18, .80),
    "recess": ((.021,.026,.032), .48, .22),
    "orange": ((.89,.245,.027), .17, .58),
    "orange_dark": ((.48,.11,.019), .27, .49),
    "white": ((.77,.84,.88), .16, .68),
    "chrome": ((.67,.72,.76), .105, .94),
    "rubber": ((.022,.026,.032), .83, .03),
    "steel": ((.34,.40,.44), .22, .83),
}
color = np.ones((N,N,4),dtype=np.float32)
rough = np.ones_like(color)
metal = np.ones_like(color)
slots = {}
for i,(name,(rgb,r,m)) in enumerate(swatches.items()):
    x,y = (i%4)*256,(i//4)*256
    fine = rng.normal(0,.0025,(256,256))
    broad = rng.normal(0,.004,(16,16)).repeat(16,0).repeat(16,1)
    color[y:y+256,x:x+256,:3] = np.clip(
        np.asarray(rgb)[None,None,:]+(fine+broad)[:,:,None],0,1)
    rough[y:y+256,x:x+256,:3] = np.clip(r+broad[:,:,None]*.7,0,1)
    metal[y:y+256,x:x+256,:3] = m
    slots[name] = (x,y)

def image(name,data,noncolor=False):
    im = bpy.data.images.new(name,width=N,height=N,alpha=True)
    if noncolor: im.colorspace_settings.name = "Non-Color"
    im.pixels.foreach_set(data.ravel())
    im.filepath_raw = str(OUT/"textures"/(name+".png"))
    im.file_format = "PNG"
    im.save(); im.pack()
    return im

mat = bpy.data.materials.new("AngularBlackOrange_Glossy_Atlas")
mat.use_nodes = True
p = mat.node_tree.nodes.get("Principled BSDF")
for name,data,socket,noncolor in (
    ("NewShape_Color",color,"Base Color",False),
    ("NewShape_Roughness",rough,"Roughness",True),
    ("NewShape_Metalness",metal,"Metallic",True),
):
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image(name,data,noncolor)
    mat.node_tree.links.new(tex.outputs["Color"],p.inputs[socket])

parts=[]
def finish(ob,name,surface):
    ob.name=name
    ob.data.materials.clear();ob.data.materials.append(mat)
    uv=ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    x,y=slots[surface]
    corners=((x+12,y+12),(x+244,y+12),(x+244,y+244),(x+12,y+244))
    for poly in ob.data.polygons:
        for j,loop in enumerate(poly.loop_indices):
            px,py=corners[j%4]
            uv.data[loop].uv=(px/N,py/N)
    parts.append(ob)
    return ob

def box(name,loc,size,surface="shell",bevel=0,rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob=bpy.context.object
    ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new("Chamfer","BEVEL")
        mod.width=min(bevel,min(size)/3)
        mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new("Weighted normals","WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location=loc
    if rotation:ob.rotation_euler=rotation
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return finish(ob,name,surface)

def roof_profile(name,profile,depth,surface,bevel=.035):
    """Extrude an X/Z polygon across Y to form the unusual sloping lid."""
    verts=[(x,y,z) for y in (-depth/2,depth/2) for x,z in profile]
    n=len(profile)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(ob)
    if bevel:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True);bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new("Lid bevel","BEVEL")
        mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new("Lid normals","WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(ob,name,surface)

# Main volume and roof line: lower shoulders at the ends, raised central roof.
box("Base armored skid",(0,0,.22),(7.60,4.83,.44),"rubber",.10)
box("Base steel seam",(0,0,.48),(7.49,4.72,.07),"chrome",.02)
box("Case body",(0,0,1.76),(7.40,4.61,2.60),"shell",.15)
box("White waist band",(0,0,3.04),(7.53,4.74,.35),"white",.035)
box("Lower waist chrome",(0,0,2.82),(7.54,4.75,.052),"chrome",.015)
box("Upper waist dark reveal",(0,0,3.25),(7.54,4.75,.052),"recess",.014)
roof_profile("Angled armored roof",
    [(-3.73,3.24),(-3.55,3.91),(-3.02,4.31),(-2.24,4.39),
     (2.24,4.39),(3.02,4.31),(3.55,3.91),(3.73,3.24)],
    4.66,"armor")
box("Roof central dark well",(0,0,4.424),(3.46,2.30,.025),"recess",.015)
box("Roof center pad",(0,0,4.445),(2.90,1.78,.025),"panel",.015)
for side in (-1,1):
    box("Roof length rail %s" % side,(0,side*1.62,4.416),
        (4.6,.075,.05),"chrome",.016)
    box("Roof orange rail %s" % side,(0,side*1.91,4.401),
        (3.82,.055,.035),"orange",.012)
for x in (-2.80,2.80):
    box("Roof terminal pad %s" % x,(x,0,4.385),
        (.58,2.75,.055),"shell",.025)

# Broad long faces: white center frame, black latch, and slashing orange feet.
for side in (-1,1):
    y=side*2.345
    box("Long side armor %s" % side,(0,y,1.67),
        (7.09,.075,2.11),"panel",.09)
    for x in (-3.12,3.12):
        box("Vertical end guard %s %s" % (side,x),(x,side*2.415,1.68),
            (.33,.12,2.35),"armor",.07)
        box("End service plate %s %s" % (side,x),(x,side*2.48,1.85),
            (.45,.035,1.25),"shell",.02)
    box("Central frame header %s" % side,(0,side*2.43,2.61),
        (2.85,.11,.22),"white",.032)
    for x in (-1.39,1.39):
        box("Central frame pillar %s %s" % (side,x),(x,side*2.43,1.91),
            (.22,.10,1.24),"white",.025)
    box("Central frame sill %s" % side,(0,side*2.43,1.25),
        (2.74,.10,.21),"white",.025)
    box("Control recess %s" % side,(0,side*2.478,2.02),
        (1.20,.030,1.16),"recess",.025)
    box("Control housing %s" % side,(0,side*2.506,2.02),
        (.88,.025,.86),"armor",.02)
    box("Control screen %s" % side,(0,side*2.527,2.02),
        (.54,.022,.53),"recess",.015)
    for x in (-2.14,2.14):
        angle=math.radians(54 if x<0 else -54)
        box("Orange diagonal %s %s" % (side,x),(x,side*2.455,1.13),
            (2.16,.10,.22),"orange",.035,(0,angle,0))
        box("Lower black angle guard %s %s" % (side,x),
            (x,side*2.48,1.07),(2.21,.06,.09),"panel",
            .016,(0,angle,0))
        box("Side relief panel %s %s" % (side,x),
            (x,side*2.416,1.55),(1.30,.06,1.12),"armor",.06)
    box("Orange base inset %s" % side,(0,side*2.453,.53),
        (2.27,.06,.30),"orange",.035)
    box("Chrome base rim %s" % side,(0,side*2.465,.72),
        (2.50,.055,.055),"chrome",.012)

# End faces: tall orange lower hatch, upper handle recess and black shoulders.
for side in (-1,1):
    x=side*3.745
    box("End armor %s" % side,(x,0,1.70),
        (.075,4.22,2.27),"panel",.10)
    for y in (-1.94,1.94):
        box("End corner bumper %s %s" % (side,y),
            (side*3.80,y,1.65),(.22,.37,2.61),"armor",.07)
    box("Upper handle frame %s" % side,(side*3.80,0,3.64),
        (.06,1.62,.62),"orange",.04)
    box("Upper handle cavity %s" % side,(side*3.837,0,3.64),
        (.035,1.32,.39),"recess",.025)
    box("Handle grip %s" % side,(side*3.867,0,3.58),
        (.055,1.05,.09),"chrome",.018)
    box("Lower hatch frame %s" % side,(side*3.818,0,1.12),
        (.07,1.55,1.53),"recess",.045)
    box("Orange access door %s" % side,(side*3.866,0,1.12),
        (.045,1.24,1.27),"orange",.045)
    box("Hatch inset %s" % side,(side*3.897,0,.94),
        (.032,.70,.51),"orange_dark",.025)
    box("Upper service latch %s" % side,(side*3.857,0,2.48),
        (.045,1.02,.34),"steel",.035)
    box("Latch chrome bar %s" % side,(side*3.886,0,2.47),
        (.032,.72,.07),"chrome",.016)

for sx in (-1,1):
    for sy in (-1,1):
        box("Corner foot %s %s" % (sx,sy),(sx*3.54,sy*2.19,.58),
            (.43,.48,1.07),"armor",.08)
        box("Corner roof cap %s %s" % (sx,sy),(sx*3.47,sy*2.15,3.55),
            (.49,.49,.75),"armor",.08)
        box("Corner orange marker %s %s" % (sx,sy),
            (sx*3.72,sy*2.14,3.72),(.043,.18,.43),"orange",.014)

bpy.ops.object.select_all(action="DESELECT")
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
ob=bpy.context.object
ob.name="GlossyAngularBlackOrangeCase"
ob["Role"]="Decoration candidate; visual approval pending"
ob["Anchored"]=True
ob.data.calc_loop_triangles()
count=len(ob.data.loop_triangles)
assert 0<count<10000,count
assert min(v.co.z for v in ob.data.vertices)>=-.0001
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/GlossyAngularCase.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT/"exports/GlossyAngularCase.glb"),
    export_format="GLB",use_selection=True,export_yup=True,export_apply=True,
    export_extras=True,export_materials="EXPORT",export_image_format="AUTO")
print("GLOSSY NEW SHAPE:",count,"triangles",flush=True)
