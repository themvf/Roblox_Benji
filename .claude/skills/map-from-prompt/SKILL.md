---
name: map-from-prompt
description: Design and build a new Convergence map from a one-line description with no check-ins along the way (description -> design data -> generated source -> converted map -> measured lanes, chokes and sightlines -> plan and preview renders). Use whenever the user asks for a new map by theme or setting, e.g. "make a map in a penthouse" or "I want a shipyard map". Not for editing a map built by hand in Studio.
---

# Map from a prompt, hands-off

The user names a setting. You design the layout, build it, measure it, revise it until the
measurements pass, and come back once with a plan, preview renders and the numbers. Do not
ask them to choose lane positions, door widths or cover placement along the way.

Read the `roblox-map-building` skill first for the map rules, and
[GAME_BUILD_WORKFLOW.md](../../../GAME_BUILD_WORKFLOW.md) for the design packet every new map
needs. `Penthouse` is the worked example: `assets/environment/source/Penthouse.design.luau`
and `docs/design/penthouse/`.

## What this produces, and what it does not

A fair, walkable, themed **blockout** that passes the converter and the measurements. It is
not a finished map: nothing here playtests it, lights it in Roblox or dresses it with props.
Say so in the report.

Good fits: three-lane arenas made of rooms, platforms, ramps and cover. Poor fits: organic
terrain, dense multi-storey interiors, and layouts whose balance is not a mirror. For those,
say what you can build and what you cannot before starting.

## What you decide without asking

| Decision | Rule |
|---|---|
| Name | PascalCase from the setting; check `assets/environment/source/` and `src/shared/Maps/` |
| Size | 250-300 studs between spawns, 160-200 across, unless told otherwise |
| Structure | mirrored across x = 0 (Blue west, Red east); three lanes spread across z; one objective per lane on the centre line |
| Dressing | the two halves differ only by a look's `east` table and by non-collidable landmarks |
| Vantage | one raised position per side, two ways up, seeing one objective |

## The design principles, as things to build

- **Three lanes with different characters**: one open with long views, one central and
  contested, one close-quarters. Join them with connectors at least twice per side.
- **Chokes with a way round**: a doorway or gap is a choke; name each in `measure.chokes`.
- **Controlled lines of fire**: apply the door rule. Every doorway gets a full-height screen
  wider than itself about 10 studs behind it, on at least one side and on both for a spawn
  exit. Doors on a regular grid line up diagonally; the Penthouse's first draft had a
  215-stud line through five of them, and moving doors only opened new alignments.
- **Stairs and big props as blockers**: fill under a stair landing so the stair is one mass.
- **Spawn protection**: no door looks straight at the pads; side exits open into an L.
- **Landmarks**: one distinct thing per area, plus one outside landmark per side.
- Keep every wall and block 2 studs or thicker, on even coordinates (the measuring grid).

## The run

1. **Write the design** as `assets/environment/source/<Name>.design.luau`: looks, parts for
   the west half (`box`, `cover`, `wall` with `doors`, `ramp`, `light`), objectives, Blue
   spawns, bounds, and `measure` (lanes with waypoints, chokes, vantages, targets, views).
   Write `<Name>.presentation.lua` beside it (copy the Penthouse's and change the mood).
2. **Generate and convert**: `lune run tools/map_generate.luau <Name>`, then
   `bash tools/save_map.sh <Name>`. Fix every error the converter prints.
3. **Measure**: `lune run tools/measure_map.luau <Name>`, then `python tools/map_plan.py <Name>`
   and Read `docs/design/<name>/plan.png`. The red lines are the longest lines of fire.
4. **Revise the design, not the output**, and repeat 2-3. Typical fixes: a screen behind a
   door, a block lengthened to cut a diagonal, a passage widened. Prefer a rule over a patch:
   if the same kind of failure returns twice, change the structure. Eight rounds, then stop
   and report what still fails.
5. **Gates**: `lune run tools/check_maps.luau`, `check_bake`, `check_map_authoring`,
   `check_live_map`. Another map's failure is not yours to fix; name it and move on.
6. **Preview**: `python tools/map_views.py <Name>` (about 3 minutes) and Read `views.png`.
   Move a view that looks at a wall from a stud away.
7. **Design packet**: `docs/design/<name>/design-packet.md` from the template, with the
   measured numbers, what is Decided, Hypothesis and Unknown, and the Studio steps still owed.

## Every block is something

A block with no identity is a design fault, not a placeholder. When you add a cover block,
say what it is in this setting before you place it: `shell = { asset = "hedge", pieces = 3 }`
with the asset described under `assets` (`is` = what it becomes, `want` = the brief for
`asset-from-prompt`), or `becomes = "..."` with `finish = true` for architecture that stays a
block and gets a material. Floors, walls, stairs and rails are `structure = true`.

- If you cannot name what a block would be in the setting, the block does not belong there.
  Solve the sightline another way: move a door, bend the route, use a real room feature.
- Prefer a few models repeated (`pieces` tiles one along a long block) over many one-offs, and
  keep the blocks that share a model the same depth and height.
- `lune run tools/map_generate.luau <Name>` prints every undecided block; the count must be
  zero before you report. `python tools/map_blocks.py <Name>` writes `blocks.png` (the plan,
  numbered and coloured by status) and `blocks.md` (the table, and the models still to make
  with the size each must fill). Send `blocks.png` with the report.

## Props

Props are a second pass, after the blockout measures clean. They are drawn by uploaded model
id with no collision, so they never change what was measured.

- List models under `assets` in the design: `name = { id = <Roblox model id>, glb = "<export>" }`.
  Reuse what is already uploaded first (the package's `HANDOFF.md` has the id); make new ones
  with the `asset-from-prompt` skill.
- A standalone prop goes in `props`: `{ name, asset, at = {x, y, z}, fit, box }`. `at` is the
  point it stands on, `fit` the length of its longer ground side in studs.
- Furniture that is cover is a **shell**: add `shell = { asset = "sofa", yaw = 90 }` to the
  cover block. The block keeps its collision and turns invisible; the model is drawn over it.
  Make the block match the model's proportions (the export's size is in its `review/export.json`),
  then re-measure, because the block is what players and bullets hit.
- An asset with a `glb` but no `id` is not placed in game, but `map_views.py` still draws it,
  so the art can be judged before it is uploaded. Uploading needs the user's approval.
- The generator writes prop markers (Authoring > Props, `Role = "Prop"`) into the source; the
  converter turns them into the map's `Decor` list. Asset ids are text attributes: a number
  attribute cannot hold one.
- Count triangles: every instance of a prop costs its full triangle count.

## What you bring back

One message:
- `plan.png` and `views.png`, sent as files
- travel times, narrowest lane widths, worst choke detour, longest line of fire
- what the measurements cannot tell (fun, pacing, weapon balance) and what was not checked
  (Studio, bots, glass against bullets, sprint and jetpack routes)
- the next step that is theirs: Play in Studio with `/explore <Name>`, then `/map <Name>`

Do not add the map to a rotation, commit, or upload anything unless asked.
