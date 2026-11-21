# Resume here: futuristic office desk

## Latest session (2026-09-28): re-verified, blocked on a wrong source path

Stage 4 was re-verified and still passes. Stages 5-7 are unchanged. Nothing was
regenerated, uploaded, placed or committed.

`python tools/build_desk.py --check-only` -> `PASS: desk package checked.`
`validation.json` `checkedAtUtc` `20260928T172931737770Z`, status `passed`.
Every SHA-256 in `filesSha256` is unchanged from the 2026-09-27 record, including
`exports/Desk.glb` = `d4a7d95c...93e4d2`. Measured 5,828 triangles, bounds
X -7..7, Y 0..2.9993, Z -1.9410..1.9410. `lune run tools/check_assets.luau`
reports `OK assets/models/desk 5828 tris relief 0.2142`; its non-zero exit is
still only the pre-existing missing `assets/scenery/mud-grassland/appraisal.json`.
`review/prototype-front-quarter.png` was opened and matches the approved desk.

The requested work named a new desk source, `Cargo/sample_2026-09-27T180812.345.glb`.
That file is not a desk, and no desk was built from it:

- Its SHA-256 is `9B5448B934441FE801A37B89CD3F6205E3C1BA39C7E8795706CA104A55064641`,
  byte-identical to `assets/models/cargo/source/trellis-original.glb`.
- It is the already-consumed bake source for the **destroyed cargo unit** in
  `assets/models/cargo` (12.56 MB, 294,974 triangles, two 2048 WebP textures).
  Its textured views are `assets/models/cargo/review/source-a..d.png`, opened
  this session: a burnt, torn-topped shipping container. No desk geometry.
- The only desk source in the repository is `Desks/sample_2026-09-27T174041.800.glb`
  (`bf8e2377...8c8e15b8`), which is already `source/trellis-original.glb` here.
  A full `.glb` sweep of the workspace found no newer or unprocessed desk source.

Building a desk from that file was not attempted, and the approved desk was not
rebuilt. Per CLAUDE.md, asking what an asset is *of* before pointing a pipeline at
it is the gate that catches exactly this mismatch.

## Stage 6 started: this GLB uploaded (2026-09-28)

`exports/Desk.glb` was imported through Studio's 3D Importer and the Import Queue
showed success. Evidence is a screenshot of that queue, in a batch that also
uploaded `assets/models/cargo/exports/CargoDestroyed.glb` and failed on
`assets/models/cargo-b/exports/CargoUnit.glb`.

So the desk is no longer parked: it is imported but not configured. **Do not import
it again** -- reuse this upload and duplicate the model for further placements, per
the streamlining rule in docs/design/ASSET_DELIVERY_WORKFLOW.md.

Not yet established: mesh and texture asset IDs, owner, whether the textures
resolved, whether the size read 14 x 3 x 3.9, and whether `SetupDecoration.luau`
has been run. A GLB carries no Roblox physics properties, so until that helper runs
the desk is unanchored with whatever collision Studio defaulted to. Questions 2-4
below are still open.

## Blocking question (2026-09-28): ANSWERED -- option b

The user chose the cargo unit: "I want this one. I don't care if it's not a desk."
Active work moved to `assets/models/cargo`. **This desk package is parked**, still
stage 5 complete / stage 6 not started, artifacts verified unchanged. Do not
rebuild it. Resume it only when the user asks for the desk again, at
"Next engineer's first steps" below.

The original question, kept for the record:

- **a.** Continue this approved desk. Then the work is stage 6, Studio import and
  verification, which needs the user in Studio. See "Next engineer's first steps".
- **b.** Approve or revise the destroyed cargo unit. It is a different package,
  `assets/models/cargo`, sitting at stage 5 with its own four questions in
  `assets/models/cargo/HANDOFF.md`. Its render was opened this session and looks
  correct against its reference, allowing for the cooler blue-grey tint noted there.
- **c.** A genuinely new desk variant. Then supply the Midjourney reference and
  the TRELLIS GLB for it; neither exists in the repository yet.

Do not guess between these. Option c costs a full rebuild.

## Current truth (2026-09-27)

