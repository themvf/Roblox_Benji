# Map kit

Reusable pieces, one `.rbxm` each. Rojo maps this folder to `ServerStorage.MapKit`. Drag a
piece into Workspace, put it where you want it, repeat.

Most were cut out of Snow Fortress, which has since been deleted as a map -- its bake is
kept at `assets/kitsource/SnowFortress.rbxm` purely so the kit stays reproducible. It is
outside the Rojo tree, so it is build input, not a map, and nothing can load it.

Regenerate with `lune run tools/build_kit.luau` (cut pieces) and
`lune run tools/build_guide.luau` (`Ground`, `Ramp`, `GUIDE`).

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
| `GUIDE` | bounds, objective circles, spawn pads, centre. **Delete before saving** |
| `Fortress` | the whole central building, 162 x 34 x 132 studs |
| `RoofTile` | one 10x10 roof tile, all three layers |
| `IceSpike` | the ice rock, one instance |
| `CrashedHelicopter` | the wreck, 34 studs across |
| `Helipad` | deck, painted border, H and scorch |
| `SniperOutpost` | a whole outpost: walls, deck, firing windows, stair |
| `Staircase` | one 18-step stair with treads |
| `Ramp` | 12 x 9 x 20 wedge, 24 degrees -- scale Y or Z to change the slope |
| `Wall` | one 2 x 8 x 10 slate wall segment, for tiling into a run |
| `WallLong` | a 54 x 8 x 2 wall in one piece |
| `BoundaryWall` | the 500-stud perimeter wall |
| `Pillar` | 3 x 13 x 3 metal support |
| `Railing` | 36-stud stair rail |
| `StoneBlock` | 7 x 15 x 6 slate block -- heavy cover |
| `SightlineScreen` | the 66-stud screen that blocks spawn sightlines |
| `ApproachCover` | a cover block beside a launch target |
| `CeilingLamp` | lamp with its PointLight |

Every piece is recentred: horizontally on its own middle, vertically so its lowest point
is at y 0. Dropping one at a spot puts it **on** that spot, rather than at whatever world
coordinate it happened to occupy in Snow Fortress.

`SightlineScreen` and `ApproachCover` were cut from the map's first bake, which was a
scratch file and never committed. `build_kit` prints `KEEP` for them and leaves the
committed `.rbxm` alone rather than failing -- which it used to do, taking the other
thirteen pieces down with it.

The last seven are plain structural blocks, added because the kit went straight from "a
500-instance building" to "a rock" with nothing in between. A map needs something to stand
on, something to hide behind and something to walk up long before it needs a fortress.
They are real pieces from a real map rather than grey boxes, so a wall placed next to the
fortress is the same slate at the same scale.

`Ramp` is the exception: Snow Fortress climbs on stairs, so there was no ramp anywhere to
copy and it is generated instead. It is also the easier of the two to use -- a staircase
only works at the rise it was built for, a ramp stretches to whatever the thing beside it
turned out to be.

## The guide

`GUIDE` is scaffolding, not map content: the bounds outline, the three objective circles at
their capture radius, both spawn lines and a centre pole. Drop it in first and everything
else has somewhere to go.

It is also how a new map's data gets written. Move the markers to where you want them,
tell me, and the positions go straight into the layout's `Objectives`, `Spawns` and
`Bounds` -- the same idea as `/mark`, at map scale.

**Delete it before saving.** `check_bake` fails a map that still contains guide markers,
because they are translucent and non-collidable, so a map carrying one looks entirely
normal until somebody asks what the glowing cylinder is.

## What is deliberately not in here

Spawn pads and the safety barrier. `MapService` draws both from the layout data on every
build, so a copy in the kit would be a duplicate sitting on top of the real one.

`BoundaryWall` is in the kit even though the barrier is not, because the two do different
jobs: the barrier is an invisible force field that stops players leaving, the wall is what
stops the eye, so the map does not read as a slab floating in sky.



## Building the current map

`Crucible` is the only map in the repo. Its bake already exists as ground plus a boundary
wall, so it loads and you can walk around it before a single piece goes down.

1. Open the place, drag `ServerStorage.BakedMaps.Crucible` into Workspace.
2. Drag in `MapKit.GUIDE` so you can see where the objectives and spawns are.
3. Assemble the kit around them.
4. **Delete the GUIDE.**
5. Right-click the `Crucible` model → **Save to File** → over
   `assets/environment/baked/Crucible.rbxm`
6. `bash tools/save_map.sh -c "what you changed"`

## Starting an additional map

1. Write `src/shared/Maps/<Name>.lua` -- copy `Crucible.lua` and change the numbers.
2. `lune run tools/build_starter_bake.luau <Name>` writes the ground-and-walls bake.
3. Add `<Name>` to `Config.Maps` / `Config.ConvergenceMaps`, and `StartupMap` to see it.
4. Then follow "Building the current map" above.

That tool refuses to overwrite an existing bake, so it cannot eat a map by being run
twice.

Geometry comes from the `.rbxm`; everything that is not geometry stays in the `.lua`.
The gates read both.

## Saving without waiting on anybody

    bash tools/save_map.sh                  gate only
    bash tools/save_map.sh -c "message"     gate, then commit and push

The first save of a NEW map needs its `.lua` written by hand -- objectives, spawns,
bounds, terrain, sky. Every save after that is self-contained: the geometry is in the
`.rbxm` and the gates read it, so there is nothing for a second person to do.

A failing gate is a to-do list, not a rejection. The map still loads.

## While editing

Never edit anything under `ServerStorage` directly. Rojo owns those instances and
overwrites them from disk, so changes there are silently lost. Workspace is yours.
