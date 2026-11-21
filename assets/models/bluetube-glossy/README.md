# Glossy blue containment tube

This package has six separate candidates for Roblox decoration: `exports/BlueTube_Glossy.glb` with a cyan core, `exports/BlueTube_GreenCore.glb` with a green core, `exports/BlueTube_NeonYellowCore.glb` with a fluorescent yellow core, `exports/BlueTube_CrackedOozing.glb` with a cracked yellow chamber and static spill, `exports/BlueTube_FaintOccupant.glb` with a faint human-shaped shadow inside the intact blue chamber, and `exports/BlueTube_BlueCrackedOozing.glb` with a cracked cyan chamber and blue spill. All leave `assets/models/bluetube/BlueTube.glb` unchanged.

## Why it was rebuilt

The first glossy trial kept the generated 9,000-triangle mesh and changed only its finish. The user's screenshot showed jagged top plates, open gaps and cyan showing through the ring. That trial is preserved at `trials/BlueTube_Glossy_FinishOnly.glb` with its earlier views. A material edit cannot close missing surfaces, so the delivery candidate now uses clean geometry modeled from the supplied concept and textured source views.

## Package

- `source/bluetube_clean.glb`, `source/BlueTube_OptimizedBaseline.glb`, `source/design-reference.png`: durable inputs and comparison baseline.
- `appraisal.json`, `views.png`: source measurements and textured views.
- `tools/blender/build_bluetube_clean_geometry.py`: authoritative procedural geometry and finish source.
- `source/GlossyBlueTube.blend`: editable Blender scene before export grouping.
- `exports/BlueTube_Glossy.glb`: current 12.1-stud, ground-pivot glTF Y-up delivery candidate.
- `exports/BlueTube_Glossy_StudioTextured.glb`: separate blue Studio import candidate with embedded color and finish maps; use this when the factor-only original previews gray. Studio appearance is pending verification.
- `exports/BlueTube_{GreenCore,NeonYellowCore,CrackedOozing,FaintOccupant}_StudioTextured.glb`: corresponding import candidates with embedded maps for the other four looks. The original variants remain separate and unchanged.
- `exports/BlueTube_GreenCore.glb`: separate 12.1-stud candidate with green inner core, glass tint and indicators; the outer blue shell is identical.
- `exports/BlueTube_NeonYellowCore.glb`: separate 12.1-stud candidate with yellow core, glass tint and indicators; its core mesh is named for an optional Roblox Neon material setting.
- `source/CrackedOozingTube.blend`, `tools/blender/build_bluetube_cracked_oozing.py`: editable and procedural sources for the broken chamber and fluid shapes.
- `exports/BlueTube_CrackedOozing.glb`: separate yellow-core candidate with an open cracked shell, retained shards and fluorescent spill down to a floor pool.
- `source/FaintOccupantTube.blend`, `tools/blender/build_bluetube_faint_occupant.py`: editable and procedural sources for the faint silhouette.
- `exports/BlueTube_FaintOccupant.glb`: separate intact blue-core candidate with a static shadow visible through the glass.
- `exports/BlueTube_BlueCrackedOozing.glb`, `exports/BlueTube_BlueCrackedOozing_StudioTextured.glb`: separate blue cracked-and-spilled candidate and its embedded-texture Studio import copy.
- `review/{front,side,rear,quarter,top}.png`: neutral-light views rendered from the saved export.
- `review/green-{front,side,rear,quarter,top}.png`: corresponding views from the green export.
- `review/yellow-{front,side,rear,quarter,top,night}.png`: corresponding views from the yellow export, including a dim-light emission check.
- `review/leaking-{front,side,rear,quarter,top,damage,night}.png`: saved-export views of the cracked variant, including a damage close-up and dim-light check.
- `review/occupant-{front,side,rear,quarter,top,night}.png`: saved-export views of the subtle blue silhouette.
- `review/blue-cracked-{front,side,rear,quarter,top,damage}.png`: saved Studio-textured export views of the blue spill below the crack.
- `validation.json`, `validation-green.json`, `validation-neon-yellow.json`, `validation-cracked-oozing.json` and `validation-faint-occupant.json`: separate saved-file checks and SHA-256 hashes.
- `tools/build_bluetube_studio_textured.py`, `textures/studio-textured/`, `review/studio-textured-front.png`, and `validation-studio-textured.json`: reproducible texture-map copy, saved-file preview and local checks for the gray-importer-preview issue.
- `review/studio-textured-{green,yellow,cracked,occupant}-front.png` and `validation-studio-textured-{green,yellow,cracked,occupant}.json`: saved-file preview and checks for the other four copies.
- `tools/build_bluetube_blue_cracked_oozing.py`, `validation-blue-cracked-oozing.json` and `validation-studio-textured-bluecracked.json`: reproducible material derivation, texture packaging and local evidence for the sixth candidate.
- `SetupNeonYellowCore.luau`: optional Studio Command Bar helper to set only the imported yellow core MeshPart to `Enum.Material.Neon`.
- `textures/README.md`: explains the factor-only original and the new image-textured Studio candidate.

The model has a continuous top cap and retaining ring, smooth blue chamber, stepped base, control cabinet, screen, vents, structural brackets, panel seams and fasteners. Glossy blue enamel, polished metal, a cyan glass shell and opaque lit core are named glTF PBR materials. The cyan shell uses alpha blending; Studio appearance requires inspection.

## Rebuild and verify

From the repository root, run `python tools/build_bluetube_glossy.py`. It backs up generated outputs under `.mapbuild/bluetube-glossy/`, runs Blender authoring, exports the GLB, renders five saved-file views and validates the result. Set `BLENDER` if Blender 4.3 is installed elsewhere. `python tools/build_bluetube_glossy.py --check-only` checks saved outputs without rebuilding.

Run `python tools/build_bluetube_green_core.py` to derive the green version from the checked blue export. The green builder changes only three material definitions and retains the exact geometry binary. It renders and validates five separate views. `python tools/build_bluetube_green_core.py --check-only` checks the saved green export. Rebuild the blue source first only if its geometry has intentionally changed; the green builder checks its base SHA before writing.

Run `python tools/build_bluetube_neon_yellow_core.py` for the yellow version. It preserves the geometry binary and earlier exports, changes three inner materials, and names the core mesh for Studio selection. It renders five standard views plus a dim-light view. `--check-only` validates saved files without rebuilding. The GLB has emissive yellow material factors, but an actual Roblox Neon material must be applied and checked in Studio; the optional helper does that after import.

Run `python tools/build_bluetube_cracked_oozing.py` for the damaged variant. It checks the intact exports before authoring, backs up prior generated outputs under `.mapbuild/bluetube-cracked-oozing/`, saves a Blender scene, exports a separate GLB, renders seven views and validates the saved files. Use `--check-only` to verify the existing candidate. The leak is static geometry, not simulated fluid.

Run `python tools/build_bluetube_faint_occupant.py` for the shadow variant. It checks all earlier exports, backs up its own previous outputs, saves an editable Blender scene, renders six views from the saved GLB and validates the final file. Use `--check-only` to verify without rebuilding. The figure is a low-opacity, static silhouette inside the blue chamber; it has no animation or gameplay role.

The first trial's generated-shell details were replaced, not UV-transferred. The retained source and trial allow later comparison. No Roblox lights, particles, collision behavior or map placement are contained in the GLB. See `HANDOFF.md` for approval and Studio status.
