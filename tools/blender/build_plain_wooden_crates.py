"""Export only the verified wood-and-pallet geometry from the wrapped crate source blend."""

from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/wrapped-white-crate"
SOURCE = PKG / "source/WrappedWhiteCrate.blend"
BLEND = PKG / "source/PlainWoodenCrates.blend"
EXPORT = PKG / "exports/PlainWoodenCrates.glb"


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    keep = {"CrateWood_Left", "CrateWood_Right"}
    for obj in list(bpy.data.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    wood = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    assert {obj.name for obj in wood} == keep
    bpy.ops.object.select_all(action="DESELECT")
    for obj in wood:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = wood[0]
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True)
    print("wrote", EXPORT)


if __name__ == "__main__":
    main()
