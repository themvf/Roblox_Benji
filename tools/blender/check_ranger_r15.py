import bpy,sys,json,bmesh
from pathlib import Path
p=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(p/'RangerR15.blend'))
rig=bpy.data.objects['RangerR15'];parts=[o for o in bpy.context.scene.objects if o.name.endswith('_Geo')]
report={'parts':{},'bones':len(rig.data.bones),'source':'RangerR15.blend'}
for o in parts:
 bm=bmesh.new();bm.from_mesh(o.data)
 report['parts'][o.name]={'triangles':sum(len(f.verts)-2 for f in bm.faces),'boundaryEdges':sum(e.is_boundary for e in bm.edges),'nonManifoldEdges':sum(not e.is_manifold for e in bm.edges),
 'unweightedVertices':sum(not v.groups for v in o.data.vertices),'maxInfluences':max((len(v.groups) for v in o.data.vertices),default=0)}
 bm.free()
assert len(parts)==15
assert all(v['unweightedVertices']==0 and v['maxInfluences']<=4 for v in report['parts'].values())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(p/'RangerR15-Trial.fbx'))
report['fbxReadback']={'meshCount':len([o for o in bpy.context.scene.objects if o.type=='MESH']),
 'armatureCount':len([o for o in bpy.context.scene.objects if o.type=='ARMATURE']),
 'boneNames':[b.name for o in bpy.context.scene.objects if o.type=='ARMATURE' for b in o.data.bones]}
assert report['fbxReadback']['meshCount']==15
report['topologyPassed']=all(v['boundaryEdges']==0 and v['nonManifoldEdges']==0 for v in report['parts'].values())
report['studioVerified']=False
report['visualAccepted']=False
(p/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
if not report['topologyPassed']:raise SystemExit('R15 topology failed; this is not an accepted delivery.')
