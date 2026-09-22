# Blender scene toolkit

Turning bought, scanned or generated art into Roblox meshes, reproducibly. One
manifest drives it, and every step is config rather than code, so a new asset is an
entry in [scenes.json](scenes.json).

| Script | Does |
| --- | --- |
| `scene_kit.py` | scale, exaggerate, re-pivot, decimate, tile, retexture, export |
| `preview_scene.py` | render the built asset at map scale from a player's eye |
| `resize_textures.py` | downscale maps to 1024 and flip DirectX normals |
| `make_sky_range.py` | generate a mountain horizon and render it as skybox faces |
| `appraise_asset.py` | **run this first**: says what a source asset is fit for |
| `../gltf_post.py` | meshoptimizer simplify + texture clamp on the exported `.glb` |

`gltf_post.py` sits in `tools/`, not here, because it needs no Blender -- it wraps
the [glTF-Transform](https://gltf-transform.dev/cli) CLI (Node, so `npx` must be on
PATH) and reads the GLB container with the standard library. That means it audits
**any** `.glb`, including one an image-to-3D generator produced that never went
through Blender:

```bash
python tools/gltf_post.py inspect assets/models/jumppad/JumpPad.glb
python tools/gltf_post.py optimize in.glb out.glb --tris 9000 --texture 1024
```

`inspect` exits non-zero when a mesh breaches the 10k cap, so it works as a gate.

Start every new asset with the appraisal, which answers "prop, skybox, terrain or
nothing" in one command. See
[ASSET_INTAKE_AND_LESSONS.md](../../docs/design/ASSET_INTAKE_AND_LESSONS.md).

```bash
blender -b -noaudio --python tools/blender/appraise_asset.py -- --source "<file>"
```

**Pick the right one.** A prop the player sees from any angle -- a weapon, a pack, a
pad -- is a mesh, so it goes through `scene_kit`. A horizon is a skybox, so it goes
through `make_sky_range`. Nothing distant should be geometry; see
"Backdrops" below for why that took four attempts to learn.

Upload with `tools/roblox/upload_asset.ps1`; see
[ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md](../../docs/design/ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md)
for the wider contract.

## Build

```bash
blender -b -noaudio --python tools/blender/scene_kit.py -- --list
blender -b -noaudio --python tools/blender/scene_kit.py -- --asset glacier
blender -b -noaudio --python tools/blender/scene_kit.py -- --all
```

Try a variant without touching the manifest. `--set` takes dotted keys, `--out`
redirects the result:

```bash
blender -b -noaudio --python tools/blender/scene_kit.py -- --asset glacier \
    --set exaggerate=6 --set fit.size=3600 --out /tmp/taller.glb
```

### Manifest fields

