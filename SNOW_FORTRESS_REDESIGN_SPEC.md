# Snow Fortress — Convergence redesign specification

Version 1.1 · 2026-09-20 · Status: implementation underway; see [implementation status](docs/reviews/snow-fortress/implementation-status.md) for verified work and remaining gates.

The user has locked opposite exterior starts, district combat identities, server-selected eligible finales without consecutive repeats, a phase-2 reveal, and bounded traversal. See [Traversal and Combat](FORTRESS_TRAVERSAL_AND_COMBAT_SPEC.md) for the authoritative FIN-01–05 selection/reveal contract. These decisions supersede the original fixed Command Keep finale.

## 1. Purpose and authority

**Snow Fortress is a map within Convergence.** This is user-confirmed product identity. It is not a proposal for a new game mode, a replacement for Convergence, or grounds for renaming the map to Carrier.

The user requires a substantial improvement in visual quality, identifiable weapon selection, meaningful separation between capture points, and a playable exterior beyond the fortress so players can storm different areas. This document converts the assessment into requirements, a candidate design, implementation sequence, and measurable acceptance gates.

Creating this specification authorizes documentation only. A future instruction to implement it authorizes the implementation work described here. This spec does not authorize publishing, production-data changes, or deletion of unrelated work.

Terminology:

- **MUST:** acceptance requirement for this redesign.
- **SHOULD:** default direction; departures require a recorded rationale and evidence.
- **Candidate:** a starting design or numeric hypothesis to validate before locking geometry. It is not an existing map measurement.
- **Verified:** supported by the cited source or supplied image, not automatically proven in the live game.

Read [ROBLOX_BEST_PRACTICES.md](ROBLOX_BEST_PRACTICES.md) and [CLAUDE.md](CLAUDE.md). Use the map-building skill referenced by CLAUDE.md for geometry work. For Snow Fortress, this spec's user-required exterior routes take precedence over copying a carrier-style barrier along every building edge.

## 2. Evidence and baseline corrections

Implementation update: the Snow Fortress source has since been located at `ae1219b` in the local `claude/snow-fortress-design-17939a` worktree and integrated into the implementation workspace. The historical findings below describe the pre-integration baseline; use the status ledger for current behavior. Live Studio build identity still needs verification.

The three supplied screenshots are preserved unchanged:

| Evidence | Observed issue |
| --- | --- |
| [01 — capture and weapons](docs/reviews/snow-fortress/evidence/01-capture-and-weapons.png) | Tiny weapon imagery; large capture effect; avatar and meter compete for foreground space |
| [02 — exterior approach](docs/reviews/snow-fortress/evidence/02-exterior-approach.png) | Undifferentiated structure and ramps; weak equipment identification; unclear exterior route purpose |
| [03 — fortress boundary](docs/reviews/snow-fortress/evidence/03-fortress-boundary.png) | Fortress/exterior relationship, large self-occluding accessories, weapon label losing contrast against snow |

Source inspection at preparation time found HEAD `7c83270` plus local edits. The images' exact place version, source revision, effective tuning, and viewport/device remain unrecorded. Their visual failures are evidence; they do not establish exact world distances or collision behavior.

The checked-in `Snow.lua` inherits Forest. That is a **source-to-running-build mapping gap**, not a dispute about the user-confirmed Snow Fortress identity. Locate the actual fortress geometry/scripts in the running place or relevant branch and bring the authoritative representation into the normal project workflow. Do not overwrite it with Forest or start rebuilding the wrong map.

Known baseline discrepancies that MUST be resolved in the implementation baseline:

