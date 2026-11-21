# Roof vent set

Nine individually placeable roof ventilation props separated from the supplied `Building Props/sample_2026-11-11T204037.020.glb`. Each file in `exports/` contains one prop, its own ground-level pivot, and embedded PNG color and surface textures. The exports are ready for a Studio import test; no upload or map placement has been verified.

| File in `exports/` | Source-sheet position | Approximate size (studs) |
| --- | --- | --- |
| `SlantedLouverHood.glb` | top left | 4.0 × 2.4 × 3.0 |
| `CurvedRoofOutlet.glb` | top center | 3.9 × 3.1 × 4.0 |
| `RectangularIntakeBox.glb` | top right | 3.2 × 2.7 × 4.0 |
| `WideRoofLouver.glb` | middle left | 2.9 × 1.6 × 4.0 |
| `TallVentStack.glb` | middle center | 3.9 × 6.8 × 4.0 |
| `RoundRoofExtractor.glb` | middle right | 4.0 × 3.1 × 4.0 |
| `PitchedRoofVent.glb` | bottom left | 3.7 × 2.3 × 4.0 |
| `RaisedCurvedDuct.glb` | bottom center | 2.4 × 4.7 × 4.0 |
| `TwinDuctIntake.glb` | bottom right | 2.6 × 2.4 × 4.0 |

The table lists width × height × depth. The largest horizontal dimension of each prop was scaled to four studs as a provisional size. Import each GLB separately in Studio with Stud units. Inspect the textures and size before placement. For static, noncolliding rooftop decoration, select one imported Model and run `SetupDecoration.luau` in Studio's Command Bar. The helper sets anchoring and collision flags; the GLB itself does not set Roblox physics.

`review/contact-sheet.png` gives a quick overview. `review/<name>.png`, `review/<name>-side.png`, and `review/<name>-rear.png` show textured views of each exported GLB. `source/` retains the untouched GLB, the two supplied image references, the editable Blender scene, and the export manifest. `textures/` contains the PNG conversions of the source's embedded color and packed surface images. `trials/` records the measured separation gaps and a full-resolution comparison for two grilles.

Each output retains about 60% of its source triangles and is split into 2–4 MeshParts, each below Roblox's 10,000-triangle per-mesh limit. All nine together contain 174,733 triangles, so test performance before placing many repeated copies. The two uneven grilles were also uneven in the untouched source, as recorded in `trials/raw/`.

From the repository root, run `python tools/build_roof_vent_set.py --check-only` to verify saved files. Run `python tools/build_roof_vent_set.py` to back up and regenerate all nine exports and previews. A rebuild requires Blender 4.3.2 and Python with Pillow; its backup and logs go under `.mapbuild/roof-vent-set/`. See `HANDOFF.md` for stage status and the next action.
