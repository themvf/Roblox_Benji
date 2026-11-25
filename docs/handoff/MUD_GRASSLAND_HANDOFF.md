# Mud Grassland scenery and map handoff

Updated: 2026-09-21

## Objective

Create a separate selectable Roblox map named `MudGrassland` using the supplied
Sketchfab mud scene as scenery. Do not place the scenery into the existing Snow
Fortress/Arena gameplay layout. The user wants a separate map within the current
game project, not a second Roblox experience.

## User decisions

- Treat supplied models as authorized for this project; do not block processing on
  license or attribution confirmation.
- Use Rojo for source-backed project integration.
- Keep the existing game map unchanged.
- The uploaded model may be used as decorative scenery; author simple gameplay
  collision separately if the final map needs it.

## Source asset

Repository source:

```text
MapLocations/mud-grassland/source/Untitled.glb
MapLocations/mud-grassland/textures/
```

Source measurements:

- GLB size: approximately 87.5 MB.
- Source triangles: 976,684.
- Source contains two meshes and four embedded images.
- Texture directory contains four 2048×2048 maps.

The source is too dense for direct Roblox use. Do not insert the source GLB into
Studio directly.

## Completed pipeline work

Reusable workflow files:

```text
tools/scenery/pipeline.py
docs/design/SCENERY_ASSET_WORKFLOW.md
```

The pipeline wraps the existing Blender exporter at
`tools/blender/scene_kit.py`. It imports the source, decimates geometry, fits the
asset to a configured stud width, tiles when configured, sets the pivot, repoints
textures, exports GLB, and records a verification hash.

The pipeline now auto-detects Blender in standard Windows install directories.
Blender 4.3.2 was used successfully.

Mud Grassland package:

```text
assets/scenery/mud-grassland/manifest.json
assets/scenery/mud-grassland/README.md
assets/scenery/mud-grassland/verification.json
assets/scenery/mud-grassland/exports/mud-grassland.glb
```

Current manifest settings:

```text
source: MapLocations/mud-grassland/source/Untitled.glb
output: assets/scenery/mud-grassland/exports/mud-grassland.glb
fit width: 128 studs
decimate target: 10,000 triangles
tile: 1 × 1
pivot: bottom
up axis: z
```

Verified output:

- Export size: 12,123,772 bytes, approximately 12.12 MB.
- Export triangles: 10,000.
- Export bounds: approximately 128 × 129.1 × 22.5 studs.
- Verification status: `Export-verified`.
- SHA-256: `260a53d00def9c413b155a5a6069b967248b41aeb9a6e45a52c57e729a6c28cb`.

Rebuild:

```powershell
cd "C:\Docs\_AI Python Projects\Roblox_Benji"
python tools/scenery/pipeline.py build --package assets/scenery/mud-grassland
python tools/scenery/pipeline.py verify --package assets/scenery/mud-grassland
```

## Roblox upload

The optimized GLB was uploaded through:

```text
tools/roblox/upload_asset.ps1
```

Roblox asset:

```text
Asset ID: 94913205102557
Asset name: MudGrassland
Asset type: Model
```

Do not upload it again. The upload receipt is stored outside the repository at:

```text
C:\Users\joshb\AppData\Local\RobloxCodex\uploads\e2b95e84d20944ec75cce5381730afb8299523bf78d9467b76e00f60721089a0.json
```

## Studio state

Connected Studio:

```text
Studio: ENGAGE
Place ID: 121549226728648
Studio ID: 9ac7b3c8-ca96-4b33-969f-2d8f5d241249
Mode: Edit
Rojo project: Arena
Rojo address: localhost:34872
```

The asset was inserted temporarily at:

```text
Workspace.MudGrassland_Review.MudGrassland
```

This review copy was moved to Y=1000 so it does not interfere with the existing
map. Its two MeshParts were anchored and set to:

```text
CanCollide = false
CanTouch = false
CanQuery = false
```

The package warning in Studio was acknowledged with **OK**, preserving local review
changes without publishing them back to the package.

The screenshot showed the existing map below and the Mud Grassland review model
above it. This is expected review placement, not final map integration.

Once the asset has been reviewed, remove `Workspace.MudGrassland_Review` from the
existing ENGAGE place. Do not move the review copy onto the current map.

## Project map architecture

Map definitions live under:

```text
src/shared/Maps/
```

Existing examples include:

```text
src/shared/Maps/Forest.lua
src/shared/Maps/Swamp.lua
src/shared/Maps/SnowFortress.lua
```

