"""Clean, detailed build of the red off-road SUV, made to be driven. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_red_suv.py
    blender -b -noaudio --python tools/blender/build_red_suv.py -- --no-render

Normally run through `python tools/asset_generate.py build red-suv`.

Why this is built from shapes: the generated SUV (assets/models/test-suv, made by Tripo)
was sound but shiny, with a smeared grille, wheels fused to the body and windows painted
on. A car that is driven needs wheels that turn and, for the view from the driver's seat,
a cabin to sit in. This is the same car as flat-coloured panels, matte, in six parts:

    Body      everything opaque, including the interior
    Glass     the window panes; game code makes this part see-through
    WheelFL, WheelFR, WheelRL, WheelRR   front/rear, left/right as the driver sees them

The reference picture (source/reference.jpg) is the guide for layout and proportions only.
No geometry is taken from it or from the generated mesh.

Units are studs. Blender Z is up and the nose points down -Y, which arrives in Roblox
facing -Z, the way VehicleSeat and the drive code face. Blender +X is the driver's left.
The origin is on the ground under the middle of the car: about 16.9 long, 7.5 wide over
the mirrors, 6 tall.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/red-suv"
EXPORT = PKG / "exports/RedSuvClean.glb"
PALETTE_PNG = PKG / "textures/RedSuvClean_Palette.png"
REVIEW = PKG / "review"

# Flat colours, sRGB 0-255. One swatch each; every face's UVs sit at the centre of its
# swatch, so texture filtering can never bleed a neighbour in.
PALETTE = [
    ("red", (98, 16, 25)),
    ("red_dark", (70, 11, 18)),
    ("red_light", (112, 21, 30)),
    ("glass", (30, 36, 42)),
    ("black", (17, 17, 19)),
    ("trim", (34, 35, 38)),
    ("tyre", (27, 27, 29)),
    ("rim", (52, 53, 57)),
    ("rim_dark", (20, 20, 22)),
    ("light", (236, 239, 226)),
    ("tail", (206, 34, 30)),
    ("grey", (74, 77, 82)),
    ("plate", (212, 214, 208)),
    ("amber", (226, 142, 36)),
    ("interior", (44, 42, 42)),
    ("seat", (86, 66, 50)),
]
COLS, ROWS, SWATCH = 4, 4, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}

# Layout, in studs.
WHEEL_R = 1.5  # tyre radius: big off-road tyres, about half the body's height
AXLE_Z = WHEEL_R + 0.15  # axle height: the tread blocks stand 0.15 proud of the tyre
WHEEL_IN, WHEEL_OUT = 2.2, 3.5  # tyre inner and outer face, from the centre line
AXLES = (-5.2, 4.9)  # front and rear axle, along the car
ARCH_R = 1.85  # wheel-arch radius
BODY_W = 3.05  # half width of the body sides
CORE_W = 2.15  # half width of the cabin; the fenders and doors are the 0.9 outside it
FLOOR, BELT, ROOF = 1.5, 4.25, 5.85  # underside, window line, roof
CABIN = (-2.0, 6.6)  # the hollow part: bulkhead behind the engine to the boot wall
SCREEN = (-1.7, -0.1)  # windscreen base and top
REAR = (5.6, 7.3)  # rear window top and base
SEAT_X = 1.1  # front seats' distance from the centre line


class Builder:
    """One mesh: closed, single-coloured shells with outward normals."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _finish(self, faces, colour):
        # Every shape here is a closed shell, so outward normals are well defined.
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        # recalc only makes a shell consistent; it can leave the whole shell inside out
        # (the patrol boat's hull, 53% see-through). A closed shell with outward normals
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

    def extrude(self, profile, x0, x1, colour):
        """A side profile [(y, z), ...] pushed across the car from x0 to x1. It may be concave
        (a wheel arch); the end caps are triangulated when the mesh is written."""
        return self._skin([[self.bm.verts.new((x, y, z)) for y, z in profile] for x in (x0, x1)], colour)

    def box(self, x0, x1, y0, y1, z0, z1, colour):
        x0, x1 = sorted((x0, x1))
        ring = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        return self.loft([(y0, ring), (y1, ring)], colour)

    def sweep(self, path, radius, colour, sides=6):
        """A tube along 3D points. `radius` is one number or one per point. Ends are capped.

        The ring is carried from point to point without twisting, so bends stay clean."""
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

    def mesh(self):
        mesh = bpy.data.meshes.new(self.name)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(mesh)
        self.bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = False
        return mesh