| Field | Meaning |
| --- | --- |
| `source` | authored art, relative to the repo root (`.obj`, `.fbx`, `.glb`) |
| `out` | where the game-ready `.glb` lands |
| `textures` | directory of downscaled maps to repoint images at before export |
| `up` | which Blender axis is up **after import**: `x`, `y` or `z` (default `z`) |
| `exaggerate` | vertical multiplier, applied in source proportions before `fit` |
| `fit` | `{axis, size}` uniform scale so that axis spans `size` studs |
| `decimate` | target triangle count, before tiling (Blender's Collapse modifier) |
| `tile` | `[nx, ny]` bisect grid across the two non-up axes |
| `pivot` | `center`, `bottom`, `top` or `origin` |
| `optimize` | `{tris, texture, error, lockBorder}` meshoptimizer pass after export |

Order is fixed and deliberate: **import, exaggerate, fit, decimate, tile, pivot,
textures, export, optimize**. `exaggerate` precedes `fit` so stretch is in source
proportions while the final width still lands exactly; `pivot` follows `tile` so
every tile shares one offset and the set places with a single `CFrame`; `optimize`
follows `export` because it works on the written file, which is the artifact that
actually gets uploaded and therefore the one worth verifying.

### Two ways to shed triangles, and when each one works

They are not interchangeable, and picking wrong wastes a build.

| | `decimate` | `optimize.tris` |
| --- | --- | --- |
| Engine | Blender Collapse modifier | meshoptimizer, via glTF-Transform |
| Good at | anything, including flat-shaded art | holding a silhouette |
| Bad at | panels and thin structures | meshes with split vertices |

**Reach for `optimize` first on a dense, smooth, generated mesh** -- a marching-cubes
output from an image-to-3D model is exactly its best case. Measured here: a
smooth-shaded 81,920-triangle sphere goes to 9,002 in one pass, 1.83 MB to 0.21 MB.

**It will stall on flat-shaded hard-surface art**, and this is worth understanding
rather than fighting. `weld` merges only bitwise-identical vertices; flat shading and
UV seams split every vertex, so nothing merges, and the simplifier will not collapse
across the seam. The jetpack asked for a 38% ratio and moved 3,984 to 3,944 -- about
1%. Raising `--error` does nothing, because the error bound was never the limit.
`gltf_post` detects this (two rungs producing the same count) and says so instead of
grinding through the ladder. Use `decimate` for those, or `tile`.

`lockBorder` defaults to true when `tile` is set, so bisected tiles stay watertight
against their neighbours. A torn seam is invisible in Blender and obvious in game.

## Preview before Studio

An asset that looks right in a viewer can still be a wall beside the playfield.
`preview_scene.py` places it at map scale and renders from a player's eye, in
Roblox studs and Roblox axes, so placements copy straight into a `MapArt` module.

```bash
blender -b -noaudio --python tools/blender/preview_scene.py -- --asset glacier \
    "--place=-2200,300,0,180" "--place=0,300,-2200,270" \
    --ground 9000 "--ground-y=-2.5" \
    "--eye=0,6,0" "--look=-2200,250,0" --lens 16 --out /tmp/look.png
```

Pass `--eye 0,7000,1 --look 0,0,0` for a top-down check of ring coverage; that is
what caught the gaps at the diagonals that a four-plate ring leaves.

Use `=` on any argument whose value starts with `-`, or argparse reads it as a flag.

## Things that cost us time

- **Importers leave an axis-conversion rotation on the object**, so its local axes
  are not the world axes. `scene_kit` bakes that in before touching any axis;
  without it a local-Y scale silently lands on world Z.
- **An OBJ authored Z-up arrives Y-up**; most FBX arrive Z-up. Hence the `up` field.
  If `exaggerate` makes an asset wider instead of taller, `up` is wrong.
- **`up` must be normalised to Blender Z before export, not just used for indexing.**
  `export_yup` maps Blender Z to glTF Y; an asset still sitting on Blender Y exports
  with its height on glTF Z and then lies on its side in Roblox. `scene_kit` does
  this now, but it is worth checking a new asset's GLB directly -- read the POSITION
  accessor min/max and confirm the height is on y. Blender's own viewport will not
  show the problem, because its importer converts back on the way in.
- **A heightfield has a cliff at every edge.** No rotation hides it, so a backdrop
  plate belongs far out with a flat plain filling the foreground, not close in.
- **Relief ratio under about 0.2 reads flat** from any distance. `scene_kit` prints
  the ratio; the glacier source is 0.119 and needs 4x exaggeration to reach 0.476.
- **Roblox caps a mesh at 10,000 triangles and 2048 studs per axis.** `scene_kit`
  fails the build rather than letting the import fail later, and reports the worst
  tile so `decimate`/`tile` can be retuned. With an `optimize` block the triangle
  verdict defers to `gltf_post`, which checks the written file; the stud span never
  defers, because no amount of simplification changes how big a thing is.
- **`--ratio` is a share of vertices, not triangles**, so the triangle count that
  falls out of it is close but never exact -- a 9,000 target landing at 9,002 is the
  arithmetic, not a failure. `gltf_post` allows 2% before it escalates.
- Blender headless cannot use EEVEE (no GPU context); these scripts use Cycles CPU,
  and set camera clip planes from the scene size so map-scale renders are not empty.

## Backdrops

A horizon belongs in a skybox, not in the world. Rendered offline it carries no
triangle or texture budget at all, so it can be far more detailed than any in-game
mesh, and by the time Roblox sees it, it is six flat images: nothing to
mis-orient, no seams, no LOD, no parts.

```bash
blender -b -noaudio --python tools/blender/make_sky_range.py --     --out assets/sky/snowfortress --faces ft --size 900 --samples 40   # preview one face
blender -b -noaudio --python tools/blender/make_sky_range.py --     --out assets/sky/snowfortress --size 1024 --samples 64             # all six
```

Then upload each PNG as a Decal and hang the ids on the map's `Environment.Sky`:

```bash
powershell -File tools/roblox/upload_asset.ps1 -File assets/sky/snowfortress_ft.png
```

`MapService.applySky` builds the `Sky` instance. If any one face fails to resolve
it removes the skybox entirely rather than showing five faces and a hole.

### Three approaches that did not work, and why

- **A bought terrain scan as mesh geometry.** It is authored to be viewed from
  directly above. Its texture is an orthographic bake, so from the side it smears;
  the silhouette that sells a mountain does not survive the decimation an in-game
  mesh needs (712,818 triangles to 16,873 here); and a heightfield is a finite sheet
  with a cliff on every edge -- measured at 38-53% of relief on average, up to 100% --
  which no rotation or placement hides.
- **Vertical exaggeration to rescue it.** Relief ratio below roughly 0.2 reads flat
  at any distance. Pushing 0.119 to 0.476 helped the profile and stretched the bake
  further. `Solidify` to close the open underside shredded the scan's non-manifold
  geometry outright.
- **Roblox terrain `FillBall`.** Native and cheap, and what Carrier, Forest and Swamp
  use -- but it fills *balls*. Smooth domes with no detail. Fine for scenery nobody
  looks at, not for an aesthetic.

Generating the silhouette sidesteps all of it, because the shape is the only thing
that actually matters at that distance and it is the one thing a scan will not give.
