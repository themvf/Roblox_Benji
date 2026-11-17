"""Clean, chunky build of the patrol RHIB (rigid inflatable boat). Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_patrol_rhib.py
    blender -b -noaudio --python tools/blender/build_patrol_rhib.py -- --no-render

Normally run through `python tools/asset_generate.py build patrol-rhib`.

Why this is built from shapes: the boat has a tubular radar arch, an engine guard rail and
a windscreen frame. Thin bars are what a generated mesh loses first when it is reduced (the
radio tower), and the boat is driven, so players stand on it. Every bar here is a closed
six-sided prism, thick enough to read at game distance.

The reference picture (source/reference.png, manufacturer logo painted out) is the guide
for layout and proportions only. No geometry is taken from it or from a generated mesh.

Units are studs. Blender Z is up and the bow points down -Y, which arrives in Roblox
facing -Z, the way VehicleSeat and the drive code face. The origin is on the keel line
under the middle of the boat: 30 long, 10 wide, 8 tall.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/patrol-rhib"
EXPORT = PKG / "exports/PatrolRhibClean.glb"
PALETTE_PNG = PKG / "textures/PatrolRhibClean_Palette.png"
REVIEW = PKG / "review"

# Flat colours, sRGB 0-255. One swatch each; every face's UVs sit at the centre of its
# swatch, so texture filtering can never bleed a neighbour in.
PALETTE = [
    ("tube", (26, 28, 31)),
    ("tube_band", (48, 52, 57)),
    ("hull", (36, 39, 43)),
    ("deck", (104, 112, 118)),
    ("deck_dark", (72, 78, 84)),
    ("console", (118, 126, 132)),
    ("seat", (30, 32, 35)),
    ("frame", (20, 21, 23)),
    ("engine", (40, 43, 47)),
    ("metal", (134, 140, 144)),
    ("glass", (44, 58, 68)),
    ("screen", (38, 132, 150)),
    ("beacon", (40, 96, 226)),
    ("light", (228, 232, 212)),
    ("red", (166, 44, 38)),
    ("green", (46, 150, 72)),
]
COLS, ROWS, SWATCH = 4, 4, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}

BAR = 0.17  # radius of rails and arch tubes; thinner than this shimmers at game distance
TUBE = 1.1  # radius of the inflatable collar


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _finish(self, faces, colour):
        # Every shape here is a closed shell, so outward normals are well defined.
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        # recalc only makes a shell consistent; it turned the whole lower hull inside out,
        # which the audit caught as 53% see-through. A closed shell with outward normals
        # has positive volume, so measure it and flip the shell if it is negative.
        for face in faces:
            face.normal_update()
        if sum(face.calc_center_median().dot(face.normal) * face.calc_area() for face in faces) < 0:
            bmesh.ops.reverse_faces(self.bm, faces=faces)
        i = INDEX[colour]
        u = (i % COLS + 0.5) / COLS
        v = 1 - (i // COLS + 0.5) / ROWS
        for face in faces:
            for loop in face.loops:
                loop[self.uv].uv = (u, v)
        return faces

    def _skin(self, rings, colour):
        faces = []
        count = len(rings[0])
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(count):
                j = (i + 1) % count
                faces.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        faces.append(self.bm.faces.new(rings[0]))
        faces.append(self.bm.faces.new(list(reversed(rings[-1]))))
        return self._finish(faces, colour)

    def loft(self, stations, colour):
        """Skin a closed shape through cross-sections: [(y, [(x, z), ...])], same count each."""
        return self._skin([[self.bm.verts.new((x, y, z)) for x, z in ring] for y, ring in stations], colour)

    def box(self, x0, x1, y0, y1, z0, z1, colour):
        x0, x1 = sorted((x0, x1))
        ring = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        return self.loft([(y0, ring), (y1, ring)], colour)

    def sweep(self, path, radius, colour, sides=6):
        """A tube along 3D points. `radius` is one number or one per point. Ends are capped.

        The ring is carried from point to point without twisting (each ring's first spoke is
        the previous one flattened onto the new cross-section), so bends stay clean."""
        points = [Vector(p) for p in path]
        radii = radius if isinstance(radius, (list, tuple)) else [radius] * len(points)
        rings, spoke = [], None
        for i, point in enumerate(points):
            before = points[max(i - 1, 0)]
            after = points[min(i + 1, len(points) - 1)]
            tangent = (after - before).normalized()
            if spoke is None:
                helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
                spoke = tangent.cross(helper).normalized()
            else:
                spoke = (spoke - tangent * spoke.dot(tangent)).normalized()
            other = tangent.cross(spoke)
            rings.append(
                [
                    self.bm.verts.new(point + (spoke * math.cos(2 * math.pi * k / sides) + other * math.sin(2 * math.pi * k / sides)) * radii[i])
                    for k in range(sides)
                ]
            )
        return self._skin(rings, colour)

    def bar(self, a, b, colour="frame", radius=BAR):
        return self.sweep([a, b], radius, colour)


def mirrored(half):
    """Half profile, bottom centre round to top centre with x >= 0, to a full ring."""
    return half + [(-x, z) for x, z in reversed(half) if x > 1e-6]


# --- hull tables: bow toward y = -15, transom at y = +12 --------------------------------

HULL_Y = [-13.4, -12.0, -9.0, -5.0, 0.0, 6.0, 12.0]
HULL_W = [0.5, 1.8, 2.9, 3.4, 3.5, 3.5, 3.4]  # half width, tucked under the collar
HULL_KEEL = [2.1, 1.05, 0.4, 0.08, 0.0, 0.0, 0.12]
DECK_Z = 1.75

# The collar: one side's centre line, stern to bow. The two sides meet at the last point.
COLLAR = [
    (3.9, 13.5, 2.1),
    (3.9, 12.3, 2.1),
    (3.9, 6.0, 2.1),
    (3.9, 0.0, 2.1),
    (3.9, -5.0, 2.1),
    (3.6, -8.5, 2.2),
    (2.9, -11.3, 2.33),
    (1.6, -13.2, 2.45),
    (0.0, -13.9, 2.5),
]
COLLAR_R = [0.4, TUBE, TUBE, TUBE, TUBE, TUBE, TUBE, TUBE, TUBE]


def seat(b, cx, cy):
    """A jockey seat: pedestal, cushion and a backrest toward the stern."""
    b.box(cx - 0.42, cx + 0.42, cy - 0.55, cy + 0.5, DECK_Z - 0.05, 2.6, "deck_dark")
    b.box(cx - 0.5, cx + 0.5, cy - 0.65, cy + 0.55, 2.6, 2.92, "seat")
    b.loft(
        [
            (cy + 0.4, [(cx - 0.48, 2.9), (cx + 0.48, 2.9), (cx + 0.44, 4.35), (cx - 0.44, 4.35)]),
            (cy + 0.72, [(cx - 0.48, 2.9), (cx + 0.48, 2.9), (cx + 0.4, 4.2), (cx - 0.4, 4.2)]),
        ],
        "seat",
    )


def engine(b, cx):
    """An outboard: cowling, leg, gearcase and its bracket on the transom."""
    b.loft(
        [
            (12.15, [(cx - 0.55, 2.7), (cx + 0.55, 2.7), (cx + 0.5, 4.3), (cx - 0.5, 4.3)]),
            (12.6, [(cx - 0.72, 2.55), (cx + 0.72, 2.55), (cx + 0.68, 4.75), (cx - 0.68, 4.75)]),
            (13.7, [(cx - 0.72, 2.55), (cx + 0.72, 2.55), (cx + 0.64, 4.65), (cx - 0.64, 4.65)]),
            (14.25, [(cx - 0.5, 2.75), (cx + 0.5, 2.75), (cx + 0.42, 4.2), (cx - 0.42, 4.2)]),
        ],
        "engine",
    )
    b.box(cx - 0.76, cx + 0.76, 12.62, 13.68, 3.95, 4.12, "tube_band")  # cowling stripe, just proud of the sides
    b.box(cx - 0.26, cx + 0.26, 12.75, 13.55, 0.75, 2.6, "engine")  # leg
    b.box(cx - 0.5, cx + 0.5, 12.6, 13.9, 1.15, 1.3, "engine")  # anti-ventilation plate
    b.sweep([(cx, 12.5, 0.72), (cx, 13.2, 0.72), (cx, 14.1, 0.72), (cx, 14.35, 0.72)], [0.2, 0.33, 0.3, 0.1], "engine", sides=8)
    b.box(cx - 0.07, cx + 0.07, 13.0, 13.7, 0.2, 0.5, "engine")  # skeg
    b.box(cx - 0.4, cx + 0.4, 11.95, 12.3, 2.2, 3.3, "metal")  # transom bracket


def build():
    b = Builder()

    # Lower hull: a deep V with a hard chine.
    b.loft(
        [(y, mirrored([(0, k), (0.72 * w, k + 0.62), (w, DECK_Z - 0.1), (0, DECK_Z - 0.1)])) for y, w, k in zip(HULL_Y, HULL_W, HULL_KEEL)],
        "hull",
    )
    # Deck: a grey floor between the collars, from the foredeck step to the transom.
    b.loft(
        [(y, mirrored([(0, DECK_Z - 0.25), (w, DECK_Z - 0.25), (w, DECK_Z), (0, DECK_Z)])) for y, w in zip([-11.0, -9.0, -5.0, 12.0], [2.3, 2.9, 3.4, 3.4])],
        "deck",
    )
    # Raised foredeck locker with a hatch.
    b.loft(
        [
            (-12.6, mirrored([(0, DECK_Z - 0.1), (1.2, DECK_Z - 0.1), (1.2, 2.5), (0, 2.5)])),
            (-11.0, mirrored([(0, DECK_Z - 0.1), (2.3, DECK_Z - 0.1), (2.3, 2.45), (0, 2.45)])),
            (-8.6, mirrored([(0, DECK_Z - 0.1), (3.0, DECK_Z - 0.1), (3.0, 2.35), (0, 2.35)])),
        ],
        "console",
    )
    b.box(-1.0, 1.0, -11.2, -9.4, 2.4, 2.52, "deck_dark")  # hatch lid
    # Transom and the engine well floor behind it.
    b.box(-3.4, 3.4, 11.7, 12.15, 0.3, 3.0, "hull")
    b.box(-2.8, 2.8, 10.2, 11.7, DECK_Z - 0.05, 2.25, "deck_dark")  # stern locker step

    # Inflatable collar, each side stern to bow; the two meet in a rounded point.
    # One tube, starboard stern round the bow to port stern. Built as two halves that met
    # at the bow, the end rings were angled and left a notch in the nose.
    around = COLLAR + [(-x, y, z) for x, y, z in reversed(COLLAR[:-1])]
    b.sweep(around, COLLAR_R + list(reversed(COLLAR_R[:-1])), "tube", sides=10)
    for sign in (1, -1):
        for y in (9.0, 3.0, -3.0):  # reinforcement bands
            b.sweep([(sign * 3.9, y - 0.35, 2.1), (sign * 3.9, y + 0.35, 2.1)], TUBE + 0.05, "tube_band", sides=10)
        # Rub strake: a raised strip along the outside of the collar.
        b.sweep([(sign * (3.9 + TUBE), 11.5, 1.95), (sign * (3.9 + TUBE), -5.0, 1.95)], 0.11, "tube_band", sides=4)

    # Centre console: pedestal, dash, screens, wheel, windscreen in a frame.
    b.loft(
        [
            (-5.4, [(-1.15, DECK_Z - 0.05), (1.15, DECK_Z - 0.05), (1.05, 4.9), (-1.05, 4.9)]),
            (-3.9, [(-1.2, DECK_Z - 0.05), (1.2, DECK_Z - 0.05), (1.15, 4.75), (-1.15, 4.75)]),
            (-2.9, [(-1.2, DECK_Z - 0.05), (1.2, DECK_Z - 0.05), (1.15, 3.75), (-1.15, 3.75)]),
        ],
        "console",
    )
    b.loft(  # screen panel on the sloping dash, facing the helm
        [
            (-3.82, [(-0.9, 4.42), (0.9, 4.42), (0.9, 4.72), (-0.9, 4.72)]),
            (-3.02, [(-0.9, 3.62), (0.9, 3.62), (0.9, 3.92), (-0.9, 3.92)]),
        ],
        "frame",
    )
    for x0, x1, colour in ((-0.8, -0.1, "screen"), (0.1, 0.8, "screen")):
        b.loft(
            [
                (-3.72, [(x0, 4.5), (x1, 4.5), (x1, 4.66), (x0, 4.66)]),
                (-3.12, [(x0, 3.9), (x1, 3.9), (x1, 4.06), (x0, 4.06)]),
            ],
            colour,
        )
    b.sweep([(0, -2.95, 3.35), (0, -2.55, 3.2)], 0.1, "frame")  # steering column
    b.sweep([(0, -2.56, 3.2), (0, -2.42, 3.15)], 0.5, "frame", sides=10)  # wheel
    # The windscreen leans back toward the helm, as in the reference.
    frame = [(-1.0, -5.25, 4.85), (-0.92, -4.85, 6.55), (0.92, -4.85, 6.55), (1.0, -5.25, 4.85)]
    b.sweep(frame, BAR, "frame")
    b.loft(  # glass, a slab inside the frame
        [
            (-5.24, [(-0.9, 4.9), (0.9, 4.9), (0.9, 4.98), (-0.9, 4.98)]),
            (-4.88, [(-0.84, 6.4), (0.84, 6.4), (0.84, 6.48), (-0.84, 6.48)]),
        ],
        "glass",
    )
    for sign in (1, -1):  # grab rails down the console sides
        b.sweep([(sign * 1.32, -5.0, 3.0), (sign * 1.32, -5.0, 4.5), (sign * 1.32, -3.4, 4.5), (sign * 1.32, -3.4, 3.0)], 0.12, "frame")
        b.bar((sign * 1.2, -5.0, 3.0), (sign * 1.32, -5.0, 3.0), radius=0.12)
        b.bar((sign * 1.2, -3.4, 3.0), (sign * 1.32, -3.4, 3.0), radius=0.12)

    # Seats: the helm behind the wheel, then two rows of two.
    seat(b, 0.0, -1.2)
    for cy in (2.2, 5.4):
        for cx in (-1.15, 1.15):
            seat(b, cx, cy)

    # Radar arch over the stern: an A-frame each side, tied across the top.
    top_z, foot_z = 7.2, 3.05
    for sign in (1, -1):
        b.sweep(
            [(sign * 3.7, 10.9, foot_z), (sign * 2.7, 9.7, top_z), (sign * 2.7, 8.3, top_z), (sign * 3.7, 6.9, foot_z)],
            BAR,
            "frame",
        )
        b.bar((sign * 3.22, 10.32, 5.05), (sign * 3.22, 7.48, 5.05))  # brace between the legs
        for y in (10.9, 6.9):  # foot pads on the collar
            b.box(sign * 3.4, sign * 4.0, y - 0.3, y + 0.3, foot_z - 0.08, foot_z + 0.1, "tube_band")
    b.bar((-2.7, 9.7, top_z), (2.7, 9.7, top_z))
    b.bar((-2.7, 8.3, top_z), (2.7, 8.3, top_z))
    b.box(-1.7, 1.7, 8.25, 9.75, top_z + 0.1, top_z + 0.24, "deck_dark")  # equipment plate
    b.box(-1.1, 1.1, 8.7, 9.3, top_z + 0.24, top_z + 0.52, "frame")  # light bar
    for x0, x1 in ((-1.0, -0.4), (0.4, 1.0)):
        b.box(x0, x1, 8.66, 8.7, top_z + 0.3, top_z + 0.46, "light")  # forward floodlights
    b.sweep([(-1.45, 9.0, top_z + 0.24), (-1.45, 9.0, top_z + 0.8)], 0.22, "beacon", sides=8)  # blue beacon
    b.sweep([(1.45, 9.0, top_z + 0.24), (1.45, 9.0, top_z + 0.62)], 0.3, "console", sides=8)  # radar dome

    # Outboards and the guard rail around them.
    for cx in (-1.25, 1.25):
        engine(b, cx)
    rail_y = 15.0 - BAR
    b.sweep([(-3.3, 12.0, 3.0), (-3.3, rail_y, 3.7), (3.3, rail_y, 3.7), (3.3, 12.0, 3.0)], BAR, "frame")
    b.sweep([(-3.1, 12.1, 1.6), (-3.1, rail_y, 2.3), (3.1, rail_y, 2.3), (3.1, 12.1, 1.6)], BAR, "frame")
    for x in (-3.2, 0.0, 3.2):
        b.bar((x, rail_y, 3.7), (x * 0.97, rail_y, 2.3))

    # Bow: a short light post with red and green navigation lights, and a towing eye.
    b.bar((0, -12.9, 2.5), (0, -12.9, 3.7), radius=0.13)
    b.box(-0.3, -0.05, -13.05, -12.75, 3.45, 3.75, "red")
    b.box(0.05, 0.3, -13.05, -12.75, 3.45, 3.75, "green")
    b.box(-0.2, 0.2, -14.2, -13.6, 3.5, 3.72, "metal")  # bow fitting on top of the collar

    low = min(v.co.z for v in b.bm.verts)
    for v in b.bm.verts:
        v.co.z -= low

    mesh = bpy.data.meshes.new("PatrolRhib")
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
    image = bpy.data.images.new("PatrolRhibClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image):
    mat = bpy.data.materials.new("PatrolRhibPalette")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def render(name, location, target, lens=50, size=(1100, 800)):
    sc = bpy.context.scene
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_end = 500
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
    ob = bpy.data.objects.new("PatrolRhib", mesh)
    bpy.context.scene.collection.objects.link(ob)

    tris = len(mesh.polygons)
    lo = [min(v.co[i] for v in mesh.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in mesh.vertices) for i in range(3)]
    print("clean patrol RHIB: %d triangles, %.2f wide x %.2f long x %.2f tall studs, y %.2f to %.2f, base z=%.2f"
          % (tris, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], lo[1], hi[1], lo[2]))
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
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.9, 0.91, 0.93, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    sun.data.energy = 3.5
    REVIEW.mkdir(parents=True, exist_ok=True)
    render("quarter", (-24, 30, 24), (0, 0, 2.5), lens=55)  # the reference picture's angle: from the stern quarter, above
    render("side", (-70, 0, 6), (0, 0, 3.5), lens=70, size=(1300, 500))


main()
