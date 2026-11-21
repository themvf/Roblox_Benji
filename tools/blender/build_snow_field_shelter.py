"""Build the closed or open-door field shelter from saved reference views."""
import argparse
from pathlib import Path
import math
import random
import sys

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument("--doors-open", action="store_true")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
DOORS_OPEN = args.doors_open

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/snow-field-shelter"
TEXTURES = PKG / "textures"
BLEND = PKG / ("source/SnowFieldShelter_OpenDoor.blend" if DOORS_OPEN
               else "source/SnowFieldShelter.blend")
OUTPUT = PKG / ("exports/SnowFieldShelter_OpenDoor.glb" if DOORS_OPEN
                else "exports/SnowFieldShelter.glb")
TEXTURES.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

HALF_WIDTH = 12.0
HALF_LENGTH = 16.0
SPRING = 6.2
RISE = 7.8
HEIGHT = SPRING + RISE


def save_image(name, color, size=64, fabric=False):
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    rng = random.Random(name)
    pixels = []
    for y in range(size):
        for x in range(size):
            if fabric:
                # Broad pulled-canvas folds, stitched bays, and scuffed ends.
                u, v = x / size, y / size
                warped = u * 17 + .10 * math.sin(v * 17 + u * 7)
                fold = .018 * math.sin(warped * 2 * math.pi)
                crease = -.018 if (x % 128) < 4 else 0.0
                broad = .009 * math.sin(v * 23 + u * 12)
                end_wear = max(0, (u - .81) / .19, (.19 - u) / .19)
                scuff = end_wear * .036 * max(0, math.sin(v * 70 + u * 19))
                snow_dust = .018 * max(0, (.17 - v) / .17) * rng.random()
                noise = rng.uniform(-.008, .008)
                value = crease + fold + broad + scuff + snow_dust + noise
            else:
                value = rng.uniform(-.005, .005)
            pixels.extend([max(0, min(1, channel + value)) for channel in color] + [1])
    image.pixels = pixels
    image.filepath_raw = str(TEXTURES / (name + "_Color.png"))
    image.file_format = "PNG"
    image.save()
    return image


def fabric_normal_image():
    size = 512
    image = bpy.data.images.new("Canvas woven folds normal", width=size, height=size, alpha=True)
    pixels = []
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            phase = (u * 17 + .10 * math.sin(v * 17 + u * 7)) * 2 * math.pi
            du = .14 * math.cos(phase)
            dv = .035 * math.cos(phase) + .025 * math.cos(v * 23 + u * 12)
            nx, ny, nz = -du, -dv, 1.0
            length = math.sqrt(nx*nx + ny*ny + nz*nz)
            pixels.extend((.5+.5*nx/length, .5+.5*ny/length,
                           .5+.5*nz/length, 1))
    image.pixels = pixels
    image.filepath_raw = str(TEXTURES / "Charcoal_insulated_fabric_Normal.png")
    image.file_format = "PNG"
    image.save()
    image.colorspace_settings.name = "Non-Color"
    return image


