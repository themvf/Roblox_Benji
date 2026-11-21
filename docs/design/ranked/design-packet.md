# Ranked play — design packet

Status: G0 ready for review, G1 in progress (no visuals; five product choices open). Nothing is implemented. · Owner: Claude (author only; no independent review) · Updated: 2026-11-16

Request: add ranked play like the top Roblox shooters: a ranked queue, a skill rating, tiers, a leaderboard and seasons. Research behind it: [Rivals and BedWars market assessment](../../../reports/Rivals%20and%20BedWars%20market%20assessment.md), [top shooter comparison](../../../reports/Top%20shooter%20monetization%20comparison.md), and the ranked survey in this session (sources in §9). Related: [store foundation packet](../store-foundation/design-packet.md), whose fairness rules ranked must enforce.

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Map, mode, or shared feature? ID and display name? | **Decided.** A shared feature layered on existing modes. Internal ID `ranked`; display name "Ranked". Not a new rule set: a ranked match is an existing mode played on a ranked server with a rating at stake. |
| Which modes/maps? Authoritative spec? | **Decided.** Release 1 (R1): Duel, 1v1, first to 5 rounds, on a curated subset of the Duel rotation. Release 2 (R2): one team mode, after R1 proves the population supports it. This packet is the spec; mode rules stay in their existing sources. |
| Player fantasy and repeatable decision? | **Decided.** "I'm getting better, and the game can prove it." The repeatable decision is whether to queue ranked now, and with what loadout and map bans. |
| Who is it for, which devices? | **Decided.** Committed players who have finished the entry gate; phone, tablet, desktop and console. |
| Roster, session length, test preset? | **Decided.** Two humans per match, never bots. Duel matches run up to 5 rounds won at 90 seconds each. Test preset: two accounts on a published test place (reserved servers do not run in Studio). |
| Authorized / out of scope? | **Decided.** Authorized: this packet. Out of scope for R1: team ranked, parties, ranked currency and shop, tournaments, spectating, replays. |
| Baseline source/build/tuning? | **Decided.** Branch `claude/mymap-rotation-and-training` at `57c5264` with uncommitted local changes. |
| What problem will the player notice is fixed? | **Decided.** Today a skilled player has no way to find equal opponents or show their skill. The only rating, Coherence Rating, rewards playing a lot, not beating strong players. |

### Baseline findings that shape the design

- **One match per server.** [RoundService.lua](../../../src/server/Services/RoundService.lua) "Runs one match at a time"; TDM sets the same busy flag. While a match runs, everyone else in that server waits. A ranked match cannot share a lobby server without blocking it.
- **Matchmaking never leaves the server.** [QueueService.lua](../../../src/server/Services/QueueService.lua) forms teams from players in one lobby. Nothing in `src` uses `TeleportService` or `MemoryStoreService`. A server's handful of queued players is too few to match by skill.
- **Coherence Rating is a career score.** [Progression.lua:81](../../../src/shared/Progression.lua:81) mixes win rate, objective score, MVP rate and bounties, scaled by matches played. It ignores opponent strength and never resets. It stays as the career board.
- **Leaderboards already exist.** [LeaderboardService.lua](../../../src/server/Services/LeaderboardService.lua) keeps four boards in Roblox's ranked data store (OrderedDataStore), refreshed every 60 seconds, drawn on the lobby wall. A seasonal ranked board is one more of these.
- **The Duel format already matches the reference games.** First to 5 rounds, 90-second rounds (`Config.RoundsToWin`, `Config.RoundSeconds`), the same shape as Rivals' ranked duels.
- **Weapons will be bought with Credits.** The store packet makes 12 of 16 weapons locked by default. Ranked must answer whether a locked weapon is a ranked disadvantage (§2, choice 1).

## 2. Mode rules

### Why Duel first

A 1v1 needs two players of similar rating at the same moment; a 3v3 needs six. Rating maths is cleanest for one player against one. Rivals' main ranked queue is the duel. Team ranked waits for evidence that the queue fills (§7, RK-14).

### Where ranked matches run

Ranked matches run on **reserved servers**: private servers of this same place, created by the game for one match.

```
Lobby server                         Shared queue (MemoryStore)           Match server (reserved)
Player presses RANKED  ── gate ──>   entry {userId, rating, since}
                                     pairing pass finds two players ──>   record {matchId, players,
lobby server that owns the pair                                            ratings, map pool, season}
reserves a server, writes the record,                                      keyed by privateServerId
teleports both players          ───────────────────────────────────────>  reads record, runs Duel
                                                                           writes ratings to profiles
both players return to a public lobby <──────────────────────────────────  teleports both back
```

