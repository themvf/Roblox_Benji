# Shiny black cargo box

Read [HANDOFF.md](HANDOFF.md) first. The current export is locally checked
and waiting for visual approval. Studio import and map integration remain
separate stages.

## Files

- `source/design-reference.png`: supplied black cubic cargo-box image.
- `source/trellis-original.glb`: unchanged user-selected GLB.
- `source/GlossyBlackBox.blend`: editable authored model. The generator
  `tools/blender/build_black_box.py` is authoritative; rebuilds replace
  manual changes to the Blender output.
- `exports/GlossyBlackBox.glb`: intended delivery candidate, 3,740
  triangles, one mesh/material, about 4.45 studs high with bottom pivot.
- `textures/BlackBox_{Color,Roughness,Metalness}.png`: 1024 atlas sources.
  The GLB embeds color and packed metallic-roughness PNG maps.
- `review/{front-quarter,doors,service,rear}.png`: neutral-light textured
  views of the saved GLB; `review/gloss-study.png` shows its reflections
  under broad studio lights. `views.png` shows the source appraisal views.
- `trials/decimated-9000.glb` and its quarter preview: rejected reduction.
- `SetupDecoration.luau`: optional, scoped Studio helper for one selected
  imported MeshPart after role approval.

## Rebuild and check

From the repository root:

```text
python tools/build_black_box.py
python tools/build_black_box.py --check-only
```

The first command backs up generated outputs under `.mapbuild/black-box/`,
builds and exports in Blender 4.3, appraises the source, renders the saved
GLB, and validates it. `tools/blender/render_black_box_gloss.py` creates the
extra studio-light gloss preview. `validation.json` records hashes and
measured bounds. These commands do not import or upload into Roblox Studio,
place the asset, or publish the game.

## Design limits

The 284,153-triangle TRELLIS source becomes jagged at 9,000 triangles, so
clean geometry was used to retain the cubic silhouette and recognizable
panels. Dark graphite surfaces use low roughness and high metalness; trim
is brighter and smoother. The gloss-study render demonstrates reflections
with broad lights. The appearance under the game's actual Studio lighting
has yet to be checked. The 4.45-stud size and non-colliding decoration role
are provisional.
