# Choke Ridge (`ChokeRidge` / `ChokeRidgeTDM`) — design packet

Status: G2 Playability (Static gates passing; Studio playtest pending) · Owner: Agent + User · Updated: 2026-11-16

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Is this a map, mode, or shared feature? What is its stable internal ID and display name? | **Decided:** Map (`ChokeRidge`, display name `"Choke Ridge"`) in [ChokeRidge.lua](../../../src/shared/Maps/ChokeRidge.lua), plus TDM variant (`ChokeRidgeTDM`, `"Choke Ridge (TDM)"`) in [ChokeRidgeTDM.lua](../../../src/shared/Maps/ChokeRidgeTDM.lua). |
| Which modes/maps must it support? Where is the authoritative spec? | **Decided:** Duel (`Config.Maps`), Convergence (`Config.ConvergenceMaps` with 3 center-line objectives), and TDM (`Config.TDMMaps`, `Mode = "TDM"`). |
| What player fantasy and repeatable decision make it worthwhile? | **Decided:** Almost-fully-natural Middle Eastern sandstone canyon T-spur centered on **forced choke points and surprise action**: push **through the cave** (blind CQC corners), wrap **around the narrow southern nose** over a sheer lethal chasm, hold split **natural sniper shelves**, or use **Jetpack** pickups/kits to fly **over** the unwalkable ridge crest. |
| Who is it for, and which devices/input types must work? | **Decided:** Desktop, controller, and touch players via existing shared movement, weapon, and jetpack pipelines. |
| What is the target roster, expected session length, and human/bot test preset? | **Decided:** `1v1` Duel through `5v5` Convergence/TDM (`6` spawn pads per team), `/bots 6` QA gate. |
| What is already authorized? What is explicitly out of scope? | **Decided:** Almost-fully-natural sandstone geology (no ruins, towers, crates, or sci-fi elements), no wind-suits, lethal cliff drops (`RecoveryY = -30`), unwalkable ridge crest above the cave (fly-over only), and five anti-sniper cover geometries. |
| Which exact source/build/tuning produced the baseline? | **Decided:** Built natively via `MapService` `Center` + `Mirrored` tables (`Validate.lua` X-mirror geometry) with `SeaLevel = -120` below `RecoveryY = -30` so falling off outer cliffs is lethal. |
| What problem will the player notice is fixed? | **Decided:** Five natural rock geometries prevent snipers from locking down spawn exits, cave mouths, and the southern nose simultaneously while preserving crisp high-risk sniper lanes. |

## 2. Game-mode questions

- **Mode Compatibility:**
  - `ChokeRidge` supports Duel (`Config.Maps`) and Convergence (`Config.ConvergenceMaps`) with 3 ground-reachable center-line objectives (`North Cavern`, `South Cavern`, `The Nose`).
  - `ChokeRidgeTDM` (`Mode = "TDM"`) strips `Objectives` and `Finale` for pure Team Deathmatch (`Config.TDMMaps`).
- **Lethal Precipice:** Similar to [Carrier.lua](../../../src/shared/Maps/Carrier.lua), leaving the cliff rims drops below `RecoveryY = -30` and kills the player (no walkable floor slab at `Y = 0` outside the mesas/ridge).

## 3. Map questions

- **Districts & Landmarks:**
  1. **Red Spawn Mesa (`-145, 8, -10`) & Blue Spawn Mesa (`+145, 8, -10`):** High sandstone mesas shielded by tall `SpawnShieldFinMain` / `SpawnShieldFinSouth` rock fins and marked only by small team cloth pennants on rock cairns.
  2. **Sunken Anti-Sniper Gulch (`X: ±26..±100, Y = 0, Z: -28..+14`):** Reached via a `22°` sandstone ramp (`GulchRamp`), shielded along its southern canyon edge by a `7`-stud-high natural rock parapet (`GulchAntiSniperWall`) so CQC players reach the cave out of sniper view.
  3. **Central Protruding Ridge Spur & Cave (`X: -26..+26, Z: -74..+48`):** Joined solidly into the sheer `NorthCliffWall` (`Z = -90, top Y = 110`) so no ground path exists north behind the ridge. The cave (`Y = 0..16, Z: -20..+10`) cuts East–West beneath an unwalkable `Y = 16..68` sandstone spine (`CaveRoofSpine` + `RidgeCrestFin`), guarded outside each lip by leaning boulders (`CaveMouthGuardBoulder` at `X = ±30, Z = -5`).
  4. **The Southern Nose (`Z: +26..+48, Y = 0`):** Narrow cliff-edge wrap-around ledge above the lethal chasm with `3` head-high boulder cover beats (`NoseCornerBoulder` at `±19, 0, 34` and `NoseTipBoulder` at `0, 0, 41`).
  5. **Split Sniper Shelves:** `UpperSniperShelf` (`±74, 16, -54`) and forward `OuterPromontory` (`±62, 12, 22`) separated by `SniperSightlineHorn` (`±52, 0, -34`) so no single perch sees spawn, cave exit, and the nose simultaneously.

## 4. Player storyboard

