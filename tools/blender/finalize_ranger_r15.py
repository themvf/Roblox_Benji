"""Remove remesh cleanup debris and rewrite the R15 delivery files."""
import bpy,bmesh,sys
from pathlib import Path
p=Path(sys.argv[sys.argv.index('--')+1]).resolve();bpy.ops.wm.open_mainfile(filepath=str(p/'RangerR15.blend'))
rig=bpy.data.objects['RangerR15'];parts=[o for o in bpy.context.scene.objects if o.name.endswith('_Geo')]
for o in parts:
 o.data.validate(clean_customdata=False)
 bm=bmesh.new();bm.from_mesh(o.data)
 for _ in range(3):
  wire=[e for e in bm.edges if not e.link_faces]
  if wire:bmesh.ops.delete(bm,geom=wire,context='EDGES')
  loose=[v for v in bm.verts if not v.link_faces]
  if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
  bad=[f for f in bm.faces if f.calc_area()<1e-10]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES_ONLY')
  boundaries=[e for e in bm.edges if e.is_boundary]
  if boundaries:bmesh.ops.holes_fill(bm,edges=boundaries,sides=0)
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(o.data);bm.free()
for o in bpy.context.scene.objects:o.select_set(o in parts or o==rig)
bpy.ops.export_scene.gltf(filepath=str(p/'RangerR15-partitioned.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.export_scene.fbx(filepath=str(p/'RangerR15-Trial.fbx'),use_selection=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',global_scale=.01,apply_unit_scale=True)
bpy.ops.wm.save_as_mainfile(filepath=str(p/'RangerR15.blend'))
