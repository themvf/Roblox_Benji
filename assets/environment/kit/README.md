# Map kit

Reusable pieces cut out of Snow Fortress, one `.rbxm` each. Rojo maps this folder to
`ServerStorage.MapKit`. Drag a piece into Workspace, put it where you want it, repeat.

Regenerate with `lune run tools/build_kit.luau`.

## Why this exists

The first version of the Studio workflow had you clone the whole 1400-instance map, edit
it in place and save the lot back. That works for moving one rock and is miserable for
anything else -- and it makes starting a *new* map impossible, because there is nothing to
start from except a copy of the old one.

A kit is the normal way to build a level: a palette of parts you assemble.

## Pieces

| Piece | What it is |
| --- | --- |
| `Ground` | the floor slab, 490 x 370, top at y 0 -- resize it to your map |
| `GUIDE` | legacy visual guide, superseded by the map template -- see below |
| `Fortress` | the whole central building, 162 x 34 x 132 studs |
| `RoofTile` | one 10x10 roof tile, all three layers |
| `IceSpike` | the ice rock, one instance |
| `CrashedHelicopter` | the wreck, 34 studs across |
| `Helipad` | deck, painted border, H and scorch |
| `SniperOutpost` | a whole outpost: walls, deck, firing windows, stair |
| `Staircase` | one 18-step stair with treads |
| `SightlineScreen` | the 66-stud screen that blocks spawn sightlines |
| `ApproachCover` | a cover block beside a launch target |
| `CeilingLamp` | lamp with its PointLight |

Every piece is recentred: horizontally on its own middle, vertically so its lowest point
is at y 0. Dropping one at a spot puts it **on** that spot, rather than at whatever world
coordinate it happened to occupy in Snow Fortress.

`SightlineScreen` and `ApproachCover` are pulled from the first bake, because both were
deleted from the map in an editing pass. Both are cover rather than scenery -- the screens
are what stops a sniper in an outpost seeing into the enemy spawn -- so keeping them here
means removing them stays a decision rather than a one-way door.

## Building a map with the kit

Kit pieces go into a map made from the Convergence template, inside its `Geometry`
folder. The template carries the objective, spawn and boundary markers that the game
reads, and one command converts it. Nobody has to write map data by hand. The full
walkthrough is [assets/environment/source/README.md](../source/README.md):

    bash tools/save_map.sh new TestMap       then Insert from File in Studio, build, Save to File
    bash tools/save_map.sh TestMap           convert and check

Copy a piece from `ServerStorage.MapKit` and use **Paste Into** on `Geometry`. Don't drag
it out of `ServerStorage` in the Explorer.

`GUIDE` is the older, visual-only version of those markers. Its positions were never
read back into anything. Don't drop it into a template map: the converter refuses a map
containing it, and so does `check_bake` if it reaches a bake.

## What is deliberately not in here

Spawn pads, the safety barrier and the outer boundary walls. `MapService` draws all three
from the layout data on every build, so a copy in the kit would be a duplicate sitting on
top of the real one.



## Saving

Maps built from the template save and convert with `bash tools/save_map.sh <Name>`. See
the walkthrough linked above. Snow Fortress predates the template: its bake in
`assets/environment/baked` is edited directly, and `bash tools/save_map.sh --all` runs
every gate over it without committing anything.

## While editing

Never edit anything under `ServerStorage` directly. Rojo owns those instances and
overwrites them from disk, so changes there are silently lost. Workspace is yours.
