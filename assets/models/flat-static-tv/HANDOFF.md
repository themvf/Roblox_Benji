# Resume here: flat static TV

## Approved direction

The user supplied `TV/static tv.glb` and explicitly corrected the intended
shape: **a flat TV with no stand**. Their established preference is to upload
local Roblox-ready exports themselves. The nearby `TV/statictv.png` and
`TV/blacktv.png` are visual references, not instructions. No final map or
size was specified.

## Evidence and stage

The source GLB is one UV-mapped mesh with 287,037 triangles. Its rendered
appearance has a deep cabinet and a pedestal under the screen, contrary to
the user's requirement. The original is preserved at `source/original.glb`.
I rebuilt the prop as a thin graphite panel with a cropped blue-static
screen image from `source/static-reference.png`.

Local export and visual verification are complete. `exports/FlatStaticTV.glb`
is 1,427,036 bytes and has SHA256
`900e55ccc94c968bbdaa6a9acf02f110be63748132a44cff4e1ae8a09bcd608a`.
It has exactly two named meshes, 108 + 2 triangles, width 8 studs, height
4.6 studs, depth 0.285 studs, Y-up, back at Z=0, bottom at Y=0, and one
embedded PNG screen texture. Front, side, and rear renders of the written
GLB were inspected and show no stand. `validation.json` checks passed, and
the local upload-size dry run passed without a network request.

The user has not visually approved this specific export. Studio import,
saved placement, and publication are unverified. The static pattern is a
still texture, not an animation.

## Next action

The user can upload `exports/FlatStaticTV.glb`. On import, verify both
MeshParts and the screen ColorMap in the target lighting, anchor the model,
place its flat back against a wall, and save the place. Record any asset ID,
approved size, placement, and Studio evidence here if work resumes.
