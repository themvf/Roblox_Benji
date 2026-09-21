"""Reproducible Snow Fortress architectural kit; run with Blender 4.3 --background.

Local axes: X across facade, Y into building, Z up. 1 unit = 1 stud.
Authoring collections retain component meshes. Exports are joined, UV-unwrapped
and baked to portable PBR images. Review staging is never included in exports.
"""
import bpy
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/snow-fortress/entrance-kit-v1"
for directory in [OUT, OUT / "textures", OUT / "exports", OUT / "renders"]:
    directory.mkdir(parents=True, exist_ok=True)
random.seed(197)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
scene.unit_settings.scale_length = 1
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 1440
scene.render.resolution_y = 960
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.52, 0.66, 0.83, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
scene.view_settings.view_transform = "AgX"
scene.render.image_settings.file_format = "PNG"


def material(name, color, rough=0.7, metal=0, texture=True):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    n, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = n.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if texture:
        coord = n.new("ShaderNodeTexCoord")
        noise = n.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 3.8
        noise.inputs["Detail"].default_value = 4
        noise.inputs["Roughness"].default_value = 0.72
        links.new(coord.outputs["Object"], noise.inputs["Vector"])
        ramp = n.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.18
        ramp.color_ramp.elements[0].color = (*(v * 0.65 for v in color), 1)
        ramp.color_ramp.elements[1].position = 0.82
        ramp.color_ramp.elements[1].color = (*(min(1, v * 1.22) for v in color), 1)
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        fine = n.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 36
        fine.inputs["Detail"].default_value = 2
        links.new(coord.outputs["Object"], fine.inputs["Vector"])
        bump = n.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.24
        bump.inputs["Distance"].default_value = 0.045
        links.new(fine.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


STONE = material("Slate / blue charcoal", (0.095, 0.125, 0.155))
STONE_LIGHT = material("Slate / cut face", (0.18, 0.22, 0.245))
BASE = material("Basalt / foundations", (0.10, 0.125, 0.145), 0.86)
STEEL = material("Steel / coated graphite", (0.13, 0.16, 0.18), 0.42, 0.65)
EDGE = material("Steel / edge caps", (0.31, 0.35, 0.37), 0.36, 0.72)
SNOW = material("Snow / chalk white", (0.84, 0.91, 0.97), 0.93)
FLOOR = material("Concrete / worn floor", (0.32, 0.35, 0.37), 0.86)
AMBER = material("Lamp / ivory amber lens", (1, 0.60, 0.19), 0.32, texture=False)
bsdf = AMBER.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Emission Color"].default_value = (1, 0.48, 0.12, 1)
bsdf.inputs["Emission Strength"].default_value = 2

modules = {}
collisions = {}
current = None


def module(name):
    global current
    current = bpy.data.collections.new(name)
    scene.collection.children.link(current)
    modules[name] = current
    collisions[name] = []
    return current


def register(obj, mat):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def cube(name, loc, size, mat=STONE, bevel=0.07, collision=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    register(obj, mat)
    if bevel:
        mod = obj.modifiers.new("Manufactured edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        normal = obj.modifiers.new("Face weighted normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=normal.name)
    if collision:
        collisions[current.name].append({"name": name, "center": list(loc), "size": list(size)})
    return obj


def snow_cap(name, center, size):
    # Closed, softly undulating snow mesh. The lower surface sits on its support.
    x, y, z = center
    w, d, h = size
    nx, ny = max(3, int(w * 1.3)), max(2, int(d * 1.3))
    vertices, faces = [], []
    for layer in range(2):
        for j in range(ny + 1):
            for i in range(nx + 1):
                xx, yy = w * (i / nx - 0.5), d * (j / ny - 0.5)
                edge = min(i / nx, 1 - i / nx, j / ny, 1 - j / ny)
                zz = 0 if layer == 0 else h * (0.65 + 0.25 * math.sin(xx * 1.7 + yy) + 0.12 * math.cos(xx * 3 - yy * 2))
                if layer and edge == 0:
                    zz *= 0.65
                vertices.append((x + xx, y + yy, z + zz))
    count = (nx + 1) * (ny + 1)
    for layer in range(2):
        for j in range(ny):
            for i in range(nx):
                a = layer * count + j * (nx + 1) + i
                q = (a, a + 1, a + nx + 2, a + nx + 1)
                faces.append(q if layer else q[::-1])
    boundary = list(range(nx + 1)) + [j * (nx + 1) + nx for j in range(1, ny + 1)]
    boundary += [ny * (nx + 1) + i for i in range(nx - 1, -1, -1)]
    boundary += [j * (nx + 1) for j in range(ny - 1, 0, -1)]
    for a, b in zip(boundary, boundary[1:] + boundary[:1]):
        faces.append((a, b, b + count, a + count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    register(obj, SNOW)
    for face in mesh.polygons:
        face.use_smooth = True
    return obj


def bolt(name, x, y, z):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.115, depth=0.07,
                                      location=(x, y, z), rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    register(obj, EDGE)


def lamp(x, y, z, horizontal=False):
    shape = (3.1, 0.38, 0.65) if horizontal else (0.68, 0.38, 2.5)
    lens = (2.7, 0.12, 0.3) if horizontal else (0.30, 0.12, 2.1)
    cube("Lamp housing", (x, y, z), shape, STEEL)
    cube("Amber lens", (x, y - 0.22, z), lens, AMBER, 0.035)


module("SF_Portal_20")
for side in [-1, 1]:
    x = side * 12
    cube("Portal jamb", (x, 0.65, 7), (4, 3.3, 14), BASE, collision=True)
    # Layered front/rear jambs create a deep opening; none enters the clear 20 studs.
    cube("Cut stone face", (x, -1.13, 7.7), (3.65, 0.35, 11.6), STONE_LIGHT)
    cube("Foot block", (x, -0.05, 0.8), (4, 4.7, 1.6), BASE)
    cube("Steel reveal", (side * 10.15, 0.55, 6.5), (0.3, 3, 13), STEEL)
    for height in [3, 6, 9, 12]:
        cube("Jamb stone joint", (x, -1.33, height), (3.6, 0.035, 0.065), BASE, 0)
    lamp(x, -1.4, 8)
    for dx in [-1.35, 1.35]:
        for height in [2, 13]:
            bolt("Jamb fixing", x + dx, -1.35, height)
cube("Portal lintel", (0, 0.65, 14), (28, 3.3, 2), BASE, collision=True)
cube("Lintel facing", (0, -1.12, 14.2), (19.8, 0.4, 1.2), STONE_LIGHT)
cube("Drip cornice", (0, -0.2, 15.3), (29, 5.3, 0.6), EDGE, collision=True)
cube("Upper crest", (0, 0.55, 16.9), (28, 3.4, 2.6), STONE, collision=True)
for x in [-8, 0, 8]:
    cube("Crest joint", (x, -1.18, 16.9), (0.06, 0.05, 2.3), BASE, 0)
cube("Crest coping", (0, 0.55, 18.4), (29, 4.1, 0.4), EDGE, collision=True)
snow_cap("Portal snow", (0, 0.55, 18.6), (29.2, 4.25, 0.42))
lamp(0, -1.43, 14.2, True)

module("SF_WallBay_10")
cube("Wall backing", (0, 0.5, 6.5), (10, 2.8, 13), BASE, collision=True)
cube("Foundation course", (0, 0.2, 0.65), (10, 3.4, 1.3), BASE)
for row in range(4):
    widths = [5, 5] if row % 2 == 0 else [2.5, 5, 2.5]
    left = -5
    for col, width in enumerate(widths):
        cube("Ashlar %d-%d" % (row, col), (left + width / 2, -0.98, 2.72 + row * 2.65),
             (width - 0.065, 0.34, 2.57), STONE_LIGHT if (row + col) % 4 == 0 else STONE, 0.045)
        left += width
cube("Upper stringcourse", (0, 0.35, 12.65), (10, 3.2, 0.7), EDGE)

module("SF_Pier_21")
cube("Pier body", (0, 0.5, 10), (5, 4.4, 20), STONE, collision=True)
cube("Pier shoe", (0, 0.35, 0.8), (5.6, 5, 1.6), BASE, collision=True)
cube("Pier recessed panel", (0, -1.76, 10), (3.5, 0.16, 16), BASE)
cube("Pier raised inner stone", (0, -1.86, 10), (2.9, 0.12, 15.3), STONE_LIGHT)
for z in [5, 10, 15]:
    cube("Pier seam", (0, -1.95, z), (2.8, 0.03, 0.07), BASE, 0)
cube("Pier crown", (0, 0.35, 20.3), (6, 5.3, 0.6), EDGE, collision=True)
snow_cap("Pier snow", (0, 0.35, 20.6), (6.15, 5.45, 0.45))

module("SF_Parapet_10")
cube("Parapet wall", (0, 0.5, 1.45), (10, 2.8, 2.9), STONE, collision=True)
cube("Parapet face", (0, -0.98, 1.4), (9.8, 0.22, 1.9), STONE_LIGHT)
for x in [-2.5, 2.5]:
    cube("Parapet joint", (x, -1.11, 1.4), (0.055, 0.04, 1.85), BASE, 0)
cube("Parapet coping", (0, 0.5, 3.1), (10, 3.4, 0.4), EDGE, collision=True)
snow_cap("Parapet snow", (0, 0.5, 3.3), (10, 3.55, 0.35))

module("SF_InteriorBay_20")
for side in [-1, 1]:
    cube("Interior column", (side * 11, 0, 6.5), (2, 2.4, 13), BASE, collision=True)
    cube("Column facing", (side * 11, -1.26, 6.5), (1.55, 0.2, 11.4), STEEL)
    cube("Column foot", (side * 11, 0, 0.4), (2.6, 2.9, 0.8), EDGE)
    lamp(side * 11, -1.43, 8)
cube("Ceiling beam", (0, 0, 13.35), (24, 2.4, 0.7), STEEL, collision=True)

module("SF_Floor_10")
cube("Floor slab", (0, 0, -0.5), (10, 10, 1), FLOOR, 0.035, collision=True)
for x in [-4.6, 4.6]:
    for y in [-4.6, 4.6]:
        cube("Floor corner inset", (x, y, 0.01), (0.28, 0.28, 0.02), STEEL, 0.02)

module("SF_Cover_8")
cube("Cover core", (0, 0, 1.7), (8, 3, 3.4), STONE, 0.16, collision=True)
cube("Cover foundation", (0, 0, 0.3), (8.4, 3.4, 0.6), BASE, 0.1)
for x in [-3.2, 3.2]:
    cube("Cover steel end", (x, -1.55, 1.6), (0.65, 0.18, 2.4), STEEL)
cube("Cover coping", (0, 0, 3.5), (8.3, 3.3, 0.2), EDGE)
snow_cap("Cover snow", (0, 0, 3.6), (8.4, 3.4, 0.36))


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


# Keep editable source component collections, hide them after generating exports.
export_collection = bpy.data.collections.new("EXPORTS / local origins")
scene.collection.children.link(export_collection)
# Authoring modules overlap at their local origins. Exclude every source from
# bake rays before baking any export, otherwise coincident surfaces contaminate it.
for source_collection in modules.values():
    source_collection.hide_render = True
exports, manifest = {}, {"version": 1, "unit": "stud", "axes": "X lateral, Y inward, Z up", "modules": {}}
for name, collection in modules.items():
    print("PREPARE", name, flush=True)
    objects = []
    for source in collection.objects:
        obj = source.copy()
        obj.data = source.data.copy()
        export_collection.objects.link(obj)
        objects.append(obj)
    select_only(objects)
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.calc_loop_triangles()
    triangle_count = len(obj.data.loop_triangles)
    assert triangle_count < 10000, (name, triangle_count)
    # Each module gets a unique UV atlas; engine materials do not depend on Blender nodes.
    original_slots = list(obj.data.materials)
    cloned_slots = []
    for i, mat in enumerate(original_slots):
        copied = mat.copy()
        obj.data.materials[i] = copied
        cloned_slots.append(copied)
    baked = {}
    scene.cycles.samples = 1
    scene.render.bake.margin = 12
    for channel, bake_type in [("Color", "DIFFUSE"), ("Normal", "NORMAL"), ("Roughness", "ROUGHNESS")]:
        print("BAKE", name, channel, flush=True)
        image = bpy.data.images.new(name + "_" + channel, width=1024, height=1024, alpha=False)
        if channel != "Color":
            image.colorspace_settings.name = "Non-Color"
        for mat in cloned_slots:
            nodes = mat.node_tree.nodes
            tex = nodes.new("ShaderNodeTexImage")
            tex.image = image
            nodes.active = tex
        bpy.ops.object.bake(type=bake_type, pass_filter={"COLOR"} if channel == "Color" else set())
        image.filepath_raw = str(OUT / "textures" / (name + "_" + channel + ".png"))
        image.file_format = "PNG"
        image.save()
        baked[channel] = image
    # Metallic is baked via emission so it remains a scalar texture in Studio.
    image = bpy.data.images.new(name + "_Metalness", width=1024, height=1024, alpha=False)
    image.colorspace_settings.name = "Non-Color"
    for mat in cloned_slots:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        p = nodes.get("Principled BSDF")
        metallic = p.inputs["Metallic"].default_value
        output = nodes.get("Material Output")
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs[0].default_value = (metallic, metallic, metallic, 1)
        links.new(emission.outputs[0], output.inputs["Surface"])
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        nodes.active = tex
    bpy.ops.object.bake(type="EMIT")
    image.filepath_raw = str(OUT / "textures" / (name + "_Metalness.png"))
    image.file_format = "PNG"
    image.save()
    baked["Metalness"] = image
    mat = bpy.data.materials.new(name + "_PBR")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = nodes.get("Principled BSDF")
    for channel, socket in [("Color", "Base Color"), ("Roughness", "Roughness"), ("Metalness", "Metallic"), ("Normal", "Normal")]:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = baked[channel]
        if channel == "Normal":
            normal = nodes.new("ShaderNodeNormalMap")
            links.new(tex.outputs["Color"], normal.inputs["Color"])
            links.new(normal.outputs["Normal"], p.inputs[socket])
        else:
            links.new(tex.outputs["Color"], p.inputs[socket])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    exports[name] = obj
    minimum = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    maximum = [max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    manifest["modules"][name] = {"triangles": triangle_count, "boundsMin": minimum, "boundsMax": maximum,
        "origin": [0, 0, 0], "collisionBoxes": collisions[name], "textureResolution": 1024,
        "textures": {key: "textures/" + Path(img.filepath_raw).name for key, img in baked.items()}}
    select_only([obj])
    bpy.ops.export_scene.fbx(filepath=str(OUT / "exports" / (name + ".fbx")), use_selection=True,
        axis_forward="Z", axis_up="Y", apply_scale_options="FBX_SCALE_UNITS", global_scale=1,
        bake_anim=False, add_leaf_bones=False, object_types={"MESH"}, path_mode="COPY", embed_textures=True)
    # glTF is also supplied for PBR transport; import unit must explicitly be Stud.
    bpy.ops.export_scene.gltf(filepath=str(OUT / "exports" / (name + ".glb")), use_selection=True,
        export_format="GLB", export_yup=True, export_texcoords=True, export_normals=True)
    obj.hide_render = True
    obj.hide_set(True)
    collection.hide_render = True
    collection.hide_viewport = True

(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

stage = bpy.data.collections.new("REVIEW ONLY / assembly and scale references")
scene.collection.children.link(stage)
current = stage
placements = []


def instance(name, location):
    obj = exports[name].copy()
    obj.data = exports[name].data
    stage.objects.link(obj)
    obj.location = location
    obj.hide_render = False
    obj.hide_set(False)
    placements.append({"module": name, "position": list(location)})
    return obj


instance("SF_Portal_20", (0, 0, 0))
for side in [-1, 1]:
    instance("SF_WallBay_10", (side * 19, 0, 0))
    instance("SF_Parapet_10", (side * 19, 0, 14))
    instance("SF_Pier_21", (side * 26, 0, 0))
    # Short returns ground the building rather than leaving a freestanding facade.
    for y in [7, 17]:
        obj = instance("SF_WallBay_10", (side * 26, y, 0))
        obj.rotation_euler.z = math.pi / 2
        placements[-1]["rotationZ"] = math.pi / 2
        obj = instance("SF_Parapet_10", (side * 26, y, 14))
        obj.rotation_euler.z = math.pi / 2
        placements[-1]["rotationZ"] = math.pi / 2
    instance("SF_Pier_21", (side * 26, 24, 0))
for y in [8, 20]:
    instance("SF_InteriorBay_20", (0, y, 0))
for x in [-20, -10, 0, 10, 20]:
    for y in [5, 15, 25]:
        instance("SF_Floor_10", (x, y, 0))
        instance("SF_Floor_10", (x, y, 14))
cube("Review foundation", (0, 12, -2.01), (58, 32, 3.98), BASE, 0.08)
cube("Review snow ground", (0, 0, -4.3), (600, 600, 0.6), SNOW, 0)
# Ramp wedge matches the map's 4-stud rise / 20 degree incline, 24-stud width.
run = 4 / math.tan(math.radians(20))
mesh = bpy.data.meshes.new("Reference ramp")
mesh.from_pydata([(-12,-run,-4),(12,-run,-4),(-12,0,-4),(12,0,-4),(-12,0,0),(12,0,0)], [],
    [(0,1,5,4),(0,4,2),(1,3,5),(2,4,5,3),(0,2,3,1)])
mesh.update()
register(bpy.data.objects.new("Reference ramp / not export", mesh), FLOOR)

# A neutral 5-stud mannequin makes the opening scale explicit in review renders.
HUMAN = material("Reference mannequin", (0.11, 0.24, 0.29), texture=False)
for name, pos, size in [("Torso",(6,3,2.9),(1.7,0.8,1.8)),("Head",(6,3,4.5),(1,0.9,1)),
    ("Leg L",(5.55,3,1),(0.7,0.8,2)),("Leg R",(6.45,3,1),(0.7,0.8,2)),
    ("Arm L",(4.95,3,2.8),(0.5,0.65,1.8)),("Arm R",(7.05,3,2.8),(0.5,0.65,1.8))]:
    cube("Scale reference " + name, pos, size, HUMAN, 0.1)


def area(name, loc, energy, color, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = energy, color, "DISK", size
    obj = bpy.data.objects.new(name, data)
    stage.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("Review soft sky", (-30, -35, 55), 75000, (0.78, 0.87, 1), 40, (0, 2, 5))
area("Review sun", (35, -10, 45), 90000, (1, 0.87, 0.69), 14, (0, 0, 0))
for y in [2, 10, 22]:
    area("Warm interior practical", (0, y, 12.5), 1500, (1, 0.67, 0.31), 4, (0, y, 0))
    cube("Review ceiling luminaire", (0, y, 12.96), (3.4, 1.2, 0.08), AMBER, 0.04)

(OUT / "review-assembly.json").write_text(json.dumps({"placements": placements,
    "note": "Review assembly only. Side returns and piers change collision; do not stamp over live map blindly."}, indent=2))
scene.cycles.samples = 32
camera_data = bpy.data.cameras.new("Review camera")
camera = bpy.data.objects.new("Review camera", camera_data)
stage.objects.link(camera)
scene.camera = camera
camera_data.lens = 32
camera_data.clip_end = 1000
sys.path.insert(0, str(Path(__file__).parent))
from render_fortress_review import render_review
render_review(OUT)
print("DONE", json.dumps({k: v["triangles"] for k, v in manifest["modules"].items()}), flush=True)