def arch(centre):
    """The top half of a wheel arch, front to back, as profile points."""
    return [(centre + ARCH_R * math.cos(math.radians(d)), AXLE_Z + ARCH_R * math.sin(math.radians(d)) if d not in (0, 180) else FLOOR) for d in range(180, -1, -15)]


def build_body():
    b = Builder("Body")

    # Bonnet and tail lines, shared by the fenders and the core so their tops meet.
    nose = [(-8.25, 2.0), (-7.85, 1.6)]
    hood = [(CABIN[0], BELT), (-7.6, 4.1), (-8.25, 3.95)]
    tail = [(7.85, 1.7), (8.25, 2.2), (8.25, 3.95), (7.9, BELT)]

    # Fenders and doors: the body side as one profile with both wheel arches cut out of it.
    side = nose + arch(AXLES[0]) + arch(AXLES[1]) + tail + hood
    for sign in (1, -1):
        b.extrude(side, sign * CORE_W, sign * BODY_W, "red")
        b.box(sign * (CORE_W - 0.08), sign * CORE_W, CABIN[0], CABIN[1], FLOOR + 0.3, BELT - 0.04, "interior")  # door card
        for centre in AXLES:  # wheel housing: a dark plate behind each tyre
            b.box(sign * (CORE_W - 0.02), sign * (CORE_W + 0.06), centre - ARCH_R, centre + ARCH_R, FLOOR, AXLE_Z + ARCH_R - 0.05, "black")
            flare = [(sign * (BODY_W + 0.1), y, z) for y, z in arch(centre)]
            b.sweep(flare, [0.1] + [0.19] * (len(flare) - 2) + [0.1], "red_dark", sides=6)  # tapers into the sill

    # Core: engine bay, floor and boot. The cabin is the gap between the two blocks.
    b.extrude(nose + [(CABIN[0], FLOOR), (CABIN[0], BELT), (-7.6, 4.1), (-8.25, 3.95)], -CORE_W, CORE_W, "red")
    b.extrude([(CABIN[1], FLOOR)] + tail + [(CABIN[1], BELT)], -CORE_W, CORE_W, "red")
    b.box(-CORE_W, CORE_W, CABIN[0], CABIN[1], FLOOR, FLOOR + 0.3, "interior")
    b.loft(  # bonnet: a raised centre panel running back to the windscreen
        [
            (-8.05, [(-1.5, 3.95), (1.5, 3.95), (1.5, 4.14), (-1.5, 4.14)]),
            (-7.4, [(-1.6, 4.05), (1.6, 4.05), (1.6, 4.3), (-1.6, 4.3)]),
            (-2.1, [(-1.95, 4.18), (1.95, 4.18), (1.95, 4.42), (-1.95, 4.42)]),
        ],
        "red_light",
    )

    # Interior: dashboard, steering wheel, console, two front seats and a rear bench.
    floor = FLOOR + 0.3
    b.loft(
        [
            (CABIN[0] - 0.02, [(-CORE_W + 0.1, 3.0), (CORE_W - 0.1, 3.0), (CORE_W - 0.1, BELT + 0.12), (-CORE_W + 0.1, BELT + 0.12)]),
            (CABIN[0] + 0.95, [(-CORE_W + 0.1, 3.0), (CORE_W - 0.1, 3.0), (CORE_W - 0.1, 3.75), (-CORE_W + 0.1, 3.75)]),
        ],
        "interior",
    )
    b.box(SEAT_X - 0.45, SEAT_X + 0.45, CABIN[0] + 0.5, CABIN[0] + 0.98, 3.72, 4.05, "black")  # instrument binnacle
    b.box(-0.55, 0.55, CABIN[0] + 0.3, CABIN[0] + 0.98, 3.2, 3.85, "black")  # centre screen
    b.box(-0.42, 0.42, CABIN[0] + 0.94, CABIN[0] + 1.0, 3.3, 3.75, "grey")
    b.sweep([(SEAT_X, CABIN[0] + 0.9, 3.45), (SEAT_X, CABIN[0] + 1.55, 3.7)], 0.09, "black")  # steering column
    rim = [(SEAT_X + 0.55 * math.cos(a), CABIN[0] + 1.6 - 0.2 * math.sin(a), 3.72 + 0.52 * math.sin(a)) for a in [math.radians(d) for d in range(0, 360, 30)]]
    b.sweep(rim + rim[:2], 0.07, "black", sides=5)
    b.box(SEAT_X - 0.5, SEAT_X + 0.5, CABIN[0] + 1.56, CABIN[0] + 1.64, 3.66, 3.78, "black")  # spoke
    b.box(-0.4, 0.4, CABIN[0] + 0.9, 3.2, floor, 2.75, "interior")  # centre console
    for sign in (1, -1):
        cx = sign * SEAT_X
        b.box(cx - 0.72, cx + 0.72, 0.3, 1.95, floor, 2.5, "seat")
        b.loft(
            [
                (1.7, [(cx - 0.72, 2.45), (cx + 0.72, 2.45), (cx + 0.66, 4.45), (cx - 0.66, 4.45)]),
                (2.15, [(cx - 0.72, 2.45), (cx + 0.72, 2.45), (cx + 0.6, 4.3), (cx - 0.6, 4.3)]),
            ],
            "seat",
        )
        b.box(cx - 0.34, cx + 0.34, 1.82, 2.12, 4.45, 4.95, "seat")  # head restraint
    b.box(-CORE_W + 0.12, CORE_W - 0.12, 4.3, 5.75, floor, 2.5, "seat")
    b.loft(
        [
            (5.55, [(-CORE_W + 0.12, 2.45), (CORE_W - 0.12, 2.45), (CORE_W - 0.2, 4.3), (-CORE_W + 0.2, 4.3)]),
            (6.0, [(-CORE_W + 0.12, 2.45), (CORE_W - 0.12, 2.45), (CORE_W - 0.2, 4.15), (-CORE_W + 0.2, 4.15)]),
        ],
        "seat",
    )
    b.box(-CORE_W, CORE_W, 6.0, CABIN[1], floor, BELT - 0.02, "interior")  # parcel shelf and boot wall

    # Roof, pillars and rails. The windows are the open frames between them.
    b.loft(
        [
            (SCREEN[1] - 0.2, [(-2.48, ROOF - 0.08), (2.48, ROOF - 0.08), (2.4, ROOF + 0.1), (-2.4, ROOF + 0.1)]),
            (REAR[0] + 0.2, [(-2.48, ROOF - 0.08), (2.48, ROOF - 0.08), (2.4, ROOF + 0.1), (-2.4, ROOF + 0.1)]),
        ],
        "red",
    )
    b.box(-2.3, 2.3, SCREEN[1] - 0.1, REAR[0] + 0.1, ROOF - 0.14, ROOF - 0.07, "interior")  # headliner
    for sign in (1, -1):
        low_front, high_front = (sign * 2.8, SCREEN[0], BELT), (sign * 2.46, SCREEN[1] - 0.05, ROOF)
        high_rear, low_rear = (sign * 2.46, REAR[0] + 0.05, ROOF), (sign * 2.8, REAR[1], BELT)
        b.sweep([low_front, high_front, high_rear, low_rear], 0.17, "red", sides=6)  # A pillar, roof rail, C pillar
        b.sweep([(sign * 2.84, 2.7, BELT - 0.05), (sign * 2.48, 2.7, ROOF)], 0.15, "red", sides=6)  # B pillar
        b.sweep([(sign * 2.1, 0.4, ROOF + 0.22), (sign * 2.1, 5.2, ROOF + 0.22)], 0.07, "trim", sides=5)  # roof bar
        for y in (0.6, 5.0):
            b.box(sign * 2.03, sign * 2.17, y - 0.08, y + 0.08, ROOF + 0.08, ROOF + 0.2, "trim")
        # Door mirror on a stalk.
        b.box(sign * 2.95, sign * 3.3, -1.45, -1.25, BELT + 0.04, BELT + 0.16, "trim")
        b.loft(
            [
                (-1.62, [(sign * 3.24, BELT + 0.04), (sign * 3.72, BELT + 0.08), (sign * 3.72, BELT + 0.46), (sign * 3.24, BELT + 0.5)]),
                (-1.2, [(sign * 3.2, BELT + 0.02), (sign * 3.75, BELT + 0.02), (sign * 3.75, BELT + 0.52), (sign * 3.2, BELT + 0.52)]),
            ],
            "red_dark",
        )
        # Sill, body-side crease, door shut lines and handles.
        b.box(sign * 2.9, sign * (BODY_W + 0.1), AXLES[0] + ARCH_R + 0.1, AXLES[1] - ARCH_R - 0.1, FLOOR - 0.08, FLOOR + 0.36, "trim")
        b.box(sign * (BODY_W - 0.02), sign * (BODY_W + 0.05), AXLES[0] + ARCH_R + 0.2, 7.6, 3.42, 3.52, "red_dark")
        for y in (CABIN[0] + 0.25, 2.7, 5.9):
            b.box(sign * (BODY_W - 0.02), sign * (BODY_W + 0.03), y - 0.03, y + 0.03, FLOOR + 0.4, BELT - 0.05, "red_dark")
        for y in (1.7, 4.9):
            b.box(sign * (BODY_W - 0.02), sign * (BODY_W + 0.09), y, y + 0.62, 3.72, 3.84, "trim")
        # Headlamp housing with a slim light bar above it, and the tail lamp round the corner.
        b.box(sign * 1.45, sign * 2.6, -8.33, -8.12, 2.45, 3.5, "red_dark")
        b.box(sign * 1.58, sign * 2.47, -8.38, -8.2, 2.6, 3.3, "black")
        b.box(sign * 1.45, sign * 2.6, -8.37, -8.15, 3.62, 3.74, "light")
        b.box(sign * 1.9, sign * 2.72, 8.2, 8.34, 3.3, 3.78, "tail")
        b.box(sign * 2.2, sign * 2.5, 8.3, 8.43, 1.85, 2.03, "amber")  # reflector

    # Nose: tall upright grille in a body-colour surround, with recessed slats.
    b.box(-1.34, 1.34, -8.36, -8.1, 2.02, 3.94, "red_dark")
    b.box(-1.16, 1.16, -8.42, -8.2, 2.16, 3.8, "black")
    for i in range(9):
        x = -0.96 + i * 0.24
        b.box(x - 0.04, x + 0.04, -8.47, -8.3, 2.2, 3.76, "trim")
    b.box(-2.75, 2.75, -8.4, -7.85, 1.6, 2.08, "trim")  # bumper
    b.box(-1.5, 1.5, -8.46, -7.9, 1.42, 1.72, "grey")  # skid plate

    # Tail: lamp bar joining the two lamps, number plate recess, bumper.
    b.box(-1.9, 1.9, 8.2, 8.31, 3.48, 3.6, "tail")
    b.box(-0.95, 0.95, 8.22, 8.35, 2.6, 3.12, "black")
    b.box(-0.8, 0.8, 8.3, 8.39, 2.68, 3.04, "plate")
    b.box(-2.75, 2.75, 7.85, 8.4, 1.7, 2.2, "trim")
    return b


