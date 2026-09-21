# Roblox game mode and UI playbook

Use this guide when adding a mode, ability, map integration, or player interface. It records reusable project conventions and acceptance criteria so each feature starts from the same foundation.

Use [GAME_BUILD_WORKFLOW.md](GAME_BUILD_WORKFLOW.md) and its design packet template to apply these practices consistently. That workflow owns planning/storyboards/gates; this guide owns technical patterns, and individual specs own feature requirements.

Reviewed: 2026-09-21. **Implemented reference** means the pattern exists in this repository; it does not mean every device or gameplay case has been verified. **Recommended standard** means new work should meet it; existing code may still need improvements. Numeric UI targets below are project starting points, not Roblox platform requirements.

Implementation update: the separate Snow Fortress worktree was located and its source integrated into `codex/snow-fortress-redesign`. The corrected income/clock/outline behavior and consistent bot preset are now in working source; runtime verification remains pending. Historical checkout warnings below refer to the original `7c83270` baseline. Consult the [implementation ledger](docs/reviews/snow-fortress/implementation-status.md) for current status.

For the user-confirmed Snow Fortress map within Convergence, use [SNOW_FORTRESS_REDESIGN_SPEC.md](SNOW_FORTRESS_REDESIGN_SPEC.md). Its baseline audit corrects earlier assumptions about handoff commit inclusion and effective tuning. The running fortress-to-source mapping is still required; the checked-in Snow/Forest inheritance is not a description of the pictured fortress.

## 1. Start with a small feature contract

Before implementation, describe what players do, how they know it worked, and how the feature ends. Record deliberate design choices separately from defects.

| Decision | Write down |
| --- | --- |
| Player loop | Enter, understand objective, act, receive feedback, finish, replay |
| Match rules | Human team requirements, bot policy, scoring, ties, overtime, aborts |
| States | Lobby, starting, active, overtime, results, cleanup; feature-specific states |
| Input | Named action, keyboard/gamepad binding, touch button, tap or hold |
| Feedback | Ready, unavailable reason, cooldown, success, failure |
| Tuning | Default, valid range, override name, when changes take effect |
| Acceptance | Observable scenarios, device coverage, evidence required |

Do not turn an unverified report into a fix. Reproduce it or trace the actual execution path first. Example: Snow inherits Forest's objectives through a deep copy; absence of an explicit `Objectives` declaration was not proof of missing objectives.

## 2. Keep gameplay rules on the server

**Implemented references:** [ConvergenceService](src/server/Services/ConvergenceService.lua), [MutationService](src/server/Services/MutationService.lua), [MutationController](src/client/Controllers/MutationController.lua).

The client requests an action; the server decides whether it is legal and applies scoring, damage, energy, cooldowns, and match results. Controllers render state and handle local input/effects. Shared modules contain definitions, not trusted client decisions.

**Recommended standard:** validate every client request for argument type and bounds, player participation, alive/state eligibility, target validity, distance where relevant, cooldown, and request rate. Client-side disabled buttons are feedback, not enforcement. Reject malformed numeric values, including non-finite numbers. See Roblox's [client-server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary).

For client-owned character movement, follow this project's server-approved movement request pattern; the client applies movement locally. Do not infer that client-reported position, hits, or completion can be trusted. Preserve server validation around the action.

## 3. Build modes from data and explicit state

**Implemented references:** [Config](src/shared/Config.lua), [ConvergenceService](src/server/Services/ConvergenceService.lua), [QueueService](src/server/Services/QueueService.lua), and [maps](src/shared/Maps).

- Maps supply objectives, events, pickups, and spawn data. Mode services interpret that data without branching on map names.
- Keep match state isolated: participants, teams, score, phase, timers, and owned resources. Define what happens when players leave or a match cannot start.
- Separate zone ownership, occupancy, contesting, capture progress, and scoring eligibility. A held zone does not automatically qualify for income.
- Define each transition once. Finalization must award results at most once and release the match's resources on both completion and abort.
- Tear down loops, connections, bots, effects, and temporary map objects. Verify a second match in the same server.
- Inspect inherited definitions before judging whether required fields are missing.