`src/server/Services/MapService.lua` loads a map module by name from
`ReplicatedStorage.Shared.Maps` and builds the map. Map rotation is configured in:

```text
src/shared/Config.lua
```

Relevant current settings include `Maps`, `StartupMap`, and `ConvergenceMaps`.

## Remaining implementation

1. Create `src/shared/Maps/MudGrassland.lua`.
2. Define a playable layout separate from the current map:
   - map bounds
   - Blue and Red spawns
   - objectives required by the selected mode
   - safe points/recovery data
   - barriers and terrain presentation
   - Mud Grassland scenery placement
3. Add `MudGrassland` to the appropriate rotation in `src/shared/Config.lua`.
4. Add runtime dressing for asset ID `94913205102557`.
   - Prefer the repository-backed upload indirection in `src/shared/Uploads.lua`.
   - Keep the map functional when the asset ID is unavailable by falling back to
     simple terrain/placeholder art.
   - Parent generated art under the map lifecycle so reloads do not duplicate it.
5. If using the existing map service only, add a map-specific scenery hook rather
   than hardcoding the asset into Snow Fortress or Arena.
6. Start Rojo and reconnect Studio if required:

```powershell
cd "C:\Docs\_AI Python Projects\Roblox_Benji"
rojo serve
```

7. Test the new map in Edit/Play mode without changing the existing map.
8. Verify map reload, map vote/forced-map selection, spawns, objectives, collision,
   visibility, and duplicate cleanup.
9. Save only after the separate map review is accepted. Do not publish the package
   or live experience as part of the initial review.

## Important distinction

The uploaded model is not automatically a playable map. Uploading creates a Roblox
asset; inserting it into `Workspace` creates a review instance; a playable map
requires a new map layout module plus map rotation/runtime integration.

Do not tell the user that `MudGrassland` is selectable until the new map module,
rotation entry, scenery hook, and Play-mode evidence all exist.

## Additional quality considerations

### Treat the asset as a scenery patch, not a complete map

The optimized asset is approximately 128 × 129 × 22.5 studs. It is much smaller
than the project's roughly 420-stud-wide Swamp-style battlefields. Decide explicitly
whether Mud Grassland is:

- a central landmark or terrain island surrounded by authored gameplay space,
- a repeated/tiled scenery kit, or
- the visual ground for a smaller map with correspondingly smaller bounds.

Do not stretch one copy to fill the whole arena without checking texture scale,
triangle density, sightlines, and the player journey. Repeated copies need controlled
rotation/variation so seams and repetition are not obvious.

### Leave headroom below the mesh limit

The current export is exactly 10,000 triangles. That passed the current local check,
but a safer future target is 8,000–9,000 triangles per MeshPart so exporter/importer
changes do not land exactly on the platform limit. If the asset is split into several
parts, record each part's triangle count and total scene budget.

### Recheck materials in Studio

Blender reported that more than one shader image node was used for a texture during
export. The Studio review also looked dark/bluish from the review camera. Before
integration, verify:

- base color is connected to the intended image,
- the normal map uses the correct OpenGL orientation,
- roughness is not being interpreted as a color map,
- grass alpha/cutout behaves correctly if transparency is intended,
- the appearance is readable under the actual map lighting.

If the grass becomes noisy or disappears, create a simpler Roblox material/texture
variant rather than relying on the original Blender shader graph.

### Separate visual and gameplay geometry

Keep the imported scenery non-collidable by default. Add simple authored collision
only for surfaces players should stand on or obstacles that should block movement and
projectiles. Record those collision boxes in the map implementation so they survive
Rojo rebuilds and map reloads.

### Test the player experience, not just the import

Acceptance should include:

- player-height approach and close-up views,
- spawn safety and time to first engagement,
- objective visibility and route clarity,
- cover and sightline checks,
- projectile collision checks,
- map reload without duplicate scenery,
- fallback behavior if the uploaded asset is unavailable,
- performance on the target device or graphics tier.

### Keep the review lifecycle explicit

The temporary Studio folder is only a review aid. After the separate map is wired,
remove `Workspace.MudGrassland_Review` from the existing ENGAGE place and verify that
the current map still starts normally. Save the new map only after the fresh Play
session passes; publishing the experience remains a separate user-authorized step.

## Suggested next agent message

“I will create `src/shared/Maps/MudGrassland.lua`, add it to the appropriate map
rotation, connect asset `94913205102557` through the existing upload indirection,
remove the temporary review copy from the current ENGAGE place, and verify the new
map in a fresh Play session. I will not modify Snow Fortress or publish the live
experience.”
