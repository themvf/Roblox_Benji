# White sci-fi tube prop

This package is based on the user's `SciFiTubes/biggertube.png`. That folder
also contains `bluetubelarge.glb`, but it depicts a different blue tube, so
this white canister was modeled from the image. The front access plate, dark
top and lower bands, white cap, and amber status detail follow the reference.
The unseen rear and sides are simple inferred continuations.

## File to upload

Import `exports/WhiteSciFiTube.glb` into Roblox Studio. It is 12 studs high,
about 4.1 studs in diameter, Y-up, centered on X/Z, with its base at Y=0.
The scale is provisional. It has five named mesh groups with five embedded
PNG ColorMaps, also saved in `textures/`. Studio may split WhiteHousing into
two MeshParts, for six MeshParts total. All groups stay below the
10,000-triangle-per-mesh limit. The GLB is about 0.72 MB.

This is a static decorative housing; it has no interaction or scripted light.
After import, verify the six MeshParts, their `SurfaceAppearance.ColorMap`
values, and their pale, graphite, and amber colors in the target lighting.
Anchor the model. If players need to bump into
it, use a simple invisible cylinder or box for collision. Save the placed
model in the intended map. Studio import and placement remain unverified.

## Rebuild and evidence

From the repository root:

```powershell
python tools/build_white_scifi_tube.py
```

The builder creates subtle material textures and the mesh in Blender, then
checks dimensions, embedded maps, triangle counts, and hashes.
`validation.json` records the latest
export check. `review/` contains front, side, and rear renders of the export.
The local upload-size dry run passed without contacting Roblox.

## Current Studio copy

The first GLB relied on material color factors. The connected Studio import
turned all six MeshParts the same gray and assigned no ColorMaps. The placed
copy under `Workspace.Scene` has now been given distinct MeshPart colors and
anchored, so its dark bands and amber accents are visible, but it remains
untextured. Reimport the updated GLB above to get actual embedded color maps.
Save the Studio place after replacing or recoloring the copy.
