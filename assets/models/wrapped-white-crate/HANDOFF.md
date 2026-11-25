# Resume here: wrapped white crate

## Current truth

The user supplied `Crates/sample_2026-11-11T151601.152.glb` and first requested a Roblox asset approximately three quarters wrapped in white plastic. On 2026-11-11 they requested that the plastic sheet cover **all of the boxes**. The saved final export is `exports/WrappedWhiteCrate.glb`. The source contains two pale wooden crates on a shared pallet. The revised film wraps both boxes on the sides, top, and both ends. The pallet feet stay exposed. Approximate 8.29-stud length and static decoration use are provisional choices, not user approvals. The prior 75%-wrapped export is retained in the timestamped `.mapbuild/wrapped-white-crate/` backup.

The user then requested a **plain asset with no plastic sheet**. `exports/PlainWoodenCrates.glb` is the separate plain export. It uses exactly the same two verified wood mesh pieces as the wrapped export, with the pallet and wood visible. Its creation did not regenerate or alter the wrapped GLB: the wrapped export SHA-256 remains `06c33dbc5c0b39cd8275ee809b53bff366d5bbd0a0cb1ef370c420f5577f100e`.

Source SHA-256: `7f79db77ea652eb29f6493ca43d82418329918a3d573658f2e6c6add3ad0da9a`. The source has 296,178 triangles. A 9,000-triangle trial visibly damaged top and slat detail (`trials/decimate-9000-quarter.png`). The chosen 17,800-target reduction retains the textured wood and is split into two mesh pieces. Film geometry and surface maps are newly authored. Do not replace the source with the reduction trial.

## Stage evidence

1. **Intake/appraisal: complete.** `appraisal.json`, `views.png`, `review/source-quarter.png`, and the reduction trials record the source condition and choice.
2. **Authoring/export: complete for both variants.** `tools/blender/build_wrapped_white_crate.py` generates `source/WrappedWhiteCrate.blend`, the wood and film PNGs, and `exports/WrappedWhiteCrate.glb`. `tools/blender/build_plain_wooden_crates.py` saves `source/PlainWoodenCrates.blend` and exports only the wood pieces to `exports/PlainWoodenCrates.glb`. The repository wrapper rebuilds both in order.
3. **Local verification: complete for both variants.** `python tools/build_wrapped_white_crate.py --check-only` passed after the plain export was added. `validation.json` records hashes and measurements for both. Wrapped: eight meshes, four embedded PNGs. Plain: two meshes (8,410 and 9,610 triangles), two embedded 2048² PNGs, ground pivot, about 7.95 × 3.84 × 3.77 studs. All meshes are below 10,000 triangles. `review/plain-front-quarter.png`, `review/plain-rear-quarter.png`, and `review/plain-top.png` were rendered from the plain GLB with original materials and visually inspected; they show both wood crates and the pallet without film. The full-wrap previews remain in `review/`. An earlier full-wrap render exposed dark openings at the right top seam; the final builder added a folded top-end lip and the final render shows the end covered.
4. **User visual approval: pending for both current variants.** Present the plain and wrapped previews. The full-wrap film is intentionally opaque off-white with gentle creases. The user requested these variants, but has not approved their rendered appearance yet.
5. **Studio import: unverified.** No upload, texture loading, imported part count, Studio appearance, or asset IDs are claimed.
6. **Map integration: unverified.** No saved placement, collision setting, map role, or published game is claimed.

## Next action

Show the user the plain front-quarter preview and the existing wrapped preview for appearance approval. If approved, check for existing uploads before importing the requested GLB(s) to the intended Studio place. Inspect two imported parts for the plain version and eight for the wrapped version, including their textures at player scale. Apply the variant-specific setup helper only if the user wants a static noncolliding prop, then save and verify map placement separately. Record owner, asset IDs, map, and actual Studio evidence here.

## Rebuild and transfer

Run `python tools/build_wrapped_white_crate.py --check-only` first. A full rebuild backs up both variants under `.mapbuild/wrapped-white-crate/`, then authors, appraises, renders, and validates. Blender 4.3.2 and Python 3 are the tested tools. Both builders, the wrapper, original GLB, both source blends, textures, previews, appraisal, validation, and this handoff must travel together. Generated `.blend` edits are overwritten by a rebuild; change the corresponding builder for reproducible edits. No off-machine backup or Studio state has been verified.
