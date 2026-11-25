"""Clean low-poly build of the Lightning Carbine, modelled from the user's concept art. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_lightning_carbine.py
    blender -b -noaudio --python tools/blender/build_lightning_carbine.py -- --no-render

A held gun goes the clean route (asset_rules: held is a close role), so nothing here is
generated: the concept picture in source/user-picture.webp sets the proportions and the
palette, and every piece is a hard-edged slab or loft in the game's chunky style.

Units are studs. Blender Z is up and the muzzle points down -Y, which exports to glTF +Z
and arrives in Roblox facing -Z. The profile tables below are written as (u, v): u runs
from the stock butt (0) to the muzzle (4.5), v from the bottom of the grip (0) up.
The finished mesh is centred on its bounding box (brief pivot: center).

Two meshes are exported: "Body" (palette texture) and "Glow", the plate between the copper
coil rails, kept apart so Studio can make it Neon. The lightning arc itself is not
geometry: it is a Beam between the two rails, added in game.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/lightning-carbine"
EXPORT = PKG / "exports/LightningCarbineClean.glb"
PALETTE_PNG = PKG / "textures/LightningCarbineClean_Palette.png"
REVIEW = PKG / "review"

# Flat colours, sRGB 0-255, sampled by eye from the concept. One swatch each in a 4x2 atlas;
# every face's UVs sit at the centre of its swatch so filtering never bleeds a neighbour in.
PALETTE = [
    ("yellow", (236, 186, 34)),
    ("yellow_shade", (196, 148, 22)),
    ("gunmetal", (62, 58, 54)),
    ("black", (24, 23, 24)),
    ("copper", (188, 106, 64)),
    ("copper_dark", (128, 68, 42)),
    ("steel", (104, 102, 98)),
    ("glow", (150, 205, 255)),
]
COLS, ROWS, SWATCH = 4, 2, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}

# Coil rails: centre heights (v) and radius, shared by the rails, caps and the glow plate.
RAIL_TOP, RAIL_LOW, RAIL_R = 1.26, 0.74, 0.10
MUZZLE_U = 4.5


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _paint(self, faces, colour):
        i = INDEX[colour]
        u = (i % COLS + 0.5) / COLS
        v = 1 - (i // COLS + 0.5) / ROWS
        for face in faces:
            for loop in face.loops:
                loop[self.uv].uv = (u, v)

    def loft(self, stations, colour, axis="y"):
        """Skin a closed shape through cross-sections, capped at both ends.

        axis "y": each station is (u, ring of (x, z)), placed at Blender y = -u.
        axis "x": each station is (x, ring of (u, v)), the side profile at that width.
        """
        rings = []
        for pos, ring in stations:
            if axis == "y":
                rings.append([self.bm.verts.new((a, -pos, b)) for a, b in ring])
            else:
                rings.append([self.bm.verts.new((pos, -a, b)) for a, b in ring])
        faces = []
        count = len(rings[0])
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(count):
                j = (i + 1) % count
                faces.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        faces.append(self.bm.faces.new(rings[0]))
        faces.append(self.bm.faces.new(list(reversed(rings[-1]))))
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self._paint(faces, colour)
        return faces

    def slab(self, profile, half_width, colour, bevel=0.025, centre_x=0.0):
        """Extrude a convex side profile (u, v) across the width, with chamfered side edges."""
        cu = sum(p[0] for p in profile) / len(profile)
        cv = sum(p[1] for p in profile) / len(profile)

        def inset(amount):
            # One scale for every point keeps each chamfer face planar.
            extent = min(max(p[0] for p in profile) - min(p[0] for p in profile), max(p[1] for p in profile) - min(p[1] for p in profile))
            k = max(0.0, 1 - 2 * amount / extent)
            return [(cu + (u - cu) * k, cv + (v - cv) * k) for u, v in profile]

        small = inset(bevel)
        stations = [
            (centre_x - half_width, small),
            (centre_x - half_width + bevel, profile),
            (centre_x + half_width - bevel, profile),
            (centre_x + half_width, small),
        ]
        return self.loft(stations, colour, axis="x")

    def block(self, u0, u1, z0, z1, half_width, colour, chamfer=0.04, taper_front=0.0, taper_back=0.0, centre_x=0.0):
        """A length-wise block with chamfered long edges; tapers shrink an end's section."""

        def section(shrink):
            w = half_width - shrink
            b, t = z0 + shrink, z1 - shrink
            c = min(chamfer, w * 0.5, (t - b) * 0.3)
            ring = [(-w + c, b), (w - c, b), (w, b + c), (w, t - c), (w - c, t), (-w + c, t), (-w, t - c), (-w, b + c)]
            return [(x + centre_x, z) for x, z in ring]

        return self.loft([(u0, section(taper_back)), (u1, section(taper_front))], colour)

    def tube(self, cz, u0, u1, radius, colour, sides=12, cx=0.0):
        ring = [(cx + radius * math.cos(2 * math.pi * k / sides), cz + radius * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
        return self.loft([(u0, ring), (u1, ring)], colour)

    def dome(self, cz, u0, u1, radius, colour, sides=12):
        """A cylinder whose front end rounds over to a smaller flat face (the copper caps)."""

        def ring(r):
            return [(r * math.cos(2 * math.pi * k / sides), cz + r * math.sin(2 * math.pi * k / sides)) for k in range(sides)]

        span = u1 - u0
        return self.loft(
            [(u0, ring(radius)), (u0 + span * 0.55, ring(radius)), (u0 + span * 0.85, ring(radius * 0.86)), (u1, ring(radius * 0.6))],
            colour,
        )


def shroud_ring(w, z0, z1):
    """Upper shroud section: flat sides and a rounded top, as in the concept."""
    top = z1 - w * 0.55
    ring = [(-w, z0), (w, z0), (w, top)]
    for k in range(1, 6):
        a = math.pi * k / 6
        ring.append((w * math.cos(a), top + (z1 - top) * math.sin(a)))
    ring.append((-w, top))
    return ring


def build_body():
    b = Builder()
    # --- Receiver (yellow) with its panel breaks and side hardware.
    b.block(0.98, 2.22, 0.80, 1.70, 0.27, "yellow", chamfer=0.06, taper_back=0.03)
    b.block(1.30, 2.10, 1.42, 1.50, 0.275, "yellow_shade", chamfer=0.01)
    b.block(1.12, 1.30, 1.20, 1.60, 0.275, "yellow_shade", chamfer=0.01)
    for side in (-1, 1):
        x = 0.29 * side
        # Ejection slot, the small box ahead of it, and the charging lever.
        b.block(1.42, 1.72, 1.30, 1.38, 0.025, "black", chamfer=0.005, centre_x=x)
        b.block(1.88, 2.10, 0.98, 1.26, 0.04, "gunmetal", chamfer=0.01, centre_x=0.27 * side + 0.02 * side)
        b.block(1.06, 1.24, 1.06, 1.12, 0.03, "gunmetal", chamfer=0.005, centre_x=x)
    # --- Upper shroud over the coils (yellow, rounded top).
    b.loft([(2.16, shroud_ring(0.28, 1.40, 1.72)), (3.68, shroud_ring(0.28, 1.40, 1.70))], "yellow")
    b.block(2.40, 3.40, 1.40, 1.46, 0.285, "yellow_shade", chamfer=0.01)
    # --- Lower beam under the coils (yellow) and the front pod under it (gunmetal).
    b.block(2.16, 3.68, 0.52, 0.66, 0.27, "yellow", chamfer=0.03)
    b.block(2.50, 3.72, 0.10, 0.54, 0.27, "gunmetal", chamfer=0.06, taper_back=0.04)
    b.block(2.70, 3.50, 0.28, 0.40, 0.275, "black", chamfer=0.01)
    # --- Back wall of the coil window, so the window reads as a recess (black).
    b.block(2.18, 3.66, 0.64, 1.42, 0.10, "black", chamfer=0.02)
    # --- Coil rails (copper) from the receiver into the muzzle housing, a pair on each
    # side of the back wall, so both flanks show the concept's two rails.
    for side in (-1, 1):
        for cz in (RAIL_TOP, RAIL_LOW):
            b.tube(cz, 2.16, 3.70, RAIL_R, "copper", cx=0.16 * side)
    # Collars where the rails leave the receiver (gunmetal).
    b.block(2.16, 2.28, 0.64, 1.42, 0.28, "gunmetal", chamfer=0.04)
    # --- Muzzle housing: two chamfered lobes, one per rail (gunmetal), and a clamp between.
    b.block(3.64, 4.40, 0.96, 1.74, 0.31, "gunmetal", chamfer=0.13, taper_front=0.02)
    b.block(3.64, 4.40, 0.10, 0.98, 0.31, "gunmetal", chamfer=0.13, taper_front=0.02)
    b.block(3.90, 4.08, 0.86, 1.08, 0.325, "black", chamfer=0.03)
    for side in (-1, 1):
        # Bolt heads on the housing flanks.
        b.block(3.74, 3.82, 1.30, 1.38, 0.02, "steel", chamfer=0.005, centre_x=0.315 * side)
        b.block(3.74, 3.82, 0.56, 0.64, 0.02, "steel", chamfer=0.005, centre_x=0.315 * side)
    # Front sight on the housing.
    b.slab([(3.78, 1.72), (3.98, 1.72), (3.96, 1.86), (3.84, 1.86)], 0.07, "gunmetal", bevel=0.015)
    # Copper caps and bores at the muzzle.
    for cz in (RAIL_TOP - 0.06, RAIL_LOW - 0.12):
        b.tube(cz, 4.30, 4.41, 0.17, "black")
        b.dome(cz, 4.36, MUZZLE_U - 0.01, 0.14, "copper")
        b.tube(cz, MUZZLE_U - 0.02, MUZZLE_U, 0.045, "black", sides=8)
    # --- Top rail, optic housing and rear sight (gunmetal).
    b.block(1.10, 2.70, 1.69, 1.76, 0.10, "gunmetal", chamfer=0.015)
    b.block(1.36, 1.96, 1.74, 1.90, 0.14, "gunmetal", chamfer=0.04)
    b.slab([(1.24, 1.74), (1.40, 1.74), (1.38, 1.94), (1.28, 1.94)], 0.10, "gunmetal", bevel=0.015)
    b.block(2.30, 2.62, 1.71, 1.80, 0.12, "gunmetal", chamfer=0.02)
    # --- Magazine well / battery block (gunmetal) with two marked panels.
    b.block(1.48, 2.52, 0.28, 0.84, 0.25, "gunmetal", chamfer=0.06)
    for side in (-1, 1):
        b.block(1.62, 1.86, 0.40, 0.66, 0.02, "steel", chamfer=0.005, centre_x=0.255 * side)
        b.block(2.14, 2.38, 0.40, 0.66, 0.02, "steel", chamfer=0.005, centre_x=0.255 * side)
    # --- Pistol grip, trigger guard and trigger (gunmetal / black).
    b.slab([(1.08, 0.86), (1.46, 0.86), (1.22, 0.04), (0.90, 0.06)], 0.15, "gunmetal", bevel=0.03)
    b.slab([(1.24, 0.34), (1.52, 0.34), (1.52, 0.42), (1.22, 0.42)], 0.07, "gunmetal", bevel=0.015)
    b.slab([(1.50, 0.80), (1.58, 0.80), (1.58, 0.56), (1.53, 0.52)], 0.035, "black", bevel=0.01)
    # --- Rear tube over the stock (gunmetal), with its end cap.
    b.tube(1.54, 0.08, 1.02, 0.11, "gunmetal")
    b.tube(1.54, 0.03, 0.10, 0.125, "black")
    b.block(0.20, 1.00, 1.36, 1.50, 0.07, "gunmetal", chamfer=0.02)
    # --- Skeleton stock (gunmetal): butt plate, top bar, rear strut and a solid lower web,
    # leaving the open window the concept shows behind the grip.
    b.slab([(0.0, 0.62), (0.16, 0.62), (0.16, 1.42), (0.0, 1.42)], 0.13, "gunmetal", bevel=0.03)
    b.slab([(-0.02, 0.66), (0.03, 0.66), (0.03, 1.38), (-0.02, 1.38)], 0.12, "black", bevel=0.015)
    b.slab([(0.10, 1.22), (1.00, 1.22), (1.00, 1.38), (0.10, 1.38)], 0.11, "gunmetal", bevel=0.025)
    b.slab([(0.10, 0.62), (0.40, 0.62), (1.02, 0.88), (1.02, 1.04), (0.10, 0.84)], 0.11, "gunmetal", bevel=0.025)
    b.slab([(0.56, 0.90), (0.70, 0.95), (0.74, 1.24), (0.58, 1.24)], 0.10, "gunmetal", bevel=0.02)
    return b


def build_glow():
    b = Builder()
    # A lit band across the window's back wall, between the rails, on both faces. The
    # concept's window is mostly dark with the light behind the arc, so the wall shows
    # black above and below it.
    mid = (RAIL_TOP + RAIL_LOW) / 2
    b.block(2.34, 3.58, mid - 0.09, mid + 0.09, 0.105, "glow", chamfer=0.01)
    return b


def to_mesh(builder, name):
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.triangulate(builder.bm, faces=builder.bm.faces[:])
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    return mesh


def write_palette():
    width, height = COLS * SWATCH, ROWS * SWATCH
    pixels = [0.0] * (width * height * 4)
    for i, (_, rgb) in enumerate(PALETTE):
        col, row = i % COLS, ROWS - 1 - i // COLS  # image rows run bottom-up
        for py in range(row * SWATCH, (row + 1) * SWATCH):
            for px in range(col * SWATCH, (col + 1) * SWATCH):
                o = (py * width + px) * 4
                pixels[o : o + 4] = [c / 255 for c in rgb] + [1.0]
    image = bpy.data.images.new("LightningCarbineClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image, name, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def render(name, location, target, lens=50, size=(1000, 600)):
    sc = bpy.context.scene
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_start = 0.01
    sc.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = str(REVIEW / ("clean-" + name + ".png"))
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = write_palette()
    body = bpy.data.objects.new("Body", to_mesh(build_body(), "Body"))
    glow = bpy.data.objects.new("Glow", to_mesh(build_glow(), "Glow"))
    body.data.materials.append(material(palette, "LightningCarbinePalette"))
    glow.data.materials.append(material(palette, "LightningCarbineGlow", emission=1.5))
    parts = [body, glow]
    for ob in parts:
        bpy.context.scene.collection.objects.link(ob)

    # Centre both meshes on the shared bounding box (pivot: center).
    verts = [v.co for ob in parts for v in ob.data.vertices]
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    mid = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
    for ob in parts:
        for v in ob.data.vertices:
            v.co -= mid
        ob.data.update()

    def roblox(u, v):
        """A profile point as a Roblox offset from the pivot (+Y up, -Z forward)."""
        return (0.0, round(v - mid.z, 3), round(-(u + mid.y), 3))

    tris = [len(ob.data.polygons) for ob in parts]
    print(
        "lightning carbine: %s triangles (%d total), %.2f wide x %.2f long x %.2f tall studs"
        % (tris, sum(tris), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    )
    print("mount Grip=%s,%s,%s" % roblox(1.18, 0.46))
    # The muzzle mount sits between the two bores; the arc Beam runs rail to rail.
    print("mount Muzzle=%s,%s,%s" % roblox(MUZZLE_U, (RAIL_TOP - 0.06 + RAIL_LOW - 0.12) / 2))
    assert max(tris) <= 10000, "over Roblox's per-mesh cap"

    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_materials="EXPORT"
    )
    print("wrote %s (%.0f KB)" % (EXPORT, EXPORT.stat().st_size / 1024))

    if "--no-render" in args:
        return
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    world = bpy.data.worlds.new("review")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.43, 0.45, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(-30))
    sun.data.energy = 3.0
    REVIEW.mkdir(parents=True, exist_ok=True)
    # The concept's angle: right side, muzzle to the right, a little from above and in front.
    render("quarter", (-6.4, -2.4, 1.8), (0, 0, 0), lens=50)
    render("side", (-10.0, 0, 0), (0, 0, 0), lens=50)
    render("other-side", (10.0, 0, 0), (0, 0, 0), lens=50)
    render("front", (0.6, -7.0, 0.4), (0, 0, 0), lens=60, size=(700, 600))
    render("top", (0, 0.001, 9.0), (0, 0, 0), lens=50, size=(700, 1000))


main()
