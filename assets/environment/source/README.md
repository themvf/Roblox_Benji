# Making a Convergence map

You build the map in Studio. One command turns it into the playable map. You don't
need to edit any code, and you don't need to ask anyone for help.

Everything below happens in Studio or in a terminal opened at the project folder.
In the terminal, `bash tools/save_map.sh ...` works in Git Bash. In a plain Windows
terminal, use `tools\save_map.cmd ...` with the same words after it.

## The loop

**Open → place pieces and move markers → Save to File → convert → Play → repeat.**

### 1. Start a map (once per map)

    bash tools/save_map.sh new TestMap

This creates `assets/environment/source/TestMap.rbxm`, a blank map containing a floor,
objectives A, B and C, six spawn pads per team and a map boundary. It also builds the
first playable version, so the map works straight away.

To start from a map you already have instead:

    bash tools/save_map.sh duplicate TestMap SecondMap

Map names use letters and digits and start with a capital. The command refuses a name
that is already taken, so you can't overwrite a map by accident.

### 2. Open it in Studio

Keep `rojo serve` running as usual. In the **Explorer**, right-click **Workspace**, choose
**Insert from File…**, and pick `assets/environment/source/TestMap.rbxm`.

You now have **`TestMap — EDITABLE`** in Workspace. **This is the only copy you edit.**
Leave `ServerStorage.BakedMaps` alone. That folder holds the generated playable copy,
and Rojo overwrites anything you change there.

    TestMap — EDITABLE
      Ground          the floor. Resize it, add to it or replace it.
      Geometry        put buildings, cover and scenery here
      Authoring       markers. Move them, but they never appear in the game.
        Objectives    A, B, C
        Spawns        Blue, Red
        Bounds        the map boundary
        Helpers       a NORTH sign

### 3. Build and move things

Use Studio's own tools (Move, Rotate, Scale, Ctrl+D to duplicate, Ctrl+Z to undo).

- **Add a piece.** Open `ServerStorage > MapKit`, select a piece and press Ctrl+C. Then
  select `Geometry` and paste it with **Paste Into** (Ctrl+Shift+V). Move it where you want
  it. Anything you add must end up **inside Geometry**. A piece left loose in Workspace
  isn't saved with the map.
- **Move an objective.** Click its amber cylinder and move it. The bottom of the cylinder
  is the capture point, so rest it on the floor. The pole and label move with it.
  - To change the capture area, select `Capture` inside the objective in the Explorer and
    use Scale. The width is the capture radius. The height is how far above the floor a
    player still counts. The same distance also counts *below* the floor, so an objective
    right above another floor can pick up players standing on it. The converter warns
    you when that happens.
  - The name players see is the objective's **Label** attribute (Properties > Attributes).
    Change it freely. **ObjectiveId** (A, B, C) is the objective's identity. Leave it alone
    unless you mean to create a different objective.
  - **FinaleEligible** controls whether the match can finish on that objective. The
    template makes all three eligible, and at least two must stay eligible.
- **Move spawns.** Drag the pads. Add one with Ctrl+D. Each team needs at least one pad,
  and pads need 6 studs between them.
- **Change the boundary.** Select `Authoring > Bounds` in the Explorer. It's locked so it
  doesn't catch clicks in the viewport. Then use Move or Scale. If handles don't appear,
  untick **Locked** in Properties, make the change, and tick it again. Players who leave
  the boundary, or fall below it, are sent back to a spawn or objective. Set the
  **TeleportOnExit** attribute to false to make leaving it lethal instead, as it is on
  public maps.
- **Move the whole map.** Moving or turning the entire `TestMap — EDITABLE` model is
  harmless. The playable map is always built around the model's own pivot.

What each kind of piece does in the game:

