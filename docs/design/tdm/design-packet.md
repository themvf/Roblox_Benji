# Team Deathmatch 5v5 — design packet

Status: implemented and gated, awaiting a multiplayer playtest.

## 1. Identity and intent

- **Request (2026-10-10):** Snow Fortress should also play as Team Deathmatch.
- **Decisions:**
  - TDM is 5v5 only.
  - Duel 1v1 and 2v2 stay as they are: elimination rounds, already on Snow Fortress.
  - Win by kill target with a time cap.
  - No bots for now.
- **Non-goals:**
  - bot fill
  - joining a match in progress
  - a per-player kill feed
  - TDM-specific spawn layouts

## 2. Game-mode questions

| Question | Answer |
|---|---|
| Teams | Red and Blue, 5 each. A match can start at 3v3 after a 30 s fill wait, like Convergence. |
| Lives | Infinite. Respawn after 3 s at a team spawn, with a 2 s ForceField. |
| Score | +1 per enemy kill. Team kills, self kills and deaths with no killer score nothing. |
| End | First team to 50 kills, or the higher score at 10:00. Equal at the cap is a draw: no podium. |
| Leavers | A team emptying aborts the match, as in Duel. |
| Map pool | `Config.TDMMaps = { "SnowFortress" }`, picked by the lobby map vote. |
| Tuning | All of the above as `TDM_*` attributes, clamped in `Config.GetTDM()`. |

## 3. Map questions

Snow Fortress needs no new geometry:
- Red and Blue spawns already exist on opposite sides.
- Convergence objectives are not built for TDM, so the zones are inert.
- The pickups, launch pads and outposts serve TDM as they are.

## 4. Player storyboard

1. In the lobby, step onto **TEAM DEATHMATCH 5v5** at the back of the gate, behind Convergence.
   The pad shows "Pick a side (3-5 per team)".
2. Both sides reach 3 and the countdown runs, or both reach 5 and the match starts at once.
   The map vote runs, then the intermission shows the vista.
3. The Duel score bar shows Red kills, the 10:00 clock and Blue kills, with your side
   underlined.
4. On death, you respawn at your side after 3 s, with a shield for 2 s.
5. The first team to 50 wins and the podium plays, or the higher score wins at the cap.

## 5. Visual and interaction contract

TDM reuses the Duel HUD (`HudController`). Any non-Convergence round shows the score bar,
and every kill re-broadcasts `Round` with the score and the time left.

## 6. Reuse and ownership contract

| Piece | Owner |
|---|---|
| Match flow, respawn, scoring | `TDMService` (new) |
| Pure rules | `Shared/TDM` |
| Match lock | `RoundService.Busy`, shared by every mode |
| Spawns | `MapService:PlaceCharacter` |
| Kill credit | `LastHitBy` from damage code |
| Pad sizes | `MapService` from `Config.GetTDM()` |
| Fill wait | `QueueService` |
| Map pool | `MapVoteService` |

## 7. Acceptance and evidence

- [x] `tools/check_tdm.luau` (in CI) covers:
  - the rules: scoring, target, cap and draw
  - the Tuning clamps
  - the lobby, queue and vote wiring
- [x] stylua, selene, every gate, and `rojo build` pass.
- [ ] Studio multiplayer test (Test > Clients and Servers, 6+ players):
  - fill wait
  - respawn and spawn shield
  - score bar updates
  - the win at the target
  - an abort when a team leaves

## 8. Gates and handoff

Pending: the multiplayer test. Follow-ups:
- bot fill for 5v5
- TDM spawn spread on larger maps
- a kill feed
