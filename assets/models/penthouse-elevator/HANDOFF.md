# PenthouseElevator handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Elevator doors in a marble surround, repeated along the spawn-hall cover block in the Penthouse
- Role: decor; height 12 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-elevator`)
- Source: `assets/models/penthouse-elevator/source/PenthouseElevator.glb`
- Export: `assets/models/penthouse-elevator/exports/PenthouseElevator.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (agent, 2026-11-16; not user-approved)

- Target proportions 11 long x 4 deep x 12 tall. Built 12.13 (x) x 2.55 (z) x 12.02 tall: face is square rather than taller than long, and about 60% of the wanted depth.
- Reference round 1, seed 1. Mesh seed 1 picked (fewer open edges than seed 2, same shape).
- scene.decimate 15000, tile [2,2] set by hand: 17,786 triangles, 4 meshes.
- Detail gate: surface error 0.176; built with --allow-detail-loss; reason in brief.json detailWaiver.
- Flaws: doors are one flat grey recessed panel with no centre seam and no brushed-steel look; the back also has a door recess instead of plain marble; marble veins are a soft cloud; a small black sliver on the back upper left; floor indicator is a grey block.