- **Decided.** The lobby keeps running while ranked matches run elsewhere, so ranked never blocks casual play.
- **Decided.** The match server trusts only the record it reads by its own server id, never data carried by the players.
- **Decided.** A server that started as a ranked match server builds no lobby and accepts no one outside the record.
- **Hypothesis.** Exact API names (`TeleportService:ReserveServerAsync` returning an access code and private server id, `TeleportOptions`, `MemoryStoreService` sorted maps and queues) are checked against current Roblox docs at G2. Owner: implementer.

### States

```
Lobby -> Queued -> Matched -> Teleporting -> Map ban -> Rounds -> Result -> Returning -> Lobby
                \-> Cancelled (player leaves queue, or queue closes)
Teleporting -> Void (a player never arrives within Ranked_ArriveSeconds; no rating change)
Rounds -> Forfeit (a player leaves; counts as their loss)
```

### Rating

- **Decided.** One visible number per player, the Ranked Rating, shown with a tier badge. Rivals shows its number directly; hiding it adds a second concept for no gain at this size.
- **Decided.** Elo maths. Expected score `E = 1 / (1 + 10^((Rb - Ra) / 400))`; change `K × (S − E)` where S is 1 for a win and 0 for a loss. Only the match result counts, not the round margin, so stomping a weak player earns nothing extra.
- **Hypothesis.** Start rating 1,000 (hidden during placements). K = 48 during placements, 32 after, 24 above the top tier threshold. Placements: 5 matches.
- **Decided.** Tiers are bands of the rating: seven named tiers of three divisions each, 200 points per division, plus a top-N title. Names come from `Shared/Lore`. (Choice 3.)
- **Decided.** Repeated matches against the same opponent within 24 hours change rating by half, then not at all after the third. This blunts win trading between friends.

### Protection and penalties

- **Decided.** Shields: below the third tier, a player gets one shield per day that blocks the rating loss from one defeat. Shields do not stack. (Rivals uses the same idea for its lower ranks.)
- **Decided.** Decay applies only at the top tier: after `Ranked_DecayGraceDays` without a ranked match, the rating drops `Ranked_DecayPerDay` a day, never below the top tier's threshold.
- **Decided.** Leaving a match or failing to arrive after accepting counts as a loss and earns a queue ban that grows with repeats: 5, 15, then 60 minutes within 24 hours.
- **Decided.** A void match (server failure, or the opponent never arrives) changes nobody's rating; the player who arrived returns to the queue front.

### Entry gate

- **Decided.** Ranked unlocks for a player who meets all of: level ≥ `Ranked_MinLevel`, casual matches ≥ `Ranked_MinMatches`, and Roblox account age ≥ `Ranked_MinAccountDays`. The gate blocks alt accounts and gives new players time to learn the weapons.
- **Decided.** The gate can never be bought or skipped. The store's build gate must fail on any product that grants ranked access.

### Fairness inside the match

- **Decided.** No paid effect works in ranked: no boosts, weapon trials, rotation loans or perk items. Rewards earned in ranked can never be bought (enforced in `check_store`).
- **Decided.** No bots, ever. If no opponent is found, the player keeps waiting or leaves.
- **Decided.** Map ban: three maps from `Config.RankedMaps` are offered; each player bans one; the third is played. Every ranked map must pass the existing map fairness gates.
- **Unknown.** Which abilities, alter egos and mutations are active in Duel today, and whether any of them should be off in ranked. Owner: author, by reading `RoundService` and playing a Duel before G1.
- **Unknown.** Camera and aim-assist policy. Rivals forces first-person and caps aim assist in ranked. Decide in G1 after checking `CameraController`.
- **Open (choice 1).** Weapons in ranked; see §8.

### Pairing

- **Hypothesis.** A pairing pass every 2 seconds pairs the two longest-waiting players whose ratings are within the current window. The window starts at ±100 and widens by 50 every 10 seconds to ±600. Players never see the window, only the wait time.
- **Hypothesis.** At low population, an always-open queue produces long waits. If the median wait over a week exceeds `Ranked_MaxMedianWaitSeconds`, ranked switches to scheduled hours (`Ranked_Schedule`), concentrating players. This is the same fix BedWars uses for its weekly tournaments.

### Seasons

