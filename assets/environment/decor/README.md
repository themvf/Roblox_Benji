# Map decor

One `.rbxmx` per map, arranged in Studio, committed as a model. Rojo maps this folder to
`ServerStorage.MapDecor`, and `MapService` clones the matching file's children into
`workspace.Map.Decor` whenever that map builds.

**Nothing here is code, and that is the point.** Placing scenery used to mean editing Lua
coordinates, which meant a commit, a sync and a server restart for every rock. Here it
means moving a rock with the move tool.

## Authoring

1. Play or Run the map so there is something to place against.
2. Arrange scenery in Studio: drag from the Toolbox, duplicate, rotate, scale.
3. Put it all under one Folder named after the map, e.g. `SnowFortress`.
4. Right-click that Folder → **Save to File** → overwrite `assets/environment/decor/<Map>.rbxmx`.
5. Commit the `.rbxmx`.

`MapService` forces `Anchored` on every part and changes nothing else. Collision is left
exactly as authored, because Studio is the authoring tool and what was set there is the
intent.

## What is and is not checked

Decor is exempt from the fairness rules in `Validate`. Scenery does not have to mirror, and
a rock on one side is not a balance problem.

`tools/check_decor.luau` audits one thing: **collidable** decor must clear the map's zip
lines and launch arcs by 6 studs. A designer in the viewport cannot see a cable's flight
path or the shape of a launch arc, and a solid part left under one stops a player
mid-route. Non-collidable decor is not checked at all.

The gate runs in CI. It has been tested in both directions -- a collidable part planted on
the northeast zip's ground endpoint fails with the distance named.

## Where the line is

| | Lives in | Reviewed | Gated |
| --- | --- | --- | --- |
| Floors, walls, cover, routes, objectives | `src/shared/Maps/<Map>.lua` | yes | fully |
| Props placed by asset id | the map's `Decor` list | lightly | collision vs routes |
| Scenery arranged in Studio | `<Map>.rbxmx`, here | no | collision vs routes |

If a piece of scenery is meant to be cover a player can rely on, it does not belong here.
Author it as a block in the map file, where the gates can see its shape and the x-mirror
rules apply.

## Diffs

`.rbxmx` is XML and its diffs are not readable. That is an accepted cost for decor and the
reason gameplay geometry stays in Lua: a wall's history has to be legible, a rock's does
not. Expect to review these files by looking at the map, not the diff.
