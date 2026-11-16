# MilitaryWaveRunner handoff

## Current stage

- Stage: **7, Rebuilt as `.rbxm` with `RenderFidelity = Precise` and `InitialSize` preserved (`ServerStorage.EnvironmentArt.MilitaryWaveRunner`), verified in Studio Edit mode (`102870506274928`), and wired into `VehicleService.buildWaveRunner` — pending live Play driving & viewport review**
- Next action: With `rojo serve` running, **Stop and restart Play** in Studio and run `/explore FiveIslandsHurricane` (or test a match) at the Red/Blue docks (`(±276, 0.35, ±15)`) to visually verify the 4 drivable WaveRunners in-water, forward-facing steering/driving (`-Z` bow), rider seating height (`DriverSeat` at `(0, 1.55, 1.05)`), and PBR look under hurricane lighting.
- Blockers: None locally.

## Approved decisions

- **Role upgrade (drivable WaveRunner replacement):** Replaced the blocky primitive `WaveRunner` shell in `src/server/Services/VehicleService.lua` (`buildWaveRunner`) with the 12-MeshPart `MilitaryWaveRunner` (`102870506274928`) template synced via Rojo (`assets/environment/runtime/MilitaryWaveRunner.rbxm` -> `ServerStorage.EnvironmentArt.MilitaryWaveRunner`).
- **Mesh fidelity, scale & orientation fixes:**
  - Serialized as binary `.rbxm` (`assets/environment/runtime/MilitaryWaveRunner.rbxm`, superseding `.rbxmx`) with explicit `InitialSize` = raw uploaded `MeshSize` and `RenderFidelity = Enum.RenderFidelity.Precise` on all 12 `MeshPart`s — resolving the sharded Automatic-LOD + missing-`InitialSize` distortion seen in the initial Play screenshot.
  - Rotated all 12 `MeshPart`s `180°` around Y so the bow faces `-Z` forward matching `VehicleService` / `VehicleController`.
  - Scaled `0.80x` (`~4.56` wide × `3.63` tall × `8.92` long) with `Y_SHIFT = -1.10` relative to the `3.8 × 1.2 × 8.6` invisible collidable `Hull` (`baseCF` spawned at `Y = 0.35` on docks) so the deep-V keel sits cleanly in the water while `DriverSeat` sits flush on top of the dark seat bolster at `(0, 1.55, 1.05)`.
  - Visual `MeshPart`s are `Massless = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = true, DoubleSided = false` welded cleanly to `Hull`. Primitive `WaveRunner` geometry remains only as a fallback if `EnvironmentArt.MilitaryWaveRunner` is absent.

## Local artifacts

- Generator script (runtime Rojo asset): `tools/build_waverunner_art.luau` -> `assets/environment/runtime/MilitaryWaveRunner.rbxm`
- Runtime spawner integration: `src/server/Services/VehicleService.lua` (`findWaveRunnerTemplate`, `buildWaveRunner`)
- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build military-wave-runner`)
- Source: `assets/models/military-wave-runner/source/MilitaryWaveRunner.glb`
- Export: `assets/models/military-wave-runner/exports/MilitaryWaveRunner.glb`

## Roblox IDs and verification status

- Root Model asset id: `102870506274928` (Open Cloud, `moderationState: Approved`), uploaded with `tools/roblox/upload_asset.ps1`.
- Uploaded export SHA-256: `8caab1c06dbf20c3b1c4ea84e653c03982c728e411afb000c825dd749499285f` (12 meshes, 70,045 triangles, two 1024 PNG textures).
- **Studio Edit-mode `InsertService:LoadAsset(102870506274928)` verification (`ENGAGE placeId: 121549226728648`):**
  - Confirmed 12 `MeshPart`s arrived with bounding box `5.71 × 4.53 × 11.14` studs and bottom-center pivot (`bboxRelCenter = (0, 2.27, 0)`).
  - **Shared `SurfaceAppearance` (`AlphaMode = Overlay`):**
    - `ColorMap`: `rbxassetid://85092293551185`
    - `RoughnessMap`: `rbxassetid://112248916807063`
    - `MetalnessMap`: `rbxassetid://138972594578249`
  - **Verified `MeshPart` `MeshId`s:**
    - `geometry_0.001`: `rbxassetid://136790609495580`
    - `geometry_0.002`: `rbxassetid://104459915267468`
    - `geometry_0.003`: `rbxassetid://106772631853126`
    - `geometry_0.004`: `rbxassetid://74049081563523`
    - `geometry_0.005`: `rbxassetid://124490272484502`
    - `geometry_0.006`: `rbxassetid://82749722578374`
    - `geometry_0.007`: `rbxassetid://75064034244473`
    - `geometry_0.008`: `rbxassetid://71864356917357`
    - `geometry_0.009`: `rbxassetid://74827792440178`
    - `geometry_0.010`: `rbxassetid://82111238221764`
    - `geometry_0.011`: `rbxassetid://115706666540431`
    - `geometry_0.012`: `rbxassetid://88217193889776`
- **Pending checks (requires live Studio Play):**
  - Visual viewport review on Five Islands Hurricane water, forward steering check, and seated character posture check.

## Clean low-poly rebuild (2026-11-16)

The 12-part TRELLIS mesh above looked lumpy and tan in game even after render-fidelity, double-sided
and metalness fixes, so the craft was remodelled by hand in the game's blocky style. This is now the
model `VehicleService.buildWaveRunner` tries first; the 12-part template is its fallback.

- Builder: `tools/blender/build_military_wave_runner.py` (tables of cross-sections; rebuild with
  `blender -b -noaudio --python tools/blender/build_military_wave_runner.py`).
- Export: `exports/MilitaryWaveRunnerClean.glb`, one mesh, 1,696 triangles, 4.43 x 3.49 x 8.95 studs,
  one 64x48 palette texture (`textures/MilitaryWaveRunnerClean_Palette.png`). SHA-256 `99f94d10ea8519f91097a1fd2b272338b64420d37c1f26badd69971b09c41374`.
- Review renders: `review/clean-comparison.png`, `review/clean-{quarter,side,rear,top}.png`.
- Roblox Model asset id: `134548593522969` (Open Cloud, `moderationState: Approved`).
- Registry: both builds are in `src/shared/AssetRegistry.json` (`military-wave-runner` is the clean
  model, `military-wave-runner-scan` the 12-mesh fallback template, over budget with a recorded
  waiver). `VehicleService` reads the clean id from there. Brief height is now 3.5 studs, the clean
  model's real height. Studio checks still open for the clean model: loads, facing, scale, materials,
  collision. Record each with `python tools/asset_generate.py verify military-wave-runner --check <name>`.
- Integration: `CLEAN_WAVE_RUNNER` in `src/server/Services/VehicleService.lua` loads the asset once with
  `InsertService:LoadAsset` and welds it to the invisible hull. Waterline is `KeelBelowHull`, rider
  position is `Seat`.
- **Unverified, needs Studio Play:** that the asset loads, that the bow faces forward, the texture
  shows, the waterline and the rider's seat position. Visual approval covers local renders only.
- Follow-up: the runtime load is a stopgap because the MeshId and TextureID can only be read in Studio.
  Once read, move them into `tools/build_waverunner_art.luau` so no network load is needed in a match.
