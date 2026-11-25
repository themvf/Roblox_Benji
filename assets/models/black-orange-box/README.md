# Black and orange cargo case

Read [HANDOFF.md](HANDOFF.md) before continuing. The current candidate is
locally verified; visual approval, Studio import and placement are separate
stages.

## Package contents

- `source/design-reference.png`: matching supplied concept image.
- `source/trellis-original.glb`: byte-identical user-selected TRELLIS source.
- `source/BlackOrangeCase.blend`: editable Blender output. The generator
  `tools/blender/build_black_orange_box.py` is authoritative; rebuilding
  replaces manual Blender edits.
- `exports/BlackOrangeCase.glb`: intended delivery candidate, 3,036
  triangles, one mesh/material, 3.644 studs tall with bottom pivot.
- `textures/BlackOrange_{Color,Roughness,Metalness}.png`: 1024 material atlas
  sources. The GLB embeds color and packed metallic-roughness PNGs.
- `review/{front-quarter,side,end,rear}.png`: textured views rendered from
  the written export. `views.png` shows the original source appraisal.
- `trials/decimated-9000.glb` and its quarter image: rejected reduction.
- `SetupDecoration.luau`: optional scoped Studio helper for one selected
  imported MeshPart, after appearance/role approval.

## Build and verify

From the repository root:

```text
python tools/build_black_orange_box.py
python tools/build_black_orange_box.py --check-only
```

The first command backs up generated files under `.mapbuild/black-orange-box/`,
authors and exports in Blender 4.3, appraises the preserved source, renders
four views, and checks the saved GLB. It does not import, upload, place or
publish the asset. `validation.json` holds current hashes and measurements.

## Design limits

The source has 286,315 triangles; a 9,000-triangle direct reduction visibly
shattered its panel faces. The clean rebuild preserves its silhouette,
black/orange color language and main panels. It deliberately favors readable
game-scale shape over small TRELLIS irregularities. The initial atlas has
restrained paint grain, but the finish is flatter than the supplied image.
The user asked to fix this asset later without specifying the change; that
revision remains pending. Height and decoration role are provisional.
