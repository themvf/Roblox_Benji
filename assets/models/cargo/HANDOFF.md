# Resume here: destroyed cargo unit

## Current truth and next action (2026-10-11)

The user asked to “fix this one too” for
`Cargo/sample_2026-09-27T180812.345.glb`, after requesting a more weathered,
broken, ransacked look for another cargo unit. This package was already an
optimized destroyed cargo with torn top and side openings. The shape survived
optimization, so this revision retained its geometry and improved the material
toward the warm, weathered gunmetal of `source/design-reference.png`.

Stage 4 local verification passed for the **new** `exports/CargoDestroyed.glb`:
SHA-256 `990cb74f94bbf68fd39f351dbfa3a90714bd1f61c69aa25d0929347bffac982b`,
7,470 triangles, one mesh/material, three embedded 1024 PNG maps, bounds
X -5.1564..5.1564, Y 0..6, Z -2.5623..2.5623, bottom pivot. The full
`python tools/build_cargo.py` author/export/appraise/four-view render/validate
pipeline passed, followed by `python tools/build_cargo.py --check-only` passing.
The current hashes and limitations are in `validation.json`.

All current `review/prototype-*.png` views were inspected. Agent assessment:
the warmer chipped metal reads closer to the reference, and torn openings remain
clear from either long-side quarter. The short end is relatively intact; prefer
showing a long side in placement. This is **not user visual approval**. The model
still has no observed loose contents or debris outside the hull, so “ransacked”
has only been interpreted as the torn, opened shell already in the source. If
the user wants visible spilled contents, that requires a separate geometry pass.

The old export that Studio accepted on 2026-09-28 is preserved at
`trials/CargoDestroyed-pre-warm-20260928.glb` with SHA-256
`3b976e41c7e7a81eb69314007d1caeb9d1335292996f862052b06db06e8d9c27`;
its front-quarter preview is also in `trials/`. **Do not re-import that exact
old file.** The revised export has a different hash and has not been imported.
The Studio acceptance of the old file does not verify this revision.

Next action: obtain visual approval of `review/prototype-front-quarter.png` and
`review/prototype-rear-quarter.png`, including whether the damage is strong
enough. After approval, import this revised GLB once with Stud units; verify
its textures and size in Studio, record the new asset IDs/owner, then apply
`SetupCargo.luau` to the selected model. Map integration and restart checks
remain later, separate stages. The six-stud height and final collision role
remain provisional.

## Prior prototype record (2026-09-27)

Stage 4, local verification, passed for the first prototype. Stage 5, visual approval,
was next at that time.
The user chose this GLB (`Cargo/sample_2026-09-27T180812.345.glb`). The user
has not approved the look, the six-stud height (10.3 x 6 x 5.1 studs) or the
role. The agent chose those and they are unconfirmed.

The delivery file is `exports/CargoDestroyed.glb`. Nothing in `trials/` is a
delivery file. Local checks passed:

- 7,470 triangles, within the 8,000 budget.
- One mesh and one material.
- Three 1024 PNG maps, including a normal map.
- Bottom pivot and a height of 6.

Evidence is in `validation.json`, `appraisal.json` and the four
`review/prototype-*.png` renders, which were viewed. No Studio import, upload,
asset IDs, physics or placement has been observed.

## Session 2026-09-28: this is the selected asset, stage 4 re-verified

