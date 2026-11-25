# Lobby: ordered build plan to a state-of-the-art standard

Status: plan only, nothing here is built unless a row says so · Author: Claude (no independent review) · 2026-11-16

This is the ordered list of work, not a new specification. It sits on top of the
[design packet](design-packet.md), the [fix specification](LOBBY_AND_SCREENS_FIX_SPEC.md), the
[kit screen spec](../kits/KIT_SELECTION_UI_SPEC.md) and the
[store foundation packet](../store-foundation/design-packet.md). Their decisions stand. Where this
plan needs a requirement they already hold, it names the ID instead of restating it.

## Where the lobby is today

| Area | State | Evidence |
| --- | --- | --- |
| Walkable lobby world, Studio-editable, published as place version 308 | Built | `Lobby.HANDOFF.md` |
| PLAY / LOADOUT / CUSTOMIZE / PROFILE bar, Play drawer, shop and More drawers | Built by hand in `LobbyNavigationController` (raw widgets, proportional sizing, no UIScale) | Source |
| One server queue shared by menu and pads; queue-time editing; match lock | Built | `QueueService`, packet section 2 |
| Catalog templates (Browser, LockIn, Track), components, offline gate | Built, on made-up data, not used by the lobby | `tools/check_ui.luau`, 58 passed |
| Every acceptance row: LOB-01 to 08, ARR-01 to 05, LFX-01 to 10 | Unverified | The three documents above |
| Kit service, store service, ownership, prices, pass, daily rewards | Not built | Store packet: "Nothing is implemented" |
| Visual target (mockup, reference, art direction for screens) | Does not exist | - |
| Player accessibility settings (reduced motion, background transparency, text size) | Not read anywhere in `src` | grep |
| Funnel analytics for the lobby | Not built | grep |
| Card art, kit portraits, icons, UI sound, UI motion | Do not exist | - |

The largest gaps are not code. They are: no approved look, no art on any card, and no row of
acceptance evidence. A lobby cannot be called state of the art on gate results alone.

## What "state of the art" means here (the bar each phase is judged against)

1. A new player presses Play within five seconds and is in a match within two presses (LFX-01, LFX-04).
2. The player's own character and equipped gear are the centre of the screen.
3. Queue state follows the player everywhere and never lies (LFX-05).
4. Every screen works by touch, mouse and controller, on a small phone through a TV (LFX-03, LFX-07).
5. Every press answers with sound, motion or a state change inside 100 ms; every server wait shows a pending state.
6. The player's Roblox accessibility settings are honoured.
7. Nothing is sold in the first match, nothing sold changes a gameplay number, every price comes from Roblox (store packet).
8. Each step of the path from spawn to second match is measured, so the weakest step is known.

## Progress, 2026-11-17

| Step | State |
| --- | --- |
| B1 reference comparison | Written: [REFERENCE_LOBBIES.md](REFERENCE_LOBBIES.md). Public sources settle what each game has, not where it sits on screen; layout questions still need hands-on captures |
| B2 mockups | Drawn: [mockups/lobby-directions.html](mockups/lobby-directions.html), two directions, five screens, desktop and phone. Concept only |
| B3 pick a direction | **Decided 2026-11-17 (user): A, walk-in hub.** The look was not named separately; slate and gold as drawn is assumed until the user says otherwise |
| Walk-in hub layout | **Approved 2026-11-18 (user), fifth concept.** Built into `assets/environment/source/Lobby.rbxm` and its playable copy by `tools/lobbyauthor/walk_in_hub.luau`; offline gates pass; not played in Studio. See `assets/environment/source/Lobby.HANDOFF.md` |
| C1 shell | Built: `src/client/UI/LobbyShell.lua`. Offline gate only; not seen in Studio; not wired into the lobby |
| C2 one Back rule | Built: `src/client/UI/ScreenStack.lua` |
| C3 accessibility settings | Built into `Components`. Text growth is tested with an assumed 1.3x; Roblox does not publish the real multipliers |
| C4 loading, empty, error, offline | Built: `Components.state`, `CatalogScreen:SetLoad` |

`lune run tools/check_ui.luau`: 97 passed. Preview the shell with `Tuning.Debug_UiGallery = "Shell"`.

## The steps

Each step names who can do it. "Hands-off" means it needs no input from the user. "Studio" means
someone must look at the running game. "User" means a product choice or an approval.

