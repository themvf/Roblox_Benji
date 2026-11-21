# Resume here: snow utility vehicle

## Current truth

The user supplied a white sci-fi snow utility vehicle image and asked "now this" in the established asset-delivery workflow. `Snow Vehicles/Snow Utility Vehicle.glb` matches the image. The image and original GLB are preserved in `source/`. No size, map, driving behavior, or gameplay role was specified. This local delivery candidate is a **stationary visual prop** at a provisional 8.45 × 14.14 × 7 stud size. The user has not yet approved this output or the static role.

Local authoring, export, and saved-file verification are complete. The intended delivery file is `exports/SnowUtilityVehicle.glb`. It retains the source's recognizable textured body and tires at 70,178 triangles in nine meshes, with two embedded 1024 PNG maps and a ground-level pivot. `validation.json` records artifact hashes and the latest local result. Textured front, side, rear, and quarter renders from the saved GLB are in `review/final-*.png`. Visual approval, Studio import, and map integration are **pending**. Roblox IDs and any saved placement are unknown.

## First unverified stage and next action

Show the user `review/final-quarter.png` and `review/final-side.png` for visual approval, and confirm whether the intended role is stationary decor or an operable vehicle before any Studio physics or map integration. If approved as decor, check for an existing valid Roblox upload before importing this GLB. Verify owner, texture appearance, size, pivot, and physics in Studio. Apply `SetupDecoration.luau` only to the selected imported model. Save placement in the chosen map's decor collection and restart to verify persistence. Record actual evidence and IDs here. A drivable version needs a distinct rig, controls, seats, and collision design.

## Source and authoring evidence

- `appraisal.json`: source has one 280,713-triangle mesh, 0.60 × 1.00 × 0.49 normalized bounds, and two embedded 2048 WebP maps. Its source SHA-256 is recorded there. `views.png` and `review/source-quarter.png` show the all-angle textured shape.
- `trials/decimate-25pct.glb` and `review/decimate-quarter.png`: a 70,178-triangle reduction retains the main silhouette, including wheels and angular body. A single-mesh reduction to the Roblox 10,000 limit would discard about 96% of the source, so the retained mesh is divided into nine chunks of at most 8,500 triangles.
- `tools/blender/build_snow_utility_vehicle.py`: rebuilds from the preserved GLB, normalizes height to seven studs, sets tire bottoms at ground level, converts maps to PNG, splits geometry while preserving UVs, saves `source/SnowUtilityVehicle.blend`, and exports the final GLB.
- `review/export-appraisal.json`: independent Blender reimport of the saved GLB, checked against its hash. Final material views are `review/final-{quarter,front,side,rear}.png`.
- The full `python tools/build_snow_utility_vehicle.py` rebuild passed on 2026-10-22, followed by `--check-only` on the saved files. The full wrapper backed up prior generated outputs, rebuilt the asset, rendered four views, appraised the saved GLB, and validated it.
- The shared `lune run tools/check_assets.luau` gate accepted this package. Its overall run still fails on the unrelated `assets/scenery/mud-grassland` package, which lacks `appraisal.json`.

## Rebuild only when needed

Read this file, `README.md`, and `validation.json`. Run `python tools/build_snow_utility_vehicle.py --check-only` first. Rebuild only for a requested revision or a failed saved-file check. The wrapper backs up generated outputs under `.mapbuild/snow-utility-vehicle/`. The `.blend` is generated; update the procedural builder for durable changes. Visually review fresh renders after any rebuild. The 70k-triangle budget is suited to limited hero-prop use until Studio performance is observed; do not assume it is cheap to instance repeatedly.

## Studio and map record

- Visual approval: pending
- Intended role (static or drivable): provisional static prop; confirm with user
- Roblox owner and mesh/texture IDs: unknown
- Studio scale, textures, pivot, and physics: unverified
- Destination map and decor file: unknown
- Runtime restart and published-game appearance: unverified
- Source control/off-machine backup: not established by this handoff
