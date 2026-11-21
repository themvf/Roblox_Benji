"""Build the reference-led transparent blue lobby containment canister."""

from pathlib import Path
import math
import random

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/lobby-containment-canister"
SOURCE = PKG / "source/trellis-original.glb"
BLEND = PKG / "source/LobbyContainmentCanister.blend"
EXPORT = PKG / "exports/LobbyContainmentCanister.glb"
TEXTURES = PKG / "textures"
TEXTURES.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source = next(ob for ob in bpy.context.scene.objects if ob.type == "MESH")
assert len([ob for ob in bpy.context.scene.objects if ob.type == "MESH"]) == 1

# Keep detailed source end caps and discard the opaque printed chamber.
bpy.context.view_layer.objects.active = source
mod = source.modifiers.new("25 percent tested cap retention", "DECIMATE")
mod.ratio = .25
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
mesh = source.data
assert 70_000 < len(mesh.polygons) < 75_000
world = [source.matrix_world @ vertex.co for vertex in mesh.vertices]
lo = Vector(tuple(min(p[i] for p in world) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in world) for i in range(3)))
scale = 8 / (hi.z - lo.z)
cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
points = [((p.x-cx)*scale, (p.y-cy)*scale, (p.z-lo.z)*scale) for p in world]
uv = mesh.uv_layers.active
assert uv is not None
cap_material = mesh.materials[0]

images = {im.name: im for im in bpy.data.images if im.size[0] > 0}
assert set(images) == {"Image_0", "Image_1"}, list(images)
for key, name in (("Image_0", "LobbyContainmentCanister_Color.png"),
                  ("Image_1", "LobbyContainmentCanister_MetalRough.png")):
    im = images[key]
    im.scale(1024, 1024)
    im.filepath_raw = str(TEXTURES / name)
    im.file_format = "PNG"
    im.save()

parts = []
cap_faces = []
for poly in mesh.polygons:
    z = sum(points[mesh.loops[i].vertex_index][2] for i in poly.loop_indices) / len(poly.loop_indices)
    if z < .94 or z > 7.04:
        cap_faces.append(poly)

def split_source_faces(faces, limit=9000):
    for offset in range(0, len(faces), limit):
        batch = faces[offset:offset+limit]
        vertices, polygons, uv_faces, smooth = [], [], [], []
        index = {}
        for poly in batch:
            face, coords = [], []
            for loop_index in poly.loop_indices:
                original = mesh.loops[loop_index].vertex_index
                tex = uv.data[loop_index].uv
                key = (original, round(tex.x, 6), round(tex.y, 6))
                if key not in index:
                    index[key] = len(vertices)
                    vertices.append(points[original])
                face.append(index[key])
                coords.append((tex.x, tex.y))
            polygons.append(face)
            uv_faces.append(coords)
            smooth.append(poly.use_smooth)
        out = bpy.data.meshes.new("Preserved cap geometry")
        out.from_pydata(vertices, [], polygons)
        out.update()
        out.materials.append(cap_material)
        layer = out.uv_layers.new(name="UVMap")
        for fi, (poly, coords) in enumerate(zip(out.polygons, uv_faces)):
            poly.use_smooth = smooth[fi]
            for li, tex in zip(poly.loop_indices, coords):
                layer.data[li].uv = tex
        ob = bpy.data.objects.new(f"Canister_Cap_{offset//limit+1:02}", out)
        bpy.context.scene.collection.objects.link(ob)
        parts.append(ob)

split_source_faces(cap_faces)
bpy.data.objects.remove(source, do_unlink=True)

