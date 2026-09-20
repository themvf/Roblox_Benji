# Lobby navigation and preparation — design packet

Status: G1 In progress · Owner: Codex · Updated: 2026-09-20

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Feature identity | **Decided:** shared feature `lobby-experience`; persistent lobby navigation, queue, loadout, customization, and profile surfaces. |
| Supported play | **Decided:** every current lobby and mode. The physical Armory and team pads remain alternate entry points. |
| Player fantasy / repeatable decision | **Decided:** prepare quickly for the next fight, or explore and test equipment without configuration chores. |
| Audience and inputs | **Decided:** new and returning Roblox players on mouse/keyboard, touch, and controller. |
| Session / roster | **Not applicable:** the feature does not change match roster or duration. It must reflect each mode's current queue requirements. |
| Authorized scope | **Decided:** the supplied direction authorizes `PLAY / LOADOUT / CUSTOMIZE / PROFILE`, slot-first browsing, immediate saves, visible queue loadout, queue-time editing, and experiential previews. A progression economy and new content are out of scope. |
| Baseline | **Decided:** working tree on 2026-09-20. Baseline behavior lives in `LoadoutController`, `QueueService`, `LoadoutService`, `SkinService`, and `CelebrationService`. The tree contains unrelated local changes that must be preserved. |
| Player-visible fix | **Decided:** players no longer have to reach a kiosk or pad to prepare and queue, unrelated content is no longer shown in six simultaneous columns, and acknowledged changes persist immediately. |

## 2. Game-mode questions

- **Decided:** lobby state is `Lobby → Queued → Committed → InMatch`. Equipment changes are legal in Lobby and Queued and rejected once `InMatch` is set at commitment.
- **Decided:** PLAY joins the same server-owned queue used by physical pads; leaving a menu queue is explicit.
- **Decided:** queue-time loadout/customization changes do not remove the player from queue.
- **Decided:** the server validates slot, item, team, mode, and match state. The client only presents and requests changes.
- **Hypothesis:** freezing persisted player attributes at `Committed` and retaining the `InMatch` lock is sufficient because the queue sets commitment before starting either match service and every mutation service rejects both states. Verify with a queue/edit/start race test and respawn test.
- **Unknown:** reconnect behavior during queue. No work in this slice depends on preserving a queue across reconnect.

State diagram:

```text
Lobby ── Join(mode, team) ──> Queued ── roster ready ──> Committed ──> InMatch
  ^                              │                              │
  └────────── Leave ─────────────┘                              └── match cleanup ──> Lobby
```

## 3. Map questions

**Not applicable to geometry.** The current gate, queue pads, Armory kiosk, and Alter Ego bay remain. The Armory is preserved as a discovery/practice destination rather than a required settings location. A firing-range geometry and safe target contract are a future map slice.

## 4. Player storyboard

| Frame | Player view / visual link | Player question | Decision/action | Feedback and next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Arrival | **Implemented, capture pending:** persistent bottom navigation | What can I do? | Pick PLAY, LOADOUT, CUSTOMIZE, or PROFILE | Selected surface opens | Lobby navigation |
| 2 Prepare | **Implemented, capture pending:** five equipped slots | What am I bringing? | Select one slot | One item grid and preview appear | Loadout strip |
| 3 Equip | **Implemented, capture pending:** card + preview | Is this the item I want? | Preview, then EQUIP NOW | Card and strip say EQUIPPED; server state updates | Item card / service mutation |
| 4 Queue | **Implemented, capture pending:** Play drawer | Which mode and team? | Join Red or Blue | SEARCHING banner, counts, and current loadout remain visible | Queue card |
| 5 Queue wait | **Implemented, capture pending:** queue badge plus editor | Can I still change gear? | Open Loadout or Customize | Queue remains active; change saves immediately | Persistent navigation |
| 6 Setback | **Implemented, capture pending:** match-lock message | Why can I no longer edit? | Attempt after commitment | Server rejects; menu closes as combat begins | Match boundary |
| 7 Match | **Existing:** combat HUD | Is my selection active? | Play | Spawn inventory uses the committed attributes | Weapon service |
| 8 Return | **Implemented, capture pending:** navigation returns | What next? | Review profile or requeue | Lobby state restored | Lobby navigation |

## 5. Visual and interaction contract

