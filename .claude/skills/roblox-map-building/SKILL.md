---
name: roblox-map-building
description: Build or edit a data-driven map layout for this project (Convergence/Duel arenas): layout schema, geometry audit checklist, required safety data, readability rules, and the QA gate. Use whenever adding a map, changing map geometry, ramps, elevators, pickups, launch pads, or events.
---

# Roblox map building (this project)

Maps are Lua data tables in `src/shared/Maps/<Name>.lua`, built by `MapService` at match start. Services are
generic; the map supplies data. Read `Carrier.lua` as the reference layout and `Forest.lua` for a terrain map.

## Layout schema (what a map may declare)
- `Name, Size, WallHeight, Seed`
- `Spawns = { Red = {...}, Blue = {...} }` (6 per team; keep them off ramps and elevator openings)
- `Objectives = { {Name, pos, radius, Phases} }` on the centre line or mirrored fairly
- `Vista = {pos, look, seconds}` hero camera on entry
- `Environment`, `Palette` (colour jobs: environment soft, cover loud, team colours reserved)
- `Terrain` (`Sea=true` for water maps, `Hills`, `Mountains`, `Lake`)
- `Center` (placed once) and `Mirrored` (placed at x and -x; rot y/z flip) pieces:
  kinds `block` (color = palette key), `rock`, `log`, `stump`, `grove`, `marker`, `light`, `beacon`,
  `elevator`, `jet`, `helicopter`, `steam`, `radar`
- `Events = { {Name, TriggerPhase, WarningSeconds, DurationSeconds, Banner, Sound, Region, Shield, Beacons, Flyover} }`
  or `{Kind="Kraken", Origin, Height}`
- `Pickups` (weapon/speed/jetpack), `LaunchPads` (pos, target, vy, size), `SniperOutposts`, `Flyovers`, `Fleet`
- Safety data (required for any map with edges or multiple floors): `RecoveryY`, `Bounds`, `InvalidRegions`,
  `SafeRegions`, `SafePoints`, `Barrier`

## Geometry audit (do this by reading coordinates before testing)
For every ramp/stair: compute both end heights from `pos`, `size.x` and `rot.z`. Positive z-rotation lowers the
-x end; negative lowers the +x end. Check the high end meets a floor and the low end meets a floor, and that no
slab covers the ramp (a deck over a ramp = trapped pocket). Cut an opening with 4 slabs around it and add rails.
For every wall: check it does not cross a ramp or doorway; split walls into two pieces plus a lintel.
For every cutout (elevator, hatch): list the uncovered strips between it and neighbouring slabs and fill them.
For every void (between inner walls and hull, under deck ends): fill it solid or declare it in `InvalidRegions`.
Spawns: on flat floor, 3+ studs from any edge or opening, facing the map centre.
Mirrored pieces: remember z-rotation flips sign; a stair that is right on the bow is right on the stern.

## Safety data every multi-level map must declare
- `RecoveryY` below the lowest legitimate floor.
- `Bounds` box around all playable space (launch arcs included).
- `InvalidRegions` for voids; `SafeRegions` for legitimate pockets inside them (ramps, stairs).
- `SafePoints` (5, spread out, on open floor) for recovery teleports.
- `Barrier` segments along every exposed edge: height 12, thickness 1.5, positioned 1.5 studs outside the edge.
  Bullets pass (CanQuery=false); players do not.
The `Debug_CarrierTestSafety` Tuning switch turns these on for testing.

## Movement systems
- Launch pads: server trigger volume (pad size + 1, height 5), velocity applied on the client, `vy` 55-70,
  landing on open floor, 1 s re-trigger guard. Never teleport.
- Elevators: anchored tween does not carry riders; treat as a known limitation or use a physics platform.
- Ramps steeper than ~30 degrees stall characters. Use rot 25-32 with length >= 2.2 x rise.

## Readability rules
- One dominant colour per role: floor neutral, cover loud with an accent band, indicators neon, team colours only
  on players, spawn pads and objectives.
- Every objective has a ring, a pillar visible across the map, and a name sign.
- Ten big recognisable props beat hundreds of small ones.

## QA gate before balance testing
Force the map (`/map <name>`), run `/bots 6`, play a full match. Pass only if: no `RECOVERY:` lines, no repeated
`PATHING_FAILURE` at the same coordinates, launch pads succeed 9/10, every edge walked without a fall, ramps and
stairs climbable both ways, elevators reachable, tester finishes the match without a restart.
