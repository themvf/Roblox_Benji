# Making a Convergence map

You build the map in Studio and press Play to try it. There's no code to edit and no
command to run while you build.

## The loop

**Build → Play → Stop → build more.**

### Once per map: get a map into your place

In a terminal opened at the project folder (PowerShell), run:

    .\tools\save_map.cmd new MyMap

In Studio, right-click **Workspace** in the Explorer, choose **Insert from File…**, and pick
`assets\environment\source\MyMap.rbxm`. You now have **MyMap — EDITABLE** in Workspace:

    MyMap — EDITABLE
      Ground          the floor. Resize it, add to it or replace it.
      Geometry        EVERYTHING you add goes in here
      Authoring       markers: objectives, spawns, boundary. Move them freely.

Press **Ctrl+S**. The map now lives in your place, so it's there every time you open Studio.

### Build

Use Studio's own tools: Move, Scale, Rotate, Ctrl+D to duplicate, Ctrl+Z to undo.

- **Add pieces:** drag them onto **Geometry** in the Explorer. This works for pieces from
  `ServerStorage > MapKit` (copy, then **Paste Into** Geometry) and for Toolbox models.
  Anything left loose in Workspace is **not part of the map**. Play leaves it out and
  lists it in the Output window.
- **Objectives:** move the amber cylinders and rest the bottom of each one on a floor.
  To change the capture area, select `Capture` inside an objective and use Scale. The
  name players see is the **Label** attribute (Properties > Attributes).
- **Spawns:** move the blue and red pads. Ctrl+D adds one.
- **Boundary:** select `Authoring > Bounds` in the Explorer, then Move or Scale it. It's
  locked, so it won't catch viewport clicks. If no handles appear, untick **Locked** first.
- **Toolbox models often contain scripts.** Delete any script inside a piece, because
  it would run in the game.
- Leave the whole map where it is. Don't move or turn the entire MyMap model.

### Play

Press **Play**. You land **on your map**, exactly as it is in the viewport. You don't need
to save or convert first. Check the Output window:

- `playing MyMap straight from Workspace` means it's working.
- `MyMap can't be played yet` is followed by a plain-English list of problems, such as
  a spawn floating in the air or a missing objective. Each one names the object and
  says how to fix it. You're put in the lobby until they're fixed.
- `loose in Workspace` lists pieces that aren't inside Geometry.

While playing:

- Type `/lobby` in chat to go to the lobby. From there, step on the **PRACTICE** pad to
  play a Convergence match on your map. Add bots with `/bots 5`.
- Falling or resetting puts you back on the map.

Press **Stop**, keep building, and press Play again. Save the place (Ctrl+S) whenever
you like.

## Keeping a map in the project

The map is safe in your place file. To store it in the project, so it's in git, can be
shared, and can later go into the public rotation, save it and convert it:

1. Right-click **MyMap — EDITABLE**, choose **Save to File…**, and overwrite
   `assets\environment\source\MyMap.rbxm`.
2. Run:

       .\tools\save_map.cmd MyMap

   This runs the same checks as Play, then writes the files the game uses without Studio.
   Or ask Claude to "save MyMap".

Other commands, all run the same way:

| Command | What it does |
| --- | --- |
| `.\tools\save_map.cmd status` | Shows whether each stored map matches its saved file |
| `.\tools\save_map.cmd restore MyMap` | Lists earlier saved versions. Add a number to bring one back. |
| `.\tools\save_map.cmd duplicate MyMap Map2` | Copies a map under a new name |
| `.\tools\save_map.cmd MyMap --commit "message"` | Stores the map and commits just its files. It never pushes. |

In Git Bash, `bash tools/save_map.sh ...` does the same. In PowerShell, plain `bash`
starts WSL, which can't run it.

## Sky, lighting and terrain

These come from `assets\environment\source\MyMap.presentation.lua`, which is created the
first time you store the map. Play uses the stored choices, or defaults if you haven't
stored the map yet. Positions never go in that file; they come only from the markers.

## Design tips (suggestions, not rules)

- Give every objective more than one way in.
- Keep spawn exits out of the enemy's direct line of sight.
- Compare how long each team takes to reach each objective.
- Don't let one high perch see all three objectives.
- Any objective can host the final fight, so play a finish on each of them.
- Get movement and fights working before adding dense decoration.

## What gets checked

Every map needs exactly three objectives with unique IDs, and at least two of them
finale-eligible. Both teams need spawn pads. Spawns and objectives must sit on a floor,
inside the boundary, not inside a wall and not under the terrain. Nothing may be tilted
or rotated in a way the game can't use. No scripts may be inside pieces, and the map must
pass the shared map rules. A small part count is fine, and missing scenery never blocks
anything. Collision is checked with each part's bounding box, so walk unusual meshes
to be sure.

## Files

| File | What it is | Edit it? |
| --- | --- | --- |
| `assets/environment/source/<Name>.rbxm` | the stored editable map | yes, in Studio |
| `assets/environment/source/<Name>.presentation.lua` | sky, lighting, terrain | optional |
| `assets/environment/baked/<Name>.rbxm` | generated playable copy | never |
| `src/shared/Maps/<Name>.lua` | generated positions and settings | never |