| Frame | Visual | Player question | Decision / action | Feedback & next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Arrival | Concept: [Bird's-Eye v3](file:///C:/Users/joshb/.gemini/antigravity/brain/5263ecda-a70d-44e2-9774-b379f4c32065/choke_ridge_v3_birds_eye_1794834408570.jpg) | Where do teams meet? | See shielded spawn fins, sunken gulch, and protruding central spur | Pick safe gulch (CQC) or upper sniper ramp | `MapService` (`Vista`, `Spawns`) |
| 2 Approach | Concept: [Sniper Overlook](file:///C:/Users/joshb/.gemini/antigravity/brain/5263ecda-a70d-44e2-9774-b379f4c32065/choke_ridge_hero_sniper_overlook_1794832959439.jpg) | How do I avoid snipers? | Drop down `GulchRamp` behind `GulchAntiSniperWall` or peek from `UpperSniperShelf` | Safe approach to `CaveMouthGuardBoulder` | `Movement` + `MapService` |
| 3 Encounter | Concept: [Spur & Cave Hero](file:///C:/Users/joshb/.gemini/antigravity/brain/5263ecda-a70d-44e2-9774-b379f4c32065/choke_ridge_v2_hero_spur_1794833354407.jpg) | Cave ambush, nose flank, or fly-over? | Fight inside cave boulders, dash rock-to-rock around nose, or grab `Jetpack` | Surprise CQC, knockback hazard, or aerial flank | `Weapons` + `Pickups` + `JetpackController` |
| 4 Setback / recovery | Concept | What if knocked off the nose? | Fall past `RecoveryY = -30` into canyon mist | Respawn safely behind shielded spawn rock fin | `SafetyService` + `Spawns` |

## 5. Visual and interaction contract

- **Art Target:** Golden-hour Wadi Rum sandstone canyon (`ClockTime = 16.8`, warm layered `SandFloor` / `Sandstone` / `SandstoneDark` rock, sparse olive `Scrub`, zero `RockEdge` neon bands, zero ruins/buildings/sci-fi).
- **Readability:** Cave interiors receive subtle warm daylight bounce (`AmberGlow` `PointLight`); team sides use minimal cloth pennants (`TeamPennant`).

## 6. Reuse and ownership contract

| Component | Status | Existing owner / path | Notes |
| --- | --- | --- | --- |
| Map geometry & X-mirror symmetry | **Reuse unchanged** | [MapService.lua](../../../src/server/Services/MapService.lua) & [Validate.lua](../../../src/shared/Maps/Validate.lua) | `Center` + `Mirrored` tables + `SeaLevel = -120` |
| Mode rotations (Duel / Convergence / TDM) | **Extend config** | [Config.lua](../../../src/shared/Config.lua) | Added `ChokeRidge` (`Maps`, `ConvergenceMaps`) & `ChokeRidgeTDM` (`TDMMaps`) |
| Jetpack fly-over & weapon pickups | **Reuse unchanged** | [PickupService.lua](../../../src/server/Services/PickupService.lua) & [JetpackController.lua](../../../src/client/Controllers/JetpackController.lua) | `ChokeRidge`: `Jetpack` (`±84, 1.2, -16`), `Shotgun` (`0, 1.2, 4`), `WhiteSniper` (`±62, 13, 22`). `ChokeRidgeTDM` pulls all power pickups mid: `Minigun` on Nose (`0, 1.2, 32`), `Shotgun` (`0, 1.2, 4`) & `WhiteSniper` (`0, 1.2, -14`) in Cave, `Jetpack` at cave/nose crossroads (`±32, 1.2, 10`), `speed` in forward gulch (`±54, 1.2, 6`). |

## 7. Acceptance and evidence

| ID | Requirement | Method | Threshold | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| `CR-01` | Geometry, ramps, mirror symmetry, pickups, bounds | `lune run tools/check_maps.luau` | `0` errors, `0` warnings for `ChokeRidge` & `ChokeRidgeTDM` | Verified | `OK ChokeRidge 58 solids 0 pads 7 pickups 0 warnings` and `OK ChokeRidgeTDM 58 solids 0 pads 7 pickups 0 warnings` (`19 maps checked, 0 failed`) |
| `CR-02` | Style, lint, Studio build | `stylua --check src && selene src && rojo build` | `0` errors, `0` warnings | Verified | `stylua --check src` exit `0`; `selene src` `0 errors, 0 warnings, 0 parse errors`; `rojo build` built `arena_chokeridge.rbxl` (`check_movement` `32 passed, 0 failed`; `check_decor` `2 checked, 0 failed`) |
| `CR-03` | Studio playtest: spawn shielding, sunken gulch, cave CQC, nose cover, jetpack ridge-clear | `/explore ChokeRidge` + `/map ChokeRidge` + `/bots 6` | `0` `OUT_OF_BOUNDS`, smooth ramps, spawn lines blocked | Not started | Requires Studio Playtest |

## 8. Gates and handoff

| Gate | Status | Notes |
| --- | --- | --- |
| G0 Baseline | Accepted | Natural T-spur + anti-sniper cover rules locked with user |
| G1 Design | Accepted | Updated bird's-eye v3 + hero concept views approved |
| G2 Playability | Static gates verified; Studio playtest pending | `ChokeRidge` and `ChokeRidgeTDM` pass `check_maps`, `stylua`, `selene`, `check_movement`, `check_decor`, and `rojo build`. Next: `/explore ChokeRidge` and `/map ChokeRidge` + `/bots 6` in Studio. |
