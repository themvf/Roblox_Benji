# Resume here: scifi-generator

## Current truth

- Packaged cleanly from `UndergroundFacilityProps/scifi-props-pack-01/source/ScifiProps/Scifi_Props_Pack_01.fbx (Generator)` into `exports/ScifiGenerator.glb` (3,438 triangles, 13.50 x 6.50 x 6.75 studs, flipped DirectX->OpenGL 1024x1024 PNG textures embedded).
- Uploaded to Roblox Open Cloud under User `3678531109` (`Model` Asset ID: `119357775236658`).
- Verified in `ENGAGE` Roblox Studio Edit session (`caa79792-c2bb-45aa-b680-9c7db6bab1e8`) via `insert_asset` + property inspection:
  - `Generator`: `rbxassetid://131758847316064` (13.50 x 6.50 x 6.75 studs) | SA: Color=rbxassetid://101163715733909, Normal=rbxassetid://138353581812443, Roughness=rbxassetid://90834354473226, Metalness=rbxassetid://77221028656075
- Integrated into `assets/environment/decor/SciFiFoundry.rbxmx` (loaded by `MapService.lua` via `ServerStorage.MapDecor.SciFiFoundry` for both `SciFiFoundry` and `SciFiFoundryTDM`) as Cryo & Reactor wing heavy turbine generators on diamond-tread plinths in SciFiFoundry.

## Studio record

- Asset owner: `User 3678531109`
- Uploaded Model asset ID: `rbxassetid://119357775236658`
- Verified in Studio Edit: YES (inserted, inspected `MeshId`, `MeshSize`, `SurfaceAppearance`, cleaned temporary `__Inspect_*` instance)
- Target map: `SciFiFoundry` (and `SciFiFoundryTDM`)

## Next action

- Open `ENGAGE` in Studio (`rojo serve`) and run `/explore SciFiFoundry` to visually verify placement, lighting, and collision in live Play mode.
