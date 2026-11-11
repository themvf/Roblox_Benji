# Editable lobby model handoff

Updated: 2026-11-10 · Stage: central arrival and floor mist saved, Studio Play tested, and published to ENGAGE as place version 308; live-client review pending.

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
