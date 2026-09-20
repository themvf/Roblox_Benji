# Leaderboards and progression: implementation handoff

Prepared 2026-09-20 against HEAD `7c83270` plus local changes. This is a code inspection and implementation plan, not proof of live persistence or device testing. Extend the existing systems rather than replacing them.

## Current implementation

| Capability | Existing behavior | Main reference |
| --- | --- | --- |
| Global lobby boards | Top 10 Rating, Best Streak, Wins, Bounties Claimed; OrderedDataStore; 60-second refresh; wall display | `src/server/Services/LeaderboardService.lua`, `MapService.lua` |
| Match scoreboard | Player score, K/D/A, captures, stops, bounty, streak; Tab or mobile SCORES | `src/client/Controllers/ScoreboardController.lua`, `TouchController.lua` |
| Win streaks | Current/best streak, named tiers at 2/3/5/8/10/15 wins; valid loss resets current streak | `src/server/Services/StatsService.lua`, `src/shared/Progression.lua` |
| Legacy checkpoints | Persistent milestones at 3/5/8/10 wins, stored as a string | `StatsService.lua`, `DataService.lua` |
| Streak visibility | Lobby nameplates, pre-match announcements, scoreboard, result recap | `HudController.lua`, `ScoreboardController.lua`, `RecapController.lua` |
| Progression | Persistent stats, XP, level, winning-team MVP, score breakdown | `StatsService.lua`, `Progression.lua`, `DataService.lua` |
| Match bounties | Combat/objective marking, eligible XP payout, repeat-pair reductions, survival reward, markers and pings | `StatsService.lua`, `BountyController.lua` |
| Persistence | ProfileStore template, reconciliation, attribute mirroring | `src/server/Services/DataService.lua` |

These richer progression hooks run through Convergence. Duel uses a separate path that increments shared Matches, Kills, and Wins; it does not call the same streak/XP/recap flow. Do not advertise complete mode parity.

Saved checkpoint data is implemented; Roblox platform badge awards and a checkpoint collection screen were not found in the inspected progression path. Do not describe checkpoint flags as awarded platform badges.

## Confirmed gaps and risks

1. **Leaderboard outage recovery:** `available` becomes false after a failed fetch and is never reset. `Submit` then returns early for the rest of the server session. Fetches still run, but later success does not restore the flag. Write failures are swallowed. The UI incorrectly treats every failure as missing Studio API access.
2. **Mobile discovery:** there is no dedicated client leaderboard menu consuming `GetBoards` / `Boards`. The persistent boards are a lobby wall; SCORES opens only the match scoreboard. No personal progression overview or personal-rank payload is implemented, despite a `You` field described in a signal comment.
3. **Scoreboard width:** column fractions total 1.10, so cells extend beyond their row. The panel has no scrolling and a height based on row count. The recap is fixed at 520 by 380 with fixed-height wrapped labels. Both need responsive layout verification and repair.
4. **Public-match eligibility:** `countsAsPublic()` checks the bot flag/debug setting, not Studio/private/reserved-server status. `match.Bots` is captured at start from tuning; verify what happens if bots are added through chat later. `Debug_CountBotMatches` defaults true. Test matches can affect the same profile/board names if real API access is used.
5. **Rating scope:** the Convergence Rating formula reads lifetime shared Matches/Wins alongside objective/MVP stats from Convergence. Duel changes the denominator/wins without equivalent objective data. Decide and document mode scope before publishing this as a Convergence-only measure.
6. **Live evidence missing:** inspect code and run tests before claiming reconnect persistence, board recovery, correct disconnect treatment, reward idempotency, or usable mobile layout.

## Recommended delivery order

### Stage 1 — Make existing progression trustworthy

Read `ROBLOX_BEST_PRACTICES.md` and `CLAUDE.md`. Preserve current gameplay balance and existing save keys unless a documented migration is necessary.

- Add a testable match eligibility decision with explicit reason codes. Recommended production policy: only eligible completed public human Convergence matches count for competitive progression; Studio/bot/private tests use a separate test namespace or a clearly labeled noncompetitive path. Treat this as a proposed policy, not an already enforced rule.
- Determine eligibility from actual match participants and bot use throughout the match, not only initial tuning. Record mode and eligibility in the final result. Define policy for disconnects, reconnects, draws, short matches, and aborts; keep unapproved new penalties out of implementation.
- Resolve rating scope. Recommended approach: retain lifetime totals and add per-mode competitive counters for rating. Existing aggregate history cannot reliably be split by mode; do not fabricate historical Convergence counts. Document whether rating starts fresh under a new version or the label/formula changes instead.
- Separate test data from production writes before testing with API access. Preserve existing data; do not wipe or overwrite boards as a migration shortcut.
- Confirm profile readiness, single finalization, and consistent persistent updates. Ensure a repeated completion call cannot award the same match twice within the supported lifecycle.

Acceptance: eligible win increments the intended counters once; valid loss resets current streak while best/checkpoints remain; thresholds 2/3/5/8/10/15 produce the correct tiers; abort/short match/draw/test-policy cases have the specified effect; Duel cannot silently distort a Convergence-only rating; reconnect restores saved fields in an isolated persistence test.

### Stage 2 — Repair leaderboard data service