**Required correction, not verified as implemented in this checkout:** Convergence should pay zone income only when `zone.Owner and not zone.Contested`. The handoff described this fix, but commit `ae1219b` is not included in inspected HEAD `7c83270`, whose scoring loop still checks only ownership. Reconcile the implementation before testing; other modes must explicitly define their own contesting policy.

**Design choice:** `MaxStack = 3` is a capture-speed cap, not an implementation defect. Decide how extra players contribute through defense, positioning, and other objectives before changing it.

### Timers must describe the same event

Choose an authoritative match end time or remaining-time source. Clearly distinguish match time, phase time, cooldown, and overtime. Clients display server state; they do not decide when a match ends.

**Required behavior:** Convergence's main HUD should show match `TimeLeft`, with phase-change banners and final-phase remaining time following the match cap. The inspected checkout still reads `PhaseTimeLeft` on the client and lacks the claimed final-phase correction. With current defaults, the 720-second hard cap and first two 180-second phases leave 360 seconds for the final phase; three configured 180-second phase values do not imply a nine-minute match. Document that relationship when tuning.

For a new mode, test exact phase boundaries, hard-cap expiration, overtime entry/exit, ties, and early wins. No displayed countdown should become negative, and no transition should fire twice.

## 4. Make tuning reproducible

**Implemented references:** [Config](src/shared/Config.lua), [TuningService](src/server/Services/TuningService.lua).

- Store gameplay numbers in shared definitions and expose appropriate Studio tuning attributes.
- Use a consistent prefix such as `Convergence_`. Arrays need scalar attributes where appropriate. The handoff proposed `Convergence_Phase1Seconds`, `Convergence_Phase2Seconds`, and `Convergence_Phase3Seconds`, but they are not exposed in the inspected checkout. Give each exposed value a real documented effect; reconcile a third-phase setting with a final phase governed by the match cap.
- State whether an override takes effect immediately, at match start, or after rebuilding a map. A live configuration getter does not make every consumer live.
- Recommended: validate ranges and relationships before use, such as positive durations and minimum team size no greater than target team size.
- Keep testing and production presets explicit. Record active overrides with playtest results.

**Important existing behavior:** TuningService fills missing attributes and preserves existing values. `default.project.json` also explicitly declares Tuning attributes that Rojo seeds/synchronizes; those are not wholly Studio-owned. Changing a Config default does not replace an existing override. Inspect both the project definition and the effective `ReplicatedStorage.Tuning` attributes when verifying a preset.

| Convergence preset | TeamSize | MinTeamSize | BotsPerTeam | Meaning |
| --- | --- | --- | --- | --- |
| Intended bot testing preset | 1 | 1 | 5 | One queued human plus five bots on each side; not yet effective while the Rojo project sets bots to zero |
| Intended human matchmaking | 6 | 4 | 0 | Six humans per side, or four after fill wait |

Bots currently spawn after matchmaking and are additional participants; they do not satisfy the human queue requirement. Raising the queue to 6/4 will not start a two-human bot test. Review progression/debug switches before public release, including whether bot matches count for stats.

## 5. Use one action path for every input

**Implemented references:** [TouchController](src/client/Controllers/TouchController.lua), [MutationController](src/client/Controllers/MutationController.lua), [JetpackController](src/client/Controllers/JetpackController.lua).

Keyboard, touch, and gamepad should call the same controller action, which sends the same server request. Keep eligibility and cooldown rules out of duplicated input handlers. Use button `Activated` for tap actions; hold actions also need release/cancel handling.

**Recommended standard:** release held actions when input ends outside the button, focus is lost, the HUD is disabled, the character dies, or the tool is unequipped. Test simultaneous movement, aiming, and ability input.

Adapt controls to the active input method and available screen space. Do not assume a touchscreen device never has a keyboard or controller. Roblox's [adaptive design guidance](https://create.roblox.com/docs/production/publishing/adaptive-design) recommends testing each supported input mode. The current touch detector uses touch/keyboard availability plus a debug override; treat it as a starting point, not complete hybrid-device support.

## 6. Make mobile buttons clear before adding decoration

**Implemented reference:** [TouchController](src/client/Controllers/TouchController.lua).

Each gameplay button should answer: **What does it do? Can I use it? Do I tap or hold?**

