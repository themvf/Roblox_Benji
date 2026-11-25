# Resume here: sci-fi snowmobile

## Current truth

The user asked "now this" for `Snow Vehicles/Snowmobile.glb`. A matching concept image sits beside it. Both are preserved in `source/`. No destination map, size, or riding behavior was specified. The local delivery candidate is a **stationary visual prop** at a provisional 5.49 × 13.80 × 5.5 stud size. The user has not approved its appearance or confirmed that a static prop is the intended final role.

Local authoring, export, and saved-file verification are complete. `exports/Snowmobile.glb` is the intended delivery file. It has 71,692 triangles across nine meshes, two embedded 1024 PNG maps, and a ground-level pivot. `validation.json` records artifact hashes and checks. `review/final-{quarter,front,side,rear}.png` are textured views of the saved GLB. The skis, windshield, handlebars, seat, and rear track survived export. Visual approval, Studio import, and map integration are **pending**. No Roblox asset IDs or saved placement are known.

## First unverified stage and next action

Show the user `review/final-quarter.png` and `review/final-side.png` for visual approval. Confirm whether this should remain a static prop or become rideable before any Studio physics or map integration. If approved as decor, look for an existing valid upload before importing this GLB. Verify owner, texture result, dimensions, ground pivot, and physics in Studio. Use `SetupDecoration.luau` only for the selected stationary import. Save any map placement in the chosen decor collection, restart, and record runtime evidence and IDs here. A rideable variant requires a separate rig and gameplay implementation.

## Rideable version discussion (2026-10-24)

The user asked how to make this snowmobile drivable. The saved export was rechecked with `python tools/build_snowmobile.py --check-only` and passed; no rig or Studio import was created in this discussion. This is a potential change of role, not evidence that the current visual model moves. The nine exported meshes are slices of triangle order, not semantic body, ski, and track pieces. A first driving prototype can weld these as a non-colliding visual shell to a separate unanchored chassis with a real `VehicleSeat`, simple hidden collision and propulsion parts, and steering/suspension. A later polish pass should reauthor the front skis and rear track as distinct visual components if steering/track animation is needed. Validate seat input, stability, slopes, mobile controls, multiplayer ownership, and server-side movement bounds before calling it game-ready. Do not use `SetupDecoration.luau` on the driving rig.

## Work performed and evidence

- `appraisal.json`: the source is one 286,769-triangle mesh with normalized 0.40 × 1.00 × 0.40 bounds, two 2048 WebP maps, and the preserved source SHA-256. `views.png` and `review/source-{positive,negative}.png` show the textured model from front and rear quarters.
- `trials/decimate-25pct.glb` and `review/decimate-quarter.png`: 25% reduction yields 71,692 triangles while retaining the important silhouette. Reducing all the way to one 10,000-triangle mesh would discard about 96.5% of source triangles; this is not the chosen route.
- `tools/blender/build_snowmobile.py`: reproducibly decimates at the reviewed ratio, scales to 5.5 studs high, grounds the skis and track, converts both WebP maps to named PNGs, preserves UVs while splitting geometry, saves `source/Snowmobile.blend`, and exports the nine-mesh GLB.
- `review/export-appraisal.json`: Blender reimport of the saved GLB, checked against the file hash. The saved export was visually inspected in four textured views.
- The full `python tools/build_snowmobile.py` rebuild passed on 2026-10-22, followed by `--check-only` on the saved files. The full wrapper backed up prior generated outputs, rebuilt the asset, rendered four views, appraised the saved GLB, and validated it.
- The shared `lune run tools/check_assets.luau` gate accepted this package. Its overall run still fails on the unrelated `assets/scenery/mud-grassland` package, which lacks `appraisal.json`.

## Rebuild only when needed

Read this file, `README.md`, and `validation.json`. Run `python tools/build_snowmobile.py --check-only` first. Rebuild only for a requested revision or failed saved-file check; generated files are backed up under `.mapbuild/snowmobile/`. The `.blend` is generated, so durable edits belong in the procedural builder. Inspect fresh renders after any rebuild. The 71k-triangle result is intended for limited hero-prop use until Studio performance is checked.

## Studio and map record

- Visual approval: pending
- Final role (stationary or rideable): provisional stationary prop; confirm with user
- Roblox owner and mesh/texture asset IDs: unknown
- Studio scale, textures, pivot, and physics: unverified
- Destination map and decor file: unknown
- Runtime restart and published-game appearance: unverified
- Source control/off-machine backup: not established by this handoff
