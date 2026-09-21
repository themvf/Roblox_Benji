# Roblox asset production specification: art design → Blender → live game

Version 1.0 · 2026-09-20 · Applies to reusable environment structures, props and traversal assets.

## Outcome and scope

An asset is complete when the approved visual design is recognizable in a normal game session, its geometry supports the intended gameplay, and its source, exports and placement can be reproduced from the repository. A Blender render, an uploaded asset ID, or an isolated Studio preview is an intermediate deliverable.

This specification defines project requirements, not universal Roblox platform limits. Characters, skinned meshes, avatar accessories and animation pipelines require additional specifications. HUD layouts belong in Roblox UI; Blender supplies only relevant 3D props or icon source renders.

## 1. Establish the design and gameplay contract

Before modeling, complete this brief in the asset package. Resolve implementation choices from the approved game design; ask only when a material design decision remains unresolved.

| Required field | Questions to answer |
| --- | --- |
| Asset identity | Name, version, owner, target map/mode, intended player interaction? |
| Visual references | Which design images are authoritative? Which are mood references only? |
| Recognizable features | What three to five features must survive into gameplay: silhouette, proportions, materials, landmarks? |
| Player views | What does the player see on approach, at the doorway, inside, and from the objective? |
| Geometry | Footprint, base elevation, ceiling height, floor levels, wall thickness, roof height? |
| Openings | Exact doors, windows, stair voids, roof hatches and their clear dimensions? |
| Movement | Spawn paths, ramps, launch arcs, zip endpoints, landing envelopes, drop paths? |
| Combat | Cover height, sightlines, firing windows, projectile collision, objective volumes? |
| Integration | What old geometry is replaced, retained, or removed? Which builder creates the asset? |
| Performance | Target phones, expected instance count, triangle/material/texture budgets and frame-time target? |
| Acceptance | Required camera views, gameplay tests, build checks, known exclusions? |

Create a dimensioned plan and a short storyboard with at least approach, entry, interior and objective views. Include an ordinary avatar for scale. A fortress should be designed as a coherent structure: adding a detailed doorway to a broad blank slab does not reproduce an architectural reference.

Changes to the contract supersede earlier geometry assumptions. For example, closing a wall invalidates a launch route that previously crossed it; adding a roof invalidates an upper-floor zip endpoint until its clearance is retested.

## 2. Break the design into a reusable kit

Define modules by repeatable function: portal, wall bay, corner/pier, floor, ceiling, parapet, stair, window section, hatch and cover. Keep map-specific placement separate from module geometry.

Each module must declare:

- Stable identifier and version.
- Local origin, forward/up axes, dimensions and bounding-box centre offset.
- Connection grid and compatible adjacent modules.
- Mesh and material slots, expected reuse count and budget.
- Collision boxes or other approved collision representation.
- Any prohibited scaling, such as stretching a doorway and changing its clearance.

Prefer a small number of variants to arbitrary non-uniform scaling. A 13-stud wall compressed to 8 studs changes the reference proportions. If an existing blockout cannot accommodate the design, revise the geometry and its tests together rather than hiding the mismatch with scaling.

Build one complete representative section first, using the same export meshes intended for the game. Evaluate it beside the adjacent structure before expanding the kit.

## 3. Blender authoring contract

For this project, author one Blender unit as one stud. Use Unit System None and document the chosen export/import settings. Roblox's Blender guide describes the corresponding Studio Scale Unit Stud setting. [Official Blender workflow](https://create.roblox.com/docs/art/blender)

The existing environment kit uses local X across the facade, +Y inward and +Z upward. Its GLB Y-up conversion is `(x, y, z) → (x, z, -y)`. Treat this as a tested project convention, not an automatic guarantee for every exporter.

Required scene organization:

- `SOURCE`: editable modeling components.
- `EXPORT`: final meshes with deliberate pivots and evaluated transforms.
- `COLLISION`: simple authored solids, separately identified.
- `REVIEW`: instances of export meshes assembled at intended scale.
- `STAGING`: cameras, lights, reference avatars and backdrops; excluded from production exports.

