# Kit selection UI — minimum product specification

Status: G1 design draft · Updated: 2026-11-08

This screen replaces the Alter Ego category in the existing lobby loadout kiosk. It
does not create a second inventory or entitlement authority. The server supplies kit
definitions, access state, rotation time, selection, and purchase eligibility; the
client renders those states and requests actions.

## 1. Player outcome

A player can answer these questions without leaving the screen:

1. Which kits can I use now?
2. What does this kit do, and what does it give up?
3. Is it a permanent starter, a temporary trial, owned, or locked?
4. Which kit will I take into the next match?
5. When does the free rotation change?

Selection saves immediately in the normal lobby. After matchmaking and map voting,
matched players receive one short Kit Lock-In window before deployment. Expiration of
that server-timed window locks the kit for the match. A rotation change never removes
a kit from a lock-in or active match.

### Selection moments

The same catalog and kit definitions serve two deliberately different experiences:

1. **Lobby Kit Browser:** a full screen opened from the persistent lobby navigation.
   It supports unhurried browsing, 3D preview, rotation information, and approved
   purchase flows. A first-time player may receive a one-time prompt to visit it after
   profile data loads; it does not force itself open on every lobby return.
2. **Pre-match Kit Lock-In:** a compact screen that opens automatically for matched
   players after the map vote closes. The saved kit is already selected, so no input
   is required. Players may change to another currently usable kit until the server
   timer expires. Purchases are disabled here.

## 2. Navigation and ownership

- Reuse the existing loadout modal, 3D preview, category strip, status line, and modal
  lifecycle in `LoadoutController`.
- Replace `AlterEgo` with `Kit` in the loadout categories.
- Keep Kit separate from cosmetic Character and weapon-skin categories.
- The authoritative selected-kit value comes from `KitService:GetSelection()`.
- The authoritative card list and access states come from `KitService:GetCatalog()`.
- The client must not infer ownership from level, product metadata, cached rotation,
  or a locally completed purchase prompt.
- Purchase confirmation uses a separate modal action. Clicking a card never initiates
  a real-money prompt.
- Lobby navigation always shows the currently selected kit and a direct `KITS` entry.
- The lock-in screen is available only to the committed roster; unrelated lobby
  players continue using the normal lobby.

## 3. Pre-match state flow

```text
Lobby browsing
    -> Queued
    -> Map voting
    -> Kit Lock-In (recommended initial hypothesis: 10 seconds)
    -> Kit snapshot and input lock
    -> Deployment/intermission
    -> Active match
    -> Results
    -> Lobby
```

- The map is known before lock-in so map-dependent kit choices are meaningful.
- Map preparation may run during lock-in when it cannot invalidate the lobby scene;
  the window should absorb loading time rather than add avoidable waiting.
- The server publishes one `LockEndsAt` timestamp. Clients display it using server
  time but do not decide when selection closes.
- A player who does nothing keeps the saved kit. A missing, expired, or invalid kit is
  replaced by the authoritative fallback starter before the countdown begins.
- Each accepted lock-in change also becomes the player's new saved lobby selection.
- Disconnects do not pause the timer. If the roster drops below the mode's start
  requirement, the match cancels through the existing queue rules.
- There are no unique-kit locks in the initial system. Duplicate and stacking rules
  are handled by gameplay, so simultaneous last-second selections cannot conflict.
- The ten-second duration is a design hypothesis. Measure abandonment, no-action
  rate, selection changes, and time-to-deployment before tuning it.

## 4. Information hierarchy

### Persistent screen regions

| Region | Required content |
| --- | --- |
| Category strip | `PRIMARY`, `SECONDARY`, `MELEE`, `UTILITY`, `KIT` |
| Catalog controls | `AVAILABLE`, `OWNED`, `ALL`; role filter is optional after the roster needs it |
| Kit cards | Name, role, access label, selected/equipped state |
| Preview | Actual kit appearance on an R15 character; plain fallback if unavailable |
| Detail | Fantasy, passive, tactical, cost/limitation, counterplay |
| Access panel | Access source, rotation remaining, price/unlock requirement if applicable |
| Primary action | `EQUIP`, `EQUIPPED`, `BUY`, or an unavailable reason |
| Status line | Saving, success, server rejection, entitlement refresh, or fallback notice |

### Card labels

Every card shows exactly one access label supplied by the server:

- `STARTER` — permanently free.
- `FREE THIS ROTATION` — temporarily usable, with remaining time in the detail view.
- `OWNED` — permanently unlocked.
- `LOCKED` — visible but not usable.
- `UNAVAILABLE` — configuration or entitlement failure; never silently treated as
  owned.

