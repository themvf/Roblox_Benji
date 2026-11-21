"""Rebuild WoodenWatchtower export from the Trellis source GLB with:
1. A clean Boolean-cut doorway in the upper crow's nest entry wall (no walk-through slats).
2. A matching Trellis-textured upper ladder cloned cleanly from the lower ladder onto Deck 1 -> Upper Booth.
3. Exact scene_kit 28-stud scaling, <10k/tile 2x2 tiling, bottom-center pivot, and 1024x1024 PNG optimization.
"""

import os
import sys

import bmesh
import bpy
import mathutils

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
sys.path.insert(0, SCRIPT_DIR)
import scene_kit  # noqa: E402

SRC_GLB = os.path.join(ROOT, "assets", "models", "wooden-watchtower", "source", "WoodenWatchtower.glb")
OUT_GLB = os.path.join(ROOT, "assets", "models", "wooden-watchtower", "exports", "WoodenWatchtower.glb")


def clone_trellis_ladder(tower_ob):
    """Extract the detached lower Trellis wood ladder mesh and place a clean copy as the upper tier ladder."""
    bm = bmesh.new()
    bm.from_mesh(tower_ob.data)
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active

    # Capture only faces strictly inside the protruding front ladder volume (Blender -Y face, Z in 0..9.6)
    def in_ladder(v):
        co = v.co
        y_cutoff = -6.92 + co.z * 0.085
        return (-1.96 <= co.x <= 1.56) and (0.05 <= co.z <= 9.65) and (co.y < y_cutoff)

    keep_faces = [f for f in bm.faces if all(in_ladder(v) for v in f.verts)]
    if not keep_faces:
        raise RuntimeError("No lower ladder faces matched filter")

    # Build new mesh data for the extracted ladder keeping UVs intact
    lad_bm = bmesh.new()
    lad_uv = lad_bm.loops.layers.uv.new(uv_layer.name if uv_layer else "UVMap")
    v_map = {}
    for f in keep_faces:
        new_vs = []
        for v in f.verts:
            nv = v_map.get(v.index)
            if nv is None:
                nv = lad_bm.verts.new(v.co)
                v_map[v.index] = nv
            new_vs.append(nv)
        try:
            nf = lad_bm.faces.new(new_vs)
        except ValueError:
            continue
        if uv_layer:
            for l_src, l_dst in zip(f.loops, nf.loops):
                l_dst[lad_uv].uv = l_src[uv_layer].uv

    # Remove tiny disconnected flecks (keep largest connected island(s) > 100 verts)
    lad_bm.verts.ensure_lookup_table()
    visited = set()
    islands = []
    for v in lad_bm.verts:
        if v.index in visited:
            continue
        stack = [v]
        comp = []
        visited.add(v.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.link_edges:
                nb = e.other_vert(cur)
                if nb.index not in visited:
                    visited.add(nb.index)
                    stack.append(nb)
        islands.append(comp)
    drop_verts = []
    for comp in islands:
        if len(comp) < 200:
            drop_verts.extend(comp)
    if drop_verts:
        bmesh.ops.delete(lad_bm, geom=drop_verts, context="VERTS")

    # Recenter ladder X to 0, remap Z [min..max] -> [11.35..20.25], and slant cleanly from Y=-5.25 -> Y=-2.45
    zs = [v.co.z for v in lad_bm.verts]
    xs = [v.co.x for v in lad_bm.verts]
    ys = [v.co.y for v in lad_bm.verts]
    z_min, z_max = min(zs), max(zs)
    x_mid = 0.5 * (min(xs) + max(xs))
    # Linear Y centerline of extracted ladder: y_bot -> y_top
    low_y = [v.co.y for v in lad_bm.verts if v.co.z < z_min + 1.0]
    high_y = [v.co.y for v in lad_bm.verts if v.co.z > z_max - 1.0]
    y_bot_src = sum(low_y) / len(low_y)
    y_top_src = sum(high_y) / len(high_y)

    z_span = max(0.01, z_max - z_min)
    for v in lad_bm.verts:
        t = (v.co.z - z_min) / z_span
        y_line_src = y_bot_src + t * (y_top_src - y_bot_src)
        y_off = v.co.y - y_line_src

        # Target span: foot on Deck 1 balcony (Z=11.30, Y=-5.25) -> upper doorway sill (Z=20.25, Y=-2.45)
        new_x = (v.co.x - x_mid) * 0.92
        new_z = 11.30 + t * 8.95
        new_y = (-5.25 + t * 2.80) + y_off
        v.co = mathutils.Vector((new_x, new_y, new_z))

    lad_mesh = bpy.data.meshes.new("UpperLadderMesh")
    lad_bm.to_mesh(lad_mesh)
    lad_bm.free()
    bm.free()

    for mat in tower_ob.data.materials:
        lad_mesh.materials.append(mat)
    lad_ob = bpy.data.objects.new("UpperLadder", lad_mesh)
    bpy.context.scene.collection.objects.link(lad_ob)
    return lad_ob


def cut_upper_doorway(tower_ob):
    """Boolean-cut a clean walk-in doorway into the -Y entry parapet wall of the upper sniper booth."""
    # Cutter covers X in [-1.65, +1.65], Y in [-3.2, -1.25], Z in [20.05, 25.60]
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -2.225, 22.825))
    cutter = bpy.context.active_object
    cutter.name = "DoorCutter"
    cutter.scale = (3.30, 1.95, 5.55)
    scene_kit.apply_transform(cutter)
    # Give cutter the tower wood material so cut jambs inherit weathered wood texture instead of flat white
    if tower_ob.data.materials:
        cutter.data.materials.append(tower_ob.data.materials[0])

    # Project cutter UVs cleanly onto a dark brown weathered wood sample UV coordinate from tower_ob
    uv_layer = cutter.data.uv_layers.active or cutter.data.uv_layers.new(name="UVMap")
    # Pick UV of a vertex near the parapet wall (-2.2, 21.5)
    sample_uv = (0.5, 0.5)
    src_uv = tower_ob.data.uv_layers.active
    if src_uv:
        for p in tower_ob.data.polygons:
            vco = tower_ob.data.vertices[p.vertices[0]].co
            if abs(vco.x) < 3.0 and -2.9 < vco.y < -1.5 and 20.5 < vco.z < 22.8:
                u = src_uv.data[p.loop_indices[0]].uv
                sample_uv = (u.x, u.y)
                break
    for loop_uv in uv_layer.data:
        loop_uv.uv = sample_uv

    mod = tower_ob.modifiers.new(name="DoorCut", type="BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "FAST"
    mod.object = cutter
    bpy.context.view_layer.objects.active = tower_ob
    bpy.ops.object.modifier_apply(modifier=mod.name)

    scene_kit.select([cutter])
    bpy.ops.object.delete()


def main():
    scene_kit.reset()
    objs = scene_kit.load(SRC_GLB)
    ob = scene_kit.join(objs, "WoodenWatchtower")
    scene_kit.op_fit(ob, "z", 28)
    scene_kit.op_pivot([ob], "bottom", 2)

    print("Source loaded, extracting upper ladder clone...")
    upper_lad = clone_trellis_ladder(ob)
    print("Upper ladder tris:", scene_kit.tris([upper_lad]))

    print("Boolean-cutting open upper doorway...")
    cut_upper_doorway(ob)
    # Verify doorway clearance inside [-1.3..1.3], [-2.9..-1.4], [20.3..25.4]
    stray = [v for v in ob.data.vertices if -1.3 <= v.co.x <= 1.3 and -2.9 <= v.co.y <= -1.4 and 20.3 <= v.co.z <= 25.4]
    print("Doorway remaining interior verts (expect ~0):", len(stray))

    joined = scene_kit.join([ob, upper_lad], "WoodenWatchtower")
    scene_kit.op_decimate(joined, 26000)
    tiles = scene_kit.op_tile(joined, 2, 2, 2)
    scene_kit.op_pivot(tiles, "bottom", 2)
    scene_kit.check(tiles, defer_tris=True)
    scene_kit.export(OUT_GLB)
    scene_kit.op_optimize(OUT_GLB, {"texture": 1024}, tiled=True)
    print("Built and exported:", OUT_GLB)


if __name__ == "__main__":
    main()
