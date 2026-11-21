"""Blockout renders of the proposed hub (hub_design.py), one PNG per view.

    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_hero.py -- [view ...]

Cycles on the CPU (EEVEE crashes headless here). Flat colours and glow only: this shows
composition, scale and sightlines, not materials, Roblox lighting or finished art.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hub_design as hub  # noqa: E402

OUT = os.path.join(HERE, "renders")


def to_blender(x, y, z):
    return Vector((x, -z, y))


def material(cache, colour, glow):
    key = (tuple(round(c, 3) for c in colour), glow)
    if key in cache:
        return cache[key]
    mat = bpy.data.materials.new("m%d" % len(cache))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    if glow > 0:
        name = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[name].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = glow * 0.45
    cache[key] = mat
    return mat


def make(part, cache):
    kind = part["kind"]
    x, y, z = part["pos"]
    sx, sy, sz = part["size"]
    yaw = math.radians(part["rot"])
    location = to_blender(x, y, z)
    if kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=location)
        ob = bpy.context.object
        ob.scale = (sx, sz, sy)
        ob.rotation_euler = (0, 0, yaw)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=sx / 2, depth=sy, location=location)
        ob = bpy.context.object
        ob.rotation_euler = (0, 0, yaw)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=sx / 2, location=location)
        ob = bpy.context.object
    elif kind == "ring":
        bpy.ops.mesh.primitive_torus_add(
            major_segments=96, minor_segments=16, major_radius=sx / 2, minor_radius=part["tube"], location=location
        )
        ob = bpy.context.object
        if part.get("flat"):
            ob.rotation_euler = (0, 0, yaw)  # lying on the floor
        else:
            # standing, facing the arrival point; `tilt` leans it back like an accretion disc
            ob.rotation_euler = (math.radians(90 - part.get("tilt", 0)), 0, yaw)
    elif kind == "text":
        bpy.ops.object.text_add(location=location)
        ob = bpy.context.object
        ob.data.body = part["text"]
        ob.data.align_x = "CENTER"
        ob.data.align_y = "CENTER"
        ob.data.size = sx
        ob.data.extrude = 0.08
        if part.get("flat"):
            ob.rotation_euler = (0, 0, yaw)  # readable from the south, lying on the floor
        elif part.get("back"):
            ob.rotation_euler = (math.radians(90), 0, yaw + math.pi)  # on the south wall, facing north
        else:
            ob.rotation_euler = (math.radians(90), 0, yaw)
    else:
        raise ValueError(kind)
    ob.name = part["name"]
    ob.data.materials.append(material(cache, part["colour"], part["glow"]))
    if kind in ("cyl", "sphere", "ring"):
        for poly in ob.data.polygons:
            poly.use_smooth = True
    return ob


def light(kind, pos, colour, power, size=1.0):
    data = bpy.data.lights.new(kind + "Light", kind)
    data.color = colour
    data.energy = power
    if kind == "AREA":
        data.size = size
    else:
        data.shadow_soft_size = size
    ob = bpy.data.objects.new(data.name, data)
    ob.location = to_blender(pos[0] * hub.SCALE, pos[1], pos[2] * hub.SCALE)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main():
    wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    cache = {}
    for part in hub.parts:
        make(part, cache)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.045, 0.08, 1)
    scene.world = world
    # a soft cool fill so dark surfaces read, then one warm pool per destination
    light("AREA", (0, 200, -30), (0.6, 0.7, 1.0), 170000, 450)
    light("POINT", (0, 34, -140), hub.GOLD, 11000, 6)
    light("POINT", (0, 30, -148), hub.VIOLET, 6000, 4)
    light("POINT", (-100, 18, 0), hub.GOLD, 4500, 6)
    light("POINT", (100, 18, 0), hub.VIOLET, 5000, 6)
    light("POINT", (0, 22, 8), (1, 0.9, 0.75), 5000, 8)
    light("POINT", (0, 22, -70), (1, 0.9, 0.75), 5000, 8)
    light("POINT", (0, 18, 98), hub.GOLD, 4000, 6)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.exposure = 0.0
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    os.makedirs(OUT, exist_ok=True)
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.sensor_fit = "VERTICAL"
    camera_data.clip_start = 0.5
    camera_data.clip_end = 2000
    for name, _title, eye, target, fov in hub.VIEWS:
        if wanted and name not in wanted:
            continue
        camera.location = to_blender(*eye)
        direction = to_blender(*target) - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        camera_data.angle_y = math.radians(fov)
        scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", name)


if __name__ == "__main__":
    main()