- Handoff commit `ae1219b` exists but is not an ancestor of the inspected HEAD. Do not assume its contested-income, phase-clock, mutation-outline, or phase-tuning work is present.
- Inspected `ConvergenceService` still pays income when `zone.Owner` is set without checking contesting. The client clock reads `PhaseTimeLeft`; final-phase decrement can continue below zero.
- `default.project.json` explicitly seeds `Convergence_BotsPerTeam = 0`. Local `Config.lua = 5` does not establish five bots in a built/synced game.
- `MutationService` uses the alter ego color for both Highlight fill and outline in this checkout. The handoff's team-outline behavior must be verified or restored.
- The recent TouchController changes cover ability/fly/score buttons, not the weapon selector shown in the screenshots.

**BASE-01:** before changing gameplay, record commit, local diff, Rojo project, place/version, runtime map ID/display name, active tuning, roster, viewport, and graphics settings. Record the actual objective coordinates and collision/recovery boundaries. Save a baseline capture from the reproduced build.

## 3. Scope and protected behavior

In scope: Snow Fortress topology and exterior routes; objective placement and capture-volume safety; visual identity and modular environment assets; weapon selector and loadout readability; combat HUD composition; camera/accessory readability; bot route use; build provenance and regression evidence.

Preserve Convergence's two-team objective competition, server authority, existing weapon behavior, compatible inventory/loadout data, mutation abilities, and persistent player data. Shared UI improvements may benefit other maps, but their behavior must be regression-tested.

Keep the 3 → 2 → 1 objective structure during the first topology test. Keep `MaxStack = 3`, damage, movement, respawn, and scoring values stable except for the explicitly specified correctness fixes. Do not confound a map evaluation with a simultaneous balance overhaul.

Out of scope: attackers-versus-defenders mode, destructible siege simulation, new weapons, new currency, weekly boards, leaderboard expansion, global save migrations, or a rewrite of the working Weapons Kit. Those require separate work.

## 4. Required player experience

Within five seconds of seeing a combat view, the player should be able to identify their equipped weapon, available alternatives, the relevant objective state, and at least one useful route. They should distinguish a building entrance from scenery and understand where exterior movement is allowed.

The intended loop is: leave a protected spawn area → choose an approach → fight through a recognizable district → capture or deny income → decide whether to defend or rotate → converge on the final district through multiple viable approaches.

The fortress MUST be a destination inside the playable battlefield. Exterior space MUST provide combat choices and connections, rather than a decorative margin or an unprotected running lap.

## 5. Battlefield topology and dimensions

### MAP-01 — Three distinct districts

Use a triangular route relationship between three recognizable districts. Avoid vertically stacking objectives or placing all three in one mutually visible courtyard.

Locked district identities; phase survival is assigned per match rather than fixed to a district:

| Objective | Identity | Combat identity | Active phases |
| --- | --- | --- | --- |
| A | Gate Courtyard | More open, mid-range fighting with a main breach and side access | 1; may survive to 2/3 |
| B | Service Yard | Dense cover and flanking routes at a separate fortress entrance | 1; may survive to 2/3 |
| C | Command Keep | Vertical, close-quarters fighting with multiple access routes | 1; may survive to 2/3 |

All three begin neutral and active. One non-final district closes in phase 2, when the server reveals the selected final district. In phase 3 only that district remains active. Two or three districts must qualify as possible finales; target all three if each passes fairness tests. Selection uses map-defined eligibility and excludes the previous finale for that map on the same server. Do not reopen a closed point. Team ownership must never depend on a district's decorative color.

Candidate blockout envelope, in studs: playable area approximately 480 × 440; fortress approximately 200 × 180; opposing spawn regions near X = −205 and +205; A near (0, 0, −135), B near (0, 0, +135), C near (0, 0, 0). These values illustrate room for exterior play and balanced east/west access. They are **not coordinates to paste without measuring routes**. Keep objective floors initially at a common datum; add vertical opportunities after the basic route network passes.

Conceptual connectivity, not a scale drawing:

