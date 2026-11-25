# Fuel drum set

Four separate Roblox import files based on the supplied three-drum GLB and image:

| Export | Contents | Approximate size |
| --- | --- | --- |
| `exports/FuelDrum_A.glb` | blue-gray weathered drum A | 2.24 × 3.54 × 2.24 studs |
| `exports/FuelDrum_B.glb` | darker weathered drum B | 2.24 × 3.54 × 2.24 studs |
| `exports/FuelDrum_C.glb` | more rust-streaked drum C | 2.24 × 3.54 × 2.24 studs |
| `exports/FuelDrum_ThreePack.glb` | three drums in a triangular arrangement | about 4.6 × 3.54 × 4.1 studs |

Each individual file contains one 2,754-triangle mesh and two embedded 1024-pixel PNG textures. The three-pack contains three such meshes and six embedded PNGs. All have a ground-level pivot. Import the desired GLB in Studio using Stud units, then inspect its textured result and size. `SetupDecoration.luau` configures the selected imported drum or group as anchored, noncolliding decoration. No explosive, fuel, or interaction gameplay is included.

The source GLB holds three tightly overlapping drums in one 296,253-triangle mesh. `trials/drum-analysis.json` shows why reliable per-drum extraction was rejected: a nearest-center split crosses 1,307 faces and the mesh has 1,888 disconnected components. Complete cylinders were modeled with rolled rims, two seam bands, recessed lids, bung caps, and recreated blue-gray enamel and rust maps. The untouched GLB and supplied reference PNG remain in `source/`. The Blender scene and `tools/blender/build_fuel_drum_set.py` reproduce all outputs.

`review/contact-sheet.png` shows all four exports. Individual front, rear, side, and top views for drum A and the group, plus fronts for B and C, were rendered from the final GLBs. `validation.json` records local triangle, texture, pivot, material, and file-hash checks. The surfaces need user visual approval; Studio import and map placement have not been verified.

From the repository root, run `python tools/build_fuel_drum_set.py --check-only` to verify saved files, or `python tools/build_fuel_drum_set.py` to back up and regenerate the complete package. The rebuild uses Blender 4.3.2 and Python with Pillow. Backups and logs go under `.mapbuild/fuel-drum-set/`.
