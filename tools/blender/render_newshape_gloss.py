"""Render the written angular case GLB under broad studio reflections."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
PKG=ROOT/"assets/models/black-orange-newshape"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG/"exports/GlossyAngularCase.glb"))
scene=bpy.context.scene

ground=bpy.data.materials.new("Neutral_ground")
ground.use_nodes=True
ground.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.21,.23,.26,1)
ground.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.77
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(ground)
bpy.context.object.location.z=-.055
world=bpy.data.worlds.new("Studio")
scene.world=world
world.use_nodes=True
world.node_tree.nodes["Background"].inputs["Color"].default_value=(.19,.21,.25,1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value=.4

def softbox(name,loc,power,width,height):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=power;data.shape="RECTANGLE";data.size=width;data.size_y=height
    light=bpy.data.objects.new(name,data)
    scene.collection.objects.link(light)
    light.location=loc
    light.rotation_euler=(Vector((0,0,2.2))-light.location).to_track_quat("-Z","Y").to_euler()

softbox("Tall left card",(7,-3,6),1300,1.4,8)
softbox("Tall right card",(-3,7,5),1000,1.3,7)
softbox("Roof card",(0,0,10),1500,7,2)
softbox("Front fill",(8,9,4),550,5,4)
camera_data=bpy.data.cameras.new("Camera")
camera=bpy.data.objects.new("Camera",camera_data)
scene.collection.objects.link(camera);scene.camera=camera
camera.location=(10,8,8)
camera.rotation_euler=(Vector((0,0,2.2))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.lens=45
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=960
scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(PKG/"review/gloss-study.png")
bpy.ops.render.render(write_still=True)
