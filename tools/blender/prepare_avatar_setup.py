"""Prepare a whole-body kit model for Roblox Studio's Avatar Setup, fitted to the match body.

    blender -b -noaudio --python tools/blender/prepare_avatar_setup.py -- <spec.json>

Run by `python tools/kit_look.py skinned <Kit>`. The match body (docs/design/kits/MATCH_BODY.md)
is one skeleton for every kit: ankle 0.3, knee 1.5, hip 2.7, waist 3.1, neck 4.7 studs. Avatar
Setup wants (create.roblox.com/docs/avatar-setup/auto-setup-requirements): an upright A- or
T-pose with no limb hiding another from the front, the front facing -Z, a contiguous,
watertight body, and no hair or accessories in it.

A Tripo model is none of that: the Bouncer arrived as 25 overlapping shells (hair, visor,
headset, collar, head, torso, each leg and glove). So:

1. Shells that start above the neck, other than the head, come off as rigid accessories
   (hair; shades and headset), keeping their own texture.
2. Every vertex is fitted to the match body: heights mapped piecewise onto its joint heights,
   arms swung out to an A-pose about the shoulder (blended in, so the armpit stretches rather
   than tears) and carried at the model's own scale.
3. The body shells are fused into one watertight shell (voxel remesh), reduced, unwrapped and
   the original paint baked onto it.
4. Turned to face -Z in glTF/Roblox terms, written as GLB, with a front/side preview. The FBX is
   written from the GLBs by write_fbx.py, which checks its size and front.

spec.json: source, out, turn (-90 for Tripo), marks (as split_whole_body.py: neck, waist, hip,
knee, ankle, shoulder, elbow, wrist, armRadius, armInner, legOuter, handLength, remove),
swing (degrees, 20), voxel (model units, 0.004), faces (target triangles, 12000),
texture (1024), hairMinFaces (the largest above-neck shell counts as hair above this),
minAccessoryFaces (300: smaller above-neck shells are dropped as debris), cage (bake, in voxels),
accessoryFaces (4000), cleanHairFlecks (true), headgearIsHair (false: what is left above the neck joins
the hair, for a character with no headgear). Marks may add hairCut (everything above it is hair)
and paint ([{x, y, z, color}] boxes repainted flat before the bake; color "hair" takes the hair's median).
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

spec = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
OUT = Path(spec["out"])
OUT.mkdir(parents=True, exist_ok=True)
m = spec["marks"]
report = {}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=spec["source"])
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    world = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = world
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
source = bpy.context.object
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
source.data.transform(Matrix.Rotation(math.radians(spec.get("turn", -90)), 4, "Z"))
xs, ys, zs = ([v.co[i] for v in source.data.vertices] for i in range(3))
source.data.transform(Matrix.Translation(Vector((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs)))))

# ---------------------------------------------------------------- 1. shells
bm = bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
for box in m.get("remove", []):  # the Bouncer's zip fin
    doomed = [f for f in bm.faces if all(box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1]
                                        for k in ("x", "y", "z") if k in box)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.faces.ensure_lookup_table()
bm.faces.index_update()
shells, seen = [], set()  # face indices: holding BMFace objects across the walk was unreliable
for f in bm.faces:
    if f.index in seen:
        continue
    stack, shell = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        shell.append(g.index)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    shells.append(shell)
layer = bm.faces.layers.int.new("group")  # 0 body, 1 hair, 2 headgear
faces = bm.faces
above = [s for s in shells if min(v.co.z for i in s for v in faces[i].verts) >= m["neck"]]
hair = max(above, key=len) if above else []
debris = kept_small = 0
model_h = max(v.co.z for v in bm.verts)
for s in above:
    group = 1 if (s is hair and len(s) >= spec.get("hairMinFaces", 1000)) else 2
    # TRELLIS leaves slivers of brow and hair strand around the head as tiny shells; as an
    # accessory they float round the head (the DarkArmour trial's "headgear" was all slivers).
    # A small shell with real area is a real part, not a sliver: Tripo's purple hair lock was 71
    # faces at an area of 66e-4 of the height squared, and dropping it left the brown skin under it
    # showing. TRELLIS slivers measured at most 15e-4 (DarkArmourAuto, BouncerAuto, 2026-11-20).
    # Kept shells sit on the head, so they join the body and the remesh fuses them on.
    if group == 2 and len(s) < spec.get("minAccessoryFaces", 300):
        if sum(faces[i].calc_area() for i in s) >= spec.get("keepShellArea", 30e-4) * model_h ** 2:
            group, kept_small = 0, kept_small + len(s)
        else:
            group, debris = 3, debris + len(s)
    elif group == 2 and spec.get("headgearIsHair"):  # a character with no headgear: split-off hair locks
        group = 1
    for i in s:
        faces[i][layer] = group
report["debrisFacesDropped"] = debris
report["smallShellFacesKept"] = kept_small
# TRELLIS fuses the hair onto the head as one shell, so it cannot be picked by shell. `hairCut`
# (model units) moves everything above that height into the hair; the remesh caps the head under it.
if m.get("hairCut"):
    for f in faces:
        if f[layer] == 0 and f.calc_center_median().z >= m["hairCut"]:
            f[layer] = 1
# `paint` boxes (model units, before the turn to -Z: front is -Y) repaint whatever lies inside
# them a flat colour before the bake. The DarkArmour trial's back of head was painted skin where the
# hair should wrap down to the neck.
def hair_colour():
    """The median colour of the source texture under the hair (faces above hairCut), so a painted
    patch matches the hair instead of standing out as a band."""
    import numpy as np

    uv = bm.loops.layers.uv.active
    samples = []
    for f in faces:
        if f[layer] != 1:
            continue
        mat = source.data.materials[f.material_index]
        tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if mat else None
        if not tex:
            continue
        img = tex.image
        if img.name not in img_px:
            img_px[img.name] = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        px = img_px[img.name]
        for loop in f.loops:
            u, v = loop[uv].uv
            samples.append(px[int((v % 1) * (img.size[1] - 1)), int((u % 1) * (img.size[0] - 1)), :3])
    if not samples:
        return (0.01, 0.01, 0.02)
    # image.pixels holds an sRGB texture's stored (gamma) values; Base Color wants linear
    srgb = np.median(np.array(samples), axis=0)
    return tuple(float(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in srgb)


def face_colour(f):
    """The source texture's sRGB colour at a face's corners, averaged; None if it has no texture."""
    import numpy as np

    uv = bm.loops.layers.uv.active
    mat = source.data.materials[f.material_index] if f.material_index < len(source.data.materials) else None
    tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if mat else None
    if not tex or uv is None:
        return None
    img = tex.image
    if img.name not in img_px:
        img_px[img.name] = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    px = img_px[img.name]
    return np.mean([px[int((l[uv].uv[1] % 1) * (img.size[1] - 1)), int((l[uv].uv[0] % 1) * (img.size[0] - 1)), :3]
                    for l in f.loops], axis=0)


def skin_like(c):
    """Warm, fairly bright: the skin TRELLIS paints where hair should be. Dark hair, armour and purple
    glow all fail it, so a paint box no longer flattens real hair texture into one colour (the
    Tripo DarkArmour's back of head, which Tripo had painted as hair, came out a flat dark block)."""
    return c is not None and c[0] > 0.35 and c[0] > c[1] > c[2] and c[0] - c[2] > 0.12


img_px = {}
# `hairSplit: "colour"` lifts hair that the generator fused onto the head (Meshy) off as its own part, by
# its paint: a flood from the crown through faces that are neither skin nor bright glow. Kept in the
# body, the hair shared the body's triangles and texture and the voxel fuse smoothed away Meshy's strand
# grooves (DarkArmourMeshyStd, 2026-11-21). A height cut (`hairCut`) left a gap line at the hairline on
# Tripo; a colour edge sits where the hair really ends. Below the hairline (`hairLine`, the measured
# hairCut) only dark faces count, high enough to stay off the collar, so the flood cannot walk down the
# scar into the face or onto the armour.
if spec.get("hairSplit") == "colour":
    line = m.get("hairLine") or m["neck"] + 0.6 * (model_h - m["neck"])
    import numpy as np

    def median_colour(fs):
        cs = [c for c in (face_colour(f) for f in fs) if c is not None]
        return np.median(np.array(cs), axis=0) if cs else None

    crown_c = median_colour([f for f in faces if f[layer] == 0 and f.calc_center_median().z > model_h * 0.985])
    # This character's own skin: front-facing faces across the cheeks and nose. A fixed "warm and fairly
    # bright" skin test also matches blond hair, which left SoldierMeshy's hair unsplit (2026-11-22).
    # Front-facing faces on the head's centre line, skin-coloured and clearly unlike the crown (a band
    # of heights tied to the measured hairline sampled SoldierMeshy's collar as grey "skin").
    front_head = [f for f in faces if f[layer] == 0 and f.calc_center_median().z > m["neck"]
                  and f.normal.y < -0.6 and abs(f.calc_center_median().x) < 0.06 * model_h]
    skin_c = None
    if crown_c is not None:
        cands = [c for c in (face_colour(f) for f in front_head)
                 if c is not None and skin_like(c) and float(np.linalg.norm(c - crown_c)) > 0.15]
        skin_c = np.median(np.array(cands), axis=0) if len(cands) >= 20 else None
    crown_lum = float(crown_c.mean()) if crown_c is not None else 0.05
    report["hairCrownColour"] = [round(float(c), 3) for c in crown_c] if crown_c is not None else None
    report["hairSkinColour"] = [round(float(c), 3) for c in skin_c] if skin_c is not None else None
    # Dark hair (DarkArmour): below the hairline only the hair's own darkness counts, so the flood runs down
    # to the nape and stops at the collar by colour; above it any dark, non-skin face (a purple streak) joins.
    # A fixed height floor cut the back of the hair in a sawtooth (DarkArmourMeshyStd, first split).
    # Light hair (blond): a face is hair when it is near the crown's colour and nearer to it than to the skin.
    dark_hair = crown_lum < 0.2
    dark_enough = max(0.06, 2.2 * crown_lum)

    def hairy(f):
        z = f.calc_center_median().z
        if f[layer] != 0 or z < m["neck"]:
            return False
        c = face_colour(f)
        if c is None:
            return False
        if dark_hair:
            if skin_like(c):
                return False
            lum = float(sum(c) / 3)
            return lum < dark_enough if z < line else lum < 0.45
        to_crown = float(np.linalg.norm(c - crown_c))
        to_skin = float(np.linalg.norm(c - skin_c)) if skin_c is not None else 1.0
        return to_crown < 0.35 and to_crown < to_skin

    crown = [f for f in faces if f.calc_center_median().z > model_h * 0.985 and hairy(f)]
    hair_faces, stack = set(f.index for f in crown), list(crown)
    while stack:
        g = stack.pop()
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in hair_faces and hairy(h):
                    hair_faces.add(h.index)
                    stack.append(h)
    for i in hair_faces:
        faces[i][layer] = 1
    report["hairSplitFaces"] = len(hair_faces)
for n, box in enumerate(m.get("paint", [])):
    mat = bpy.data.materials.new(f"Paint{n}")
    mat.use_nodes = True
    colour = hair_colour() if box["color"] == "hair" else tuple(box["color"])
    report[f"paint{n}Colour"] = [round(c, 3) for c in colour]
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
    source.data.materials.append(mat)
    slot = len(source.data.materials) - 1
    inside = [f for f in faces if f[layer] != 3 and all(
        box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1] for k in ("x", "y", "z") if k in box)]
    skin = [f for f in inside if skin_like(face_colour(f))] if box.get("onlySkin", True) else inside
    # The box is for skin painted where hair should be: TRELLIS put skin over most of the back of the
    # head. When skin is only a small share of the box (a Tripo head, whose hair is painted, with the
    # backs of its ears inside the box), there is nothing to fix, and repainting turned the ears dark
    # with orange rims. Area share, so a few big faces count for what they cover.
    area_in = sum(f.calc_area() for f in inside) or 1.0
    share = sum(f.calc_area() for f in skin) / area_in
    report[f"paint{n}SkinShare"] = round(share, 3)
    if share < box.get("minSkinShare", 0.35):
        skin = []
    for f in skin:
        f.material_index = slot
    report[f"paint{n}Faces"] = len(skin)