`EQUIPPED` is a separate selected-state marker and never replaces the access label.
Color reinforces these states but is not their only signal.

## 5. Responsive layout

The modal is created through `Screen.newScreenGui(..., Screen.Layers.Modal)`, uses
`Screen.autoScale` and `Screen.fitWithin`, and reflows from `Screen.onChange`.

### Desktop and console

```text
+--------------------------------------------------------------------------+
| PRIMARY  SECONDARY  MELEE  UTILITY  KIT                                  |
|--------------------------------------------------------------------------|
| AVAILABLE  OWNED  ALL                                                    |
|                                                                          |
| +-------------------------------+  +-----------------------------------+ |
| | KIT CARD GRID                 |  | 3D CHARACTER PREVIEW              | |
| | [NEUTRON] [NEUTRINO]         |  |                                   | |
| | [GRAVITON] [ACCRETOR]        |  |                                   | |
| |                               |  |                                   | |
| +-------------------------------+  +-----------------------------------+ |
| | NAME / ROLE                                                            |
| | Passive · Tactical · Limitation · Counter                              |
| | Access / rotation time                            [PRIMARY ACTION]      |
| +-----------------------------------------------------------------------+|
| Status                                                                    |
+--------------------------------------------------------------------------+
```

- Catalog and preview remain side by side.
- Console focus moves category → filter → cards → primary action → close.
- The focused card has shape/stroke emphasis in addition to color.

### Phone and narrow tablet/Split View

```text
+---------------------------------------------+
| horizontally scrollable category strip      |
| AVAILABLE  OWNED  ALL                       |
| horizontally scrollable kit cards           |
|---------------------------------------------|
| compact 3D preview                          |
| NAME · ROLE · ACCESS                        |
| Passive                                     |
| Tactical                                    |
| Limitation / counter                        |
| Rotation time                               |
| [ full-width primary action, >= 44pt ]      |
| status                                      |
+---------------------------------------------+
```

- Cards use horizontal scrolling rather than a squeezed multi-column grid.
- Details scroll vertically; the name, access state, and primary action remain
  available without requiring tiny text.
- The primary action uses `Screen.tapSize` and stays within safe insets.
- This lobby modal blocks combat input, so it does not share HUD thumb zones; it must
  still clear notches, the topbar, and the home indicator.

### Pre-match lock-in layout

The lock-in is a reduced catalog, not the full shop:

```text
+------------------------------------------------------------------+
| KIT LOCK-IN                                      DEPLOYING IN 8.4 |
| MAP: <selected map>                                                |
| [usable kit] [usable kit] [usable kit] [usable kit]               |
|                                                                   |
| <selected kit> · <role>                                           |
| Passive summary · Tactical summary · Limitation                   |
|                                              [LOCKED IN / SELECT]  |
+------------------------------------------------------------------+
```

- Show usable kits first. Locked kits may be omitted or shown after them without a
  purchase action.
- Selecting a usable card sends the server request immediately; server acceptance
  updates the locked-in marker.
- The countdown, selected kit, map name, and passive/tactical summary remain visible.
- At zero, cards and actions disable, the accepted kit remains visible briefly, and
  the screen transitions to deployment without another confirmation requirement.
- On phone, use one horizontally scrolling card row and a compact summary. Do not
  reproduce the full 3D preview or long descriptions during a short countdown.

## 6. Detail content contract

The detail panel uses authoritative kit-definition text and tuning summaries:

```text
NEUTRON                         DEFENSE · STARTER
Hold territory by resisting displacement.

PASSIVE — INERTIAL FRAME
Resist enemy knockback while contesting or defending an objective.

TACTICAL — DEGENERATE ARMOR
Brace against frontal attacks. You move slowly and cannot aim while active.

COUNTER
Flank Neutron or attack after the armor releases.
```

- The fantasy comes first; implementation terminology does not appear in player copy.
- Show a cooldown or duration only when it comes from the same authoritative tuning
  used by the server.
- Do not show vague damage bars or comparative ratings that are not derived from
  measured gameplay.
- Long names and localized text wrap; text is not shrunk below the Theme type floor.

## 7. Interaction states