def material(name, color, roughness=.2, metallic=0, alpha=1, emission=None, strength=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1:
        mat.surface_render_method = "BLENDED"
    return mat

glass = material("Chamber_Glass", (.06, .20, .31), .08, .12, .28)
interior = material("Chamber_Dark_Interior", (.008, .028, .055), .82, 0, .53)
interior.use_backface_culling = True
metal = material("Blue_Black_Seals", (.025, .065, .09), .2, .82)
cyan = material("Energy_Cyan", (.04, .72, 1), .18, 0, .78, (.03, .65, 1), 4)
bright = material("Energy_White_Blue", (.28, .88, 1), .13, 0, .92, (.22, .86, 1), 7)
faint = material("Energy_Mist", (.08, .52, .9), .3, 0, .28, (.02, .33, .75), 2)
vapor = material("Energy_Blue_Vapor", (.08, .48, .88), .38, 0, .18, (.04, .38, .82), 2.4)
highlight = material("Glass_Reflection", (.5, .91, 1), .08, 0, .18)
plume_image = bpy.data.images.load(str(TEXTURES / "LobbyContainmentCanister_Energy.png"))
plume_mat = bpy.data.materials.new("Energy_Textured_Plume")
plume_mat.use_nodes = True
plume_mat.surface_render_method = "BLENDED"
plume_nodes = plume_mat.node_tree.nodes
plume_bsdf = plume_nodes.get("Principled BSDF")
plume_bsdf.inputs["Roughness"].default_value = .5
plume_bsdf.inputs["Metallic"].default_value = 0
plume_bsdf.inputs["Emission Strength"].default_value = 1.2
tex = plume_nodes.new("ShaderNodeTexImage")
tex.image = plume_image
plume_mat.node_tree.links.new(tex.outputs["Color"], plume_bsdf.inputs["Base Color"])
plume_mat.node_tree.links.new(tex.outputs["Color"], plume_bsdf.inputs["Emission Color"])
plume_mat.node_tree.links.new(tex.outputs["Alpha"], plume_bsdf.inputs["Alpha"])

# A separate clear shell makes the lower energy visible from every angle.
verts, faces = [], []
ring_z = [.85, .92, 1.04, 1.2, 2, 3, 4, 5, 6, 6.8, 6.96, 7.08]
for z in ring_z:
    radius = 2.055 if 1.05 < z < 6.95 else 2.09
    for k in range(96):
        a = 2*math.pi*k/96
        verts.append((radius*math.cos(a), radius*math.sin(a), z))
for j in range(len(ring_z)-1):
    for k in range(96):
        a, b = j*96+k, j*96+(k+1)%96
        faces.append((a,b,b+96,a+96))
shell_mesh = bpy.data.meshes.new("Clear chamber shell")
shell_mesh.from_pydata(verts, [], faces)
shell_mesh.update()
shell_mesh.materials.append(glass)
for face in shell_mesh.polygons:
    face.use_smooth = True
shell = bpy.data.objects.new("Canister_Glass_Chamber", shell_mesh)
bpy.context.scene.collection.objects.link(shell)
parts.append(shell)

# An inward-facing dark liner is visible on the far side from each viewpoint,
# while the front side is culled so it does not cover the energy.
inner_vertices, inner_faces = [], []
for z in (1.02, 6.98):
    for k in range(96):
        a = 2*math.pi*k/96
        inner_vertices.append((1.99*math.cos(a), 1.99*math.sin(a), z))
for k in range(96):
    a, b = k, (k+1)%96
    inner_faces.append((a,a+96,b+96,b))
inner_mesh = bpy.data.meshes.new("Dark far-side lining")
inner_mesh.from_pydata(inner_vertices, [], inner_faces)
inner_mesh.update()
inner_mesh.materials.append(interior)
liner = bpy.data.objects.new("Canister_Dark_Interior", inner_mesh)
bpy.context.scene.collection.objects.link(liner)
parts.append(liner)

def torus(name, radius, tube, z, mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=8,
                                    location=(0,0,z), major_radius=radius, minor_radius=tube)
    ob = bpy.context.object
    ob.name = name
    ob.data.materials.append(mat)
    for face in ob.data.polygons:
        face.use_smooth = True
    parts.append(ob)

for z in (.88, 7.04):
    torus("Canister_Dark_Seal", 2.1, .08, z, metal)
for z in (1.03, 6.96):
    torus("Canister_Cyan_Light_Ring", 2.06, .035, z, cyan)

def make_curve(name, positions, depth, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = depth
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(positions)-1)
    for p, xyz in zip(spline.points, positions):
        p.co = (*xyz, 1)
    ob = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.object
    ob.data.materials.append(mat)
    return ob

rng = random.Random(205221)
energy_groups = {"Energy_Bright_Wisps": [], "Energy_Cyan_Wisps": [], "Energy_Faint_Wisps": []}
for i in range(9):
    group = ("Energy_Bright_Wisps" if i < 3 else
             "Energy_Cyan_Wisps" if i < 6 else "Energy_Faint_Wisps")
    mat = bright if i < 3 else cyan if i < 6 else faint
    angle = rng.uniform(0, 2*math.pi)
    phase = rng.uniform(0, 2*math.pi)
    radius = rng.uniform(.28, 1.63)
    start = rng.uniform(1.10, 1.75)
    rise = rng.uniform(.9, 2.35) if i < 6 else rng.uniform(1.7, 3.9)
    positions = []
    for step in range(27):
        t = step/26
        a = angle + 1.5*t + .22*math.sin(t*13+phase)
        r = radius*(1-.22*t) + .22*math.sin(t*10+phase)
        z = start + rise*t + .18*math.sin(t*12+phase)*(1-t)
        positions.append((r*math.cos(a), r*math.sin(a), z))
    ob = make_curve(f"{group}_{i:02}", positions, rng.uniform(.012,.035), mat)
    energy_groups[group].append(ob)

for name, group in energy_groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in group:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    bpy.ops.object.join()
    group[0].name = name
    parts.append(group[0])

# Broad tapered ribbons make a soft, asymmetric plasma cloud around the
# sharper strands. Double-sided faces keep them visible around the chamber.
vapor_vertices, vapor_faces = [], []
for i in range(65):
    angle = rng.uniform(0, 2*math.pi)
    radius = rng.uniform(.16, 1.62)
    start = rng.uniform(1.0, 1.7)
    height = rng.uniform(.8, 2.8)
    width = rng.uniform(.15, .48)
    twist = rng.uniform(-1.8, 1.8)
    phase = rng.uniform(0, 2*math.pi)
    first = len(vapor_vertices)
    for j in range(19):
        t = j/18
        a = angle + twist*t + .24*math.sin(t*8+phase)
        r = radius + .22*math.sin(t*9+phase)
        center = Vector((r*math.cos(a), r*math.sin(a), start+height*t))
        tangent = Vector((-math.sin(a), math.cos(a), 0))
        span = width*(.18+.82*math.sin(math.pi*t)**.7)
        for side in (-1, 1):
            vapor_vertices.append(tuple(center+tangent*side*span))
    for j in range(18):
        a, b = first+j*2, first+(j+1)*2
        vapor_faces.extend(((a,a+1,b+1,b),(b,b+1,a+1,a)))
vapor_mesh = bpy.data.meshes.new("Layered blue vapor")
vapor_mesh.from_pydata(vapor_vertices, [], vapor_faces)
vapor_mesh.update()
vapor_mesh.materials.append(vapor)
vapor_ob = bpy.data.objects.new("Energy_Layered_Vapor", vapor_mesh)
bpy.context.scene.collection.objects.link(vapor_ob)
parts.append(vapor_ob)

# Three crossed alpha planes give the diffuse plasma volume a silhouette from
# all lobby viewpoints. The source image is generated for this asset and saved
# beside the export; their geometry is separate from the transparent glass.
for index, angle in enumerate((0, math.pi/3, 2*math.pi/3), start=1):
    ca, sa = math.cos(angle), math.sin(angle)
    xyz = []
    for x, z in ((-1.7, 1.08), (1.7, 1.08), (1.7, 6.25), (-1.7, 6.25)):
        xyz.append((x*ca, x*sa, z))
    plane = bpy.data.meshes.new("Energy volume plane")
    plane.from_pydata(xyz, [], [(0,1,2,3), (3,2,1,0)])
    plane.update()
    plane.materials.append(plume_mat)
    layer = plane.uv_layers.new(name="UVMap")
    for poly in plane.polygons:
        for li, texcoord in zip(poly.loop_indices, ((0,0),(1,0),(1,1),(0,1))):
            layer.data[li].uv = texcoord
    ob = bpy.data.objects.new(f"Energy_Textured_Plume_{index:02}", plane)
    bpy.context.scene.collection.objects.link(ob)
    parts.append(ob)

bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=16, location=(0,0,1.12))
pool = bpy.context.object
pool.name = "Energy_Luminous_Base"
pool.scale = (1.73,1.73,.22)
pool.data.materials.append(faint)
parts.append(pool)

