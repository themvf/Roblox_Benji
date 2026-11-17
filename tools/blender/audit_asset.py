"""Render an asset for a visual audit: every side, bright, plus close-ups and a hole map.

    blender -b -noaudio --python tools/blender/audit_asset.py -- --source "<glb>" --out-dir "<dir>"

Normally run through `python tools/asset_generate.py audit <name>`, which also builds the
sheets and measures the hole map. The appraiser's views.png is three small dark views; it
hid a fourth rotor blade and could not say whether two pale rectangles were holes.

Each view is rendered twice into --out-dir:

  color_<view>.png   textured, lit from the sky as well as the sun, transparent background,
                     back faces invisible: one-sided, the way Roblox draws a mesh.
  holes_<view>.png   front faces grey, BACK faces magenta. Any magenta you can see is a
                     place the game shows straight through: a hole into the hollow inside,
                     a flipped patch, or a sheet with no reverse side.

Views: front, back, left, right, top, bottom, four three-quarter views from above, then
close-ups of three to six sections along the longest axis from both sides, each at most
--closeup-studs across. --focus x,y,z
(fractions of the bounding box, repeatable) adds a close-up pair at a point of your choice.

views.json lists what was rendered. Nothing here judges the asset.
"""

import argparse
import json
import os
import sys

import bpy
import mathutils

MAGENTA = (1.0, 0.0, 1.0, 1.0)


