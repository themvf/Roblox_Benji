# Lobby professionalism pass — 2026-11-09

## Goal

At first spawn, a new player recognizes **Play** in five seconds, understands where the world gate leads, can choose a mode and team, and can leave a queue. A returning player can prepare without blocking that route. The lobby should feel like Convergence: a restrained science-fiction staging area with one dark-matter focal point and character displays, rather than a wall of competing announcements.

## Evidence and limits

- The supplied BedWars screenshots are visual references, not screenshots of ENGAGE. Their character displays and large action buttons are useful; overlapping signs, avatars, chat, roster, and utility controls illustrate a clutter risk.
- A live ENGAGE Studio Play capture at 1287 × 665 on 2026-11-09 showed the four-action lobby bar overlapping the weapon hotbar and a downward view dominated by floor and the avatar. The spawn destination was not visible in that capture. This is one spawn and one viewport, so it does not establish every player's arrival view.
- The Play drawer's source previously put five loadout chips before mode choices. The local source now puts modes first and moves the desktop navigation above the hotbar. The connected Studio session displayed the older bar after Stop/Play, so this change still needs a fresh place or Rojo sync for visual verification.
- The Studio Output reported SnowFortress failing to build because `TurretService` found an incomplete turret template, then falling back to Arena. It also reported Studio DataStore access unavailable and a missing archived sound. These are separate runtime issues; do not attribute them to the lobby UI change.
- The kit browser, direct Kits action, server KitService, and pre-match lock-in remain design work. Do not present them as working in today's build.

## Work order

### Today: prove the core path

1. Open the freshly built `arena-lobby-today.rbxl` in Studio, or connect Rojo to this source and restart Play. Capture the first five seconds at every lobby spawn.
2. Check the focal view: visible gate, one readable **Play** action, and no UI/hotbar overlap. Adjust spawn facing and camera only after observing all spawn views. Keep the gate and physical pads as a second route to the same queues.
3. Open Play. Mode and team choices must be the first content. Join, observe queue status, Leave, and rejoin. With two clients, confirm both see matching team counts.
4. Open Loadout while queued, change one item, and verify the queue remains active. Check the item at match commitment and after return. Record where SnowFortress fallback prevents this test.
5. Repeat arrival, Play, and Leave on a small landscape phone, tablet Split View, desktop, and controller. Capture screenshots with viewport and input type. Test keyboard/controller focus and all close/back paths.

### Next visual pass

1. Give spawn one composed sightline: Convergence gate/dark-matter core as hero, mode destinations nearby, avatar or kit displays to the side. Avoid a large sign directly behind other signs.
2. Use one prominent Play control and a quieter preparation control. Move Profile and cosmetic browsing into a secondary menu once their entry path is preserved. Keep queue status and Leave persistent when searching.
3. Replace the generic instruction banner with concise contextual guidance that disappears after the first successful queue. Reduce distant billboards and nameplates in the spawn sightline.
4. Apply one shared surface, accent, type ramp, and selected/queued/locked treatment across the lobby, Play drawer, future kit browser, and pre-match screen. Use `Screen` and `Theme` for every UI change.
5. Build a functional Kits entry only after the server owns kit access, selection, rotation, and match snapshot. Two permanent starters and two rotation trials should be distinguishable by text as well as color. The saved starter should require no extra action at match start.

## Acceptance for the next review

- From every spawn, Play and the gate are visible or unambiguously indicated without rotating the camera.
- A first-time tester points to Play within five seconds; a returning tester queues within five deliberate actions.
- Navigation, hotbar, Roblox chrome, and touch controls do not overlap at the tested sizes. All core controls are at least 44 points on touch.
- Queue status, mode, team, and Leave are readable; two clients agree on counts and queue state.
- The test log separates working flows from blocked flows and names the exact place revision, viewport, device, and client count.

Current status: source layout change and local build complete; synced Studio visual review, multi-client queue test, device passes, and kit implementation pending.