### Phase A. Know what we have (before changing anything)

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| A1 | Fix the Snow Fortress turret-template failure that makes matches fall back to Arena (fix spec B-07) | Hands-off, then Studio | A queued match loads the chosen map |
| A2 | Capture the current lobby: all five spawns, Play drawer, loadout, shop drawer, on small phone, iPad, Split View, 1287x665, 1920x1080, controller | Studio | Captures stored with place version and viewport |
| A3 | Run the existing unverified rows (LOB, ARR, LFX) and mark each pass or fail | Studio, two clients | Each row has evidence or a defect |
| A4 | Add funnel events: spawn, Play opened, queue joined, match started, match finished, requeued, and one per shop step later | Hands-off | Events fire in a Studio test; dashboards need a published place |

### Phase B. Decide the look once

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| B1 | Collect reference captures of four or five current top Roblox shooters' lobbies (home, play, loadout, shop, pass) and note what each does | Hands-off (public video and images) | A one-page comparison, structure only, no copied art |
| B2 | Mock up five screens at phone and desktop size: home, play, kit browser, shop, pass. Two visual directions at most | Hands-off | Static mockups the user can open |
| B3 | Pick a direction | **User, one decision** | Direction recorded in the packet as the art target (G1) |
| B4 | Turn the direction into tokens: surface levels, corner and stroke rules, icon set, rarity treatment, motion timings, UI sounds. Extend `Theme`; add `UI/Motion` and `UI/Sound` | Hands-off | `check_ui` covers the new tokens |

### Phase C. The lobby shell (the frame every screen opens inside)

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| C1 | New template `Shell`: persistent nav (Play dominant, four to six destinations), level and currency readout, queue strip, notification dots, one toast stack | Hands-off | Gate builds it on seven sizes |
| C2 | One screen stack with a single Back rule (Escape, B, on-screen) and focus restored on return | Hands-off | Gate test: open three deep, back three times, focus lands where it left |
| C3 | Honour `GuiService.ReducedMotionEnabled`, `PreferredTransparency` and `PreferredTextSize` inside `Components`, so every screen gets them | Hands-off | Gate builds each template at Largest text and opaque panels with no overflow |
| C4 | Loading, empty, error and offline states as shared components | Hands-off | Each template has a gate case for all four |
| C5 | Controller glyph hints and a visible selection highlight | Hands-off, then Studio with a gamepad | Every action shows its button on console |
| C6 | Move the Play drawer, More and Profile off hand-built widgets onto the shell; delete `LobbyCatalog.lua` | Hands-off | `ui_baseline.json` count for `LobbyNavigationController` reaches zero |
| C7 | Stop the nav colliding with the hotbar, topbar and thumb zones (LFX-03) | Hands-off, then Studio | A2 captures repeated, no overlap |

### Phase D. Arrival and the character stage

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| D1 | Spawn facing and first camera so the Play gate is in frame from all five spawns (LFX-02) | Studio edit of `Lobby.rbxm` | Five captures |
| D2 | Character stage: when a menu is open, the camera frames the player's avatar holding the equipped weapon and skin; it updates on equip | Hands-off, then Studio | Equip changes what the stage shows |
| D3 | The dark-matter focal object in the gate, with a low-effects version (fix spec section 5) | Asset pipeline (one intake round with the user) | Approved in Studio |
| D4 | Cut arrival signage to one primary and two secondary labels; first-use hint that disappears after the first queue (B-04) | Hands-off, then Studio | LFX-09 capture |
| D5 | Lobby performance budget on a low-end phone, measured with the existing perf probe | Studio or device | Budget recorded and met |

### Phase E. Play flow

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| E1 | Mode cards with art, one-line purpose, live counts and a clear disabled reason | Hands-off (art from B4) | LFX-04 |
| E2 | Queue strip everywhere: mode, team, elapsed time, Leave; survives opening any screen | Hands-off | LFX-05 with two clients |
| E3 | Party: read Roblox party membership so friends land on one team; invite button through Roblox's invite prompt | Hands-off, then published place | Two friends queue together |
| E4 | Match found: a short committed state, then the kit lock-in screen (template exists), then load | Needs the kit service (F2) | Kit spec acceptance |
| E5 | After a match: results, what was earned, one Play Again press back into the queue | Hands-off | Second match in two presses |

### Phase F. The services the screens read from

The screens are thin on purpose. These are the real work and each has, or needs, its own packet.

| # | Step | Who | Done when |
| --- | --- | --- | --- |
| F1 | Store foundation: catalog, entitlements, receipts, `check_store` | Hands-off for code; **user** for the five open choices in the store packet and for creating products in Creator Hub | SF-01 to SF-19 |
| F2 | Kit service: access, selection, rotation, match snapshot, lock-in deadline | Hands-off; needs more than one kit to exist | Kit spec acceptance |
| F3 | `CatalogService`: the one place that turns catalog, ownership and rotation into `CatalogItem` records | Hands-off | Gallery data replaced; `MockCatalog` used only by the gate |
| F4 | Progression read model: level, XP to next, currencies, unclaimed counts for the dots | Hands-off | Shell readouts are live |
| F5 | Daily contract and daily reward (store packet idea 10) | Hands-off after F1 | Own packet |