Stage 5, visual approval: the user approved the desk ("That looks perfect!")
after asking for the file path to import and test it. Do not regenerate it or
reopen the look. The approved file is `exports/Desk.glb`, SHA-256
`d4a7d95cef08cf6bec3d2d4698e762977ce5d37fc599a4a65b2fc4f21693e4d2`.
The user did not say whether that approval followed a Studio import, so stage 6
is still unverified. The 14 x 3 x 3.9 stud size was not explicitly confirmed
separately; collision role and target map (questions 3-4) remain open.

The delivery file is `exports/Desk.glb`, not anything in `trials/`. Local checks
passed: 5,828 triangles (budget 8,000), one mesh and material, 1024 PNG textures,
bottom pivot, length 14 on X, height 3.0. Evidence: `validation.json`,
`appraisal.json`, and the four `review/prototype-*.png` renders, which were viewed.
No Studio import, upload, owner, asset IDs, physics, or placement has been observed.

## Decisions made so far

- Authority: the Midjourney image. The TRELLIS GLB is reference only.
- Clean rebuild, not optimization: one-mesh decimation shredded the surfaces
  (`review/trellis-decimate-9000.png`), and TRELLIS invented a second pod and a
  sunken screen well that the reference does not have.
- Surface detail is recreated (modelled seams, door, display, tablet, controls);
  nothing is baked from the TRELLIS textures.

## Open questions for the user

1. Look: answered, approved 2026-09-27.
2. Is 14 studs long by 3 studs high right? Depth is 3.9 studs.
3. Role: non-colliding decoration (current helper default), or a solid prop
   players bump into (`SOLID = true` in `SetupDecoration.luau`, box collision)?
   Cover a player relies on belongs in the map's Lua blocks instead.
4. Which map, and has any desk already been imported or uploaded?

## Next engineer's first steps

1. Read this file, `README.md`, and `validation.json`.
2. From the repo root run `python tools/build_desk.py --check-only`.
3. Get answers to the questions above and record them here. Change geometry only
   in `tools/blender/build_desk.py`, then run `python tools/build_desk.py` and
   view the regenerated renders before asking again.
4. After approval: import `exports/Desk.glb` with Stud units, check textures and
   size, select only the desk and run `SetupDecoration.luau`.
5. Place via `assets/environment/decor/README.md`, preserving existing decor.
   Restart the map and verify. Record IDs and evidence below.

## Do not repeat failed work

- Do not treat `Cargo/sample_2026-09-27T180812.345.glb` as a desk source. It is the
  destroyed cargo container already consumed by `assets/models/cargo`. Hash the
  supplied file against the existing packages' `source/trellis-original.glb` before
  starting; identical bytes mean the asset is already intake-complete elsewhere.
- Do not decimate the TRELLIS GLB again to one mesh; it failed visual review.
- Preview defaults to clay; texture reviews need `--materials original`.
- Negative preview coordinates need `--eye=-12,8,16` form, not `--eye -12,...`.
- Write JSON from Python, not Windows PowerShell 5 `Set-Content -Encoding utf8`,
  which adds a BOM that breaks the wrapper's JSON reads.
- `lune run tools/check_assets.luau` lists the desk as OK; its non-zero exit is
  the pre-existing missing `assets/scenery/mud-grassland/appraisal.json`.

## Transfer

Keep this package with `tools/build_desk.py`, `tools/blender/build_desk.py`, the
`desk` entry in `tools/blender/scenes.json`, and the shared Blender tools. All of
it is uncommitted local work; commit or back up for off-machine recovery. The
original `Desks/` folder was left untouched.

## Studio record (fill only from observed evidence)

- Stage: 5 complete. Stage 6 upload accepted 2026-09-28; not yet configured or placed.
  Next action: run SetupDecoration.luau on the imported desk and record IDs here.
- Upload accepted: yes, 2026-09-28 (Studio Import Queue success). Do not re-import.
- Local re-verification: passed 2026-09-28, artifacts unchanged (see top section).
- Visual approval: approved 2026-09-27 ("That looks perfect!")
- Asset owner: unknown
- Mesh and texture asset IDs: unknown
- Target map and decor file: unknown
- Imported size / textures: unverified
- Physics settings: unverified
- Restart persistence / published game: unverified
