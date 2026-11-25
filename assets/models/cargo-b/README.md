# White cargo unit: ransacked revision

**Continuing this work? Read [HANDOFF.md](HANDOFF.md) first.**

Status: locally validated ransacked prototype awaiting visual approval. This
new export has not been imported, placed, or verified in Studio. The earlier
intact export failed its Studio upload attempts and is preserved in `trials/`.

## Current deliverable (2026-10-11)

- `exports/CargoUnit.glb`: clean authored, weathered and broken white cargo
  shell with opened end doors, torn side and roof, displaced interior contents.
  3,508 triangles, one mesh/material, two embedded 1024 PNG maps, 1.41 MB.
- Bounds in glTF/Roblox axes: X -4.687..4.687, Y 0..6, Z -3.114..3.114.
  Bottom-centred pivot. The opened door extends the footprint beyond the
  original intact body.
- `source/CargoB_Wreck.blend`: editable modeled parts and joined export.
  `tools/blender/build_cargo_b_wrecked.py` is the authoritative generator;
  `tools/build_cargo_b_wrecked.py` backs up, builds, appraises, renders and
  validates the package. Run `python tools/build_cargo_b_wrecked.py --check-only`
  to verify saved files without rebuilding.
- `textures/CargoB_Wreck_{Color,Roughness,Metalness}.png`: separate atlas maps;
  color and packed metallic-roughness are embedded in the GLB.
- `review/wreck-{front-quarter,side,end,rear}.png`: renders imported from the
  written GLB at its actual scale.
- `trials/CargoUnit_intact_20260928.glb`: unchanged earlier optimized export.

The white body, ribs, corner caps, rectangular proportions and dark base come
from the selected Midjourney/TRELLIS design. Broken openings and ransacked
contents are authored geometry. The old model's normal map was not carried into
this clean geometry version; its large panel details are modeled directly.
The six-stud size and non-colliding decoration role remain provisional.

## Prior intact prototype (historical record)

The earlier version was the white, undamaged sibling of the destroyed unit in
[`assets/models/cargo`](../cargo/README.md). Same method, same six-stud height, so
the two can stand in the same yard.

## Sources

- `source/design-reference.png`: Midjourney "Cargo unit" (807ce1a0, variant 1),
  copied unchanged from `Cargo/`. The TRELLIS model matches it: white body, dark
  grey corner caps top and bottom, double doors on one narrow end, ribbed long
  sides, base skid with vent slots.
- `source/trellis-original.glb`: copied unchanged from
  `Cargo/sample_2026-09-27T182032.482.glb`. It is the bake source, not a deliverable.
- `source/trellis-reference-appraisal.json`: its appraisal and why it is source only.
- Variants 0 and 3 of the same Midjourney prompt are a longer, lower container and
  a latched hard case. Neither matches this model, and neither was used.

## Prior intact deliverables (superseded)

- `exports/CargoUnit.glb`: 7,498 triangles, one mesh, one material, 3.86 MB.
- Bounds (glTF/Roblox): X -4.087..4.087, Y 0..6, Z -2.419..2.419. Bottom-centre
  pivot. 8.2 wide, 4.8 deep, 6.0 tall in studs. Long sides face +/-Z; the doors
  face +X.
- Embedded 1024 PNG colour, packed metallic/roughness and normal maps. Separate
  copies are `textures/CargoB_Color.png`, `CargoB_Normal.png`,
  `CargoB_Roughness.png` and `CargoB_Metalness.png`.
- `source/CargoB.blend`: dense source in the hidden SOURCE collection, low mesh
  visible. The generator `tools/blender/build_cargo_b.py` is authoritative; blend
  edits are overwritten by the next rebuild.
- `review/prototype-{front,front-quarter,rear-quarter,end}.png`: textured renders
  of the final GLB at true scale. `review/source-a..d.png` are the dense source.
- `SetupCargoUnit.luau`: Studio Command Bar helper for the selected unit.

## Prior intact rebuild command (historical)

These old commands target the same `exports/CargoUnit.glb` path and would
overwrite the current ransacked deliverable. Use them only for recovery work
with a separate output path or after preserving the new export.

```text
python tools/build_cargo_b.py              # backup, author+bake, export, appraise, render, validate
python tools/build_cargo_b.py --check-only # validate current files only
```

The full build takes about 6 minutes on CPU, mostly the four bakes and renders.
Backups and per-stage logs are written to `.mapbuild/cargo-b/<timestamp>/`.
The command does not upload, place, commit, or publish anything.

## Prior intact method (2026-09-28)

Optimization, not a rebuild: the silhouette is a plain rectangular box with corner
caps, so the shape survives reduction and the detail is worth baking rather than
re-modelling. The pipeline is the one proven on the destroyed unit:

1. Import the dense source, join, drop its UVs (collapse preserves UV seams and
   stalls on them).
2. Rotate the long axis onto X. This source arrives yawed 90 degrees from the
   destroyed unit's, and everything downstream assumes length on X.
3. Voxel remesh at 0.0035 source units into one manifold shell: 284,422 to
   1,365,916 triangles.
4. Planar dissolve at 2 degrees, triangulate: 379,304 triangles.
5. Collapse to 7,500, smooth by angle at 20 degrees, smart UV unwrap.
6. Selected-to-active bakes from the dense source: normal, roughness, then colour
   and metalness as emission.
7. `scene_kit.py` fits height to 6 studs and sets the bottom pivot.

Two tunings differ from the destroyed unit, both because this design is flat
panels meeting at crisp edges rather than torn metal: the planar dissolve is 2
degrees instead of 4, so it does not eat the panel ribs, and the smoothing angle
is 20 instead of 30, so the shallow chamfers do not round into a bulge.

## Prior intact limitations

- Edges are softer than the dense source. The voxel remesh rounds the chamfers,
  which is the cost of this method on a "clean lines" design. Turn `VOXEL` down
  and `DISSOLVE_DEG` down in the generator to sharpen it, at the price of a
  harsher collapse ratio.
- The long-side rib panels read with less contrast than in `review/source-c.png`.
- A few shallow recesses along the top read as dark openings in
  `review/prototype-rear-quarter.png` rather than as recesses.
- The bottom corners bulge very slightly.
- There is no collision proxy. The collision role is still an open decision
  (see HANDOFF.md).
