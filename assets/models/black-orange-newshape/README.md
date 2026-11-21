# Glossy angular black-and-orange cargo case

Read [HANDOFF.md](HANDOFF.md) first. The current candidate has passed local
verification. Visual approval, Studio import and map integration are
separate stages.

## Files

- `source/design-reference.png`: matching supplied new-shape image.
- `source/trellis-original.glb`: unchanged user-selected source GLB.
- `source/GlossyAngularCase.blend`: editable authored model. The generator
  `tools/blender/build_black_orange_newshape.py` is authoritative; a rebuild
  replaces manual edits to the Blender output.
- `exports/GlossyAngularCase.glb`: intended candidate, 3,956 triangles,
  one mesh/material, 4.4575 studs tall with a bottom pivot.
- `textures/NewShape_{Color,Roughness,Metalness}.png`: 1024 atlas sources.
  The GLB embeds color and packed metallic-roughness PNG maps.
- `review/{front-quarter,long-side,end,rear}.png`: neutral-light textured
  views rendered from the saved GLB. `review/gloss-study.png` shows broad
  reflections under studio lights. `views.png` shows source appraisal views.
- `trials/decimated-9000.glb` and its quarter preview: rejected reduction.
- `SetupDecoration.luau`: optional scoped Studio helper for one selected
  imported MeshPart after appearance and role approval.

## Rebuild and check

From the repository root:

```text
python tools/build_black_orange_newshape.py
python tools/build_black_orange_newshape.py --check-only
```

The first command backs up generated outputs under
`.mapbuild/black-orange-newshape/`, authors and exports in Blender 4.3,
appraises the source, renders the written GLB and validates the package.
`tools/blender/render_newshape_gloss.py` produces the extra broad-light
reflection study. `validation.json` records hashes and bounds. Neither
command imports, uploads, places or publishes the asset.

## Design limits

The TRELLIS source has 283,338 triangles; direct reduction at 9,000
fractures its broad panels. Clean geometry keeps the long footprint,
sloped roof, white belt and orange diagonals. Small source irregularities
and some panel lines are simplified. Gloss is authored in the packed
metallic-roughness map and visible under the studio preview lights, but
the game's actual Studio lighting remains unverified. Size and decoration
role are provisional. This is separate from the older rectangular
`assets/models/black-orange-box` candidate until the user chooses whether
one replaces the other.