def material(name, rgb, roughness, metallic=0, fabric=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = save_image(name.replace(" ", "_"), rgb, 1024 if fabric else 64, fabric)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


canvas = material("Charcoal insulated fabric", (.038, .042, .049), .84, fabric=True)
canvas_tex = canvas.node_tree.nodes.new("ShaderNodeTexImage")
canvas_tex.image = fabric_normal_image()
canvas_normal = canvas.node_tree.nodes.new("ShaderNodeNormalMap")
canvas_normal.inputs["Strength"].default_value = .55
canvas.node_tree.links.new(canvas_tex.outputs["Color"], canvas_normal.inputs["Color"])
canvas.node_tree.links.new(canvas_normal.outputs["Normal"],
                            canvas.node_tree.nodes["Principled BSDF"].inputs["Normal"])
paint = material("White painted aluminum", (.75, .80, .83), .32, .38)
door_paint = material("Off-white steel door", (.69, .73, .75), .41, .25)
glass = material("Dark sealed window", (.008, .014, .019), .13, .25)
gasket = material("Graphite window gasket", (.015, .020, .024), .68)
seam = material("Black reinforced seam", (.019, .022, .027), .76)
hardware = material("Door hardware", (.10, .12, .13), .28, .7)
interior = material("Slate interior walkway", (.18, .20, .21), .74) if DOORS_OPEN else None


def mesh_object(name, vertices, faces, uvs, mat, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly, coords in zip(mesh.polygons, uvs):
        poly.use_smooth = smooth
        for loop_index, value in zip(poly.loop_indices, coords):
            uv.data[loop_index].uv = value
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    return ob


def quads_from_grid(name, grid, uvgrid, mat, smooth=False):
    rows = len(grid)
    columns = len(grid[0])
    vertices = [tuple(v) for row in grid for v in row]
    faces, uvs = [], []
    for row in range(rows - 1):
        for col in range(columns - 1):
            a = row * columns + col
            faces.append((a, a + 1, a + columns + 1, a + columns))
            uvs.append((uvgrid[row][col], uvgrid[row][col + 1],
                        uvgrid[row + 1][col + 1], uvgrid[row + 1][col]))
    ob = mesh_object(name, vertices, faces, uvs, mat, smooth)
    solid = ob.modifiers.new("Fabric thickness", "SOLIDIFY")
    solid.thickness = .12
    solid.offset = -1
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=solid.name)
    return ob


ys = [-HALF_LENGTH + 2*HALF_LENGTH*j/20 for j in range(21)]
for side in (-1, 1):
    zs = [SPRING * i/6 for i in range(7)]
    grid = [[(side*HALF_WIDTH + .03*math.sin(y*.55 + z*.26), y, z)
             for z in zs] for y in ys]
    uv = [[((y + HALF_LENGTH)/(2*HALF_LENGTH), z/HEIGHT) for z in zs] for y in ys]
    quads_from_grid("Canvas side " + str(side), grid, uv, canvas)

angles = [math.pi*i/64 for i in range(65)]
roof = [[(HALF_WIDTH*math.cos(a) + .028*math.sin(y*.45+a*3), y,
          SPRING + RISE*math.sin(a)) for a in angles] for y in ys]
roof_uv = [[((y + HALF_LENGTH)/(2*HALF_LENGTH), a/math.pi) for a in angles] for y in ys]
quads_from_grid("Continuous arched black roof", roof, roof_uv, canvas, True)

# The open variant has a real aperture through the front canvas, not a
# rotated door placed in front of an intact wall.
for label, y in (("Front", -HALF_LENGTH), ("Rear", HALF_LENGTH)):
    if label == "Front" and DOORS_OPEN:
        left, right, lintel = -3.225, .125, 7.49
        for section, x0, x1, bottom in (
            ("left", -HALF_WIDTH, left, 0.0),
            ("over-door", left, right, lintel),
            ("right", right, HALF_WIDTH, 0.0),
        ):
            count = max(4, int((x1-x0)*4))
            xs = [x0 + (x1-x0)*i/count for i in range(count+1)]
            grid = [[(x, y, bottom),
                     (x, y, SPRING + RISE*math.sqrt(max(0, 1-(x/HALF_WIDTH)**2)))]
                    for x in xs]
            uvgrid = [[((x+HALF_WIDTH)/(2*HALF_WIDTH), bottom/HEIGHT),
                       ((x+HALF_WIDTH)/(2*HALF_WIDTH),
                        (SPRING + RISE*math.sqrt(max(0, 1-(x/HALF_WIDTH)**2)))/HEIGHT)]
                      for x in xs]
            quads_from_grid("Front canvas " + section, grid, uvgrid, canvas)
        continue
    verts = [(-HALF_WIDTH, y, 0), (HALF_WIDTH, y, 0),
             (HALF_WIDTH, y, SPRING)]
    verts += [(HALF_WIDTH*math.cos(a), y, SPRING + RISE*math.sin(a))
              for a in angles[1:]]
    verts += [(-HALF_WIDTH, y, SPRING)]
    center = len(verts)
    verts.append((0, y, 5.2))
    faces, uvs = [], []
    for i in range(center):
        nxt = (i+1) % center
        faces.append((center, i, nxt) if y < 0 else (center, nxt, i))
        uvs.append(tuple(((verts[index][0]+HALF_WIDTH)/(2*HALF_WIDTH),
                           verts[index][2]/HEIGHT) for index in faces[-1]))
    mesh_object(label + " closed canvas gable", verts, faces, uvs, canvas)


def box(name, loc, scale, mat, bevel=.01):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new("Soft manufactured corner", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat)
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for loop_index in poly.loop_indices:
            v = ob.data.vertices[ob.data.loops[loop_index].vertex_index].co
            uv.data[loop_index].uv = ((v.x*.08) % 1, (v.z*.08) % 1)
    return ob


def pipe(name, points, radius, mat, sides=8):
    points = [Vector(p) for p in points]
    vertices, faces = [], []
    for index, point in enumerate(points):
        tangent = (points[min(index+1, len(points)-1)]
                   - points[max(index-1, 0)]).normalized()
        axis = tangent.cross(Vector((0, 1, 0)))
        if axis.length < .01:
            axis = tangent.cross(Vector((1, 0, 0)))
        axis.normalize()
        other = tangent.cross(axis).normalized()
        for j in range(sides):
            a = 2*math.pi*j/sides
            vertices.append(tuple(point + radius*(math.cos(a)*axis + math.sin(a)*other)))
    faces.append(tuple(reversed(range(sides))))
    for i in range(len(points)-1):
        for j in range(sides):
            k = (j+1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    uvs = []
    for face in faces:
        uvs.append(tuple((j/sides, i/max(1, len(points)-1))
                         for j, i in enumerate(range(len(face)))))
    return mesh_object(name, vertices, faces, uvs, mat, True)


def arch_points(y, x_radius, z_base, rise, segments=64):
    return [(x_radius*math.cos(math.pi*i/segments), y,
             z_base + rise*math.sin(math.pi*i/segments))
            for i in range(segments+1)]


front_y = -HALF_LENGTH - .22
rear_y = HALF_LENGTH + .07
pipe("Front outer white arch", arch_points(front_y, 12.08, SPRING, RISE+.05),
     .18, paint, 10)
pipe("Front inner white arch", arch_points(front_y-.08, 10.9, SPRING-.13, RISE-1.12),
     .11, paint, 8)
for x in (-12.08, 12.08):
    pipe("Front upright frame", [(x, front_y, 0), (x, front_y, SPRING)], .16, paint)
pipe("Rear outer white arch", arch_points(rear_y, 12.08, SPRING, RISE+.05),
     .15, paint, 8)
for x in (-12.08, 12.08):
    pipe("Rear upright frame", [(x, rear_y, 0), (x, rear_y, SPRING)], .14, paint)

# Triangular members sit in the visible front truss band between two arches.
for i in range(12):
    a0, a1 = math.pi*i/12, math.pi*(i+1)/12
    mid = (a0+a1)/2
    outer = (12.08*math.cos(mid), front_y-.10,
             SPRING + (RISE+.05)*math.sin(mid))
    inner0 = (10.9*math.cos(a0), front_y-.10,
              SPRING-.13+(RISE-1.12)*math.sin(a0))
    inner1 = (10.9*math.cos(a1), front_y-.10,
              SPRING-.13+(RISE-1.12)*math.sin(a1))
    pipe("White front truss diagonal", [inner0, outer, inner1], .075, paint, 6)

# The dark bands follow the roof's fabric tension points without obscuring it.
for y in (-12, -8, -4, 0, 4, 8, 12):
    pipe("Black canvas roof tension band", arch_points(y, 12.025, SPRING, RISE+.03, 40),
         .042, seam, 6)


def window(side, y):
    x = side*(HALF_WIDTH+.13)
    center_z, half_y, half_z = 4.65, 1.95, 1.15
    box("Sealed dark window", (x+side*.025, y, center_z),
        (.055, 2*half_y-.25, 2*half_z-.25), glass, .01)
    box("Window black gasket top", (x, y, center_z+half_z-.06),
        (.12, 2*half_y+.16, .16), gasket)
    for dz in (-half_z, half_z):
        box("White window horizontal frame", (x+side*.065, y, center_z+dz),
            (.17, 2*half_y+.24, .15), paint, .015)
    for dy in (-half_y, half_y):
        box("White window vertical frame", (x+side*.065, y+dy, center_z),
            (.17, .17, 2*half_z+.18), paint, .015)


for side in (-1, 1):
    for y in (-8.2, 8.2):
        window(side, y)

door_x, door_y = -1.55, -HALF_LENGTH-.17
door_parts = []
door_parts.append(box("Front solid steel door", (door_x, door_y-.06, 3.70),
                      (3.25, .22, 7.40), door_paint, .055))
for x in (door_x-1.68, door_x+1.68):
    box("Door white jamb", (x, door_y-.21, 3.74),
        (.17, .18, 7.48), paint, .015)
box("Door top lintel", (door_x, door_y-.21, 7.48),
    (3.55, .18, .18), paint, .015)
door_parts.append(box("Door dark vision panel", (door_x, door_y-.193, 5.13),
                      (1.48, .036, 1.68), gasket, .008))
door_parts.append(box("Door black glass", (door_x, door_y-.217, 5.13),
                      (1.29, .035, 1.49), glass, .005))
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                      radius=.105, location=(door_x+1.28, door_y-.31, 3.28))
bpy.context.object.name = "Round steel door handle"
bpy.context.object.data.materials.append(hardware)
door_parts.append(bpy.context.object)

if DOORS_OPEN:
    # Swing the intact panel 96 degrees outward on the left jamb.
    hinge = Vector((door_x-1.625, door_y-.06, 0))
    angle = math.radians(-76)
    for ob in door_parts:
        offset = ob.location - hinge
        ob.location = hinge + Vector((math.cos(angle)*offset.x-math.sin(angle)*offset.y,
                                      math.sin(angle)*offset.x+math.cos(angle)*offset.y,
                                      offset.z))
        ob.rotation_euler.z += angle
    for z in (1.05, 3.7, 6.4):
        pipe("Exposed door hinge", [(hinge.x, door_y-.20, z-.14),
                                     (hinge.x, door_y-.20, z+.14)], .09, hardware, 10)
    # A dark inner floor and frame depth make the cut-through doorway legible.
    box("Visible dark interior floor", (0, 0, .035), (23.7, 31.6, .07), seam, .01)
    box("Interior walkway", (door_x, -4.4, .095), (3.05, 23.1, .065), interior, .02)
    box("Metal entry threshold", (door_x, -HALF_LENGTH+.34, .115),
        (3.40, .34, .06), paint, .015)
    for y in (-11.5, -6.5, -1.5, 3.5):
        box("Walkway cross grip", (door_x, y, .132),
            (2.83, .10, .012), gasket, .002)
    for x in (-3.28, .18):
        box("Doorway inner return", (x, -HALF_LENGTH+.17, 3.73),
            (.10, .34, 7.46), gasket, .01)
    box("Doorway inner lintel", (-1.55, -HALF_LENGTH+.17, 7.51),
        (3.56, .34, .11), gasket, .01)

# Keep every authoring part in the source scene. Delivery groups by material
# after saving to limit imported MeshPart count while retaining distinct maps.
BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

for mat in (canvas, paint, door_paint, glass, gasket, seam, hardware) + ((interior,) if interior else ()):
    parts = [ob for ob in scene.objects if ob.type == "MESH" and ob.data.materials
             and ob.data.materials[0] == mat]
    if not parts:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "Shelter_" + mat.name.replace(" ", "_")

bpy.ops.object.select_all(action="DESELECT")
exports = [ob for ob in scene.objects if ob.type == "MESH"]
for ob in exports:
    ob.select_set(True)
bpy.context.view_layer.objects.active = exports[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB",
                          export_image_format="AUTO", export_yup=True,
                          use_selection=True)
print("EXPORTED", OUTPUT, len(exports), "material meshes")
