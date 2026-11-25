"""Clean low-poly build of the Plasma Blaster, modelled from the user's concept art. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_plasma_blaster.py
    blender -b -noaudio --python tools/blender/build_plasma_blaster.py -- --no-render

A held gun goes the clean route (asset_rules: held is a close role), so nothing here is
generated: the concept picture in source/user-picture.webp sets the proportions and the
palette, and every piece is a hard-edged slab or loft. Same construction as
build_prism_blaster.py.

Units are studs. Blender Z is up and the muzzle points down -Y, which exports to glTF +Z
and arrives in Roblox facing -Z. Profile tables are (u, v): u runs from the stock butt (0)
to the muzzle (4.0), v from the bottom of the grip (0) up. The picture was measured at
307.5 px per stud: u = (x - 65) / 307.5, v = (770 - y) / 307.5.
The finished mesh is centred on its bounding box (brief pivot: center).

Two meshes are exported: "Body" (palette texture) and "Core" (the molten plasma in the side
window and the vent slot), kept apart so Studio can make the core Neon and let it glow,
which a textured MeshPart cannot do.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/plasma-blaster"
EXPORT = PKG / "exports/PlasmaBlasterClean.glb"
PALETTE_PNG = PKG / "textures/PlasmaBlasterClean_Palette.png"
REVIEW = PKG / "review"

# Flat colours, sRGB 0-255, sampled by eye from the concept. One swatch each in a 4x2 atlas;
# every face's UVs sit at the centre of its swatch so filtering never bleeds a neighbour in.
PALETTE = [
    ("rust", (168, 66, 42)),
    ("rust_dark", (122, 46, 30)),
    ("gunmetal", (70, 74, 84)),
    ("black", (30, 31, 36)),
    ("black_shade", (48, 50, 56)),
    ("plasma", (255, 112, 24)),
    ("plasma_hot", (255, 196, 64)),
]
COLS, ROWS, SWATCH = 4, 2, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}

HALF = 0.32  # half-width of the red main body


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

    def slab(self, profile, half_width, colour, bevel=0.025):
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
            (-half_width, small),
            (-half_width + bevel, profile),
            (half_width - bevel, profile),
            (half_width, small),
        ]
        return self.loft(stations, colour, axis="x")

    def block(self, u0, u1, z0, z1, half_width, colour, chamfer=0.04, taper_front=0.0, taper_back=0.0):
        """A length-wise block with chamfered long edges; tapers shrink an end's section."""

        def section(shrink):
            w = half_width - shrink
            b, t = z0 + shrink, z1 - shrink
            c = min(chamfer, w * 0.5, (t - b) * 0.3)
            return [(-w + c, b), (w - c, b), (w, b + c), (w, t - c), (w - c, t), (-w + c, t), (-w, t - c), (-w, b + c)]

        return self.loft([(u0, section(taper_back)), (u1, section(taper_front))], colour)

    def tube(self, cz, u0, u1, radius, colour, sides=12):
        ring = [(radius * math.cos(2 * math.pi * k / sides), cz + radius * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
        return self.loft([(u0, ring), (u1, ring)], colour)


def build_body():
    b = Builder()
    # Heavy butt stock (black), with a raised side panel each side as in the concept.
    b.block(0.0, 0.66, 0.30, 1.50, 0.36, "black", chamfer=0.12, taper_back=0.04)
    b.block(0.10, 0.56, 0.48, 1.30, 0.375, "black_shade", chamfer=0.06)
    # Red collar between the stock and the receiver.
    b.block(0.60, 0.92, 0.44, 1.46, 0.30, "rust", chamfer=0.05)
    # Gunmetal receiver, a little wider than the body so it stands proud.
    b.block(0.88, 1.62, 0.82, 1.54, 0.34, "gunmetal", chamfer=0.05)
    b.block(1.12, 1.56, 1.54, 1.60, 0.24, "black", chamfer=0.015)
    # Main red body and its tapered front cap.
    b.block(1.55, 3.70, 0.95, 1.60, HALF, "rust", chamfer=0.05)
    b.block(3.68, 3.88, 1.00, 1.58, HALF, "rust", chamfer=0.05, taper_front=0.06)
    # Lower housing under the window (red) with a dark inset panel.
    b.block(1.62, 2.95, 0.62, 0.98, 0.30, "rust", chamfer=0.04)
    b.block(1.82, 2.82, 0.68, 0.82, 0.305, "black", chamfer=0.02)
    # Ribbed black handguard under the front of the body.
    b.block(2.90, 3.84, 0.78, 1.00, 0.27, "black", chamfer=0.04)
    for u in (3.06, 3.26, 3.46, 3.66):
        b.block(u, u + 0.10, 0.80, 0.98, 0.285, "black_shade", chamfer=0.02)
    # Window bezel (gunmetal): four bars standing proud of the red skin, on both sides.
    # Top and bottom bars stop at the side bars, so no two faces share a plane at the corners.
    for u0, u1, v0, v1 in ((2.22, 3.06, 1.43, 1.54), (2.22, 3.06, 0.98, 1.09), (2.07, 2.22, 0.98, 1.54), (3.06, 3.20, 0.98, 1.54)):
        b.block(u0, u1, v0, v1, 0.35, "gunmetal", chamfer=0.02)
    # Dark backing behind the vent slot ahead of the window.
    b.block(3.30, 3.64, 1.27, 1.43, 0.33, "black", chamfer=0.02)
    # Top rail, rear sight and front sight (black).
    b.block(1.70, 3.70, 1.58, 1.65, 0.10, "black", chamfer=0.015)
    b.block(2.00, 2.60, 1.58, 1.70, 0.15, "black", chamfer=0.03)
    b.block(3.58, 3.70, 1.58, 1.74, 0.08, "black", chamfer=0.02)
    # Muzzle: collar and barrel (black), bore (gunmetal so it reads as an opening).
    b.tube(1.36, 3.84, 3.92, 0.17, "black")
    b.tube(1.36, 3.90, 4.00, 0.14, "black")
    b.tube(1.36, 3.92, 4.005, 0.08, "rust_dark")
    # Pistol grip (black) with a red toe, and the thumbhole strut behind it.
    b.slab([(1.00, 0.84), (1.42, 0.84), (1.32, 0.26), (1.04, 0.20), (0.94, 0.42)], 0.17, "black")
    b.slab([(1.04, 0.22), (1.32, 0.28), (1.28, 0.10), (1.15, 0.0), (1.05, 0.06)], 0.15, "rust")
    b.slab([(0.62, 0.84), (0.80, 0.84), (1.04, 0.32), (0.96, 0.24)], 0.13, "black", bevel=0.02)
    # Trigger guard (black) and trigger (gunmetal).
    b.slab([(1.38, 0.60), (1.74, 0.60), (1.74, 0.53), (1.42, 0.53)], 0.10, "black", bevel=0.015)
    b.slab([(1.66, 0.96), (1.74, 0.96), (1.74, 0.56), (1.66, 0.56)], 0.10, "black", bevel=0.015)
    b.slab([(1.50, 0.84), (1.56, 0.84), (1.56, 0.66), (1.52, 0.64)], 0.04, "gunmetal", bevel=0.01)
    # Small details from the concept: a gunmetal latch on the receiver and an orange button on the stock.
    for side in (-1, 1):
        lo, hi = sorted((0.34 * side, 0.365 * side))
        b.loft([(1.20, [(lo, 1.20), (hi, 1.20), (hi, 1.34), (lo, 1.34)]), (1.42, [(lo, 1.20), (hi, 1.20), (hi, 1.34), (lo, 1.34)])], "black_shade")
        lo, hi = sorted((0.36 * side, 0.39 * side))
        b.loft([(0.70, [(lo, 0.86), (hi, 0.86), (hi, 0.94), (lo, 0.94)]), (0.78, [(lo, 0.86), (hi, 0.86), (hi, 0.94), (lo, 0.94)])], "plasma")
    return b


def build_core():
    b = Builder()
    # Molten plasma in the window: a loft that swells toward the front, recessed behind the
    # bezel (0.35) but in front of the red skin (0.32), so it reads as glass in a frame.
    w = 0.335
    b.loft(
        [
            (2.20, [(-w, 1.16), (w, 1.16), (w, 1.36), (-w, 1.36)]),
            (2.60, [(-w, 1.10), (w, 1.10), (w, 1.42), (-w, 1.42)]),
            (3.08, [(-w, 1.08), (w, 1.08), (w, 1.45), (-w, 1.45)]),
        ],
        "plasma",
    )
    # Hot streak through the middle of the window and the glowing vent slot ahead of it.
    b.block(2.40, 3.02, 1.22, 1.32, 0.338, "plasma_hot", chamfer=0.02)
    b.block(3.34, 3.60, 1.31, 1.39, 0.335, "plasma", chamfer=0.01)
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
    image = bpy.data.images.new("PlasmaBlasterClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image, name, emission=0.0, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Metallic"].default_value = metallic
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
    core = bpy.data.objects.new("Core", to_mesh(build_core(), "Core"))
    body.data.materials.append(material(palette, "PlasmaBlasterPalette"))
    core.data.materials.append(material(palette, "PlasmaBlasterCore", emission=0.6))
    parts = [body, core]
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
        "plasma blaster: %s triangles (%d total), %.2f wide x %.2f long x %.2f tall studs"
        % (tris, sum(tris), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    )
    print("mount Grip=%s,%s,%s" % roblox(1.18, 0.50))
    print("mount Muzzle=%s,%s,%s" % roblox(4.005, 1.36))
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
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.66, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(-30))
    sun.data.energy = 3.0
    REVIEW.mkdir(parents=True, exist_ok=True)
    # The concept's angle: right side, muzzle to the right, a little from above and in front.
    render("quarter", (-5.6, -1.8, 1.6), (0, 0, 0), lens=50)
    render("side", (-8.5, 0, 0), (0, 0, 0), lens=50)
    render("other-side", (8.5, 0, 0), (0, 0, 0), lens=50)
    render("front", (0.6, -6.0, 0.4), (0, 0, 0), lens=60, size=(700, 600))
    render("top", (0, 0.001, 7.5), (0, 0, 0), lens=50, size=(700, 1000))


main()
