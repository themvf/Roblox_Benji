"""Test using preserved scan surface detail over a clean articulated underbody.

The output is deliberately a trial: scan triangles are open and not suitable as
Marketplace geometry. It answers whether their texture/detail can guide a more
faithful clean rebuild without returning to the broken full scan segmentation.
"""
from pathlib import Path
import json

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentrySourceDetailShell"
TRIAL.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(PKG / "trials/SciFiSentryCleanBody/SciFiSentryCleanBody.blend"))

# Remove simplified shell but retain the clean closed body underneath, plus
# limb plates whose boundaries can be redesigned after this comparison.
for obj in list(bpy.data.objects):
    if obj.name.startswith(("Head__", "UpperTorso__", "LowerTorso__")):
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=str(PKG / "source/SciFiSentrySource.glb"))
source = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"][0]
decimate = source.modifiers.new("Reference detail, quarter density", "DECIMATE")
decimate.ratio = .25
bpy.context.view_layer.objects.active = source
bpy.ops.object.modifier_apply(modifier=decimate.name)

regions = {
    "Head": (.28, .51, .18),
    "UpperTorso": (.075, .28, .145),
    "LowerTorso": (-.065, .075, .14),
}
counts = {}
for name, (z0, z1, xlimit) in regions.items():
    copy = source.copy()
    copy.data = source.data.copy()
    bpy.context.collection.objects.link(copy)
    copy.name = name + "__original detail guide"
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    discard = [face for face in bm.faces if not (z0 <= face.calc_center_median().z < z1
                                               and abs(face.calc_center_median().x) <= xlimit)]
    bmesh.ops.delete(bm, geom=discard, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    counts[name] = len(bm.faces)
    bm.to_mesh(copy.data)
    bm.free()
    copy.scale = (5.5, 5.5, 5.5)
    copy.location.z = 2.75
    copy.hide_render = counts[name] == 0
bpy.data.objects.remove(source, do_unlink=True)

scene = bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentrySourceDetailShell.blend"))
for label, at in (("front", (7, -11, 6)), ("side", (12, 0, 5))):
    bpy.ops.object.camera_add(location=at)
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.7
    scene.camera = camera
    scene.render.filepath = str(TRIAL / (label + ".png"))
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

(TRIAL / "manifest.json").write_text(json.dumps({
    "status": "source detail transfer guide; not a deliverable mesh",
    "sourceTrianglesByRigidGuideRegion": counts,
    "limitations": ["unclosed scan surfaces", "no source detail on clean limb plates",
                    "reference-only positional cuts", "no rig or Marketplace validation"],
}, indent=2) + "\n", encoding="utf-8")
print("SOURCE DETAIL REGION COUNTS", counts)
