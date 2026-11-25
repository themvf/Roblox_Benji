"""Clean low-poly build of the Quantum Cannon, modelled from the user's concept art. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_quantum_cannon.py
    blender -b -noaudio --python tools/blender/build_quantum_cannon.py -- --no-render

A held gun goes the clean route (asset_rules: held is a close role), so nothing here is
generated: the concept picture in source/user-picture.webp sets the proportions and the
palette. build_prism_blaster.py is the pattern this follows.

Units are studs. Blender Z is up and the muzzle points down -Y, which exports to glTF +Z
and arrives in Roblox facing -Z. Profile tables are (u, v): u runs from the stock butt (0)
to the muzzle face (4.5), v from the bottom of the grip (0) up. The barrel and muzzle are
lathed round the bore axis at v = BORE_V. The finished mesh is centred on its bounding box
(brief pivot: center).

Two meshes are exported: "Body" (palette texture) and "Glow", the ring inside the muzzle,
kept apart so Studio can make it Neon, which a textured MeshPart cannot do.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/quantum-cannon"
EXPORT = PKG / "exports/QuantumCannonClean.glb"
PALETTE_PNG = PKG / "textures/QuantumCannonClean_Palette.png"
REVIEW = PKG / "review"

BORE_V = 0.98  # height of the barrel axis
SIDES = 28  # facets round the barrel

# Flat colours, sRGB 0-255, sampled by eye from the concept. One swatch each in a 4x2 atlas.
PALETTE = [
    ("white", (224, 220, 210)),
    ("white_shade", (196, 191, 180)),
    ("black", (24, 24, 27)),
    ("gunmetal", (52, 54, 59)),
    ("red", (168, 30, 34)),
    ("glow", (236, 244, 255)),
    ("bore", (8, 8, 10)),
    ("steel", (92, 95, 102)),
]
COLS, ROWS, SWATCH = 4, 2, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}


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

    def _finish(self, faces, colour):
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self._paint(faces, colour)
        return faces

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
        return self._finish(faces, colour)

    def lathe(self, profile, colour, closed=False, cz=BORE_V, cx=0.0, sides=SIDES):
        """Revolve a (u, r) profile round a lengthwise axis. A point with r == 0 becomes one
        vertex on the axis, so a profile that starts and ends on the axis is a closed solid;
        closed=True joins the last point back to the first (a ring with a section)."""
        rings = []
        for u, r in profile:
            if r <= 1e-6:
                rings.append(self.bm.verts.new((cx, -u, cz)))
            else:
                rings.append(
                    [self.bm.verts.new((cx + r * math.cos(2 * math.pi * k / sides), -u, cz + r * math.sin(2 * math.pi * k / sides))) for k in range(sides)]
                )
        pairs = list(zip(rings, rings[1:]))
        if closed:
            pairs.append((rings[-1], rings[0]))
        faces = []
        for a, b in pairs:
            for k in range(sides):
                n = (k + 1) % sides
                if isinstance(a, list) and isinstance(b, list):
                    faces.append(self.bm.faces.new((a[k], a[n], b[n], b[k])))
                elif isinstance(a, list):
                    faces.append(self.bm.faces.new((a[k], a[n], b)))
                elif isinstance(b, list):
                    faces.append(self.bm.faces.new((a, b[n], b[k])))
        return self._finish(faces, colour)

    def slab(self, profile, half_width, colour, bevel=0.025, x0=0.0):
        """Extrude a convex side profile (u, v) across the width, with chamfered side edges."""
        cu = sum(p[0] for p in profile) / len(profile)
        cv = sum(p[1] for p in profile) / len(profile)
        extent = min(max(p[0] for p in profile) - min(p[0] for p in profile), max(p[1] for p in profile) - min(p[1] for p in profile))
        k = max(0.0, 1 - 2 * bevel / extent)
        small = [(cu + (u - cu) * k, cv + (v - cv) * k) for u, v in profile]
        stations = [
            (x0 - half_width, small),
            (x0 - half_width + bevel, profile),
            (x0 + half_width - bevel, profile),
            (x0 + half_width, small),
        ]
        return self.loft(stations, colour, axis="x")

    def block(self, u0, u1, z0, z1, half_width, colour, chamfer=0.04, taper_front=0.0, taper_back=0.0, x0=0.0):
        """A lengthwise block with chamfered long edges; tapers shrink an end's section."""

        def section(shrink):
            w = half_width - shrink
            b, t = z0 + shrink, z1 - shrink
            c = min(chamfer, w * 0.5, (t - b) * 0.3)
            return [(x0 + p, q) for p, q in [(-w + c, b), (w - c, b), (w, b + c), (w, t - c), (w - c, t), (-w + c, t), (-w, t - c), (-w, b + c)]]

        return self.loft([(u0, section(taper_back)), (u1, section(taper_front))], colour)

    def tube(self, cz, u0, u1, radius, colour, sides=12, cx=0.0):
        return self.lathe([(u0, 0.0), (u0, radius), (u1, radius), (u1, 0.0)], colour, cz=cz, cx=cx, sides=sides)


