"""Blockout renders of the four alternatives (alternatives.py), same look as render_hero.py.

    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_alternatives.py -- [variant ...]

Writes alternatives/<variant>/<view>.png. Cycles on the CPU; flat colours and glow only.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import alternatives  # noqa: E402
import render_hero  # noqa: E402

to_blender = render_hero.to_blender


def light(kind, pos, colour, power, size):
    data = bpy.data.lights.new(kind + "Light", kind)
    data.color = colour
    data.energy = power
    if kind == "AREA":
        data.size = size
    else:
        data.shadow_soft_size = size
    ob = bpy.data.objects.new(data.name, data)
    ob.location = to_blender(*pos)
    if pos[1] < 0:
        ob.rotation_euler = (math.pi, 0, 0)  # an area light below the islands shines up
    bpy.context.scene.collection.objects.link(ob)


def render(variant, samples, views=()):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    cache = {}
    for part in variant.parts:
        render_hero.make(part, cache)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.045, 0.08, 1)
    scene.world = world
    for spec in variant.LIGHTS:
        light(*spec)
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.sensor_fit = "VERTICAL"
    camera_data.clip_start = 0.5
    camera_data.clip_end = 3000
    folder = os.path.join(HERE, "alternatives", variant.key)
    os.makedirs(folder, exist_ok=True)
    for name, _title, eye, target, fov in variant.VIEWS:
        if views and name not in views:
            continue
        camera.location = to_blender(*eye)
        direction = to_blender(*target) - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        camera_data.angle_y = math.radians(fov)
        scene.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", variant.key, name, flush=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    samples = 64
    import factions

    variants = dict(alternatives.VARIANTS, factions=factions.factions)
    wanted = [a for a in args if a in variants] or list(alternatives.VARIANTS)
    for key in wanted:
        render(variants[key](), samples, [a for a in args if a not in variants])


main()
