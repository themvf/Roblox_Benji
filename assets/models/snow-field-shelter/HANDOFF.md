# Resume here: snow field shelter

## Current truth

The user supplied a black arched field shelter reference and asked "now this" in the established Roblox asset workflow. The adjacent `Snow Props/Tent.glb` was preserved as `source/trellis-original.glb`; the image was preserved as `source/reference.png`. No explicit shelter size, map, or interactivity was supplied. This candidate is a **closed decorative shell** at a provisional 24 × 32 × 14 stud authoring size. Do not treat that provisional role or the appearance as user-approved.

Local authoring, export, and saved-file verification are complete for **two separate variants**. `exports/SnowFieldShelter.glb` is the closed version; `validation.json` records 15,528 triangles across seven material meshes, eight embedded PNG maps, and world dimensions of 24.56 × 32.805 × 14.231. `exports/SnowFieldShelter_OpenDoor.glb` is the user's requested additional version; `validation-open.json` records 16,780 triangles across eight meshes, nine embedded PNG maps, and world dimensions of 24.56 × 35.617 × 14.231 including the protruding door. Textured saved-export previews were inspected from front, side, rear, and quarter views for both. The open version has a cut-through aperture, a door fixed at about 76 degrees, a threshold, and short interior walkway. Neither version has visual approval, a Studio import, or map integration. No Roblox asset IDs or saved placement are known.

## First unverified stage and next action

Show the user `review/open-quarter.png` and `review/open-front.png` for visual approval of the **open-door** variant; the closed version remains intact. Confirm whether the opening is meant only as visual decoration or for player entry before creating any collision or route contract. If approved, check whether an upload already exists, then import the chosen saved GLB into the intended Studio place and inspect scale, textures, and physics. Apply the variant's decoration helper only if it remains non-colliding decor. Record observed asset IDs and owner; then resolve the destination map, save its decor collection, restart, and verify runtime appearance. Keep these stages separate.

## Work performed and decision evidence

- Source appraisal: one 279,190-triangle mesh, two embedded images, approximately 1.002 × 0.769 × 0.443 in source units; SHA-256 is recorded in `appraisal.json`.
- Source and reference textured review: `review/source-quarter.png` and `views.png` show the generated model is recognizable as the supplied tent.
- Rejected optimization: `trials/decimate-9000.glb` and `review/decimate-quarter.png` show torn fabric, window frames, and front arch at 8,933 triangles. Do not resume this decimation route without new evidence.
- Clean rebuild: `tools/blender/build_snow_field_shelter.py` creates a procedural editable scene, seven material-grouped export meshes, recreated fabric folds and wear, the outer and inner front arches with triangular truss, two windows on each long side, and a closed white door.
- Export appraisal: `review/export-appraisal.json` was made by reimporting the saved GLB; the local checker enforces its export hash and dimensions.
- Builder and local check: the full `python tools/build_snow_field_shelter.py` rebuild passed on 2026-10-22, followed by `--check-only` on the saved files. The full wrapper backed up prior generated outputs, authored the scene, rendered four saved-export views, appraised the export, and validated it.
- Open-door version: the procedural builder's `--doors-open` path creates `source/SnowFieldShelter_OpenDoor.blend` and a separate GLB. The full `python tools/build_snow_field_shelter_open.py` rebuild passed on 2026-10-22, followed by `--check-only` for both versions. `review/open-export-appraisal.json` reimports the open GLB. `review/open-{quarter,front,side,rear}.png` shows the saved GLB; the doorway is a real aperture rather than a door placed on an uncut wall.
- Shared appraisal gate: `lune run tools/check_assets.luau` accepted `assets/models/snow-field-shelter`; its overall run still fails because the unrelated `assets/scenery/mud-grassland` package has no `appraisal.json`.

## Rebuild only when needed

Read this handoff, `README.md`, `validation.json`, and `validation-open.json`, then run both `python tools/build_snow_field_shelter.py --check-only` and `python tools/build_snow_field_shelter_open.py --check-only`. Rebuild only the version that needs a change. The wrappers back up generated files under `.mapbuild/snow-field-shelter/` and `.mapbuild/snow-field-shelter-open/`. The `.blend` files are generated; change the procedural builder to preserve edits. Inspect fresh texture renders after any rebuild. Do not infer Studio or map success from a local pass.

## Studio and map record

- Visual approval: pending
- Open-door gameplay passage and collision contract: unresolved; no claim of player access
- Roblox owner: unknown
- Mesh and texture asset IDs: unknown
- Studio import and texture appearance: unverified
- Physics and collision: unverified
- Target map and decor file: unknown
- Restart persistence and published-game appearance: unverified
- Source control/off-machine backup: not established by this handoff