- **Hypothesis.** Seasons last about 10 weeks, aligned with every second battle pass.
- **Decided.** At a season start, ratings move halfway back to 1,000 and each player plays 3 placement matches. A new season board starts empty.
- **Decided.** Season rewards are cosmetic and unbuyable: a tier charm and title for the final tier; a weapon skin for reaching `Ranked_WinsForSkin` ranked wins; an exclusive title and MVP celebration for the season's top N. The MVP celebration is the one moment the whole server watches, so it is where top players are seen.

### What persists

The player profile gains:

```
Ranked = {
    Season, Rating, Peak, Placed, PlacementsLeft, Wins, Losses,
    LastPlayedAt, ShieldDay, BanUntil, BanCount24h,
    RecentOpponents = { [userId] = { count, firstAt } },
}
RankedHistory = { [season] = { FinalRating, FinalTier, Wins, TopN } }
```

The match server owns the profile while the player is on it. ProfileStore's session lock moves it with the player: the lobby releases it on leave, the match server loads it on arrival, and the result is saved before the teleport home.

## 3. Map questions

- **Decided.** `Config.RankedMaps` is a curated subset of the Duel rotation (`Config.Maps`). Hypothesis: start with three to five maps that pass `check_maps` symmetry and fairness checks.
- **Unknown.** Which Duel maps qualify. Owner: author with the `roblox-map-building` skill before G1.
- No new geometry.

## 4. Player storyboard

Storyboard brief only; visuals are required before G1 can be accepted.

| Frame | Player view | Player question | Decision/action | Feedback and next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Locked | PLAY menu, Ranked shows a lock | "When can I play ranked?" | None | Progress bars for level, matches and account age | PLAY menu |
| 2 Queue | Ranked selected; tier badge and wait timer | "How long will this take?" | Queue or leave | Timer; estimated wait if known | QueueService UI |
| 3 Found | "Opponent found" with both tier badges | "Who am I playing?" | None (auto-accept in R1) | Teleport screen | New ranked UI |
| 4 Ban | Three maps; ban one | "Which map favours me?" | Ban | Remaining map revealed | Map vote UI |
| 5 Rounds | Standard Duel HUD plus both badges | "Am I winning?" | Play | Round score | RoundService HUD |
| 6 Setback | Lost; "−18, shield used" or "−18" | "How much did that cost me?" | Requeue or stop | Rating change, shield state | Recap card |
| 7 Climb | Division up; badge animation | "What did I earn?" | Requeue | New tier, progress to next | Recap card |
| 8 Season end | Final tier, rewards, top-N board | "Where did I finish?" | Claim rewards | Charm, title, skin | Lobby wall board |

## 5. Visual and interaction contract

- **Layout.** All panels through `Screen`; colours and type through `Theme`; load the `roblox-ui-layout` skill before building.
- **Tier badges.** Shape and name, never colour alone.
- **Input.** Queue and Leave are tap/click/controller A; the map ban is a three-card choice with a timer and a default ban if time runs out.
- **States.** Locked · Queueing (with timer) · Found · Teleporting · Arrival timeout (Void) · Banned (with time left) · Ranked closed (scheduled hours, with next open time) · Placement (n of 5) · Placed.
- **Lobby wall.** A fifth board, "Ranked — Season N", beside the existing four, showing the top N names, tiers and ratings.
- **Not applicable:** new art target, map materials.

## 6. Reuse and ownership contract

