# White Sniper pickup

This package prepares `Weapons/White Sniper.glb` as the player-held Snow Fortress
sniper pickup. The source is a one-metre-long textured rifle. The export is scaled
to about 5.5 studs long and split into eight mesh sections, each at or below
9,500 triangles, with two embedded PNG textures. Studio import must use Stud
units, then verify the size and appearance before using it as a Tool visual.

## Rebuild and verify

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.3\blender.exe' --factory-startup -b --python-exit-code 1 --python tools/blender/build_white_sniper.py
python tools/check_white_sniper.py
```

The editable Blender file is `source/WhiteSniper.blend`. The builder script is
authoritative; changes made only to the blend file will be overwritten. The
delivery model is `exports/WhiteSniper.glb`. `review/side.png`, `front.png`, and
`rear.png` are renders of that exported GLB, not the source scan.

The Studio import is preserved in `source/WhiteSniperImported.rbxmx` and
`source/WhiteSniperImported.rbxm`. To reproduce the Tool after changing the
Studio import, run:

```powershell
python tools/extract_white_sniper_import.py
lune run tools/build_weapons.luau
rojo build -o $env:TEMP\white-sniper-check.rbxl
```

`studio_import.json` records the uploaded mesh and texture IDs. The weapon
builder welds those eight sections into the generated WhiteSniper Tool and
hides the kit's old shape while retaining its firing attachments.

## Pickup placement and behavior

The active Snow Fortress map (`MyMapPublic`) and its TDM copy (`MyMapTDM`)
use two WhiteSniper pickups. The older `SnowFortress.lua` map remains a legacy
map with its original kit Snipers.
Each reads a marker part from `Workspace.WhiteSniperSpawns` if present:
`BlueOutpost` and `RedOutpost`. Move these parts in Studio Edit mode and save
the place. The centre of the part is the pickup pad location. The default
coordinates remain in `src/shared/Maps/MyMapPublic.lua` if a marker is absent.
`SetupSpawnMarkers.luau` can recreate missing markers without moving existing
ones. The server hides the markers during play and shows the pickup pads instead.

The WhiteSniper is pickup-only, never a loadout selection. Its shot base damage
is 90% of the target's maximum health (including a headshot); Brace can reduce
the actual damage. A carrier keeps it until death. The 24-second respawn starts
when that carrier dies, or leaves the server, and can be tuned with
`ReplicatedStorage.Tuning.WhiteSniperRespawnSeconds` in Studio.

The active rifle Tool is now saved in ENGAGE at
`ReplicatedStorage.StudioWeaponTools.WhiteSniper`. Select its `Configuration`
Value objects to change ammo, damage fraction, and other Tool settings in
Studio Properties, then save the place. Rojo excludes only the generated
`assets/weapons/tools/WhiteSniper.rbxm` from sync and preserves the Studio
Tool. The old Studio duplicate is archived under
`ServerStorage.LegacyWeaponTools.WhiteSniperPreDetach`, and a local backup is
`source/WhiteSniperToolPreDetach.rbxm`. A fresh Rojo-only place build does not
include the Studio-owned Tool; use the saved ENGAGE place or insert the backup
when creating a new place. The builder command above remains available to
regenerate a candidate rifle, but it does not replace the Studio-owned Tool.

Private Studio tests verified collection in both modes, removal on death, the
24-second return, the 90% damage callback, and that a Tool equipped by
PickupService uses the Studio-owned configuration. A clear view of the held
gun, real firing and aiming behavior, and publication remain separate.
