"""Fit a Meshy skin to the repository match skeleton; export a separate R15 trial."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
base=Path(sys.argv[sys.argv.index('--')+1]).resolve();out=base/'r15';out.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(base/'meshy-rig/RangerRig_glb.glb'))
src=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');src.animation_data_clear()
for pb in src.pose.bones:pb.matrix_basis=Matrix.Identity(4)
body=max((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
# Weld the imported UV-split surface before fitting. Per-corner weights can disagree
# at identical positions; fitting those independently opens cracks in a continuous skin.
import bmesh
bm=bmesh.new();bm.from_mesh(body.data)
local_span=max(max(v.co[i] for v in bm.verts)-min(v.co[i] for v in bm.verts) for i in range(3))
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=local_span*1e-4)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
bm.verts.index_update();seen=set();duplicates=[]
for face in bm.faces:
 key=tuple(sorted(v.index for v in face.verts))
 if key in seen:duplicates.append(face)
 else:seen.add(key)
if duplicates:bmesh.ops.delete(bm,geom=duplicates,context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
source_topology={'vertices':len(bm.verts),'boundaryEdges':sum(e.is_boundary for e in bm.edges),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges)}
bm.to_mesh(body.data);bm.free()
if body.data.has_custom_normals:
 bpy.context.view_layer.objects.active=body;body.select_set(True)
 bpy.ops.mesh.customdata_custom_splitnormals_clear()
heads={b.name:src.matrix_world@b.head_local for b in src.data.bones}
mapping={'Hips':'LowerTorso','Spine02':'UpperTorso','Spine01':'UpperTorso','Spine':'UpperTorso',
         'neck':'Head','Head':'Head','head_end':'Head','headfront':'Head'}
targets={'Root':((0,0,2.9),(0,0,3.0),None),
 'HumanoidRootNode':((0,0,2.9),(0,0,3.0),'Root'),
 'LowerTorso':((0,0,2.9),(0,0,3.1),'HumanoidRootNode'),
 'UpperTorso':((0,0,3.1),(0,0,4.7),'LowerTorso'),
 'Head':((0,0,4.7),(0,0,5.8),'UpperTorso')}
for side,s in [('Left',1),('Right',-1)]:
 for old,new in [('Shoulder','UpperTorso'),('Arm','UpperArm'),('ForeArm','LowerArm'),('Hand','Hand'),('UpLeg','UpperLeg'),('Leg','LowerLeg'),('Foot','Foot'),('ToeBase','Foot')]:
  mapping[side+old]=new if new=='UpperTorso' else side+new
 for name,head,tail,parent in [
  ('UpperArm',(s*1.5,0,4.55),(s*1.5,0,3.5),'UpperTorso'),
  ('LowerArm',(s*1.5,0,3.5),(s*1.5,0,2.4),side+'UpperArm'),
  ('Hand',(s*1.5,0,2.4),(s*1.5,0,1.9),side+'LowerArm'),
  ('UpperLeg',(s*.5,0,2.7),(s*.5,0,1.5),'LowerTorso'),
  ('LowerLeg',(s*.5,0,1.5),(s*.5,0,.3),side+'UpperLeg'),
  ('Foot',(s*.5,0,.3),(s*.5,-.55,.15),side+'LowerLeg')]:targets[side+name]=(head,tail,parent)

# Build per-influence fitting transforms from source segments to target segments.
# Source GLB joint heads are trustworthy; exported display bone lengths are not.
scale=3.1/heads['Spine02'].z
children={'Hips':'Spine02','Spine02':'Spine01','Spine01':'Spine','Spine':'neck','neck':'Head','Head':'head_end'}
for side in ['Left','Right']:
 children.update({side+'Shoulder':side+'Arm',side+'Arm':side+'ForeArm',side+'ForeArm':side+'Hand',side+'UpLeg':side+'Leg',side+'Leg':side+'Foot',side+'Foot':side+'ToeBase'})
def trunk_z(z):
 a,b=heads['Spine02'].z,heads['Head'].z
 return 3.1+(z-a)/(b-a)*1.6
transforms={}
for name,h in heads.items():
 dest=mapping[name];sh=h*scale
 if name in ['Hips','Spine02','Spine01','Spine','neck','Head','head_end','headfront'] or name.endswith('Shoulder'):
  # Trunk and collar retain offsets while fitting waist/neck landmarks.
  dz=trunk_z(h.z);th=Vector((sh.x,sh.y,dz));rot=Matrix.Identity(3);stretch=1
  if dest=='Head':th=Vector((sh.x,sh.y,4.7+(h.z-heads['Head'].z)*scale))
  if name=='Hips':th=Vector((0,0,2.9))
 else:
  th=Vector(targets[dest][0]);tt=Vector(targets[dest][1]);td=tt-th
  child=children.get(name)
  if child:sd=(heads[child]-h)*scale
  else:sd=Vector((1 if name.startswith('Left') else -1,0,0))*.5 if name.endswith('Hand') else Vector((0,-.3,0))
  if name.endswith('ToeBase'):
   th=Vector(targets[dest][1]);td=Vector((0,-.3,0))
  rot=sd.normalized().rotation_difference(td.normalized()).to_matrix()
  stretch=td.length/max(sd.length,1e-6)
  axis=sd.normalized();axial=Matrix.Identity(3)
  for i in range(3):
   for j in range(3):axial[i][j]+=(stretch-1)*axis[i]*axis[j]
  rot=rot@axial
 transforms[name]=(sh,th,rot)
# All influences collapsed into one R15 bone must share a coherent fitting frame.
# In particular, collapsing ToeBase but fitting it independently folds the boot.
for side in ['Left','Right']:
 transforms[side+'ToeBase']=transforms[side+'Foot']
for name in ['neck','head_end','headfront']:
 transforms[name]=transforms['Head']
trunk_scale=1.6/((heads['Head'].z-heads['Spine02'].z)*scale)
trunk_matrix=Matrix.Diagonal(Vector((1,1,trunk_scale)))
for name in ['Hips','Spine02','Spine01','Spine','LeftShoulder','RightShoulder']:
 transforms[name]=(heads['Spine02']*scale,Vector((0,0,3.1)),trunk_matrix)
# Smooth positional warp constrained by every anatomical landmark. Unlike independent
# per-influence fitting frames, this gives coincident surface positions one unique result.
import numpy as np
anchors=[];destinations=[]
for name,h in heads.items():
 if name in ['headfront','neck','LeftShoulder','RightShoulder']:continue
 sh,th,rot=transforms[name]
 dest=th+rot@(h*scale-sh)
 anchors.append(list(h*scale));destinations.append(list(dest))
anchors=np.array(anchors);destinations=np.array(destinations)
distance=np.linalg.norm(anchors[:,None,:]-anchors[None,:,:],axis=2)
poly=np.column_stack([np.ones(len(anchors)),anchors])
system=np.block([[distance**3+np.eye(len(anchors))*1e-7,poly],[poly.T,np.zeros((4,4))]])
coeff=np.linalg.solve(system,np.vstack([destinations,np.zeros((4,3))]))
def fit_surface(p):
 q=np.array(p);r=np.linalg.norm(anchors-q,axis=1)**3
 return Vector((np.concatenate([r,[1,*q]])@coeff).tolist())
weights=[];coords=[];unweighted=0
groups={g.index:g.name for g in body.vertex_groups}
for v in body.data.vertices:
 p=(body.matrix_world@v.co)*scale;total=0;co=Vector();ws={}
 for g in v.groups:
  name=groups[g.group]
  if name not in transforms:continue
  sh,th,rot=transforms[name];co+=(th+rot@(p-sh))*g.weight;total+=g.weight
  dest=mapping[name];ws[dest]=ws.get(dest,0)+g.weight
 if not total:unweighted+=1;co=p;ws={'LowerTorso':1}
 else:co/=total
 ws=dict(sorted(ws.items(),key=lambda x:-x[1])[:4]);norm=sum(ws.values());ws={n:w/norm for n,w in ws.items()}
 # Meshy's pelvis is largely weighted to upper legs; give the R15 waist an actual
 # deforming pelvis band instead of a nominal LowerTorso with almost no geometry.
 if abs(co.x)<1.05 and 2.65<co.z<3.35:
  pelvis=max(0,min(1,(3.25-co.z)/.25))
  ws={n:w*(1-pelvis) for n,w in ws.items()};ws['LowerTorso']=ws.get('LowerTorso',0)+pelvis
 ws=dict(sorted(((n,w) for n,w in ws.items() if w>1e-6),key=lambda x:-x[1])[:4]);norm=sum(ws.values());ws={n:w/norm for n,w in ws.items()}
 coords.append(co-Vector((0,0,2.9)));weights.append(ws)
for mod in list(body.modifiers):body.modifiers.remove(mod)
body.parent=None;body.matrix_world=Matrix.Identity(4)
for v,co in zip(body.data.vertices,coords):v.co=co
for g in list(body.vertex_groups):body.vertex_groups.remove(g)
for name in set(mapping.values()):body.vertex_groups.new(name=name)
for i,ws in enumerate(weights):
 for n,w in ws.items():body.vertex_groups[n].add([i],w,'REPLACE')
# Rebuild the fitted surface once, then project its source paint and weights back.
# This removes cracks/self-intersecting slivers inherited from the generated mesh.
from mathutils.kdtree import KDTree
kd=KDTree(len(body.data.vertices))
for v in body.data.vertices:kd.insert(v.co,v.index)
kd.balance();source_weights=weights
import ast
tree=ast.parse((base.parents[3]/'tools/blender/prepare_avatar_setup.py').read_text(encoding='utf-8'))
function=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='fuse_and_bake')
instrumented=[]
for statement in function.body:
 text=ast.unparse(statement)
 # Smart project already lays out an atlas; expensive concave repacking is optional.
 if 'bpy.ops.uv.pack_islands' in text:continue
 instrumented.extend(ast.parse(f'print({("SURFACE "+str(statement.lineno))!r}, flush=True)').body)
 instrumented.append(statement)
function.body=instrumented;ast.fix_missing_locations(function)
scene=bpy.context.scene;spec={'cage':2};OUT=out;report={}
exec(compile(ast.Module(body=[function],type_ignores=[]),'fuse_and_bake','exec'),globals())
body,remeshed=fuse_and_bake(body,'RangerSkin',18000,.018,2048)
for g in list(body.vertex_groups):body.vertex_groups.remove(g)
for name in sorted(set(mapping.values())):body.vertex_groups.new(name=name)
weights=[]
for v in body.data.vertices:
 samples=kd.find_n(v.co,3);ws={}
 for _,index,d in samples:
  factor=1/max(d,.002)**2
  for n,w in source_weights[index].items():ws[n]=ws.get(n,0)+w*factor
 ws=dict(sorted(ws.items(),key=lambda x:-x[1])[:4]);total=sum(ws.values());ws={n:w/total for n,w in ws.items()}
 weights.append(ws)
 for n,w in ws.items():body.vertex_groups[n].add([v.index],w,'REPLACE')
for o in list(bpy.context.scene.objects):
 if o!=body:bpy.data.objects.remove(o,do_unlink=True)
arm=bpy.data.armatures.new('R15');rig=bpy.data.objects.new('RangerR15',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,parent) in targets.items():
 b=arm.edit_bones.new(n);b.head=Vector(h)-Vector((0,0,2.9));b.tail=Vector(t)-Vector((0,0,2.9));b.use_deform=n not in ['Root','HumanoidRootNode']
 if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');body.parent=rig;mod=body.modifiers.new('R15Skin','ARMATURE');mod.object=rig
body.name='RangerSkin'
# Keep one continuous skin as a control, and partition a copy into 15 named meshes.
control=body.copy();control.data=body.data.copy();bpy.context.collection.objects.link(control);control.name='ContinuousControl';control.hide_render=True;control.hide_viewport=True
for o in bpy.context.scene.objects:o.select_set(False)
body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(out/'RangerR15-continuous.glb'),export_format='GLB',use_selection=True,export_animations=False)
part_faces={n:[] for n in set(mapping.values())}
for f in body.data.polygons:
 score={}
 for vi in f.vertices:
  for n,w in weights[vi].items():score[n]=score.get(n,0)+w
 part_faces[max(score,key=score.get)].append(f.index)
parts=[]
for name,faces in part_faces.items():
 obj=body.copy();obj.data=body.data.copy();bpy.context.collection.objects.link(obj);obj.name=name+'_Geo'
 capmat=bpy.data.materials.new(name+'_Interior');capmat.diffuse_color=(.10,.09,.07,1)
 capmat.use_nodes=True;capmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.10,.09,.07,1)
 capmat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1
 obj.data.materials.append(capmat);cap_index=len(obj.data.materials)-1
 import bmesh
 bm=bmesh.new();bm.from_mesh(obj.data);bm.faces.ensure_lookup_table();keep=set(faces)
 bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.index not in keep],context='FACES')
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 boundary=[e for e in bm.edges if e.is_boundary]
 if boundary:
  filled=bmesh.ops.holes_fill(bm,edges=boundary,sides=0).get('faces',[])
  if filled:
   for f in filled:f.material_index=cap_index
   bmesh.ops.triangulate(bm,faces=filled)
 # Close complex, non-planar cut loops that holes_fill leaves behind. Separate
 # over-connected edges first; build a weighted interior fan for each edge loop.
 over=[e for e in bm.edges if len(e.link_faces)>2]
 if over:bmesh.ops.split_edges(bm,edges=over)
 remaining=set(e for e in bm.edges if e.is_boundary)
 deform=bm.verts.layers.deform.active
 while remaining:
  first=remaining.pop();a,b=first.verts;chain=[a,b];edges=[first];current=b
  while current!=chain[0]:
   candidates=[e for e in current.link_edges if e in remaining]
   if not candidates:break
   e=candidates[0];remaining.remove(e);edges.append(e);current=e.other_vert(current);chain.append(current)
  if current!=chain[0] or len(edges)<3:continue
  ring=chain[:-1];center=bm.verts.new(sum((v.co for v in ring),Vector())/len(ring))
  if deform:
   center_weights={}
   for v in ring:
    for g,w in v[deform].items():center_weights[g]=center_weights.get(g,0)+w/len(ring)
   center_weights=dict(sorted(center_weights.items(),key=lambda x:-x[1])[:4]);norm=sum(center_weights.values())
   for g,w in center_weights.items():center[deform][g]=w/max(norm,1e-9)
  for e in edges:
   loop=e.link_loops[0];u=loop.vert;v=loop.link_loop_next.vert
   try:
    face=bm.faces.new((v,u,center));face.material_index=cap_index
   except ValueError:pass
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.to_mesh(obj.data);bm.free()
 parts.append(obj)
body.hide_render=True;body.hide_viewport=True
for o in bpy.context.scene.objects:o.select_set(o in parts or o==rig)
bpy.ops.export_scene.gltf(filepath=str(out/'RangerR15-partitioned.glb'),export_format='GLB',use_selection=True,export_animations=False)
for image in bpy.data.images:
 if image.packed_file:
  image.filepath_raw=str(out/(image.name+'.png'));image.file_format='PNG';image.save()
bpy.ops.export_scene.fbx(filepath=str(out/'RangerR15-Trial.fbx'),use_selection=True,add_leaf_bones=False,bake_anim=False,
 path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',global_scale=.01,apply_unit_scale=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'RangerR15.blend'))
report={'sourceWeldedTopology':source_topology,'unweightedSourceVertices':unweighted,'bones':{n:{'head':list(b.head_local),'parent':b.parent.name if b.parent else None} for n,b in rig.data.bones.items()},
 'parts':{o.name:sum(len(f.vertices)-2 for f in o.data.polygons) for o in parts},'mapping':mapping,
 'limitations':['Partition boundaries capped automatically; welded topology and visual checks required before acceptance.','Accessories retained in skin, not separated wearable assets.','Rest fitting and deformation require visual and Studio verification.','Source movements not yet retargeted.']}
(out/'adaptation.json').write_text(json.dumps(report,indent=2))
