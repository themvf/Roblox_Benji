# Server rack: mesh-front decoration prototype

**Continuing this work? Read [HANDOFF.md](HANDOFF.md) first.** It records user
approval, the next step, and what has not yet been verified in Studio.

Status: rebuilt prototype ready for visual review and Studio import. Not uploaded,
placed, or verified in Studio. Earlier TRELLIS experiments are retained below.

## Approved brief and deliverables

- User selected glass/mesh front, eight studs tall, background decoration.
- Implemented the mesh-front option: closed framed grille, recessed server rows,
  handle, hinges, small blue indicators, flat powder-coated sides, metal feet.
- `exports/ServerRack.glb`: 4,096 triangles, one mesh, one material, about 0.62 MB.
- Final file bounds in glTF/Roblox coordinates: X -1.6..1.6, Y 0..8,
  Z -1.855..1.855. Pivot is centered at the bottom. Front faces +Z.
- Embedded color and packed metallic/roughness textures are 1024 PNGs. Separate
  Roblox Color, Roughness and Metalness PNGs are also in `textures/`.
- `source/ServerRack.blend`: editable components in SOURCE (hidden for export),
  joined production mesh in EXPORT. Enable SOURCE for component editing.
- `review/prototype-front.png` and `review/prototype-rear.png`: textured renders
  of the final GLB without preview scaling, so actual dimensions are exercised.
- Material details were recreated in an atlas, not transferred from the damaged
  TRELLIS panels. No true glass transparency or functioning door is claimed.

## Rebuild

One command from the repository root backs up, rebuilds, renders and checks:

```text
python tools/build_server_rack.py
```

To check existing files without rebuilding: `python tools/build_server_rack.py --check-only`.
The commands below are the individual pipeline stages for troubleshooting.

```text
blender --factory-startup -b --python tools/blender/build_server_rack.py
blender --factory-startup -b --python tools/blender/scene_kit.py -- --asset server-rack
python tools/gltf_post.py inspect assets/models/server-rack/exports/ServerRack.glb
```

The manifest intentionally performs no decimation. Modeling already meets budget.

## Studio handoff

Import `exports/ServerRack.glb` with units set to Stud. Check 8-stud height and the
loaded SurfaceAppearance. If automatic materials need correction, assign the
separate named PNG maps from `textures/`. Select only the rack and run the supplied
`SetupDecoration.luau` in the Studio Command Bar to set Anchored=true and
CanCollide/CanTouch/CanQuery=false. GLB does not enforce these Roblox properties.
No collision proxy is provided because this asset is background decoration.
These settings and the Studio appearance remain unverified until import.

## Prototype checks

Final-file geometry/texture audit, Python syntax checks, and diff whitespace
checks passed. Front/rear views were rendered and inspected. The local asset gate
accepts this package; its unrelated mud-grassland appraisal failure remains.

## Earlier export experiment

## Results (2026-09-26)

- Original source: `ServerRacjs/sample_2026-09-26T215845.338.glb`, 277,885 indexed triangles, two 2048 WebP textures. Blender's appraisal counts 277,883 triangles after import. Original remains unchanged.
- Original textured renders: `review/source-front.png`, `review/source-rear.png`. Preview height is provisionally eight studs; this does not modify or validate source units or pivot.
- The existing hosted TRELLIS tab had an input image but no generated preview. Its currently loaded image differs from the original GLB's reference. New runs are separate candidates, not controlled comparisons of the same source.
- The hosted numeric export field clamps a typed 9,000 target to 100,000 on blur. The hosted UI cannot directly test the project's 9,000 target.
- A new 1024-resolution generation, seed 1869743971, ended with a generic service error after sampling. No specific cause was exposed.
- A 512-resolution retry with seed 1869743971 and randomization disabled succeeded. Export target 100,000; texture size 2048.
- Downloaded export: `trials/trellis-512-target100k.glb`, 93,483 indexed triangles, 5.26 MB, two 2048 WebP textures. Original remote filename: `sample_2026-09-26T224647.392.glb`.
- Textured render: `review/trellis-512-target100k.png`. The side panel is badly distorted and the front detail is irregular. Visual rejection occurs before local simplification.
- The local 9,000-target post-processing trial was stopped before it returned a completed result, after the source candidate failed visual review. No result or successful triangle reduction is claimed.

## Decision

Lowering hosted generation resolution is not accepted as the production solution.
Do not infer that a custom pre-bake 9,000-target export has been tested: it has not.
That test requires a TRELLIS runtime with editable export settings and the decoded
mesh/material data. A downloaded GLB does not contain the original latent state.
The successful 512 result remains in the user's browser session; do not regenerate
it accidentally. For this rack, clean cabinet geometry with baked surface detail
remains the recommended fallback if custom low-target exports fail visual review.

## Reproduce a textured review

Run Blender with `tools/blender/preview_scene.py`, supplying:

```text
--glb assets/models/server-rack/trials/trellis-512-target100k.glb
--materials original --no-arena --fit-height 8
--eye 10,6,14 --look 0,4,0 --lens 52 --resolution 600,700
--samples 24 --ground 200 --ground-y=-0.05
--out assets/models/server-rack/review/trellis-512-target100k.png
```

The preview script still defaults to clay materials for compatibility. Use
`--materials original` explicitly for all texture checks. Eight studs is a review
assumption, not an approved gameplay dimension.

## Validation

- Preview Python syntax check and `git diff --check`: passed.
- Original front/rear and new candidate textured renders: completed and inspected.
- GLB inspection correctly rejects both dense source meshes for the current project budget and flags WebP/2048 textures.
- Repository asset gate has an unrelated existing failure: missing
  `assets/scenery/mud-grassland/appraisal.json`.
- Studio import and gameplay acceptance: not performed.
