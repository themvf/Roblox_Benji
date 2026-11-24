"""Read the joints of a T-posed whole-body model off its mesh for the Tripo Argon pipeline.

    blender -b -noaudio --python tools/blender/measure_joints_argon.py -- <model.glb> <turn> <out.json>

Duplicates measure_joints.py for the Tripo Argon pipeline with two fixes discovered on GoldenOniTripo,
StormStoneTripo and CodeHoodTripo:
1. Torso half-width (`armInner`) is measured by horizontal BVH raycasts from +-X inward across the
   under-arm torso band (with a vertex fallback and a [0.12*H, 0.24*H] sanity bound), instead of
   relying only on mesh vertices in a thin 5% Z band. On a blocky torso whose side walls are large
   triangles with no mid-wall vertices (GoldenOniTripo), vertex-only sampling collapsed `armInner`
   to 0.0193 (the centre lapel seam), which pulled `shoulder` inside the neck and caused `arm_weight`
   to yank the mask's cheeks up through the eye openings.
2. Detects long coat / robe webbing below `crotch` (`skirtWebbing`) so `prepare_avatar_setup_argon.py`
   can cleanly split fused inner-leg coat tails below the hip.
"""
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

src, turn, out = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
obj.data.transform(Matrix.Rotation(math.radians(float(turn)), 4, "Z"))
xs, ys, zs = ([v.co[i] for v in obj.data.vertices] for i in range(3))
obj.data.transform(Matrix.Translation(Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs)))))
pts = [v.co.copy() for v in obj.data.vertices]
H = max(p.z for p in pts)
span = max(abs(p.x) for p in pts)