bm.verts.index_update()
vertex_shell = {}
for n, s in enumerate(shells):
    for i in s:
        for v in faces[i].verts:
            vertex_shell[v.index] = n
report["shells"] = len(shells)
report["accessoryShells"] = len(above)


def srgb_to_linear(c):
    return tuple(float(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


# `hands: "glove"` swaps each generated hand for one built from shapes (step 2b). Its colour is the
# median paint of the hand it replaces, sampled here while the source texture is still attached.
hand_colour = {}
if spec.get("hands") == "glove":
    import numpy as np

    for sign in (1, -1):
        sh = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
        wr = Vector((m["wrist"][0] * sign, 0, m["wrist"][1]))
        axis, reach = (wr - sh).normalized(), (wr - sh).length
        cols = []
        for f in faces:
            c = f.calc_center_median()
            flat = Vector((c.x, 0, c.z))
            if f[layer] == 0 and (flat - sh).dot(axis) > reach and abs(c.x) > abs(wr.x) * 0.9:
                col = face_colour(f)
                if col is not None:
                    cols.append(col)
        # the darker half: a glove's glow lines and highlights are not its colour
        if cols:
            cols = np.array(cols)
            lum = cols.mean(1)
            hand_colour[sign] = srgb_to_linear(np.median(cols[lum <= np.median(lum)], axis=0))
        else:
            hand_colour[sign] = (0.02, 0.02, 0.025)
    report["handColour"] = {str(k): [round(x, 3) for x in v] for k, v in hand_colour.items()}
bm.to_mesh(source.data)
bm.free()

# ---------------------------------------------------------------- 2. fit to the match body
R15 = {"ankle": 0.3, "knee": 1.5, "hip": 2.7, "waist": 3.1, "neck": 4.7}
SHOULDER = 4.55
scale = R15["neck"] / m["neck"]
stops = [(0.0, 0.0)] + sorted((m[k], v) for k, v in R15.items())


def height(z):
    if z >= stops[-1][0]:
        return stops[-1][1] + (z - stops[-1][0]) * scale
    for (z0, r0), (z1, r1) in zip(stops, stops[1:]):
        if z <= z1:
            return r0 + (z - z0) * (r1 - r0) / (z1 - z0)
    return z * scale


def arm_weight(p):
    """0 on the body, rising to 1 along the arm past the shoulder (smoothly, so the armpit
    stretches instead of tearing). Uses the same arm tests as split_whole_body.py."""
    if abs(p.x) < m.get("armInner", 0) or (p.z < m["hip"] and abs(p.x) < m.get("legOuter", 0)):
        return 0.0
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
    wrist = Vector((m["wrist"][0] * sign, 0, m["wrist"][1]))
    axis = (wrist - shoulder).normalized()
    flat = Vector((p.x, 0, p.z))
    t = (flat - shoulder).dot(axis)
    length = (wrist - shoulder).length + m.get("handLength", 0.2)
    if t < -0.03 or t > length or (flat - (shoulder + axis * t)).length > m["armRadius"] * 1.15:
        return 0.0
    k = max(0.0, min(1.0, (t + 0.03) / 0.07))
    return k * k * (3 - 2 * k)


swing = math.radians(spec.get("swing", 20))
weights = [arm_weight(v.co) for v in source.data.vertices]
# A shell that is mostly arm (the Bouncer's gloves are shells of their own) moves whole: vertex
# by vertex, its edges fell outside the arm zone and stayed behind as shards at the hips.
by_shell = {}
for i, w in enumerate(weights):
    by_shell.setdefault(vertex_shell.get(i, -1), []).append(w)
whole_arm = {n for n, ws in by_shell.items() if n >= 0 and sorted(ws)[len(ws) // 2] > 0.5}
for v in source.data.vertices:
    p = v.co.copy()
    w = 1.0 if vertex_shell.get(v.index, -1) in whole_arm else weights[v.index]
    body = Vector((p.x * scale, p.y * scale, height(p.z)))
    if w == 0:
        v.co = body
        continue
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
    # the arm at the model's own scale from the match shoulder, swung out by `swing`
    local = (p - shoulder) * scale
    turned = Matrix.Rotation(-sign * swing, 3, "Y") @ local
    arm = Vector((shoulder.x * scale, 0, SHOULDER)) + turned
    v.co = body.lerp(arm, w)
source.data.update()

# split accessories off into their own objects
def take(group, name):
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    scene.collection.objects.link(obj)
    pb = bmesh.new()
    pb.from_mesh(obj.data)
    lay = pb.faces.layers.int["group"]
    bmesh.ops.delete(pb, geom=[f for f in pb.faces if f[lay] != group], context="FACES")
    pb.to_mesh(obj.data)
    pb.free()
    return obj


body_src = take(0, "BodySource")
accessories = {"Hair": take(1, "Hair"), "Headgear": take(2, "Headgear")}
for name in [n for n, o in accessories.items() if not o.data.polygons]:  # never ship an empty part
    bpy.data.objects.remove(accessories.pop(name))
    report[name + "Triangles"] = 0
bpy.data.objects.remove(source)


# ---------------------------------------------------------------- 2b. hands built from shapes
# Every generator so far made poor hands: TRELLIS mitts, Meshy fingers fused into a block or a pointing
# finger, Tripo claws. A bought kit is seen holding a gun all match, so with `hands: "glove"` each
# generated hand is cut off at the measured wrist and replaced by one chunky stylised glove: a closed
# fist with four finger ends and a thumb across the front (palms down in the T-pose). It plugs into the cuff,
# and the voxel fuse below welds it on; its colour is the median of the hand it replaces.
def add_glove(gb, wrist, u, r, voxel_s):
    """A chunky closed fist from rounded blocks (superellipsoids): one fist block, four finger ends with
    grooves between them, and a thumb across the front. Boxes failed twice: a flat open hand came out of the
    voxel fuse as a thin paddle, and box finger segments as a crude hook with its thumb lost
    (DarkArmourMeshyD, 2026-11-21). Nothing here is thinner than a few voxels, so the fuse keeps it."""
    up = Vector((0, 0, 1))
    up = (up - u * up.dot(u)).normalized()
    front = Vector((0, -1, 0))
    front = (front - u * front.dot(u) - up * front.dot(up)).normalized()
    frame = Matrix((u, front, up)).transposed()  # local x along the fingers, y to the thumb, z back of hand
    W = 2.15 * r  # hand width across the knuckles
    gap = max(3.5 * voxel_s, 0.05 * W)  # the voxel fuse closes anything narrower
    made = []

    def blob(centre, half, n=4.0, rot=None):
        """A rounded box: a sphere pushed out towards its bounding box (exponent n; 2 is a sphere)."""
        vs = bmesh.ops.create_uvsphere(gb, u_segments=24, v_segments=14, radius=1.0)["verts"]
        for v in vs:
            d = v.co
            v.co = Vector(tuple(math.copysign(abs(d[i]) ** (2.0 / n), d[i]) * half[i] for i in range(3)))
        if rot is not None:
            bmesh.ops.rotate(gb, cent=Vector(), matrix=rot, verts=vs)
        bmesh.ops.translate(gb, vec=centre, verts=vs)
        made.extend(vs)

    blob(Vector((-0.2 * W, 0, 0)), (0.3 * W, 0.85 * r, 0.85 * r), 6.0)  # plug, hidden inside the cuff
    blob(Vector((0.4 * W, 0, -0.04 * W)), (0.44 * W, 0.5 * W, 0.4 * W), 4.0)  # the fist
    fw = (W - 3 * gap) / 4
    for i, (reach, tall) in enumerate(((0.7, 0.33), (0.79, 0.37), (0.81, 0.38), (0.78, 0.37))):  # little .. index
        y = -W / 2 + fw / 2 + i * (fw + gap)
        blob(Vector((reach * W, y, -0.06 * W)), (0.17 * W, fw / 2, tall * W), 3.0)  # curled finger, seen end-on
    thumb_rot = Matrix.Rotation(math.radians(-22), 3, "Z")  # angled back across the fingers
    blob(Vector((0.52 * W, 0.44 * W, -0.34 * W)), (0.3 * W, 0.14 * W, 0.14 * W), 3.0, thumb_rot)

    bmesh.ops.transform(gb, matrix=Matrix.Translation(wrist) @ frame.to_4x4(), verts=made)
    return made


def gb_face_colour(gb, f):
    """face_colour for a face of the body bmesh (same materials as the source)."""
    import numpy as np

    uv = gb.loops.layers.uv.active
    mats = body_src.data.materials
    mat = mats[f.material_index] if f.material_index < len(mats) else None
    tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if mat and mat.node_tree else None
    if not tex or uv is None:
        return None
    img = tex.image
    if img.name not in img_px:
        img_px[img.name] = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    px = img_px[img.name]
    return np.mean([px[int((l[uv].uv[1] % 1) * (img.size[1] - 1)), int((l[uv].uv[0] % 1) * (img.size[0] - 1)), :3]
                    for l in f.loops], axis=0)


def linear_to_srgb(c):
    return tuple(x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c)


def tidy_wrist(gb, wrist, u, r, hand_srgb=None):
    """What the cut leaves at the cuff. Meshy's layered outfits keep the hand's skin, the shirt cuff and the
    sleeve lining inside the sleeve; cut at one plane they left ragged stubs, and faces straddling the plane
    left slivers past it, which showed as skin and black shards round every glove (GreySuitMeshy,
    2026-11-23). So: (1) anything inside the sleeve near the cut goes (the glove's plug fills it), (2) loose
    scraps the cut set free go, (3) vertices past the plane are pulled back onto it, so the sleeve ends
    clean."""
    near = lambda p: (p - wrist).length < 3.0 * r

    def where(p):
        d = p - wrist
        t = d.dot(u)
        return t, (d - u * t).length

    # Inside means covered: a face near the cut with more cloth further out along its radius. A fixed radius
    # missed the lab coat's flared cuff, whose lining stood out as black spikes past 0.9r (2026-11-23).
    from mathutils.bvhtree import BVHTree

    gb.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(gb)
    inner = []
    for f in gb.faces:
        c = f.calc_center_median()
        if not near(c):
            continue
        t, d = where(c)
        if not -1.2 * r < t <= 0:
            continue
        if d < 0.9 * r:
            inner.append(f)
            continue
        # dark only: unrestricted, it also took the lab coat's teal cuff band (luma about 0.25; the ring is under 0.2)
        if t > -0.4 * r and f.normal.dot(u) > 0.6 and (lambda c: c is not None and sum(c) / 3 < 0.2)(gb_face_colour(gb, f)):
            # the cuff's own end face, a dark ring facing down the arm at the cut: the fuse turned it into
            # the lab coat's black spikes between cuff and glove (layer map, 2026-11-23)
            inner.append(f)
            continue
        out = (c - wrist) - u * t
        out.normalize()
        hit = tree.ray_cast(c + out * 1e-3 * r, out, 1.0 * r)
        if hit[0] is not None and hit[2] != f.index:
            inner.append(f)
        elif hand_srgb is not None and d < 1.1 * r:
            # the old hand's own wrist between the cuff and the cut: nothing covers it, and its ragged
            # ring came out of the fuse as black spikes round the lab coat's gloves (2026-11-23)
            col = gb_face_colour(gb, f)
            if col is not None and max(abs(col[k] - hand_srgb[k]) for k in range(3)) < 0.1:
                inner.append(f)
    if spec.get("debugWrist"):  # layer map of the wrist zone, before the tidy: t, radius, colour, fate
        rows = {}
        gone = set(inner)
        for f in gb.faces:
            c = f.calc_center_median()
            if not near(c):
                continue
            t, d = where(c)
            if not -2.0 * r < t < 0.5 * r:
                continue
            col = gb_face_colour(gb, f)
            key = (round(t / r * 5) / 5, round(d / r * 5) / 5)
            row = rows.setdefault(key, [0, 0, 0.0])
            row[0] += 1
            row[1] += f in gone
            row[2] += float(sum(col) / 3) if col is not None else 0
        print("WRIST", "r", round(r, 3), "hand", [round(x, 2) for x in hand_srgb])
        for (t, d), (n, g, lum) in sorted(rows.items()):
            print("WRIST t %.1f d %.1f faces %d cut %d lum %.2f" % (t, d, n, g, lum / n))
    bmesh.ops.delete(gb, geom=inner, context="FACES")
    # loose scraps: connected pieces lying wholly in the wrist zone
    seen, loose = set(), []
    for f in gb.faces:
        if f in seen or not near(f.calc_center_median()):
            continue
        stack, piece, inside = [f], [], True
        seen.add(f)
        while stack:
            g = stack.pop()
            piece.append(g)
            if inside and (not near(g.calc_center_median()) or where(g.calc_center_median())[0] < -1.5 * r):
                inside = False
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
            if len(piece) > 4000:
                inside = False
        if inside:
            loose.extend(piece)
    bmesh.ops.delete(gb, geom=loose, context="FACES")
    pulled = 0
    for v in gb.verts:
        if near(v.co):
            t, d = where(v.co)
            if t > 0 and d < 1.6 * r:
                v.co -= u * t
                pulled += 1
    bmesh.ops.delete(gb, geom=[v for v in gb.verts if not v.link_faces], context="VERTS")
    return {"innerFaces": len(inner), "looseFaces": len(loose), "pulledVerts": pulled}


if spec.get("hands") == "glove":
    gb = bmesh.new()
    gb.from_mesh(body_src.data)
    voxel_s = spec.get("voxel", 0.004) * scale
    before = set(gb.faces)
    for sign in (1, -1):
        sh = Vector((m["shoulder"][0] * sign, 0, m["shoulder"][1]))
        wr = Vector((m["wrist"][0] * sign, 0, m["wrist"][1]))
        turn_m = Matrix.Rotation(-sign * swing, 3, "Y")
        u = (turn_m @ (wr - sh)).normalized()
        wrist = Vector((sh.x * scale, 0, SHOULDER)) + turn_m @ ((wr - sh) * scale)
        # the arm's real centre and radius at the wrist, from a thin slab of the fitted mesh
        slab = [v.co for v in gb.verts if abs((v.co - wrist).dot(u)) < 0.04 and (v.co - wrist).length < 1.0]
        if len(slab) >= 8:
            c = sum(slab, Vector()) / len(slab)
            c = c - u * (c - wrist).dot(u)
            dists = sorted(((p - c) - u * (p - c).dot(u)).length for p in slab)
            r = dists[int(len(dists) * 0.8)]
            wrist = c
        else:
            r = m.get("armRadius", 0.1) * scale * 0.6
        doomed = [f for f in gb.faces if (f.calc_center_median() - wrist).dot(u) > 0
                  and abs(f.calc_center_median().x) > abs(wrist.x) * 0.8]
        bmesh.ops.delete(gb, geom=doomed, context="FACES")
        report[f"wristTidy{'R' if sign > 0 else 'L'}"] = tidy_wrist(gb, wrist, u, r, linear_to_srgb(hand_colour[sign]))
        mat = bpy.data.materials.new(f"Glove{'R' if sign > 0 else 'L'}")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*hand_colour[sign], 1)
        body_src.data.materials.append(mat)
        slot = len(body_src.data.materials) - 1
        made_before = set(gb.faces)
        add_glove(gb, wrist, u, r, voxel_s)
        for f in gb.faces:
            if f not in made_before:
                f.material_index = slot
        report[f"glove{'R' if sign > 0 else 'L'}"] = {"wrist": [round(x, 3) for x in wrist], "radius": round(r, 3),
                                                       "handFacesCut": len(doomed)}
    bmesh.ops.recalc_face_normals(gb, faces=[f for f in gb.faces if f not in before])
    gb.to_mesh(body_src.data)
    gb.free()


def fuse_and_bake(src, name, faces, voxel, texture, remesh=True):
    """A closed copy of `src` at `faces` triangles with its paint baked on (emission, so no
    lighting gets in). Thicken first: Tripo's jacket is an open surface, and a voxel remesh of an
    open surface kept only scraps of the Bouncer's torso and upper arms. The simplifier also cannot
    collapse TRELLIS's hair, whose internal fins share edges between three or more faces; the remesh
    removes them."""
    out = src.copy()
    out.data = src.data.copy()
    out.name = name
    scene.collection.objects.link(out)
    bpy.context.view_layer.objects.active = out
    for o in bpy.data.objects:
        o.select_set(o == out)
    if remesh:  # off for split-off hair: keep the generator's sculpt, only thin it to budget
        thick = out.modifiers.new("thicken", "SOLIDIFY")
        thick.thickness = voxel * 2.5
        thick.offset = -1  # inward, so the outside stays where the paint is
        bpy.ops.object.modifier_apply(modifier="thicken")
        fuse = out.modifiers.new("fuse", "REMESH")
        fuse.mode = "VOXEL"
        fuse.voxel_size = voxel
        fuse.adaptivity = 0
        bpy.ops.object.modifier_apply(modifier="fuse")
    remeshed = sum(len(p.vertices) - 2 for p in out.data.polygons)
    reduce = out.modifiers.new("reduce", "DECIMATE")
    reduce.ratio = min(1.0, faces / max(1, remeshed))
    bpy.ops.object.modifier_apply(modifier="reduce")
    # The reduction leaves sliver triangles (areas near 1e-6 square studs), and lone faces float
    # off the surface. Slivers made Blender's heat skinning fail on the whole body (BouncerAuto and
    # the Tripo body) and are a risk for Studio's own skinning. Collapse edges shorter than a
    # quarter voxel, then drop islands of fewer than 50 faces.
    cleaned = bmesh.new()
    cleaned.from_mesh(out.data)
    bmesh.ops.triangulate(cleaned, faces=cleaned.faces[:])
    for _ in range(3):
        bmesh.ops.dissolve_degenerate(cleaned, edges=cleaned.edges[:], dist=voxel * 0.25)
        thin = [e for e in cleaned.edges if e.is_valid and e.calc_length() < voxel * 0.25]
        if not thin:
            break
        bmesh.ops.collapse(cleaned, edges=thin)
    cleaned.faces.ensure_lookup_table()
    seen, islands = set(), []
    for f in cleaned.faces:
        if f.index in seen:
            continue
        stack, island = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(island)
    # 1% of the body for a remeshed part: a 30-vertex chip off the black coat's shoulder passed the old
    # 50-face floor, took the torso's weights and hung in the air when the arm came down (2026-11-23).
    floor = max(50, len(cleaned.faces) // 100) if remesh else 8
    bmesh.ops.delete(cleaned, geom=[f for i in islands if len(i) < floor for f in i], context="FACES")
    bmesh.ops.triangulate(cleaned, faces=cleaned.faces[:])
    bmesh.ops.recalc_face_normals(cleaned, faces=cleaned.faces[:])
    cleaned.to_mesh(out.data)
    cleaned.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    # smart_project left DarkArmourAuto's 12k body using 29% of its 1024 texture (Roblox's cap), so the
    # paint projected from the picture came out mottled. Packing the islands by shape fills far more.
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, shape_method="CONCAVE", margin_method="FRACTION", margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    out.data.materials.clear()

    image = bpy.data.images.new(name + "Color", texture, texture, alpha=False)
    mat = bpy.data.materials.new(name + "Color")
    mat.use_nodes = True
    holder = mat.node_tree.nodes.new("ShaderNodeTexImage")
    holder.image = image
    mat.node_tree.links.new(holder.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    mat.node_tree.nodes.active = holder
    out.data.materials.append(mat)

    for slot in src.material_slots:
        slot.material = slot.material.copy()  # shared with the other parts, which keep their paint
        tree = slot.material.node_tree
        tex = next((n for n in tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
        emit = tree.nodes.new("ShaderNodeEmission")
        sink = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
        if tex:
            tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
        else:  # a flat `paint` colour
            emit.inputs["Color"].default_value = tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        tree.links.new(emit.outputs["Emission"], sink.inputs["Surface"])
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = voxel * spec.get("cage", 3)
    scene.render.bake.max_ray_distance = voxel * spec.get("cage", 3) * 2.7
    scene.render.bake.margin = 6
    for o in bpy.data.objects:
        o.select_set(o in (out, src))
    bpy.context.view_layer.objects.active = out
    bpy.ops.object.bake(type="EMIT")
    if name == "Hair" and spec.get("cleanHairFlecks", True):
        # TRELLIS paints pale flecks and highlights into dark hair; pull pale, grey texels down to
        # the hair's own median colour. Saturated streaks (a purple fringe) are kept.
        import numpy as np

        px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
        rgb = px[:, :3]
        hi, lo = rgb.max(1), rgb.min(1)
        lum = rgb.mean(1)
        sat = (hi - lo) / np.maximum(hi, 1e-4)
        dark = lum < np.percentile(lum, 70)
        pale = (lum > np.percentile(lum, 70) * 1.8) & (sat < 0.35)
        if dark.any() and pale.any():
            rgb[pale] = np.median(rgb[dark], axis=0)
            px[:, :3] = rgb
            image.pixels[:] = px.ravel()
            report["hairFlecksCleaned"] = int(pale.sum())
    image.filepath_raw = str(OUT / f"{name}Color.png")
    image.file_format = "PNG"
    image.save()
    bpy.data.objects.remove(src)
    return out, remeshed


CREASE_VIEWS = 6


def recolour_hidden(obj, image):
    """Repaint the faces nobody can see from outside with the colour of the nearest face that can be seen.
    The voxel fuse closes a layered outfit into one shell, but the gaps between layers (under a jacket
    hem, inside a coat) survive as pockets inside it, and the bake paints their walls near-black. Skinned,
    the layers bend apart and those walls poke through: black patches over the suit, the legs and the
    eyes (GreySuitMeshy 32% of faces hidden, BlackCoatMeshy 21%, 2026-11-22). Deleting them would open
    holes at the pocket mouths, so they are recoloured instead: what pokes through is the outfit's own
    colour. A face is seen when a ray from outside, along one of 64 directions in front of it, reaches it."""
    import numpy as np
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree

    me = obj.data
    pts = [obj.matrix_world @ v.co for v in me.vertices]
    tree = BVHTree.FromPolygons(pts, [tuple(p.vertices) for p in me.polygons])
    span = max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))
    dirs = []
    for i in range(64):  # Fibonacci sphere
        z = 1 - 2 * (i + 0.5) / 64
        r = math.sqrt(1 - z * z)
        a = i * math.pi * (3 - math.sqrt(5))
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    centres = [sum((pts[v] for v in p.vertices), Vector()) / len(p.vertices) for p in me.polygons]
    # A crease between two layers is seen from outside through a narrow slot, from a few directions at
    # most; its walls are baked as dark as a sealed pocket and poke out the same way once the layers bend
    # (GreySuitMeshy's trouser streaks, after sealed pockets alone were recoloured). Faces seen from fewer
    # than CREASE_VIEWS of the 64 directions count as hidden, unless their paint is light.
    seen, views = [], []
    for p, c in zip(me.polygons, centres):
        count = 0
        for d in dirs:
            if d.dot(p.normal) <= 0.05:
                continue
            found = tree.ray_cast(c + d * 2 * span, -d, 4 * span)
            if found[2] == p.index or (found[0] is not None and (found[0] - c).length < 1e-4 * span):
                count += 1
                if count >= CREASE_VIEWS:
                    break
        views.append(count)
        seen.append(count > 0)
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = me.uv_layers.active.data
    luma = np.array([0.3, 0.59, 0.11], dtype=np.float32)

    def colour_at(i):
        loops = me.polygons[i].loop_indices
        x = min(w - 1, max(0, int(sum(uv[li].uv.x for li in loops) / len(loops) * w)))
        y = min(h - 1, max(0, int(sum(uv[li].uv.y for li in loops) / len(loops) * h)))
        return px[y, x, :3].copy()

    for i, n in enumerate(views):
        if 0 < n < CREASE_VIEWS and float(colour_at(i) @ luma) < 0.06:
            seen[i] = False
    hidden = [i for i, s in enumerate(seen) if not s]
    report["creaseFacesRecoloured"] = round(sum(1 for i in hidden if views[i] > 0) / max(1, len(seen)), 3)
    report["hiddenFacesRecoloured"] = round(len(hidden) / max(1, len(seen)), 3)
    if not hidden or len(hidden) == len(seen):
        return
    def uv_of(i):
        return [(uv[li].uv.x * w, uv[li].uv.y * h) for li in me.polygons[i].loop_indices]

    def colour_at(i):
        tri = uv_of(i)
        x = min(w - 1, max(0, int(sum(t[0] for t in tri) / len(tri))))
        y = min(h - 1, max(0, int(sum(t[1] for t in tri) / len(tri))))
        return px[y, x, :3].copy()

    kd = KDTree(len(seen) - len(hidden))
    for i, s in enumerate(seen):
        if s:
            kd.insert(centres[i], i)
    kd.balance()

    def cover_colour(i):
        """The colour of the layer this pocket wall shows through when it pokes out: the first visible face
        along its normal, either way. The plain nearest visible face was often the tie or the beard, and
        the pocket behind the lapel still poked through black (GreySuitMeshy, first try)."""
        c, n = centres[i], me.polygons[i].normal
        best = None
        for d in (n, -n):
            start = c + d * 1e-4 * span
            for _ in range(8):
                found = tree.ray_cast(start, d, 0.25 * span)
                if found[0] is None:
                    break
                if seen[found[2]]:
                    dist = (found[0] - c).length
                    if best is None or dist < best[0]:
                        best = (dist, found[2])
                    break
                start = found[0] + d * 1e-4 * span
        # Thin black trim (a tie, a belt, a beard's edge) is often the nearest thing and still read as a
        # black patch on a grey jacket (GreySuitMeshy, second try: 29% of hidden faces still near-black).
        # Black only wins when most of the surface around is black, as on an all-black outfit.
        around = np.array([colour_at(j) for _, j, _ in kd.find_n(c, 24)])
        lum = around @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
        light = around[lum >= 0.06]
        if best:
            hit = colour_at(best[1])
            if float(hit @ np.array([0.3, 0.59, 0.11])) >= 0.06 or len(light) < len(around) / 3:
                return hit
        if len(light) >= len(around) / 3:
            return np.median(light, axis=0)
        return np.median(around, axis=0)

    ys, xs = np.mgrid[0:h, 0:w]
    for i in hidden:
        fill = cover_colour(i)
        tri = uv_of(i)
        (x0, y0), (x1, y1), (x2, y2) = tri[:3]
        lo_x, hi_x = int(max(0, min(x0, x1, x2) - 2)), int(min(w - 1, max(x0, x1, x2) + 2))
        lo_y, hi_y = int(max(0, min(y0, y1, y2) - 2)), int(min(h - 1, max(y0, y1, y2) + 2))
        if hi_x < lo_x or hi_y < lo_y:
            continue
        gx, gy = xs[lo_y:hi_y + 1, lo_x:hi_x + 1] + 0.5, ys[lo_y:hi_y + 1, lo_x:hi_x + 1] + 0.5
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        a = ((x1 - gx) * (y2 - gy) - (x2 - gx) * (y1 - gy)) / area
        b = ((x2 - gx) * (y0 - gy) - (x0 - gx) * (y2 - gy)) / area
        inside = (a >= -0.15) & (b >= -0.15) & (1 - a - b >= -0.15)  # a little past the edges: no dark seams
        if abs(area) < 8:  # a triangle smaller than a few texels covers no texel centre: paint its box
            inside[:] = True
        px[lo_y:hi_y + 1, lo_x:hi_x + 1, :3][inside] = fill
    image.pixels[:] = px.ravel()
    image.save()


def paint_sheen(obj, sheen):
    """Paint a stylised highlight band into the hair's own texture: where the hair faces up and to the
    front, its colour is screened towards the sheen colour read from the picture. Meshy's
    remove_lighting strips the picture's sheen with the rest of its lighting, and a bought kit reads
    flat without it (DarkArmourMeshyStd, 2026-11-21). Screen keeps the strand grooves darker than the
    strands, so the sculpt still shows through. `sheen`: {colour: sRGB, strength}."""
    import numpy as np

    for p in obj.data.polygons:  # the band follows the normals; flat ones gave it blotchy, faceted edges
        p.use_smooth = True
    # The band is placed from a smoothed copy of the shape (a modifier, removed after the bake; an EMIT bake
    # onto the object's own UVs ignores where its points sit), so it sweeps cleanly like a toon highlight
    # instead of following every bump of the generator's surface.
    soften = obj.modifiers.new("sheenSoften", "SMOOTH")
    soften.factor, soften.iterations = 1.0, 12
    mat = obj.data.materials[0]
    holder = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    base = holder.image
    w, h = base.size
    src = bpy.data.images.new(base.name + "Base", w, h, alpha=False)
    src.pixels.foreach_set(np.array(base.pixels[:], dtype=np.float32))
    tmp = bpy.data.materials.new("SheenBake")
    tmp.use_nodes = True
    t = tmp.node_tree
    t.nodes.clear()
    tex = t.nodes.new("ShaderNodeTexImage")
    tex.image = src
    geo = t.nodes.new("ShaderNodeNewGeometry")
    dot = t.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    # light from above the front (-y); at (0, -0.45, 1) the band covered the whole crown, where the
    # picture's gloss sits on the front sweep with black behind it
    dot.inputs[1].default_value = Vector((0, -0.75, 1)).normalized()
    t.links.new(geo.outputs["Normal"], dot.inputs[0])
    ramp = t.nodes.new("ShaderNodeValToRGB")  # a band, not a cap: strongest on the upper front sweep
    els = ramp.color_ramp.elements
    # a tighter rise reads as gloss; the first, wider band (0.5 -> 0.72) came out as a dull wash
    els[0].position, els[0].color = 0.6, (0, 0, 0, 1)
    els[1].position, els[1].color = 0.74, (1, 1, 1, 1)
    for pos, v in ((0.9, 1.0), (1.0, 0.5)):
        e = els.new(pos)
        e.color = (v, v, v, 1)
    t.links.new(dot.outputs["Value"], ramp.inputs["Fac"])
    gain = t.nodes.new("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = float(sheen.get("strength", 0.8))
    t.links.new(ramp.outputs["Color"], gain.inputs[0])
    mix = t.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "SCREEN"
    t.links.new(gain.outputs["Value"], mix.inputs["Factor"])
    t.links.new(tex.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (*srgb_to_linear(sheen["colour"]), 1)
    emit = t.nodes.new("ShaderNodeEmission")
    t.links.new(mix.outputs[2], emit.inputs["Color"])
    sink = t.nodes.new("ShaderNodeOutputMaterial")
    t.links.new(emit.outputs["Emission"], sink.inputs["Surface"])
    target = t.nodes.new("ShaderNodeTexImage")
    target.image = bpy.data.images.new(base.name + "Sheen", w, h, alpha=False)
    t.nodes.active = target
    obj.data.materials[0] = tmp
    for o in bpy.data.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    scene.render.bake.use_selected_to_active = False
    scene.render.bake.margin = 6
    bpy.ops.object.bake(type="EMIT")
    base.pixels.foreach_set(np.array(target.image.pixels[:], dtype=np.float32))
    base.save()
    obj.data.materials[0] = mat
    obj.modifiers.remove(soften)
    report["hairSheen"] = {"colour": [round(c, 3) for c in sheen["colour"]], "strength": sheen.get("strength", 0.8)}


# ---------------------------------------------------------------- 3. one watertight shell
voxel = spec.get("voxel", 0.004) * scale
body, report["remeshTriangles"] = fuse_and_bake(body_src, "Body", spec.get("faces", 12000), voxel,
                                                spec.get("texture", 1024))
if spec.get("recolourHidden", True):
    recolour_hidden(body, next(n for n in body.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE").image)
# Accessories over budget (TRELLIS's come at the generator's density: the Bouncer's hair was
# 35,000 triangles) get the same treatment at a finer voxel, which keeps spikes and strands.
for name in list(accessories):
    obj = accessories[name]
    limit = spec.get("accessoryFaces", 4000)
    if name == "Hair" and spec.get("hairSplit"):
        # split-off hair: the generator's own sculpt, thinned to budget, on a texture of its own
        obj.name = name + "Source"
        accessories[name], _ = fuse_and_bake(obj, name, spec.get("hairFaces", limit), voxel * 0.6,
                                             spec.get("hairTexture", spec.get("texture", 1024)), remesh=False)
        if spec.get("hairSheen"):
            paint_sheen(accessories[name], spec["hairSheen"])
        continue
    if sum(len(p.vertices) - 2 for p in obj.data.polygons) > limit:
        obj.name = name + "Source"
        accessories[name], _ = fuse_and_bake(obj, name, limit, voxel * 0.6, spec.get("texture", 1024) // 2)

# ---------------------------------------------------------------- 4. face -Z, write, preview
flip = Matrix.Rotation(math.pi, 4, "Z")  # Blender -Y front -> +Y, which glTF and FBX write as -Z
for obj in [body, *accessories.values()]:
    obj.data.transform(flip)
    obj.data.update()

# measurements for the report: height, open edges, shells, triangles, arms clear of the body
pb = bmesh.new()
pb.from_mesh(body.data)
report["bodyTriangles"] = len(pb.faces)
report["bodyOpenEdges"] = sum(e.is_boundary for e in pb.edges)
pb.free()
report["height"] = round(max(v.co.z for v in body.data.vertices), 3)
for name, obj in accessories.items():
    report[name + "Triangles"] = len(obj.data.polygons)

for name, obj in [("Body", body), *accessories.items()]:
    for o in bpy.data.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", use_selection=True,
                              export_yup=True)
# The FBX for Studio is written from these GLBs by tools/blender/write_fbx.py (kit_look.py runs it next),
# which fixes its size and front and reads it back.

# preview: front and side, flat light
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.88, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.4
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(60), 0, math.radians(160))
scene.collection.objects.link(sun)
scene.cycles.samples = 24
scene.render.resolution_x, scene.render.resolution_y = 900, 1000
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 9
scene.collection.objects.link(cam)
scene.camera = cam
for view, location, rotation in (("front", (0, 30, 3.3), (math.pi / 2, 0, math.pi)),
                                 ("side", (30, 0, 3.3), (math.pi / 2, 0, math.pi / 2))):
    cam.location = location
    cam.rotation_euler = rotation
    scene.render.filepath = str(OUT / f"preview-{view}.png")
    bpy.ops.render.render(write_still=True)

(OUT / "prepare.json").write_text(json.dumps(report, indent=1))
print("PREPARED", json.dumps(report))