def load(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit("unsupported source format: " + ext)
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def hole_material():
    mat = bpy.data.materials.new("audit_holes")
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    mix = tree.nodes.new("ShaderNodeMixShader")
    geometry = tree.nodes.new("ShaderNodeNewGeometry")
    # Front faces are emission too, shaded by how squarely they face the camera. A lit diffuse
    # surface came out as sampling noise at this sample count and went black inside every
    # cavity, which made back-face speckle impossible to tell from shadow.
    facing = tree.nodes.new("ShaderNodeLayerWeight")
    shade = tree.nodes.new("ShaderNodeMath")
    shade.operation = "MULTIPLY_ADD"
    shade.inputs[1].default_value = -0.5
    shade.inputs[2].default_value = 0.8
    tree.links.new(facing.outputs["Facing"], shade.inputs[0])
    front = tree.nodes.new("ShaderNodeEmission")
    front.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    tree.links.new(shade.outputs[0], front.inputs["Strength"])
    back = tree.nodes.new("ShaderNodeEmission")
    back.inputs["Color"].default_value = MAGENTA
    back.inputs["Strength"].default_value = 1.0
    tree.links.new(geometry.outputs["Backfacing"], mix.inputs["Fac"])
    tree.links.new(front.outputs["Emission"], mix.inputs[1])
    tree.links.new(back.outputs["Emission"], mix.inputs[2])
    tree.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def cull_back_faces(meshes):
    """Make every back face invisible in the colour pass, as Roblox does.

    Cycles draws both sides, so a missing or flipped face used to render as solid, textured
    surface: the radio tower's colour views looked whole while every strut was see-through
    in game. With this, a hole in the colour view is a hole in Roblox."""
    seen = set()
    for obj in meshes:
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or mat.name in seen or not mat.use_nodes:
                continue
            seen.add(mat.name)
            tree = mat.node_tree
            out = next((n for n in tree.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
            if out is None or not out.inputs["Surface"].links:
                continue
            surface = out.inputs["Surface"].links[0].from_socket
            mix = tree.nodes.new("ShaderNodeMixShader")
            geometry = tree.nodes.new("ShaderNodeNewGeometry")
            clear = tree.nodes.new("ShaderNodeBsdfTransparent")
            tree.links.new(geometry.outputs["Backfacing"], mix.inputs["Fac"])
            tree.links.new(surface, mix.inputs[1])
            tree.links.new(clear.outputs["BSDF"], mix.inputs[2])
            tree.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="audit_asset")
    ap.add_argument("--source", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--size", type=int, default=640, help="pixels per view")
    ap.add_argument("--zoom", type=float, default=3.0, help="close-up magnification for --focus")
    ap.add_argument("--focus", action="append", default=[], help="x,y,z as fractions of the bounding box")
    ap.add_argument("--closeup-studs", type=float, default=0.0, help="a close-up frames at most this many studs (0: a third of the model)")
    ap.add_argument("--height-studs", type=float, default=0.0, help="finished height, for a source that is not in studs yet (0: one unit is one stud)")
    args = ap.parse_args(argv)

    out_dir = os.path.abspath(args.out_dir)  # Blender resolves relative render paths against its own directory
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meshes = load(args.source)
    if not meshes:
        raise SystemExit("no meshes found")

    corners = [o.matrix_world @ mathutils.Vector(c) for o in meshes for c in o.bound_box]
    lo = mathutils.Vector([min(c[i] for c in corners) for i in range(3)])
    hi = mathutils.Vector([max(c[i] for c in corners) for i in range(3)])
    box = [mathutils.Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    mid, span = (lo + hi) / 2, hi - lo
    diag = span.length

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.render.resolution_x = sc.render.resolution_y = args.size
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.use_persistent_data = True
    # Standard, not Filmic/AgX: the hole map is measured by colour, so magenta must stay magenta.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    world = bpy.data.worlds.new("audit")
    sc.world = world
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
    background.inputs[1].default_value = 0.8  # sky light from every side, so no view is in the dark
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (0.8, 0.2, 0.6)
    sun.data.energy = 2.0
    holes = hole_material()
    cull_back_faces(meshes)
    sc.cycles.transparent_max_bounces = 32  # a lattice stacks many culled faces along one ray

    cam = bpy.data.objects.new("audit", bpy.data.cameras.new("audit"))
    cam.data.type = "ORTHO"
    cam.data.clip_start = diag * 0.01
    cam.data.clip_end = diag * 10
    sc.collection.objects.link(cam)
    sc.camera = cam

    views = []

    def shoot(name, kind, direction, target, scale=None):
        direction = mathutils.Vector(direction).normalized()
        quat = (-direction).to_track_quat("-Z", "Y")
        cam.rotation_euler = quat.to_euler()
        cam.location = target + direction * diag * 3
        if scale is None:  # fit the whole bounding box as seen from here
            right, up = quat @ mathutils.Vector((1, 0, 0)), quat @ mathutils.Vector((0, 1, 0))
            scale = 2.12 * max(max(abs((c - target).dot(right)), abs((c - target).dot(up))) for c in box)
        cam.data.ortho_scale = scale
        for render_pass in ("color", "holes"):
            colour = render_pass == "color"
            bpy.context.view_layer.material_override = None if colour else holes
            sc.cycles.samples = 16 if colour else 8
            sc.cycles.use_denoising = colour
            sc.cycles.max_bounces = 4 if colour else 0  # no bounce: magenta must not tint its surroundings
            sc.render.filepath = os.path.join(out_dir, "%s_%s.png" % (render_pass, name))
            bpy.ops.render.render(write_still=True)
        views.append({"name": name, "kind": kind, "color": "color_%s.png" % name, "holes": "holes_%s.png" % name})
        print("audit view %s" % name, flush=True)

    for name, direction in (
        ("front", (0, -1, 0)),
        ("back", (0, 1, 0)),
        ("left", (-1, 0, 0)),
        ("right", (1, 0, 0)),
        ("top", (0, 0, 1)),
        ("bottom", (0, 0, -1)),
        ("front-left", (-1, -1, 0.6)),
        ("front-right", (1, -1, 0.6)),
        ("back-left", (-1, 1, 0.6)),
        ("back-right", (1, 1, 0.6)),
    ):
        shoot(name, "overview", direction, mid)

    # Close-ups: sections along the longest axis, looked at from each side. They used to be
    # framed on the model's height, so a 60-stud tower got six more pictures of the whole
    # tower with struts three pixels wide. Now a frame is at most --closeup-studs across.
    along = 0 if span.x >= span.y else 1
    across = 1 - along
    units_per_stud = span.z / args.height_studs if args.height_studs > 0 else 1.0
    frame = max(span[along] / 3, span.z) * 1.2
    tall = False
    if args.closeup_studs > 0 and frame > args.closeup_studs * units_per_stud:
        frame = args.closeup_studs * units_per_stud
        tall = span.z > max(span.x, span.y)
    walk = 2 if tall else along  # step up a tower, along a wall
    stations = min(6, max(3, int(span[walk] / frame + 0.999)))
    for index in range(stations):
        target = mid.copy()
        target[walk] = lo[walk] + span[walk] * (index + 0.5) / stations
        for side, sign in (("a", -1), ("b", 1)):
            direction = [0.0, 0.0, 0.45]
            direction[across] = sign
            if tall:
                direction[along] = 0.5 * sign  # off the axis, so the near and far faces do not line up
            shoot("section-%d%s" % (index + 1, side), "closeup", direction, target, frame)

    for index, text in enumerate(args.focus):
        fx, fy, fz = [float(v) for v in text.split(",")]
        target = mathutils.Vector((lo.x + span.x * fx, lo.y + span.y * fy, lo.z + span.z * fz))
        for side, sign in (("a", -1), ("b", 1)):
            direction = [0.0, 0.0, 0.3]
            direction[across] = sign
            shoot("focus-%d%s" % (index + 1, side), "closeup", direction, target, max(span) / args.zoom)

    with open(os.path.join(out_dir, "views.json"), "w", encoding="utf-8") as handle:
        json.dump(
            {
                "source": os.path.basename(args.source),
                "size": [round(v, 3) for v in span],
                "longAxis": "xy"[along],
                "views": views,
            },
            handle,
            indent=2,
        )
        handle.write(chr(10))


main()
