# Editable lobby model handoff

Updated: 2026-11-20 · Stage: Faction Islands built into the source and playable copy; offline gates pass; not yet played in Studio, not committed, not published.

## 2026-11-20: Faction Islands

The user approved the Faction Islands concept ("Build it"):
`docs/design/lobby-experience/hub-concept/factions.py`, page with the art direction:
https://claude.ai/artifact/RrBcZtUhdCH1daDBfL5DZu. It replaced the walk-in hub in this file.

- Layout: a neutral spine of floating islands (arrival -> pads -> PLAY gate) over the void, and one
  island per faction off it: Forge Union = ARMORY (loadout kiosk), Coherence Institute = ALTER EGO
  (the concept said KITS; the game's name for that room is Alter Ego), Kade Dynamics = SHOP (sign
  only), the Ferrymen = THE LEDGER (the leaderboard). Coloured bridges are the wayfinding.
- Rebuild: `python docs/design/lobby-experience/hub-concept/export_factions.py`, then
  `lune run tools/lobbyauthor/faction_islands.luau`, then `lune run tools/lobby.luau convert`.
  Like the hub builder it replaces Geometry wholesale; after the first Studio edit, edit in
  Studio instead. The walk-in hub source is backed up at
  `.mapbuild/lobby-faction-islands/Lobby-before-factions.rbxm`.
- The exporter adds the art direction's Roblox materials and sign fonts per part, invisible
  barriers (15 studs) along every island rim and bridge, and the station positions.
- Geometry `Floor` is now an invisible, non-colliding footprint over the spine: the marker reader
  needs one part holding every spawn and pad. Nobody stands on it.
- Stations turn: the Board and Kiosk markers may rotate about the vertical (LobbyAuthoring reads
  `yaw`; MapService turns the leaderboard wall, the kiosk and its showcase). Pads still may not.
- Falls: `Maps/Lobby.lua` `FallRecovery` is a box under the islands; `MapService:WatchLobbyFalls`
  puts anyone outside a match who drops into it back on an arrival spawn. No penalty.
- Wayfinding: the islands name themselves in surface lettering facing arrival; the only billboard
  left is PLAY over the pad-island end of the first bridge. The Armory/AlterEgo/Shop markers were
  removed.
- Effects: five ParticleEmitters (weld sparks and chimney smoke on the Forge, two frost vents on
  the Institute, rocket steam on Kade), built-in textures, low rates.
- Size: about 2,150 geometry parts, 285 of them invisible (barriers, light anchors).
- Evidence: `check_lobby_authoring` (now also checks station yaw and the fall box),
  `lobby.luau status` (match), `check_live_map`, `check_maps`, `check_ui`, `check_movement`,
  StyLua, Selene and `rojo build` pass. `hub-concept/built/factions/*.png` are Blender renders of
  the playable copy (`dump_built.luau` + `render_built.py -- factions`): placement and
  orientation only, not Roblox lighting or materials.
- Open: play it in Studio (walk times, the fall recovery, whether the barriers are
  enough, sign fonts and materials under Roblox lighting, lighting at y 400); there is no
  dark-matter skybox yet, so the void is whatever sky the place has; the Shop is a sign only;
  kit plinths are empty; pledge flags are blank.

## 2026-11-18: walk-in hub

