# Resume here: broken tank prop

## User direction and intake

The user supplied `Tank/brokentank.glb` and said "now this" after requesting
local Roblox-ready exports of other 3D props. Their established preference is
to upload assets themselves. The nearby `Tank/BrokenTank.png` is preserved as
`source/reference.png`; the supplied GLB is `source/original.glb`. Treat this
as a **static decorative wreck** at a provisional size, not an operable tank.
The user has not specified final map placement or dimensions.

## Current evidence and stage

Appraisal found one UV-mapped 3D mesh, 291,219 triangles, 221,693 open edges,
and a roughly 1 x 1 x 0.35 unit envelope. It has depth and is an all-angle
prop. Its source BaseColor image averages roughly RGB (54, 63, 79), already
dark blue-gray, so the local export keeps the source palette without a tint.

Local export and verification are complete. `exports/BrokenTank.glb` is
16,915,628 bytes and SHA256
`9e8681bbd7f5d8b4c759c046c91a0d230b911851c5ab09ff13f142709a0355c4`.
It contains 72,804 triangles in 12 named meshes, each at or below 9,000.
Written-file bounds are approximately 17.2 x 17.3 x 6 studs, Y up and base
at Y=0. Two PNG material maps are embedded. The build's validation passed,
and a local upload-size dry run passed without a network request. Source and
export views were inspected; the turret, broken hull, and debris remain
recognizable from several angles.

The `lune run tools/check_assets.luau` command could not start in this shell
(`The system cannot find the path specified`), so that repository gate is
unverified. No Studio import, user visual approval, saved placement, or
publication has been established.

## Next action

The user can upload `exports/BrokenTank.glb`. After Studio import, inspect
12 MeshParts and their SurfaceAppearance maps under the intended map lighting,
anchor the Model, and add simple collision if players can touch it. Record the
actual uploaded asset ID, approved size, placement, and saved-place evidence
here if work resumes. Do not infer any of those from local export checks.
