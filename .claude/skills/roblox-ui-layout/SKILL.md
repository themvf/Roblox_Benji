---
name: roblox-ui-layout
description: Build or edit any on-screen UI in this project (HUDs, meters, touch buttons, modals, world-space billboards) so it is correct on phone, iPad, desktop and console. Holds the device/safe-area rules, the Screen module API, the reserved-zone map and the QA gate. Use whenever adding or moving a ScreenGui, BillboardGui, HUD element, on-screen button or panel.
---

# Roblox UI layout (this project)

Every screen in this game is authored once and has to read on a 375 px-tall phone in landscape, a 12.9" iPad
(including Split View), a 4K desktop window and a TV. The rules below are what `src/client/UI/Screen.lua`
exists to enforce. Read that module before writing UI code; it is short and commented.

The failure it was written for: HUD panels authored as fixed `UDim2.fromOffset` sizes at desktop dimensions
stack on top of each other and on top of the crosshair on a phone, and anything pinned to a screen edge
disappears under an iPhone notch, the Dynamic Island or the home indicator.

## The Screen module

```lua
local Screen = require(script.Parent.Parent.UI.Screen)   -- from src/client/Controllers/*
```

- `Screen.get()` -> `{ Class, Scale, Viewport, Touch, Insets = {Top,Bottom,Left,Right,TopbarLead},
  Aim, ThumbLeft, ThumbRight }`. `Class` is `Phone` / `Tablet` / `Desktop` / `Console`.
- `Screen.onChange(fn)` runs `fn(state)` now and on every rotation, Split View resize, window resize and
  input-device change. Returns an unsubscribe function. **All positioning goes in here**, never in a
  one-shot at build time.
- `Screen.newScreenGui(name, layer)` — the only way to make a `ScreenGui`. Sets
  `ScreenInsets = DeviceSafeInsets`, `ResetOnSpawn = false` and a `DisplayOrder` from `Screen.Layers`.
- `Screen.autoScale(frame [, multiplier])` — attaches a `UIScale` that tracks the device.
- `Screen.fitWithin(frame, maxScaleX, maxScaleY)` — a `UISizeConstraint` capped to the viewport.
- `Screen.tapSize(designPx)` — scaled size for a tap target, floored at `Screen.MIN_TAP` (44pt) on touch.
- `Screen.isTouch()`, `Screen.overlaps(rect, zone)`, `Screen.audit(instance, label)` (dev warning when an
  element lands in a reserved zone).

`Screen.Layers` is the single DisplayOrder table: `Hud 2, Objective 4, Meter 6, Touch 8, Scoreboard 15,
Recap 18, Celebration 20, Modal 30`. Never hard-code a DisplayOrder; add a layer here instead.

## Rules

1. **Never hand-roll a ScreenGui.** Use `Screen.newScreenGui`. Do not set `IgnoreGuiInset` — it is the legacy
   flag and fights `ScreenInsets`; `DeviceSafeInsets` already lets a modal cover the topbar while staying
   clear of a notch.
2. **Never position off a raw screen edge.** Use `state.Insets.Top/Bottom/Left/Right`. The top inset already
   includes the Roblox topbar and the notch.
3. **Fixed pixel sizes need a `UIScale`.** Author panels at desktop pixel sizes and hand them to
   `Screen.autoScale`. Large panels (scoreboard, recap) also get `Screen.fitWithin`.
   *Do not put a `UIScale` on a full-screen `Size = fromScale(1,1)` frame* — it moves the 0.5 centre line.
   Scale each panel, which scales about its own anchor.
4. **44pt minimum tap target.** Anything tapped mid-fight goes through `Screen.tapSize`.
5. **Keep out of the reserved zones:**
   - `state.Aim` (the middle ~40% of the screen) during play — that is the crosshair and the fight.
     Banners go above it, meters below or to the side.
   - `state.ThumbLeft` on touch — Roblox's movement thumbstick.
   - `state.ThumbRight` on touch — Roblox's jump button and the Weapons Kit fire button.
   - The bottom-centre strip on touch — the backpack hotbar, and it sits on the player's own character.
   The free strips on every device are: top-centre (one stack only), the left edge between the topbar and
   the thumbstick, and the right edge above the jump cluster.
6. **One owner per strip.** Only one HUD may claim the top-centre stack at a time (Convergence owns it
   during a round; `HudController`'s round state hides itself then). If two HUDs want the same strip, one
   of them moves or hides.
7. **Stack with a `UIListLayout`, not with hand-computed offsets**, wherever elements appear and disappear
   (the touch action column) — otherwise a hidden button leaves a hole.
8. **World-space `BillboardGui` sizes go in scale (studs), not offset (pixels).** An offset-sized billboard
   draws the same size at 300 studs as at 10, so every label in the map ends up stacked over the HUD at full
   size. Give it a `MaxDistance` short enough that the whole map is not labelled at once
   (zone signs 250, pickups 90).
9. **Device class comes from `Screen`, not from `UserInputService` directly.** A laptop with a touchscreen is
   a Desktop; an iPad with a Magic Keyboard is still a Tablet. `Tuning.Debug_ForceTouchUi` forces the touch
   HUD on in Studio.

## QA gate for any UI change

1. Studio device emulator, all four: iPhone (small, notched, landscape), iPad (landscape **and** Split View),
   a 1920x1080 desktop window, and one resize while the game is running.
2. `Tuning.Debug_ForceTouchUi = true` on desktop to check the touch layout without a device.
3. Rotate / resize mid-match and confirm every panel re-anchors — nothing may need a respawn to look right.
4. Confirm no element overlaps the crosshair, the thumbstick, the jump button or the hotbar. `Screen.audit`
   warns for a named element if you are unsure.
5. Then the usual: `stylua src && selene src && rojo build -o /tmp/arena.rbxl`, zero warnings.
