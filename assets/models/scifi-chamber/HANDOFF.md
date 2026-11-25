# Resume here: scifi-chamber

## Current truth

- Packaged cleanly from `UndergroundFacilityProps/scifi-props-pack-01/source/ScifiProps/Scifi_Props_Pack_01.fbx (SciFi_Chamber)` into `exports/ScifiChamber.glb` (1,088 triangles, 5.39 x 10.50 x 5.39 studs, flipped DirectX->OpenGL 1024x1024 PNG textures embedded + separate translucent Glass mesh).
- Uploaded to Roblox Open Cloud under User `3678531109` (`Model` Asset ID: `132772119580578`).
- Verified in `ENGAGE` Roblox Studio Edit session (`caa79792-c2bb-45aa-b680-9c7db6bab1e8`) via `insert_asset` + property inspection:
  - `Base`: `rbxassetid://101858467157064` (5.39 x 10.50 x 5.39 studs) | SA: Color=rbxassetid://91652780573796, Normal=rbxassetid://89692045570467, Roughness=rbxassetid://73822917005144, Metalness=rbxassetid://133120130584107
  - `Glass`: `rbxassetid://138562219324774` (4.31 x 9.19 x 4.31 studs) | SA: none (translucent Glass Material)
- Integrated into `assets/environment/decor/SciFiFoundry.rbxmx` (loaded by `MapService.lua` via `ServerStorage.MapDecor.SciFiFoundry` for both `SciFiFoundry` and `SciFiFoundryTDM`) as Cryo Bay & outer wing backlit glass containment chambers on diamond-tread plinths in SciFiFoundry.

## Studio record

- Asset owner: `User 3678531109`
- Uploaded Model asset ID: `rbxassetid://132772119580578`
- Verified in Studio Edit: YES (inserted, inspected `MeshId`, `MeshSize`, `SurfaceAppearance`, cleaned temporary `__Inspect_*` instance)
- Target map: `SciFiFoundry` (and `SciFiFoundryTDM`)

## Next action

- Open `ENGAGE` in Studio (`rojo serve`) and run `/explore SciFiFoundry` to visually verify placement, lighting, and collision in live Play mode.
