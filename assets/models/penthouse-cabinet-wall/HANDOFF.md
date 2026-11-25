# PenthouseCabinetWall handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Kitchen cabinet wall with ovens and fridge, repeated along kitchen cover blocks in the Penthouse
- Role: decor; height 10 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-cabinet-wall`)
- Source: `assets/models/penthouse-cabinet-wall/source/PenthouseCabinetWall.glb`
- Export: `assets/models/penthouse-cabinet-wall/exports/PenthouseCabinetWall.glb`

## Roblox IDs and verification status

- None yet.

## Run record (asset-from-prompt, 2026-11-16)

- Target block: 8 long x 4 deep x 10 tall studs; drawn without collision over a cover block, 10 copies.
- Assumed: role decor, style realistic, aspect square, copies 10, share game, no moving parts, nearest 0, not thin.
- Reference prompt, round 2 (round 1 gave cabinets about 0.25 as deep as wide): "A very deep freestanding
  block of modern kitchen cabinets shaped like a chunky upright box: eight units wide, four units deep and ten
  units tall, so its side is half as wide as its front. The front is a flush grid of handleless matte charcoal
  cabinet doors, with a built-in double oven of black glass stacked in the left column and one full-height
  integrated brushed stainless steel fridge door on the right. The deep sides are flat plain charcoal panels
  with square corners, on a low charcoal plinth. Clean and new."
- Reference seed 13 used. Rejected: 1-8 (too shallow, 2/4/6/7/8 too narrow), 9-11 single oven, 12 too wide and
  single oven, 14 ovens side by side.
- Mesh seed 1 used. Seed 2 failed on the Space (RuntimeError), not reviewed.
- `scene` in brief.json, set by hand:
  - `cull` "interior": removes 150,699 of 282,995 source faces whose centres are inside the shell (TRELLIS
    built the carcass partitions and a second back layer inside the box).
  - `decimate` 24500, `tile` [3, 2] (grid chosen by the build's retry): 29,615 triangles, 6 meshes.
  - Tried and failed on holes: decimate 10000 (8.67% see-through with cull, 11.67% without), 20000 (1.96%).
    The 12,000-triangle target for 10 copies was not reached; the scan tears below about 25,000.
    meshopt (`optimize.tris`) stalls at about 47,000.
- Detail gate overridden with `--allow-detail-loss`; reason is in `detailWaiver` in brief.json.
- Flaws still visible: see `asset_generate.py findings` record. Proportions are 9.16 x 3.35 x 10.07 studs
  (length on x), wider and shallower than the 8 x 4 x 10 target.
- Not uploaded. No user verdict recorded.