The user approved the fifth hub concept ("Yes, build it"):
`docs/design/lobby-experience/hub-concept/` (page: https://claude.ai/artifact/Wv5XzYwsPfkFjAmKZ9ijJr).
It replaced the old 500 x 500 hall in this file.

- Rebuild: `python docs/design/lobby-experience/hub-concept/export_parts.py`, then
  `lune run tools/lobbyauthor/walk_in_hub.luau`, then `lune run tools/lobby.luau convert`.
  The builder replaces Geometry wholesale, so it overwrites Studio edits; after the first
  Studio edit, edit in Studio instead of rerunning it. The pre-hub source is backed up at
  `.mapbuild/lobby-walk-in-hub/Lobby-before-hub.rbxm`.
- Marker positions live in `src/shared/Maps/Lobby.lua` (spawns, pads, board, kiosk,
  signs, lights); the builder moves the markers there. A new `Shop` sign marker was added.
  The stone columns, purple columns and canister are the lobby's own models, moved.
- `MapService` wayfinding signs now draw to 170 studs (was 110), since PLAY is about 125
  studs from arrival.
- Evidence: `check_lobby_authoring`, `lobby.luau status` (match), `check_live_map`,
  `check_maps`, StyLua, Selene and `rojo build` pass. `hub-concept/built/*.jpg` are Blender
  renders of the playable copy (`dump_built.luau` + `render_built.py`), showing placement
  and orientation only.
- Studio note: a `Workspace.Lobby` editing copy saved in the place file wins over the saved
  copy on Play. Delete it and re-import this file, or Play shows the old hall.
- Open: play it in Studio (walk times, PLAY sign distance, wall gaps, lighting at y 400);
  the kiosk and leaderboard face north because markers cannot rotate; kit plinths are empty;
  the shop is a sign only; pads keep gameplay sizes.

## Earlier stage (2026-11-10)

Central arrival and floor mist saved, Studio Play tested, and published to ENGAGE as place version 308; live-client review pending.

## Approved direction

The user approved a Studio-editable lobby source, using the same Build → Play →
Stop loop as authored maps. The current rectangular PLAY hall, including TDM,
is the seed layout. Queue rules stay in server code. No external art or GLB was
supplied; this is a project-native Roblox model, so external-asset appraisal,
textures, upload IDs and visual render stages are not applicable.

## Files and ownership

- `Lobby.rbxm`: editable source. Insert it into Workspace and save edits back
  to this file. The `Geometry` and `Authoring` folders are the source of truth.
- `../baked/Lobby.rbxm`: validated playable copy. Do not edit directly.
- `../../../src/shared/LobbyAuthoring.lua`: one marker reader for Studio Play
  and saved runtime loading.
- `../../../tools/save_lobby.cmd`: validation and conversion entry point.
- `../../../docs/design/lobby-experience/EDITING.md`: designer instructions.

## Evidence

- `lune run tools/check_lobby_authoring.luau`: passes source/bake freshness,
  movable TDM marker, editable sign text, and invalid overlap/off-floor/rotation.
- `lune run tools/check_live_map.luau`: passes; the editable lobby survives the
  map cleanup stage until its own reader consumes it.
- `selene src`: 0 errors/warnings; `rojo build`: passes and includes the Lobby
  model in `ServerStorage.BakedMaps`.
- On 2026-11-10 the editable ENGAGE `Workspace.Lobby.Geometry.Cannister`
  contains `BlueContainmentCanister` at pivot `(-2, 400, 984)`, approximately
  31 studs high. The source and baked `Lobby.rbxm` files were saved after
  anchoring twelve previously unanchored stone-column decoration pieces.
  `tools/save_lobby.cmd status`, `check_lobby_authoring`, and `check_live_map`
  passed. A fresh Play test without the editable Workspace lobby loaded the
  canister from `ServerStorage.BakedMaps.Lobby` with its blue vapor emitter.
  The asset-specific evidence is in
  `../../models/lobby-containment-canister/HANDOFF.md` and
  `../../models/lobby-containment-canister/review/lobby-placed-play.jpg`.
- The 2026-11-10 source and baked files replaced prior versions only after
  backups were written under `.mapbuild/lobby-containment-canister/20261110-181014/`.
  The source remains the editable authority; the playable copy is generated.
  Published-game appearance and device presentation remain unverified.
- On 2026-11-10 the five spawn markers moved from the back row near local Z 42–46
  to the central arrival area at local X -14 through 14, Z 10–14. The editable
  source was backed up at `.mapbuild/lobby-center-mist/Lobby-before-center-arrival.rbxm`,
  then converted to the playable baked copy. `MapService` now creates 15
  non-colliding floor mist emitters around those spawns using Roblox's built-in
  smoke texture. The effect is confined to the lobby; match maps retain their
  own spawns and atmosphere. The connected ENGAGE editable lobby markers were
  moved to match the saved source.
- `tools/save_lobby.cmd status`, `check_lobby_authoring.luau`, StyLua check,
  and Rojo build passed. In a fresh ENGAGE Studio Play, the player spawned at
  a central marker and `Workspace.Lobby.ArrivalMist` contained all 15 emitters.
  A viewport capture showed white mist across the floor around the arrival
  area. The first blue vapor texture was rejected after a visual test because
  it read as tall turquoise plumes; the final built-in smoke texture was
  checked in a second fresh Play. The user has not yet approved the appearance.
- On 2026-11-10 the user explicitly approved publishing the full current ENGAGE
  revision, including the other synced map and gameplay changes. The connected
  Studio instance identified itself as ENGAGE, place ID `121549226728648`.
  Immediately before publication, Studio held matching central spawn markers in
  both `Workspace.Lobby` and `ServerStorage.BakedMaps.Lobby`, and the synced
  `Maps.Lobby` source declared the final built-in smoke texture at rate 5.
  Studio's File > Publish action reported `Published new changes in "ENGAGE" to
  Roblox`, `Place published`, and offered publish notes for version `v308`.
  This verifies the Studio publication result; it does not verify a fresh
  Roblox client or broader audience access settings.

## Next action

Join the published ENGAGE place as a fresh Roblox client to check the central
spawn and mist at normal and lower graphics quality, then test performance with
several players in the lobby. Review the placed canister's 31-stud size and
position from normal player paths. To change the placement, edit the Workspace
source, Save to File over `Lobby.rbxm`, rerun `tools/save_lobby.cmd`, restart
Play, and publish a new revision after review.