| Component | Reuse / extend / new | Owner/path | Data/input → result | Consumers affected | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| `Shared/Ranked.lua` | New | Pure functions | Ratings, result → new ratings; rating → tier; pairing window from wait time | RankedService, UI, `check_ranked` | `check_ranked` unit cases |
| `RankedService` | New | Server | Lobby side: gate, shared queue, pairing, reserve and teleport. Match side: read record, run Duel, write results, teleport home | QueueService, RoundService, DataService | RK-01 to RK-13 |
| `RankedController` | New | Client | Queue, found, ban, result and locked states | PLAY menu, recap card | RK-15 |
| `QueueService` | Extend shared | Existing | A Ranked entry hands the player to RankedService instead of a pad | Casual queues | Casual queue fills and starts as today |
| `RoundService` | Reuse unchanged where possible | Existing | Runs the Duel on the match server; reports the winner | Duel | Casual Duel unchanged |
| `MapService` | Extend shared | Existing | Builds the banned-down map on the match server; no lobby on a ranked server | All modes | Lobby builds as today on public servers |
| `DataService` | Extend shared | Existing | Template gains `Ranked` and `RankedHistory` | Every profile load | Existing profiles load with new fields only |
| `LeaderboardService` | Extend shared | Existing | Board `Ranked_S<n>` per season | Lobby wall | Existing four boards unchanged |
| `CelebrationService` | Extend shared | Existing | Season-reward celebration entries, flagged unbuyable | MVP sequence | Celebration validator passes |
| `StoreService` (planned) | Extend planned | Store packet | `Owns` reports "ranked-disabled" for boosts, trials and loans on a ranked server | Loadout | No paid effect active in ranked |
| `Config.Ranked` + Tuning | Extend shared | `Config.lua` | All numbers in §2 and §8 | TuningService | Out-of-range falls back to default |
| `tools/check_ranked.luau` | New | Build gate, added to CI and the CLAUDE.md gate list | Fails on: rating maths drift from fixtures, tier table gaps or overlaps, a ranked map not in the Duel rotation, a ranked reward id present in the store catalog | CI | Gate passes |

**Why new.** Nothing in the project matches across servers, reserves servers or keeps a skill rating. The new pieces are the minimum for that; mode rules stay where they are.

**Authority.** The lobby server that formed a pair owns reservation and teleport. The match server owns the result. Clients never report results or ratings.

**Cleanup.** Queue entries expire after `Ranked_QueueEntrySeconds` without a heartbeat from their lobby server. Match records expire after the longest possible match plus a margin. A match server with no record after `Ranked_ArriveSeconds` sends everyone home.

**Tuning (`Ranked_*`, hypotheses).**

| Setting | Default | Range |
| --- | --- | --- |
| Enabled | true | |
| Schedule | "always" | "always" or a list of UTC windows |
| MinLevel | 10 | 1–100 |
| MinMatches | 20 | 0–200 |
| MinAccountDays | 14 | 0–90 |
| Placements | 5 | 1–15 |
| SeasonPlacements | 3 | 0–10 |
| StartRating | 1000 | 0–3000 |
| KPlacement / K / KTop | 48 / 32 / 24 | 4–100 |
| WindowStart / WindowStep / WindowMax | 100 / 50 / 600 | 0–2000 |
| WindowStepSeconds | 10 | 1–60 |
| DecayGraceDays / DecayPerDay | 7 / 50 | 1–60 / 0–500 |
| BoardSize | 100 | 10–500 |
| WinsForSkin | 50 | 1–1000 |
| ArriveSeconds | 45 | 15–120 |
| QueueEntrySeconds | 20 | 5–120 |
| MaxMedianWaitSeconds | 120 | 30–900 |

## 7. Acceptance and evidence

All rows **Not started**. RK-01 to RK-13 need a published test place and at least two accounts.

| ID | Player-visible requirement | Test | Threshold |
| --- | --- | --- | --- |
| RK-01 | Gate holds | Account below each gate condition presses Ranked | Refused with the unmet condition shown |
| RK-02 | Two queued players meet | Two eligible accounts in different lobby servers queue | Same match server within 30 s |
| RK-03 | Casual play is not blocked | Run a casual match in a lobby while two of its players are in ranked | Casual match starts and finishes normally |
| RK-04 | Ratings change correctly | Play a match between known ratings | Both new ratings equal `check_ranked` fixtures |
| RK-05 | Leaving is a loss | One player leaves mid-match | Leaver loses rating and gets the 5-minute ban; stayer wins |
| RK-06 | No-show is void | One player never arrives | No rating change; arriving player re-queued at the front |
| RK-07 | Results survive the trip home | Finish, return to lobby, rejoin later | Rating, wins and placement count persist |
| RK-08 | No paid effect in ranked | Own a boost, a trial and a loaned weapon; enter ranked | None active; `Owns` reports ranked-disabled |
| RK-09 | No bots | Queue alone for the full window | No bot match; player can keep waiting or leave |
| RK-10 | Win trading is blunted | Same pair plays four times in 24 hours | Third match moves rating by half; fourth by nothing |
| RK-11 | Season reset | Advance the season | Ratings halved toward 1,000; placements reset; board empty; rewards granted once |
| RK-12 | Decay only at the top | Top-tier and mid-tier accounts idle past grace | Only the top-tier account decays, never below its threshold |
| RK-13 | Board shows the top N | Several accounts with known ratings | Board order and values correct within one refresh |
| RK-14 | Team ranked is justified | One week of R1 queue data | Median wait below `MaxMedianWaitSeconds` before R2 starts |
| RK-15 | Every state reads on every device | `roblox-ui-layout` QA gate | Passes on phone, tablet, desktop, console |
| RK-16 | Existing gates stay green | Full pre-commit list plus `check_ranked` | Zero warnings |

