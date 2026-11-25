# radio-tower handoff

## Approved decisions (user, 2026-11-16)

- Subject: rusted steel lattice radio tower (two railed platforms, antennas, dish, ladder, base cabinets).
- Reference: user-supplied image, saved as `source/reference.jpg` (realistic style).
- Where: Snow Fortress (running place currently named MyMap).
- Role: `scenery` (seen only from far away), kind `prop`, height 60 studs, pivot bottom.
- Moving parts: none. Share: `public` (may be sold or shared) -> rights note in `provenance.json` must be filled before it leaves the game.
- Stop at the local build for approval; do not upload.
- Agent-chosen (user did not specify): package name `radio-tower`, about 2 copies on screen, TRELLIS seed 2.
- Budget: 60,000 triangles total, 10,000 per mesh. Route `scan` (auto).

## Stage

Stage 4 (local verification) reached. Stage 5 (user visual approval) NOT done. Stages 6-7 not started.

## Evidence (2026-11-16)

- `generate` with HF_TOKEN: seeds 1-3 made (~300k tris each), sheet `review/candidates.png`.
- `pick --seed 2` (cleanest lattice, keeps rust colour, dish and both platforms intact) -> `source/RadioTower.glb`, `provenance.json`, `appraisal.json`.
- `build` history:
  1. default decimate 59,747, auto-retry to tile [3,15]: 96,462 tris, 45 meshes -> FAIL over budget (tile seams add triangles).
  2. `scene.decimate` 37,000: 66,471 tris, surface error 0.086 -> FAIL over budget.
  3. `scene.decimate` 32,000: **59,121 tris, 45 meshes, worst mesh 4,899 -> PASS**. Surface error 0.122 worst view (warns over 0.08, fails over 0.15).
     Size 13.5 W x 59.9 H x 17.0 D studs, pivot bottom. Audit: no back-face patches over 0.15% (worst 0.03%).
- `lune run tools/check_asset_registry.luau`: radio-tower OK, not uploaded. `check_large_files.luau`: 0 problems (new files are not tracked yet).
- Agent look at `review/audit.png` / `audit_closeups.png`: silhouette, platforms, dish and lattice read correctly from a distance; some thin members slightly chunky. No `verdict` recorded - left for the user's eye.

## Open issues

- The mesh includes the reference's dirt/grass ground patch (~13x17 studs) at the base, which will not match snow. Options: bury it in snow terrain in Studio, or cut it off in a later build.
- Large files: `source/RadioTower.glb` 12.8 MB and `exports/RadioTower.glb` 7.8 MB. Each needs a line in `tools/large_files.json` before commit, or CI fails.
- `provenance.json` rights note must be filled in (share = public).

## Update 2026-11-16 14:57

- User: keep the dirt/grass base for now; not selling/sharing for now -> brief `share` set to `game`.
- User said "continue" after review -> `verdict radio-tower --looks good` recorded (surface error 0.122).
- Added both GLBs to `tools/large_files.json` with reasons.
- `publish radio-tower` dry run: size check pass, ready. `publish --confirm` NOT run yet; awaiting explicit
  upload go-ahead (user originally chose "stop at local build").

## Update 2026-11-16 14:59 - published

- User approved upload. `publish radio-tower --confirm` -> asset **132097701288704**
  (operation ed1bdddb-a5e5-46e8-9746-c88322aa7f77), recorded in `src/shared/AssetRegistry.json`.
- `check_asset_registry.luau`: radio-tower OK; open: Studio checks loads, facing, scale, materials, collision.
- `check_large_files.luau` currently FAILS on the two radio-tower lines only because the package is not tracked
  yet; it passes once `assets/models/radio-tower` is staged/committed (lines must stay).
- Stage 6 (Studio verification) NOT done. Stage 7 (map placement) NOT done. Uploading is not integration.

## Next action

1. Studio: insert asset 132097701288704 into Snow Fortress (MyMap), check it loads, faces the right way,
   is ~60 studs tall, textures are rusty brown (not grey/white), and that the visual mesh has CanCollide off
   with a simple invisible collision block. Then
   `python tools/asset_generate.py verify radio-tower --check loads --check facing --check scale --check materials --check collision`.
2. Save it into the Snow Fortress decor (`assets/environment/decor/`), restart test.
3. Commit the package plus `tools/large_files.json` and `src/shared/AssetRegistry.json`.

## Earlier next actions (superseded)

1. `python tools/asset_generate.py publish radio-tower --confirm` (done 14:59).
2. Studio: `verify` checks, place in Snow Fortress decor.

## Previous next action (superseded)

1. User reviews `review/audit.png`, `review/audit_closeups.png`, `review/detail.png`; then
   `python tools/asset_generate.py verdict radio-tower --looks good|bad`.
2. If approved: add the large_files.json entries, then `publish radio-tower` (dry run) -> `publish --confirm` only with user approval.
3. Studio: `verify` checks, place in Snow Fortress decor.

## Update 2026-11-16 (later) - upload is not usable; rebuild on the clean route

- User saw asset 132097701288704 in Studio beside the fortress wall: struts torn and see-through, white speckles.
  `review/verdict.json` now says `bad`, in the user's words. The earlier `good` was recorded from "continue".
- Cause: the reduction, not the generator. `audit radio-tower --seed 2` on the picked source shows 0% back faces
  in every view; the export shows 6-9% (`review/audit.json`, re-run with the corrected audit). The old audit
  only counted solid patches and its close-ups framed the whole tower, so it reported nothing.
- The brief's `scenery` role does not match the placement: a player can walk up to it.
- Next action: ask the user how close players get, then `brief radio-tower --role decor --nearest <studs>
  --thin yes --route clean` and write `tools/blender/build_radio_tower.py` (legs, braces, two platforms,
  railings, dish and mast from simple shapes; the picked source is the shape guide). Do not place the
  current upload in a map.
