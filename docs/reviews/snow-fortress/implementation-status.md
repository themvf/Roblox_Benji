# Snow Fortress implementation status

Started 2026-09-20 on `codex/snow-fortress-redesign`. Working changes are not yet committed. This records the first implementation tranche; it does not mark the full redesign complete.

## Baseline found

The actual Snow Fortress source was located in the clean local worktree `.claude/worktrees/snow-fortress-design-17939a`, branch `claude/snow-fortress-design-17939a`, commit `ae1219b`. Its `SnowFortress.lua` defines the terraced fortress, plinth enclosure, and objectives. Its `WeaponBarController.lua` explicitly used 48-pixel slots and only named the equipped weapon, matching the reported visual symptoms.

Source and supporting tools differing from master were imported into this workspace without overwriting existing local edits. Config was reconciled manually to retain the local five-bot default and register SnowFortress. This is source integration, not a claim that the original commit is now an ancestor or that the exact screenshot place version has been verified.

The working source now includes map voting, the fortress prefab builder, readability/camera controllers, and the handoff correctness fixes required by that baseline. No exterior geometry redesign has been applied yet. Original screenshot evidence remains unchanged in `evidence/`.

## Requirement status

| Requirement | Status | Evidence / remaining work |
| --- | --- | --- |
| BASE-01 | In progress | Authoritative local branch and source located/imported; running Studio version, effective overrides, and live captures remain to verify |
| TEST-01 | Implemented, runtime unverified | Config and default.project.json both set 1/1 human queue and five bots/team; automated preset consistency check passes; live 12-participant check pending |
| OBJ-01 | Implemented, gameplay unverified | Imported scoring condition excludes contested objectives; isolated live capture test pending |
| OBJ-02 | Not started | Need per-objective vertical extents and shared membership audit |
| OBJ-03 | Implemented, gameplay unverified | Imported match-time HUD/final-phase handling; added nonnegative match time and validated first/second phase overrides; final phase derives from cap; automated invalid/boundary cases pass |
| OBJ-04/05 | In progress | Imported existing compact objective HUD as baseline; local state and effect redesign pending |
| UI-01 | Implemented first pass, visual unverified | 64–104 by 88 pixel weapon cards, persistent names, backed status, equipped text, category sorting, touch Activated and controller cycling; preview excludes invisible parts and fits projected geometry to aspect ratio; no real device acceptance yet |
| UI-02 | Not started | Responsive loadout category design still pending |
| HUD-01/02/03/04 | In progress | Existing touch clarity changes preserved; weapon row resizes; full responsive/simultaneous-input composition not yet accepted |
| CAM-01 | Not started | Existing camera baseline imported; accessory occlusion treatment pending |
| CAM-02 | Implemented baseline, visual unverified | Imported coordinated team/alter-ego Highlight treatment; avatar matrix pending |
| MAP-01/02/03/04 | Not started | Original fortress source restored; exterior routes, new districts, boundary redesign, and travel-time proof pending |
| ART-01/02/03 | Not started | Existing fortress art is baseline only; no claim that importing it improves its quality |
| BOT-01 | Not started | Runtime route and roster tests pending |
| UX-01 / PERF-01 / REG-01 | Not started | Physical-device, human usability, performance, and cross-mode runtime checks pending |

## Automated evidence

- `tools/check_fortress_baseline.luau`: passes normal/invalid phase overrides, total duration invariants, Config/Rojo bot agreement, and camera-fit bounds for tall/wide geometry across aspect ratios.
- StyLua and Selene: pass, zero warnings/errors.
- Skins: 42 pass. Celebrations: 8 pass.
- Weapon regeneration: passes and leaves generated assets unchanged.
- Rojo build: passes; output is in the local temporary directory as `SnowFortress-redesign.rbxl`.

These checks do not prove model appearance, actual input behavior, combat balance, or map traversal. The weapon preview geometry calculation has automated coverage; the actual rendered icons still need to be viewed in Studio.

## Next slice

### Rotating finale implementation — 2026-09-20

FIN-01–04 are implemented in source, pending in-game visual/multiplayer acceptance. `src/server/FinalePlan.lua` owns a private plan and per-map server-session reveal history. Snow Fortress opts in with stable gate/yard/keep IDs and `Finale.EligibleIds`; other maps keep fixed phases. Preflight rejects invalid IDs and fewer than two eligible districts before map loading/spawning. History advances at phase-2 reveal, not at selection, and excludes the previous revealed finale on each map.

Phase 1 snapshots and bot zone data do not contain the selected future plan. The phase-1 individual closure warning is suppressed for rotating maps. Phase 2 closes one non-final district, reveals the final district, and preserves the other survivor's income eligibility and ownership. Phase 3 closes the remaining non-final district. The same selected district remains through overtime. Stable world/HUD FINAL markers are restored by snapshots; one-time reveal events are deduplicated by match ID and include a short world pulse. `UI_ReducedMotion` skips the pulse/banner movement.

The district names now use Gate Courtyard, Service Yard and Command Keep. Their coordinates and geometry are still the existing baseline; the separate district/exterior topology redesign is not implemented by this naming or phase change. All three are prototype finale candidates, not yet certified as balanced finales by playtests.

Audio hookup: add a Sound or StringValue to `ReplicatedStorage.Uploads` named `FinaleReveal_gate`, `FinaleReveal_yard`, or `FinaleReveal_keep`, with a valid uploaded asset ID. Generic `FinaleReveal` is the fallback. No recorded announcer asset was available during implementation; missing audio leaves the caption and visual markers functional. Actual voice playback remains pending asset configuration.

FIN-05 automated evidence: `lune run tools/check_finale_plan.luau` passes all six closure combinations, hidden/revealed state, repeat prevention over 30 further selections, intervening-map history, unrevealed-abort behavior, eligibility exclusion, duplicate/invalid IDs, malformed configuration, and non-opted-in compatibility. The test and existing baseline regression are included in CI. StyLua, Selene, baseline regression and Rojo build pass. Output: temporary directory `SnowFortress-finale.rbxl`.

Live checks still required: play all eligible finales, verify isolated phase-2 and phase-3 scoring, inspect phone/world reveal markers and actual announcer playback, respawn during the reveal, and play consecutive matches. Automated plan tests do not substitute for those checks.

1. Run Rojo from this workspace (not the old fortress worktree), verify source/tuning in Studio, and select Snow Fortress via map vote or `Debug_ForceMap = "SnowFortress"`.
2. Capture the new weapon cards in gameplay and on a small phone viewport. Confirm equip order and names through pickup, respawn, and switching; tune layout from those captures.
3. Design and review the exterior district/route plan against the now-located original geometry. The old plinth enclosure is the actual boundary problem; replace it only together with walkable exterior geography and valid recovery data.
4. Build the complete exterior approach/entrance/objective slice and complete the remaining spec gates.

Do not publish or count bot playtests as production progression acceptance. Preserve unrelated local docs and edits when making subsequent commits.
