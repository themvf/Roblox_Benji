# Team Deathmatch on Snow Fortress — design packet

Status: G2 source implemented, Snow Fortress runtime pending · Owner: Codex · Updated: 2026-11-10

## 1. Identity and intent

| Question | Decision / evidence |
| --- | --- |
| Identity | **Decided:** map-independent `TDM` mode, displayed as Team Deathmatch; Snow Fortress is currently the only public arena. |
| Authority | **Decided:** [TDM contract](../REUSABLE_TDM_MAP_AUTHORING_SPEC.md#6-team-deathmatch-contract) for rules; `Config.TDM` for live defaults and Tuning overrides. |
| Outcome | **Decided:** a player can choose 5v5 in the rectangular PLAY hall or menu and enter a respawning team kill match on Snow Fortress. The same arena remains available for the three objective Convergence mode. |
| Roster/session | **Decided:** exactly five humans on each public team; 50 kills or ten-minute regulation, with a full two-minute overtime on a tie. |
| Scope | **Decided:** this slice adds the playable public mode and one map. The reusable blank Studio authoring workflow in the broader spec remains separate work. |
| Baseline | **Verified in source:** Duel and Convergence used their own services and the lobby had no active TDM path. |

## 2. Mode rules and state

`Lobby → Queued → Committed → Intermission → Regulation → Overtime if tied → Result → Lobby`.

- **Decided:** the shared QueueService accepts menu and physical Red/Blue choices. It waits for five humans per side; bots do not satisfy the public queue. TDMService uses the existing map loading and player spawn systems.
- **Decided:** the PLAY label names the mode, not a map. `Config.TDMMaps` is the approved public rotation. Additional compatible maps join that list and use the same vote and match service; drafts stay outside public matchmaking.
- **Decided:** an eligible elimination credits the opponent team when a participating enemy dealt the most recent tagged hit within ten seconds. Self, friendly, and untagged environmental deaths give no point. A dead player respawns after three seconds with one second of spawn protection.
- **Decided:** first to 50 wins in regulation. At the ten-minute limit, the leader wins. A tie runs the entire two-minute overtime; the leader then wins or the match draws. A team with no connected players aborts the match.
- **Hypothesis:** existing damage tags cover all intended weapons and abilities. Verify kill attribution, protected hits, environmental deaths, and near-simultaneous eliminations in Studio before accepting the rule implementation.
- **Unknown:** how the ten-second recent-hit window feels in play. It is exposed as `TDM_RecentHitSeconds` for balance testing.

## 3. Map and layout

`SnowFortressTDM` derives its layout and six-per-side spawns from `SnowFortress` and reuses the approved `SnowFortress.rbxm` geometry. It removes Convergence objectives and finale only in the TDM layout; the Convergence layout retains all three objectives. The sixth spawn on each side remains an available respawn alternative. The source map validator checks the TDM layout against the same baked collision geometry. Spawn sightlines, exits, recovery behavior and ten-player performance still need a populated Studio test.

The [arrival concept](../lobby-experience/arrival-concept.svg) shows the rectangular PLAY hall. The source hall contains distinct Duel, Convergence, TDM and Practice zones; its TDM zone has physical Red and Blue halves. The concept is not a Studio capture.

## 4. Player storyboard

| Frame | Player question | Action and feedback |
| --- | --- | --- |
| Arrival | Where is team play? | PLAY hall and menu show Team Deathmatch 5v5. |
| Join | Which team needs me? | Choose Red or Blue; queue counts update. |
| Wait | Can I prepare? | Queue remains active while editing loadout; Leave is explicit. |
| Spawn | Where am I fighting? | Intermission names Snow Fortress; team spawns and protection apply. |
| Death | Can I rejoin? | Three-second respawn; team score changes only for an eligible enemy kill. |
| Finish | Did we win? | Score, winner or draw appear; players return to lobby. |

## 5. Visual and interaction contract

Red and Blue remain team-only colors, paired with text labels and separate pad positions. TDM uses the shared PLAY card, queue counts and round HUD. The timer and score are broadcast by the server. Existing `Screen` and `Theme` components own safe-area and contrast behavior. Phone, tablet, desktop and controller captures are pending.

## 6. Ownership

| Component | Owner | Role / regression |
| --- | --- | --- |
| Public queue | `QueueService`, `MapVoteService` | Shares menu/pad selection; Duel and Convergence queue regression required. |
| Match rules | `TDMService`, `TDMRules`, `Config.TDM` | New authority for scoring, respawn, result and cleanup. |
| Map | `SnowFortressTDM`, `SnowFortress`, `MapService` | Both layouts reuse the same baked arena and spawn placement; Convergence map regression required. |
| Combat attribution | Weapon, ability, melee and turret services | Existing damage tags plus hit time; cross-weapon kill checks required. |
| Presentation | Lobby navigation, HUD, Lobby layout | Shared entry/status and match result; device checks required. |

## 7. Acceptance and evidence

| ID | Requirement | Test / threshold | Status |
| --- | --- | --- | --- |
| TDM-01 | Find and join mode | Five arrival spawns; menu and pad both queue Red/Blue; counts agree | Source implemented; Studio pending |
| TDM-02 | Correct public roster | Nine players never start; five per side start the selected approved TDM map | Source implemented; ten-client test pending |
| TDM-03 | Correct scoring | Enemy hit kill scores once; self, friendly and untagged deaths do not | Rules source checked; live combat pending |
| TDM-04 | Regulation and overtime | Target, regulation leader, full tied overtime and draw match the spec | `check_tdm_rules.luau` passes; Studio timing pending |
| TDM-05 | Respawn and cleanup | Three-second respawn, one-second protection, result and return to lobby | Source implemented; live match pending |
| TDM-06 | Snow Fortress compatibility | No capture objectives; valid spawns and shared baked geometry | `check_maps.luau` and `check_fortress_modes.luau` pass; Studio edit state confirms layout values; populated walkthrough pending |

## 8. Gates and handoff

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 Baseline | Complete | Existing services and map relationships inspected. |
| G1 Design | Provisional | User chose rectangular PLAY and now Snow Fortress as the only public map for objective and TDM modes; concept is source based. |
| G2 Playability | In progress | Source mode, map and queue exist; ten-client Studio match required. |
| G3 Complete section | Pending | Device captures and match feedback review. |
| G4 Extension | Pending | Reusable blank TDM map authoring workflow from the broader spec. |
| G5 Release candidate | Pending | Full gates and populated runtime evidence. |

Next concrete task: start a fresh Studio session with ten clients, use both TDM entry routes on Snow Fortress, play through score and time outcomes, and capture lobby/device views. Also run a Convergence match and confirm all three objective zones. Preserve the broader TDM authoring spec as an outstanding dependency; source build success alone does not prove the experience.

Decision log: 2026-10-11 — adapted existing Snow/Forest geometry into a TDM-only Snow Forest map and placed its five-per-side queue inside one rectangular PLAY hall, per the user's direction.

Decision log: 2026-11-10 — user selected Snow Fortress as the sole current arena for the three objective mode and Team Deathmatch. The TDM layout reuses the fortress bake; the older Snow Forest layout stays in source but is removed from the public rotation. `Maps` (Duel) was already Snow Fortress only. Map votes skip automatically when a rotation contains one arena. Local map and TDM rule checks pass; Studio match verification is pending.

Verification on 2026-11-10: `check_maps.luau`, `check_fortress_modes.luau`, `check_fortress_layout.luau`, `check_convergence_entry.luau`, `check_tdm_rules.luau`, StyLua check, and Rojo build passed. Connected ENGAGE Studio Edit state has the synced TDM module and the fortress bake; requiring both layouts returned three Convergence objectives, zero TDM objectives, and six Red/Blue spawns per side. Selene could not start locally because its Roblox API dump was unavailable. A live ten-player TDM match and Convergence match remain unverified.