| You want | Set on the part |
| --- | --- |
| Decoration players pass through | CanCollide off (CanQuery off too, so it doesn't stop bullets) |
| Cover that blocks movement and shots | CanCollide on |
| Something to walk on | CanCollide on, with a floor that's solid where players stand |

New imported models (GLB) go through asset intake first
([docs/design/ASSET_INTAKE_AND_LESSONS.md](../../../docs/design/ASSET_INTAKE_AND_LESSONS.md)).
Once a model is prepared, you can reuse it like any kit piece without asking anyone.

### 4. Save

Right-click **`TestMap — EDITABLE`** and choose **Save to File…**. Save over
`assets/environment/source/TestMap.rbxm`. Always save the whole model, including the
markers.

You can save as often as you like, even when the map is half-finished or broken. Saving
the source never changes the game. That only happens in step 5.

### 5. Convert

    bash tools/save_map.sh TestMap

It prints one of these:

- **Playable version UPDATED: src-xxxxxxxxxx** is followed by what changed. You're done.
- **Playable version NOT updated** is followed by a list of problems. Each one names the
  object and says how to fix it, for example *"Blue spawn "Spawn 3" is outside the Map
  Boundary. Move the spawn inside, or enlarge the boundary."* The game keeps the last
  working version, and your source file stays as you saved it. Fix the problems, save,
  and run the command again.

Warnings don't block the conversion. They point out things worth a look, like balance
or a missing wall at the edge.

### 6. Test

In Studio, **Stop** and then **Play** (F5). A map only reloads when a test starts. When
the test starts, the editable copy in Workspace is hidden automatically. In the game chat:

- `/explore TestMap` builds the map and puts you on a spawn pad, so you can walk around
  and check the scale, floors, stairs and collision. Reset or die to return to the lobby.
- `/map TestMap`, then step on the **PRACTICE** pad, plays a Convergence match on it.
  Add bots with `/bots 5`. Use `/map off` to go back to normal map choice.

The game shows **DRAFT TestMap · build src-xxxxxxxxxx** when it loads your map, and the
Output window prints the same text. If that build number differs from the one step 5
printed, the game is still running an older version. Make sure `rojo serve` is
running, then Stop and Play again.

Drafts never appear in the public map vote or rotation. Testing a draft doesn't publish it.

### 7. Go back to step 3

The editable copy in Workspace still has all its markers. Keep editing it, save, and
convert. If you closed Studio, open the map again as in step 2.

## Checking and recovering

    bash tools/save_map.sh status

This lists every map and says whether its playable version matches your latest save.
**STALE** means you saved after the last successful conversion, or someone edited the
generated files by hand.

    bash tools/save_map.sh restore TestMap        list earlier versions
    bash tools/save_map.sh restore TestMap 12     bring version 12 back

The converter keeps a copy of your source every time you run it: the last 30 versions,
on this computer only. After restoring, delete the old copy from Workspace, open the map
again (step 2), and convert.

## Keeping your work in git (optional)

Converting never commits or pushes anything. When you want a checkpoint:

    bash tools/save_map.sh TestMap --commit "Move objective A onto the bridge"

This commits exactly this map's four files: the source, the presentation file, the
playable copy and the generated data. It leaves anything else you have staged alone,
and it doesn't push. Publishing is a separate step.

## Sky, lighting and terrain

`assets/environment/source/TestMap.presentation.lua` is created with defaults the first
time you convert. You can edit it: sky, time of day, fog, and the terrain material under
the map. The converter never overwrites it. Positions don't go in this file. They come
from the markers only.

## Files

| File | What it is | Edit it? |
| --- | --- | --- |
| `assets/environment/source/<Name>.rbxm` | the editable map, with markers | yes, in Studio |
| `assets/environment/source/<Name>.presentation.lua` | sky, lighting, terrain | optional |
| `assets/environment/baked/<Name>.rbxm` | the playable copy, with no markers | never, it's regenerated |
| `src/shared/Maps/<Name>.lua` | every position and setting the game uses | never, it's regenerated |

## Design tips (suggestions, not rules)

- Give every objective more than one way in.
- Keep spawn exits out of the enemy's direct line of sight.
- Compare how long each team takes to reach each objective. A layout that looks
  symmetrical doesn't guarantee that.
- Don't let one high perch see all three objectives.
- Any objective can host the final fight, so play a finish on each of them.
- Get movement and fights working before adding dense decoration.

## What the converter checks

It checks that the map has exactly three objectives with unique IDs, and that at least
two of them are finale-eligible. Both teams need spawn pads. Spawns and objectives must
sit on a floor, inside the boundary, and not inside a wall. Nothing tilted or rotated
may be impossible to turn into game data: a leaning capture cylinder or a turned
boundary is refused. No marker can leak into the playable copy. Finally, the map must
pass the shared map rules that every map passes.

A small part count is fine, and missing cover or scenery never blocks conversion.
Collision is checked with each part's bounding box, so an unusual imported mesh can
still behave differently in play. Walk it with `/explore`.
