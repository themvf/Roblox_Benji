# Resume here: control-panel

## Current truth

- Packaged cleanly from `UndergroundFacilityProps/scifi-props-pack-01/source/ScifiProps/Scifi_Props_Pack_01.fbx (Control_Panel)` into `exports/ControlPanel.glb` (528 triangles, 2.33 x 5.20 x 1.58 studs, flipped DirectX->OpenGL 1024x1024 PNG textures embedded).
- Uploaded to Roblox Open Cloud under User `3678531109` (`Model` Asset ID: `99769027486274`).
- Verified in `ENGAGE` Roblox Studio Edit session (`caa79792-c2bb-45aa-b680-9c7db6bab1e8`) via `insert_asset` + property inspection:
  - `Control_Panel`: `rbxassetid://127623062517526` (2.33 x 5.20 x 1.58 studs) | SA: Color=rbxassetid://121775128193262, Normal=rbxassetid://114180133863411, Roughness=rbxassetid://103931753673895, Metalness=rbxassetid://83721507994467
- Integrated into `assets/environment/decor/SciFiFoundry.rbxmx` (loaded by `MapService.lua` via `ServerStorage.MapDecor.SciFiFoundry` for both `SciFiFoundry` and `SciFiFoundryTDM`) as Operator terminals replacing old white StandingDesk units & flanking Cryo portal in SciFiFoundry.

## Studio record

- Asset owner: `User 3678531109`
- Uploaded Model asset ID: `rbxassetid://99769027486274`
- Verified in Studio Edit: YES (inserted, inspected `MeshId`, `MeshSize`, `SurfaceAppearance`, cleaned temporary `__Inspect_*` instance)
- Target map: `SciFiFoundry` (and `SciFiFoundryTDM`)

## Next action

- Open `ENGAGE` in Studio (`rojo serve`) and run `/explore SciFiFoundry` to visually verify placement, lighting, and collision in live Play mode.