| Button property | Reusable standard |
| --- | --- |
| Main label | Short action word: MUTATE, SLAM, BRACE, CHARGE, FLY |
| Status label | READY, cooldown with units such as 2.4s, or a useful unavailable reason |
| Hold action | Keep HOLD visible while showing fuel or progress |
| Contrast | Strong backing panel, readable text, clear boundary against bright and dark maps |
| State cues | Text plus fill/ring changes; color alone must not carry availability |
| Placement | Stable action location, comfortable reach, clear of movement/jump/fire controls |
| Visibility | Show actions relevant to the current state; avoid a full grid of inactive abilities |

Current action diameters are 64-76 UI pixels on phones and 84-96 on tablets, with a 12-pixel ability gap. Secondary buttons are 44 pixels high. These are baselines to verify physically, not proof of comfortable tap targets. Test the longest labels and status text at the smallest supported size.

Recommended layout rules:

- Respect device safe areas, Roblox controls, weapon-kit controls, chat, and menus. Reserve the center for aiming and reading the arena.
- Use anchors and responsive layouts; recompute layout when the viewport or orientation changes. Do not rely on a size captured once at startup.
- Give vital match information priority: score, match clock, objective state, health, and the current action. Put detailed statistics behind SCORES.
- Keep labels understandable without desktop key hints. Never use a letter such as Q as the only mobile instruction.
- Avoid excessive flashing. Readiness should remain clear without animation.
- Test text scaling and localization expansion; shrinking text until it fits is not sufficient.