def build_glass():
    """Thin panes in the window frames. One part, made see-through by game code."""
    g = Builder("Glass")

    def pane(y0, z0, y1, z1, half0, half1):
        g.loft(
            [
                (y0, [(-half0, z0), (half0, z0), (half0, z0 + 0.06), (-half0, z0 + 0.06)]),
                (y1, [(-half1, z1), (half1, z1), (half1, z1 + 0.06), (-half1, z1 + 0.06)]),
            ],
            "glass",
        )

    pane(SCREEN[0] + 0.02, BELT + 0.04, SCREEN[1] - 0.04, ROOF - 0.12, 2.68, 2.34)  # windscreen
    pane(REAR[0] + 0.04, ROOF - 0.12, REAR[1] - 0.02, BELT + 0.04, 2.34, 2.68)  # rear window

    def lean(z):  # the side glass leans in toward the roof, like the pillars
        return 2.8 - (z - BELT) / (ROOF - BELT) * 0.34

    def side(sign, stations):  # [(y, top z)]
        g.loft(
            [(y, [(sign * lean(BELT), BELT + 0.02), (sign * (lean(BELT) - 0.06), BELT + 0.02), (sign * (lean(top) - 0.06), top), (sign * lean(top), top)]) for y, top in stations],
            "glass",
        )

    for sign in (1, -1):
        side(sign, [(SCREEN[0] + 0.25, BELT + 0.2), (SCREEN[1], ROOF - 0.12), (2.58, ROOF - 0.12)])  # front door
        side(sign, [(2.82, ROOF - 0.12), (REAR[0], ROOF - 0.12), (REAR[1] - 0.25, BELT + 0.2)])  # rear door
    return g