| State | Primary action | Required behavior |
| --- | --- | --- |
| Usable, not selected | `EQUIP` | Request selection; show saving state; accept server result |
| Selected | `EQUIPPED` | Disabled confirmation state |
| Locked, purchasable | `BUY` | Open confirmation/details; do not equip optimistically |
| Purchase pending | `CHECKING PURCHASE...` | Disable repeat submission; allow modal close safely |
| Purchase confirmed by server | `EQUIP` | Refresh catalog and ownership before enabling |
| Trial expired | `TRIAL ENDED` | Refresh, explain fallback, select starter only through server result |
| Pre-match lock-in open | `SELECT` / `LOCKED IN` | Accept usable-kit changes until server deadline |
| Lock-in expired/in match | `MATCH LOCKED` | Disable selection; retain authoritative kit snapshot |
| Service/config failure | `UNAVAILABLE` | Preserve play through an authoritative starter fallback |

Card selection changes the preview and detail only. It does not equip the kit until
the player activates `EQUIP` and the server accepts it.

## 8. Preview and presentation

- Preview the actual saved kit visual, not unrelated concept art.
- If the visual asset is pending, show a labeled `VISUAL IN DEVELOPMENT` fallback;
  gameplay availability and visual readiness are separate states.
- Preview neutral idle and tactical-active presentation through an explicit preview
  control; never auto-loop loud audio or flashing effects.
- Keep weapons separate unless a kit tactical owns a specific tool.
- Team readability treatment appears in the preview, with a Red/Blue toggle optional
  for art review.
- Reduced-effects preference disables preview orbit and repeated VFX.

## 9. Rotation and purchase presentation

- The catalog identifies the two global rotating kits without implying ownership.
- Rotation time uses one server-provided end timestamp and a clear timezone-independent
  countdown such as `FREE FOR 2D 04H`.
- Owned kits retain `OWNED` while in rotation; the global rotation still contains the
  same two kits for everyone.
- Price, currency, and purchase mechanism remain pending until the economy decision is
  approved. The UI supports the state without inventing a price.
- A purchase confirmation states that the unlock is permanent and that kits are
  sidegrades, not upgrades.
- Receipt success is not inferred from a closed platform prompt; refresh from the
  server before showing ownership.
- Purchases and platform prompts are disabled during pre-match lock-in. The short
  competitive countdown is not a sales surface.

## 10. Theme and accessibility

- Add a `Theme.Slot.Kit` token when implementation replaces `AlterEgo`; do not add
  controller-local colors.
- Use `Theme.Color` surfaces/status tokens and the four-step `Theme.Type` ramp.
- Text-bearing panels use `Theme.Transparency.Panel` and pass contrast over a bright
  backdrop.
- Ownership, rotation, selection, role, cooldown, and lock state all include text or
  shape cues; color alone is insufficient.
- Every touch target is at least 44pt after scaling.
- Console focus is visible, ordered, and recoverable after a catalog refresh.
- Closing the modal restores the previous CoreGui and input state.

## 11. Minimum acceptance evidence

| ID | Requirement | Evidence |
| --- | --- | --- |
| KUI-01 | Player can distinguish Starter, Trial, Owned, Locked, and Equipped without relying on color | Captures of every state |
| KUI-02 | Server rejection cannot produce a false equipped or owned state | Client/server rejection tests |
| KUI-03 | Rotation expiry falls back safely without changing an active match | Two-client expiry scenario |
| KUI-04 | Phone, iPad landscape/Split View, desktop, and console layouts remain usable | Named-device captures and focus test |
| KUI-05 | Kit name, passive, tactical, limitation, counter, and primary action remain readable | Long-content test on smallest viewport |
| KUI-06 | Preview uses final saved asset or declares its pending state honestly | Preview-to-asset evidence |
| KUI-07 | Equip, close, reopen, respawn, queue lock, lobby return, and second match retain authoritative selection | Lifecycle test record |
| KUI-08 | Purchase prompt cancellation, delay, duplicate response, and confirmed receipt are handled without double grant | Test-product receipt evidence before real products |
| KUI-09 | No raw `ScreenGui`, local UI colors, unsafe edge positioning, or sub-44pt touch action is introduced | Code review and UI audit output |
| KUI-10 | Saved kit is preselected, no input is required, accepted changes lock at the server deadline, and late requests are rejected | Timed two-client lock-in test |
| KUI-11 | Map vote, lock-in, map preparation, deployment, cancellation, and lobby return occur once in the intended order | State-transition evidence |

Implementation remains pending until `KitService` exposes the authoritative catalog,
selection, access reasons, rotation end time, match kit snapshot, and lock-in deadline.
A mock catalog may be used for visual layout review, but it is not evidence that
ownership, rotation, lock-in, or purchases work.

