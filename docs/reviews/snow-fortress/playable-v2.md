# Snow Fortress playable v2 — 2026-09-20

Implemented in game source, built with Rojo, and verified in the running Rojo source snapshot. Not published and not yet verified through a Studio match. This is a geometry/integration pass, not final art approval.

## What changed

- Opposite six-slot exterior spawns at x ±210, split staging exits, external safety boundary.
- Separate Gate Courtyard, Service Yard and centre-line Command Keep capture districts.
- Continuous fortress walls, three 32-stud ground gates per side, towers, buttresses and snow caps.
- Two outposts, each with two stair approaches; four contextual zip lines; two central-entry launch pads; four grapples terminating on ledges, including a stair-accessible keep balcony.
- Traversal service now reads the map's `From`/`To` schema. Keyboard interaction is G, avoiding the mutation ability on E; native proximity prompts support touch and gamepad.
- Development project forces SnowFortress for the next match. Clear `Debug_ForceMap` to restore voting.

## Source connection corrected

The prior Rojo process on localhost:34872 returned older source with neither the new revision nor the named districts. Replaced that serve process with Rojo 7.7.0 rooted at this workspace. Verified its source snapshot contains `exterior-fortress-v2`, `Gate Courtyard`, and the traversal field integration.

Studio must reconnect the Rojo plugin after the server replacement and Stop/Start the playtest to reload cached modules. No claim that the currently open Studio session has synchronized or restarted.

Build: `builds/SnowFortress-playable-v2.rbxl`. Runtime Output identifier: `[MapBuild] SnowFortress / exterior-fortress-v2`.

## Verification

Passed: StyLua, Selene, layout regression, finale regression, baseline regression, 42 skins, eight celebrations, API dump freshness, unchanged generated weapon assets and Rojo build. Layout regression checks actual block intersections along sampled zip-line and ballistic launch paths in addition to spacing, bounds and inventory. These static checks do not simulate avatar physics, terrain, mobile controls or bots.

Pending: full 6v6 Studio match, travel-time balance (gate/yard retain a small westward offset), ground route navigation and outpost visibility, launch success rate, grapple collision behavior, mobile readability, recovery logs, render/performance captures, announcer audio assets and final art pass. The concept sketch is illustrative; measured geometry in source is authoritative for this prototype.
