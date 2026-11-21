# Fast Map Look-Dev & Industrial Kit Playbook

Practical workflow for going from blank blockout to a rich, lived-in arena in minutes instead of rewriting bespoke scripts each time.

## 1. Reuse the Repo Kit Instead of Hand-Coding Parts
Import `tools/mapkit/IndustrialKit.luau` (`local Kit = require("./mapkit/IndustrialKit")`) in Lune map builders to stamp tested primitives directly:
- **Sightline & Main-Lane Landmarks:** `Kit.buildChamferedPortal`, `Kit.buildBlastShield`, `Kit.buildIBeam`, `Kit.buildXBrace`, `Kit.makeRamp`, `Kit.makeRampMirrored`, `Kit.addRampSupportMirrored`
- **Conduits & Overhead Clutter:** `Kit.makePipeSegment` (auto pipe clamps), `Kit.makeDrapedCable` (catenary slack cables)
- **Floor & Surface Grit:** `Kit.makePatchPlate` (welded steel patches), `Kit.makeOilSlick`, `Kit.makeHazardStrip` (procedural `SurfaceGui` hazard chevrons—zero upload needed)
- **Living Motion & Atmosphere:** `Kit.buildSteamVent`, `Kit.buildEmberPlume`, plus `SpinFan`, `FlickerLight`, and `CraneGlide` tags handled by `src/client/Controllers/MapMotionController.lua`
- **Asset Grounding & Safety:** `Kit.placeOnPlinth`, `Kit.placeAssetClone` (pass `decor = false` on solid props), and `Kit.assertFloorClearance` (verifies zero props poke below `Y = 0`)

Example canonical map builder: `tools/build_scifi_foundry.luau`.

## 2. Indoor Floor & Smooth Terrain Rule
If a map uses a flat architectural floor (`Y = 0`), **never** leave a default solid `Terrain` slab at `Y = 0` (`GroundMaterial = Concrete`/`Snow`). Roblox smooth voxel terrain bulges ~1.5–2.1 studs above `Y = 0`, swallowing floor tiles, trims, and furniture legs.
- In `<Map>.presentation.lua`, set:
  ```lua
  Terrain = {
      GroundMaterial = Enum.Material.Water,
      Sea = true,
      SeaLevel = -40,
  }
  ```
  and ensure `Bounds`, `RecoveryY`, and `>= 5 SafePoints` exist inside `Authoring`.

## 3. Anti-Sterile Lighting & Color Calibration
- Avoid flat unshadowed floodlighting (`Ambient > 140`), **and** avoid overly crushed indoor shadows (`Ambient < 85` in roofed maps leaves walled spawn bays and corner alcoves pitch black). For enclosed indoor arenas, aim for `Ambient ~ 95–115`, `OutdoorAmbient ~ 105–125`, directional skylight pools (`Brightness ~ 1.1–1.25`), and `Shadows = true` on hero core and portal fixtures.
- **Behind bulkheads & walls:** Any wall/screen partition blocks nearby ceiling point lights—always place dedicated skylights inside Spawn Bays and above corner console/rack alcoves so light-colored props never appear floating in a black void.
- **Neon color pitfall:** High green values turn orange into banana yellow under `Bloom`. Use low-green saturated RGBs for `Neon` trim (`TrimOrange = (255, 68, 8)`, `TrimCyan = (0, 196, 255)`).

## 4. Custom Tileable PBR `MaterialVariant`s
Generate or regenerate seamless `1024x1024` PBR texture sets (`Color`, `Normal`, `Roughness`, `Metalness`) with:
```bash
python tools/generate_pbr_materials.py
lune run tools/build_material_variants.luau
```
This outputs PNG maps and `MaterialVariants.rbxm` into `assets/environment/materials/industrial-foundry-v1/`.

### One-Time Studio Attachment (To Swap Stock Materials for Custom PBR)
1. In Roblox Studio **Explorer**, right-click **MaterialService** → **Insert from File…** → pick `assets/environment/materials/industrial-foundry-v1/MaterialVariants.rbxm` and ungroup the `IndustrialFoundryMaterials` folder so the 4 `MaterialVariant` children live directly under `MaterialService`.
2. In **Asset Manager**, bulk-import the PNGs from `assets/environment/materials/industrial-foundry-v1/*/`.
3. Paste each texture's uploaded `rbxassetid://` into its matching `MaterialVariant` (`ColorMap`, `NormalMap`, `RoughnessMap`, `MetalnessMap`):
   - `Ind_ConcreteFloor` (`BaseMaterial = Concrete`)
   - `Ind_GunmetalWall` (`BaseMaterial = Metal`)
   - `Ind_DiamondTread` (`BaseMaterial = DiamondPlate`)
   - `Ind_ForgeSootMetal` (`BaseMaterial = Basalt`)
4. Parts built with `IndustrialKit` already carry those `MaterialVariant` names, so they fall back cleanly before upload and switch to full PBR automatically once Studio has the variants in `MaterialService`.

