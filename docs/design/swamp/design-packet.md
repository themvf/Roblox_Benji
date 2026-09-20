# Swamp — design packet

Status: G1 Design accepted (author = verifier, see §8) · G2 Playability **not started** · Owner: Claude Opus 5 · Updated: 2026-09-20

Concept source: [map-concept-notes.md](map-concept-notes.md) (user hand sketch + photo board).
Implementation: [`src/shared/Maps/Swamp.lua`](../../../src/shared/Maps/Swamp.lua).

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Map, mode, or shared feature? Stable ID and display name? | **Decided.** A map. Module `Swamp`, `Name = "Swamp"`, `Revision = "swamp-basin-v1"`. |
| Which modes must it support? Authoritative spec? | **Decided.** Convergence only. Registered in `Config.ConvergenceMaps`; deliberately **not** in `Config.Maps` (Duel ignores Objectives/Phases/Finale). This packet is authoritative. |
| Player fantasy and repeatable decision? | **Decided.** Fight across a drowned forest. The repeatable decision is priced in **exposure-seconds, not walk-seconds**: cross the open basin fast and wet, or go long and covered behind the boles. The codebase has no water slow, so the tax is sightline exposure. |
| Devices/input types? | **Decided.** Same envelope as every shipped map: phone, tablet, desktop, console. No new UI. |
| Target roster, session length, test preset? | **Decided.** 6v6 design target; ships with the repo's testing values (`TeamSize 1`, `BotsPerTeam 5`). Full match 720 s. Preset: `/map swamp` + `/bots 6`. |
| What is authorized? Out of scope? | **Decided.** User asked to spec, then to implement into the game. Out of scope: new piece kinds, new traversal gadgets (zip/grapple), any Duel support. |
| Which source/build produced the baseline? | **Decided.** Branch `claude/swamp-map-spec-fc7cb9` at `be853e1`. Baseline gate: `check_maps` 5 maps / 0 failed before this work. |
| What problem will the player notice is fixed? | **Not applicable** — new map, not a fix. |

## 2. Game-mode questions

Swamp uses Convergence unchanged; see `ConvergenceService.lua` and `Config.Convergence`. Map-compatibility only:

- **Three objectives, all on `x = 0`.** `FinalePlan.create` rejects any count other than 3 whenever `Finale` exists, and `ConvergenceService` then calls `Finish(match, nil, true)` **before** the intermission broadcast and before `MapService:Load` — every match would dump to the lobby with no map on screen. `Validate` never inspects the count, so that failure ships CI-green.
- **Rotating finale declared:** `Finale = { EligibleIds = { "bridge", "basin", "delta" } }`. All three are plausible last stands.
- **Phase economy (corrected).** `Config.GetConvergence` always rebuilds `PhaseSeconds` as `{180, 180, HardCapSeconds − 360}` = **{180, 180, 360}**. Phase 3 is six minutes, not the three the raw table suggests. Every district is paced for that.
- **Capture math** (`CaptureSeconds 8`, `StackBonus 0.5`, `MaxStack 3`): solo 8.00 s neutral→owned / 16.00 s enemy→owned; duo 5.33 / 10.67; trio+ 4.00 / 8.00.
- **Reinforcement window** after a wipe (respawn 3.5 + travel): bridge 16.90 s, delta 16.23 s, basin 15.10 s.

## 3. Map questions

