# PenthouseGalleryWall handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Freestanding gallery wall with paintings, repeated along a gallery cover block in the Penthouse
- Role: decor; height 8 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-gallery-wall`)
- Source: `assets/models/penthouse-gallery-wall/source/PenthouseGalleryWall.glb`
- Export: `assets/models/penthouse-gallery-wall/exports/PenthouseGalleryWall.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (agent, 2026-11-16; not user-approved)

- Target proportions 12 long x 4 deep x 8 tall. Built 11.01 (x) x 1.35 (z) x 8.01 tall: a third of the wanted depth.
- References: round 1 rejected (thin walls, base wider than wall); round-2 seed 8 gave 2:1 meshes (trials/rejected-ref-round2-seed8); round 3 (square aspect) seed 7 used.
- Mesh seed 2 picked first and failed the audit (2.31% see-through speckle on both faces, garbage frames on the back). Seed 1 is clean and is the current export, but it has FOUR paintings on each face, not three.
- Seeds 3-4 were not generated: Hugging Face ZeroGPU quota ran out. Resume: python tools/asset_generate.py generate --name penthouse-gallery-wall --seeds 2 --first-seed 3
- scene.decimate 15000, tile [2,2] set by hand: 16,186 triangles, 4 meshes. Detail 0.028, holes 0.08%: all gates pass with no waiver.
- Flaws: four paintings per face; paintings are blurred; frames differ in width; base stands slightly proud of the wall.
