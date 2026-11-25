# Resume here: light-cage-wall

## Current truth

- Packaged cleanly from `UndergroundFacilityProps/UndergroundFacilityProps_FreeSample/UndergroundFacilityProps_FreeSample/FBX/Light_Cage_Wall.fbx` into `exports/LightCageWall.glb` (1,152 triangles, 2.40 x 2.40 x 2.18 studs, OpenGL 1024x1024 PNG textures embedded).
- Uploaded to Roblox Open Cloud under User `3678531109` (`Model` Asset ID: `137096761422753`).
- Verified in `ENGAGE` Roblox Studio Edit session (`caa79792-c2bb-45aa-b680-9c7db6bab1e8`) via `insert_asset` + property inspection:
  - `Light_Cage_Wall`: `rbxassetid://104104323610061` (2.40 x 2.40 x 2.13 studs) | SA: Color=rbxassetid://81295133992292, Normal=rbxassetid://106809109272131, Roughness=rbxassetid://74066780797341, Metalness=rbxassetid://132765954272792
  - `Light_Cage_Wall_Glow`: `rbxassetid://78457213058005` (1.81 x 1.81 x 1.09 studs) | SA: Color=rbxassetid://81295133992292, Normal=rbxassetid://106809109272131, Roughness=rbxassetid://74066780797341, Metalness=rbxassetid://132765954272792
- Integrated into `assets/environment/decor/SciFiFoundry.rbxmx` (loaded by `MapService.lua` via `ServerStorage.MapDecor.SciFiFoundry` for both `SciFiFoundry` and `SciFiFoundryTDM`) as Spawn bay & outer wing bulkhead wall cage lights in SciFiFoundry.

## Studio record

- Asset owner: `User 3678531109`
- Uploaded Model asset ID: `rbxassetid://137096761422753`
- Verified in Studio Edit: YES (inserted, inspected `MeshId`, `MeshSize`, `SurfaceAppearance`, cleaned temporary `__Inspect_*` instance)
- Target map: `SciFiFoundry` (and `SciFiFoundryTDM`)

## Next action

- Open `ENGAGE` in Studio (`rojo serve`) and run `/explore SciFiFoundry` to visually verify placement, lighting, and collision in live Play mode.
