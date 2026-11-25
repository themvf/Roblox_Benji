"""Render Stage 5 preview views (front, side, rear, quarter, head closeup, posed limbs,
and in-game scale view) for DarkFantasyDemonFemale from the saved editable .blend.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/dark-fantasy-demon-female"
REVIEW = PKG / "review"
REVIEW.mkdir(parents=True, exist_ok=True)


def setup_scene():
    bpy.ops.wm.open_mainfile(filepath=str(PKG / "source/DarkFantasyDemonFemale.blend"))
    # Hide cages in visual renders
    for o in bpy.data.objects:
        if o.name.endswith("_InnerCage") or o.name.endswith("_OuterCage"):
            o.hide_render = True
            o.hide_viewport = True

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 28
    sc.render.resolution_x = 768
    sc.render.resolution_y = 1024

    world = bpy.data.worlds.new("review")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.76, 0.77, 0.80, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.05

    # Soft studio 3-point lighting with subtle cool-violet rim
    for lname, loc, rot, energy, col in (
        ("key", (4.2, -6.5, 7.2), (0.82, 0.18, 0.48), 3.1, (1.0, 0.99, 0.98)),
        ("fill", (-5.2, -4.5, 4.8), (1.0, -0.2, -0.6), 1.65, (0.94, 0.95, 1.0)),
        ("rim", (0.0, 6.2, 6.8), (-0.8, 0.0, 3.14), 2.2, (0.93, 0.88, 1.0)),
    ):
        ldata = bpy.data.lights.new(lname, "SUN")
        ldata.energy = energy
        ldata.color = col
        ldata.angle = math.radians(12.0)
        lobj = bpy.data.objects.new(lname, ldata)
        sc.collection.objects.link(lobj)
        lobj.location = loc
        lobj.rotation_euler = rot
    return sc


def render_cam(sc, name, loc, target, ortho_scale=8.0, res=(768, 1024), persp_lens=None):
    cam_data = bpy.data.cameras.new(name)
    if persp_lens is not None:
        cam_data.type = "PERSP"
        cam_data.lens = persp_lens
    else:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new(name, cam_data)
    sc.collection.objects.link(cam)
    cam.location = Vector(loc)
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = str(REVIEW / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def reset_pose():
    arm = bpy.data.objects["R15_Rig"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = Vector((0.0, 0.0, 0.0))
    bpy.ops.object.mode_set(mode="OBJECT")


def _set_bone_world_euler(arm, bname: str, world_xyz: tuple[float, float, float]):
    pb = arm.pose.bones[bname]
    q_world = Euler(world_xyz, "XYZ").to_quaternion()
    b_rot = pb.bone.matrix_local.to_quaternion()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = b_rot.inverted() @ q_world @ b_rot


def apply_test_pose():
    """Apply an aggressive R15 stress-test pose (overhead raised arm ~100 deg, torso twist ~28 deg,
    deep hip stride ~60 deg, and deep knee flexion ~75 deg) to expose any mantle/tasset/wrist clipping.
    """
    arm = bpy.data.objects["R15_Rig"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    poses = {
        "UpperTorso":    (0.14, 0.08, 0.48),
        "Head":          (-0.10, -0.04, -0.36),
        "LeftUpperArm":  (-0.35, -1.78, 0.15),   # Raised overhead (~102 deg abduction)
        "LeftLowerArm":  (-0.85, 0.0, 0.0),      # Elbow flex
        "RightUpperArm": (0.45, 1.05, -0.25),    # Pulled back/out (~65 deg)
        "RightLowerArm": (-1.35, 0.0, 0.0),      # Deep forearm curl (~77 deg)
        "LeftUpperLeg":  (-1.05, 0.0, -0.10),    # Forward high hip stride (-60 deg)
        "LeftLowerLeg":  (1.30, 0.0, 0.0),       # Deep knee bend (+75 deg)
        "LeftFoot":      (-0.25, 0.0, 0.0),
        "RightUpperLeg": (0.62, 0.0, 0.10),      # Back lunge (+35 deg)
        "RightLowerLeg": (0.95, 0.0, 0.0),       # Trailing knee bend (+55 deg)
        "RightFoot":     (-0.35, 0.0, 0.0),
    }
    for bname, xyz in poses.items():
        _set_bone_world_euler(arm, bname, xyz)
    bpy.ops.object.mode_set(mode="OBJECT")


def apply_idle_ready_pose():
    """Apply a subtle R15 in-game idle stance for the gameplay-scale view."""
    arm = bpy.data.objects["R15_Rig"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    poses = {
        "UpperTorso": (0.02, 0.06, 0.0),
        "Head": (-0.02, -0.05, 0.0),
        "LeftUpperArm": (0.08, 0.05, 0.06),
        "LeftLowerArm": (0.18, 0.0, 0.0),
        "RightUpperArm": (-0.06, -0.05, -0.06),
        "RightLowerArm": (0.16, 0.0, 0.0),
        "LeftUpperLeg": (-0.06, 0.0, 0.02),
        "LeftLowerLeg": (0.08, 0.0, 0.0),
        "RightUpperLeg": (0.06, 0.0, -0.02),
        "RightLowerLeg": (0.06, 0.0, 0.0),
    }
    for bname, xyz in poses.items():
        pb = arm.pose.bones[bname]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler(xyz, "XYZ")
    bpy.ops.object.mode_set(mode="OBJECT")


def build_ingame_scale_props(sc) -> list[bpy.types.Object]:
    """Create a 1-stud grid arena floor, a 5.5-stud Standard R15 Scale Dummy,
    and 1-stud height ruler ticks for the in-game scale view.
    """
    created: list[bpy.types.Object] = []

    # Materials
    floor_mat = bpy.data.materials.new("ArenaFloorMat")
    floor_mat.use_nodes = True
    nt = floor_mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.72
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    checker = nt.nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 24.0  # 1-stud squares across 24-stud floor
    checker.inputs["Color1"].default_value = (0.20, 0.21, 0.25, 1.0)
    checker.inputs["Color2"].default_value = (0.25, 0.26, 0.31, 1.0)
    nt.links.new(tex_coord.outputs["Generated"], checker.inputs["Vector"])
    nt.links.new(checker.outputs["Color"], bsdf.inputs["Base Color"])

    dummy_mat = bpy.data.materials.new("R15ReferenceDummyMat")
    dummy_mat.use_nodes = True
    dummy_bsdf = dummy_mat.node_tree.nodes["Principled BSDF"]
    dummy_bsdf.inputs["Base Color"].default_value = (0.28, 0.30, 0.36, 1.0)
    dummy_bsdf.inputs["Roughness"].default_value = 0.68

    ruler_mat = bpy.data.materials.new("StudRulerMat")
    ruler_mat.use_nodes = True
    ruler_bsdf = ruler_mat.node_tree.nodes["Principled BSDF"]
    ruler_bsdf.inputs["Base Color"].default_value = (0.58, 0.36, 0.84, 1.0)
    ruler_bsdf.inputs["Roughness"].default_value = 0.42

    # 1. Floor plane at Z = 0
    bpy.ops.mesh.primitive_plane_add(size=24.0, location=(1.4, 0.0, -0.01))
    floor_obj = bpy.context.active_object
    floor_obj.name = "ScaleView_ArenaFloor"
    floor_obj.data.materials.append(floor_mat)
    created.append(floor_obj)

    # 2. Standard 5.5-stud Classic/Stylized R15 Reference Mannequin at X = +3.65
    dx = 3.65
    parts = [
        # (name, loc, scale, is_round)
        ("Ref_LeftLeg", (dx - 0.50, 0.0, 1.10), (0.45, 0.45, 1.10), False),
        ("Ref_RightLeg", (dx + 0.50, 0.0, 1.10), (0.45, 0.45, 1.10), False),
        ("Ref_Torso", (dx, 0.0, 3.25), (0.95, 0.46, 1.05), False),
        ("Ref_LeftArm", (dx - 1.44, 0.0, 3.25), (0.42, 0.42, 1.05), False),
        ("Ref_RightArm", (dx + 1.44, 0.0, 3.25), (0.42, 0.42, 1.05), False),
        ("Ref_Head", (dx, 0.0, 4.90), (0.58, 0.58, 0.58), True),
    ]
    for pname, ploc, pscale, is_round in parts:
        if is_round:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=ploc)
        else:
            bpy.ops.mesh.primitive_cube_add(size=2.0, location=ploc)
            mod = bpy.context.active_object.modifiers.new("Bevel", "BEVEL")
            mod.width = 0.08
            mod.segments = 2
        obj = bpy.context.active_object
        obj.name = pname
        obj.scale = pscale
        obj.data.materials.append(dummy_mat)
        created.append(obj)

    # 3. Stud height ruler pillar at X = +1.92 with ticks every 1.0 stud (1..7 studs)
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=(1.92, 0.25, 3.75))
    post = bpy.context.active_object
    post.name = "ScaleView_RulerPost"
    post.scale = (0.03, 0.03, 3.75)
    post.data.materials.append(dummy_mat)
    created.append(post)

    for stud_z in range(1, 8):
        bpy.ops.mesh.primitive_cube_add(size=2.0, location=(1.92, 0.25, float(stud_z)))
        tick = bpy.context.active_object
        tick.name = f"ScaleView_Tick_{stud_z}"
        is_major = stud_z in (5, 6, 7)
        tick.scale = (0.22 if is_major else 0.14, 0.035, 0.025)
        tick.data.materials.append(ruler_mat if is_major else dummy_mat)
        created.append(tick)

    return created


def _make_variant_mat(base_mat, suffix: str, body_tex: Path, acc_tex: Path, is_acc: bool):
    m = base_mat.copy()
    m.name = f"{base_mat.name}_{suffix}"
    img_path = acc_tex if is_acc else body_tex
    for node in m.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None and "_ALB" in node.image.name:
            node.image = bpy.data.images.load(str(img_path), check_existing=True)
    return m


def main():
    sc = setup_scene()
    center = (0.0, 0.0, 3.65)
    render_cam(sc, "front", (0.0, -10.0, 3.65), center, ortho_scale=8.0)
    render_cam(sc, "side", (10.0, 0.0, 3.65), center, ortho_scale=8.0)
    render_cam(sc, "rear", (0.0, 10.0, 3.65), center, ortho_scale=8.0)
    render_cam(sc, "quarter", (6.5, -7.5, 4.2), center, ortho_scale=8.2)
    render_cam(
        sc,
        "head_closeup",
        (0.32, -5.0, 5.26),
        (0.0, 0.0, 5.18),
        ortho_scale=2.55,
        res=(768, 768),
    )

    apply_test_pose()
    render_cam(sc, "posed_limbs", (4.8, -8.8, 4.1), (0.0, 0.0, 3.55), ortho_scale=8.5)
    render_cam(sc, "posed_stress_side", (-9.5, -1.8, 3.85), (0.0, 0.0, 3.55), ortho_scale=8.5)

    # Render Team Red / Neutral Violet / Team Blue 3-character comparison at gameplay distance:
    reset_pose()
    tex_dir = PKG / "textures"
    body_mat = bpy.data.materials.get("DarkFantasyDemonBodyMat")
    acc_mat = bpy.data.materials.get("DarkFantasyDemonAccMat")
    render_objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith(("_InnerCage", "_OuterCage"))]
    tmp_created = []
    if body_mat and acc_mat:
        for dx, tsuf in ((-3.65, "TeamRed"), (3.65, "TeamBlue")):
            m_b = _make_variant_mat(body_mat, tsuf, tex_dir / f"DarkFantasyDemonBody_{tsuf}_ALB.png", tex_dir / f"DarkFantasyDemonAcc_{tsuf}_ALB.png", False)
            m_a = _make_variant_mat(acc_mat, tsuf, tex_dir / f"DarkFantasyDemonBody_{tsuf}_ALB.png", tex_dir / f"DarkFantasyDemonAcc_{tsuf}_ALB.png", True)
            for src in render_objs:
                dup = src.copy()
                dup.data = src.data.copy()
                dup.modifiers.clear()
                dup.parent = None
                dup.location = Vector((dx, 0.0, 0.0))
                dup.data.materials.clear()
                is_acc_obj = any(mat and "Acc" in mat.name for mat in src.data.materials)
                dup.data.materials.append(m_a if is_acc_obj else m_b)
                sc.collection.objects.link(dup)
                tmp_created.append(dup)
        render_cam(sc, "team_colors", (0.0, -17.5, 4.1), (0.0, 0.0, 3.55), res=(1280, 720), persp_lens=38.0)
        for o in tmp_created:
            bpy.data.objects.remove(o, do_unlink=True)

    # Render in-game scale view at normal Roblox third-person camera distance
    apply_idle_ready_pose()
    props = build_ingame_scale_props(sc)
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.21, 1.0)
    render_cam(
        sc,
        "ingame_scale",
        (1.35, -16.2, 5.2),
        (1.35, 0.0, 3.35),
        res=(1024, 768),
        persp_lens=38.0,
    )
    for o in props:
        bpy.data.objects.remove(o, do_unlink=True)
    reset_pose()
    print("PREVIEWS_COMPLETE")


if __name__ == "__main__":
    main()
