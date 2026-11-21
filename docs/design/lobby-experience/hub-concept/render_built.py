"""Render the lobby as built (built/built_parts.json from dump_built.luau) from the concept's views.

    lune run docs/design/lobby-experience/hub-concept/dump_built.luau
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_built.py -- [view ...]

Same cameras and lights as render_hero.py, so built/<view>.png sits beside renders/<view>.png.
This checks the conversion (placement, rotation, what the game adds from markers), not Roblox lighting.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hub_design as hub  # noqa: E402

OUT = os.path.join(HERE, "built")
M = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # game (x, y, z) -> Blender (x, -z, y)


def to_blender(x, y, z):
    return Vector((x, -z, y))


def rotation(item):
    if "yaw" in item:
        d = math.radians(item["yaw"])
        r = Matrix(((math.cos(d), 0, math.sin(d)), (0, 1, 0), (-math.sin(d), 0, math.cos(d))))
    else:
        r = Matrix([item["rot"][0:3], item["rot"][3:6], item["rot"][6:9]])
    return M @ r @ M.transposed()


def main():
    wanted = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    # `factions`: the Faction Islands lobby, from that concept's cameras and lights, into built/factions
    variant = None
    if "factions" in wanted:
        wanted.remove("factions")
        import factions

        variant = factions.factions()
    out = os.path.join(OUT, "factions") if variant else OUT
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    with open(os.path.join(OUT, "built_parts.json"), encoding="utf-8") as handle:
        items = json.load(handle)

    meshes = {}
    for shape, op in (("Block", "cube"), ("Cylinder", "cyl"), ("Ball", "ball")):
        if op == "cube":
            bpy.ops.mesh.primitive_cube_add(size=1)
        elif op == "cyl":
            bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.5, depth=1)
            bpy.context.object.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))  # axis along x
        else:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.5)
        ob = bpy.context.object
        if op != "cube":
            for poly in ob.data.polygons:
                poly.use_smooth = True
        meshes[shape] = ob.data
        bpy.data.objects.remove(ob)
    blank = bpy.data.materials.new("blank")
    for mesh in meshes.values():
        mesh.materials.append(blank)

    cache = {}

    def material(colour, neon):
        key = (tuple(round(c, 3) for c in colour), neon)
        if key not in cache:
            mat = bpy.data.materials.new("m%d" % len(cache))
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*colour, 1)
            bsdf.inputs["Roughness"].default_value = 0.55
            if neon:
                name = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
                bsdf.inputs[name].default_value = (*colour, 1)
                bsdf.inputs["Emission Strength"].default_value = 3.0
            cache[key] = mat
        return cache[key]

    for index, item in enumerate(items):
        loc = to_blender(*item["pos"])
        rot = rotation(item).to_4x4()
        sx, sy, sz = item["size"]
        if item["shape"] == "Text":
            curve = bpy.data.curves.new("t%d" % index, "FONT")
            curve.body = item["text"]
            curve.align_x = "CENTER"
            curve.align_y = "CENTER"
            curve.size = sy * 0.8
            curve.extrude = 0.05
            ob = bpy.data.objects.new("t%d" % index, curve)
            stand = Matrix.Identity(4) if item.get("flat") else Matrix.Rotation(math.radians(90), 4, "X")
            ob.matrix_world = Matrix.Translation(loc) @ rot @ stand
            curve.materials.append(material(item["colour"], True))
        else:
            ob = bpy.data.objects.new("p%d" % index, meshes.get(item["shape"], meshes["Block"]))
            ob.matrix_world = Matrix.Translation(loc) @ rot @ Matrix.Diagonal((sx, sz, sy, 1))
            scene.collection.objects.link(ob)
            ob.material_slots[0].link = "OBJECT"
            ob.material_slots[0].material = material(item["colour"], item["neon"])
            continue
        scene.collection.objects.link(ob)

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.045, 0.08, 1)
    scene.world = world

    def light(kind, pos, colour, power, size=1.0):
        data = bpy.data.lights.new(kind + "Light", kind)
        data.color = colour
        data.energy = power
        if kind == "AREA":
            data.size = size
        else:
            data.shadow_soft_size = size
        lob = bpy.data.objects.new(data.name, data)
        lob.location = to_blender(pos[0] * hub.SCALE, pos[1], pos[2] * hub.SCALE)
        scene.collection.objects.link(lob)

    if variant:
        for kind, pos, colour, power, size in variant.LIGHTS:
            data = bpy.data.lights.new(kind + "Light", kind)
            data.color, data.energy = colour, power
            if kind == "AREA":
                data.size = size
            else:
                data.shadow_soft_size = size
            lob = bpy.data.objects.new(data.name, data)
            lob.location = to_blender(*pos)
            scene.collection.objects.link(lob)
    else:
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
    scene.cycles.samples = 64
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
    camera_data.clip_end = 2000
    for name, _title, eye, target, fov in variant.VIEWS if variant else hub.VIEWS:
        if wanted and name not in wanted:
            continue
        camera.location = to_blender(*eye)
        direction = to_blender(*target) - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        camera_data.angle_y = math.radians(fov)
        scene.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", name)


main()