def build_wheel(name, sign, y):
    """One wheel on its own, so game code can spin it: tyre, dished rim, five spokes, hub."""
    w = Builder(name)
    z = AXLE_Z
    w.sweep(
        [(sign * WHEEL_IN, y, z), (sign * (WHEEL_IN + 0.14), y, z), (sign * (WHEEL_OUT - 0.14), y, z), (sign * WHEEL_OUT, y, z)],
        [WHEEL_R - 0.16, WHEEL_R, WHEEL_R, WHEEL_R - 0.16],
        "tyre",
        sides=24,
    )
    for k in range(12):  # tread blocks across the crown
        a = 2 * math.pi * k / 12
        centre = Vector((0, y + (WHEEL_R + 0.02) * math.cos(a), z + (WHEEL_R + 0.02) * math.sin(a)))
        along = Vector((0, -math.sin(a), math.cos(a)))
        w.sweep([centre + Vector((sign * (WHEEL_IN + 0.2), 0, 0)) - along * 0.0, centre + Vector((sign * (WHEEL_OUT - 0.2), 0, 0))], 0.13, "rim_dark", sides=4)
    w.sweep([(sign * (WHEEL_OUT - 0.34), y, z), (sign * (WHEEL_OUT - 0.26), y, z)], 1.0, "rim_dark", sides=20)  # dish
    w.sweep([(sign * (WHEEL_OUT - 0.3), y, z), (sign * (WHEEL_OUT + 0.02), y, z)], [1.02, 0.94], "rim", sides=20)  # rim lip
    w.sweep([(sign * (WHEEL_OUT - 0.28), y, z), (sign * (WHEEL_OUT - 0.02), y, z)], 0.86, "rim_dark", sides=20)  # recess
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        tip = Vector((sign * (WHEEL_OUT - 0.04), y + 0.9 * math.cos(a), z + 0.9 * math.sin(a)))
        w.sweep([(sign * (WHEEL_OUT + 0.04), y, z), tip], [0.2, 0.13], "rim", sides=4)
    w.sweep([(sign * (WHEEL_OUT - 0.05), y, z), (sign * (WHEEL_OUT + 0.12), y, z)], 0.27, "rim", sides=10)  # hub
    return w


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
    image = bpy.data.images.new("RedSuvClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image):
    mat = bpy.data.materials.new("RedSuvPalette")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8  # matte: the generated car's gloss is what read as wrong in game
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
    cam.data.clip_start = 0.05
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
    # Front is -Y and the driver's left is +X, so the left wheels are the +X ones.
    parts = [build_body(), build_glass()]
    for label, y in (("F", AXLES[0]), ("R", AXLES[1])):
        parts.append(build_wheel("Wheel" + label + "L", 1, y))
        parts.append(build_wheel("Wheel" + label + "R", -1, y))

    mat = material(write_palette())
    objects, total = [], 0
    low, high = [1e9] * 3, [-1e9] * 3
    for part in parts:
        mesh = part.mesh()
        mesh.materials.append(mat)
        ob = bpy.data.objects.new(part.name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        objects.append(ob)
        tris = len(mesh.polygons)
        total += tris
        assert tris <= 10000, part.name + " is over Roblox's per-mesh cap"
        for v in mesh.vertices:
            for i in range(3):
                low[i], high[i] = min(low[i], v.co[i]), max(high[i], v.co[i])
        print("  %-8s %5d triangles" % (part.name, tris))
    print("clean red SUV: %d triangles in %d parts, %.2f wide x %.2f long x %.2f tall studs, y %.2f to %.2f, base z=%.2f"
          % (total, len(objects), high[0] - low[0], high[1] - low[1], high[2] - low[2], low[1], high[1], low[2]))
    assert abs(low[2]) < 0.02, "the tyres should sit on z = 0"

    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
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
    render("quarter", (-17, -22, 10), (0, 0, 2.8), lens=55)  # the reference picture's angle: front quarter, slightly above
    render("side", (-48, 0, 4), (0, 0, 3.0), lens=70, size=(1300, 600))
    # The driver's view: from where the head sits, with the glass hidden as it is see-through in game.
    for ob in objects:
        if ob.name == "Glass":
            ob.hide_render = True
    render("driver", (SEAT_X, 1.25, 5.15), (SEAT_X * 0.6, -9.0, 4.4), lens=14)


main()
