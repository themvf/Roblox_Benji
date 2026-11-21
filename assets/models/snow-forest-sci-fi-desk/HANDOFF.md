# Resume here: snow forest sci-fi command desk

## Current truth (2026-10-10)

The user supplied `Desks/snowforestscifidesk.glb` and said "now this one" after
the sci-fi chair workflow. This is a **new variant**, not the existing approved
`assets/models/desk` package. Preserve that desk and its Studio upload.

This package reached stages 1-4: intake, authoring, export, and local
verification. Stage 5 user visual approval is pending. Decoration role and
8.1-stud width are provisional. No Studio import, upload, owner/asset IDs,
texture loading, physics, placement, runtime test, or publication has been
observed. The candidate file is `exports/SnowForestSciFiDesk.glb`, SHA-256
`4b99e41ba6014f05ecaf889bca7ca63034d6789780fd9a022f7c6800ab243469`.

## Intake and geometry decision

- Original GLB is saved unchanged at `source/trellis-original.glb`, SHA-256
  `cd7929cacb119b1a1c0938f465692435d6f1327a901356f61b4ef469194bfd13`.
  It is byte-distinct from the earlier desk source. `appraisal.json` and
  `views.png` record 282,973 triangles, one mesh, UVs, and two embedded WebP
  images. The textured sheet was opened: a command desk with a black raised
  monitor, tabletop controls, and enclosed legs, seen from front, side, top.
- Of the nearby Midjourney images, `source/reference-2.png` depicts the same
  desk. That selection is an **inference from visual matching**, not an explicit
  user designation. `source/reference-0.png` depicts a different console and
  is retained only as context.
- A 25,467-triangle decimation trial (`trials/decimate-25000.glb`) was rendered
  with original textures. `review/source-quarter.png` and
  `review/trial-quarter.png` were opened side by side. The trial fractures
  panel surfaces and monitor edges, so it was rejected as delivery geometry.
- `tools/blender/build_snow_forest_sci_fi_desk.py` creates clean editable
  geometry, restores prominent surface details, and writes
  `source/SnowForestSciFiDesk.blend`, named textures, and the final GLB.

## Local verification

- The complete `python tools/build_snow_forest_sci_fi_desk.py` rebuild passed.
  `validation.json` records UTC time `20261010T233418623189Z`, file hashes,
  measurements, and limits. Backup/logs:
  `.mapbuild/snow-forest-sci-fi-desk/20261010T233418623189Z/`.
- The **written GLB** was reimported and rendered in
  `review/final-{front,side,rear,quarter}.png`. All four views were opened.
  The initial console screen was too thin; the builder was corrected and the
  latest renders show the full sloped blue display. The reference's finer
  etched details remain simplified.
- Export: one mesh, 7,492 triangles, one material, two embedded 1024 PNG
  textures, 381,364 bytes. glTF bounds X -4.05..4.05, Y 0..6.545,
  Z -2.05..2.334. Bottom pivot, +Y up, front +Z. Import with Stud units.
- `python tools/build_snow_forest_sci_fi_desk.py --check-only` validates saved
  files without regenerating. The repo-wide Lune gate has not been verified
  for this package; the earlier chair run in this sandbox failed to start
  because Lune could not canonicalize the current directory (`Access is denied`).

## Next action

1. Show `review/final-quarter.png` and other views to the user. Ask whether
   this simplified appearance, 8.1-stud width / 6.545-stud height, and
   decorative role are right. Record approval against the exact GLB hash.
2. If approved, preserve this export. Determine whether it was already
   imported. Reuse an existing upload rather than upload twice. In Studio,
   verify owner, asset IDs, actual textures, orientation, size, and physics.
3. If map placement is requested, save into the destination map's existing
   decor collection, restart the map, and record runtime evidence here.

Do not infer stages 5-7 from a passing local check. The originals in `Desks/`
were untouched. Package and builder are local uncommitted work; commit or
back up for off-machine recovery.

## Studio record (fill only from observed evidence)

- Asset owner / mesh and texture IDs: unknown.
- Imported size, orientation, texture appearance: unverified.
- Physics: unverified; `SetupDecoration.luau` is a conditional helper.
- Target map and saved decor file: unknown.
- Restart persistence and published game: unverified.
