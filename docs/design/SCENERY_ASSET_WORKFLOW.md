# Reusable Sketchfab-to-Roblox scenery workflow

This is the repeatable path for external environment models. It keeps source
provenance, Blender processing, Roblox limits, and map integration separate.

## 1. Create a package

```powershell
python tools/scenery/pipeline.py init `
  --name "My Scenery" `
  --url "https://sketchfab.com/3d-models/..." `
  --creator "Creator name" `
  --license "CC BY 4.0" `
  --width 128 `
  --triangles 10000 `
  --tiles 1
```

This creates `assets/scenery/<name>/` with `source/`, `textures/`, `exports/`, a
manifest, optional attribution notes, and a verification record. Provenance fields
are recorded for reference but do not block the build.

## 2. Prepare the source

Extract the game source into the package's `source/` directory and put resized maps
in `textures/`. The creator, license, source URL, and retrieval date can be recorded
in `manifest.json` for reference.

## 3. Set the scenery contract

Edit the manifest before exporting:

- `fit.size` is the intended Roblox-stud width; use a measured landmark rather than
  blindly matching the source bounding box.
- `decimate` is the total triangle target before tiling. Keep each final mesh at or
  below 10,000 triangles and each axis at or below 2,048 studs.
- `tile` splits large terrain into a grid. Use it for broad ground/backdrop art,
  not to hide a high-detail prop that should be optimized differently.
- `pivot: bottom` places the lowest point on the map floor; use `center` for a
  distant backdrop that is positioned by its bounding-box centre.
- `up` documents the source's up axis after import (`z` is the default).

The exporter applies operations in this order: import, optional vertical
exaggeration, fit, decimate, tile, pivot, texture repoint, GLB export.

## 4. Build and verify

```powershell
python tools/scenery/pipeline.py build --package assets/scenery/<name>
python tools/scenery/pipeline.py verify --package assets/scenery/<name>
```

The build uses the existing Blender exporter and prints mesh counts, bounds, relief,
and output size. Verification records the export hash in `verification.json`. A
successful export is only **Export-verified**; it is not yet imported or playable.

## 5. Review in Studio

Upload the GLB with the existing `tools/roblox/upload_asset.ps1` workflow, insert it
into an isolated review folder, and confirm scale, axis, materials, and textures.
Keep visual scenery `CanCollide = false`; add simple authored collision only where
the design packet requires a wall, cover, or walkable ledge. Never use a detailed
scenery mesh as gameplay collision by default.

## 6. Integrate and accept

Place the reviewed asset through a repository-backed map builder/manifest. Test fresh
map load, reload, route clearance, projectile collision, objective visibility, and
the target device. Capture approach and player-height views. Track status separately:

`Source-approved → Modeled → Export-verified → Uploaded → Imported → Integrated → Visually verified → Playtested`.

For the supplied Mud Grassland link, the package is ready to process as soon as the
Blender conversion environment is available.
