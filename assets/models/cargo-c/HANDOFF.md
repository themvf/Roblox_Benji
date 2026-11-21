# Resume here: ransacked cargo unit

## Current truth (2026-10-11)

The user rejected the soft voxel version, then asked for the clean rebuild to
look **more weathered and broken, as if ransacked**. The current delivery asset
is `exports/CargoWrecked.glb`, SHA-256
`09f099ef75f8242b0d7d980c702a05a4d0df2643f2db384d019b3030ac319a04`.
It is a new revision of the clean authored mesh, not an approval. Do not infer
that the user accepted its look from the request for changes.

The original requested TRELLIS file (`Cargo/sample_2026-09-27T175344.993.glb`)
and matching Midjourney reference remain in `source/`. The former four-mesh
voxel export is preserved at `trials/CargoWrecked_voxel_2026-09-29.glb`. The
first clean but too-pristine export is preserved at
`trials/CargoWrecked_clean_preweather.glb`, with its quarter view and handoff
also saved in `review/` and `trials/`. Neither trial is the delivery asset.

## What changed after the user's feedback

The current generator `tools/blender/build_cargo_c_clean.py` gives the white
enamel, blue interior and exposed steel an atlas with reproducible chips,
scuffs, dirty patches and rust flecks. UVs span the atlas regions so the wear
appears in the export. The side and front openings remain actual gaps. The
swung door now has a missing upper outer corner and bent fragments. Inside are
tipped open storage cases, a loose drawer, a fallen wall panel, bent shelving,
hanging conduit and scattered scrap. This reads as a disturbed, looted space
from the open end. The original snow ground disc remains excluded.

The first wear trial covered the panels in too-uniform speckles. Chip and
scratch density was reduced, then the four final views were regenerated and
opened. The current `review/clean-front-quarter.png`, `clean-end.png`,
`clean-side.png` and `clean-rear.png` are textured renders of the exact written
GLB. The front-quarter and open-end views show the damage and ransacked
contents; side and rear views show the retained panel structure and wear.

## Verification and stage boundary

Stages 1-4 are complete for this revision. Full rebuild and
`python tools/build_cargo_c_clean.py --check-only` passed on 2026-10-11.
`validation.json` (`checkedAtUtc` `20261011T141618314361Z`, status `passed`)
records 4,713 triangles in one mesh, one material, two embedded 1024 PNGs,
no node transforms, bottom pivot, 1,676,256 bytes, and GLB bounds about
9.372 x 5.995 x 8.241 studs (X x Y-up x Z). The asymmetrical footprint
includes the swung door; the shell itself is nominally six studs high.
Current build logs and backups are under
`.mapbuild/cargo-c-clean/20261011T141353004541Z/`. The delivery SHA-256 above
was checked again after the build. `tools/build_cargo_c.py` delegates to the
current clean builder; the old voxel wrapper is preserved in `trials/` and its
`scene_kit` entry exports only into `trials/`.
The package and tooling are local, uncommitted workspace files; an off-machine
Git commit or project backup remains a recovery step.

Stage 5 visual approval is next. The weathered result is still stylized relative
to the intricate Midjourney image; judge it at the intended in-game viewing
distance. Six-stud height, non-colliding decoration role, absence of a snow
base, and target map remain unapproved or unresolved. No Studio import,
upload, asset IDs, owner, physics verification, placement or published-game
check has been observed. The earlier `lune run tools/check_assets.luau` attempt
could not start in this sandbox: Lune panicked while canonicalizing the current
working directory with Windows `PermissionDenied` (code 5). Local package
validation passed; the repository-wide Lune gate is unverified here.

## Next action

1. Read this handoff, `README.md`, and `validation.json`; run
   `python tools/build_cargo_c_clean.py --check-only` before further work.
2. Show `review/clean-front-quarter.png` and `review/clean-end.png` to the user.
   Ask whether this weathering and ransacked state matches their intent. Record
   approval or specific further changes, plus height, decoration role, and
   ground-base preference.
3. For revisions, edit the authoritative generator, run
   `python tools/build_cargo_c_clean.py`, inspect all four exported-GLB renders,
   and update this handoff. Keep old trials out of `exports/`.
4. After visual approval, identify target map and game asset owner. Check for
   an existing upload of this exact GLB before importing. Import with Scale
   Unit Stud, verify textures and height in Studio, then run
   `SetupCargoWrecked.luau` on the one selected imported MeshPart/Model.
5. Save placement through the map decor workflow, preserving other decor;
   restart and verify persistence. Record actual IDs and runtime evidence here.

## Studio record

- Visual approval of current GLB: pending
- Asset owner / mesh and texture IDs: unknown
- Target map and decor file: unknown
- Imported size and textures: unverified
- Physics: unverified
- Restart persistence / published game: unverified