### Phase G. The remaining screens (each is records plus a thirty-line controller)

| # | Step | Depends on |
| --- | --- | --- |
| G1 | Loadout and Customize rebuilt on `Components`, with weapon stats shown as bars and a live 3D preview | C, D2 |
| G2 | Kit browser | F2, F3 |
| G3 | Shop: featured, daily rotation with timers, bundles; Roblox purchase prompt; pending and delayed states | F1, F3 |
| G4 | Season pass track with Claim All | F1 and a pass packet |
| G5 | Profile and leaderboards: stats, match history, rank on the existing boards | F4 |
| G6 | Settings: sensitivity, field of view, audio levels, reduced effects, controller layout | none |
| G7 | News panel and code redemption | F1 for codes |

### Phase H. First session

| # | Step | Who |
| --- | --- | --- |
| H1 | First join: highlight Play, dim the rest, no shop or pass prompt until one match is finished (`Store_FirstPromptAfterMatches`) | Hands-off |
| H2 | Practice range reachable in one press while queued (packet G4 item) | Own map slice |
| H3 | Contextual hints shown once each: loadout after the first death, kits after the first match | Hands-off |

### Phase I. Feel

| # | Step | Who |
| --- | --- | --- |
| I1 | Press, hover, select, equip, unlock and claim each get motion and sound from B4; all of it off under reduced motion | Hands-off, judged in Studio |
| I2 | Lobby music and ambience with a mix that ducks under UI sound | Needs audio assets |
| I3 | Custom loading screen and lobby-to-match transition | Hands-off, judged in Studio |
| I4 | Haptics on controller and phone for confirm and match found | Hands-off, judged on a device |

### Phase J. Proof

| # | Step | Who |
| --- | --- | --- |
| J1 | Gate growth: Shell and every new screen in `check_ui`; text 30% longer; Largest text size; every state | Hands-off |
| J2 | Device pass on the roblox-ui-layout QA list, with captures, for every screen | Studio |
| J3 | Full controller pass, no mouse | Studio with a gamepad |
| J4 | Fresh-player test: ten players, time to Play, time to first match (LFX-01) | **User** to arrange |
| J5 | Policy: paid random items hidden where restricted; odds shown; nothing typed as a price | Hands-off plus published place |
| J6 | Localisation: no text in images; strings in one table | Hands-off |
| J7 | After launch: read the funnel from A4, fix the worst step, repeat | Ongoing |

## Order and what can run at once

```text
A1 A4 ──┐
B1 B2 ──┼─> B3 (user) ─> B4 ─> C ─> G1, E1, E2, E5, H, I ─> J
F1 F3 F4┘                         └> D2
F2 (needs kits) ───────────────────> E4, G2
A2 A3, D1, D5 and every "judged in Studio" row need a Studio session
```

Hands-off now, with no answer needed: A1, A4, B1, B2, C1 to C4, F1 code, F3, F4.

## What only the user can supply

1. One pick between the mockup directions (B3).
2. The five open store choices (store packet section 8).
3. Studio sessions or screenshots for every Studio row, or permission for me to drive Studio.
4. Products and passes created in Creator Hub; any publish.
5. Approval of each generated asset before upload (D3, card art).
6. Ten fresh players for J4.

## Risks

- **Art is the long pole.** Card art, kit portraits and icons do not exist. Text-only cards will not read as finished however good the layout is.
- **Kits.** One alter ego exists. A kit browser with one kit is not a feature.
- **Unverified base.** Twenty-three acceptance rows are unverified. Building on top before A3 risks polishing defects in.
- **Shared files.** `LobbyNavigationController`, `HudController` and `TuningService` are edited by other sessions.

## Sources checked for this plan

- Roblox accessibility settings and the three `GuiService` properties: <https://create.roblox.com/docs/production/publishing/accessibility>
- Roblox onboarding guidance and funnel events: <https://create.roblox.com/docs/production/game-design/onboarding>, <https://create.roblox.com/docs/production/game-design/onboarding-techniques>, <https://create.roblox.com/docs/production/analytics/funnel-events>
- Invite prompts and party data: <https://create.roblox.com/docs/production/promotion/invite-prompts>, <https://create.roblox.com/docs/reference/engine/classes/SocialService>

Genre conventions in "the bar" come from general knowledge of Roblox shooters, not from captures.
B1 replaces that with evidence.
