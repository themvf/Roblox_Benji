# Snow utility vehicle

`exports/SnowUtilityVehicle.glb` is a detailed **stationary visual prop** based on `source/reference.png` and the matching `Snow Vehicles/Snow Utility Vehicle.glb`, preserved as `source/trellis-original.glb`. It is not a drivable vehicle or animated rig. The authoring size is approximately 8.45 studs wide × 14.14 long × 7 high, with a ground-level pivot. The hood is at Blender +Y; the GLB uses +Y up.

The original textured TRELLIS file has one 280,713-triangle mesh and two 2048 WebP maps. A textured 25% geometry reduction retained its cabin, body panels, fenders, and tire silhouettes in `review/decimate-quarter.png`. The delivered export preserves 70,178 triangles across nine meshes, each below Roblox's 10,000-triangle limit. Its two maps are saved as named 1024 PNGs in `textures/` and embedded in the GLB. This is still a detailed prop; avoid mass placement until Studio performance is checked.

## Build and check

From the repository root:

```powershell
python tools/build_snow_utility_vehicle.py
python tools/build_snow_utility_vehicle.py --check-only
```

The wrapper backs up generated outputs under `.mapbuild/snow-utility-vehicle/<timestamp>/`, runs the Blender builder, renders textured front, side, rear, and quarter views from the saved GLB, reappraises the export, and writes `validation.json`. Use `--blender <absolute path>` when Blender is not on PATH. The reproducible geometry and texture pipeline is in `tools/blender/build_snow_utility_vehicle.py`; manual edits to `source/SnowUtilityVehicle.blend` will be replaced by a rebuild.

`review/final-quarter.png`, `final-front.png`, `final-side.png`, and `final-rear.png` are views of the **saved export**. The original textured view is `review/source-quarter.png`; the 25% reduction trial is retained in `trials/`. See `HANDOFF.md` for verified stages and `STUDIO_SETUP.md` for engine-side checks.