| Question | Answer |
| --- | --- |
| Districts and callouts | **Trestle Bridge** (elevated, north, z −76) · **The Basin** (wet, centre) · **Cypress Delta** (south, z +76). Landmarks: timber trestle, algae water, cypress landing. Plus four **Masts** (corner towers) and two **Hides** (bunkers). |
| Spawns and spawn-fire prevention | Red `x = −186/−194`, Blue mirrored. 6 per team, min separation **10.0** studs (required 6). 185 studs from the nearest objective; the colonnade and screens break every spawn-to-objective sightline. |
| Routes | Three ground routes within **1.8 s** of each other, plus one launch pad per team as the single asymmetry. |
| Route costs (WalkSpeed 16) | Basin **11.60 s** · Delta **12.73 s** · Bridge **13.40 s** · Delta via pad **9.55 s** · Tower deck **7.49 s**. |
| Can one position control everything? | **No, by geometry.** All six west tower→objective lanes traced and blocked by `TowerScreenNW/SW` at `x = ±126`. Counter to elevation: the towers are entered only from their own team's side, and their pickups force a descent to use. |
| Objective volumes / double membership | Ring separation **40 studs** on both sides. `halfHeight` audited across 12 standing cases, zero mismatches — no reachable position counts toward two. |
| Traversable when a phase closes | All geometry is permanent; closing a zone removes only the scoring volume. |
| Footprint / perimeter / collision / recovery | Walls `±210` (square, `Size` is a number) · Barrier `x ±205, z ±102` = **410 × 204 = 2.01 : 1** · `Bounds ±212/±112` · `RecoveryY −12`. |
| Visually honest? | Ramps meet decks with **0.0000 lip** at every junction. Decor pieces (canopy, masts, mud flats) are `CanQuery = false` so nothing invisible stops a bullet. |
| Bot/character parity | **Required fix applied** — see §6. |
| Reusable vs unique | All 169 solids use existing kinds. Unique: the trestle, the bog, the hides. |

## 4. Player storyboard

Visuals are **concept-only** (the user sketch). No in-engine captures exist yet; this is a storyboard brief, not a completed visual storyboard — G3 requires captures.

| Frame | Player question | Decision / action | Feedback | Shared component |
| --- | --- | --- | --- | --- |
| 1 Arrival | Where am I? | `Vista` sweeps the basin from the north-west at y 70 | Three neon pillars, 46 studs tall | `MapService.Vista` → `HudController` |
| 2 Prepare | What do I take? | Loadout in lobby | — | `LoadoutController` |
| 3 Approach | Which way? | Three ground routes within 1.8 s, or the pad | Neon lane markers | `marker` pieces |
| 4 Encounter | Who is a threat? | Boles, rocks, hides as cover | Team highlight (Occluded) | `Palette` |
| 5 Objective | Am I helping? | Capture bar, stack bonus | Ring at water level (+0.2) | `ConvergenceController` |
| 6 Setback | What happened? | Wipe → 3.5 s respawn → 15–17 s travel | Phase/closing banners | `ConvergenceService` |
| 7 Climax | How do we finish? | Finale revealed at phase 2; 360 s of phase 3 | `IsFinal` on the zone | `FinalePlan` |
| 8 Result | Why did we win? | Recap | Score by phase | `RecapController` |

## 5. Visual and interaction contract

- **Art target:** the five reference photos in the concept notes. Silhouette and material reference **only** — not colour or value.
- **Colour roles:** environment soft (`Ambient`/`OutdoorAmbient`/`Atmosphere.Color`), cover loud (`Rock` + `RockEdge` neon band), indicators neon (`Marker`), team colours reserved to players/spawns/objectives via `Palette.lua`.
- **`Saturation = +0.16`, `Tint` within 5 points of white.** The green comes from ambient light, never from a negative saturation or a green tint — `ColorCorrectionEffect` grades the team highlights and the neon rings too.
- **No `light` and no `beacon` pieces anywhere.** `makePart` never sets `CanQuery = false`, so a light anchor and a beacon ball are both invisible bullet sponges, and neither kind accepts `decor`.
- HUD, input map and states: unchanged, inherited from the shared layer. No new screen.

## 6. Reuse and ownership contract

| Component | Classification | Path | Change | Consumers | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| Map data | **new** | `src/shared/Maps/Swamp.lua` | 169 solids | Convergence rotation | `check_maps` OK, 0 warnings |
| Convergence rotation | **reuse unchanged** | `Config.lua:19` | `+"Swamp"` | map vote, `/map` | all gates green |
| Terrain water colour | **extend shared** | `MapService.buildTerrain` | `Terrain.Water` hook replacing three hard-coded constants | **all 5 existing maps** | Defaults are the previous constants exactly; every map that declares no `Terrain.Water` renders identically. `check_maps` 6/6. |
| Bot line of sight | **shared bug fix** | `BotService.los` | `params.IgnoreWater = true` | every map with water | Terrain water returned `workspace.Terrain`, failing the descendant test, so bots would not trade across the basin while players shoot through freely |
| Bounty marker LOS | **shared bug fix** | `BountyController.hasLos` | `params.IgnoreWater = true` | every map with water | same defect |
| Convergence match start | **shared bug fix** | `ConvergenceService` | removed a call to `MapVoteService:Pick`, which does not exist | **every Convergence match** | It threw inside `task.spawn` after `Busy`/`RoundService.Busy` were set and never cleared, wedging the server on the first pad fill. `QueueService:220` already runs the vote and passes `mapName` in. |
| Forced debug map | **config** | `default.project.json:51` | `"SnowFortress"` → `"Swamp"` | dev sessions only | see §8 caveat |

