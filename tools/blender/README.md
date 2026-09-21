# Blender scene toolkit

Turning bought or scanned art into Roblox meshes, reproducibly. Three scripts, one
manifest. Every step is config, not code, so a new asset is an entry in
[scenes.json](scenes.json).

| Script | Does |
| --- | --- |
| `scene_kit.py` | scale, exaggerate, re-pivot, decimate, tile, retexture, export |
| `preview_scene.py` | render the built asset at map scale from a player's eye |
| `resize_textures.py` | downscale maps to 1024 and flip DirectX normals |

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
| `decimate` | target triangle count, before tiling |
| `tile` | `[nx, ny]` bisect grid across the two non-up axes |
| `pivot` | `center`, `bottom`, `top` or `origin` |

Order is fixed and deliberate: **import, exaggerate, fit, decimate, tile, pivot,
textures, export**. `exaggerate` precedes `fit` so stretch is in source proportions
while the final width still lands exactly; `pivot` follows `tile` so every tile
shares one offset and the set places with a single `CFrame`.

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
  tile so `decimate`/`tile` can be retuned.
- Blender headless cannot use EEVEE (no GPU context); these scripts use Cycles CPU,
  and set camera clip planes from the scene size so map-scale renders are not empty.
