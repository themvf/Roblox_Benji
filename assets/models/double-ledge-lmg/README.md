# Double Ledge LMG mounted turret

The user-supplied `source/reference.png` is the visual target. `source/original.glb`
is the only supplied 3D source. `Weapons/Gun meshes.rbxl` is a separate collection
of older firearms and is not used by this turret.

## Intended use

This is an approximately eight-stud-high, walk-up, team-operated turret for Snow
Fortress. One is declared for Blue and one for Red in
`src/shared/Maps/SnowFortress.lua`. The two sites are rotational counterparts,
47.2 studs from their nearest spawns, with no baked collidable parts within 18
studs of either site centre in the local geometry check.

## Rebuild and local verification

From the repository root:

```powershell
python tools/build_double_ledge_lmg.py
& 'C:\Users\joshb\.rokit\tool-storage\lune-org\lune\0.10.5\lune.exe' run tools/build_double_ledge_template.luau
& 'C:\Users\joshb\.rokit\tool-storage\lune-org\lune\0.10.5\lune.exe' run tools/check_double_ledge_template.luau
```

The first builder converts the GLB's two embedded WebP textures to named 1024px
PNG maps, decimates the 281,613-triangle scan to 70,403 triangles, and separates
it into nine named pieces. Each piece has at most 9,000 triangles. The second
builder uses the recorded Studio import IDs in `studio_import.json` to write
`assets/environment/runtime/DoubleLedgeTurret.rbxmx`. The template has a fixed
base, a movable head pivot, a muzzle, an interaction point, and three invisible
collision boxes. The imported scan chunks remain noncollidable. Rebuilding the
GLB produces a new hash; it requires a new upload and import before reusing the
recorded mesh IDs.

`exports/DoubleLedgeTurret.glb` is the intended 3D export. `review/` contains
renders of the actual source and final export. `validation.json` records mesh
counts, bounds, texture format, and artifact hashes. A local render verifies the
painted look, not its appearance under Roblox lighting.

## Studio and gameplay

Uploaded model asset `110074246078061` is owned by Roblox user `3678531109`
and was approved by moderation. Studio import produced nine MeshParts with
SurfaceAppearance maps. The review import was placed at Y=1000 for visual
inspection and was later found under
`Workspace.MyMap — EDITABLE.Geometry.Turrets.DoubleLedgeTurret_Review` in an
AutoRecovery file with PlaceId 0. This is a staging observation, not a saved
Snow Fortress match placement.

The repository-backed template is mapped by Rojo under
`ServerStorage.EnvironmentArt.DoubleLedgeTurret`. `TurretService` clones it
when a map declares `Turrets`; `TurretController` handles mouse, controller,
and touch firing and exit. Gameplay code has passed format, lint and local
place-build checks but has not been playtested in the target place.

## Limits

The supplied GLB is a dense scan with many disconnected components and open
edges. The decimated export preserves its silhouette in local renders, but
70,403 total triangles may be costly on lower-end phones. The base and head are
separated by height rather than original authoring groups; inspect the seam
while aiming. Studio texture loading, interaction, firing, respawn cleanup,
team fairness, and device performance need live verification.
