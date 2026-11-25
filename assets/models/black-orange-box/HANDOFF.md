# Resume here: black and orange cargo case

## Related new-shape candidate (2026-10-17)

The user later supplied `Cargo/blackandorangebox_newshape.glb` and asked for
a glossy version. Its separate local candidate and evidence are in
`assets/models/black-orange-newshape/HANDOFF.md`. The user has not said it
replaces this rectangular case, so preserve both pending visual review.

## Current truth (2026-10-17)

The user selected `Cargo/blackandorangebox.glb` and asked to “make this one”
and “fix it later.” No specific later fix was described. This package is the
first intact candidate. Its appearance, 3.64-stud height, and provisional
non-colliding decoration role have **not** been approved. No Studio import,
asset IDs, map placement, or published result has been observed.

The selected TRELLIS GLB is preserved byte-for-byte at
`source/trellis-original.glb` (SHA-256
`cb33c82718f215be6547d054f3fdacaa66bf30ddc46349721abbbc002f63308d`).
`source/design-reference.png` is the matching black/orange case image.
`appraisal.json` records the original 286,315 triangles, dimensions,
measurements and explicit purpose decision. `views.png` was opened: it shows
a closed case with depth, recognizable from front, side and top, with no
obvious loose background props.

## Authoring decision and local evidence

A 9,000-triangle `scene_kit` reduction is preserved at
`trials/decimated-9000.glb`, with the actual textured GLB render at
`trials/decimated-9000-quarter.png`. The basic silhouette survived, but the
panel faces became jagged and cracked. It is not a delivery candidate. The
clean authored version keeps the broad rectangular armored shell, inset
lid well, orange waist band, side recesses and end latch. The generator is
`tools/blender/build_black_orange_box.py`; its editable Blender output is
`source/BlackOrangeCase.blend`. Further wear, damage or proportion changes
belong to the later requested fix, after the user describes or reviews it.

**Stage 4 local verification passed:**
`python tools/build_black_orange_box.py` completed authoring, appraisal,
four rendered textured views and written-GLB checks. The current delivery
file is `exports/BlackOrangeCase.glb`, SHA-256
`bf1afb9b9af329aea03904b3f4b6f0e20c7dc1f30842ca2fa4d2e243837c5044`.
The saved GLB has 3,036 triangles, one mesh/material, two embedded 1024 PNG
maps (color and packed metallic-roughness), and a bottom pivot. Its glTF
bounds are X -3.7215..3.7215, Y 0..3.644, Z -2.1475..2.1475. All four
`review/{front-quarter,side,end,rear}.png` images were opened and inspected.
Agent assessment: the clean shell and orange trim read clearly, but the
paneling is simpler and the painted finish is flatter than the source image.
This is not user visual approval. `validation.json` records full hashes,
measurements and limits. A separate `--check-only` verification also passed
after the full build; run it again on resumption to check the saved files.
The repository-wide `lune run tools/check_assets.luau` reported this package
as OK. Its overall exit was nonzero solely because the unrelated
`assets/scenery/mud-grassland` package has no `appraisal.json`.

## Next action and separate stages

Stage 5: show the current front-quarter, side and end views for visual
approval. Record what the user wants fixed later before making another
version. Preserve this GLB as a trial if changes are requested.

Stage 6: after appearance and size are settled, import the exact approved
GLB with Stud units in Studio under the correct owner. Verify texture
loading, dimensions, orientation and physics. `SetupDecoration.luau` sets
one selected imported MeshPart to anchored non-colliding decoration; do not
assume GLB extras applied those engine properties. Record asset IDs here.

Stage 7: save placement in the chosen map's decor collection, preserve
existing decor, restart the map and record runtime evidence. The target map
and owner are currently unknown.

## Studio record (fill only from observed evidence)

- Visual approval and requested later fix: pending
- Studio import of current SHA: unverified
- Owner and mesh/texture IDs: unknown
- Imported size, textures and physics: unverified
- Target map/decor file: unknown
- Restart persistence and publication: unverified
