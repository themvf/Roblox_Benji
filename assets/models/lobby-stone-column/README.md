# Lobby stone column

`exports/LobbyStoneColumn.glb` is a high-detail local delivery candidate from the unchanged `source/trellis-original.glb`, copied from `Lobby/sample_2026-11-09T190538.784.glb`. Its weathered blue-gray finish is preserved from the GLB. The capital is chipped and hollow-looking, the shaft is smooth, and the pedestal is stepped. The 12-stud height is provisional; the grounded base spans about 2.38 × 2.40 studs. Blender uses +Z up and the GLB uses +Y up.

The source has 286,003 triangles in one mesh and two 2048 WebP maps. Textured 8% and 15% reduction trials are saved under `trials/` and `review/`. The 8% version introduces speckled shaft artifacts, so the final uses the 15% version: 42,900 triangles in six meshes, each below 10,000 triangles. The color and packed metal/roughness maps were converted to named 1024 PNGs in `textures/` and embedded in the GLB.

## Rebuild and check

From the repository root:

```powershell
python tools/build_lobby_stone_column.py
python tools/build_lobby_stone_column.py --check-only
```

The wrapper backs up generated outputs under `.mapbuild/lobby-stone-column/<timestamp>/`, rebuilds the Blender scene and export, renders four textured views from the saved GLB, reappraises that export, and writes `validation.json`. `tools/blender/build_lobby_stone_column.py` is the reproducible source; direct edits to `source/LobbyStoneColumn.blend` will be overwritten by a rebuild. This is a high-detail feature prop; check Studio performance before repeating it widely. `HANDOFF.md` records stage evidence and the next action.
