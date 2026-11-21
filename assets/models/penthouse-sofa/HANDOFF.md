# PenthouseSofa handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Long low sectional sofa, visual shell over a low-cover block in the Penthouse atrium
- Role: decor; height 3.5 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-sofa`)
- Source: `assets/models/penthouse-sofa/source/PenthouseSofa.glb`
- Export: `assets/models/penthouse-sofa/exports/PenthouseSofa.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (2026-11-16, asset-from-prompt)

- Assumed (not asked): copies 4, stays in this game, no moving parts, style realistic, aspect wide. Target block 22 x 4 x 3.5 studs.
- Description, round 2 (used): "An extremely long, low modern sofa for a hotel lobby, built as one single straight piece, six times as long as it is deep. A continuous low straight backrest runs along the whole of one long side, with a low squared arm at each end, and its total height equals its depth. Eight identical boxy seat cushions sit in a single long row with eight matching back cushions. The upholstery is charcoal grey woven fabric. It rests on a slim recessed matte black metal plinth base. Clean and new."
- References: round 1 (seeds 1-8, "seven cushions") all came out 4-5 seats and too short; round 2 seeds 9-14, used seed 11 (longest, five seats, plain white). Rejected 9, 10, 12 (single bench seat, shorter), 13 (front-on, hides depth), 14 (shorter).
- Mesh: seed 1 picked. Seed 2 rejected: it doubled the back cushions into a second row of narrow ones.
- Build: `scene` set by hand to decimate 25000, tile [4, 1] to fit the 30,000 decor budget (below the 15% keep guideline; surface error 0.022, passed).
- Flaws in the export: 15.41 long x 4.46 deep x 3.51 tall studs, so length:depth is 3.5:1 against the 5.5:1 target (6.6 studs short of the 22-stud block, 0.46 deeper). Five seats, not eight. Many thin wire legs (about ten) instead of a plinth; some may read broken up close. Light creasing on the back panel and the base rail. Back cushions stand about 0.5 stud above the back frame.
- Tool note: `source/reference.json` sorts before `reference.png`, so `generate`, `review` and `build` crash on it; it was moved aside for those steps and restored, then `provenance` was rerun.
