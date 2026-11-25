# Snow field shelter

`exports/SnowFieldShelter.glb` is the local delivery candidate. It is a closed, decorative field shelter based on `source/reference.png` and the adjacent TRELLIS model preserved as `source/trellis-original.glb`. The approximate authoring footprint is 24 by 32 studs, with a 14 stud roof peak. The exported world bounds include the protruding frame and door and measure 24.56 × 32.805 × 14.231 Blender units. The source scene uses a ground-level origin, Blender +Z up, and the white trussed door end at Blender -Y; glTF exports with +Y up.

The source scan has 279,190 triangles in one mesh. A trial reduction to 8,933 triangles damaged the canvas, window frames, and front arch. `trials/decimate-9000.glb` and `review/decimate-quarter.png` document that rejected route. The final asset is a clean rebuild with seven meshes grouped by material, each under 10,000 triangles. It recreates the fabric folds, white truss, door, and sealed windows; it does not bake the source scan's texture. Eight named PNG maps are embedded in the exported GLB and kept separately in `textures/`.

The door is closed and nonfunctional. The windows are dark, opaque panels. There is no interior. This candidate is intended for background decoration; it has no gameplay collision contract. If the shelter should be enterable or used for cover, that requires a separate geometry and map review.

## Rebuild and verify

From the repository root:

```powershell
python tools/build_snow_field_shelter.py
python tools/build_snow_field_shelter.py --check-only
```

The wrapper backs up generated files under `.mapbuild/snow-field-shelter/<timestamp>/`, then runs Blender to rebuild the editable `.blend`, export the GLB, render four views from the saved GLB, appraise the exported geometry, and write `validation.json`. Use `--blender <absolute path>` if Blender is not on PATH. The authoritative procedural source is `tools/blender/build_snow_field_shelter.py`; direct edits to the generated `.blend` will be replaced by a rebuild.

`review/final-quarter.png`, `final-front.png`, `final-side.png`, and `final-rear.png` are textured views of the **saved export**. Visual approval and Studio verification are still required. See `HANDOFF.md` for current stage and `STUDIO_SETUP.md` for the import checks.

## Separate open-door version

`exports/SnowFieldShelter_OpenDoor.glb` preserves the shelter shape but cuts a real doorway through the front fabric and fixes the original white door open about 76 degrees. It includes visible jamb depth, a threshold, and a short interior walkway. Its editable scene is `source/SnowFieldShelter_OpenDoor.blend`; textured saved-export previews are `review/open-quarter.png`, `open-front.png`, `open-side.png`, and `open-rear.png`. Its ninth named map is `textures/Slate_interior_walkway_Color.png`.

```powershell
python tools/build_snow_field_shelter_open.py
python tools/build_snow_field_shelter_open.py --check-only
```

The open version has eight material-grouped meshes and measures 24.56 × 35.617 × 14.231 with the door protruding. The door is fixed open; there is no hinge animation or working door script. The visible opening is **not yet approved or validated as a player route**. `validation-open.json` is its independent local check. Rebuilding the open version does not replace the closed GLB.
