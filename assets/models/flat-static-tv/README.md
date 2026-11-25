# Flat static TV

The supplied `TV/static tv.glb` has a deep cabinet and a stand. The user
specified a **flat TV with no stand**, so the delivery is a clean rebuild.
The blue static screen was cropped from the supplied `TV/statictv.png` image;
`TV/blacktv.png` and the original GLB are preserved in `source/` as references.

## File to upload

Import `exports/FlatStaticTV.glb` into Roblox Studio. It is 8 studs wide,
4.6 studs high, and 0.285 studs deep. Its back is at Z=0, its bottom at Y=0,
and the screen faces positive Z. These dimensions are provisional. The export
contains two named meshes: `TV_SlimFrame` and `TV_StaticScreen`. The screen
texture is embedded as PNG and is also saved as `textures/StaticScreen.png`.
It is a still image of static, not an animated broadcast.

After import, group and anchor both MeshParts. Place the flat back against a
wall. Confirm the static screen texture appears on `TV_StaticScreen` in the
target lighting, then save the place. The GLB was prepared locally; Studio
import, placement, and publication have not been verified.

## Rebuild and evidence

From the repository root:

```powershell
python tools/build_flat_static_tv.py
```

The builder crops the screen image, makes the standless panel in Blender,
exports the GLB, and checks piece count, dimensions, thinness, texture format,
and hashes. `validation.json` is the latest result. The written export was
rendered from front, side, and rear in `review/`; the local upload-size dry
run passed.
