# Office chair variants

Two Roblox-ready GLBs share the same chair geometry. Import either `exports/OfficeChair_Clean.glb` or `exports/OfficeChair_YellowStained.glb` with Studio Scale Unit **Stud**. The current five-stud height is a working scale pending user approval. Each import is a three-part mesh model with one material and embedded PNG color and metallic-roughness maps. Use the clean version for an ordinary office chair and the stained version for a lightly worn one.

The source files are `source/trellis-original.glb` and `source/design-reference.png`, copied from `Chairs/` without changing those originals. `source/OfficeChair.blend` keeps the editable source and clean result. `source/stain-metrics.json` records the deterministic texture change. The stained variant changes only the color map; the retained geometry, UVs, and other texture are shared.

Rebuild from the repository root with `python tools/build_office_chair.py`. This backs up existing generated files in `.mapbuild/office-chair/`, generates the maps, writes both GLBs, renders eight exported-file views, and validates the package. Use `python tools/build_office_chair.py --check-only` to inspect saved files without changing approved outputs. Authoring is in `tools/make_office_chair_textures.py` and `tools/blender/build_office_chair.py`.

The 279,541-triangle TRELLIS original is reduced to roughly 25,000 retained triangles, then divided into three height bands below Roblox's 10,000-triangle limit per mesh. This is a visual prop candidate, not an interactive Roblox Seat. The source has small generated-surface irregularities visible at close range. Check the actual Studio import, texture display, scale, ownership, and physics before use; local export validation does not establish those results.

The first stained texture trial covered too much fabric and was rejected. The current map limits the yellow marks to smaller upholstery areas; see `source/stain-metrics.json` and `review/` for evidence. User visual review is still pending.