def median(values):
    values = sorted(values)
    return values[len(values) // 2]


tree = BVHTree.FromPolygons(pts, [tuple(p.vertices) for p in obj.data.polygons])

far = [p for p in pts if abs(p.x) > 0.7 * span]
arm_z = median([p.z for p in far])
mid = [p for p in pts if 0.5 * span < abs(p.x) < 0.65 * span]
radius = (median([p.z for p in mid if p.z > arm_z]) - median([p.z for p in mid if p.z < arm_z])) if mid else 0.07 * H
radius = max(0.05 * H, min(0.1 * H, radius))


def solid_at_centre(z):
    """Rays front to back at the centre line and a little either side: all three hit only where
    the body is closed between the legs. A thin hanging tab or zip pull is narrower than the three."""
    for x in (-0.025 * H, 0.0, 0.025 * H):
        hit = tree.ray_cast(Vector((x, -H, z)), Vector((0, 1, 0)), 2 * H)
        if hit[0] is None:
            return False
    return True


step = 0.005 * H
crotch, z = None, 0.1 * H
while z < 0.6 * H:
    if all(solid_at_centre(z + i * step) for i in range(4)):
        crotch = z
        break
    z += step
crotch = crotch if crotch is not None else 0.35 * H
hip = crotch + 0.025 * H
waist = hip + 0.065 * H
ankle = 0.07 * H
knee = (ankle + hip) / 2

# Measure torso half-width (`arm_inner`) below the arms by horizontal raycasts from +-X inward
# across the BVH surface, so flat/blocky side walls with few vertices still report their true width.
z_low = max(waist, arm_z - radius - 0.12 * H)
z_high = arm_z - radius - 0.015 * H
ray_hits = []
for i in range(9):
    zt = z_low + (z_high - z_low) * (i / 8.0)
    for yt in (-0.03 * H, 0.0, 0.03 * H):
        for s in (-1.0, 1.0):
            # start at 0.36 * span (inside the elbow/forearm, outside the torso) and shoot toward x=0
            start = Vector((s * min(0.36 * span, 0.26 * H), yt, zt))
            hit = tree.ray_cast(start, Vector((-s, 0.0, 0.0)), abs(start.x))
            if hit[0] is not None and abs(hit[0].x) > 0.05 * H:
                ray_hits.append(abs(hit[0].x))

under_verts = [abs(p.x) for p in pts if z_low < p.z < z_high and abs(p.x) < 0.26 * H]
candidates = ray_hits + under_verts
if candidates:
    candidates.sort()
    raw_inner = candidates[int(len(candidates) * 0.92)]
else:
    raw_inner = 0.16 * H
arm_inner = max(0.12 * H, min(0.23 * H, raw_inner))

hand = 0.14 * H
wrist_x = span - hand
shoulder_x = arm_inner + 0.02 * H
elbow_x = (shoulder_x + wrist_x) / 2

# In a T-pose the top of the arms is the base of the neck.
neck = arm_z + radius
hair_cut = neck + 0.62 * (H - neck)
head = sorted(abs(p.x) for p in pts if neck + 0.04 * H < p.z < hair_cut and abs(p.x) < max(arm_inner, 0.15 * H))
head_x = head[int(len(head) * 0.99)] if head else 0.1 * H

marks = {
    "neck": round(neck, 4), "waist": round(waist, 4), "hip": round(hip, 4), "knee": round(knee, 4),
    "ankle": round(ankle, 4), "shoulder": [round(shoulder_x, 4), round(arm_z, 4)],
    "elbow": [round(elbow_x, 4), round(arm_z, 4)], "wrist": [round(wrist_x, 4), round(arm_z, 4)],
    "armRadius": round(radius, 4), "armInner": round(arm_inner, 4), "legOuter": 0,
    "handLength": round(hand, 4), "hairCut": round(hair_cut, 4),
    "crotch": round(crotch, 4),
    "paint": [{"x": [round(-head_x, 4), round(head_x, 4)], "y": [0.0, round(0.25 * H, 4)],
               "z": [round(neck + 0.025 * H, 4), round(hair_cut, 4)], "color": "hair"}],
}
measured = {"height": round(H, 4), "span": round(span, 4), "crotch": round(crotch, 4), "marks": marks,
            "pipeline": "tripo-argon"}
with open(out, "w") as f:
    json.dump(measured, f, indent=1)
print("JOINTS_ARGON", json.dumps(measured))

# a front render with the marks drawn on, for the audit
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 8
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[1].default_value = 1.2
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
size = max(H, 2 * span) * 1.1
cam.data.ortho_scale = size
cam.location = (0, -20, H / 2)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.render.resolution_x = scene.render.resolution_y = 1000


def line(name, a, b, colour):
    me = bpy.data.meshes.new(name)
    t = 0.004 * H
    d = (Vector(b) - Vector(a))
    side = Vector((0, 0, t)) if abs(d.x) > abs(d.z) else Vector((t, 0, 0))
    me.from_pydata([Vector(a) - side + Vector((0, -0.5, 0)), Vector(b) - side + Vector((0, -0.5, 0)),
                    Vector(b) + side + Vector((0, -0.5, 0)), Vector(a) + side + Vector((0, -0.5, 0))], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*colour, 1)
    emit.inputs["Strength"].default_value = 3
    nt.links.new(emit.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    me.materials.append(mat)


w = size / 2
for name in ("neck", "waist", "hip", "knee", "ankle", "hairCut"):
    line(name, (-w, 0, marks[name]), (w, 0, marks[name]), (1, 0.85, 0))
for s in (1, -1):
    line(f"arm{s}", (s * shoulder_x, 0, arm_z), (s * span, 0, arm_z), (0, 0.9, 1))
    for key in ("shoulder", "elbow", "wrist"):
        x = s * marks[key][0]
        line(f"{key}{s}", (x, 0, arm_z - radius), (x, 0, arm_z + radius), (1, 0.2, 0.2))
    line(f"inner{s}", (s * arm_inner, 0, 0), (s * arm_inner, 0, H), (0.3, 1, 0.3))
scene.render.filepath = out.replace(".json", "-front.png")
bpy.ops.render.render(write_still=True)
