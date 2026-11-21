# Resume here: simple sci-fi desk

## Current truth (2026-10-10)

The user supplied `Desks/desksimple.glb` and said "now this" after two other
desk variants. This source is byte-distinct from both the existing approved
`assets/models/desk` package and `assets/models/snow-forest-sci-fi-desk`.
Neither of those packages was changed or rebuilt here.

Stages 1-4 (intake, authoring, export, local verification) have evidence.
Stage 5 user visual approval is pending. Width 9.2 studs and decoration role
are provisional. No Studio import, upload, owner/asset IDs, texture loading,
physics, map placement, runtime test, or publication has been observed.
The only delivery candidate is `exports/SimpleSciFiDesk.glb`, SHA-256
`6c02702656aca7151fa091304687172e27fa606d8035891a57d36df2852f0e1c`.

## Intake and authoring evidence

- `source/trellis-original.glb` is an unchanged copy of the supplied file,
  SHA-256 `440f2010e8ca812778cfb628b71c1dbb8a51a5728686a0dedebf242b562ab2fd`.
  `appraisal.json` and `views.png` record one mesh, 299,417 triangles, UVs,
  165,909 open edges, and two embedded WebP images. The textured sheet was
  opened: a wide desk with four dark rear panels and separated supports.
- `source/reference-0.png` depicts the same variant and is used as the design
  guide by visual inference, not explicit user designation. `reference-2.png`
  depicts the taller single-monitor console; it is context only.
- `trials/decimate-27000.glb` contains 26,947 triangles. The source and trial
  were rendered with original textures in `review/source-quarter.png` and
  `review/trial-quarter.png` and opened side by side. The trial fractures the
  broad top, monitor frame, and foot surfaces, so it was rejected.
- `tools/blender/build_simple_sci_fi_desk.py` creates clean editable geometry
  and recreated surface detail. It writes `source/SimpleSciFiDesk.blend`,
  the named atlas maps, and the final GLB. No damaged scan texture bake is
  claimed.

## Local verification

- `python tools/build_simple_sci_fi_desk.py` passed as a full rebuild;
  `validation.json` records UTC time `20261010T235511610421Z`, hashes,
  measurements, and limitations. Backup/logs:
  `.mapbuild/simple-sci-fi-desk/20261010T235511610421Z/`.
- The **written GLB** was reimported and rendered as
  `review/final-{front,side,rear,quarter}.png`. All four views were opened.
  Its two supports and four-panel console read clearly. Compared with the
  source, fine edge etching is simplified and the rear is plainer.
- Export measurements: one mesh, 4,268 triangles, one material, two embedded
  1024 PNG maps, 239,100 bytes. glTF bounds X -4.6..4.6, Y 0..5.425,
  Z -2.2..2.389. Ground pivot, +Y up, front +Z. Studio import setting: Stud.
- `python tools/build_simple_sci_fi_desk.py --check-only` checks saved files
  without rebuilding. Repo-wide `lune run tools/check_assets.luau` remains
  unverified in this sandbox: a previous attempt for the chair failed before
  starting because Lune could not canonicalize the current directory.

## Next action

1. Show `review/final-quarter.png` to the user. Confirm visual acceptance,
   approximate 9.2-stud width / 5.425-stud height, and whether this variant
   is non-colliding decoration. Bind approval to the exact final GLB hash.
2. If approved, preserve this file; check for any existing upload before
   importing. In Studio verify owner, IDs, actual textures, size, orientation,
   and decoration physics. `SetupDecoration.luau` is a conditional helper.
3. If map placement is requested, preserve the destination map's existing
   decor collection, save the desk there, restart the map, and record runtime
   evidence here.

Stages 5-7 cannot be inferred from local validation. Originals in `Desks/`
were untouched. This package and its builder are local uncommitted work;
commit or project backup is needed for off-machine recovery.

## Studio record (fill only from observed evidence)

- Asset owner / mesh and texture IDs: unknown.
- Imported size, orientation, texture appearance: unverified.
- Physics: unverified; no Studio helper execution observed.
- Target map and saved decor file: unknown.
- Restart persistence and published game: unverified.
