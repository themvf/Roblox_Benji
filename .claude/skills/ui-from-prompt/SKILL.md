---
name: ui-from-prompt
description: Build a catalog-style screen (kits, packs, passes, skins, a season track, a pre-match pick) from a one-line request with no check-ins along the way (request -> records -> template -> gallery -> offline gate -> report). Use whenever the user asks for a shop, browser, picker, unlock or pass screen, e.g. "add the kit browser", "make a skin shop", "we need a battle pass screen". Not for HUD elements drawn during a fight; those use roblox-ui-layout directly.
---

# A screen from a prompt, hands-off

Kits, packs, passes and skins are the same screen with different data. So a new one is three
small things, not a new 700-line controller: **records** the server sends, a **template** that
draws them, and a **controller of about thirty lines** that joins the two. Do not ask the user to
choose layouts, sizes or colours along the way; decide, record the assumptions, report once.

Read `roblox-ui-layout` first: its Screen and Theme rules still apply underneath.

## The pieces

| Piece | File | What it owns |
| --- | --- | --- |
| Record shape and rules | `src/shared/CatalogItem.lua` | fields, access labels, actions, text limits, `validate` |
| Widgets | `src/client/UI/Components.lua` | button, card, badge, tab strip, card list, detail, countdown, confirm |
| Templates | `src/client/UI/CatalogScreen.lua` | `Browser`, `LockIn`, `Track`; layout per device shape; open/close; focus |
| Lobby shell | `src/client/UI/LobbyShell.lua` | nav with one dominant PLAY, wallet, queue strip above modals, notification counts, toasts |
| Back rule | `src/client/UI/ScreenStack.lua` | `push`, `back`, `clear`; open lobby screens through it, never with a bare `:Open()` |
| Made-up data | `src/client/UI/MockCatalog.lua` | every state at once, and the longest text allowed |
| Gallery | `src/client/Controllers/UiGalleryController.lua` | `Tuning.Debug_UiGallery = "Browser" \| "LockIn" \| "Track" \| "Shell"` |
| Gate | `tools/check_ui.luau`, `tools/ui_baseline.json` | builds every template offline on seven screen sizes |

## What you decide without asking

| Decision | Rule |
| --- | --- |
| Template | browsing with no clock -> `Browser`; a timed pick before a match -> `LockIn`; tiers with free and premium rows -> `Track`. If none fits, say so before building a fourth |
| Tabs | one per `Kind` shown; a single Kind gets no tab strip |
| Copy | fantasy first, no implementation words; inside `CatalogItem.Limits` |
| States | every record has exactly one `Access` and one `Action`; `Selected` is separate |
| Where it opens | lobby only, on `Screen.Layers.Modal`; never during a fight |
| Money | never invent a price or a product id. No price yet means `Access = "ComingSoon"` |

## The run

1. **Records first.** List the items as `CatalogItem` records. If the server cannot supply them
   yet, add them to `MockCatalog` and say the screen runs on made-up data. A new field or state
   goes into `CatalogItem` with a validation rule, not into one screen.
2. **Controller.** `CatalogScreen.new({ Name, Template, Title, Tabs, OnAction, Preview })`, then
   `:SetItems(records)` and `:Open()`. `OnAction(item, action)` asks the server and, when the
   server answers, calls `:SetItems` again with what it sent back. Never edit a record on the
   client to make the screen look right: a rejected request must not leave "equipped" or "owned"
   on screen.
3. **A missing widget** goes into `Components` (with the tap height, the text floor and a
   non-colour cue built in) and into the gate's audit, so the next screen gets it too. Do not
   build it inside the controller; the baseline will fail the build if you do.
4. **Gate:** `lune run tools/check_ui.luau`. It builds the screen for a phone, a small phone,
   Split View, a tablet, a desktop, a small window and a console, and fails on a region that
   leaves the panel or overlaps another, a tap target under 44pt, text under the floor, a card
   with no access label, or a property the Roblox API does not have. Fix the template, not the
   check.
5. **Then the usual:** `stylua src && selene src && rojo build`, zero warnings.
6. **Design packet** for a new screen: `docs/design/<feature>/design-packet.md` from the template,
   with what is Decided, Hypothesis and Unknown.

## Rules the templates already enforce (do not undo them)

- Pressing a card only shows it. Equipping is the primary action; buying needs a confirmation.
- A disabled action is a readout: no handler, no controller focus.
- `LockIn` shows only usable items, never a purchase, has no close button, and switches off at
  the server's deadline. The server still decides what was locked in.
- A record that fails `CatalogItem.validate` is left out with a warning, never drawn as usable.
- Access, selection, the active tab and a reached tier each have a text or shape cue as well as
  a colour.
- Every screen is rebuilt from its state on every change and on every `Screen.onChange`.
- Box sizes come from `Components.measure` / `Components.line`, never from `TextSize` arithmetic,
  so the player's Text Size setting cannot clip a label. Surfaces use `Components.surface(...)`
  for the Background Transparency setting, and any tween takes its time from `Components.motion`.
- While content is missing a screen shows `:SetLoad("Loading" | "Empty" | "Error" | "Offline")`,
  not a blank panel or its own message.

## What the gate cannot tell you

It checks arithmetic and the API, not appearance. Not checked without Studio: real text
wrapping and fonts, spacing, the 3D preview, scrolling feel, controller navigation order, and
anything the server does. Say so in the report, and list the Studio steps still owed: the
gallery under the device emulator on an iPhone, an iPad in landscape and Split View, a
1920x1080 window and a console, with one rotation while it is open.

## What you bring back

One message: which template and records were used, what runs on made-up data, the gate result,
what was not checked, and the one Studio step that is theirs
(`ReplicatedStorage > Tuning > Debug_UiGallery`). Do not create products, set prices, commit or
publish unless asked.
