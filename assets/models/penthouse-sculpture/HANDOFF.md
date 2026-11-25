# PenthouseSculpture handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Abstract bronze sculpture, visual shell over a full-cover block at the south end of the Penthouse gallery
- Role: decor; height 12 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-sculpture`)
- Source: `assets/models/penthouse-sculpture/source/PenthouseSculpture.glb`
- Export: `assets/models/penthouse-sculpture/exports/PenthouseSculpture.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (2026-11-16, asset-from-prompt)

- Description sent (round 2): three massive solid blocks of polished warm bronze stacked, each slightly offset, bevelled edges, flat smooth faces, dense closed mass wider than tall and half as deep as wide, on a low matte black stone plinth. Style realistic, aspect square.
- Round 1 (twisted ribbon knot) rejected whole: every image had through-holes and was taller than wide.
- Assumed: role decor, height 12 studs, copies 1, share game, no moving parts. Target block 16 x 8 x 12 studs.
- Reference seed 1 (round 2) used: the widest of the eight. Others were taller and narrower.
- Mesh seed 4 picked. Seeds 1, 2, 3 each had invented embossed panels and slots on the unseen face.
- `scene` set by hand to decimate 25000, tile [2,2]: the default build was 68,283 triangles against the 30,000 decor budget.
- Built with `--allow-detail-loss`. The detail gate reports 0.272 surface error at both 28k and 68k triangles; outline overlap is 0.993-0.995 and the wrong pixels are scattered evenly with full-depth errors of both signs, which is sampling noise in tools/outline_check.py, not lost surface. Not fixed in the tool.
- Export 11.11 long x 8.85 deep x 12.01 tall studs: 5 studs short of the 16-stud length. Does not fill the block.
- Still visible: faceted shading on the flat bronze faces (worst on the bottom block and top face), the middle tier is two blocks with a slot between, narrow necks between tiers, bronze reads pink-copper and matte rather than polished.
- Same `source/reference.json` workaround as the kitchen island.