def build_body():
    b = Builder()

    # --- Barrel and muzzle shroud: one lathed solid with the bore recessed into its face. ---
    b.lathe(
        [
            (2.30, 0.0),
            (2.30, 0.40),
            (2.42, 0.46),
            (3.46, 0.46),
            (3.56, 0.58),
            (3.92, 0.58),
            (3.94, 0.565),
            (3.98, 0.565),
            (4.00, 0.58),
            (4.46, 0.58),
            (4.50, 0.555),
            (4.50, 0.50),  # outer lip
            (4.45, 0.49),
            (4.45, 0.445),  # first step in
            (4.39, 0.435),  # the glow ring sits on this shelf
            (4.39, 0.355),
            (4.20, 0.31),  # into the bore
            (3.95, 0.0),
        ],
        "black",
    )
    # Dark bore floor so the throat reads deep.
    b.lathe([(4.05, 0.0), (4.05, 0.24), (4.10, 0.24), (4.10, 0.0)], "bore")
    # Steel collar where the barrel meets the shroud.
    b.lathe([(3.40, 0.0), (3.40, 0.50), (3.50, 0.50), (3.50, 0.0)], "gunmetal")

    # --- Receiver (black) with the white collar behind it. ---
    b.block(1.40, 2.55, 0.58, 1.48, 0.36, "black", chamfer=0.08)
    b.block(1.26, 1.46, 0.60, 1.50, 0.39, "white", chamfer=0.07)
    # Gunmetal side plates and black hardware, both sides.
    for side in (-1, 1):
        b.block(1.62, 2.40, 0.92, 1.30, 0.035, "gunmetal", chamfer=0.015, x0=0.37 * side)
        b.block(1.70, 1.92, 0.70, 0.86, 0.03, "black", chamfer=0.01, x0=0.40 * side)
        b.block(2.02, 2.20, 1.36, 1.44, 0.03, "steel", chamfer=0.01, x0=0.38 * side)
        # Side canister with a red band, as on the concept's flank.
        b.tube(0.80, 2.05, 2.95, 0.12, "black", cx=0.42 * side)
        b.tube(0.80, 2.00, 2.07, 0.13, "red", cx=0.42 * side)
        b.tube(0.80, 2.92, 3.02, 0.14, "gunmetal", cx=0.42 * side)

    # --- Top rail over the whole length, with a window strip and the red front sight. ---
    b.block(1.08, 4.18, 1.48, 1.66, 0.29, "black", chamfer=0.04, taper_front=0.02)
    # Spine joining the rail to the barrel, so no light shows between them.
    b.block(2.45, 3.60, 1.30, 1.50, 0.22, "black", chamfer=0.03)
    b.block(2.95, 3.92, 1.63, 1.69, 0.18, "gunmetal", chamfer=0.015)
    b.block(3.05, 3.82, 1.66, 1.70, 0.12, "steel", chamfer=0.01)
    b.slab([(3.98, 1.66), (4.10, 1.66), (4.08, 1.80), (4.02, 1.80)], 0.05, "red", bevel=0.01)
    b.block(1.20, 1.50, 1.62, 1.74, 0.16, "black", chamfer=0.03)

    # --- Stock: black top cap and butt plate, white panels, open thumbhole. ---
    b.block(-0.04, 1.30, 1.38, 1.50, 0.30, "black", chamfer=0.04)
    b.slab([(-0.06, 1.50), (0.06, 1.50), (0.06, 0.42), (-0.06, 0.46)], 0.31, "black", bevel=0.03)
    b.slab([(0.04, 1.40), (1.28, 1.42), (1.28, 1.08), (0.04, 1.08)], 0.27, "white", bevel=0.035)
    b.slab([(0.04, 1.10), (0.40, 1.10), (0.62, 0.62), (0.50, 0.50), (0.04, 0.50)], 0.27, "white", bevel=0.035)
    b.slab([(0.00, 0.52), (0.52, 0.50), (0.56, 0.40), (0.00, 0.40)], 0.25, "black", bevel=0.02)
    # Red stencil marks on the white stock, both sides.
    for side in (-1, 1):
        b.slab([(0.10, 1.26), (0.16, 1.26), (0.13, 1.20)], 0.006, "red", bevel=0.002, x0=0.272 * side)
        b.slab([(0.56, 1.16), (0.60, 1.16), (0.60, 1.12), (0.56, 1.12)], 0.006, "red", bevel=0.002, x0=0.272 * side)

    # --- Grip (black), raked back, joined to the stock below the thumbhole. ---
    b.slab([(0.86, 1.10), (1.20, 1.10), (0.92, 0.04), (0.62, 0.08)], 0.15, "black", bevel=0.04)
    b.slab([(0.50, 0.62), (0.80, 0.62), (0.74, 0.42), (0.50, 0.48)], 0.16, "black", bevel=0.03)
    # White trigger guard block, black trigger.
    b.slab([(1.02, 0.40), (1.58, 0.62), (1.74, 0.62), (1.64, 0.30), (1.10, 0.24)], 0.17, "white", bevel=0.035)
    b.slab([(1.24, 0.62), (1.32, 0.62), (1.34, 0.44), (1.28, 0.42)], 0.04, "gunmetal", bevel=0.01)

    # --- Under the barrel: white handguard, black power pack, front lower housing. ---
    b.block(1.70, 3.70, 0.30, 0.52, 0.30, "white", chamfer=0.05)
    b.block(2.20, 3.40, 0.50, 0.60, 0.24, "black", chamfer=0.02)
    b.slab([(3.56, 0.56), (3.95, 0.56), (4.02, 0.30), (3.62, 0.24)], 0.31, "white", bevel=0.04)
    b.block(2.30, 3.70, 0.10, 0.32, 0.22, "black", chamfer=0.04)
    b.block(3.90, 4.36, 0.04, 0.46, 0.30, "black", chamfer=0.05, taper_front=0.02)
    for side in (-1, 1):
        b.block(4.00, 4.28, 0.14, 0.36, 0.02, "gunmetal", chamfer=0.01, x0=0.30 * side)
    b.block(4.36, 4.39, 0.16, 0.34, 0.14, "gunmetal", chamfer=0.01)
    return b