```text
                NORTH GATE / A
             /        |        \
       west cover     |      east cover
          /           |           \
   RED SPAWN --- COMMAND KEEP / C --- BLUE SPAWN
          \           |           /
       west service   |      east service
             \        |        /
                SERVICE YARD / B

Outer boundary encloses the spawn approaches, both exterior networks,
and all districts. The fortress footprint encloses only the central structure.
```

### MAP-02 — Routes with different costs

Each team MUST have an obvious direct route, a covered side approach, and a longer route reaching another entry angle. At least two independent entrances must serve each active district. Alternate routes must not all merge at a single choke before reaching the district.

Main approach: easiest to understand, relatively short, with exposure broken by combat cover. Side approach: different sightline and timing, with recognizable cover transitions. Service approach: longer and more sheltered, with close-range vulnerability. Optional elevation may improve observation but must expose the occupant or have a reachable counter-route.

Spawns MUST have at least two exits, cover against long-range fire, and no direct firing line into the opposing spawn. Team path times to neutral districts should be comparable; initial candidate tolerance is 10% for equivalent routes. Visual asymmetry is allowed after route fairness is checked.

### MAP-03 — Measure distance in player time

Measure from defined endpoints using the actual default loadout/movement speed, no temporary boosts, no fighting, and the intended traversable path. Record at least five runs per team/direction. Report alternate boosted/flight traversal separately.

| Measurement | Candidate starting target |
| --- | --- |
| Spawn to first plausible encounter area | 8–15 seconds |
| Spawn to nearest objective edge | 10–18 seconds |
| A ↔ C and B ↔ C, objective edge to edge | 8–14 seconds |
| A ↔ B cross-map rotation | 16–28 seconds, with meaningful intermediate choices |
| Flank versus its corresponding direct approach | 20–40% longer |

Targets may change from playtest evidence. No change may be justified solely by visual distance. The final district MUST remain attackable from multiple directions after A/B stop scoring; closing a point must not accidentally sever the route network.

### MAP-04 — Boundary, collision, and recovery

Author separate fortress footprint, walkable exterior, collision perimeter, and recovery volume. The visible outer boundary MUST sit beyond the complete exterior route network and communicate why travel ends: terrain, fencing, cliffs, or perimeter structures appropriate to the art direction.

Do not surround the fortress itself with invisible walls that block intended assaults. Do not globally disable recovery to make an exterior route accessible. Move or split the relevant bounds/barriers/invalid regions and provide valid floor, cover, navigation, and safe points together.

All ramps must meet their landing surfaces, allow travel both directions, and fit the largest supported combat form. Test corners, door lintels, railings, catwalks, and camera clearance. Use the map-building geometry audit; derive dimensions from the actual character envelope. Test flight/launch arcs against the outer recovery volume separately.

Safety behavior essential to the map MUST be independent from debug visualization. Generic map services should consume map data; do not add `if mapName == "Snow"` branches for topology.

## 6. Objective rules and combat state

**OBJ-01:** live owned objectives award income only while not contested. Test one isolated scoring objective to avoid other income masking the result. Enemy entry stops that objective's income by the next scoring evaluation; leaving resumes it according to the existing scoring cadence. Preserve legitimate kill/other-point scoring.

**OBJ-02:** capture membership MUST use the same resolving definition for humans and bots. Support explicit vertical extent/floor separation where needed. Do not rely on a generic ±12-stud height allowance for closely stacked floors. Every reachable location, including jump/flight paths, must count toward at most one objective. Preserve compatible defaults on other maps when extending the schema.

**OBJ-03:** show remaining match time in the primary clock, phase changes through a brief banner, and local objective state through concise text. No negative visible or authoritative final-phase remaining time. Overtime must be explicit.

For the initial baseline, preserve the 720-second hard cap and 180-second first/second phases: the final phase uses the remaining 360 seconds absent early finish/overtime. Expose phase tuning consistently, but document that the hard cap governs the final phase; do not expose a supposedly independent third-phase duration that silently has no effect. Validate impossible duration combinations. Reconcile the old handoff's third-phase attribute with this rule before implementation.

