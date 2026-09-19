# Blender carrier kit

`carrier_kit.py` builds the first five modular aircraft-carrier pieces in Blender and
reports poly counts and dimensions. It is idempotent: it clears the scene and rebuilds.

```
blender --background --python tools/blender/carrier_kit.py            # build + report
blender --background --python tools/blender/carrier_kit.py -- --export  # also write FBX
```

FBX lands in `assets/blender/carrier/`, one file per module (that folder is gitignored --
meshes belong in Roblox as uploaded assets, not in the repo).

## Conventions

- **Scale.** 1 Blender metre = 1 Roblox stud. Export uses `FBX_SCALE_UNITS` with
  `global_scale=1.0`, so Studio's mesh importer needs no rescale.
- **Grid.** 4 studs. Deck modules are 32x32x2; anything that snaps to a deck edge is
  32 long or a divisor of it.
- **Pivots.** Deck: centre of the walking surface (z=0, body hangs below), so decks tile
  by moving in 32-stud steps at a single Y. Railing / catwalk / barrier: base centre.
  Stairs: base *front* edge, so it snaps to a deck edge and its top lands exactly 8 studs up.
- **Axes.** +X is along a deck edge, +Y across it, +Z up. Stairs climb toward +Y.
- **Materials.** Four reusable slots only: `Carrier_Deck`, `Carrier_Metal`,
  `Carrier_Hazard`, `Carrier_Grate`. Detail (tie-downs, deck stripes, rust, tread plate)
  is texture work, never geometry.
- **Collections.** `Structure`, `Cover`, `Props`, `GameplayMarkers`, `ExportReady`.
- **No modifiers.** Every module is applied box geometry; there is nothing left unbaked.

## Roblox Studio import settings

| Setting | Value |
| --- | --- |
| Import method | 3D Importer (Avatar off) |
| World-space / anchor pivot | off -- the FBX pivot is already the snap point |
| Rescale unit | none (1:1) |
| Insert in world space | off |
| Collision fidelity | `Box` for barrier and railing posts, `Default` for deck and catwalk, `PreciseConvexDecomposition` for stairs only |
| RenderFidelity | `Automatic` |
| DoubleSided | off (normals are outward) |
| CastShadow | on for structure, off for railings |

Anchor everything on insert. Set each MeshPart's `Size` back to the values in the script
report if the importer rounds them -- snapping depends on exact 32 / 16 / 8 stud spans.
