# Resume here: scifi-container

## Current truth

- Packaged cleanly from `UndergroundFacilityProps/scifi-props-pack-01/source/ScifiProps/Scifi_Props_Pack_01.fbx (Container)` into `exports/ScifiContainer.glb` (1,456 triangles, 5.41 x 5.33 x 5.60 studs, flipped DirectX->OpenGL 1024x1024 PNG textures embedded).
- Uploaded to Roblox Open Cloud under User `3678531109` (`Model` Asset ID: `87549662307240`).
- Verified in `ENGAGE` Roblox Studio Edit session (`caa79792-c2bb-45aa-b680-9c7db6bab1e8`) via `insert_asset` + property inspection:
  - `Container`: `rbxassetid://130331310814567` (5.41 x 5.33 x 5.60 studs) | SA: Color=rbxassetid://76859172271463, Normal=rbxassetid://72431067255628, Roughness=rbxassetid://98051894001588, Metalness=rbxassetid://91574480680855
- Integrated into `assets/environment/decor/SciFiFoundry.rbxmx` (loaded by `MapService.lua` via `ServerStorage.MapDecor.SciFiFoundry` for both `SciFiFoundry` and `SciFiFoundryTDM`) as Main-bay & rear-forge solid hazard containers replacing generic crates in SciFiFoundry.

## Studio record

- Asset owner: `User 3678531109`
- Uploaded Model asset ID: `rbxassetid://87549662307240`
- Verified in Studio Edit: YES (inserted, inspected `MeshId`, `MeshSize`, `SurfaceAppearance`, cleaned temporary `__Inspect_*` instance)
- Target map: `SciFiFoundry` (and `SciFiFoundryTDM`)

## Next action

- Open `ENGAGE` in Studio (`rojo serve`) and run `/explore SciFiFoundry` to visually verify placement, lighting, and collision in live Play mode.
