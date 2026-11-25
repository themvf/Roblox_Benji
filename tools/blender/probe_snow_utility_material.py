from pathlib import Path
import bpy
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / "assets/models/snow-utility-vehicle/source/trellis-original.glb"))
for mat in bpy.data.materials:
    print("MAT",mat.name)
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            print("IMAGE",node.name,node.image.name,node.image.size[:],node.image.file_format)
            for link in node.outputs["Color"].links:
                print("LINK",link.to_node.name,link.to_socket.name)
