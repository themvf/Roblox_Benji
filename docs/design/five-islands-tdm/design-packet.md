# Five Islands (`FiveIslandsTDM`) — design packet

Status: Phase 2 Drivable Vehicles Implemented (unverified in Studio) · Owner: Agent + User · Updated: 2026-11-15

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Is this a map, mode, or shared feature? What is its stable internal ID and display name? | **Decided:** Map (`FiveIslandsTDM`, display name `"Five Islands"`), defined in [FiveIslandsTDM.lua](../../../src/shared/Maps/FiveIslandsTDM.lua). |
| Which modes/maps must it support? Where is the authoritative spec? | **Decided:** Team Deathmatch (`Mode = "TDM"`), reusing the TDM ruleset in [Config.lua](../../../src/shared/Config.lua) and [team-deathmatch](../team-deathmatch/design-packet.md). |
| What player fantasy and repeatable decision make it worthwhile? | **Decided:** Island-hopping amphibious/vertical TDM: rush the Center Vault on wave runners, push as an armed RHIB squad, heli-drop onto the Sniper Overlooks, or fight for rotating power-weapon pedestals. |
| Who is it for, and which devices/input types must work? | **Decided:** Desktop, controller, and touch players via existing shared movement, weapon, and launch-pad input pipelines. |
| What is the target roster, expected session length, and human/bot test preset? | **Decided:** `4v4`–`6v6` TDM (`6` spawn pads per team), 6–8 min rounds, `/bots 6` QA gate. |
| What is already authorized? What is explicitly out of scope? | **Decided:** 5-island layout, spawn-only drivable vehicles (`1` transport heli, `2` armed RHIBs, `2` wave runners per spawn), clean swimmable water with no coral/rocks, and placeholder center weapon pickups. Out of scope: custom weapon authoring (deferred to user). |
| Which exact source/build/tuning produced the baseline? | **Decided:** Built directly on `Validate.lua` + `MapService.lua` `Sea = true` Terrain water and X-mirror placement. |
| What problem will the player notice is fixed? | **Decided:** Islands are spaced wide enough (`~194` studs Spawn→Center, `~130` studs Sniper→Center) that waiting for a helicopter, RHIB, or wave runner beats a `~12–14s` open-water swim, while Sniper cliffs block spawn-dock angles. |

## 2. Game-mode questions

- **Mode Compatibility:** Uses existing `Mode = "TDM"` rules (score-to-win `50`, regulation `600s`, respawn `3s`, spawn protect `1s` in [Config.lua](../../../src/shared/Config.lua)).
- **Swimmable Water Deviation:** Unlike [Carrier.lua](../../../src/shared/Maps/Carrier.lua) where water height is lethal, `FiveIslandsTDM` enables native `Terrain` water at `SeaLevel = 0` with `RecoveryY = -18` below the seafloor (`Y = -10`) so players swim safely between islands.
- **Map Data Contract:** Declares `Spawns`, `Pickups`, `LaunchPads`, `SniperOutposts`, `SafePoints`, `Bounds`, `RecoveryY`, and `VehicleSpawns` metadata.

## 3. Map questions

- **Districts & Landmarks:**
  1. **Red Base (`-330, 0`) & Blue Base (`+330, 0`):** Walled coastal spawn compounds (`Y = 4`, `Y = 14` walls), `1` helipad, `1` wooden dock facing center, and tropical palm/bush perimeter greenery.
  2. **The Vault (`0, 0`):** Center island (`116 × 116` studs beach) with green turf rim, open-corner ruin walls (`16`-stud cardinal doorways), CQC cover pillars, palm trees/shrubs, and `3` beacon-lit power-weapon pedestals (`Minigun`, `EnergyRifle`, `WhiteSniper` placeholders).
  3. **North Overlook (`0, -230`) & South Overlook (`0, +230`):** Multi-tier grassy sniper cliffs (`Y = 3 → 14 → 24 → 32` watchtower) framed by palm trees and shrubs, with dual X-mirrored `25°–26°` flank ramps (`RampAngleMax = 32` compliant) and `1` one-way `LaunchPad` back onto Center Beach.
- **Anti-Spawn-Camping & Sightlines:** Spawn compounds wrap `Y = 14` walls around the spawn pads and dock approach so elevated snipers at `Z = ±230` overlook the Center Island (`~220–245` studs) and water lanes without direct spawn-pad sightlines.
- **Playable Perimeter & Clean Water:** `Size = 860`, `Bounds` `X: [-420, 420]`, `Z: [-320, 320]`, `Y: [-18, 240]`; open water contains zero coral or submerged rocks, with `~194`-stud Spawn dock-to-Center and `~130`-stud Sniper-to-Center channels favoring vehicles over swimming.

## 4. Player storyboard