def build_glow():
    b = Builder()
    # A ring with a flat face looking out of the muzzle, seated on the shelf in the bore.
    b.lathe([(4.385, 0.36), (4.425, 0.36), (4.425, 0.43), (4.385, 0.43)], "glow", closed=True, sides=SIDES)
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
    image = bpy.data.images.new("QuantumCannonClean_Palette", width, height, alpha=False)
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
    bsdf.inputs["Roughness"].default_value = 0.45
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def render(name, location, target, lens=50, size=(1100, 650)):
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
    body.data.materials.append(material(palette, "QuantumCannonPalette"))
    glow.data.materials.append(material(palette, "QuantumCannonGlow", emission=2.0))
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
        "quantum cannon: %s triangles (%d total), %.2f wide x %.2f long x %.2f tall studs"
        % (tris, sum(tris), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    )
    print("mount Grip=%s,%s,%s" % roblox(0.90, 0.55))
    print("mount Muzzle=%s,%s,%s" % roblox(4.50, BORE_V))
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
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.56, 0.58, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(-30))
    sun.data.energy = 3.0
    REVIEW.mkdir(parents=True, exist_ok=True)
    # The concept's angle: right side, muzzle to the right, from in front and a little above.
    render("quarter", (-6.4, -4.2, 1.5), (0, -0.4, 0), lens=50)
    render("side", (-10.0, 0, 0), (0, 0, 0), lens=50)
    render("other-side", (10.0, 0, 0), (0, 0, 0), lens=50)
    render("front", (0.8, -7.0, 0.5), (0, 0, 0), lens=60, size=(700, 600))
    render("top", (0, 0.001, 9.0), (0, 0, 0), lens=50, size=(700, 1100))


main()
