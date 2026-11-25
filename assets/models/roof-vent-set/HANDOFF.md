# Resume here: nine separate roof vents

## Current truth

The user supplied `Building Props/sample_2026-11-11T204037.020.glb` and asked for all contained objects as separate assets they can place in the game. The GLB contains nine roof ventilation props laid out in a 3×3 product sheet but stored as one mesh. The two PNGs in `Building Props/` are source references, copied under `source/`. The nine final files are the individually named GLBs under `exports/`, listed in `README.md` and `source/vent-manifest.json`. These are provisional static rooftop decorations with four-stud maximum horizontal footprint; the user has not approved the scale or specific map role.

Source GLB SHA-256: `535cce079c9e0f4623d05cf7af279cfc1dd1fc22a33523b3ab140b097c3dd1a1`. Its glTF records 291,238 triangles. Blender imported 291,236 triangle polygons; the two-count difference has not been diagnosed, so do not claim perfect source-triangle preservation. The grid analysis accounted for all 291,236 imported polygons and found empty x/z gaps between the nine props. The split does not cut through any imported face.

## Stage evidence

1. **Intake/appraisal: complete.** `appraisal.json`, `views.png`, both saved image references, and `trials/grid-analysis.json` establish the nine-object source and separation gaps. The appraisal decision states the provisional role and construction method.
2. **Authoring/export: complete.** `tools/blender/build_roof_vent_set.py` imports the source once, separates the nine objects, converts its embedded WebP maps to named PNGs, scales and bottom-centers each object, reduces each to 60% of its imported triangles, and splits geometry into 2–4 mesh parts below 10,000 triangles each. `source/RoofVentSet.blend` and `source/vent-manifest.json` make the result reproducible. The 100%-triangle trial renders in `trials/raw/` show that uneven bars in the slanted and wide grilles already exist in the source. They were not introduced by reduction. The unused large raw trial exports were removed; `trials/build_raw_trial.py` can regenerate them if needed.
3. **Local verification: complete.** `python tools/build_roof_vent_set.py --check-only` passed. `validation.json` records file hashes, identity, part triangle counts, ground pivots, four-stud footprints, UVs, PBR material wiring, and two embedded 2048-pixel PNG textures per GLB. The nine front, side, and rear textured renders in `review/` were inspected. `review/contact-sheet.png` summarizes all nine front views. The recognizable silhouettes survived optimization; source-generated surface irregularities remain. The shared `lune run tools/check_assets.luau` gate reports this package as OK, but exits nonzero for the pre-existing missing appraisal at `assets/scenery/mud-grassland`.
4. **User visual approval: pending.** Present `review/contact-sheet.png` and individual views. Record which vents, if any, need a cleaner grille, different scale, or geometry changes. The current outputs are separate local files; asking for them does not prove the user approves their appearance.
5. **Studio verification: unverified.** No import, upload, owner, mesh/texture asset IDs, material appearance, or Studio size check has been observed.
6. **Map integration: unverified.** No roof placement, collision setup, saved decor collection, restart test, performance measurement, or publication has been observed.

## Next action

Show the contact sheet and export links for visual review. If the user approves, check for existing uploads before importing to the intended Studio place and owner. Verify each imported Model contains only its own 2–4 mesh parts, textured appearance, bottom pivot, and size. Decide whether these props should be noncolliding decoration or physical cover before applying `SetupDecoration.luau`. Save any placement in the map's decor collection, restart the map, and record actual asset IDs and evidence here. One of each prop is 174,733 triangles, so assess device performance before mass repetition.

## Rebuild and transfer

Run `python tools/build_roof_vent_set.py --check-only` first. A full rebuild backs up the current exports and reviews under `.mapbuild/roof-vent-set/`, then authors, appraises, renders, and validates. Blender 4.3.2 and Python with Pillow are the tested tools. Keep the source GLB, references, Blender scene, manifest, textures, previews, appraisal, validation, scripts, and this handoff together. The builder script is authoritative: a full rebuild overwrites manual edits to generated files. No off-machine backup or Studio state has been verified.
