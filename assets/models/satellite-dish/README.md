# Satellite dish visual prop

The user's `Satellite Dish/sample_2026-10-04T223857.672.glb` is preserved as
`source/original.glb`; `source/reference.png` is the nearby concept image.
The source is a textured 3D scan with 281,033 triangles and UVs.

## Delivery

`exports/SatelliteDish.glb` is the file to import into Roblox Studio. It is
16 studs high, about 17.8 by 15.3 studs across, centered on X/Z, with the
base at Y=0. The visual mesh is 70,257 triangles split into 10 named pieces;
each piece stays below Roblox's 10,000-triangle-per-mesh limit. Two PNG
material maps are embedded and also preserved in `textures/`.

The 16-stud scale is provisional because the user did not specify a target
map or final size. This is visual art, not walkable collision geometry. If
players must bump into its pedestal, add a simple anchored collider in Studio
after import instead of relying on the open scan's mesh collision.

## Rebuild and evidence

From the repository root:

```powershell
python tools/build_satellite_dish.py
```

The builder extracts the supplied textures, reduces the scan, divides it into
sector meshes, writes the GLB, and validates the written bounds, triangle
counts, texture formats, and hashes. `validation.json` is the latest local
check. `review/` contains source and final GLB renders from several angles.

## Studio import

The user will upload the saved GLB. After import, verify 10 MeshParts and
their SurfaceAppearance maps, set `MeshPart.Color` to white if Studio's tint
dims the texture, then anchor the model. For a decorative placement, leave
the visual chunks noncollidable and add a small pedestal collider if needed.
Save the chosen placement in the intended map. No Studio import or placement
was verified at the time of the local export.

## Color in the current Studio place

The source image and BaseColor map are pale gray, so the default Studio import
looks nearly white on snow. The user's imported dish has working
`SurfaceAppearance` maps. In `ENGAGE` Studio, its ten `SurfaceAppearance.Color`
values were set to RGB `55, 82, 110`, and the model was put under
`MyMap — EDITABLE.Geometry` at its existing position. A Play check found all
ten tinted pieces in `Workspace.Map`. `MeshPart.Color` does not tint an opaque
SurfaceAppearance ColorMap; change `SurfaceAppearance.Color` when adjusting
this look. This Studio edit does not recolor the local GLB. Save the place and
export the edited MyMap `.rbxm` to retain it outside the current session.
