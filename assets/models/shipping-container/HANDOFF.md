# Resume here: shipping container

## Current truth (2026-10-10)

The user supplied `Crates/0_1.png` and said “now this,” continuing the local
Roblox-ready asset workflow used for the preceding chair and desks. The matching
TRELLIS source is `Crates/sample_2026-10-04T220852.863.glb`, SHA-256
`341ac0d42e80d5b3895335bb0eae03f6e5331d29bbcc7c4cec094f40fe8936c2`.
The source and reference are copied into this package. The intended role is
provisionally non-colliding decoration and the nominal length is 22 studs;
neither has user approval yet. The earlier `assets/models/container` package
contains a processed export and appraisal but no handoff or approval record.
It remains unchanged.

Stage 1 intake and source appraisal, stage 2 authored rebuild, stage 3 export,
and stage 4 local verification have been completed. Stage 5 visual approval is
next. The delivery asset is `exports/ShippingContainer.glb`, SHA-256
`f781c6134eec998be2b858cd752a5e3c971b858329a07691938d9b4557fb8fb7`,
never the dense source or the older `assets/models/container/Container.glb`.
The written file is 395,496 bytes with 7,824 triangles, one mesh/material,
two embedded 1024 PNG images, a bottom pivot, and GLB bounds of about
22.426 x 10.78 x 8.054 studs (X x Y up x Z). `validation.json` records the
full current hashes and bounds. The actual
export was rendered from the double-door end, long side, plain rear, and an
elevated door-side quarter view in `review/`. The reference has charcoal ribs,
gray doors, gold locking rods, dark corner fittings and yellow/black hazard
marks. Those are modeled or recreated in the new export.

## Next action

1. Read this handoff, `README.md` and `validation.json`; run
   `python tools/build_shipping_container.py --check-only` to verify saved files.
2. Show `review/final-quarter.png` and `review/final-doors.png` to the user.
   Record approval or requested changes to appearance, size, and decoration role.
3. After visual approval, establish target map and asset owner. Check whether
   this exact GLB has already been uploaded before creating another upload.
4. Import with Stud units, verify texture loading and size in Studio, then
   apply `SetupDecoration.luau` only to the selected imported container.
5. Save placement through the destination map's decor collection, preserve
   existing decor, restart the map, and record actual runtime evidence.

## Stage evidence and limits

- Source appraisal is `appraisal.json` with the original source hash; its
  `views.png` is the textured source inspection. The roughly 291k triangle
  TRELLIS mesh could not be reduced cleanly enough to keep its detailed ribs.
- `tools/blender/build_shipping_container.py` is the reproducible geometry and
  texture source. `tools/build_shipping_container.py` backs up outputs under
  `.mapbuild/shipping-container/`, writes logs, renders, and validates.
- `validation.json` hashes the final GLB, references, editable source, textures,
  and review views. Full build and `python tools/build_shipping_container.py
  --check-only` both passed on 2026-10-10. The full build logs and backups are
  under `.mapbuild/shipping-container/20261011T002355092937Z/`. All four
  exported-GLB renders were opened and compared with the supplied reference.
  A passing local check does not prove Studio import.
- `lune run tools/check_assets.luau` could not execute in this sandbox:
  Lune panicked while canonicalizing the working directory with Windows
  `PermissionDenied` (code 5). This is a tool environment limitation rather
  than a passing repository-wide gate.
- Visual approval: pending. Studio import, ownership, asset IDs, texture
  appearance, physics, map placement, restart persistence: unverified.
- No upload, placement, map integration, or publication was performed.

## Studio record

- Asset owner and mesh/texture IDs: unknown
- Target map/decor file: unknown
- Imported size and textures: unverified
- Physics settings: unverified
- Restart persistence and published game: unverified
