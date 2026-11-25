# Five Islands (`FiveIslandsTDM`) — Visual Spec Guide

Status: Active Reference · Target Style: Stylized Golden-Hour Tactical Arena (Rivals-inspired)

## 1. Visual Targets

- **Hero Mood:** [five_islands_hero_view_v3_1794714519064.jpg](file:///C:/Users/joshb/.gemini/antigravity/brain/b17b1190-98c0-4316-b026-f7a3168d264d/five_islands_hero_view_v3_1794714519064.jpg)
- **Layout Target:** [five_islands_birds_eye_v4_clean_1794714528349.jpg](file:///C:/Users/joshb/.gemini/antigravity/brain/b17b1190-98c0-4316-b026-f7a3168d264d/five_islands_birds_eye_v4_clean_1794714528349.jpg)

### Design Pillars
1. **Instant Silhouette Readability at 250–350 Studs:** From either Spawn Island, the Center Vault's tall gold/cyan vertical light beams, the two Sniper Watchtowers on flanking cliffs, and the clean turquoise channel must read in under one second.
2. **Clean Open Water (`Y = 0`):** Smooth turquoise-to-deep-blue `Terrain` water (`Transparency = 0.35`, `Reflectance = 0.45`, gentle `0.15` wave size) with **zero coral reefs and zero submerged rocks**.
3. **Color-Coded Roles:**
   - **Environment (Soft/Natural):** Warm beach sand (`Sand`), saturated tropical grass (`Grass`, `LeafDark`, `LeafLight`), slate cliffs (`Cliff`).
   - **Structures (Neutral):** Concrete pads/compound (`Concrete`, `Wall`), weathered dock & watchtower timber (`Wood`).
   - **Gameplay / Vehicles (High-Contrast):** Tactical matte-black RHIBs (`BoatHull`), bright cyan/yellow wave runners (`WaveRunner`), dark tactical helicopters, yellow helipad `H` markings (`Marker`), orange cover trim (`CoverAccent`), and gold/cyan objective beams (`VaultGold`, `VaultCyan`).

---

## 2. Atmosphere & Lighting Spec

| Setting | Target Value | Visual Purpose |
| --- | --- | --- |
| `ClockTime` | `17.2` | Warm golden-hour rim light & long island shadows |
| `Brightness` | `2.6` | Crisp specular highlights on water and metal |
| `Atmosphere` | `Density = 0.16`, `Haze = 0.5`, `Glare = 0.2` | Sun-washed horizon depth without obscuring sniper sightlines |
| `FogStart / FogEnd` | `550 / 1900` | Keeps all 5 islands sharp while softening far horizon |
| `Bloom / Saturation` | `0.45 / 0.25` | Makes Center Vault energy beams pop cleanly |

---

## 3. Island-by-Island Art Breakdown

### A. Spawn Islands (`X = ±330, Z = 0`)
- **Shoreline & Cove:** Wide golden sand beach (`Y = 3`) stepping up to green turf (`Y = 4`), framed on outer corners by curved palm trees and coastal bushes.
- **Tactical Compound:** Shielded `6`-pad spawn courtyard (`Y = 4.25`) with perimeter cover walls (`Y = 14`) that block direct Sniper Overlook lines while leaving open lanes toward the helipad and dock.
- **Helipad (`X = ±352, Z = -28`):** Concrete pad (`28 × 28`) with full neon-yellow `H` emblem and perimeter corner stripes, holding **1 tactical helicopter** facing center.
- **Timber Dock (`X = ±280, Z = 0`):** Weathered plank pier on submerged wooden pilings extending into the channel (`Y = 2`), flanked symmetrically by:
  - **2 Black Army RHIBs:** Rigid dark-grey/black hull, side sponsons, center steering console, tactical roll bar, and twin outboard motors.
  - **2 Wave Runners:** Compact streamlined hulls with sculpted seat, handlebars, and high-visibility cyan/yellow trim.

### B. Center Power-Weapon Island — *The Vault* (`0, 0`)
- **Outer Rim:** Clean sandy beaches (`Y = 3`) rising via wide cardinal stairs into a grassy perimeter (`Y = 4`) dotted with olive/wood supply crates and chest-high tactical cover.
- **Vault Bunker (`64 × 64`):** Angled slate/concrete ruin walls (`Y = 12.5`) with 4 wide (`16`-stud) entrances on N/S/E/W and 4 interior pillars for tight SMG/shotgun fights.
- **Power-Weapon Beacons:** Three central metal plinths (`Y = 5.0`) projecting **36-stud translucent neon energy pillars** (Center: `VaultGold`; North/South: `VaultCyan`) plus pulsing beacons so players across the sea always see active power-weapon locations.

### C. Sniper Overlooks (`0, ±230`)
- **Stepped Cliff Mass:** Three readable elevation tiers—sandy beach (`Y = 3`), lower grass/stone shelf (`Y = 14`), and upper sniper ridge (`Y = 24`)—broken up with stepped rock buttresses along the edges so the cliffs look sculpted rather than single blocks.
- **Flank Access:** Dual X-mirrored `25°–26°` timber ramps on West and East flanks (never facing straight out the front), keeping rear/side flanks open to wave-runner rushers.
- **Watchtower (`Y = 32..42`):** Braced 4-post wooden tower with safety half-railings, sloped/stepped overhang roof, and orange-trimmed sniper cover (`CoverAccent`) along the ridge edge.
- **Zero Vehicles:** No docks, boats, wave runners, or helipads; includes 1 glowing `LaunchPad` per ridge (`Z = ±223`) back to Center Beach.

---

## 4. Development Phases (Iterative Roadmap)

1. **Phase 1 — Architectural & Prop Visual Pass (Current Focus):**
   - Upgrade [FiveIslandsTDM.lua](file:///c:/Docs/_AI%20Python%20Projects/Roblox_Benji/src/shared/Maps/FiveIslandsTDM.lua) with multi-part RHIB & Wave Runner models, full helipad `H` markings, dock pilings, stepped Vault stairs, supply crates, tall translucent energy beam pillars, cliff buttresses, and braced watchtower roofs/railings.
2. **Phase 2 — Drivable Vehicles & Water Combat:**
   - Implement server-authoritative `VehicleService` + client `VehicleController` bound to `VehicleSpawns` (Wave Runner 1-seat, RHIB 4-seat with passenger weapon fire, Helicopter 4-seat transport-only, vehicle HP/respawn, and `25s` abandoned cleanup).
3. **Phase 3 — Custom Center Weapons & Studio Art Pass (Optional `.rbxm`):**
   - Swap placeholder `Pickups` (`Minigun`, `EnergyRifle`, `WhiteSniper`) for custom power weapons, and optionally convert to a Studio-editable `.rbxm` for smooth `Terrain` beaches/cliffs.
