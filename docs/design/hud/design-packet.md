# In-match HUD, Rivals-style — design packet

Status: implemented, awaiting Studio device QA and icon upload.

## 1. Identity and intent

- **Problem (playtest, 2026-10-10):** the HUD was cluttered and hard to read. It was all text,
  full of key-hint sentences ("MUTATION READY  press Q", "E GroundSlam 3.1", "1  EQUIPPED"),
  and it had no health or ammo readout of its own.
- **Reference:** Rivals. One score bar at the top, then health, ammo and loadout at the bottom
  centre. Icons carry the meaning and key numbers stay small.
- **Non-goals:** the lobby, loadout, scoreboard, recap and celebration screens. A kill feed is a
  separate follow-up.

## 2. Game-mode questions

Not applicable: no rules change. Duel and Convergence share every element. Convergence keeps
its own top bar and zone chips, and the Duel score bar steps aside for it.

## 3. Map questions

Not applicable.

## 4. Player storyboard

1. **Lobby or intermission:** one status line at the top, e.g. "NEXT MAP  SNOW FORTRESS  0:05".
2. **Duel round:** the score bar shows the red score, the clock and the blue score. Your side is
   underlined, which replaced the "RED TEAM" badge.
3. **Convergence round:** only the Convergence bar and zone chips show. This fixes the duplicate
   clock.
4. **Picking something up:** a notice under the bar with an icon and a few words, e.g. "SPEED"
   with a bolt.
5. **Bottom centre:**
   - Health bar with the number on it, and "12 / 30" ammo beside it.
   - Holding the jetpack swaps ammo for a fuel bar.
   - Weapon slots underneath: icon only, small key number on keyboard, held weapon outlined.
6. **Mutation (desktop):** a round power icon left of the slots fills up and pulses when ready.
   While mutated it drains with the time left, and three ability icons with cooldown shades
   appear right of the slots.
7. **Touch:** the same state on the existing action buttons, now icons plus a number. There is
   also a SCOPE toggle for scoped weapons.

## 5. Visual and interaction contract

- **Icons:** `assets/ui/icons/*.png`, drawn by `tools/ui/draw_icons.py`. They are white and
  tinted in game, and resolved through `src/client/UI/Icons.lua`, which shows a short word
  until the upload ids are filled in.
- **One owner per strip:**

  | Strip | Owner |
  |---|---|
  | Top centre | `HudController` (Duel and status) or `ConvergenceController` (its rounds) |
  | Notice line | `HudController:Notify`, seated under whichever bar is up |
  | Bottom centre | `WeaponBarController` slots, `VitalsController` strip above them, `MutationController` docked either side (desktop) |
  | Right edge (touch) | `TouchController` |

- **Layers:** new `Screen.Layers.Hotbar = 3`. The weapon bar used to hard-code 12.
- **Theme tokens throughout.** The only `Color3.fromRGB` left in these controllers is
  ViewportFrame lighting.
- **No instruction sentences on screen.** Keycaps are keyboard-only and hidden on touch.

## 6. Reuse and ownership contract

| Element | Owner |
|---|---|
| Score bar, status, notices | `HudController` |
| Convergence bar | `ConvergenceController`. `ShowBanner` is kept as an API and now calls `HudController:Notify`, so Duel shows these notices too. |
| Health, ammo, fuel | `VitalsController`. Disables the CoreGui health bar. |
| Weapon slots | `WeaponBarController` |
| Mutation dock (desktop) | `MutationController` |
| Touch buttons | `TouchController` |
| Removed | `TeamIdentityController` |

## 7. Acceptance and evidence

- [x] stylua, selene, every lune gate, and `rojo build` pass.
- [ ] Icons uploaded and ids entered in `Icons.IDS`.
- [ ] Studio device QA (roblox-ui-layout skill): iPhone landscape, iPad and Split View, 1080p
  desktop, a resize mid-match, and `Debug_ForceTouchUi`.
- [ ] Bright-sky contrast check on Snow Fortress.
- [ ] Duel: score bar, notices, health and ammo.
- [ ] Convergence: a single clock, and the notice line under the zone chips.

## 8. Gates and handoff

Pending: the device QA above and the icon upload. Known follow-ups: a kill feed, and
reload-state feedback on the ammo count.