- Track status per board: loading, ready, stale, unavailable, with last successful refresh time. A failed board must not disable unrelated boards.
- Retain the last successful rows through transient failures; recover automatically after a later successful request. Show a useful unavailable/retrying message, with Studio guidance only when appropriate.
- Add bounded retries/backoff and visible diagnostics. Respect request budgets, cache username lookups, and avoid resubmitting unchanged values every refresh. Serialize pending writes per player/board so an old retry cannot replace a newer value. Rating can decrease; do not use a max-only update for it.
- Include stable UserId in rows. Return a cached board snapshot through `GetBoards` and publish refreshes through the existing signal. Keep the lobby wall working.
- Return the local player's values separately. If that player is outside the fetched top 10, say “Outside top 10”; do not invent a global rank or scan an unbounded datastore to find it.
- Keep board schema/version and ranking meaning documented. No new datastore names without an intentional compatibility/migration decision.

Acceptance: inject a read failure followed by success and verify submission/display recovery; inject write failure and confirm bounded ordered retry; cached rows remain visible as stale; one board failure does not break the others; empty results differ from service failure; UI refreshes use cache rather than causing a datastore request per tap.

Use Roblox's official [datastore error and budget guidance](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) and [datastore best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices). A protected call alone does not implement recovery.

### Stage 3 — Add clear player-facing menus

Implement a dedicated leaderboard controller and a personal progression view using existing services and attributes.

- Add a clearly labeled **LEADERBOARDS** entry in the lobby and a **MY PROGRESS** view. Keep **SCORES** for the current match. Avoid adding persistent combat buttons for every menu.
- Leaderboards: tabs/dropdown for Rating, Best Streak, Wins, Bounties; rank/name/value rows; highlighted local player when present; local value summary; loading/empty/stale/error states.
- My Progress: level and XP to next level, current streak, next streak tier, best streak, unlocked checkpoints, wins/matches, MVPs, and bounty totals. Label checkpoint milestones distinctly from platform badges or claimable rewards.
- Explain rating in plain language and identify its mode/time scope. Do not expose raw implementation flags to players.
- Fix match scoreboard column widths and provide scrolling/compact rows for small screens. Keep important columns visible; reveal secondary detail without unreadably small text.
- Make recap responsive and scrollable where necessary. Preserve XP/streak/MVP information and coordinate its timing with celebrations so controls remain usable.
- Use clear tab/close labels, at least the project's established secondary-button tap height, safe-area positioning, and keyboard/gamepad navigation. Ensure input is released and menus close cleanly on state changes.

Acceptance: small landscape phone, tablet, and desktop can open/switch/close the views; long names and all top-10 entries remain readable; scoreboard supports intended player count without overflowing; recap has no clipped text; gamepad has a usable back action; HUD/menu layering does not hide the close button or block required gameplay controls. Capture screenshots and report physical-device coverage separately from simulator coverage.

### Stage 4 — Optional extensions, after the core is verified

README explicitly defers weekly leaderboards, rivalry history, and cross-match streak bounties with currency. They are not needed to finish Stages 1-3. Do not invent an economy or silently add them as part of a reliability fix.

For a later weekly-board feature, first specify metric, eligible modes, UTC week boundary, season/week key, current/previous-week display, rollover behavior, tie policy, and whether there are rewards. Rewarded boards additionally need idempotent claims and a correction policy. Preserve all-time boards.

For rivalry history, first specify qualifying encounters, privacy/display rules, retention limits, and whether repeated opponents influence rewards. Store bounded history rather than an unlimited opponent ledger.

For cross-match streak bounties/currency, first specify sources/sinks, caps, eligibility, anti-farming behavior, persistence, disconnect policy, and duplicate-claim handling. Saved titles/checkpoints and XP do not constitute an implemented currency economy.

## Verification and handoff deliverables

- Add focused tests around eligibility, streak transitions, rating scope, and leaderboard failure/retry behavior. Test state changes and outcomes, not copied implementation expressions.
- Run repository gates documented in `ROBLOX_BEST_PRACTICES.md`; preserve generated asset consistency.
- Run two-client Convergence tests and intended-population bot tests using isolated test data. Include an abort, a second match in the same server, a disconnect, and an input-mode change.
- Verify save/rejoin and board publishing in an isolated API-enabled environment. If unavailable, explicitly mark that validation pending rather than claiming mock tests prove persistence.
- Deliver code, focused test results, device screenshots, migration/namespace notes, and updated player-facing documentation. Distinguish implemented, tested, and deferred items in the final summary.

## Copyable prompt for the next agent

> Complete the existing leaderboard and progression system using LEADERBOARDS_AND_PROGRESSION_HANDOFF.md. Begin with Stage 1 eligibility/rating decisions and Stage 2 leaderboard recovery, then implement the mobile-friendly menus and layout fixes in Stage 3. Inspect the existing code before editing; preserve working streaks, XP, bounties, and profile data. Read ROBLOX_BEST_PRACTICES.md and CLAUDE.md. Treat proposed policy changes as design choices, resolve them from current user direction where possible, and isolate test data. Do not implement Stage 4 economy/weekly/rivalry features without a separate design decision. Add focused regression tests, run project gates, and report live persistence and device checks accurately. Preserve unrelated local edits and do not publish or migrate production data as part of testing.

At preparation time, local edits include bot defaults, touch-button clarity, README/CLAUDE documentation, and the new best-practices guide. Check the current working tree before starting; do not revert or accidentally absorb unrelated changes.
