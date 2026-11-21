# Purple Roman column

`exports/PurpleColumn.glb` is the local high-detail delivery candidate from `source/trellis-original.glb`, a copy of `Lobby/Purple Column.glb`. `source/reference-purple.png` is the adjacent purple finish reference; `source/concept-column.png` is the broader Roman-column concept. This is a chipped, fluted all-angle lobby prop, provisionally 12 studs high and about 2.52 × 2.56 studs across. The base sits at the ground pivot. Blender uses +Z up; the exported GLB uses +Y up.

The source has 285,461 triangles in one mesh and two embedded 2048 WebP maps. Textured 8% and 15% reduction trials are preserved under `trials/` and shown in `review/decimate-*-quarter.png`. The 15% trial retains more of the capital, flutes, stone chips, and stepped pedestal, so it is the chosen high-quality geometry. The final export has 42,819 triangles across six meshes, each below Roblox's 10,000-triangle per-mesh limit. The source color map is tinted toward the supplied purple finish while retaining its stone wear. Named 1024 PNG color and packed metal/roughness maps are stored in `textures/` and embedded in the GLB.

## Rebuild and check

From the repository root:

```powershell
python tools/build_purple_column.py
python tools/build_purple_column.py --check-only
```

The wrapper backs up generated outputs under `.mapbuild/purple-column/<timestamp>/`, rebuilds the Blender scene and export, renders textured front, side, rear, and quarter views from the **saved GLB**, reappraises the export, and writes `validation.json`. Use `--blender <absolute path>` if Blender is not on PATH. `tools/blender/build_purple_column.py` is the authoritative procedural source; direct edits to `source/PurpleColumn.blend` will be replaced by a rebuild.

The 42k-triangle version is a high-detail feature prop. Check Studio frame time before repeating it many times in the lobby. `review/final-*.png` shows the actual saved export. `HANDOFF.md` records stages and `STUDIO_SETUP.md` covers import and lobby placement. No collision shape has been approved yet.