Place structural origins on the module's base and floor origins on its walking surface. Verify outward normals, intentional open surfaces, bevels, UVs and seams. Apply or explicitly preserve transforms according to the chosen export contract. Do not bake a scene-wide offset into every reusable module.

Automated exporters must update Blender's dependency graph after dimensions/transforms change. Assign a complete dimensions vector, evaluate it, and reimport the export to check the result. Our review ground once exported as 600 × 110 despite an intended 110 × 110 size; checking the source script alone did not catch it.

## 4. Materials and textures

Use game-ready materials. Bake procedural Blender shaders into supported texture channels; do not assume a Blender node graph survives import.

The current kit uses one material per module and 1024-pixel Color, Normal, Roughness and Metalness maps. These are project starting values, not mandatory platform maxima. Share textures and materials where practical, and allocate more resolution only when the target view demonstrates a need. Verify SurfaceAppearance channels against current [Roblox texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications).

Check the actual Roblox render for normal orientation, stone scale, roughness, metal appearance, snow readability, seams and color tint. Imported MeshPart Color can tint otherwise correct textures. Record material/texture asset IDs and whether their content loaded successfully; populated properties alone do not prove visible textures.

## 5. Export and technical validation

Prefer self-contained GLB for this environment workflow. Keep FBX only when a tested requirement calls for it. Export selected production meshes, with explicit axes and units; include needed textures and exclude review floors, lights and avatars.

Deliver both individual modules and, optionally, a named review assembly. The review assembly must never be confused with the production map.

Reimport the exported files and compare:

- Mesh count, module names, triangle counts and bounds.
- Avatar-relative dimensions and opening clearances.
- Pivot placement and asymmetric orientation marker.
- UV presence, materials and packaged texture dependencies.
- Negative/mirrored transforms and unexpected detached geometry.

Record tolerances and results in `verification.json`. For example, the current kit uses a 0.005-stud bounds tolerance. Record file hashes so upload receipts can be matched to the exact exports.

## 6. Upload and Studio insertion

