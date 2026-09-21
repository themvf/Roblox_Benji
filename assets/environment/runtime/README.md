# Live Snow Fortress entrance art

## Current revision: enclosed-fortress-v3

The ground perimeter is closed except for four ramp doors. The upper floor now has full walls, a ceiling/roof at Y=33, and interior lights. The two zip lines land above the roof beside 10x10 drop hatches centred at (-55, 33, 40) and (55, 33, -40). The four trampolines now land outside the ramp entrances; the old side launch gaps are closed. Each sniper outpost has one exterior staircase, an upper doorway, enclosed side/back walls and firing windows.

The HUD adds a team-name badge, a shorter final-objective label, a smaller touch Titan meter, and a two-column grid of wider 52-pixel-high Titan action buttons. Full mobile playtesting remains necessary. Map/layout, phase, entry, lint and Rojo checks pass, with no map warnings. The enclosed editor preview was visually inspected; source and UI synchronization were confirmed in Studio.

The sections below record the preceding facade pass.

`SnowFortress.rbxmx` contains five reusable MeshPart templates (portal, wall bay, pier, parapet, paving) with uploaded PBR maps from approved model asset `136223303527413`. Generate it with `lune run tools/build_fortress_art.luau`. Rojo packages it under `ServerStorage.EnvironmentArt.SnowFortress`; matches do not need an Open Cloud key or a runtime asset insertion request.

`src/server/FortressArt.lua` builds four portals, full-height wall bays, corner piers, parapets and deck paving whenever MapService builds SnowFortress. East/west doors retain 20-stud openings; north/south retain 30-stud openings. New walls and parapets have authored collision. Paving is visual-only and skips tiles intersecting stair openings. Stairs, objectives, spawns, ramps, voting and bots are unchanged. Other maps do not instantiate this kit. Rebuilding art replaces the previous art folder.

Verified in Studio: 282 generated parts; sampled rays across all four doorway widths and all four launch corridors are clear; collision overlap checks at both zip landings, both stairs and the keep centre are clear. The rebuilt facade was visually inspected close up using the Computer Use viewport capture. Lint, map/layout gates and Rojo build passed. Full match playtesting remains with the user. A temporary editor preview under Workspace.Map is removed by normal MapService.Build on Play; it is not the source of the live map.

Revision: `blender-facades-v2`. Restart Play and choose Snow Fortress in Convergence to test. Save/publish the updated place when ready for online players. The outposts and surrounding environment still use the existing art; this pass addresses the central fortress facade and upper deck.