## 5. Fast Iteration Loop
```bash
lune run tools/build_scifi_foundry.luau
lune run tools/map.luau convert SciFiFoundry
lune run tools/check_decor.luau
lune run tools/audit_map_visuals.luau SciFiFoundry
lune run tools/check_maps.luau
```
Before opening Studio (or handing off for playtesting), render a multi-angle visual contact sheet (top-down + eye-level sightlines with a `5.5`-stud player height reference) of both `source/<Map>.rbxm` and `decor/<Map>.rbxmx`, inspect the images directly, and resolve every finding before **Stop → Test → `/explore SciFiFoundry`** in Studio.

## 6. Pre-Play Visual & Collision Audit Checklist
Run `lune run tools/audit_map_visuals.luau <MapName>` (which inspects **both** `assets/environment/source/<MapName>.rbxm` and `assets/environment/decor/<MapName>.rbxmx`) and review these eight items before calling a map ready for playtesting:

1. **Ramp Flushness, Underside Support & Bidirectional Egress**
   - Compute ramp CFrames from deck top and floor endpoints (`Kit.makeRamp` / `Kit.makeRampMirrored`) instead of guessing `posY` + angle by hand, so top edges meet decks flush (`±0.05` studs) with no curb/lip poke-up.
   - Frame ramps with steel side stringers and underside vertical stanchions (`Kit.addRampSupportMirrored`) and give elevated decks corner columns + perimeter girders so platforms never read as floating planks.
   - Every walkable elevated deck must have **at least 2 distinct ramp approaches (`[DECK-EGRESS]`)** with unobstructed landings—never trap players on a one-way balcony or place blocking rails across a landing.
2. **Clear Centerline & Primary-Lane Traversal**
   - Keep spawn-to-mid (`Z = 0`) and main centerline (`X = 0`) lanes clear of dead-center pillars (`[CENTER-PILLAR]`), un-rampable curb steps (`> 0.45` studs, `[LANE-BLOCK]`), or mid-corridor decks that force awkward zig-zags.
3. **Human-Scale Prop Sizing (`5.5`-Stud Player Rule)**
   - Measure **both** `.rbxm` geometry props and `.rbxmx` GLB placements against a `5.5`-stud R15/R6 player capsule (`[SCALE]`):
     - Floor containers/crates/cargo: keep footprint and height `<= 4.6` studs (waist/chest/head cover, never room-sized blocks).
     - Consoles/control panels: `<= 5.5` studs tall.
     - Cryo chambers/generators/tubes: keep heights `<= 8.5` studs and footprints `<= 7.5` studs unless explicitly sculpted as a centerpiece landmark.
   - Reject off-theme office/datacenter filler (`ServerRack`, `StandingDesk`, white furniture — `[THEME]`).
4. **Physical Collision & `.rbxmx` Overlap / Grounding**
   - Pass `decor = false` on walkable/solid hero props (`placeOnPlinth` cabinets, cargo crates, cryo tubes, containment canisters), portal jambs & 45° chamfers, base plinths, collars, and floor-to-deck structural I-beams.
   - Only pure particles, light nodes, neon strips, and thin surface patches should remain `CanCollide = false`.
   - Verify `.rbxmx` placements never sink below `Y = 0` (`[DECOR-GROUND]`) and never intersect wall ribs, lanes, shield walls, or adjacent props (`[DECOR-OVERLAP]`).
5. **Symmetry, Grounding & No Stacked Monoliths**
   - Never hide an imported asset inside or atop a plain rectangular block (`Cover`/`Wall` stub)—replace the stub with the grounded asset + diamond-tread plinth directly (`minY = 0.32` above `Y = 0`).
   - Keep flanking wing props and structural silhouettes cleanly mirrored across `X = 0` and/or `Z` teams.
6. **Lighting Coverage (Zero Black Corners)**
   - Verify the `24`-stud floor sample grid has **0 dim zones (`score < 0.35`)** using lights from both `.rbxm` and `.rbxmx`, especially inside walled Spawn Bays (`SpawnSkylightPanel_*`) and behind bulkheads (`CornerAlcoveLight_*`).
7. **Overhead, Crane & Conduit Clearances**
   - Verify ceiling columns/shafts reach all the way into `CeilingDeck` with collars (never stopping mid-air).
   - Check static and animated `CraneGlide` sweep bands (`Y` and `Z`) against overhead `SpinePipe` runs, trusses, portals, and tall canisters so moving props never pass through static geometry, and hang crane tracks from ceiling girders.
8. **Material Diversity, Steel Contrast & Signage Finish**
   - Avoid replacing all `Metal` and `DiamondPlate` surfaces with dark custom PBR variants (`[MATERIAL]` warns if `< 15%` of steel parts keep native `Metal` / `DiamondPlate`); keep stairs, treads, catwalks, I-beams, and industrial trim in crisp brushed steel / diamond plate alongside custom `Ind_ConcreteFloor` and `Ind_GunmetalWall` panels.
   - Avoid raw `SmoothPlastic` slabs on architectural trim or sign housings, use bold condensed/mono fonts (`RobotoMono` Bold) with `UIPadding` and `UIStroke` borders, and complete a **mandatory visual render/screenshot inspection** across top-down, spawn-to-mid, and hero-prop zones before declaring the pass complete.