**OBJ-04:** retain A/B/C plus district names for navigation. Show CAPTURING, DEFENDING, CONTESTED, or CLOSED as appropriate, using text and shape/icon cues alongside team colors. A local player must understand why progress has stopped. Ownership, occupancy, capture progress, and score eligibility must remain separate state concepts.

**OBJ-05:** tune presentation without hiding enemies or movement cues. Keep distant markers compact; emphasize local interaction. Reduce persistent ring/beam saturation and duplicate bars where they dominate the battlefield. Tie progress and states to server data, not client guesses.

## 7. Art direction and asset production

**ART-01 — Candidate direction:** a stylized arctic military fortress with deliberate architectural proportions and strong landmark silhouettes. This is a proposed visual treatment for the confirmed Snow Fortress map. A coherent stylized result is the target; photorealism is not required.

| Visual role | Required treatment |
| --- | --- |
| Snow/exterior ground | Controlled large forms and subtle surface variation; retain contrast for characters and HUD |
| Fortress structure | Repeated wall thickness, supports, doors, ramps, and believable construction vocabulary |
| Cover | Recognizable function and height; readable silhouette from normal combat distance |
| District landmarks | Distinct gatehouse, service structure, and command silhouette; navigation must survive grayscale review |
| Lighting | Entrances and floor changes legible in shadow; no bloom washing out opponents or indicators |
| Interaction effects | Consistent vocabulary; team colors reserved for ownership/identity information |

**ART-02:** before full-map art production, create a reference board, material/color sheet, a small modular kit, and target compositions for spawn vista, exterior approach, interior objective, and a normal combat camera. Record asset source/license where applicable. Approved concepts are targets, not proof that the running map meets them.

The initial kit should include wall sections/corners, gates, door frames, ramps/stairs, railings, cover families, and the three landmark types. Review seams, collision proxies, scale, and repeated material frequency in-engine. Favor authored reusable forms over accumulating disconnected blocks or noisy detail.

**ART-03:** finish one exterior approach, entrance, and objective district to target quality before extending across the map. Compare before/after captures from the same camera and device settings. Assess opponents, equipment, and objective effects in the scene; empty-map screenshots cannot pass combat readability.

## 8. Weapon identification and loadout UI

### UI-01 — Own the combat weapon selector

Identify the actual built-in Backpack/kit/custom selector ownership before implementation. Introduce one authoritative presentation for carried weapons while retaining the established equip and weapon behavior. Disable a redundant selector only after input parity and fallback states work.

Every carried weapon MUST have a persistent short name and a deliberately framed recognizable silhouette or thumbnail. Names are mandatory fallbacks if imagery is missing. Do not merely enlarge an image whose weapon occupies a few pixels of empty canvas. Frame from weapon geometry/approved thumbnail bounds and test each carried asset, including skins and utility items.

Stable slot order: primary, secondary, melee, utility when present. Avoid duplicate slots during equip transitions between Backpack and Character. Distinguish selected/equipped, unavailable, and empty states; selected state must use a border/shape and text, not color alone. Preserve keyboard shortcuts and controller/touch access.

Show equipped weapon name and ammunition/reload state on a contrasting panel. Derive ammo and equip state from the existing weapon system; do not create a second inventory authority or optimistically show an equip the game rejected. Validate switching during reload, death, respawn, pickup expiry, and loadout replacement. Cosmetics must not modify gameplay stats.

Candidate touch baseline: slot hit regions at least 64 × 64 logical pixels, short names initially around 16 pixels, clear spacing. Adapt to safe width rather than scaling text into illegibility. Viewport pixels alone are not physical usability proof.

### UI-02 — Make pre-match choice readable

Replace six narrow simultaneous category columns on small screens with category tabs and readable weapon cards. Keep a large preview for the selected weapon and show a small consistent set of player-facing comparisons such as damage, fire cadence, magazine, and role, sourced from weapon definitions.