## 8. Gates and handoff

| Gate | Status | Evidence / decision |
| --- | --- | --- |
| G0 Baseline | Ready for review | §1 findings, commit `57c5264` |
| G1 Design | In progress | Needs storyboard visuals, the Duel ability/camera audit, the ranked map list and the choices below |
| G2 Playability | Not started | |
| G3 Complete section | Not started | |
| G4 Extension | Not started | Team ranked |
| G5 Release candidate | Not started | |

**Next concrete task.** Write `Shared/Ranked.lua` and `tools/check_ranked.luau` (rating maths, tiers, pairing window). Pure code that needs none of the choices below and no published place.

**Choices for the user.**

1. **Weapons in ranked.** Recommended: a ranked arsenal: every ranked player may use the starter and Standard weapons whether or not they own them, and Prime weapons are off in Season 1. Ranked then measures skill, and Credits keep their value in casual play. Alternative: owned weapons only, with each player banning one of the opponent's (the Rivals approach), which makes locked weapons a ranked disadvantage.
2. **Start with Duel 1v1.** Recommended. Alternative: start with a 3v3 team mode, which needs three times the players per match.
3. **Tier names.** Seven names from the game's lore, plus a title for the top N.
4. **Season length and reset.** Recommended: about 10 weeks, halfway reset, 3 placement matches.
5. **Gate strictness.** Recommended: level 10, 20 casual matches, 14-day-old account.

**Dependencies.**

- A published test place with two or more accounts; reserved servers and teleports do not run in Studio.
- The store foundation's `Owns` check, for RK-08. Until it exists, nothing is paid and RK-08 passes trivially.
- `RoundService` must run a Duel for a fixed pair handed to it, rather than from a pad. Check how far that is from today's entry point.

**Work that can continue independently.** `Shared/Ranked.lua`, `check_ranked`, the profile template fields, the seasonal board, and the gate check need no published place.

**Shared consumers needing regression checks.** Casual queue and Duel, lobby build on public servers, profile load, existing leaderboards, celebration validator.

**Decision log.**

- 2026-11-16 — Ranked runs on reserved match servers, not in the lobby server. Reason: one match per server today; a ranked match there would block casual play. Affects RK-03.
- 2026-11-16 — Duel 1v1 first, team ranked later. Reason: fills with two players; clean individual rating; matches the reference games' core ranked queue. Affects RK-14.
- 2026-11-16 — Coherence Rating is kept as the career board, not converted. Reason: it measures volume and consistency, not strength against opponents.
- 2026-11-16 — Elo with a visible number. Reason: simplest to explain and to test; Rivals shows its number directly.
- 2026-11-16 — Ranked access and ranked rewards are never sold. Reason: a sold bypass undermines the rating; unbuyable rewards are what make them status.

## 9. Sources

- Rivals ranked rules: [All Things How](https://allthings.how/roblox-rivals-ranked-mode-and-ranks-explained/) (updated 10 Dec 2025), [Bloxodes](https://bloxodes.com/wiki/rivals/ranks), [Timesaver Season 4](https://timesaver.gg/blog/roblox-rivals-season-4). Third-party guides; season numbering conflicts between them.
- BedWars ranked: [fan guide](https://sites.google.com/view/dizzys-haven/bedwars/tips-and-tricks/ranked) (2022 rules, may be outdated), [Sportskeeda](https://sportskeeda.com/roblox-news/roblox-bedwars-ranked-guide).
- Hypershot ranked: [RoWatcher](https://rowatcher.com/news/rivals-vs-hypershot-roblox-s-biggest-shooters-go-head-to-head).
- Valorant: [SI](https://www.si.com/esports/valorant/valorant-ranked-system-explained-mmr-divisions-leaderboards), [Dot Esports](https://dotesports.com/valorant/news/how-ranked-works-in-valorant).
- Roblox platform: [custom matchmaking](https://create.roblox.com/docs/matchmaking/customize-matchmaking), [custom matchmaking announcement](https://devforum.roblox.com/t/custom-matchmaking-is-now-available-to-all-experiences-on-roblox/4051419), [memory store sorted maps](https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map.md).
