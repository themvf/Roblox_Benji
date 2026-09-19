# Aircraft-carrier modular kit, pass 1 (five pieces).
#
# Run headless:   blender --background --python tools/blender/carrier_kit.py
# Run in the UI:  paste into the Scripting tab and press Run.
# Add --export to also write one FBX per module into assets/blender/carrier/.
#
# Units: 1 Blender metre == 1 Roblox stud, so the FBX imports 1:1 with no rescale.
# Grid: everything snaps on a 4-stud lattice; deck modules are 32x32.

import os
import sys

import bpy
from mathutils import Matrix, Vector

GRID = 4.0
DECK = 32.0
DECK_THICK = 2.0

COLLECTIONS = ("Structure", "Cover", "Props", "GameplayMarkers", "ExportReady")

MATERIALS = {
    # name: (base colour RGBA, roughness, metallic)
    "Carrier_Deck": ((0.13, 0.14, 0.15, 1.0), 0.90, 0.0),
    "Carrier_Metal": ((0.38, 0.40, 0.43, 1.0), 0.55, 1.0),
    "Carrier_Hazard": ((0.72, 0.56, 0.10, 1.0), 0.70, 0.0),
    "Carrier_Grate": ((0.22, 0.23, 0.25, 1.0), 0.75, 0.6),
}


# --------------------------------------------------------------------------
# scene scaffolding
# --------------------------------------------------------------------------


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def ensure_collections():
    made = {}
    for name in COLLECTIONS:
        col = bpy.data.collections.get(name)
        if col is None:
            col = bpy.data.collections.new(name)
            bpy.context.scene.collection.children.link(col)
        made[name] = col
    return made


def ensure_materials():
    made = {}
    for name, (colour, rough, metal) in MATERIALS.items():
        mat = bpy.data.materials.get(name)
        if mat is None:
            mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        made[name] = mat
    return made


# --------------------------------------------------------------------------
# geometry helpers
# --------------------------------------------------------------------------


def box(name, size, centre):
    """An axis-aligned box. size/centre are (x, y, z) in studs."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(size)
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name + "_mesh"
    return obj


def finalise(obj, collection, material, origin):
    """Apply transforms, set the pivot, fix normals, file it, shade it."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    # Bake scale/rotation into the mesh so Studio sees a clean 1,1,1 transform.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Move the pivot to the snap point, then park the object at the world origin.
    offset = Vector(origin)
    obj.data.transform(Matrix.Translation(obj.location - offset))
    obj.location = (0.0, 0.0, 0.0)

    # Outward normals, no leftover interior faces from the box soup.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.ops.object.shade_flat()

    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


# --------------------------------------------------------------------------
# the five modules
# --------------------------------------------------------------------------


def deck_straight():
    """32 x 32 slab. Pivot at the centre of the walking surface."""
    slab = box("deck_slab", (DECK, DECK, DECK_THICK), (0, 0, -DECK_THICK / 2))
    return join([slab], "CarrierDeck_Straight_32x32"), (0, 0, 0)


def railing():
    """32 long, 3.5 tall, posts on the 4-stud grid. Pivot at base centre."""
    parts = []
    height = 3.5
    for i in range(9):
        x = -DECK / 2 + i * GRID
        parts.append(box(f"post_{i}", (0.35, 0.35, height), (x, 0, height / 2)))
    for z in (height - 0.2, height * 0.55):
        parts.append(box(f"rail_{z:.2f}", (DECK, 0.25, 0.25), (0, 0, z)))
    return join(parts, "CarrierRailing_32"), (0, 0, 0)


def catwalk():
    """32 x 8 walkway that hangs off a deck edge. Pivot at base centre."""
    parts = [box("floor", (DECK, 8.0, 0.5), (0, 0, 0.25))]
    for side in (-1, 1):
        parts.append(box(f"kick_{side}", (DECK, 0.3, 1.0), (0, side * 3.85, 0.5)))
    for i in (-1, 0, 1):
        parts.append(box(f"bracket_{i}", (0.5, 8.0, 0.5), (i * 12.0, 0, -0.25)))
    return join(parts, "CarrierCatwalk_32x8"), (0, 0, 0)


def blast_barrier():
    """8 wide, 5 tall medium cover: stand behind it, shoot over it crouched-up.

    5 studs puts the lip just under an R15 chest, which is the 'medium cover'
    read we want -- blocks torso, leaves head/shoulders exposed when standing.
    """
    parts = [box("slab", (8.0, 1.0, 5.0), (0, 0, 2.5))]
    parts.append(box("lip", (8.0, 1.6, 0.4), (0, 0, 4.8)))
    for side in (-1, 1):
        parts.append(box(f"foot_{side}", (1.0, 3.0, 0.6), (side * 3.0, 0, 0.3)))
    return join(parts, "CarrierBarrier_Medium_8x5"), (0, 0, 0)


def stairs():
    """8 wide, rises 8 studs over a 16-stud run: one deck-to-catwalk level.

    Pivot at the base front edge so it snaps to a deck edge and lands exactly
    on the level above.
    """
    steps = 8
    rise = 8.0 / steps
    run = 16.0 / steps
    parts = []
    for i in range(steps):
        z = rise * (i + 0.5)
        y = -16.0 / 2 + run * (i + 0.5)
        parts.append(box(f"step_{i}", (8.0, run, rise), (0, y, z)))
    for side in (-1, 1):
        parts.append(box(f"stringer_{side}", (0.5, 16.0, 1.0), (side * 4.25, 0, 4.0)))
    return join(parts, "CarrierStair_8w_8rise"), (0, -16.0 / 2, 0)


BUILD = [
    (deck_straight, "Structure", "Carrier_Deck"),
    (railing, "Structure", "Carrier_Metal"),
    (catwalk, "Structure", "Carrier_Grate"),
    (blast_barrier, "Cover", "Carrier_Hazard"),
    (stairs, "Structure", "Carrier_Metal"),
]


# --------------------------------------------------------------------------
# report + export
# --------------------------------------------------------------------------


def tri_count(obj):
    return sum(max(len(p.vertices) - 2, 0) for p in obj.data.polygons)


def dims(obj):
    return tuple(round(d, 2) for d in obj.dimensions)


def export_fbx(obj, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out_dir, obj.name + ".fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        global_scale=1.0,
        axis_forward="-Z",
        axis_up="Y",
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        add_leaf_bones=False,
        bake_space_transform=True,
        path_mode="COPY",
        embed_textures=True,
    )


def main():
    reset_scene()
    cols = ensure_collections()
    mats = ensure_materials()

    rows = []
    for builder, col_name, mat_name in BUILD:
        obj, origin = builder()
        finalise(obj, cols[col_name], mats[mat_name], origin)
        rows.append((obj, col_name, mat_name))

    do_export = "--export" in sys.argv
    out_dir = os.path.join(
        os.path.dirname(bpy.data.filepath) or os.getcwd(),
        "assets",
        "blender",
        "carrier",
    )

    print("\n%-28s %-16s %6s %6s  %s" % ("module", "collection", "tris", "verts", "size (studs)"))
    print("-" * 82)
    total = 0
    for obj, col_name, _ in rows:
        tris = tri_count(obj)
        total += tris
        print(
            "%-28s %-16s %6d %6d  %s"
            % (obj.name, col_name, tris, len(obj.data.vertices), dims(obj))
        )
        if do_export:
            export_fbx(obj, out_dir)
    print("-" * 82)
    print("%-28s %-16s %6d" % ("TOTAL", "", total))
    if do_export:
        print("exported to " + out_dir)


if __name__ == "__main__":
    main()
