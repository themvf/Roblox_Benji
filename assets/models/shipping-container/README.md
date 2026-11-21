# Shipping container

Reference: `source/design-reference.png` (`Crates/0_1.png`). The dense TRELLIS
output is preserved as `source/trellis-original.glb`. The older reduction at
`assets/models/container/Container.glb` was inspected. It retained the broad
silhouette but darkened the finish and blurred the door and side details. The
delivered version uses clean authored geometry with recreated panel and hardware
detail; it is not a texture bake from the TRELLIS output.

From the repository root, run `python tools/build_shipping_container.py` to
back up prior generated files, rebuild, render the actual export, and validate.
Run `python tools/build_shipping_container.py --check-only` to inspect the saved
package without regenerating it. The authoritative editable generator is
`tools/blender/build_shipping_container.py`; manual `.blend` edits need to be
transferred to that generator before rebuilding. Blender 4.3.2 was used.

The GLB uses one Blender unit per stud, +Y up, +X toward the double doors,
and a bottom pivot. Import with Studio's 3D Importer, Scale Unit Stud. The
container is roughly 22.4 long, 8.1 wide, and 10.78 high in the export.
The source dimensions are provisional until visual approval. The current Studio
helper configures non-colliding decoration. If this becomes gameplay cover,
author collision and placement in the map's geometry path instead of relying
on decor collision.

`exports/` contains only the delivery GLB. `textures/` has the 1024-pixel
color, roughness, and metalness source maps; Blender embeds color and packed
metallic/roughness PNGs in the GLB. `review/final-*.png` renders the written GLB
with original materials. `validation.json` records hashes, bounds and the
current local check. The preview does not establish Studio appearance.

Previous experiment: legacy `assets/models/container/Container.glb` from
`scene_kit` decimated the ~291k triangle source to 9k. The ribs became noisy
and the body too dark. No visual or Studio approval was found for that file,
so it has been left in place as historical work, separate from this package.