Roblox documents [reserved control zones and thumb reach](https://create.roblox.com/docs/building-and-visuals/ui/positioning-and-sizing-guiobjects). Use that guidance when positioning new controls.

**Current verification gap:** the touch HUD has labeled buttons and stronger backgrounds, but phone/tablet overlap and physical usability have not been verified in this work. `Debug_ForceTouchUi` previews visibility on desktop; it does not establish mobile acceptance. Current sizing is chosen when the GUI is built, so responsive resizing remains work to evaluate.

## 7. Preserve combat readability

Make team, character form, objective ownership, and action availability distinguishable at the same time. Avoid competing effects that erase another system's information.

**Required correction, not verified as implemented in this checkout:** preserve alter ego identity in the Highlight fill and team identity in its outline, coordinating any other team-readability effects. The inspected MutationService uses the alter ego color for both; the handoff's corrected outline must be reconciled with the running build. Do not claim a separate readability service exists without locating it in that build.

Recommended: reinforce color with names, shapes, icons, or labels where players must make a decision. Check effects from both teams' viewpoints and during crowded fights, not only on an isolated character.

## 8. Verify code, then verify play

Run the current repository gates from the project root. CI is defined in [.github/workflows/ci.yml](.github/workflows/ci.yml); conventions are in [CLAUDE.md](CLAUDE.md).

```powershell
stylua --check src
selene src
lune run tools/check_skins.luau
lune run tools/check_celebrations.luau
lune run tools/check_maps.luau
lune run tools/check_assets.luau
lune run tools/build_weapons.luau
git diff --exit-code -- assets
rojo build -o "$env:TEMP\Roblox_Benji-check.rbxl"
git diff --check
```

Inspect each command's result; a later successful command does not erase an earlier failure. Format edited Lua with StyLua first. Weapon definition changes require regenerating and reviewing the intended asset changes before expecting the asset diff check to pass. Map layout work also follows the map-building workflow referenced in CLAUDE.md.

Build/lint gates cannot verify tap reach, overlaps, gameplay balance, or multiplayer behavior. Restart Studio play after script changes. Use Roblox's [Device Simulator](https://create.roblox.com/docs/studio/device-simulator) and a real phone where available; simulated pixel dimensions alone do not establish physical readability.

| Scenario | Evidence to capture |
| --- | --- |
| Small phone and tablet | Screenshot of active combat HUD; readable labels, no overlap or clipping |
| Each supported orientation / viewport change | Controls stay reachable and within safe areas |
| Desktop and gamepad | Equivalent actions work; menus can be navigated and closed |
| Two clients, opposing teams | Queue, spawn, team readability, scoring, result agreement |
| Full intended population | Objective contention, effects density, bot behavior, frame responsiveness |
| Ability ready / cooldown / empty fuel | Correct text, server rejection of unavailable actions, reliable hold release |
| Death, respawn, disconnect, second match | No stuck controls, stale HUD, orphan effects, duplicate rewards |
| Phase boundary / hard cap / overtime | Accurate clocks and exactly one transition/result |

For contested-scoring regression coverage, own a point, bring an enemy into it, and verify that point stops contributing income while contested. Isolate other point income and kills before interpreting total score. Then remove the enemy and verify income resumes.

## 9. Source environment art by destination

**Implemented reference:** `tools/blender/appraise_asset.py`, `tools/check_assets.luau`,
`tools/blender/scene_kit.py`, `Environment.Sky` in `src/shared/Maps/SnowFortress.lua`.
Full account of what failed and why: [docs/design/ASSET_INTAKE_AND_LESSONS.md](docs/design/ASSET_INTAKE_AND_LESSONS.md).

Appraise any bought or scanned asset before pointing a pipeline at it, and record the
decision. `check_assets` fails a package whose `appraisal.json` has an empty
`decision`, and it runs in CI, so this is a gate rather than advice.

```powershell
blender -b -noaudio --python tools/blender/appraise_asset.py -- `
    --source "<file>" --record assets/<kind>/<name>/appraisal.json
```

Ask what the asset is *of* and the viewpoint it was authored for. That is not the
same question as what you want it for, and the gap between them is expensive: a
top-down scan of a flat ice plain was decimated, exaggerated, tiled, uploaded three
times and placed as a mountain range before anyone measured whether it could be one.

| Destination | Use | Not |
| --- | --- | --- |
| Prop seen from any angle | mesh via `scene_kit.py` | — |
| Horizon or anything distant | a `Sky`, chosen from the Creator Store | geometry of any kind |
| Ground the player stands on | `Terrain` data in the map module | a decimated scan |

**Recommended standard:** nothing distant should be geometry. A skybox costs no
parts, no triangles and no LOD, cannot be mis-oriented, and has no seams or plate
edges. Roblox terrain `FillBall` is native and cheap but fills *balls*: fine for
scenery nobody looks at, not for an aesthetic.

Buy the horizon rather than generating it. Two generated ranges were tried and both
lost to a Creator Store asset found in about a minute. When looking, filter to
**Visual Effects / Sky and Atmosphere** — that category holds real `Sky` objects,
while free-text "skybox" also returns models that fake one out of six giant textured
parts, putting geometry back inside the playable space.

| Check | Real `Sky` | Faked from parts |
| --- | --- | --- |
| Store thumbnail | blank, nothing to render | a rendered preview |
| On insert | appears under `Lighting` | appears in `Workspace` |
| Face ids | six distinct images | one image repeated on four sides |

Numbers that decide things, all measurable before any pipeline work:

- Roblox caps a mesh at **10,000 triangles and 2048 studs per axis**. The cap is
  **per mesh**, so tile breadth rather than decimating it away. Past roughly 90%
  reduction the silhouette is gone, and silhouette is most of what reads at distance.
- A relief ratio (height ÷ longest horizontal) under about **0.2** reads flat at any
  distance. Vertical exaggeration raises it but stretches the texture bake with it.
- A finite heightfield is a sheet with a cliff on every edge and no underside. No
  rotation or placement hides either.

**Recommended standard:** verify an export against the file, not the viewer. Blender's
importer converts axes on the way in, so a mesh exported with its height on the wrong
axis looks correct in every preview and lies on its side in game. Read the GLB's
`POSITION` accessor min/max, and stitch skybox faces with
`tools/blender/stitch_skybox.py` before uploading.

## 10. Copy this checklist into each feature plan

```markdown
### Feature: <name>
- Player objective and success feedback:
- Server-owned state and allowed transitions:
- Shared definitions / map requirements:
- External art appraised, destination chosen, `appraisal.json` decision recorded:
- Action names and touch / keyboard / gamepad bindings:
- Button labels, status text, hold behavior, placement:
- Tuning defaults, valid ranges, override names, application timing:
- Test preset and production preset:
- Completion / abort / respawn / disconnect cleanup:
- Gameplay edge cases and regression scenarios:
- Build and validation results:
- Device sizes, input modes, and multiplayer scenarios tested:
- Evidence links and known limitations:
```

Update this guide when a verified defect exposes a reusable lesson. Link the implementation, explain the general rule, and keep pending improvements visibly separate from completed behavior. Do not report a feature as mobile-tested or multiplayer-tested without that evidence.
