"""Clean low-poly rebuild of the military wave runner. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_military_wave_runner.py
    blender -b -noaudio --python tools/blender/build_military_wave_runner.py -- --no-render

Why this exists: the TRELLIS mesh (289,000 triangles of thin open shells) only fits
Roblox after a cut that leaves it lumpy, and it needed 12 mesh parts and 70,000
triangles to look even that good. This models the same craft from hard-edged lofted
shapes instead, in the game's blocky style: one mesh, a few thousand triangles, one
tiny palette texture. The generated mesh and the Midjourney image are the reference
for proportions only; no geometry is taken from them.

Units are studs. Blender Z is up and the bow points down -Y, which exports to glTF +Z
and arrives in Roblox facing -Z, the way VehicleSeat and the drive code face. The
origin is at the keel line under the middle of the craft.

Everything is tables of stations: a station is a cross-section at one point along the
length. Change a number, rebuild, look at review/clean-*.png.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/military-wave-runner"
EXPORT = PKG / "exports/MilitaryWaveRunnerClean.glb"
PALETTE_PNG = PKG / "textures/MilitaryWaveRunnerClean_Palette.png"
REVIEW = PKG / "review"

# Flat colours, sRGB 0-255. One 16-pixel swatch each in a 4x2 atlas; every face's UVs
# sit at the centre of its swatch, so texture filtering can never bleed a neighbour in.
PALETTE = [
    ("olive_dark", (54, 66, 46)),
    ("olive", (76, 90, 60)),
    ("olive_light", (100, 114, 80)),
    ("grey_dark", (58, 62, 66)),
    ("grey_mid", (84, 90, 94)),
    ("black", (24, 26, 28)),
    ("metal", (128, 134, 138)),
    ("light", (226, 232, 210)),
    ("red", (158, 42, 36)),
    ("shadow", (36, 44, 32)),
]
COLS, ROWS, SWATCH = 4, 3, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}


def interp(table_y, table_v, y):
    """Piecewise-linear lookup, clamped at the ends."""
    if y <= table_y[0]:
        return table_v[0]
    for (y0, v0), (y1, v1) in zip(zip(table_y, table_v), zip(table_y[1:], table_v[1:])):
        if y <= y1:
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
    return table_v[-1]


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
        """Skin a closed shape through cross-sections.

        `stations` is [(position, ring)], ring a closed list of 2D points, the same
        count at every station. With axis "y" the ring is (x, z) and the position is
        y; with axis "x" the ring is (y, z) and the position is x. Ends are capped.
        """
        rings = []
        for pos, ring in stations:
            if axis == "y":
                rings.append([self.bm.verts.new((a, pos, b)) for a, b in ring])
            else:
                rings.append([self.bm.verts.new((pos, a, b)) for a, b in ring])
        faces = []
        count = len(rings[0])
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(count):
                j = (i + 1) % count
                faces.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        faces.append(self.bm.faces.new(rings[0]))
        faces.append(self.bm.faces.new(list(reversed(rings[-1]))))
        # Each loft is a closed shell, so outward normals are well defined.
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self._paint(faces, colour)
        return faces

    def box(self, x0, x1, y0, y1, z0, z1, colour):
        ring = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        return self.loft([(y0, ring), (y1, ring)], colour)

    def tube(self, cx, cz, y0, y1, radius, colour, sides=8, axis="y"):
        ring = [
            (cx + radius * math.cos(2 * math.pi * k / sides), cz + radius * math.sin(2 * math.pi * k / sides))
            for k in range(sides)
        ]
        return self.loft([(y0, ring), (y1, ring)], colour, axis=axis)


def mirrored(half):
    """Half profile, bottom centre round to top centre with x >= 0, to a full ring."""
    return half + [(-x, z) for x, z in reversed(half) if x > 1e-6]


# --- hull tables: bow at y = -4.5, stern at y = +4.5 ------------------------------

HULL_Y = [-4.5, -4.2, -3.6, -2.6, -1.2, 0.5, 2.5, 4.0, 4.5]
HULL_W = [0.6, 1.15, 1.65, 2.0, 2.2, 2.28, 2.28, 2.15, 2.0]  # half width at the gunwale
HULL_KEEL = [0.95, 0.45, 0.05, -0.25, -0.45, -0.45, -0.45, -0.32, -0.12]
HULL_CHINE = [0.2, 0.42, 0.66, 0.82, 0.92, 0.92, 0.92, 0.82, 0.66]  # chine height above the keel
HULL_SIDE = [1.66, 1.56, 1.42, 1.27, 1.15, 1.15, 1.15, 1.15, 1.15]  # where hull side meets the deck slab
HULL_DECK = [1.8, 1.7, 1.56, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]  # deck height; it sweeps up at the bow
DECK = 1.5
SCALE = 0.92  # modelled a little large; this lands it near 9 studs long

HOOD_Y = [-4.1, -3.4, -2.4, -1.4, -0.7]
HOOD_W = [0.6, 1.0, 1.3, 1.35, 1.2]
HOOD_TOP = [1.9, 2.08, 2.28, 2.46, 2.54]


def half_width(y):
    return interp(HULL_Y, HULL_W, y)


def hood_top(y):
    return interp(HOOD_Y, HOOD_TOP, y)


def build():
    b = Builder()

    # Lower hull: a deep V with a hard chine, dark so the waterline reads.
    b.loft(
        [
            (y, mirrored([(0, k), (0.72 * w, k + c), (w, s), (0, s)]))
            for y, w, k, c, s in zip(HULL_Y, HULL_W, HULL_KEEL, HULL_CHINE, HULL_SIDE)
        ],
        "olive_dark",
    )
    # Deck slab on top of it.
    b.loft(
        [(y, mirrored([(0, s), (w, s), (w, d - 0.1), (w - 0.15, d), (0, d)])) for y, w, s, d in zip(HULL_Y, HULL_W, HULL_SIDE, HULL_DECK)],
        "olive",
    )
    # Rub rail: the dark band that runs the length of the craft in the reference.
    for sign in (1, -1):
        b.loft(
            [
                (y, [(sign * (w - 0.03), s - 0.03), (sign * (w + 0.13), s + 0.02), (sign * (w + 0.13), s + 0.2), (sign * (w - 0.03), s + 0.22)])
                for y, w, s in zip(HULL_Y, HULL_W, HULL_SIDE)
            ],
            "grey_dark",
        )

    # Bow bumper block with two lamps.
    b.loft(
        [
            (-4.8, [(-0.5, 1.2), (0.5, 1.2), (0.5, 1.72), (-0.5, 1.72)]),
            (-4.52, [(-0.95, 1.08), (0.95, 1.08), (0.95, 1.82), (-0.95, 1.82)]),
            (-4.15, [(-1.2, 1.1), (1.2, 1.1), (1.2, 1.78), (-1.2, 1.78)]),
        ],
        "grey_dark",
    )
    for sign in (1, -1):
        x0, x1 = sorted((sign * 0.18, sign * 0.42))
        b.box(x0, x1, -4.83, -4.78, 1.38, 1.54, "light")
        cx0, cx1 = sorted((sign * 0.7, sign * 1.1))
        b.box(cx0, cx1, -4.5, -4.05, 1.2, 1.86, "grey_mid")  # corner blocks, inside the hull line

    # Strake: a raised lighter band along each hull side, between the chine and the rail.
    for sign in (1, -1):
        stations = []
        for y, w, k, c, sd in zip(HULL_Y, HULL_W, HULL_KEEL, HULL_CHINE, HULL_SIDE):
            cx, cz, gx, gz = 0.72 * w, k + c, w, sd
            length = math.hypot(gx - cx, gz - cz)
            nx, nz = (gz - cz) / length, -(gx - cx) / length
            lo_x, lo_z = cx + (gx - cx) * 0.28, cz + (gz - cz) * 0.28
            hi_x, hi_z = cx + (gx - cx) * 0.66, cz + (gz - cz) * 0.66
            stations.append((y, [(sign * lo_x, lo_z), (sign * (lo_x + 0.07 * nx), lo_z + 0.07 * nz),
                                 (sign * (hi_x + 0.07 * nx), hi_z + 0.07 * nz), (sign * hi_x, hi_z)]))
        b.loft(stations[1:], "olive")

    # Hood: faceted, rising from the bow to the dash.
    b.loft(
        [
            (y, mirrored([(0, DECK - 0.05), (w, DECK - 0.05), (w, DECK + 0.12), (0.8 * w, t - 0.18), (0.35 * w, t), (0, t + 0.04)]))
            for y, w, t in zip(HOOD_Y, HOOD_W, HOOD_TOP)
        ],
        "olive",
    )
    # Raised centre plate, the layered armour look.
    plate_y = [-3.7, -3.0, -2.0, -1.3]
    plate_w = [0.3, 0.52, 0.66, 0.58]
    b.loft(
        [
            (y, mirrored([(0, hood_top(y) - 0.06), (w, hood_top(y) - 0.06), (0.85 * w, hood_top(y) + 0.15), (0, hood_top(y) + 0.18)]))
            for y, w in zip(plate_y, plate_w)
        ],
        "olive_light",
    )
    # Dark shoulder strips either side of the plate.
    for sign in (1, -1):
        b.loft(
            [
                (y, [(sign * (0.62 * interp(HOOD_Y, HOOD_W, y)), hood_top(y) - 0.2), (sign * (0.8 * interp(HOOD_Y, HOOD_W, y)), hood_top(y) - 0.3),
                     (sign * (0.8 * interp(HOOD_Y, HOOD_W, y)), hood_top(y) - 0.14), (sign * (0.62 * interp(HOOD_Y, HOOD_W, y)), hood_top(y) - 0.04)])
                for y in (-3.3, -2.4, -1.5)
            ],
            "olive_dark",
        )

    # Dash tower, handlebar and grips.
    b.loft(
        [
            (-1.0, [(-0.45, 2.3), (0.45, 2.3), (0.45, 2.55), (-0.45, 2.55)]),
            (-0.45, [(-0.38, 2.4), (0.38, 2.4), (0.38, 3.15), (-0.38, 3.15)]),
            (-0.25, [(-0.3, 2.4), (0.3, 2.4), (0.3, 3.0), (-0.3, 3.0)]),
        ],
        "olive_dark",
    )
    b.box(-0.22, 0.22, -0.26, -0.21, 2.66, 2.92, "black")  # instrument screen
    bar = [(-0.5, 3.12), (-0.36, 3.12), (-0.36, 3.26), (-0.5, 3.26)]
    b.loft([(-0.95, bar), (0.95, bar)], "grey_dark", axis="x")
    b.box(-0.26, 0.26, -0.58, -0.3, 3.06, 3.34, "grey_mid")
    for sign in (1, -1):
        x0, x1 = sorted((sign * 0.8, sign * 1.14))
        b.tube(-0.43, 3.19, x0, x1, 0.11, "black", axis="x")

    # Seat pedestal and seat with a raised backrest.
    b.loft(
        [(y, mirrored([(0, DECK - 0.05), (w, DECK - 0.05), (w, 1.85), (0, 1.85)])) for y, w in zip([-0.35, 0.2, 3.2, 3.7], [0.7, 0.9, 0.9, 0.6])],
        "olive",
    )
    seat_y = [-0.2, 0.3, 1.0, 1.7, 2.3, 2.8, 3.3, 3.55]
    seat_top = [2.2, 2.05, 2.0, 2.1, 2.55, 2.7, 2.45, 2.1]
    seat_w = [0.5, 0.62, 0.66, 0.66, 0.62, 0.56, 0.5, 0.4]
    b.loft(
        [(y, mirrored([(0, 1.8), (w, 1.8), (w, t - 0.15), (0.7 * w, t), (0, t)])) for y, w, t in zip(seat_y, seat_w, seat_top)],
        "grey_dark",
    )

    # Side sponsons that wall in the footwells, each with a grey top rail and a tail fin.
    spon_y = [-0.6, 0.2, 3.6, 4.35]
    spon_in = [1.75, 1.5, 1.5, 1.6]
    spon_top = [1.52, 1.95, 1.95, 1.6]
    for sign in (1, -1):
        b.loft(
            [
                (y, [(sign * i, DECK - 0.05), (sign * half_width(y), DECK - 0.05), (sign * half_width(y), t - 0.1),
                     (sign * (half_width(y) - 0.15), t), (sign * (i + 0.1), t)])
                for y, i, t in zip(spon_y, spon_in, spon_top)
            ],
            "olive",
        )
        x0, x1 = sorted((sign * 1.62, sign * 1.93))
        b.box(x0, x1, 0.4, 3.4, 1.95, 2.03, "grey_dark")
        fx0, fx1 = sorted((sign * 1.62, sign * 1.8))
        b.loft(
            [
                (3.2, [(fx0, 1.95), (fx1, 1.95), (fx1, 2.0), (fx0, 2.0)]),
                (4.25, [(fx0, 1.95), (fx1, 1.95), (fx1, 2.3), (fx0, 2.3)]),
                (4.42, [(fx0, 1.8), (fx1, 1.8), (fx1, 2.15), (fx0, 2.15)]),
            ],
            "olive_dark",
        )

    # Stern: deck plate, pump housing and jet nozzle.
    b.box(-1.4, 1.4, 3.7, 4.47, DECK - 0.05, 1.62, "olive_dark")
    b.box(-0.55, 0.55, 4.3, 4.62, 0.4, 1.1, "grey_dark")
    b.tube(0, 0.75, 4.55, 4.9, 0.3, "metal", sides=10)

    # Weapons on the foredeck, different each side as in the reference: three stacked
    # tubes to starboard, one heavy gun to port. Each has a mount and an ammunition box.
    for sign in (1, -1):
        x0, x1 = sorted((sign * 1.5, sign * 1.92))
        b.box(x0, x1, -2.5, -1.15, DECK - 0.05, 1.86, "grey_dark")
        b.box(x0, x1, -1.15, -0.7, DECK - 0.05, 2.1, "olive_dark")
    for cx, cz in ((1.6, 1.95), (1.82, 1.95), (1.71, 2.13)):
        b.tube(cx, cz, -3.0, -1.3, 0.075, "black")
        b.tube(cx, cz, -3.05, -2.96, 0.1, "grey_mid")  # muzzle collar
    b.box(-1.88, -1.54, -2.35, -1.3, 1.86, 2.2, "black")  # receiver
    b.tube(-1.71, 2.04, -3.5, -2.35, 0.085, "black")
    b.box(-1.82, -1.6, -3.66, -3.46, 1.94, 2.14, "grey_mid")  # muzzle brake
    b.box(-1.5, -1.38, -2.1, -1.5, 1.9, 2.3, "olive_dark")  # ammunition drum

    # Ribs across the hood plate, vents and tail lights, seat stripe, antenna.
    for y in (-3.05, -2.2):
        w = interp([-3.7, -3.0, -2.0, -1.3], [0.3, 0.52, 0.66, 0.58], y) * 0.9
        b.box(-w, w, y, y + 0.07, hood_top(y) + 0.1, hood_top(y) + 0.21, "shadow")
    for sign in (1, -1):
        for y0 in (1.1, 1.75, 2.4):
            x0, x1 = sorted((sign * (half_width(y0) - 0.02), sign * (half_width(y0) + 0.03)))
            b.box(x0, x1, y0, y0 + 0.45, 1.58, 1.78, "black")
        x0, x1 = sorted((sign * 1.05, sign * 1.6))
        b.box(x0, x1, 4.47, 4.54, 1.18, 1.34, "red")
    b.box(-0.67, 0.67, 0.9, 1.0, 1.86, 2.02, "grey_mid")
    b.box(-1.76, -1.7, 3.9, 3.96, 1.9, 3.25, "black")

    # Fairing ahead of the handlebar, a grab rail behind the seat, and footwell mats.
    b.loft(
        [
            (-1.2, [(-0.5, 2.46), (0.5, 2.46), (0.5, 2.6), (-0.5, 2.6)]),
            (-0.72, [(-0.4, 2.86), (0.4, 2.86), (0.4, 3.02), (-0.4, 3.02)]),
        ],
        "black",
    )
    b.box(-0.5, 0.5, 3.56, 3.66, 1.85, 2.3, "grey_mid")
    for sign in (1, -1):
        x0, x1 = sorted((sign * 0.95, sign * 1.45))
        b.box(x0, x1, 0.2, 3.1, DECK - 0.02, DECK + 0.03, "grey_dark")

    # Sit the keel on z = 0 and bring the craft to its in-game size.
    low = min(v.co.z for v in b.bm.verts)
    for v in b.bm.verts:
        v.co.z -= low
        v.co *= SCALE

    mesh = bpy.data.meshes.new("MilitaryWaveRunner")
    bmesh.ops.triangulate(b.bm, faces=b.bm.faces[:])
    b.bm.to_mesh(mesh)
    b.bm.free()
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
                # A byte image holds sRGB values as they are; converting here darkens twice.
                pixels[o:o + 4] = [c / 255 for c in rgb] + [1.0]
    image = bpy.data.images.new("MilitaryWaveRunnerClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image):
    mat = bpy.data.materials.new("WaveRunnerPalette")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.65
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def render(name, location, target, lens=50, size=(900, 700)):
    sc = bpy.context.scene
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    sc.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = str(REVIEW / ("clean-" + name + ".png"))
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = build()
    mesh.materials.append(material(write_palette()))
    ob = bpy.data.objects.new("MilitaryWaveRunner", mesh)
    bpy.context.scene.collection.objects.link(ob)

    tris = len(mesh.polygons)
    lo = [min(v.co[i] for v in mesh.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in mesh.vertices) for i in range(3)]
    print("clean wave runner: %d triangles, %.2f wide x %.2f long x %.2f tall studs, base z=%.2f"
          % (tris, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], lo[2]))
    assert tris <= 10000, "over Roblox's per-mesh cap"

    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_materials="EXPORT")
    print("wrote %s (%.0f KB)" % (EXPORT, EXPORT.stat().st_size / 1024))

    if "--no-render" in args:
        return
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    world = bpy.data.worlds.new("review")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.86, 0.88, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    sun.data.energy = 3.0
    REVIEW.mkdir(parents=True, exist_ok=True)
    render("quarter", (-8.5, -10.5, 6.0), (0, -0.2, 1.4))  # the reference image's angle
    render("side", (-24, 0, 2.2), (0, 0, 1.6), lens=70, size=(900, 450))
    render("rear", (6.5, 10.5, 5.0), (0, 0.5, 1.5))
    render("top", (0, 0.01, 18), (0, 0, 0), lens=60, size=(600, 900))


main()
