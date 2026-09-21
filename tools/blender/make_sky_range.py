"""Generate a snowy mountain horizon and render it as Roblox skybox faces.

Why generated rather than from a bought scan: a terrain scan is authored to be
looked at from directly above. Asked to be a horizon it fails three ways at once --
its texture is an orthographic bake so it smears when seen from the side, the
silhouette that sells a mountain is destroyed by the decimation in-game meshes
demand, and a heightfield is a single sheet with no underside and a cliff on every
edge. Generating the silhouette controls the one thing that actually matters here,
and a skybox is rendered offline so detail costs nothing at runtime.

    blender -b -noaudio --python tools/blender/make_sky_range.py -- \
        --out assets/sky/snowfortress --faces ft --size 1024
    blender -b -noaudio --python tools/blender/make_sky_range.py -- \
        --out assets/sky/snowfortress --size 1024 --samples 96

Faces use Roblox's names: ft bk lf rt up dn (ft is -Z, rt is +X, up is +Y).
The result is six square PNGs to upload and hang on a Sky instance; in game it
costs no parts, no triangles and cannot be mis-oriented.
"""

import argparse
import math
import os
import random
import sys

import bpy

FACES = {
    "ft": (math.radians(90), 0, 0),
    "bk": (math.radians(90), 0, math.radians(180)),
    "lf": (math.radians(90), 0, math.radians(90)),
    "rt": (math.radians(90), 0, math.radians(-90)),
    # A Blender camera at (0,0,0) looks along -Z, which is DOWN. So the zenith view
    # needs the 180 flip and the nadir view is the unrotated one -- the obvious
    # reading of these two is backwards, and shipping it swapped puts ground
    # overhead and sky underfoot.
    "up": (math.radians(180), 0, 0),
    "dn": (0, 0, 0),
}


def snow_material():
    """Snow that goes bluish in shadow, with rock showing on the steepest faces --
    a flat white silhouette reads as cardboard at this distance."""
    mat = bpy.data.materials.new("Snow")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.55

    geometry = nt.nodes.new("ShaderNodeNewGeometry")
    separate = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geometry.outputs["Normal"], separate.inputs["Vector"])
    # Z of the normal is 1 on flat ground and 0 on a vertical face.
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "EASE"
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = (0.20, 0.21, 0.24, 1)  # exposed rock
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = (0.94, 0.96, 1.00, 1)  # snow
    nt.links.new(separate.outputs["Z"], ramp.inputs["Fac"])

    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    noise.inputs["Detail"].default_value = 8.0
    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "OVERLAY"
    mix.inputs["Fac"].default_value = 0.12
    nt.links.new(ramp.outputs["Color"], mix.inputs["Color1"])
    nt.links.new(noise.outputs["Color"], mix.inputs["Color2"])
    nt.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def build_range(args, material):
    rng = random.Random(args.seed)
    rows = ((args.peaks, 1.00, 1.00), (max(4, args.peaks // 2), 1.70, 1.70))
    for row, (count, distance_scale, size_scale) in enumerate(rows):
        for i in range(count):
            angle = (i + rng.uniform(-0.34, 0.34)) * 2 * math.pi / count
            distance = args.radius * distance_scale * rng.uniform(0.88, 1.16)
            radius = rng.uniform(0.30, 0.52) * args.radius * size_scale
            height = rng.uniform(0.34, 0.70) * args.radius * size_scale
            bpy.ops.mesh.primitive_cone_add(
                vertices=56,
                radius1=radius,
                radius2=radius * rng.uniform(0.0, 0.08),
                depth=height,
                location=(
                    math.cos(angle) * distance,
                    math.sin(angle) * distance,
                    args.ground + height / 2 - radius * 0.30,
                ),
            )
            cone = bpy.context.object
            cone.name = "Peak%d_%02d" % (row, i)
            cone.rotation_euler = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), rng.uniform(0, 6.283))
            sub = cone.modifiers.new("sub", "SUBSURF")
            sub.subdivision_type = "SIMPLE"
            sub.levels = sub.render_levels = 4
            # Two octaves: broad ridges, then a finer break-up so the silhouette
            # is never a clean cone edge.
            for index, (scale, strength) in enumerate(
                ((radius * 0.85, radius * 0.34), (radius * 0.22, radius * 0.11))
            ):
                tex = bpy.data.textures.new("rock%d_%02d_%d" % (row, i, index), "CLOUDS")
                tex.noise_scale = scale
                tex.noise_depth = 4
                disp = cone.modifiers.new("disp%d" % index, "DISPLACE")
                disp.texture = tex
                disp.strength = strength
                disp.mid_level = 0.5
            bpy.ops.object.shade_smooth()
            cone.data.materials.append(material)

    bpy.ops.mesh.primitive_plane_add(size=args.radius * 40)
    plain = bpy.context.object
    plain.name = "Plain"
    plain.location = (0, 0, args.ground)
    plain.data.materials.append(material)


def setup_world(scene, args):
    """Physical sky rather than a hand-rolled gradient.

    A colour ramp driven off the view vector gave a flat grey zenith -- wrong, and
    fiddly to tune. Nishita computes real atmospheric scattering, so the horizon
    glow, the zenith blue and the light on the peaks all agree with the same sun
    angle for free."""
    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    background = nt.nodes["Background"]
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "NISHITA"
    sky.sun_elevation = math.radians(args.sun)
    sky.sun_rotation = math.radians(40)
    sky.sun_intensity = 0.4
    sky.air_density = 1.4
    sky.dust_density = 2.2
    nt.links.new(sky.outputs["Color"], background.inputs["Color"])
    # Nishita is a far brighter environment than a flat gradient; left at full
    # strength it blows the snow out to pure white with no ridge shading left.
    background.inputs["Strength"].default_value = args.sky_strength


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="make_sky_range")
    ap.add_argument("--out", required=True, help="output prefix; faces append _ft etc")
    ap.add_argument("--faces", default="ft,bk,lf,rt,up,dn")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--peaks", type=int, default=20)
    ap.add_argument("--radius", type=float, default=2600.0)
    ap.add_argument("--ground", type=float, default=-120.0)
    ap.add_argument("--sun", type=float, default=34.0)
    ap.add_argument("--sky-strength", type=float, default=0.22, help="environment light from the sky")
    ap.add_argument("--exposure", type=float, default=-0.7)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    build_range(args, snow_material())
    setup_world(scene, args)

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.1
    sun_data.angle = math.radians(2.0)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - args.sun), 0, math.radians(40))

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = args.size
    scene.view_settings.exposure = args.exposure

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "VERTICAL"
    cam_data.sensor_height = 36.0
    cam_data.lens = 18.0  # exactly 90 degrees, which is what a cube face needs
    cam_data.clip_start = 1.0
    cam_data.clip_end = 500000.0
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0, 0, 0)

    out = args.out if os.path.isabs(args.out) else os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    for face in [f.strip() for f in args.faces.split(",") if f.strip()]:
        if face not in FACES:
            raise SystemExit("unknown face %r; use ft bk lf rt up dn" % face)
        cam.rotation_euler = FACES[face]
        scene.render.filepath = "%s_%s.png" % (out, face)
        bpy.ops.render.render(write_still=True)
        print("wrote %s_%s.png" % (out, face))


main()
