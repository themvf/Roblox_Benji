# Bouncer (TRELLIS): Avatar Setup in Studio

The free alternative to `../skinned/` (Tripo P2, 120 credits). Same character, same match body, made like this:

1. The whole-body picture (`crops/whole.png`) was edited into a T-pose with FLUX.1 Kontext
   (`compare/apose/seed-1.png`). That was free, and it means the arms never have to be swung in
   Blender. TRELLIS fuses the sleeves to the jacket, so swinging them tore the hem into flaps and spikes.
2. TRELLIS.2 made the model from that picture (`compare/trellis-tpose/seed-101-1024.glb`, 283,000
   triangles), also free.
3. `python tools/kit_look.py skinned Bouncer --source <that glb> --turn 0 --swing 0 --cage 6
   --name skinned-trellis --marks '<joints read off its grid; see prepare-spec.json>'`

What came out:

- **Body:** one watertight shell of 12,000 triangles in a T-pose (Avatar Setup accepts A or T),
  fitted to the match body and facing -Z.
- **Hair:** 4,000 triangles. TRELLIS fused the hair to the head, so everything above the brow
  (`hairCut`) was cut off as the hair, then rebuilt closed. The remesh caps the head under it.
- **No headgear.** The first build's 752 triangles of "headgear" were floating slivers; dropped.
- **Audit.** `audit/` holds the views, close-ups and the hair on its own, with the findings in
  `audit/status.json`; `python tools/kit_look.py ready <this folder>` passes for these files.

## Steps

The same as `../skinned/STUDIO.md`, with this folder's `Bouncer-AvatarSetup.fbx`. The only
differences: the pose is a T-pose, and you save the result as `BouncerRigTrellis.rbxm`.

## Known before you start

- **Visor and coil are in the body.** TRELLIS fused them to the head and neck. The visor will
  follow the head, but the coil sits across the neck joint and may stretch when the head turns.
- **Back box.** TRELLIS invented a box on the upper back. It's in the body.
- **Surface.** The worn trim reads wider and softer than on the source (it was baked onto
  12,000 triangles at 1024). It's the agreed polish step, done after movement passes.
- **No pink zip.** The T-pose picture lost it, which matches the request to remove the chest magenta.
