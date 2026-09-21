"""Render a processed asset at map scale, from a player's eye, before it ever
reaches Studio. This is the feedback loop scene_kit.py is missing on its own: a
backdrop that looks right in an asset viewer can still be a wall beside the
playfield, and that is only visible from inside the map.

    blender -b -noaudio --python tools/blender/preview_scene.py -- \
        --asset glacier \
        --place -2200,-150,0,0 --place 2200,-150,0,180 \
        --place 0,-150,-2200,90 --place 0,-150,2200,270 \
        --ground 9000 --ground-y -2.5 \
        --eye 0,5,0 --look -2200,100,0 \
        --out /tmp/backdrop.png

Coordinates are Roblox studs and Roblox axes (X right, Y up, Z forward), the same
numbers a map's MapArt module uses, so a placement can be copied straight across.
`--place` is x,y,z,yaw with yaw in degrees about Y.
"""

import argparse
import json
import math
import os
import sys

import bpy
import mathutils

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def triple(text, count=3):
    parts = [float(v) for v in text.split(",")]
    if len(parts) != count:
        raise SystemExit("expected %d comma-separated numbers, got %r" % (count, text))
    return parts


def to_blender(x, y, z):
    """Roblox (x, y, z) -> Blender (x, -z, y); Blender is Z-up, Roblox is Y-up."""
    return mathutils.Vector((x, -z, y))


def import_placed(path, x, y, z, yaw):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    fresh = [o for o in bpy.context.scene.objects if o not in before]
    meshes = [o for o in fresh if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no meshes in " + path)
    # The glTF importer parents meshes to an empty. Detach them, keeping their world
    # transform, so placing the joined mesh is not fighting a parent transform --
    # that bug once produced a backdrop that looked fine in isolation and wrong here.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # scene_kit exports with export_yup, so the file is Y-up like Roblox, and the
    # glTF importer hands it back that way. Blender's world is Z-up, so bake the
    # conversion in before placing, or the asset stands on its side.
    ob.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    ob.rotation_euler = (0, 0, math.radians(-yaw))  # Roblox yaw about Y is -Z in Blender
    ob.location = to_blender(x, y, z)
    # The importer's leftover empties are harmless and do not render. Removing them
    # here would walk a list whose entries the join has already invalidated.
    return ob


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="preview_scene")
    parser.add_argument("--manifest", default=os.path.join(os.path.dirname(__file__), "scenes.json"))
    parser.add_argument("--asset", help="manifest asset whose built .glb to place")
    parser.add_argument("--glb", help="explicit .glb instead of --asset")
    parser.add_argument("--place", action="append", default=[], metavar="X,Y,Z,YAW")
    parser.add_argument("--ground", type=float, default=0.0, help="flat plane size in studs")
    parser.add_argument("--ground-y", type=float, default=0.0)
    parser.add_argument("--eye", default="0,5,0")
    parser.add_argument("--look", default="0,0,0")
    parser.add_argument("--lens", type=float, default=24.0)
    parser.add_argument("--out", required=True)
    parser.add_argument("--samples", type=int, default=16)
    args = parser.parse_args(argv)

    if args.glb:
        glb = args.glb if os.path.isabs(args.glb) else os.path.join(ROOT, args.glb)
    else:
        with open(args.manifest, encoding="utf-8") as handle:
            spec = json.load(handle)["assets"][args.asset]
        glb = os.path.join(ROOT, spec["out"])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    snow = bpy.data.materials.new("snow")
    snow.use_nodes = True
    snow.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.90, 0.95, 1)
    snow.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85

    for place in args.place:
        x, y, z, yaw = triple(place, 4)
        ob = import_placed(glb, x, y, z, yaw)
        ob.data.materials.clear()
        ob.data.materials.append(snow)

    if args.ground > 0:
        bpy.ops.mesh.primitive_plane_add(size=args.ground)
        plane = bpy.context.object
        plane.location = to_blender(0, args.ground_y, 0)
        plane.data.materials.append(snow)

    # A marker the size of the arena floor, so scale is legible in the render.
    bpy.ops.mesh.primitive_cube_add(size=1)
    arena = bpy.context.object
    arena.scale = (490, 370, 2)
    arena.location = to_blender(0, 0, 0)
    marker = bpy.data.materials.new("arena")
    marker.use_nodes = True
    marker.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.85, 0.35, 0.15, 1)
    arena.data.materials.append(marker)

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52), 0, math.radians(35))

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 960
    scene.render.resolution_y = 500
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.60, 0.86, 1)

    eye = to_blender(*triple(args.eye))
    look = to_blender(*triple(args.look))
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = args.lens
    cam_data.clip_start = 0.5
    cam_data.clip_end = 60000
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = eye
    cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()

    out = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("wrote " + out)


main()