- **Decided:** dark panels preserve the existing lobby language; amber means primary interaction, red/blue mean teams only.
- **Decided:** Loadout contains Primary, Secondary, Melee, Utility, and Alter Ego. Customize contains Celebrations and weapon skins.
- **Decided:** selected and equipped states use border/text plus color; locked draft skins include `COMING SOON` and remain previewable.
- **Decided:** buttons use `Activated`; Escape/Button B closes; Roblox selection focus is enabled. Minimum intended control height is 42–48 UI pixels.
- **Decided:** the layout switches from side-by-side browser/preview to stacked panes below 760 UI pixels.
- **Decided:** ReducedEffects stops continuous weapon rotation. Celebration preview plays motion locally without taking over the lobby camera.
- **Unknown:** final screen-reader behavior, localization expansion, smallest supported phone, controller glyph system, and real-device safe-area evidence. These keep G1/G3 from acceptance.

## 6. Reuse and ownership contract

| Component | Classification | Owner/path | Data/input → result | Consumers | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| Lobby navigation | **New**; no prior shared lobby shell existed | `src/client/Controllers/LobbyNavigationController.lua` | lobby/player attributes → nav, queue, profile | all lobby players | Build/lint plus device playtest pending |
| Loadout/customize browser | **Extend shared** | `src/client/Controllers/LoadoutController.lua` | options/current state → slot cards, preview, immediate equip | HUD and kiosk | Build/lint plus input tests pending |
| Queue service | **Extend shared** | `src/server/Services/QueueService.lua` | menu request or pad occupancy → one queue | PLAY UI and physical pads | Multiplayer race test pending |
| Per-slot loadout mutation | **Extend shared** | `src/server/Services/LoadoutService.lua` | slot/item → validated attribute update | Loadout UI, weapon grants | Server validation test pending |
| Celebration preview | **Extend shared** | `src/client/Controllers/CelebrationController.lua` | celebration id → local avatar motion | Customize | Runtime animation test pending |
| Match lock | **Extend shared** | loadout/skin/celebration services | mutation after `InMatch` → reject | all equipment writers | Respawn/race test pending |

## 7. Acceptance and evidence

| ID | Player-visible requirement | Test | Threshold | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| LOB-01 | Navigation is available anywhere in lobby | Spawn away from stations on mouse, touch, controller | Four actions visible/reachable within 1 s | Implemented, unverified | Source; runtime capture pending |
| LOB-02 | One weapon can be changed and queue started quickly | Cold spawn task | ≤10 s and ≤5 deliberate actions for 8/10 returning players | Implemented, unverified | Moderated test pending |
| LOB-03 | Queue survives editing | Join, open both editors, equip, observe counts | No queue cancellation before Leave/commit | Implemented, unverified | Two-client test pending |
| LOB-04 | Match commitment freezes configuration | Race final edit against start; respawn | Last acknowledged pre-commit choice spawns; every later request rejected | Implemented, unverified | Automated/runtime race test pending |
| LOB-05 | Information architecture stays separated | Inspect screens | Loadout shows exactly five gameplay slots; cosmetics live in Customize | Implemented, unverified | Runtime capture pending |
| LOB-06 | Equip is immediate | Equip and reopen | No Save/Apply/Confirm; acknowledged item remains equipped | Implemented, unverified | Runtime persistence test pending |
| LOB-07 | Preview is useful | Select weapon and celebration | 3D weapon visible; celebration motion plays on avatar | Implemented, unverified | Runtime asset test pending |
| LOB-08 | Responsive/input behavior | Small phone, tablet, desktop, controller | No clipped core action; visible focus; no focus trap | Not started | Device Simulator/physical test pending |

## 8. Gates and handoff

| Gate | Status | Evidence / decision |
| --- | --- | --- |
| G0 Baseline | Ready for review | Source paths and dirty-tree constraint recorded. StyLua, Selene, both content validators, generated weapon check, diff hygiene, and Rojo build passed on 2026-09-20. |
| G1 Design | In progress | User direction and simulated three-role review reconciled; storyboard captures and device decisions pending. |
| G2 Playability | In progress | Code slice exists; multiplayer queue/commit verification pending. |
| G3 Complete section | Not started | Needs in-engine captures and input/device evidence. |
| G4 Extension | Not started | Firing range, unlock metadata, new indicators, and broader cosmetic categories remain. |
| G5 Release candidate | Not started | Full checks and runtime evidence required. |

Next concrete task: verify LOB-01 through LOB-08 in Studio with two clients and Device Simulator. Native Studio control was unavailable in the implementation environment, so no runtime claim is made.

Dependencies / unresolved choices: progression ownership/unlock metadata; a reduced-motion settings surface; firing-range safety contract; controller glyph standard.

Changes to shared consumers needing regression: physical pad queueing, weapon grants, skin equips, celebration favorites, Alter Ego selection, respawn equipment, and match cleanup.

Decision log: 2026-09-20 — adopted “Menus are for doing; the lobby world is for playing,” separated Loadout/Customize, made queue menu and pads share one server queue, and treated `InMatch` as the current authoritative commit boundary.
