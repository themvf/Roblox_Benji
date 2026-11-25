# Resume here: lobby stone column

## Current truth

The user asked to convert `Lobby/sample_2026-11-09T190538.784.glb` at high quality. The original is preserved unchanged in `source/trellis-original.glb`. The GLB itself is the finish reference: a weathered pale blue-gray smooth column with a damaged capital and stepped base. Adjacent lobby images have different finishes and were not selected for this file. No exact target location, approved size, or collision role was supplied. This is a provisional 12-stud lobby decoration candidate.

Local intake, authoring, export, and saved-file verification are complete. `exports/LobbyStoneColumn.glb` is the delivery candidate, with 42,900 triangles across six meshes and two embedded 1024 PNG maps. `validation.json` records saved-file hashes and measurements. Visual approval, Studio import, and lobby integration are **pending**. Roblox IDs and saved placement are unknown.

## First unverified stage and next action

Show `review/final-quarter.png` and `review/final-front.png` for visual approval of the preserved blue-gray finish, damaged capital, and provisional 12-stud scale. Resolve decorative versus solid architectural collision before Studio setup. Once approved, import the exact saved GLB under the correct owner, verify actual texture and mesh IDs, appearance, dimensions, and physics in Studio. Place it in the repository-backed lobby source only after that review, following `docs/design/lobby-experience/EDITING.md`, and record restart evidence here.

## Work and evidence

- Source: `appraisal.json` records original SHA-256, one 286,003-triangle mesh, normalized size about 0.198 × 0.199 × 1.002, UVs, and two embedded 2048 WebP maps. `views.png` and `review/source-quarter.png` show the textured original.
- Geometry trial: `trials/decimate-{08pct,15pct}.glb` and `review/decimate-{08,15}-quarter.png` show textured reductions. The 8% trial has shaft artifacts; 15% preserves the all-angle shape and was selected.
- Reproducible source: `tools/blender/build_lobby_stone_column.py` scales to 12 studs, grounds the pedestal, partitions the 15% geometry into six meshes, preserves UVs and the original color, converts the maps to PNG, saves `source/LobbyStoneColumn.blend`, and exports the GLB.
- Saved export: `review/final-{quarter,front,side,rear}.png` was rendered from the written GLB with original materials and all four views were inspected. `review/export-appraisal.json` is a Blender reimport tied to the export hash. The export measures 2.383 × 2.400 × 12 studs with a ground pivot. `validation.json` records 42,900 triangles across six meshes (five at 8,500 and one at 400), two embedded 1024 PNGs, UVs, and saved-file hashes.
- Local checker: the full `python tools/build_lobby_stone_column.py` rebuild passed on 2026-11-09, followed by `--check-only` on saved files.
- Shared appraisal gate: `lune run tools/check_assets.luau` accepted `assets/models/lobby-stone-column`. Its overall run fails because the unrelated existing `assets/scenery/mud-grassland` package has no `appraisal.json`.

## Rebuild only when needed

Read this file, `README.md`, and `validation.json`, then run `python tools/build_lobby_stone_column.py --check-only`. Rebuild only after an approved revision or failed saved-file check. Generated files are backed up under `.mapbuild/lobby-stone-column/`. Do not treat local rendering as Studio appearance or placement evidence.

## Studio and lobby record

- Visual approval: pending
- Size and collision role: provisional 12-stud non-colliding decoration
- Roblox owner and mesh/texture IDs: unknown
- Studio scale, color, roughness, and collision: unverified
- Lobby position and saved source file change: unknown
- Restart persistence and published-game appearance: unverified
- Source control/off-machine backup: not established by this handoff
