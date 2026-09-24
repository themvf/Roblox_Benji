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

## While editing

Never edit anything under `ServerStorage` directly. Rojo owns those instances and
overwrites them from disk, so changes there are silently lost. Workspace is yours.
