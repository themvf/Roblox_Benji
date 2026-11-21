# PenthouseHedge handoff

## Current stage

- Stage: 2, references. The only build so far FAILED and must not be uploaded (2026-11-16).
- Failed build: reference round 1 seed 3 (loose leafy hedge) -> TRELLIS seed 1 at `--resolution 512`.
  77,087 triangles in 12 meshes against a 30,000 budget; surface error 0.541 (limit 0.08); 23.27% back
  faces in the worst view (limit 1.5%). The scan made every leaf a separate one-sided card, so it is
  see-through in game and cannot be decimated to the 8,000 triangle target. Size 7.28 long (x) x 2.93
  deep (z) x 8.06 tall against a target of 8 x 4 x 8.
- TRELLIS at the default 1024 resolution failed five times on this reference with a bare `RuntimeError`
  after about 170 s each; 512 worked. Use `--resolution 512` for foliage.
- Blocker: Hugging Face ZeroGPU quota ran out during reference round 2 (only seeds 9 and 10 were made;
  both are tall columns, wrong proportions, reject).
- Next action: rerun reference round 2 (prompt in `trials/reference/prompt.json`, `--first-seed 9 --seeds 8`),
  choose a tightly sheared, solid-surfaced block that is as long as it is tall, then delete `trials/seed-*`,
  `generate --name penthouse-hedge --seeds 2 --resolution 512`, `pick --replace`, `build`, then set
  `scene.decimate` for about 8,000 triangles. If the leaves still come out as loose cards, switch to the
  clean route (a box with a leaf texture).
- Rejected: round 1 seeds 4-8 (taller than long), 1-2 (little visible depth); candidate seed 2 (dark gaps
  between vertical stripes of leaves).
- Assumed: copies 31, share game, no moving parts, nearest 0, thin no, stop at local build.

## Approved decisions

- Purpose: Clipped hedge in a stone planter, repeated along terrace cover blocks in the Penthouse
- Role: decor; height 8 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-hedge`)
- Source: `assets/models/penthouse-hedge/source/PenthouseHedge.glb`
- Export: `assets/models/penthouse-hedge/exports/PenthouseHedge.glb`

## Roblox IDs and verification status

- None yet.