## 7. Acceptance and evidence

| ID | Requirement | Method | Threshold | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| SWP-01 | Map passes the geometry gate | `lune run tools/check_maps.luau` | 0 errors, 0 warnings | **Verified** | `OK Swamp 169 solids 2 pads 7 pickups 0 warnings` |
| SWP-02 | Existing maps unaffected | same gate | 6 maps, 0 failed | **Verified** | 6/6, SnowFortress's 2 pre-existing warnings unchanged |
| SWP-03 | Place builds | `rojo build` | success | **Verified** | `Built project to arena.rbxl` (530 KB) |
| SWP-04 | Lint/format clean | `stylua src && selene src` | 0/0/0 | **Verified** | clean |
| SWP-05 | Finale rotation legal | `check_finale_plan` | PASS | **Verified** | PASS, 6 closure combinations |
| SWP-06 | Neither team favoured | objective x-offset | all on `x = 0` | **Verified** | zero off-centre warnings (SnowFortress ships 2) |
| SWP-07 | Every list mirrors on X | `check_maps` mirror rules | no unpaired entries | **Verified** | no `Symmetry` override needed |
| SWP-08 | 120 backdrop trees, none in play | count `Trees` children; assert min `|z| ≥ 106` | 120 / 120 | **Not started** | `scatterTrees` gives up silently with no `warn()` — must be asserted, not assumed. Seed 2207 is load-bearing. |
| SWP-09 | Bots contest the basin | `/bots 6`, basin live | bots trade across water | **Not started** | fix landed; effect unmeasured |
| SWP-10 | Contained with safety debug **off** | clear `Debug_CarrierTestSafety`, walk the barrier | no death on legitimate ground | **Not started** | the one thing nobody has tested |
| SWP-11 | Bridge sustains a 360 s finale | 3 full finales | no entry carries >60% of arrivals; bar moves within 60 s | **Not started** | remedy pre-planned: widen stair piers to 14, add a pair at `x = ±40` |
| SWP-12 | Enemy legible on a phone | screenshots at 60/100/140 studs | silhouette resolves at 100 | **Not started** | fallback: Density 0.24 / Haze 0.9 |
| SWP-13 | Lake rim meets authored blocks | Studio walk of the rim and both stair flights | no half-buried pier | **Not started** | voxel boundary will not land exactly on computed half-widths |
| SWP-14 | Solo cannot reliably flip after a wipe | stopwatch vs the zone bar | solo fails or is marginal | **Not started** | margin is under 1 s by arithmetic; remedy is to move pads outboard, **not** to raise `CaptureSeconds` |
| SWP-15 | Launch targets have authored floor | `check_maps` | no "nothing to land on" | **Verified** | `PadLanding` platforms added; main's `Validate.solids` no longer synthesises a terrain slab |
| SWP-16 | Barrier sits against real geometry | `check_maps` | all 4 segments adjacent | **Verified** | timber revetments at `x = ±203`, `z = ±101` |

## 8. Gates and handoff

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 Baseline | **Accepted** | `be853e1`, `check_maps` 5/0 before |
| G1 Design | **Accepted** | Layout from a 3-proposal / 3-judge panel, synthesised and re-verified. **Author and verifier are the same agent** — this is not an independent review. |
| G2 Playability | **Not started** | SWP-08…SWP-14 all require a running session |
| G3 Complete section | Not started | needs in-engine captures |
| G4 Extend | Not started | |
| G5 Release candidate | Not started | |

**Next concrete task:** playtest. `/map swamp`, `/bots 6`, full match; then repeat once with `Debug_CarrierTestSafety` **off**.

**Caveat on the forced map:** `default.project.json:51` now pins `Debug_ForceMap = "Swamp"`, which forces every Convergence match to Swamp and hides the map vote. Restore rotation with `/map off` at runtime, or revert the line. `TuningService` seeds these as attributes on `ReplicatedStorage.Tuning` on first run — **a stale attribute in an existing Studio place wins over this file**, so clear it there if the change appears not to take.

