"""Player's-eye renders of a measured map, built from its parts list.

    blender -b -noaudio --python tools/blender/render_map_views.py -- --measure <measure.json> --out-dir <dir>

Normally run through `python tools/map_views.py <Name>`. measure.json (written by
tools/measure_map.luau) lists every baked part and the design's `views` (eye, look). Each
part becomes a box with its colour; Neon parts glow, Glass is see-through, and parts named
like a lamp carry a point light, since the rooms are under a roof.

This is a blockout preview in Blender's lighting. It shows shapes, cover heights and what is
in view from a spot. It is not how Roblox will light or texture the map.
"""

import argparse
import json
import math
import os
import sys

import bpy
import mathutils


def to_blender(v):
    """Roblox (x, y up, z) -> Blender (x, -z, z up). Keeps handedness."""
    return mathutils.Vector((v[0], -v[2], v[1]))


def material_for(cache, part):
    colour = tuple(round(c, 3) for c in part["color"])
    key = (colour, part["material"], round(part["transparency"], 2))
    if key in cache:
        return cache[key]
    mat = bpy.data.materials.new("m%d" % len(cache))
    mat.use_nodes = True
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = 0.25 if part["material"] in ("Glass", "Marble", "Metal") else 0.7
    if part["material"] == "Neon":
        shader.inputs["Emission Color"].default_value = (*colour, 1.0)
        shader.inputs["Emission Strength"].default_value = 4.0
    if part["transparency"] > 0.05:
        shader.inputs["Alpha"].default_value = 1.0 - part["transparency"] * 0.8
    cache[key] = mat
    return mat


def world_bounds(objects):
    corners = [o.matrix_world @ mathutils.Vector(c) for o in objects if o.type == "MESH" for c in o.bound_box]
    lo = mathutils.Vector([min(c[i] for c in corners) for i in range(3)])
    hi = mathutils.Vector([max(c[i] for c in corners) for i in range(3)])
    return lo, hi


def place_props(sc, props):
    """Import each prop's GLB and stand it where MapService would: turned, scaled so its
    longer ground side is `fit`, bounding-box centre over the point, lowest point on it."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # tools/blender -> repo
    placed = 0
    for prop in props:
        path = prop.get("glb") and os.path.join(root, prop["glb"])
        if not path or not os.path.isfile(path):
            continue
        before = set(sc.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in sc.objects if o not in before]
        holder = bpy.data.objects.new(prop["name"], None)
        sc.collection.objects.link(holder)
        for o in new:
            if o.parent is None:
                o.parent = holder
        bpy.context.view_layer.update()
        holder.rotation_euler = (0, 0, math.radians(prop.get("yaw") or 0))
        bpy.context.view_layer.update()
        lo, hi = world_bounds(new)
        if prop.get("fit"):
            longest = max(hi.x - lo.x, hi.y - lo.y)
            if longest > 0:
                holder.scale = (prop["fit"] / longest,) * 3
                bpy.context.view_layer.update()
                lo, hi = world_bounds(new)
        target = to_blender(prop["pos"])
        holder.location += mathutils.Vector((target.x - (lo.x + hi.x) / 2, target.y - (lo.y + hi.y) / 2, target.z - lo.z))
        placed += 1
    bpy.context.view_layer.update()
    return placed


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="render_map_views")
    ap.add_argument("--measure", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--width", type=int, default=960)
    ap.add_argument("--height", type=int, default=540)
    args = ap.parse_args(argv)

    with open(args.measure, encoding="utf-8") as handle:
        data = json.load(handle)
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_cube_add(size=1)
    template = bpy.context.active_object
    cube = template.data
    sc.collection.objects.unlink(template)

    cache, lamps = {}, 0
    hidden = set(data.get("hidden", []))
    for part in data["parts"]:
        if part["transparency"] >= 0.99 or part["name"] in hidden or part["name"][:-4] in hidden and part["name"].endswith("Band"):
            continue  # an invisible collision block with a prop drawn over it
        r, size = part["rot"], part["size"]
        columns = [to_blender((r[i], r[3 + i], r[6 + i])) * size[i] for i in range(3)]
        position = to_blender(part["pos"])
        matrix = mathutils.Matrix((
            (columns[0].x, columns[1].x, columns[2].x, position.x),
            (columns[0].y, columns[1].y, columns[2].y, position.y),
            (columns[0].z, columns[1].z, columns[2].z, position.z),
            (0, 0, 0, 1),
        ))
        ob = bpy.data.objects.new(part["name"], cube.copy())
        ob.matrix_world = matrix
        ob.data.materials.append(material_for(cache, part))
        sc.collection.objects.link(ob)
        name = part["name"].lower()
        if part["material"] == "Neon" and ("light" in name or "lamp" in name or "chandelier" in name):
            light = bpy.data.objects.new("lamp", bpy.data.lights.new("lamp", "POINT"))
            light.data.energy = 2500
            light.data.shadow_soft_size = 2.0
            light.data.color = part["color"]
            light.location = position - mathutils.Vector((0, 0, 1.5))
            sc.collection.objects.link(light)
            lamps += 1

    placed = place_props(sc, data.get("props", []))

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.render.resolution_x, sc.render.resolution_y = args.width, args.height
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("dusk")
    sc.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (0.42, 0.40, 0.55, 1.0)
    background.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(68), 0, math.radians(-40))
    sun.data.energy = 2.0
    sun.data.color = (1.0, 0.78, 0.62)

    cam = bpy.data.objects.new("eye", bpy.data.cameras.new("eye"))
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle = math.radians(70)  # Roblox's default field of view
    cam.data.clip_start = 0.3
    cam.data.clip_end = 3000
    sc.collection.objects.link(cam)
    sc.camera = cam

    written = []
    for view in data.get("views", []):
        eye, look = to_blender(view["eye"]), to_blender(view["look"])
        cam.location = eye
        cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, view["name"] + ".png")
        bpy.ops.render.render(write_still=True)
        written.append(view["name"])
        print("map view %s" % view["name"], flush=True)

    with open(os.path.join(out_dir, "views.json"), "w", encoding="utf-8") as handle:
        json.dump({"views": written, "lamps": lamps, "parts": len(data["parts"]), "props": placed}, handle, indent=2)
        handle.write(chr(10))


main()
