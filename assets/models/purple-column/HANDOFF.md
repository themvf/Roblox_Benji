# Resume here: purple column

## Current truth

The user asked to convert `Lobby/Purple Column.glb` at **high quality**. The source GLB and adjacent purple reference are preserved in `source/`; the broader Roman-column concept is also saved. No exact target location, approved size, or collision role was supplied. This is a provisional **12-stud-high lobby decoration** candidate. Do not infer visual approval or a solid architectural/cover role.

Local intake, authoring, export, and saved-file verification are complete. `exports/PurpleColumn.glb` is the intended delivery file. It retains the chipped capital, fluted shaft, worn stone, and stepped pedestal at 42,819 triangles split across six meshes. Two named 1024 PNG maps are embedded; the color map has a violet tint matching the adjacent purple reference. The ground pivot and four textured saved-export views are verified locally. `validation.json` records current file hashes and measurements. Visual approval, Studio import, and lobby integration are **pending**. Roblox IDs and saved placement are unknown.

## First unverified stage and next action

Show the user `review/final-quarter.png` plus `final-front.png` for visual approval of the purple finish and provisional 12-stud scale. Resolve whether the column is non-colliding decoration or solid lobby architecture before setting collision. If approved, check for an existing valid Roblox upload; import the exact saved GLB under the correct owner, verify mesh/texture IDs, scale, material, and physics in Studio. For lobby placement, edit the repository-backed `Lobby.Geometry` source according to `docs/design/lobby-experience/EDITING.md`, save and rebuild the lobby, restart, and record runtime evidence here. Do not use a local GLB render as evidence of Studio appearance or placement.

## Work and evidence

- Source: `appraisal.json` records the original GLB SHA-256, one 285,461-triangle mesh, normalized size about 0.21 × 0.21 × 1.00, UVs, and two embedded 2048 WebP maps. `views.png` and `review/source-quarter.png` show the source shape.
- Optimization decision: `trials/decimate-{08pct,15pct}.glb` and `review/decimate-{08,15}-quarter.png` show both textured reductions. The 15% version kept more chipped capital and fluted-shaft detail while staying well below the original density; a single 10k-mesh reduction would discard about 96.5% of source triangles.
- Reproducible authoring: `tools/blender/build_purple_column.py` performs the reviewed 15% reduction, scales to 12 studs, grounds the base, preserves UVs while splitting into six meshes, converts both source maps to PNG, tints the color map purple, saves `source/PurpleColumn.blend`, and exports the final GLB.
- Saved-export review: `review/final-{quarter,front,side,rear}.png` was rendered from the written GLB with its original materials and inspected. `review/export-appraisal.json` is a Blender reimport tied to the export hash.
- Local checker: the full `python tools/build_purple_column.py` rebuild passed on 2026-11-09, followed by `--check-only` on saved files. The wrapper backed up prior generated files, rebuilt, rendered four saved-export views, appraised the GLB, and validated the package.
- Shared appraisal gate: `lune run tools/check_assets.luau` accepted `assets/models/purple-column`. Its overall run still fails because the unrelated `assets/scenery/mud-grassland` package has no `appraisal.json`.

## Rebuild only when needed

Read this file, `README.md`, and `validation.json`, then run `python tools/build_purple_column.py --check-only`. Rebuild only after an approved revision or failed saved-file check. The wrapper backs up generated outputs under `.mapbuild/purple-column/`. The `.blend` is generated; durable edits belong in the procedural builder. Reinspect textured views after changes. Do not apply `SetupDecoration.luau` if solid collision is desired.

## Studio and lobby record

- Visual approval: pending
- Size and collision role: provisional 12-stud non-colliding decoration
- Roblox owner and mesh/texture asset IDs: unknown
- Studio scale, color, roughness, and collision: unverified
- Lobby position and saved source file change: unknown
- Restart persistence and published-game appearance: unverified
- Source control/off-machine backup: not established by this handoff