Weapon name, selected state, confirm, and close actions MUST remain visible and readable. Detailed stats and cosmetic variants can be disclosed after selection. Touch must not depend on hover; gamepad focus must reach and leave every category. Preserve existing saved loadouts and confirmation semantics.

## 9. Unified HUD, camera, and accessibility

**HUD-01:** define one layout contract covering CoreGui, the weapon kit, and custom controllers. Inventory/weapon state, mutation readiness, ability buttons, objective status, and score must share safe areas and priorities. Reserve the aiming area and route view; avoid stacking unrelated meters over the character.

**HUD-02:** use responsive layouts that update on viewport/orientation and active-input changes. Touch must work when a keyboard/controller is also connected. Debug_ForceTouchUi is a preview aid, not evidence of mobile support.

**HUD-03:** retain clear labels MUTATE, SLAM, BRACE, CHARGE, FLY, SCORES. Keep HOLD visible for hold actions, seconds on cooldowns, and a useful readiness/unavailability state. Release held input when canceled, focus is lost, the control hides, the character dies, or the relevant tool is unequipped.

**HUD-04:** keep text on backing panels across snow and dark interiors. Reinforce team/objective/availability colors with non-color cues. Keep essential information available without animation; respect available reduced-motion/text preferences. Localized long labels must fit through layout/wrapping rather than uncontrolled shrinking. Retain explicit access to chat/social panels; compose combat UI to avoid collisions with them.

**CAM-01:** identify the large accessory assets and actual camera in the baseline captures. Do not assume the screenshots show a mutation effect. Define a near-camera policy that locally fades self-occluding accessories or otherwise restores the aim/route view. Preserve player identity and equipment; do not delete persisted cosmetics or change opponents' hitboxes as a presentation fix.

**CAM-02:** test standard, large, and highly ornamented avatars plus mutation forms in aim/turn/jump/capture states. Team identity MUST remain visible during mutation; reconcile Highlight ownership so two effects do not fight. An alter-ego fill with a team-colored outline is the initial direction, with an additional non-color identity cue where needed.

## 10. Bots and test configuration

**TEST-01:** establish one effective test preset at the configuration boundary. For two-human testing: queue one human per team and add five bots per team; confirm 12 active combatants at runtime. Bots spawn after the human queue fills. Update or reconcile Rojo attributes, Config defaults, and persisted Studio overrides together. A Config edit alone is not acceptance.

When more humans participate, choose bot counts to reach the intended roster without silently exceeding six per side. Production human matchmaking remains 6 target / 4 minimum / 0 bots unless separately changed. Record these presets and isolate test progression/data according to the existing progression handoff.

**BOT-01:** bots must traverse exterior approaches, doors, ramps, and alternate routes. A lateral offset near an objective is not proof of flanking. Objective selection must not treat a nearby point on another floor as directly reachable. Review short-range pathfinding bypasses around walls/elevation.

Run at least three complete bot-assisted matches after the route network is built. Record route use, stuck locations, recovery events, encounter times, and capture reversals. Follow with human playtests before claiming balance. Preserve current telemetry and add only measurements needed for the acceptance matrix.

## 11. Implementation sequence and gates

Future implementation should progress in this order. Each gate has concrete artifacts; avoid stopping for approval of routine implementation details. Obtain design approval at the concept/slice gates if that approval has not already been given for the presented result.