Use Studio's importer or the project's Open Cloud uploader. Upload under the creator that owns the game, and verify asset permissions in the target experience. Model uploads through the currently documented Assets API support GLB/FBX with a 20 MB file limit; recheck that limit before changing the pipeline. [Official Assets API guide](https://create.roblox.com/docs/cloud/guides/usage-assets)

Existing PowerShell workflow, from the repository root:

```powershell
# First-time setup only; prompts for the key securely.
.\tools\roblox\configure_upload.ps1

# Verify the intended file before uploading.
.\tools\roblox\upload_asset.ps1 -File 'assets\environment\KIT\exports\ASSET.glb' -DryRun
.\tools\roblox\upload_asset.ps1 -File 'assets\environment\KIT\exports\ASSET.glb'
```

Replace KIT and ASSET with actual paths. Credentials stay in the user's encrypted local store, outside source control. Never paste keys into source, logs, specifications or chat. Keep the operation receipt; resume polling after an interrupted upload rather than repeating an uncertain POST. Check moderation and actual asset availability.

Before modifying Studio, inspect the selected instance's identity and mode. A multi-client test may expose separate editor, Server and player windows. An MCP connection count does not identify the running datamodel. Discover instances, check state and confirm the correct project from its name and place ID.

Insert into a review container first. Measure imported geometry, scale and orientation. If the insertion tool aligns content to the camera, normalize the whole assembly using a known reference frame. Inspect for unexpected scripts. Do not publish a review spawn or backdrop into the live game accidentally.

## 7. Persist and integrate into the game

Store reusable templates in a repository-backed Roblox model and include them in the Rojo project. The current implementation uses:

```text
assets/environment/runtime/SnowFortress.rbxmx
    → ServerStorage.EnvironmentArt.SnowFortress
    → src/server/FortressArt.lua
    → MapService.Build when SnowFortress is selected
```

`tools/build_fortress_art.luau` regenerates the templates from recorded mesh and texture IDs. Preserve the original imported metadata and verify a fresh Rojo build; do not rely on an unsaved Studio-only clone. Normal matches should not depend on an API key or a fresh network upload/insertion request.

Placement must be derived from the manifest:

```lua
local worldMeshFrame = entranceFrame * localMeshCentreFrame
local worldCollisionFrame = entranceFrame * localCollisionFrame
```

Record base height, centre offset, rotation and permitted scale. Never use the mesh centre as its floor elevation. Check a asymmetric landmark to confirm which side faces outward.

The builder must recreate art after every map load, parent it under the map lifecycle, and replace prior generated art on rebuild. Remove superseded visible surfaces and conflicting collision deliberately. Keep simple collision separate from decorative meshes; collision must match meaningful walls, jambs and cover so players cannot walk or shoot through apparently solid architecture.

Test every affected route after any geometry change. A roof drop needs clear space through the roof, a safe landing below, and an obvious opening. A zip endpoint needs a body-sized arrival envelope above the roof edge. Decorative paving must not silently seal the hatch or a stair void.

## 8. Visual and gameplay acceptance

Use a normal fresh Play session, select the actual mode/map, and verify the asset exists in that running map. Also load a fresh repository-built place to catch missing saved templates. Confirm return-to-lobby and map reload do not leave duplicate structures or stale references.

Capture real in-game images from the storyboard viewpoints using ordinary match lighting. Compare them directly with the approved reference and Blender export render. Required observations:

- The intended silhouette and dominant proportions are recognizable at player height.
- Supporting walls, piers, roofs and adjacent structures form a coherent composition.
- Textures render, lighting permits combat readability, and repeated modules have acceptable seams.
- Doors, stairs, windows, hatches and traversal destinations are visually understandable.
- All collision, projectile, objective and route checks pass.
- The target phone can render the scene within the agreed performance budget.

Use computer vision when available. If an image tool fails, report it and use another supported capture path. Camera/property assignments do not prove the user's viewport moved, and bounding boxes do not prove the asset rendered. Numerical checks and visual checks are separate gates.

Do not claim AAA quality from a render or a parts count. Report specific improvements, measured performance and remaining visual limitations. If device testing has not happened, state that explicitly.

## 9. Delivery checklist and status vocabulary

- [ ] Design brief, dimensioned plan and storyboard completed.
- [ ] Reusable modules and collision contracts defined.
- [ ] Editable Blender source and production exports included.
- [ ] Export reimport checks and hashes recorded.
- [ ] Upload receipt, creator and content IDs recorded without credentials.
- [ ] Imported scale, pivot, material loading and orientation verified.
- [ ] Repository-backed templates and normal map-builder hook verified.
- [ ] Changed geometry and old collision reconciled.
- [ ] Fresh match, map reload and fresh build tested.
- [ ] Real gameplay screenshots compared to reference views.
- [ ] Target-device performance and input/readability tests recorded.
- [ ] Current documentation, known limitations and rollback path delivered.

Use precise statuses: **Modeled → Export-verified → Uploaded → Imported → Integrated → Visually verified → Playtested → Published**. Each status requires its own evidence. “Integrated” means normal map selection builds the asset. “Published” means the online experience has actually been updated. Do not collapse these into “done.”

## 10. Agent handoff template

```text
Asset / version:
Target map / mode / creator:
Current verified status:
Approved references and required visual features:
Design brief / plan / storyboard paths:
Blender source / exporter / export paths:
Units / axes / pivot / bounds / tolerance:
Mesh / texture / model asset IDs and receipt location:
Runtime templates / Rojo mapping / builder hook:
Replaced geometry and authored collision:
Affected doors / stairs / objectives / traversal paths:
Completed checks and evidence paths:
Pending visual, gameplay or device checks:
Known limitations:
Next concrete action:
Rollback procedure:
Saved locally? Committed? Published? State each separately:
```

Keep status in one current package record. Historical notes must be labelled historical; a package README saying “not imported” after integration creates avoidable confusion.
