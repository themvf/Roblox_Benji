"""Inspect the delivered Meshy skeleton and render samples of its actual walk/run clips."""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector
folder=Path(sys.argv[sys.argv.index('--')+1]).resolve()
report={}
clips = sys.argv[sys.argv.index('--')+2:] or ['walking_glb','running_glb']
for clip in clips:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder/(clip+'.glb')))
    scene=bpy.context.scene
    meshes=[o for o in scene.objects if o.type=='MESH']
    arms=[o for o in scene.objects if o.type=='ARMATURE']
    actions=list(bpy.data.actions)
    ranges=[tuple(a.frame_range) for a in actions]
    lo=min((r[0] for r in ranges),default=1); hi=max((r[1] for r in ranges),default=1)
    data={'armatures':[{ 'name':o.name,'bones':[{'name':b.name,'parent':b.parent.name if b.parent else None} for b in o.data.bones]} for o in arms],
          'meshes':[{ 'name':o.name,'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'vertexGroups':len(o.vertex_groups)} for o in meshes],
          'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in actions], 'samples':[]}
    scene.render.engine='CYCLES';scene.cycles.samples=12
    scene.render.resolution_x=480;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(0.65,0.65,0.65,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=0.8
    bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
    frames=[lo] if hi==lo else [lo+(hi-lo)*t for t in (0,.2,.4,.6,.8,1)]
    points=[]
    for f in frames:
        scene.frame_set(round(f));dg=bpy.context.evaluated_depsgraph_get()
        for o in meshes:
            ev=o.evaluated_get(dg);points.extend(ev.matrix_world@Vector(c) for c in ev.bound_box)
    low=Vector([min(v[i] for v in points) for i in range(3)]);high=Vector([max(v[i] for v in points) for i in range(3)])
    center=(low+high)/2;size=high-low;span=max(size);cam.data.ortho_scale=span*1.3
    bpy.ops.object.light_add(type='AREA',location=center+Vector((span,-span,span*2)))
    light=bpy.context.object;light.data.energy=span*span*80;light.data.shape='DISK';light.data.size=span*2
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    for n,f in enumerate(frames):
        scene.frame_set(round(f))
        for view,offset in [('front',(0,-3,.15)),('side',(3,0,.15)),('back',(0,3,.15))]:
            cam.location=center+Vector(offset)*span;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
            path=folder/f'{clip}-{n}-{view}.png';scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            data['samples'].append({'frame':round(f),'view':view,'image':path.name})
    report[clip]=data
(folder/'rig-review.json').write_text(json.dumps(report,indent=2))
