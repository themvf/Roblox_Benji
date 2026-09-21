"""Read exported files back into clean Blender scenes; verify actual transport.
Run after build_fortress_kit.py with --factory-startup --background.
"""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/snow-fortress/entrance-kit-v1"
manifest = json.loads((OUT / "manifest.json").read_text())
report = {"status": "pass", "checks": []}
for name, spec in manifest["modules"].items():
    expected_min, expected_max = spec["boundsMin"], spec["boundsMax"]
    for extension in ["glb", "fbx"]:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        path = str(OUT / "exports" / (name + "." + extension))
        if extension == "glb":
            bpy.ops.import_scene.gltf(filepath=path)
        else:
            bpy.ops.import_scene.fbx(filepath=path)
        objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        assert len(objects) == 1, (name, extension, "unexpected mesh splitting", len(objects))
        obj = objects[0]
        points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
        lower = [min(v[i] for v in points) for i in range(3)]
        upper = [max(v[i] for v in points) for i in range(3)]
        assert max(abs(a-b) for a,b in zip(lower, expected_min)) < 0.005, (name, extension, lower, expected_min)
        assert max(abs(a-b) for a,b in zip(upper, expected_max)) < 0.005, (name, extension, upper, expected_max)
        assert len(obj.data.uv_layers) == 1, (name, extension, "expected one UV set")
        assert len(obj.data.materials) == 1, (name, extension, "expected one material")
        obj.data.calc_loop_triangles()
        assert len(obj.data.loop_triangles) == spec["triangles"]
        for loop in obj.data.uv_layers.active.data:
            assert -0.001 <= loop.uv.x <= 1.001 and -0.001 <= loop.uv.y <= 1.001
        # glTF splits vertices along normal/UV seams. Weld only in the verification
        # mesh to check whether surfaces close, without changing the deliverable.
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.00001)
        # Assembled solid components may meet along an edge; welding creates
        # multi-face junctions there. Reject actual holes, record junctions.
        boundary_edges = sum(edge.is_boundary or edge.is_wire for edge in mesh.edges)
        junction_edges = sum(len(edge.link_faces) > 2 for edge in mesh.edges)
        mesh.free()
        assert boundary_edges == 0, (name, extension, "open edges", boundary_edges)
        report["checks"].append({"module": name, "format": extension, "triangles": spec["triangles"],
                                  "boundsRoundTrip": True, "uvRange": True, "openEdges": boundary_edges,
                                  "weldedContactEdges": junction_edges})
    for channel, relative in spec["textures"].items():
        img = bpy.data.images.load(str(OUT / relative), check_existing=False)
        assert tuple(img.size) == (1024, 1024), (name, channel, "texture size")
        bpy.data.images.remove(img)

# The primary portal must have no collision in its 20 x 13 clear opening.
for box in manifest["modules"]["SF_Portal_20"]["collisionBoxes"]:
    pos, size = box["center"], box["size"]
    intersects_x = pos[0] - size[0]/2 < 9.99 and pos[0] + size[0]/2 > -9.99
    intersects_z = pos[2] - size[2]/2 < 12.99 and pos[2] + size[2]/2 > 0.01
    assert not (intersects_x and intersects_z), ("Portal clear opening blocked", box["name"])
report["portalOpeningStuds"] = [20, 13]
(OUT / "verification.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("PASS: 14 mesh round trips, bounds/scale, UVs, triangles, closed surfaces, 28 texture files, portal collision opening")
