"""Read the joints of a T-posed whole-body model off its mesh, in place of reading a grid by eye.

    blender -b -noaudio --python tools/blender/measure_joints.py -- <model.glb> <turn> <out.json>

Writes the marks prepare_avatar_setup.py takes, in the same model units (turned by `turn`,
centred on x and y, feet on z = 0), plus `front.png`: a front render with every mark drawn on
it, which goes on the audit so a wrong guess is seen, not trusted.

How each mark is found, for an upright T-pose (FLUX edit -> TRELLIS):
- arms: the vertices out past 70% of the span are forearms and hands; their median height is the
  arm line and their spread the arm radius.
- torso half width (armInner): the widest point of the body in a band just under the arms.
- hand length: 14% of the height (both trials measured 14-15% by hand); wrist and elbow follow.
- crotch: scanning up from the feet, the first height where rays front to back hit the body at
  the centre line and a little either side (a thin zip tab or strap does not count).
  Hip sits 2.5% of the height above it, waist 6.5% above the hip (both trials, by hand).
- ankle 7% of the height; knee halfway from ankle to hip (the match body's own proportion).
- neck: the top of the arms (in a T-pose that is the base of the neck).
- hairCut: 62% of the way from neck to top, above brows and visors on both trials.
- paint: the back half of the head, from just above the neck up to the hair cut, in the hair's
  own colour, in case the generator painted skin where the hair should wrap. Harmless when the
  back of the head is already hair.
"""
import json
import math
import sys

import bpy
from mathutils import Matrix, Vector

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


far = [p for p in pts if abs(p.x) > 0.7 * span]
arm_z = median([p.z for p in far])
mid = [p for p in pts if 0.5 * span < abs(p.x) < 0.65 * span]
radius = (median([p.z for p in mid if p.z > arm_z]) - median([p.z for p in mid if p.z < arm_z])) if mid else 0.07 * H
radius = max(0.05 * H, min(0.1 * H, radius))
under = [abs(p.x) for p in pts if arm_z - radius - 0.06 * H < p.z < arm_z - radius - 0.01 * H]
arm_inner = max(under) if under else 0.17 * H
hand = 0.14 * H
wrist_x = span - hand
shoulder_x = arm_inner + 0.02 * H
elbow_x = (shoulder_x + wrist_x) / 2

from mathutils.bvhtree import BVHTree

tree = BVHTree.FromPolygons(pts, [tuple(p.vertices) for p in obj.data.polygons])


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
    # closed for four steps running: a strap across the legs is not the crotch
    if all(solid_at_centre(z + i * step) for i in range(4)):
        crotch = z
        break
    z += step
crotch = crotch if crotch is not None else 0.35 * H
hip = crotch + 0.025 * H
waist = hip + 0.065 * H
ankle = 0.07 * H
knee = (ankle + hip) / 2

# In a T-pose the top of the arms is the base of the neck (both trials: within 0.004 of the hand reading).
neck = arm_z + radius
hair_cut = neck + 0.62 * (H - neck)
# the head proper: above the collar (neck + 4% of the height), at its full half width (99th
# percentile, ignoring stray points). The box starts 2.5% above the neck: lower, it painted the
# collar and upper back; higher, a strip of skin showed above the collar.
head = sorted(abs(p.x) for p in pts if neck + 0.04 * H < p.z < hair_cut and abs(p.x) < arm_inner)
head_x = head[int(len(head) * 0.99)] if head else 0.1 * H

marks = {
    "neck": round(neck, 4), "waist": round(waist, 4), "hip": round(hip, 4), "knee": round(knee, 4),
    "ankle": round(ankle, 4), "shoulder": [round(shoulder_x, 4), round(arm_z, 4)],
    "elbow": [round(elbow_x, 4), round(arm_z, 4)], "wrist": [round(wrist_x, 4), round(arm_z, 4)],
    "armRadius": round(radius, 4), "armInner": round(arm_inner, 4), "legOuter": 0,
    "handLength": round(hand, 4), "hairCut": round(hair_cut, 4),
    "paint": [{"x": [round(-head_x, 4), round(head_x, 4)], "y": [0.0, round(0.25 * H, 4)],
               "z": [round(neck + 0.025 * H, 4), round(hair_cut, 4)], "color": "hair"}],
}
measured = {"height": round(H, 4), "span": round(span, 4), "crotch": round(crotch, 4), "marks": marks}
with open(out, "w") as f:
    json.dump(measured, f, indent=1)
print("JOINTS", json.dumps(measured))

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
