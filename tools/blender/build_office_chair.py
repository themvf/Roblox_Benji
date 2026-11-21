"""Build two office chair GLBs with identical geometry and distinct upholstery.

The source's organic back, seat and five-spoke base survive a 0.09 triangle
ratio trial. Faces are divided into three height bands under Roblox's
10,000-triangle per-mesh cap without altering the remaining positions or UVs.
"""
from pathlib import Path
import bpy
import bmesh

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/models/office-chair"
HEIGHT=5.0
RATIO=.09
PART_LIMIT=9500

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(OUT/"source/trellis-original.glb"))
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
assert len(meshes)==1,"Source topology changed; reappraise"
source=meshes[0]
bpy.ops.object.select_all(action="DESELECT")
source.select_set(True);bpy.context.view_layer.objects.active=source
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
source.data.calc_loop_triangles()
assert len(source.data.loop_triangles)==279541,"Source triangle count changed"

clean_image=bpy.data.images.load(str(OUT/"textures/OfficeChair_Clean_Color.png"))
stain_image=bpy.data.images.load(str(OUT/"textures/OfficeChair_YellowStained_Color.png"))
packed_image=bpy.data.images.load(str(OUT/"textures/OfficeChair_MetallicRoughness.png"))
packed_image.colorspace_settings.name="Non-Color"
material=source.data.materials[0]
material.name="OfficeChair_Clean"
assert material.use_nodes
for node in material.node_tree.nodes:
    if node.type=="TEX_IMAGE" and node.image:
        if "0" in node.image.name:
            node.image=clean_image
        else:
            node.image=packed_image
if not any(n.type=="TEX_IMAGE" and n.image==clean_image for n in material.node_tree.nodes):
    raise RuntimeError("Could not find original base-color image node")
stained_material=material.copy()
stained_material.name="OfficeChair_YellowStained"
for node in stained_material.node_tree.nodes:
    if node.type=="TEX_IMAGE" and node.image==clean_image:
        node.image=stain_image

source.name="SOURCE_Trellis_Original"
source.hide_render=True
source.hide_set(True)
body=source.copy();body.data=source.data.copy()
bpy.context.scene.collection.objects.link(body)
body.name="WORK_Decimated"
source.hide_set(False)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True);bpy.context.view_layer.objects.active=body
mod=body.modifiers.new("Shape-preserving reduction","DECIMATE")
mod.ratio=RATIO
bpy.ops.object.modifier_apply(modifier=mod.name)
body.data.calc_loop_triangles()
total=len(body.data.loop_triangles)
assert 18000<total<3*PART_LIMIT,total
lo=[min(v.co[i] for v in body.data.vertices) for i in range(3)]
hi=[max(v.co[i] for v in body.data.vertices) for i in range(3)]
scale=HEIGHT/(hi[2]-lo[2])
mid_x=(lo[0]+hi[0])/2;mid_y=(lo[1]+hi[1])/2
for v in body.data.vertices:
    v.co.x=(v.co.x-mid_x)*scale
    v.co.y=(v.co.y-mid_y)*scale
    v.co.z=(v.co.z-lo[2])*scale
body.data.update()

ordered=sorted(body.data.polygons,
    key=lambda f:sum(body.data.vertices[i].co.z for i in f.vertices)/len(f.vertices))
n=len(ordered)
groups=[set(f.index for f in ordered[n*k//3:n*(k+1)//3]) for k in range(3)]
clean_parts=[]
collection=bpy.data.collections.new("EXPORT_CLEAN")
bpy.context.scene.collection.children.link(collection)
for number,keep in enumerate(groups,1):
    part=body.copy();part.data=body.data.copy()
    bpy.context.scene.collection.objects.link(part)
    part.name="OfficeChair_%02d"%number
    bm=bmesh.new();bm.from_mesh(part.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],
                     context="FACES")
    bm.to_mesh(part.data);bm.free();part.data.update()
    # The TRELLIS source carries a few invalid face references after reduction.
    # Repair these before export so the written mesh passes Blender validation.
    part.data.validate(clean_customdata=False)
    part.data.calc_loop_triangles()
    count=len(part.data.loop_triangles)
    assert 0<count<PART_LIMIT,count
    for old in list(part.users_collection):old.objects.unlink(part)
    collection.objects.link(part)
    clean_parts.append(part)
body.hide_render=True;body.hide_set(True)

def export(parts,path):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:part.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
        export_image_format="AUTO",use_selection=True,export_apply=True)

# Keep the clean variant and source mesh editable in the saved Blender file.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"source/OfficeChair.blend"))
export(clean_parts,OUT/"exports/OfficeChair_Clean.glb")
stained_parts=[]
for clean in clean_parts:
    part=clean.copy();part.data=clean.data.copy()
    bpy.context.scene.collection.objects.link(part)
    part.name=clean.name+"_Stained"
    part.data.materials.clear();part.data.materials.append(stained_material)
    stained_parts.append(part)
export(stained_parts,OUT/"exports/OfficeChair_YellowStained.glb")
print("OFFICE CHAIR",total,"triangles; per mesh",
      [len(p.data.loop_triangles) for p in clean_parts],flush=True)
