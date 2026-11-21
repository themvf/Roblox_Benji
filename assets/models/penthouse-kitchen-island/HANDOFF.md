# PenthouseKitchenIsland handoff

## Current stage

- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.
- Next action: look at `review/views.png`, then record visual approval (stage 5).
- Blockers: none locally. Not uploaded.

## Approved decisions

- Purpose: Kitchen island counter, visual shell over a low-cover block in the Penthouse kitchen and foyer
- Role: decor; height 3.5 studs; pivot bottom.

## Local artifacts

- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build penthouse-kitchen-island`)
- Source: `assets/models/penthouse-kitchen-island/source/PenthouseKitchenIsland.glb`
- Export: `assets/models/penthouse-kitchen-island/exports/PenthouseKitchenIsland.glb`

## Roblox IDs and verification status

- None yet.

## Run notes (2026-11-16, asset-from-prompt)

- Description sent: modern luxury kitchen island, single block 3.5x as long as deep, thick white marble worktop overhanging dark walnut base, flat cabinet doors with slim steel bar handles on the long front, plain walnut ends, clear worktop, low recessed dark plinth. Style realistic, aspect wide.
- Assumed: role decor, height 3.5 studs, copies 2, share game, no moving parts. Target block 14 x 4 x 3.5 studs.
- Reference seed 2 used. Rejected: 3 and 7 (L-shape / open bay), 1, 4, 5, 8 (weaker overhang or grey backdrop), 6 (flat front-on view).
- Mesh seed 2 picked; seed 1 had a white vertical streak on the cabinet front.
- `scene` set by hand to decimate 25000, tile [4,2]: the default build was 61,183 triangles against the 30,000 decor budget.
- Export 12.68 long x 5.29 deep x 3.51 tall studs: shorter and deeper than the 14 x 4 x 3.5 block (length:depth 2.4, wanted 3.5).
- Still visible: two handle pairs where the reference has three; door seams faint; back is plain walnut; walnut greyer than the reference; open toe-kick slot under the front; marble veining smeared on top.
- `source/reference.json` makes `reference_image()` in tools/asset_generate.py pick the JSON as the image; review/build were run with it moved aside, then restored.
