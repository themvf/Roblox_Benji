# Resume here: separate surgical-room props

## Current truth (2026-10-17)

The user supplied `Surgery/sample_2026-10-18T000819.948.glb` to be repaired as a surgeon's table, then asked to create the visible pieces as separate items. The current delivery candidates are four independent GLBs:

| Item | Export | Placement |
| --- | --- | --- |
| Operating table | `exports/SurgicalTable.glb` | Own ground pivot; padded bed, pedestal, wheels and support rails |
| Surgical lights | `exports/SurgicalLights.glb` | Own ground pivot; freestanding two-head rig |
| Patient monitor | `exports/PatientMonitor.glb` | Own ground pivot; separate wheeled cart |
| IV stand | `exports/IVStand.glb` | Own ground pivot; wheeled tripod and bag |

These are local candidates. User visual approval, exact scale and role, Studio import, and map integration have not been observed. No earlier asset in this package was approved. The prior all-in-one candidate, SHA-256 `0824555854517f27da77b876db37cc10d58108b373f73cbfa9961497392ad328`, is preserved under `trials/SurgicalTable_Combined.glb` with its validation and previews for comparison. Do not use that trial as one of the current four deliveries.

## Source, decisions and authoring evidence

- `source/trellis-original.glb` is an unchanged copy of the user's file, SHA-256 `17c2b311b64c5e6d43d9585456c3001fba7998b074dacd09fc30d8d285b0d45f`. `source/design-reference.png` copies the neighboring `Surgery/` concept image. The original files remain untouched.
- `appraisal.json` and `views.png` document the original single 286,566-triangle, UV-mapped open mesh with 234,976 open edges. Textured front, side and top views were inspected. The bed, overhead lights, monitor and IV equipment are identifiable, but the thin detail is entangled with the table and would not survive direct reduction into one Roblox-sized mesh. Clean geometry with recreated finishes was chosen.
- `tools/blender/build_surgical_table.py` is the authoritative reproducible geometry source. `source/SurgicalTable.blend` keeps the editable assembled arrangement; the builder separates it by item and material before export. `tools/make_surgical_table_texture.py` creates the blue-vinyl map embedded in the table GLB. Metal, polymer, rubber, screen and light finishes use material factors.
- The monitor was given its own wheeled cart; the IV pole and overhead light rig already have their own bases. All four exports are recentered at their individual ground pivots. `source/assembly-layout.json` records Roblox XYZ offsets for recreating the reference arrangement from one set origin. Those offsets are a layout aid, not observed Studio placement.
- The current reference image includes separate consoles and loose cables that were not recreated. The result focuses on a legible operating table and three distinct associated props. The two lamps remain on one shared rig; they are not two separate uploads.

## Local verification

- `python tools/build_surgical_table.py` rebuilds the four GLBs, backs up generated files under `.mapbuild/surgical-table/`, renders exported-file front/side/rear/quarter views for each item, and records structure and hashes in `validation.json`. `python tools/build_surgical_table.py --check-only` checks saved artifacts without rebuilding.
- `review/{table,lights,monitor,iv}-{front,side,rear,quarter}.png` are the views from the actual written GLBs. They were inspected. Initial tall-item cameras clipped some objects; those camera views were reframed before handoff. Do not infer approval from those local images.
- Each export uses glTF Y-up, has a centered ground pivot, UV coordinates, identity node transforms and meshes under Roblox's 10,000-triangle per-mesh cap. See `validation.json` for exact per-file triangle counts, bounds, byte sizes and SHA-256 hashes. Only the table embeds a 1024-pixel PNG; other exports use material factors without texture files.
- `lune run tools/check_assets.luau` recognizes the surgical-table package. The repository-wide gate's known unrelated failure is `assets/scenery/mud-grassland`, which lacks `appraisal.json`.

## Production contract and next action

- Import each approved GLB separately with Studio Scale Unit **Stud**. The table's head faces +X. The light rig, monitor cart and IV stand can be placed or duplicated independently. `STUDIO_SETUP.md` has the Studio checks and the local assembly offsets.
- The GLBs are visual props. No interactive Seat, medical behavior, live Roblox Light instances, anchoring or collision settings are included. Decide each item's role and physics during Studio verification.
- First review the four quarter views with the user, record any requested changes or approval tied to the exact corresponding export hashes, and preserve approved outputs. Then verify owner, asset IDs, scale, material appearance, physics and the assembled layout in Studio. Map placement and restart persistence are separate final stages.

## Studio record (observed evidence only)

- Visual approval: pending for all four items.
- Owner and mesh/texture IDs: unknown.
- Imported size, materials, lighting and physics: unverified.
- Destination map, placement and restart persistence: unverified.
