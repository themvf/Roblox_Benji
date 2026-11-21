# Resume here: white sci-fi tube

## October 4 color correction

The user imported the original material-only GLB into the connected `ENGAGE`
Studio place and reported no color or texture. Studio inspection confirmed
six MeshParts under `Workspace.Scene.Tube_*_Node` (WhiteHousing split into two),
all with the same gray `MeshPart.Color` and no `SurfaceAppearance` or texture
IDs. The original GLB's material color factors did not carry through import.

In Studio Edit, I applied distinct `MeshPart.Color` values: WhiteHousing RGB
(180,190,194), GunmetalDetails (65,78,84), DarkRecesses (32,43,48),
PalePanels (218,221,218), and AmberLights (235,95,25). I anchored all six
pieces. A Studio capture showed dark top and lower bands, a framed front plate,
and amber indicators. The placed copy now has color, but still lacks texture
maps. The Studio place has not been saved or published; the user must save it.

I rebuilt `exports/WhiteSciFiTube.glb` with five embedded 128x128 PNG
ColorMaps, retaining the prior material-only GLB in `trials/`. The current
export is 722,004 bytes, SHA256
`ca99963012b6418b1e7833cc596729361ad1d142965411dd22b908425ff52677`.
`validation.json` confirms all five maps are embedded and referenced by the
materials. The final export was rendered from the front, and the local
upload-size dry run passed. A fresh Studio import of this updated GLB is
unverified. The user handles upload; no upload was made.

Next: reimport the updated GLB, verify ColorMaps on the new MeshParts, replace
the material-only copy if successful, and save the place. Do not infer that
the updated GLB is already in Studio.

## User direction and source

The user supplied `SciFiTubes/biggertube.png` and said "now this", continuing
their established request for locally saved Roblox-ready 3D props that they
upload themselves. The image is preserved as `source/reference.png`.
The nearby `SciFiTubes/bluetubelarge.glb` and existing
`assets/models/bluetube/BlueTube.glb` correspond to a different blue tube;
they were not used for this white canister. No size or target placement was
specified, so 12 studs high is provisional. Intended role is static scenery.

## Evidence and current stage

The source is a front-view image, not a 3D mesh. The white cylindrical body,
dark top and lower recesses, front access panel, and small amber indicator
are visible. Rear and side details were inferred. A reproducible procedural
builder created `exports/WhiteSciFiTube.glb` with five mesh groups, 10,492
total triangles, and a maximum of 7,088 on one mesh. Written-file dimensions
are about 4.112 x 12 x 4.112 studs, Y-up, with its base at Y=0. The initial
material-only export is retained in `trials/`; the current export embeds PNG
ColorMaps as described above.

`validation.json` passed its mesh, dimensions, material, texture, and orientation
checks. Front, side, and rear renders of the exported GLB were inspected.
The local upload-size dry run passed without a network request. User visual
approval of the updated exported model, its Studio import, saved placement,
and publication are still unverified.

## Next action

The user can upload `exports/WhiteSciFiTube.glb`. On import, verify its five
mesh groups, six material sections, and ColorMaps under target lighting;
anchor the model, add a
simple collision proxy if reachable by players, and save its placement.
Record any asset ID, approved size, Studio screenshot, and saved-place
evidence here if work resumes.
