# Wrecked cargo unit — clean rebuild

Read [HANDOFF.md](HANDOFF.md) first when resuming. The current delivery file is
`exports/CargoWrecked.glb`. It is a clean authored rebuild of
`source/design-reference.png` (Midjourney Destroyed cargo unit, b5d03922,
variant 1), with the original `source/trellis-original.glb` retained. The user
rejected the earlier soft voxel version on 2026-10-11.

## Rebuild and check

From the repository root:

```text
python tools/build_cargo_c_clean.py
python tools/build_cargo_c_clean.py --check-only
```

`python tools/build_cargo_c.py` is a compatibility entry point for these same
commands.

The first command backs up generated files to `.mapbuild/cargo-c-clean/`, authors
the Blender scene, exports the GLB, appraises it, renders the exported GLB, and
validates hashes and bounds. `tools/blender/build_cargo_c_clean.py` is the
authoritative editable source. Manual changes to `source/CargoC_Clean.blend` will
be replaced on rebuild. Blender 4.3.2 and Python 3 were used. The commands do
not upload, place, or publish the asset.

## Current design and export contract

- One Blender unit is one stud; +X points through the blown doorway, +Z is up
  in Blender. The GLB uses +Y up. The pivot is at the original shell centre on
  the floor, so the swung door makes the exported bounds asymmetrical.
- One mesh and one atlas material. The separate 1024 PNG color, roughness, and
  metalness maps live in `textures/`; color and packed metal/roughness are
  embedded in the GLB. The atlas has reproducibly generated paint chips,
  scuffs, grime and rust flecks, with per-face UVs that show the wear in the
  export. The geometry carries the sharp panel and tear relief.
- A true open front and side gap reveal the blue interior. The right door swings
  outward, stays attached at its hinges, and has a missing upper outer corner.
  Irregular dark cut edges and white shards identify the damaged areas. The
  interior has tipped open cases, a loose drawer, a fallen panel, bent shelves,
  hanging conduit and scrap on the floor to read as ransacked. The floor is
  part of the prop, while the TRELLIS snow ground disc is excluded.
- Nominal shell height is six studs to match the two other Cargo units. The
  provisional Studio helper sets anchored, non-colliding decoration physics.
  This size and role still need user approval.
- `review/clean-*.png` are textured views of the actual written export.
  `validation.json` records the current hashes, triangle count, bounds and
  limitations. Neither file proves Roblox Studio appearance.

## Earlier trial and why it was replaced

The 2026-09-29 version optimized the 289,373-triangle TRELLIS scan by cutting
the ground disc, voxel remeshing at 0.018, baking color/normal/roughness/
metalness, and dividing the result into four tiles. It met the per-mesh cap,
but its walls, viewport and torn frame softened. The user requested a better
version on 2026-10-11. The exact old export is preserved as
`trials/CargoWrecked_voxel_2026-09-29.glb`, with its prior validation and
appraisal in `trials/voxel-*.json`. Its previews remain as
`review/prototype-*.png`. The old wrapper is retained at
`trials/build_cargo_c_voxel_wrapper.py`; its authoring script remains
`tools/blender/build_cargo_c.py`. Probe files remain in `trials/`. They are not
the current build path.

The first clean export was still too pristine for the user's requested
ransacked look. Its exact GLB is preserved as
`trials/CargoWrecked_clean_preweather.glb` and its front-quarter render as
`review/clean-preweather-front-quarter.png`. The present builder adds surface
wear and disturbed contents while preserving the clean silhouette and openings.

The old approach failed because reducing the hollow torn shell to one mesh
locked above Roblox's 10,000-triangle per-mesh cap; coarser voxels destroyed
the surface, and a collapsed UV atlas became fragmented. The new authored mesh
avoids that reduction step. The ground disc remains excluded because it would
conflict with a generic floor; a snow-specific base would be separate terrain
or map decor.

## Studio stage

After visual approval, import `exports/CargoWrecked.glb` through Studio's 3D
Importer with Scale Unit Stud. Verify the actual six-stud height, textures,
orientation and ownership. Select only the imported unit and run
`SetupCargoWrecked.luau` in the Command Bar. Record asset IDs and placement in
`HANDOFF.md`. Gameplay cover belongs in the map's authored geometry path;
the current helper treats this as decoration.