for idx, a in enumerate((.12, 1.62, 3.34, 4.78), start=1):
    positions = []
    for step in range(16):
        t = step/15
        angle = a + .045*math.sin(t*math.pi*2)
        positions.append((2.105*math.cos(angle), 2.105*math.sin(angle), 1.15+5.7*t))
    parts.append(make_curve(f"Glass_Reflection_{idx}", positions, .014, highlight))

def join_group(prefix, name):
    group = [ob for ob in parts if ob.name.startswith(prefix)]
    assert len(group) > 1, (prefix, len(group))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in group:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    bpy.ops.object.join()
    combined = bpy.context.object
    combined.name = name
    for ob in group:
        if ob in parts:
            parts.remove(ob)
    parts.append(combined)

join_group("Canister_Dark_Seal", "Canister_Dark_Seals")
join_group("Canister_Cyan_Light_Ring", "Canister_Cyan_Light_Rings")
join_group("Energy_Textured_Plume_", "Energy_Textured_Plumes")
join_group("Glass_Reflection_", "Glass_Reflections")

for ob in parts:
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

for image in images.values():
    image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.object.select_all(action="DESELECT")
for ob in parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB",
                          export_image_format="AUTO", use_selection=True,
                          export_yup=True)
print("EXPORTED", EXPORT, len(parts), "meshes", len(cap_faces), "source cap triangles")