| Frame | Visual | Player question | Decision / action | Feedback & next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Arrival | Concept: [Hero View](file:///C:/Users/joshb/.gemini/antigravity/brain/b17b1190-98c0-4316-b026-f7a3168d264d/five_islands_hero_view_v3_1794714519064.jpg) | Where am I and what matters? | See glowing Center Vault beacons and spawn dock/helipad | Choose transport lane immediately | `MapService` (`Vista`, `beacon`) |
| 2 Prepare | Concept: [Bird's-Eye](file:///C:/Users/joshb/.gemini/antigravity/brain/b17b1190-98c0-4316-b026-f7a3168d264d/five_islands_birds_eye_v4_clean_1794714528349.jpg) | Which ride fits my plan? | Pick Wave Runner (flank), RHIB (armed squad), or Heli (cliff drop) | Board at spawn dock or helipad | `VehicleSpawns` *(new system)* |
| 3 Approach | Concept | How fast do I reach combat? | Cross `~95`-stud channel (`~1.5–2.1s`) | Enter beach or climb sniper cliff | Terrain `Sea` + `Movement` |
| 4 Encounter | Concept | Who has the angle? | Fight CQC inside Vault walls or peek sniper cover | Eliminations advance TDM score | `Weapons` + `TDM` |
| 5 Objective | Concept | Why push middle? | Contest `45–60s` placeholder power-weapon beacons | Equip heavy pickup for map control | `Pickups` |
| 6 Setback / recovery | Concept | My ride sank or I'm on a cliff | Swim `~3–5.5s` or hit Sniper `LaunchPad` to Center Beach | Rejoin action without stranded downtime | `LaunchPads` + `Terrain` water |
| 7 Climax | Concept | How do we close the gap? | Coordinate RHIB push + heli drop on Vault pickups | High-tempo mid-map brawl | `TDM` + `Pickups` |
| 8 Result / replay | Concept | Why did we win/lose? | Review TDM scoreboard & rematch | Standard TDM reset | `TDM` |

## 5. Visual and interaction contract

- **Art Target:** Golden-hour tropical tactical arena (`ClockTime = 17.2`), bright turquoise water, warm sand, neutral concrete/slate structures, and orange/gold/cyan cover & beacon accents.
- **Readability:** Team colors reserved for spawn pads and players; `beacon` pillars mark the 3 Center Vault power-weapon pedestals across the map.

## 6. Reuse and ownership contract

| Component | Status | Existing owner / path | Notes |
| --- | --- | --- | --- |
| Map layout & X-mirror geometry | **Reuse unchanged** | [MapService.lua](../../../src/server/Services/MapService.lua) & [Validate.lua](../../../src/shared/Maps/Validate.lua) | `Center` + `Mirrored` tables (`136` solids) |
| TDM scoring, rotation & respawns | **Extend shared** | [Config.lua](../../../src/shared/Config.lua) (`TDMMaps`, `Mode = "TDM"`) | Added `"FiveIslandsTDM"` to `Config.TDMMaps` |
| Launch pads & placeholder pickups | **Reuse unchanged** | `LaunchPads` + `Pickups` in [Weapons/init.lua](../../../src/shared/Weapons/init.lua) | `Minigun`, `EnergyRifle`, `WhiteSniper` placeholders + `2` `speed` pads |
| Drivable Heli, RHIB (armed passengers), Wave Runner | **Implemented (unverified in Studio)** | [VehicleService.lua](../../../src/server/Services/VehicleService.lua), [VehicleController.lua](../../../src/client/Controllers/VehicleController.lua), [MapService.lua](../../../src/server/Services/MapService.lua), [WeaponService.lua](../../../src/server/Services/WeaponService.lua) | Builds from `VehicleSpawns`; enforces seat team gating, `VehicleNoFire` (`RHIB` passengers armed, drivers & heli transport unarmed), HP destruction + respawn, and `25s` abandoned cleanup |
| Non-lethal swimmable water | **Extend shared** | `MapService` (`Terrain.Sea`) + `RecoveryY = -18` | Already supported by `MapService.buildTerrain` |

## 7. Acceptance and evidence

| ID | Requirement | Method | Threshold | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| `FI-01` | Geometry, ramps, launch arcs, pickups, X-mirror symmetry | `lune run tools/check_maps.luau` | `0` errors, `0` warnings | Verified | `OK FiveIslandsTDM 136 solids 2 pads 5 pickups 0 warnings` (`16 maps checked, 0 failed`) |
| `FI-02` | Movement single-writer & controller gate | `lune run tools/check_movement.luau` | `0` failures | Verified | `32 passed, 0 failed` |
| `FI-03` | Style & lint compliance | `stylua --check ... && selene src` | `0` errors, `0` warnings | Verified | `stylua --check` exit `0`; `selene src`: `0 errors, 0 warnings, 0 parse errors` |
| `FI-04` | Studio build | `rojo build -o "$env:TEMP\arena_fiveislands.rbxl"` | `0` errors | Verified | `Built project to arena_fiveislands.rbxl` |
| `FI-05` | Studio playtest: vehicles, RHIB passenger fire, heli flight, swim & launch-pad flow | `/explore FiveIslandsTDM` + `/map FiveIslandsTDM` + `/bots 6` | Clean driving/flight, `0` `OUT_OF_BOUNDS`, `9/10` launch success | Not started | Requires Studio Stop/Restart Play + interactive playtest |

## 8. Gates and handoff

| Gate | Status | Notes |
| --- | --- | --- |
| G0 Baseline | Accepted | Concept views & medium-scale TDM decisions locked |
| G1 Design | Accepted | Packet & [visual-spec.md](visual-spec.md) authored |
| G2 Playability | Code complete, Studio playtest pending | Static gates (`check_maps`, `check_movement`, `stylua`, `selene`, `rojo build`) all pass after Phase 2 edits |
| G3–G5 | Not started | Pending in-Studio vehicle & TDM playtest captures |

**Next concrete task:** Stop and restart Play in Roblox Studio so Rojo syncs [VehicleService.lua](../../../src/server/Services/VehicleService.lua), [VehicleController.lua](../../../src/client/Controllers/VehicleController.lua), [MapService.lua](../../../src/server/Services/MapService.lua), [WeaponService.lua](../../../src/server/Services/WeaponService.lua), and [FiveIslandsTDM.lua](../../../src/shared/Maps/FiveIslandsTDM.lua), then test via `/explore FiveIslandsTDM` (all vehicles usable) and `/map FiveIslandsTDM` + `/bots 6` (team-gated home vehicles, RHIB passenger shooting, heli flight).
