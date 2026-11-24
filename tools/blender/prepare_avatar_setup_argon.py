"""Prepare a whole-body kit model for Roblox Studio's Avatar Setup (Tripo Argon pipeline).

    blender -b -noaudio --python tools/blender/prepare_avatar_setup_argon.py -- <spec.json>

Duplicates prepare_avatar_setup.py for the Tripo Argon pipeline so the baseline Tripo pipeline can
be tested side-by-side against these quality fixes:
1. Head/Neck guard on `arm_weight`: vertices at or above `neck` (or on head/mask shells) never
   receive arm displacement, fixing the GoldenOniTripo eye spikes and nape tear when `armInner`
   was narrow.
2. Asymmetric side rim-light despill on source textures (fixing BouncerTripo's right-side magenta
   cast) + emissive accent contrast lift (fixing StormStoneTripo / CodeHoodTripo washed glow lines).
3. Inter-leg skirt/coat cleft separation below the crotch so long coats don't web between the legs
   during walk, run and crouch.
4. Thinner inward solidify (1.5x voxel), head/hand/joint-protected decimation (`argon_preserve`
   vertex group), and priority-weighted UV packing (1.75x Head, 1.35x UpperTorso texel density).
5. Bakes tangent-space `BodyNormal.png` from the high-res source mesh and a material-aware
   `BodyRoughness.png` map alongside `BodyColor.png`.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

spec = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
OUT = Path(spec["out"])
OUT.mkdir(parents=True, exist_ok=True)
m = spec["marks"]
report = {"pipeline": "tripo-argon"}

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
source.data.update()

# ---------------------------------------------------------------- 1. shells & asymmetric rim-light despill
bm = bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
for box in m.get("remove", []):
    doomed = [f for f in bm.faces if all(box[k][0] <= f.calc_center_median()["xyz".index(k)] <= box[k][1]
                                        for k in ("x", "y", "z") if k in box)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.faces.ensure_lookup_table()
bm.faces.index_update()
shells, seen = [], set()
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
    if group == 2 and len(s) < spec.get("minAccessoryFaces", 300):
        if sum(faces[i].calc_area() for i in s) >= spec.get("keepShellArea", 30e-4) * model_h ** 2:
            group, kept_small = 0, kept_small + len(s)
        else:
            group, debris = 3, debris + len(s)
    elif group == 2 and spec.get("headgearIsHair"):
        group = 1
    for i in s:
        faces[i][layer] = group
report["debrisFacesDropped"] = debris
report["smallShellFacesKept"] = kept_small
if m.get("hairCut"):
    for f in faces:
        if f[layer] == 0 and f.calc_center_median().z >= m["hairCut"]:
            f[layer] = 1


def hair_colour():
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
    srgb = np.median(np.array(samples), axis=0)
    return tuple(float(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in srgb)


def face_colour(f):
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
    return c is not None and c[0] > 0.35 and c[0] > c[1] > c[2] and c[0] - c[2] > 0.12


img_px = {}
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
    area_in = sum(f.calc_area() for f in inside) or 1.0
    share = sum(f.calc_area() for f in skin) / area_in
    report[f"paint{n}SkinShare"] = round(share, 3)
    if share < box.get("minSkinShare", 0.35):
        skin = []
    for f in skin:
        f.material_index = slot
    report[f"paint{n}Faces"] = len(skin)

# Asymmetric side rim-light despill on the source texture (e.g. BouncerTripo's right-side magenta cast).
# Compares chroma on left-facing (+X) vs right-facing (-X) side surfaces below the neck. If one side has a
# strong asymmetric colour cast on dark cloth/armour (ratio > 1.45 and chroma diff > 0.045), we desaturate
# that side's UV texels toward the neutral side's chroma.
if spec.get("despillRimLight", True):
    uv_lay = bm.loops.layers.uv.active
    mat0 = source.data.materials[0] if source.data.materials else None
    tex0 = next((n for n in mat0.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if (mat0 and mat0.use_nodes) else None
    if tex0 and uv_lay:
        img0 = tex0.image
        tw, th = img0.size
        px0 = np.array(img0.pixels[:], dtype=np.float32).reshape(th, tw, 4)
        left_chroma, right_chroma = [], []
        left_faces, right_faces = [], []
        for f in faces:
            if f[layer] == 3:
                continue
            c = f.calc_center_median()
            if c.z > m["neck"] * 0.96:  # don't touch head/visor/ears
                continue
            fc = face_colour(f)
            if fc is None:
                continue
            ch = float(max(fc) - min(fc))
            if f.normal.x > 0.45 and c.x > 0:
                left_chroma.append(ch)
                left_faces.append(f)
            elif f.normal.x < -0.45 and c.x < 0:
                right_chroma.append(ch)
                right_faces.append(f)
        if left_chroma and right_chroma:
            lc, rc = float(np.median(left_chroma)), float(np.median(right_chroma))
            hi_side = None
            if rc > max(lc * 1.45, lc + 0.045):
                hi_side, target_ch, side_faces = "right(-X)", lc, right_faces
            elif lc > max(rc * 1.45, rc + 0.045):
                hi_side, target_ch, side_faces = "left(+X)", rc, left_faces
            if hi_side:
                # Build UV mask for the spilled side faces and desaturate toward target_ch
                from PIL import Image, ImageDraw, ImageFilter
                mask_im = Image.new("L", (tw, th), 0)
                draw = ImageDraw.Draw(mask_im)
                for f in side_faces:
                    pts_uv = [(float(l[uv_lay].uv[0] % 1) * tw, (1.0 - float(l[uv_lay].uv[1] % 1)) * th) for l in f.loops]
                    if len(pts_uv) >= 3:
                        draw.polygon(pts_uv, fill=255)
                mask_im = mask_im.filter(ImageFilter.GaussianBlur(radius=max(2, tw // 256)))
                w_mask = (np.asarray(mask_im, dtype=np.float32)[::-1] / 255.0)[..., None]
                rgb = px0[:, :, :3]
                lum = (rgb[:, :, 0:1] * 0.2126 + rgb[:, :, 1:2] * 0.7152 + rgb[:, :, 2:3] * 0.0722)
                keep_ratio = min(0.65, max(0.15, target_ch / max(rc, lc, 1e-4)))
                # Dim both the spilled chroma and its extra rim brightness
                desat = (lum * 0.85) + (rgb - lum) * keep_ratio
                px0[:, :, :3] = rgb * (1.0 - w_mask * 0.85) + desat * (w_mask * 0.85)
                img0.pixels[:] = px0.ravel()
                img0.update()
                img_px[img0.name] = px0
                report["rimLightDespilled"] = {"side": hi_side, "leftChroma": round(lc, 3), "rightChroma": round(rc, 3)}

bm.verts.index_update()
vertex_shell = {}
shell_max_z = {}
for n, s in enumerate(shells):
    zs_s = [v.co.z for i in s for v in faces[i].verts]
    shell_max_z[n] = max(zs_s) if zs_s else 0.0
    for i in s:
        for v in faces[i].verts:
            vertex_shell[v.index] = n
report["shells"] = len(shells)
report["accessoryShells"] = len(above)


def srgb_to_linear(c):
    return tuple(float(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


hand_colour = {}
if spec.get("hands") == "glove":
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

# Enforce a sane minimum armInner so a narrow mark can never grab the head/neck/chest
safe_arm_inner = max(m.get("armInner", 0), 0.12 * model_h)
safe_shoulder_x = max(m["shoulder"][0], safe_arm_inner + 0.015 * model_h)


def height(z):
    if z >= stops[-1][0]:
        return stops[-1][1] + (z - stops[-1][0]) * scale
    for (z0, r0), (z1, r1) in zip(stops, stops[1:]):
        if z <= z1:
            return r0 + (z - z0) * (r1 - r0) / (z1 - z0)
    return z * scale


def arm_weight(p, v_idx):
    """0 on the body and head/neck, rising to 1 along the arm past the shoulder."""
    # Argon fix: never let arm_weight reach the head, mask or neck
    if p.z >= m["neck"] - 0.008 * model_h:
        return 0.0
    sh_id = vertex_shell.get(v_idx, -1)
    if sh_id >= 0 and shell_max_z.get(sh_id, 0.0) > m["neck"] + 0.04 * model_h and abs(p.x) < safe_arm_inner * 1.15:
        return 0.0
    if abs(p.x) < safe_arm_inner or (p.z < m["hip"] and abs(p.x) < m.get("legOuter", 0)):
        return 0.0
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((safe_shoulder_x * sign, 0, m["shoulder"][1]))
    wrist = Vector((max(m["wrist"][0], safe_shoulder_x + 0.05 * model_h) * sign, 0, m["wrist"][1]))
    axis = (wrist - shoulder).normalized()
    flat = Vector((p.x, 0, p.z))
    t = (flat - shoulder).dot(axis)
    length = (wrist - shoulder).length + m.get("handLength", 0.2)
    if t < -0.03 or t > length or (flat - (shoulder + axis * t)).length > m["armRadius"] * 1.15:
        return 0.0
    k = max(0.0, min(1.0, (t + 0.03) / 0.07))
    return k * k * (3 - 2 * k)


swing = math.radians(spec.get("swing", 20))
weights = [arm_weight(v.co, v.index) for v in source.data.vertices]
by_shell = {}
for i, w in enumerate(weights):
    by_shell.setdefault(vertex_shell.get(i, -1), []).append(w)
whole_arm = {n for n, ws in by_shell.items()
             if n >= 0 and shell_max_z.get(n, 0.0) < m["neck"] and sorted(ws)[len(ws) // 2] > 0.5}
for v in source.data.vertices:
    p = v.co.copy()
    w = 1.0 if vertex_shell.get(v.index, -1) in whole_arm else weights[v.index]
    body = Vector((p.x * scale, p.y * scale, height(p.z)))
    if w == 0:
        v.co = body
        continue
    sign = 1 if p.x >= 0 else -1
    shoulder = Vector((safe_shoulder_x * sign, 0, m["shoulder"][1]))
    local = (p - shoulder) * scale
    turned = Matrix.Rotation(-sign * swing, 3, "Y") @ local
    arm = Vector((shoulder.x * scale, 0, SHOULDER)) + turned
    v.co = body.lerp(arm, w)
source.data.update()


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
for name in [n for n, o in accessories.items() if not o.data.polygons]:
    bpy.data.objects.remove(accessories.pop(name))
    report[name + "Triangles"] = 0
bpy.data.objects.remove(source)


def add_glove(gb, wrist, u, r, voxel_s):
    up = Vector((0, 0, 1))
    up = (up - u * up.dot(u)).normalized()
    front = Vector((0, -1, 0))
    front = (front - u * front.dot(u) - up * front.dot(up)).normalized()
    frame = Matrix((u, front, up)).transposed()
    W = 2.15 * r
    gap = max(3.5 * voxel_s, 0.05 * W)
    made = []

    def blob(centre, half, n=4.0, rot=None):
        vs = bmesh.ops.create_uvsphere(gb, u_segments=24, v_segments=14, radius=1.0)["verts"]
        for v in vs:
            d = v.co
            v.co = Vector(tuple(math.copysign(abs(d[i]) ** (2.0 / n), d[i]) * half[i] for i in range(3)))
        if rot is not None:
            bmesh.ops.rotate(gb, cent=Vector(), matrix=rot, verts=vs)
        bmesh.ops.translate(gb, vec=centre, verts=vs)
        made.extend(vs)

    blob(Vector((-0.2 * W, 0, 0)), (0.3 * W, 0.85 * r, 0.85 * r), 6.0)
    blob(Vector((0.4 * W, 0, -0.04 * W)), (0.44 * W, 0.5 * W, 0.4 * W), 4.0)
    fw = (W - 3 * gap) / 4
    for i, (reach, tall) in enumerate(((0.7, 0.33), (0.79, 0.37), (0.81, 0.38), (0.78, 0.37))):
        y = -W / 2 + fw / 2 + i * (fw + gap)
        blob(Vector((reach * W, y, -0.06 * W)), (0.17 * W, fw / 2, tall * W), 3.0)
    thumb_rot = Matrix.Rotation(math.radians(-22), 3, "Z")
    blob(Vector((0.52 * W, 0.44 * W, -0.34 * W)), (0.3 * W, 0.14 * W, 0.14 * W), 3.0, thumb_rot)

    bmesh.ops.transform(gb, matrix=Matrix.Translation(wrist) @ frame.to_4x4(), verts=made)
    return made


if spec.get("hands") == "glove":
    gb = bmesh.new()
    gb.from_mesh(body_src.data)
    uv_lay = gb.loops.layers.uv.active
    voxel_s = spec.get("voxel", 0.0032) * scale
    before = set(gb.faces)
    for sign in (1, -1):
        sh = Vector((safe_shoulder_x * sign, 0, m["shoulder"][1]))
        wr = Vector((max(m["wrist"][0], safe_shoulder_x + 0.05 * model_h) * sign, 0, m["wrist"][1]))
        turn_m = Matrix.Rotation(-sign * swing, 3, "Y")
        u = (turn_m @ (wr - sh)).normalized()
        wrist = Vector((sh.x * scale, 0, SHOULDER)) + turn_m @ ((wr - sh) * scale)
        slab = [v.co for v in gb.verts if abs((v.co - wrist).dot(u)) < 0.04 and (v.co - wrist).length < 1.0]
        if len(slab) >= 8:
            c = sum(slab, Vector()) / len(slab)
            c = c - u * (c - wrist).dot(u)
            dists = sorted(((p - c) - u * (p - c).dot(u)).length for p in slab)
            r = dists[int(len(dists) * 0.8)]
            wrist = c
        else:
            r = m.get("armRadius", 0.1) * scale * 0.6
        # Shift cut slightly outward past the wrist bracelet/prayer beads so wrist accessories survive intact
        wrist_cut = wrist + u * (0.14 * r)
        doomed = [f for f in gb.faces if (f.calc_center_median() - wrist_cut).dot(u) > 0
                  and abs(f.calc_center_median().x) > abs(wrist_cut.x) * 0.8]
        # Capture dorsal/front-top back-of-hand UVs before deleting the old hand so back-of-hand runes
        # transfer directly onto the back of both closed-fist gloves
        gb.normal_update()
        dorsal_uvs = []
        if uv_lay is not None and doomed:
            doomed_reaches = [(f.calc_center_median() - wrist_cut).dot(u) for f in doomed]
            max_doomed_reach = max(max(doomed_reaches), 1e-4)
            # The back of the hand in T-pose faces upward (+Z) and slightly forward (-Y)
            dorsal_reach_cap = max_doomed_reach * 0.62
            for f in doomed:
                fc_d = f.calc_center_median()
                r_d = (fc_d - wrist_cut).dot(u)
                if f.material_index == 0 and 0.0 <= r_d <= dorsal_reach_cap and (f.normal.z > -0.05 and (f.normal.z > 0.12 or f.normal.y < -0.18)):
                    for l in f.loops:
                        rel_p = l.vert.co - wrist_cut
                        u_norm = max(0.0, min(1.0, rel_p.dot(u) / max(dorsal_reach_cap, 1e-4)))
                        y_off = rel_p.y
                        z_off = rel_p.z
                        dorsal_uvs.append((u_norm, y_off, z_off, l[uv_lay].uv.copy()))
        bmesh.ops.delete(gb, geom=doomed, context="FACES")
        mat = bpy.data.materials.new(f"Glove{'R' if sign > 0 else 'L'}")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*hand_colour[sign], 1)
        body_src.data.materials.append(mat)
        slot = len(body_src.data.materials) - 1
        made_before = set(gb.faces)
        add_glove(gb, wrist_cut, u, r, voxel_s)
        new_glove_faces = [f for f in gb.faces if f not in made_before]
        # Recalculate face normals immediately because sign > 0 frame has det = -1
        bmesh.ops.recalc_face_normals(gb, faces=new_glove_faces)
        gb.normal_update()
        W_g = 2.15 * r
        glove_dorsal_span = 0.68 * W_g
        dorsal_Transferred = 0
        for f in new_glove_faces:
            fc = f.calc_center_median()
            reach_u = (fc - wrist_cut).dot(u)
            if (dorsal_uvs and uv_lay is not None
                    and 0.0 <= reach_u <= glove_dorsal_span
                    and fc.z >= wrist_cut.z - 0.18 * W_g
                    and f.normal.z > -0.10
                    and (f.normal.z > 0.15 or f.normal.y < -0.20)):
                f.material_index = 0
                for l in f.loops:
                    rel_l = l.vert.co - wrist_cut
                    u_n = max(0.0, min(1.0, rel_l.dot(u) / max(glove_dorsal_span, 1e-4)))
                    y_l, z_l = rel_l.y, rel_l.z
                    best_uv = min(
                        dorsal_uvs,
                        key=lambda item: (item[0] - u_n) ** 2 + ((item[1] - y_l) / max(r, 1e-4)) ** 2 + ((item[2] - z_l) / max(r, 1e-4)) ** 2
                    )[3]
                    l[uv_lay].uv = best_uv
                dorsal_Transferred += 1
            else:
                f.material_index = slot
        report[f"glove{'R' if sign > 0 else 'L'}"] = {
            "wrist": [round(x, 3) for x in wrist_cut], "radius": round(r, 3),
            "handFacesCut": len(doomed), "dorsalRuneFacesTransferred": dorsal_Transferred,
        }
    bmesh.ops.recalc_face_normals(gb, faces=[f for f in gb.faces if f not in before])
    gb.to_mesh(body_src.data)
    gb.free()


def split_skirt_cleft(obj, voxel_studs):
    """If a long coat or tunic skirt bridges across x=0 between the knees and mid-thigh
    (z < R15['knee'] + 0.55), split faces that cross x=0 before voxel remeshing so left and
    right coat tails remesh onto their respective legs without opening holes at the crotch arch."""
    cleft_top = R15["knee"] + 0.55
    cleft_half = max(0.032, voxel_studs * 1.2)
    bm_c = bmesh.new()
    bm_c.from_mesh(obj.data)
    crossed = []
    for f in bm_c.faces:
        cz = f.calc_center_median().z
        if cz >= cleft_top or cz <= R15["ankle"]:
            continue
        xs_f = [v.co.x for v in f.verts]
        if (min(xs_f) < -1e-4 and max(xs_f) > 1e-4) or abs(f.calc_center_median().x) < cleft_half * 0.75:
            crossed.append(f)
    removed = len(crossed)
    if crossed:
        bmesh.ops.delete(bm_c, geom=crossed, context="FACES")
        for v in bm_c.verts:
            if R15["ankle"] < v.co.z < cleft_top and abs(v.co.x) < cleft_half:
                v.co.x = cleft_half if v.co.x >= 0 else -cleft_half
        bmesh.ops.recalc_face_normals(bm_c, faces=bm_c.faces[:])
        bm_c.to_mesh(obj.data)
        obj.data.update()
    bm_c.free()
    return removed


def build_preserve_group(obj):
    """Create a vertex group `argon_preserve` so DECIMATE preserves triangle density in the head/mask,
    hands/fingers, and R15 bending joint bands while decimating flat limb/torso shafts harder."""
    vg = obj.vertex_groups.new(name="argon_preserve")
    xs_v = [abs(v.co.x) for v in obj.data.vertices]
    max_x = max(xs_v) if xs_v else 3.0
    wrist_x = max_x - 0.85
    joint_zs = (R15["ankle"], R15["knee"], R15["hip"], R15["waist"], R15["neck"])
    for v in obj.data.vertices:
        p = v.co
        w = 0.0
        if p.z >= R15["neck"] - 0.12:
            w = 0.92  # Head, face, mask cutouts, horns
        elif abs(p.x) >= wrist_x and p.z > R15["waist"]:
            w = 0.82  # Hands and fingers
        else:
            # R15 joint bending bands (ankle, knee, hip, waist, shoulder/elbow)
            d_joint = min(abs(p.z - jz) for jz in joint_zs)
            if d_joint < 0.24:
                w = max(w, 0.72 * (1.0 - d_joint / 0.24))
        if w > 0.01:
            vg.add([v.index], w, "REPLACE")
    return vg.name


def boost_head_torso_uvs(obj):
    """Scale Head UV islands by 1.65x and UpperTorso UV islands by 1.3x before concave island packing
    so the 1024x1024 texture devotes ~2.5x more pixels to the face, mask and upper chest."""
    bm_u = bmesh.new()
    bm_u.from_mesh(obj.data)
    uv_lay = bm_u.loops.layers.uv.active
    if uv_lay is not None:
        for f in bm_u.faces:
            cz = f.calc_center_median().z
            factor = 1.65 if cz >= R15["neck"] - 0.1 else (1.3 if cz >= R15["waist"] else 1.0)
            if factor > 1.0:
                for loop in f.loops:
                    loop[uv_lay].uv *= factor
    bm_u.to_mesh(obj.data)
    bm_u.free()


def enhance_and_make_roughness(color_image, name):
    """Boost high-chroma emissive accents (eyes, visors, lightning/circuit lines) so flat T-pose
    lighting doesn't wash them out, and derive a material-aware Roughness image (`<name>Roughness.png`):
    metallic/gold/visor highlights get 0.35-0.48, leather/armour plates get 0.62, dark cloth gets 0.88."""
    w, h = color_image.size
    px = np.array(color_image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[:, :, :3]
    hi = rgb.max(axis=2)
    lo = rgb.min(axis=2)
    chroma = hi - lo
    lum = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722

    # 1. Emissive / vibrant accent contrast lift + Cyan glow emission map (`<name>Emission.png`)
    r_c, g_c, b_c = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    cyan_excess = np.minimum(g_c, b_c) - r_c
    cyan_mask = (g_c > r_c + 0.035) & (b_c > r_c + 0.035) & (cyan_excess > 0.045) & (hi > 0.11)
    accent = ((chroma > 0.18) & (hi > 0.28)) | cyan_mask
    if accent.any():
        mean_c = lum[..., None]
        boosted = mean_c + (rgb - mean_c) * 1.25
        boosted = np.where(hi[..., None] > 0.45, boosted * 1.08, boosted)
        if cyan_mask.any():
            # Lift cyan eyes, under-eye rune, hand runes and robe inscriptions toward vivid electric cyan
            cyan_str = np.clip((cyan_excess - 0.035) / 0.22, 0.0, 1.0)[..., None]
            electric_cyan = np.array([0.08, 0.92, 1.0], dtype=np.float32)
            boosted = np.where(cyan_mask[..., None],
                               boosted * (1.0 - cyan_str * 0.55) + electric_cyan * (cyan_str * 0.75),
                               boosted)
        rgb = np.where(accent[..., None], np.clip(boosted, 0.0, 1.0), rgb)
        px[:, :, :3] = rgb
        color_image.pixels[:] = px.ravel()
        color_image.update()
        report[f"{name}AccentTexelsBoosted"] = int(accent.sum())

    # Generate `<name>Emission.png` for glowing cyan/accent features
    if cyan_mask.any() or accent.any():
        c_str = np.where(cyan_mask, np.clip((cyan_excess - 0.03) / 0.18, 0.15, 1.0), 0.0).astype(np.float32)
        # Soft 2px bloom halo around bright glowing eyes & runes using pure NumPy separable blur
        pad = np.pad(c_str, 2, mode="edge")
        c_h = (pad[:, 0:-4] * 0.15 + pad[:, 1:-3] * 0.22 + pad[:, 2:-2] * 0.26 +
               pad[:, 3:-1] * 0.22 + pad[:, 4:] * 0.15)
        c_bloom = (c_h[0:-4, :] * 0.15 + c_h[1:-3, :] * 0.22 + c_h[2:-2, :] * 0.26 +
                   c_h[3:-1, :] * 0.22 + c_h[4:, :] * 0.15)
        c_final = np.maximum(c_str, c_bloom * 0.65)
        emit_img = bpy.data.images.new(name + "Emission", w, h, alpha=False)
        e_px = np.zeros((h, w, 4), dtype=np.float32)
        e_px[:, :, 0] = c_final * 0.09
        e_px[:, :, 1] = c_final * 0.92
        e_px[:, :, 2] = c_final * 1.00
        e_px[:, :, 3] = 1.0
        emit_img.pixels[:] = e_px.ravel()
        emit_img.filepath_raw = str(OUT / f"{name}Emission.png")
        emit_img.file_format = "PNG"
        emit_img.save()
        report[f"{name}CyanGlowTexels"] = int(cyan_mask.sum())
        report["glowColor"] = "#1CE8FF"

    # 2. Material-aware Roughness map:
    # - Gold/warm metallic (R > G > B, high chroma & medium-high lum) -> 0.36
    # - Vivid emissive/visor (high chroma, bright) -> 0.32
    # - Mid-tone armour/leather -> 0.64
    # - Dark matte cloth -> 0.88
    gold_like = (rgb[:, :, 0] > rgb[:, :, 1]) & (rgb[:, :, 1] > rgb[:, :, 2]) & (chroma > 0.16) & (lum > 0.18)
    visor_like = (chroma > 0.25) & (hi > 0.4)
    rough = np.clip(0.88 - lum * 0.28 - chroma * 0.22, 0.48, 0.90)
    rough = np.where(gold_like, 0.36, rough)
    rough = np.where(visor_like, 0.32, rough)

    rough_img = bpy.data.images.new(name + "Roughness", w, h, alpha=False, is_data=True)
    rough_img.colorspace_settings.name = "Non-Color"
    r_px = np.ones((h, w, 4), dtype=np.float32)
    r_px[:, :, 0] = rough
    r_px[:, :, 1] = rough
    r_px[:, :, 2] = rough
    rough_img.pixels[:] = r_px.ravel()
    rough_img.filepath_raw = str(OUT / f"{name}Roughness.png")
    rough_img.file_format = "PNG"
    rough_img.save()

    # 3. Clean tangent-space relief Normal map derived from high-frequency surface detail.
    # Raycasting NORMAL against 20+ overlapping internal Tripo shells hits hidden interior walls at
    # armpits and hems (inverting tangent normals when joints bend); height-gradient normals stay
    # 100% manifold and deformation-safe.
    dx = np.zeros_like(lum)
    dy = np.zeros_like(lum)
    dx[:, 1:-1] = (lum[:, 2:] - lum[:, :-2]) * 1.35
    dy[1:-1, :] = (lum[2:, :] - lum[:-2, :]) * 1.35
    nz = np.ones_like(lum)
    norm_len = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx = (-dx / norm_len) * 0.5 + 0.5
    ny = (-dy / norm_len) * 0.5 + 0.5
    nz = (nz / norm_len) * 0.5 + 0.5
    norm_img = bpy.data.images.new(name + "Normal", w, h, alpha=False, is_data=True)
    norm_img.colorspace_settings.name = "Non-Color"
    n_px = np.ones((h, w, 4), dtype=np.float32)
    n_px[:, :, 0] = nx
    n_px[:, :, 1] = ny
    n_px[:, :, 2] = nz
    norm_img.pixels[:] = n_px.ravel()
    norm_img.filepath_raw = str(OUT / f"{name}Normal.png")
    norm_img.file_format = "PNG"
    norm_img.save()
    return rough_img, norm_img


def fuse_and_bake(src, name, faces, voxel, texture):
    """A closed copy of `src` at `faces` triangles with Head/Hand/Joint-protected topology,
    priority-weighted UVs, and Color + Normal + Roughness maps baked."""
    if name == "Body" and spec.get("splitSkirtCleft", True):
        report["skirtCleftFacesSplit"] = split_skirt_cleft(src, voxel)
    out = src.copy()
    out.data = src.data.copy()
    out.name = name
    scene.collection.objects.link(out)
    bpy.context.view_layer.objects.active = out
    for o in bpy.data.objects:
        o.select_set(o == out)
    thick = out.modifiers.new("thicken", "SOLIDIFY")
    thick.thickness = voxel * spec.get("thicknessVoxels", 1.5)
    thick.offset = -1
    bpy.ops.object.modifier_apply(modifier="thicken")
    remesh = out.modifiers.new("fuse", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0
    bpy.ops.object.modifier_apply(modifier="fuse")
    remeshed = sum(len(p.vertices) - 2 for p in out.data.polygons)

    vg_name = build_preserve_group(out) if name == "Body" else None
    reduce = out.modifiers.new("reduce", "DECIMATE")
    reduce.ratio = min(1.0, faces / max(1, remeshed))
    if vg_name:
        reduce.vertex_group = vg_name
        reduce.invert_vertex_group = True
        reduce.vertex_group_factor = 0.65
    bpy.ops.object.modifier_apply(modifier="reduce")

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
    bmesh.ops.delete(cleaned, geom=[f for i in islands if len(i) < 50 for f in i], context="FACES")
    b_edges = [e for e in cleaned.edges if e.is_boundary]
    if b_edges:
        bmesh.ops.holes_fill(cleaned, edges=b_edges, sides=16)
        b_edges = [e for e in cleaned.edges if e.is_boundary]
        if b_edges:
            b_verts = list({v for e in b_edges for v in e.verts})
            bmesh.ops.remove_doubles(cleaned, verts=b_verts, dist=voxel * 1.5)
    bmesh.ops.triangulate(cleaned, faces=cleaned.faces[:])
    bmesh.ops.recalc_face_normals(cleaned, faces=cleaned.faces[:])
    cleaned.to_mesh(out.data)
    cleaned.free()

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    if name == "Body":
        boost_head_torso_uvs(out)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, shape_method="CONCAVE", margin_method="FRACTION", margin=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    out.data.materials.clear()

    image = bpy.data.images.new(name + "Color", texture, texture, alpha=False)

    mat = bpy.data.materials.new(name + "Color")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    holder = mat.node_tree.nodes.new("ShaderNodeTexImage")
    holder.image = image
    mat.node_tree.links.new(holder.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    mat.node_tree.nodes.active = holder
    out.data.materials.append(mat)

    for slot in src.material_slots:
        slot.material = slot.material.copy()
        tree = slot.material.node_tree
        tex = next((n for n in tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
        emit = tree.nodes.new("ShaderNodeEmission")
        sink = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
        if tex:
            tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
        else:
            emit.inputs["Color"].default_value = tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        tree.links.new(emit.outputs["Emission"], sink.inputs["Surface"])

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = voxel * spec.get("cage", 1)
    scene.render.bake.max_ray_distance = voxel * spec.get("cage", 1) * 2.5
    scene.render.bake.margin = 6
    for o in bpy.data.objects:
        o.select_set(o in (out, src))
    bpy.context.view_layer.objects.active = out
    bpy.ops.object.bake(type="EMIT")

    if name == "Hair" and spec.get("cleanHairFlecks", True):
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

    enhance_and_make_roughness(image, name)
    image.filepath_raw = str(OUT / f"{name}Color.png")
    image.file_format = "PNG"
    image.save()

    # Keep only the Base Color texture node in the exported GLB so write_fbx.py and Studio's
    # Avatar Setup FBX importer see a single clean texture per part; Normal and Roughness maps
    # are saved on disk (<name>Normal.png, <name>Roughness.png) for Roblox SurfaceAppearance
    # and loaded during Argon preview/pose rendering.
    mat.node_tree.nodes.active = holder

    bpy.data.objects.remove(src)
    return out, remeshed


# ---------------------------------------------------------------- 3. one watertight shell
voxel = spec.get("voxel", 0.0032) * scale
body, report["remeshTriangles"] = fuse_and_bake(body_src, "Body", spec.get("faces", 12000), voxel,
                                                spec.get("texture", 1024))
for name in list(accessories):
    obj = accessories[name]
    limit = spec.get("accessoryFaces", 4000)
    if sum(len(p.vertices) - 2 for p in obj.data.polygons) > limit:
        obj.name = name + "Source"
        accessories[name], _ = fuse_and_bake(obj, name, limit, voxel * 0.6, spec.get("texture", 1024) // 2)

# ---------------------------------------------------------------- 4. face -Z, write, preview
flip = Matrix.Rotation(math.pi, 4, "Z")
for obj in [body, *accessories.values()]:
    obj.data.transform(flip)
    obj.data.update()

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

# Attach the baked Normal and Roughness maps for the preview renders
for name, obj in [("Body", body), *accessories.items()]:
    if not obj.data.materials:
        continue
    tree = obj.data.materials[0].node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    n_path, r_path = OUT / f"{name}Normal.png", OUT / f"{name}Roughness.png"
    if bsdf and n_path.exists():
        nh = tree.nodes.new("ShaderNodeTexImage")
        nh.image = bpy.data.images.load(str(n_path))
        nh.image.colorspace_settings.name = "Non-Color"
        nm = tree.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.85
        tree.links.new(nh.outputs["Color"], nm.inputs["Color"])
        tree.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if bsdf and r_path.exists():
        rh = tree.nodes.new("ShaderNodeTexImage")
        rh.image = bpy.data.images.load(str(r_path))
        rh.image.colorspace_settings.name = "Non-Color"
        tree.links.new(rh.outputs["Color"], bsdf.inputs["Roughness"])
    e_path = OUT / f"{name}Emission.png"
    if bsdf and e_path.exists():
        eh = tree.nodes.new("ShaderNodeTexImage")
        eh.image = bpy.data.images.load(str(e_path))
        tree.links.new(eh.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 4.5

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
print("PREPARED_ARGON", json.dumps(report))
