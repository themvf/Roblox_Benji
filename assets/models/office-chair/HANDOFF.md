# Resume here: office chair, clean and yellow-stained variants

## Current truth (2026-10-17)

The user asked for two versions of `Chairs/officechair.glb`: one clean and one with a bit of yellow staining. The current local delivery candidates are `exports/OfficeChair_Clean.glb` and `exports/OfficeChair_YellowStained.glb`. They use identical reduced chair geometry and differ in their mapped upholstery color. The stained version should be reviewed as a light stain, not a wholesale recolor.

Saved export identities after the final local check: clean SHA-256 `a798723fe6f72424cc63a1e8bd272b037195fe7b7807aad52719e2606dfd1d1d`; stained SHA-256 `80e29a81ebb4a744148d6c25557274296b9dd9a5dd2742857f26f49f2150cbdb`. These are candidate hashes, not yet approved hashes.

Stages 1-4 (intake, authoring, export, local verification) have local evidence. Stage 5 user visual approval is pending. Studio import and map integration are unverified. Five-stud height is provisional; unlike the separate sci-fi chair, the user has not approved this chair's height or role. No Studio asset IDs, upload, physics, seat behavior, or map placement should be inferred from these files.

## Evidence and design decision

- `source/trellis-original.glb` is an unchanged copy of the user file, SHA-256 `588cacb7a220d74a93a05a1f599ced4836eded2c5ab31e5b09c17af4c5961a01`. `source/design-reference.png` copies the nearby `Chairs/office chair.png` reference. The original `Chairs/` files are untouched.
- `appraisal.json` and `views.png`: the textured source has one 279,541-triangle mesh, UVMap, two embedded WebP maps, and 132,371 open edges. The padded back, seat, armrests, and wheeled base match the reference. It has no obvious unwanted environment geometry, though small surface artifacts remain.
- `tools/blender/build_office_chair.py`: shape-preserving decimation at ratio 0.09 and scale to provisional five-stud height. Retained triangles are split across three mesh parts; the export never relies on the 279,541-triangle original at runtime.
- `tools/make_office_chair_textures.py`: extracts original color and metallic-roughness maps, keeps an unchanged clean PNG, and deterministically adds local yellow-tan patches to bright neutral upholstery pixels for the second variant. The dark frame and wheels are excluded by the brightness mask. The first broad-stain trial was rejected after render; this is the narrowed version.
- `review/clean-{front,side,rear,quarter}.png` and `review/stained-{front,side,rear,quarter}.png` are renders reimported from the written GLBs. Inspect them before asking for approval. `validation.json` records exact export hashes, bounds, texture formats, geometry identity, and package results.
- All eight saved views were inspected. The front, side, rear, and quarter silhouettes show a complete office chair. The clean fabric stays pale gray; the stained export adds small yellow-tan patches near the lower back and seat without recoloring the dark base. Small source-derived nicks, a thin adjustment lever beneath the seat, and irregular edges remain visible. The reduction kept the recognizable shape, so a full geometric rebuild was not warranted for this pass.
- `python tools/build_office_chair.py` passed after a mesh-validity repair in the Blender builder. `python tools/build_office_chair.py --check-only` then passed against the saved final exports and views. `lune run tools/check_assets.luau` reports `OK` for `assets/models/office-chair`; the repository-wide command exits 1 solely because the unrelated `assets/scenery/mud-grassland` lacks `appraisal.json`.
- Rebuild: `python tools/build_office_chair.py`. Saved-file verification: `python tools/build_office_chair.py --check-only`. Generated-file backups and build logs go under `.mapbuild/office-chair/`.

## Production contract

- GLB is Y-up, bottom pivot near Y=0, and about five studs tall when imported with Studio Scale Unit **Stud**. Final bounds and triangle counts are in `validation.json`.
- Current bounds: X -1.737 to 1.739, Y 0 to 5, Z -1.739 to 1.739 studs. Both variants have 8,386 / 8,385 / 8,386 triangles, 25,157 total. The front faces +Z.
- Both exports have the same three meshes, UV geometry, and packed texture; the clean and stained color maps differ. Each mesh stays below 10,000 triangles. Each GLB embeds two 2048-pixel PNG textures.
- Treat as a visual prop candidate pending role decision. These GLBs contain no Roblox Seat and do not set collisions or anchoring. If the user chooses decoration, configure physics after Studio import.

## Next action

1. Show the clean and stained quarter previews for user visual review. Confirm whether the stain amount and provisional five-stud scale suit this chair. Record the exact approved export hashes if approved; do not regenerate an approved version without a concrete change request.
2. Import the approved GLB or GLBs into Studio if needed, with Stud units. Verify appearance, actual size and pivot, texture loading, owner, and mesh/texture asset IDs. Record observed results here.
3. Decide and configure intended role, then integrate any approved version into the target map. Record placement and runtime evidence separately.

## Studio record (observed evidence only)

- Visual approval: pending.
- Owner / mesh and texture IDs: unknown.
- Imported size, appearance, and physics: unverified.
- Map placement and persistence: unverified.
