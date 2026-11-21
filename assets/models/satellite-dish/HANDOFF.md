# Resume here: satellite dish prop

## October 4 Studio color update

The user imported the GLB into the connected `ENGAGE` Studio place
(PlaceId `121549226728648`) and reported that it looked white against the
snow. Inspection found all 10 MeshParts had valid `SurfaceAppearance` color,
metalness, and roughness map asset IDs. The supplied BaseColor map itself is
mostly pale gray (mean RGB about 194/195/193), consistent with the reference.
All imported `SurfaceAppearance.Color` values were white; the MeshPart gray
color does not tint an opaque ColorMap.

In Studio Edit, I changed each dish `SurfaceAppearance.Color` to RGB
`55, 82, 110` (muted deep blue-gray), then moved the import from the loose
`Workspace.Scene` model into
`Workspace.MyMap — EDITABLE.Geometry.SatelliteDish` without changing its world
position. An edit-time capture showed stronger contrast against the snow. A
Play check confirmed `Workspace.Map.Geometry.SatelliteDish` contains all 10
pieces with the same tint, and Studio was returned to Edit mode. The user
still needs to save the place and save the edited MyMap source model to file;
no publication or permanent save was verified. The local GLB remains the
original pale version; reimports need the tint reapplied.

## User direction

The user supplied `Satellite Dish/sample_2026-10-04T223857.672.glb` and said
"now this" after receiving a locally saved orbital station export. Their
established preference is to upload Roblox assets themselves. Save a Roblox-ready
GLB locally; do not upload it on their behalf. The nearby concept image
`Satellite Dish/0_2.png` is preserved as `source/reference.png` and the GLB
as `source/original.glb`.

## Current evidence and stage

Initial appraisal: one UV-mapped 3D mesh, 281,033 triangles, 134,273 open
edges, and a normalized envelope near one unit on each axis. This is an
all-angle prop, not a flat backdrop. Local export and visual verification are
complete. `exports/SatelliteDish.glb` is 9,740,412 bytes and contains 70,257
triangles across 10 named meshes; each is below 10,000. The written file is
16 studs high, its base is at Y=0, and two PNG maps are embedded. Source,
export, and texture hashes are in `validation.json`. Source and front/back/side
export renders were inspected against `source/reference.png`; the dish, feed
arms, mount, and pedestal remain recognizable. Purpose is a non-walkable
decorative satellite dish; exact map and final size were not specified. The
16-stud scale is provisional and can be changed in Studio.

The standalone export checks and upload size dry run passed. The shared
`check_assets` command accepts this package but still fails on the unrelated,
pre-existing missing appraisal at `assets/scenery/mud-grassland`.

## Next action

The user will handle upload and placement. After import, verify all 10
MeshParts and SurfaceAppearance textures under Roblox lighting, anchor the
model, and add simple base collision only if needed. Record any uploaded asset
ID and saved map placement here if this work resumes. Do not infer Studio
import or saved map integration from local checks.
