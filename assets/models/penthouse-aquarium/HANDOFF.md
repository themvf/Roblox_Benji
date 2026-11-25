# PenthouseAquarium handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Built-in aquarium wall, repeated along the foyer cover block in the Penthouse
- Role: decor; height 10 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-aquarium`)
- Source: `assets/models/penthouse-aquarium/source/PenthouseAquarium.glb`
- Export: `assets/models/penthouse-aquarium/exports/PenthouseAquarium.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (agent, 2026-11-16; not user-approved)

- Target proportions 13 long x 4 deep x 10 tall. Built 12.73 (x) x 2.11 (z) x 10.03 tall: about half the wanted depth.
- Reference: round 1 (glass tanks on cabinets, see-through ends) rejected; round 2 prompt described a walnut partition wall with a flush aquarium window. Round-2 seed 5 gave 1.7:1 meshes (trials/rejected-ref5), so round-2 seed 3 was used instead.
- Mesh seed 1 picked; seed 2 rejected (water is a blur with no coral).
- scene.decimate 15000, tile [2,2] set by hand: 18,442 triangles, 4 meshes.
- Detail gate: surface error 0.177 at 68k triangles and 0.181 at 18k, so not caused by the reduction. Built with --allow-detail-loss; reason in brief.json detailWaiver.
- Flaws: coral and fish are a smeared picture; lower walnut band is much taller than the upper; corner posts stand slightly proud of the faces and top; a crumpled patch on the top face; small nicks on one end.