**Deviations from the sketch** (full reasoning in the decision log below):

| Sketch element | Change | Why |
| --- | --- | --- |
| Blue west / Red east | **Kept as drawn.** Blue = `−X`, Red = `+X` | Initially swapped on the grounds that `Mirrored` parts are named `Red_` at the authored coordinates. That prefix turned out to be cosmetic — nothing in `src/` reads it — and the Snow Fortress redesign now asserts `"Blue west, Red east exterior starts"` in `tools/check_fortress_layout.luau:52`. Reverted to the sketch. |
| Four capture points A/B/C/D | Four landmarks, **three** objectives | `FinalePlan` rejects any count ≠ 3 with a `Finale`; the match aborts before the map loads, CI-green. |
| A and B crowded at the north end | A merges into the bridge | Two rings 40 studs apart at one end collapse the north half into one blob fight. |
| B drawn west of centre | Demoted, **doubled** to a mirrored pair of bunker hides at `x = ±77` | B-west against D-east is a 180° rotational pair — the exact bug `Validate.lua`'s header calls out. Doubled rather than deleted, so the intent survives for both teams. |
| D drawn east of centre | Straightened onto `x = 0` | Other half of the same bug. `Validate` only *warns*, so it would have shipped. |
| Full-depth 1/5-width swamp ellipse | One circular lake, r 56 (27% of width), extended visually by mud flats | `buildTerrain` carves at `math.max(rx, rz)` and discards the smaller — an ellipse is not expressible. Forest's `{0,0,22,14,3}` has always built a 22-radius circle; that lie is not copied. |
| Dense conifer bands | 16 large `stump` boles per side + 2 decor canopy slabs; all 120 trees pushed outside the fence | Every tree is 4 shadow-casting parts with no `StreamingEnabled`. Forest is 611 parts, 82% in-play trees. In-play geometry here is ~241. |
| Bridge as a thin band | 116 × 34 deck, **four** entries | Phase 3 actually runs 360 s; a one-entry deck is a six-minute ramp camp. |
| Corner tick marks | 10-stud masts, `decor = true` | Kept as drawn, but a plain block there is a bullet sponge above the highest perch. |
| (nothing in sketch) | Two mirrored launch pads added | The map's only route asymmetry: 3.2 s to the Delta for a fixed, audible, pre-aimable 0.65 s arc. |

**Merge note (2026-09-20).** Merging onto `master` picked up an in-progress change that removes the synthetic `TerrainGround` slab from `Validate.solids`. That made five Swamp checks fail — two launch landings and three barrier segments — because they had been leaning on a modelled slab rather than authored geometry. The removal is a genuine tightening (an infinite slab made barrier adjacency trivially true for every map), so Swamp was adapted rather than the change reverted: two `PadLanding` platforms and four timber revetments were added, giving the play boundary a visible edge as well as a valid one. 169 solids → 174.

**Known limitation, stated plainly:** `Validate` models the lake carve, mountains, groves and every scattered tree as *nothing*, and models terrain as one flat box whose top is `y = 0` across the whole basin. Every "dry ground" and "arc clear" result rests on half-width arithmetic and the written launch-corridor invariant in the map file — **not** on the gate. SWP-13 is the check that matters.

**Decision log**

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-09-20 | Three objectives, not four | `FinalePlan` hard-rejects; failure is invisible to CI |
| 2026-09-20 | All objectives on `x = 0` | SnowFortress took the off-centre shortcut and still carries the balance debt |
| 2026-09-20 | `Hills = {}` | Trees plant at `y = 0` with no terrain awareness; any hill in the scatter box buries trees, and no gate reports it |
| 2026-09-20 | No jetpack pickup | 3.5 s × Thrust 42 = a 147-stud climb against walls spanning `y 0..48` |
| 2026-09-20 | `Bounds` wider than the walls | With `SafetyAlwaysOn`, a `Bounds` box clipping real ground kills real players |
| 2026-09-20 | Fixed `MapVoteService:Pick` rather than working around it | It wedged every Convergence match, so no Swamp playtest was possible |
| 2026-09-20 | Extended `MapService` for water colour | The three constants were applied before layout data was read; defaults preserve every existing map |
