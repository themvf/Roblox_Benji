# Editing the lobby in Roblox Studio

The lobby now has one editable source model. The saved project copy is
`assets/environment/source/Lobby.rbxm`; the game uses the validated copy at
`assets/environment/baked/Lobby.rbxm`. The generated `Workspace > Lobby` seen
while playing is temporary and should not be edited.

## Open the editing copy

1. Open the Arena place in Studio with Rojo connected.
2. In Explorer, right-click **Workspace** → **Insert** → **Import Roblox Model**, then choose
   `assets/environment/source/Lobby.rbxm`. It appears as **Lobby** with a
   `LobbySource` attribute. If it is hard to find in the viewport, select it
   and press **F** to focus the camera.
3. Save the Studio place. Keep only **one** editable Lobby model in Workspace.

The model has two folders:

- **Geometry:** the floor, PLAY hall, Armory, Alter Ego, walls, paths and scenery.
  Move, resize, recolor, or add anchored parts/models here. Parts here are
  copied into the playable lobby. Do not put scripts inside the model.
- **Authoring:** non-colliding markers for Spawns, QueuePads, Stations,
  Wayfinding and Lights. Move a marker to move its gameplay or display element.
  Resize a queue marker to resize its Red/Blue joining area. A marker's `Role`
  and `Id` attributes identify it; do not rename or duplicate those IDs.
  Edit `Title` and `Detail` attributes on wayfinding markers to change signs,
  and `Range`/`Brightness` on light markers. Marker colors control pad accent,
  sign and light colors. The kiosk's `Showcase` attribute chooses its weapon.

Queue rules such as TDM's five players per side remain in game code. Moving
`PadTDM` only moves the entry area; it cannot change the match rules.

## Test and save

Press **Play** to test your latest Workspace edit. The play session reads the
editable model directly and builds the working lobby from it. Press **Stop**,
continue moving parts, and press **Play** again. The editor copy remains in
Workspace. If a marker is missing, duplicated, outside the floor, or too small,
the Output window names the problem and the last validated lobby is used.
Queue areas also cannot overlap or rotate; move and resize their markers instead.

To store the design in the project:

1. Right-click the **editable Lobby model in Workspace** → **Save to File…**.
   Overwrite `assets/environment/source/Lobby.rbxm`.
2. In a PowerShell terminal at the project folder, run
   `.\tools\save_lobby.cmd`. It validates the source and updates the playable
   copy only if valid.
3. Rojo syncs that copy into Studio. Stop and restart Play to test the saved
   version without an editable Workspace copy. To make a standalone place file,
   run `rojo build -o arena-lobby.rbxl` after conversion.

Run `.\tools\save_lobby.cmd status` to check whether source and playable copy
match. The `new` command is only for creating the first starter; it refuses to
overwrite an existing source.

## Current limits

The editor source covers existing queue pads, signs, stations and spawns plus
arbitrary static geometry. Adding a **new game mode or queue pad ID** still
requires code so the server knows its rules. The live Play loop and device
appearance need verification in Roblox Studio; scripted source checks do not
prove the viewport result.
