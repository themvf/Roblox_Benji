"""Try preserving the original textured character before any clean rebuild."""
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
variant = sys.argv[sys.argv.index("--") + 1]
ratio = float(sys.argv[sys.argv.index("--") + 2])
source = PKG / "source" / f"{variant}Source.glb"
output = PKG / "trials" / f"{variant}-decimate-{int(ratio * 100)}.glb"
output.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(meshes) == 1
obj = meshes[0]
before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
modifier = obj.modifiers.new("Trial decimation", "DECIMATE")
modifier.ratio = ratio
bpy.context.view_layer.objects.active = obj
bpy.ops.object.modifier_apply(modifier=modifier.name)
after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print("TRIANGLES", before, after)
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=False)
print("EXPORTED", output)
