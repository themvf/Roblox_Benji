# Heavy Cannon handoff

Game name `HeavyCannon`; behaves like `Minigun` (kit base in `tools/build_weapons.luau`). Held in every map,
about 12 on screen. Game only; stop at the local build until the user approves the review sheets.

## Source
- User's picture: `source/user-picture.png`.
- Meshy image-to-3D, two runs:
  - `meshy-4000/`: 4,000 triangles, seed 201. The user rejected it as faceted, with see-through slits along the barrel top (0.6%).
  - `meshy/`: 9,000 triangles at 2k geometry (35 credits), seed 202. This is the picked source.
- The model is turned `yaw 90` in the brief, because Meshy delivers the barrel along x.

## Build
- 8,980 triangles, one mesh, under Roblox's 10,000-per-mesh cap. This is over the held budget of 4,000, waived in the brief at the user's request for more detail.
- 0.71 x 1.505 x 4.5 studs, pivot centre.
- Worst view has 0.08% back faces and no patches.

## Mounts (studs from the pivot, -z forward)
- `Muzzle` (0, 0.19, -2.25): the barrel tip.
- `Grip` (0, -0.43, 1.01): the pistol grip under the ring.
- `Core` (0, 0.15, 0.33): centre of the core orb inside the ring housing.

## Core glow (game side, not in the mesh)
Roblox cannot make one region of a textured MeshPart glow. Add these when the weapon is wired up:
- A `Core` part: a cylinder with its axis across the gun, diameter 0.34 studs, length = model width + 0.04 (about 0.75).
  - Its two end faces show as glowing discs on both sides of the ring.
  - `Material = Neon`, colour from `Palette`/`Theme` (warm yellow, close to RGB 255, 200, 40).
  - `CanCollide`, `CanQuery` and `CanTouch` off. Welded to the handle at the `Core` mount.
- A `PointLight` on it: range about 4, brightness about 1.5, the same colour.

Preview: `review/core_glow.png`, rendered by a scratch Blender script with an emissive disc and point light at `Core`.

## Open
- Wire `HeavyCannon` into `src/shared/Weapons` + `tools/build_weapons.luau` on the Minigun base.
- Publish only after a `good` verdict on the current build.
