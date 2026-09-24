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
| `GUIDE` | bounds, objective circles, spawn pads, centre. **Delete before saving** |
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

Spawn pads, the safety barrier and the outer boundary walls. `MapService` draws all three
from the layout data on every build, so a copy in the kit would be a duplicate sitting on
top of the real one.



## Starting a new map

1. Clear Workspace, drag pieces out of `ServerStorage.MapKit`, assemble.
2. Group the lot under one Folder.
3. Right-click it → **Save to File** → `assets/environment/baked/<Name>.rbxm`
4. Add `src/shared/Maps/<Name>.lua` with the data and `RequiresBake = true`:
   `Name`, `Size`, `WallHeight`, `Spawns`, `Objectives`, `Bounds`, `SafePoints`,
   `Barrier`, `Terrain`, `Palette`, `Environment`, and empty `Center`/`Mirrored`.
5. `lune run tools/check_maps.luau` and `tools/check_bake.luau`.

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
