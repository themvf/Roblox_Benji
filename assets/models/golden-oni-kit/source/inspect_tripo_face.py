"""Render the original Tripo face in color and clay for defect diagnosis."""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

root = Path(__file__).resolve().parent
review = root.parent / 'review' / 'tripo'
bpy.ops.wm.read_factory_settings(use_empty=True)
prepared = '--prepared' in sys.argv
bpy.ops.import_scene.gltf(filepath=str(root / ('tripo-candidate/Body.glb' if prepared else 'tripo-multiview.glb')))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for obj in meshes:
    obj.rotation_euler[2] -= math.pi / 2
bpy.context.view_layer.update()
corners = [obj.matrix_world @ Vector(c) for obj in meshes for c in obj.bound_box]
lo = Vector([min(c[i] for c in corners) for i in range(3)])
hi = Vector([max(c[i] for c in corners) for i in range(3)])
height = hi.z - lo.z
target = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z + height * .78))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new('Neutral studio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.5,.5,.5,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .8
scene.world = world
bpy.ops.object.light_add(type='AREA', location=target + Vector((0,-height*3,height*3)))
bpy.context.object.data.energy = 200
bpy.context.object.data.size = height * 3
bpy.ops.object.camera_add(location=target + Vector((0,-height*5,0)))
camera = bpy.context.object
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=height*.48
scene.camera=camera
for direction, offset in [('xplus',(5,0,0)),('xminus',(-5,0,0)),('yminus',(0,-5,0)),('yplus',(0,5,0))]:
    camera.location=target + Vector(offset)*height
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    for label in ('color','clay'):
        if label == 'clay':
            mat = bpy.data.materials.get('Clay diagnostic') or bpy.data.materials.new('Clay diagnostic')
            mat.diffuse_color=(.6,.6,.6,1)
            scene.view_layers[0].material_override=mat
        else:
            scene.view_layers[0].material_override=None
        prefix = 'prepared' if prepared else 'source'
        scene.render.filepath=str(review / (prefix+'-face-'+direction+'-'+label+'.png'))
        bpy.ops.render.render(write_still=True)
