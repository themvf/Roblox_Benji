"""Render the actual baked export meshes; staging is explicitly separate.
Can rerender the saved .blend without rebuilding/baking the kit.
"""
import bpy
import json
from pathlib import Path
from mathutils import Vector


def render_review(out):
    scene = bpy.context.scene
    stage = bpy.data.collections["REVIEW ONLY / assembly and scale references"]
    # Keep the staging foundation below the floor, never coplanar with it.
    foundation = bpy.data.objects["Review foundation"]
    foundation.location.z = -2.01
    foundation.dimensions.z = 3.98
    manifest = json.loads((out / "manifest.json").read_text())
    source_by_mesh = {bpy.data.objects[name].data: name for name in manifest["modules"]}
    placements = []
    for obj in stage.objects:
        if obj.type == "MESH" and obj.data in source_by_mesh:
            placements.append({"module": source_by_mesh[obj.data], "position": list(obj.location),
                               "rotationZ": obj.rotation_euler.z})
    (out / "review-assembly.json").write_text(json.dumps({"placements": placements,
        "note": "Review assembly only. New piers and returns change collision; not a live map patch."}, indent=2))
    views = [
        ("01-player-approach", (-25, -55, 2), (0, 3, 8)),
        ("02-entrance-detail", (-18, -30, 4), (0, 1, 8)),
        ("03-interior-bay", (5, 23, 5), (-15, 3, 6)),
    ]
    for name, eye, target in views:
        scene.camera.location = eye
        scene.camera.rotation_euler = (Vector(target) - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out / "renders" / (name + ".png"))
        if name == views[0][0]:
            # Relative image paths make the .blend folder portable.
            for image in bpy.data.images:
                filename = Path(image.filepath).name
                if filename and (out / "textures" / filename).is_file():
                    image.filepath = "//textures/" + filename
            bpy.ops.wm.save_as_mainfile(filepath=str(out / "SnowFortress_EntranceKit_v1.blend"))
        print("RENDER", name, flush=True)
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    output = Path(__file__).resolve().parents[2] / "assets/environment/snow-fortress/entrance-kit-v1"
    bpy.ops.wm.open_mainfile(filepath=str(output / "SnowFortress_EntranceKit_v1.blend"))
    render_review(output)