| Stage | Work | Required exit evidence |
| --- | --- | --- |
| 0 — Reproduce | Map running Snow Fortress to source; reconcile baseline and effective tuning | BASE-01 manifest, baseline captures, present/absent/fixed checklist for handoff defects |
| 1 — Design | Top-down plan, route/time matrix, boundary plan, art board, desktop/mobile HUD mockups | Reviewable concepts addressing all user concerns; candidate dimensions clearly labeled |
| 2 — Blockout | Exterior geography, separate districts, entrances, safe traversal and spawn protection | Measured routes, objective exclusivity, boundary walk, bot navigation evidence |
| 3 — Complete slice | One finished approach/entrance/objective with weapon UI and combat camera | In-engine combat captures on desktop and phone; capture/retake and switching tests |
| 4 — Extend | Apply approved kit and UI patterns across Snow Fortress | Full-map quality review and Convergence phase tests |
| 5 — Verify | Device, input, performance, regression, and human playtests | Completed acceptance matrix, remaining limitations, reproducible release candidate |

If Stage 0 cannot locate the running fortress source, finish the independent design artifacts and report the exact missing place/source export. Do not recreate or replace unrelated map data to hide that gap.

## 12. Acceptance matrix

All numeric values below are project acceptance targets or initial hypotheses, not measured results or platform requirements. Record individual runs; do not average away a phone failure with desktop success.

| ID | Verification | Pass condition / evidence |
| --- | --- | --- |
| BASE-01 | Reproduce exact test | Manifest includes revision/diff, map/roster/tuning, place, device, graphics; screenshots trace to source |
| MAP-01/02 | Route walkthrough from both spawns | Three recognizable district identities; two usable entries per district; no all-entrance dominant firing position |
| MAP-03 | Five runs per team/direction, without boosts | Route/time matrix meets candidate ranges or documents playtest-supported revisions; comparable team access |
| MAP-04 | Walk all exterior edges, ramps and entries; test flight separately | Zero invisible obstructions on valid routes, invalid recoveries, traps, or inaccessible advertised entries |
| OBJ-01 | Isolated owned-point contest/leave | Point income stops while contested and resumes correctly; unrelated scoring remains correct |
| OBJ-02 | Position sampling plus live grounded/jump/flight tests | No reachable simultaneous membership in different objectives; human/bot membership agrees |
| OBJ-03/04 | Phase transitions, early win, hard cap, overtime | Honest clock, exactly one transition/result, explicit local state, final district reachable |
| ART-01/03 | Matched camera captures with active combat | Consistent architecture/materials; cover/entrances/opponents readable in snow, shadow, low/high graphics |
| UI-01 | Repeated weapon switches and lifecycle cases | Correct named weapon equips; no duplicate/stale slots; imagery or clear name fallback; ammo matches kit |
| UI-02/HUD-01 | Loadout, combat, scores and recap on small display | Readable labels and reachable confirm/close; no clipped essential content or conflicting controls |
| HUD-02/03 | Resize/rotate, keyboard/controller on touch, multi-touch | No layout loss; move/aim/fire/switch/ability works; no stuck hold states |
| CAM-01/02 | Avatar/form matrix in combat | Aim region, nearby route and test opponent remain identifiable; team identity survives mutation |
| BOT-01 | Three complete intended-roster matches | Both teams use intended major approaches; no permanently stuck bots or repeat failure at the same blocker |
| UX-01 | Exploratory test with 8–10 unfamiliar players | At least 80% name current point/state within five seconds and find an alternate entrance within 30 seconds without coaching; 90% correct first weapon selection; report raw counts |
| TEST-01 | Inspect effective runtime preset and roster | Two-human preset produces one human plus five bots per side; alternative human counts do not silently exceed intended team size |
| PERF-01 | At least 10 minutes of intended-roster combat per reference device | Record frame-time distribution, memory trend and effects density; target p95 frame time ≤33.3 ms on agreed baseline phone and ≤16.7 ms on agreed desktop; no crash or continuing memory growth |
| REG-01 | Forest/Carrier/Duel and second match | Shared HUD/equip/membership changes preserve supported behaviors; no stale map effects/input or duplicate rewards |

Choose and record named physical reference devices during Stage 0; until then performance and physical touch acceptance remain pending. Include a small landscape phone, larger phone, tablet, desktop, and gamepad input. Suggested simulator viewport checks: 667×375, 812×375, 1024×768, and 1920×1080, plus portrait/menu recovery where rotation is supported. Simulators do not replace physical-device evidence.

