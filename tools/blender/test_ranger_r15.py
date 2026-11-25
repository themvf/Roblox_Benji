"""Create local deformation-test actions on the fitted R15 rig, without paid animation calls."""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Matrix,Vector
folder=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(folder/'RangerR15.blend'))
rig=bpy.data.objects['RangerR15'];rig.animation_data_clear()
parts=[o for o in bpy.context.scene.objects if o.name.endswith('_Geo')]
if '--continuous' in sys.argv:
 parts=[bpy.data.objects['ContinuousControl']]
 parts[0].hide_viewport=False;parts[0].hide_render=False
 for o in bpy.context.scene.objects:
  if o.name.endswith('_Geo'):o.hide_render=True;o.hide_viewport=True
 output=folder/'continuous-tests';output.mkdir(exist_ok=True)
else:output=folder
poses={
 'idle':[],
 'walk':[('LeftUpperLeg','X',30),('LeftLowerLeg','X',-20),('RightUpperLeg','X',-30),('RightLowerLeg','X',-45),('LeftUpperArm','X',-30),('RightUpperArm','X',30)],
 'run':[('UpperTorso','X',12),('LeftUpperLeg','X',55),('LeftLowerLeg','X',-70),('RightUpperLeg','X',-40),('RightLowerLeg','X',-90),('LeftUpperArm','X',-55),('RightUpperArm','X',55),('LeftLowerArm','X',80),('RightLowerArm','X',80)],
 'crouch':[('UpperTorso','X',20),('LeftUpperLeg','X',80),('LeftLowerLeg','X',-110),('RightUpperLeg','X',80),('RightLowerLeg','X',-110)],
 'jump':[('LeftUpperLeg','X',70),('LeftLowerLeg','X',-100),('RightUpperLeg','X',20),('RightLowerLeg','X',-60),('LeftUpperArm','Y',-120),('RightUpperArm','Y',120)],
 'aim':[('RightUpperArm','X',85),('LeftUpperArm','X',70),('LeftUpperArm','Z',-25),('LeftLowerArm','X',30)],
 'headturn':[('UpperTorso','Z',-15),('Head','Z',50)]}
for name,rots in poses.items():
 rig.animation_data_clear()
 for action in list(bpy.data.actions):bpy.data.actions.remove(action)
 for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 for n,axis,deg in rots:
  pb=rig.pose.bones[n];m=pb.matrix.copy();pivot=m.translation
  pb.matrix=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-pivot)@m
  bpy.context.view_layer.update()
 for pb in rig.pose.bones:
  pb.keyframe_insert('location',frame=1);pb.keyframe_insert('rotation_quaternion',frame=1);pb.keyframe_insert('scale',frame=1)
 rig.animation_data.action.name=name
 for o in bpy.context.scene.objects:o.select_set(o in parts or o==rig)
 bpy.ops.export_scene.gltf(filepath=str(output/(name+'.glb')),export_format='GLB',use_selection=True,
  export_animations=True,export_nla_strips=False,export_frame_range=False)
(folder/'pose-tests.json').write_text(json.dumps({'poses':poses,'purpose':'Static deformation probes on adapted skin; not final gameplay clips or retargeted Meshy actions.'},indent=2))
