# PenthouseDaybed handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Outdoor daybed, visual shell over a low-cover block on the Penthouse terrace and gallery
- Role: decor; height 3.5 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-daybed`)
- Source: `assets/models/penthouse-daybed/source/PenthouseDaybed.glb`
- Export: `assets/models/penthouse-daybed/exports/PenthouseDaybed.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (2026-11-16, asset-from-prompt)

- Assumed (not asked): copies 6, stays in this game, no moving parts, style realistic, aspect wide. Target block 8 x 4 x 3.5 studs.
- Description, round 2 (used): "A narrow single-person outdoor chaise lounge daybed, chunky and block-like. The base is a tall solid rectangular teak wood box plinth that sits flat on the ground, twice as long as it is wide and nearly half as tall as it is wide. A very thick cream fabric mattress cushion covers the whole top. At one short end a tall upright teak backrest with a thick cream padded cushion rises to almost the width of the daybed. Honey-brown teak planks, cream cushions, clean and new."
- References: round 1 (seeds 1-8) were all low double beds on legs, too wide and too flat. Round 2 seeds 9-16, used seed 10 (solid box plinth to the ground). Rejected 9 and 11-16: slab feet with open space under the platform.
- Mesh: seed 1 picked (fewer open edges, sturdier back strut); seed 2 was also acceptable.
- Build: default dense route gave 69,285 triangles (over the 30,000 decor budget); `scene` set by hand to decimate 25000, tile [2, 2] (below the 15% keep guideline). Surface error 0.142: inside the 0.15 fail line, over the 0.08 warn line.
- Flaws in the export: 3.84 wide x 7.72 long x 3.53 tall studs, close to the block. The backrest is a reclined cushion on an open A-frame, not a solid block, so only the back 1.5 studs reach full height; the platform top is about 1.6 studs. The plinth is inset under an overhanging frame. Cushion edges are slightly lumpy.
- Tool note: `source/reference.json` sorts before `reference.png`, so `generate`, `review` and `build` crash on it; it was moved aside for those steps and restored, then `provenance` was rerun.