The user named `Cargo/sample_2026-09-27T180812.345.glb` and confirmed they want
this asset worked on, explicitly accepting that it is not a desk ("I want this
one. I don't care if it's not a desk"). That settles *which* asset. It is not
look approval, a size approval, or a role decision; questions 1-4 below are still
open. The earlier desk/cargo path confusion is recorded in
`assets/models/desk/HANDOFF.md`; that package is untouched and still at stage 5.

Confirmed the named file is this package's existing intake, so nothing was
regenerated: its SHA-256 is
`9b5448b934441fe801a37b89cd3f6205e3c1ba39c7e8795706ca104a55064641`, identical to
`source/trellis-original.glb` in `validation.json`.

Stage 4 re-verified. `python tools/build_cargo.py --check-only` ->
`PASS: cargo package checked.` `validation.json` `checkedAtUtc`
`20260928T184844840293Z`, status `passed`, 7,470 triangles, one mesh
`geometry_0.001`, three 1024 PNG maps, bounds X -5.1564..5.1564, Y 0..6.0,
Z -2.5623..2.5623, bottom pivot. Delivery file `exports/CargoDestroyed.glb`
= `3b976e41c7e7a81eb69314007d1caeb9d1335292996f862052b06db06e8d9c27` (3.95 MB).
`lune run tools/check_assets.luau` -> `OK assets/models/cargo 7470 tris relief
0.4969`; its non-zero exit remains only the pre-existing missing
`assets/scenery/mud-grassland/appraisal.json`.

All four `review/prototype-*.png` were opened and compared against
`source/design-reference.png`. Agent assessment, not user approval:

- Silhouette, corner blocks, vertical panel seams, the small vent grille, base
  skids and the torn top edge all survive and read from every angle.
- Colour is the one real divergence. The reference is a warm brown-grey gunmetal
  with rust highlights; the export reads cooler, darker and sootier. This is the
  TRELLIS tint carried through the bake, as recorded in README.md.
- From the short end (`prototype-end.png`) the damage barely reads; that view is
  close to an intact box. Prefer placements that show a long side.

Nothing was uploaded, placed, published or committed.

## Stage 6 started: this GLB uploaded (2026-09-28)

`exports/CargoDestroyed.glb` was imported through Studio's 3D Importer and the
Import Queue showed success. Evidence is a screenshot of that queue; the sibling
`assets/models/cargo-b/exports/CargoUnit.glb` failed in the same batch with a
Roblox-side `Internal` error, and `assets/models/desk/exports/Desk.glb` succeeded.

What this does and does not establish. It establishes that the upload was accepted,
so **this asset must not be imported again**: reuse the existing upload and
duplicate the model for further placements, per the streamlining rule in
docs/design/ASSET_DELIVERY_WORKFLOW.md. It does not establish the mesh or texture
asset IDs, the owner, that the textures resolved correctly, that the height read 6,
or that `SetupCargo.luau` has been run. All of those are still unrecorded below.

Still outstanding for this package: `SetupCargo.luau` has to be run on the imported
unit, because a GLB carries no Roblox physics properties, so until then it is
unanchored and its collision flags are whatever Studio defaulted to.

## Next action (2026-09-28)

Stage 5 needs the user's eye on `review/prototype-front-quarter.png`, plus a
decision on the colour: accept the cooler tint, or warm it toward the reference.
A tint is a texture-level change in `tools/blender/build_cargo.py` followed by
`python tools/build_cargo.py` (about 6 minutes) and a fresh render review; the
geometry would not change. Stage 6 cannot be advanced by this agent: it needs the
user in Studio. Answers to questions 2-4 are required before stage 7 placement.

## Decisions made so far

- Optimization, not a rebuild. The TRELLIS silhouette survives, so the shape is
  kept and the detail is baked from the dense source. The method and failed
  rounds are in README.md.
- `source/design-reference.png` is the matching Midjourney image. Other
  `Cargo/` images and the other GLB are separate designs. They have not started.

## Questions for the user (stage 5)

1. Is the look in `review/prototype-front-quarter.png` right? It is cooler and
   bluer than the warm reference. Should it be tinted?
2. Is six studs tall right? A character is about 5, so it blocks sight lines.
3. What is its role? Options:
   - Non-colliding decoration. This is the current `SetupCargo.luau` default.
   - A solid prop (`SOLID = true`).
   - Gameplay cover. Cover must be authored as map Lua blocks, not decor.
4. Which map will it go on? Should the other cargo designs follow?

The second design has since been built: the intact white unit is
`assets/models/cargo-b`, also at stage 5, six studs tall to match this one.
Approving one does not approve the other. The third `Cargo/` GLB
(`sample_2026-09-27T175344.993.glb`) has not been started.

## Next engineer's first steps

1. Read this file, `README.md` and `validation.json`.
2. Run `python tools/build_cargo.py --check-only`.
3. Record the answers here. Change the output only through
   `tools/blender/build_cargo.py`, rebuild, and view the renders again.
4. After approval, import with Stud units and check the textures and height.
   Select only the unit and run `SetupCargo.luau`.
5. Place it using `assets/environment/decor/README.md` and preserve the
   existing decor. Restart the map to verify, then record IDs and evidence below.

## Do not repeat failed work

- Do not bake colour with DIFFUSE. It is base x (1 - metallic), so metal bakes black.
- Do not collapse the raw TRELLIS soup or weld it before collapse. Remesh first.
- Negative preview coordinates need the `--eye=-14,10,17` form.
- Write JSON from Python, not PowerShell 5 `Set-Content -Encoding utf8`,
  which adds a BOM.
- `check_assets` reports cargo as OK. It still exits non-zero because of the
  pre-existing missing `assets/scenery/mud-grassland/appraisal.json`.

## Transfer

Keep this package together with `tools/build_cargo.py`,
`tools/blender/build_cargo.py`, the `cargo` entry in `tools/blender/scenes.json`
and the shared Blender tools. All of it is uncommitted local work. `Cargo/` was
left untouched.

## Studio record (fill only from observed evidence)

- Stage: 4 passed for revised GLB on 2026-10-11. Stage 5 pending the user's approval.
  Stage 6 upload accepted 2026-09-28 for the **older hash only**; import of the
  revised GLB and everything after that are unverified.
- Asset selected by the user: yes, 2026-09-28.
- Upload accepted: old hash only, 2026-09-28 (Studio Import Queue success). Do not
  re-import that exact file. Revised hash has not been imported.
- Visual approval: pending
- Asset owner: unknown
- Mesh and texture asset IDs: unknown
- Target map and decor file: unknown
- Imported size / textures: unverified
- Physics settings: unverified
- Restart persistence / published game: unverified