Run the current repository formatting/lint/content/build gates in ROBLOX_BEST_PRACTICES.md. Add focused regression tests for changed membership, scoring, timer and inventory state transitions. Add map-data audits where they can catch repeatable geometry errors. Do not write screenshot-blind tests and describe them as visual approval.

## 13. Likely implementation ownership

| Area | Starting files / systems | Notes |
| --- | --- | --- |
| Map identity | Running place, `src/shared/Maps/Snow.lua`, Config rotation | Resolve actual Snow Fortress source before editing; preserve compatibility with map voting and Duel |
| Geometry/world | Authoritative map module, MapService, SafetyService | Data-driven routes, bounds, capture heights, prefab assembly; no map-specific service branches |
| State correctness | ConvergenceService, ConvergenceController, MutationService | Reconcile handoff fixes individually against baseline; avoid blind cherry-pick over divergent work |
| Tuning | Config, TuningService, default.project.json | Document ownership/precedence and inspect effective attributes |
| Equipment UI | WeaponService, actual kit/Backpack UI, LoadoutController | One presentation owner; preserve weapon authority and equip lifecycle |
| HUD/camera | TouchController, MutationController, kit camera, relevant custom HUDs | Shared layout/input contract and accessory policy |
| Navigation | BotService and map navigation data | Validate real route choice and elevation handling |
| QA/docs | This spec, best-practices guide, captured evidence | Update requirement status with links, not only prose claims |

Shared controllers must not hardcode Snow Fortress-only behavior. Keep map-specific callouts/appearance/data in the map definition or a compatible presentation configuration. Preserve the distinction between the Snow Fortress display name and existing internal IDs; document any migration instead of silently renaming them.

## 14. Delivery record for the next agent

Create `docs/reviews/snow-fortress/implementation-status.md` when implementation begins. Use one row per requirement ID: Not started / In progress / Implemented, unverified / Verified / Blocked; include the file/commit, test result, evidence path, and remaining issue. None are verified merely because this spec exists.

Store durable before/after images and relevant logs alongside the preserved baseline evidence. Keep sensitive account data out of manifests. Source files and authored assets must be tracked; large generated place files should use the project's artifact workflow.

Final handoff must contain: authoritative map/source mapping; before/after views; route measurements; effective test/production preset; responsive UI evidence; avatar/device matrix; meaningful regression results; remaining limitations; and exact instructions to reproduce the accepted build. Do not claim balance, persistence, or mobile quality without corresponding evidence.

Known local work at preparation time includes bot Config changes, touch-label/background changes, README/CLAUDE edits, the best-practices guide, and the progression handoff. Preserve it and inspect the current diff before starting. Do not assume an unchanged HEAD means an unchanged working tree.

## 15. Copyable implementation prompt

> Implement SNOW_FORTRESS_REDESIGN_SPEC.md for Snow Fortress, which is a map within Convergence. First identify the screenshot-producing map source and reproduce its effective build/tuning; the old ae1219b handoff was not included in the inspected branch, and Rojo seeded zero bots despite a Config change. Preserve existing local work and player data. Deliver the battlefield plan, exterior route/boundary design, art direction, and phone/desktop HUD concepts, then build one complete playable slice before extending across the map. Address every requirement ID, especially weapon identification, meaningful objective spacing, exterior assault routes, camera readability, and contested-scoring/timer correctness. Follow the ordered gates and record evidence in docs/reviews/snow-fortress/implementation-status.md. Treat candidate dimensions and timings as hypotheses requiring measurement. Keep Convergence's mode identity and existing balance stable outside specified fixes. Do not publish, wipe data, or claim device/playtest verification that was not performed. If the fortress source is unavailable, advance independent design work and state precisely what source mapping is missing.
