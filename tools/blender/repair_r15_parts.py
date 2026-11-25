"""Rebuild each R15 part as a closed surface, baking paint and transferring weights."""
import bpy,bmesh,sys,json,math,ast
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
folder=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(folder/'RangerR15.blend'))
scene=bpy.context.scene;spec={'cage':2};OUT=folder;report={}
root=Path(__file__).resolve().parents[2]
tree=ast.parse((root/'tools/blender/prepare_avatar_setup.py').read_text(encoding='utf-8'))
func=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='fuse_and_bake')
func.body=[s for s in func.body if 'bpy.ops.uv.pack_islands' not in ast.unparse(s)]
exec(compile(ast.Module(body=[func],type_ignores=[]),'fuse','exec'),globals())
rig=bpy.data.objects['RangerR15'];parts=[o for o in scene.objects if o.name.endswith('_Geo')]
total=sum(len(o.data.polygons) for o in parts);newparts=[]
for src in parts:
 name=src.name;print('REPAIR',name,flush=True)
 kd=KDTree(len(src.data.vertices));weights=[];names={g.index:g.name for g in src.vertex_groups}
 for v in src.data.vertices:
  kd.insert(v.co,v.index);weights.append({names[g.group]:g.weight for g in v.groups})
 kd.balance();src.parent=None
 for mod in list(src.modifiers):src.modifiers.remove(mod)
 budget=max(300,round(11500*len(src.data.polygons)/total))
 out,_=fuse_and_bake(src,name,budget,.028,1024)
 out.name=name
 for g in list(out.vertex_groups):out.vertex_groups.remove(g)
 for n in sorted(set(n for ws in weights for n in ws)):out.vertex_groups.new(name=n)
 for v in out.data.vertices:
  ws={}
  for _,index,d in kd.find_n(v.co,3):
   for n,w in weights[index].items():ws[n]=ws.get(n,0)+w/max(d,.003)**2
  ws=dict(sorted(ws.items(),key=lambda x:-x[1])[:4]);s=sum(ws.values())
  for n,w in ws.items():out.vertex_groups[n].add([v.index],w/s,'REPLACE')
 out.parent=rig;mod=out.modifiers.new('R15Skin','ARMATURE');mod.object=rig
 for f in out.data.polygons:f.use_smooth=True
 newparts.append(out)
for o in scene.objects:o.select_set(o in newparts or o==rig)
bpy.ops.export_scene.gltf(filepath=str(folder/'RangerR15-partitioned.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.export_scene.fbx(filepath=str(folder/'RangerR15-Trial.fbx'),use_selection=True,add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,axis_forward='-Z',axis_up='Y',global_scale=.01,apply_unit_scale=True)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'RangerR15.blend'))
