# Sci-fi snowmobile

`exports/Snowmobile.glb` is the local delivery candidate from the supplied `Snow Vehicles/Snowmobile.glb`, preserved as `source/trellis-original.glb`. The matching concept image beside it is preserved as `source/reference.png`. The current version is a **stationary visual prop**, not a rideable snowmobile. Its provisional dimensions are about 5.49 studs wide × 13.80 long × 5.5 high, with a ground-level pivot. The nose and skis point toward Blender +Y; the GLB uses +Y up.

The original TRELLIS mesh has 286,769 triangles in one mesh and two 2048 WebP maps. A textured 25% reduction preserved the front skis, windshield, handlebars, seat, and rear track in `review/decimate-quarter.png`. The saved export has 71,692 triangles split among nine meshes below Roblox's 10,000-triangle per-mesh limit. `textures/Snowmobile_Color.png` and `Snowmobile_MetalRough.png` are named 1024 PNG copies embedded in the GLB. This is a detailed hero prop; repeated placement needs a Studio performance check.

## Rebuild and verify

From the repository root:

```powershell
python tools/build_snowmobile.py
python tools/build_snowmobile.py --check-only
```

The wrapper backs up generated files under `.mapbuild/snowmobile/<timestamp>/`, rebuilds the editable scene and GLB, renders four textured views from the saved export, appraises the export, and writes `validation.json`. Use `--blender <absolute path>` if Blender is not on PATH. `tools/blender/build_snowmobile.py` is the authoritative reproducible builder. Direct edits to `source/Snowmobile.blend` will be replaced by a rebuild.

`review/final-{quarter,front,side,rear}.png` are views of the saved GLB. The original and reduction views are in `review/`; the reduction GLB is in `trials/` and is not the delivery file. See `HANDOFF.md` for stage evidence and `STUDIO_SETUP.md` for Roblox-specific checks.
