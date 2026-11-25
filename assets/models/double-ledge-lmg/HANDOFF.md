# Resume here: Double Ledge LMG turret

## October 4 color update

The user reported that the placed turrets looked washed out, like the
satellite dish. The source `BaseColor.png` is dark (mean RGB about 96, 93,
92), and Studio inspection confirmed valid ColorMap, RoughnessMap, and
MetalnessMap asset IDs on all nine MeshParts in each of the two placed
`DoubleLedgeTurret_Review` models. In the bright snowy scene, the metallic
finish looked pale. The `SurfaceAppearance.Color` value was white.

In the connected `ENGAGE` Studio Edit session, I set `SurfaceAppearance.Color`
to RGB (120, 130, 140) on all nine MeshParts in both models under
`Workspace.MyMap — EDITABLE.Geometry.Turrets`. Screen captures showed better
gunmetal contrast while retaining lighter panels. A Play session confirmed
two models with nine tinted MeshParts each under `Workspace.Map.Geometry.Turrets`;
Studio was returned to Edit. I also updated
`tools/build_double_ledge_template.luau` and regenerated
`assets/environment/runtime/DoubleLedgeTurret.rbxmx` with the same tint. The
template check and `rojo build default.project.json` passed, and Studio's
Rojo-synced ServerStorage template showed the tint on all nine MeshParts.

The Studio place has not been saved or published by this work. The user must
save the place to retain the two placed-model edits. The exported source GLB
was not modified; a fresh manual import needs the same
`SurfaceAppearance.Color` tint. Gameplay checks in the sections below remain
outstanding.

## October 4 collision update

The user reported walking through the turrets during testing. The two
`DoubleLedgeTurret_Review` models under
`Workspace.MyMap — EDITABLE.Geometry.Turrets` had zero collidable parts. In
the connected `ENGAGE` Studio place (PlaceId `121549226728648`), I added
three invisible, anchored collision boxes to each model: pedestal, housing,
and barrel. Studio inspection confirmed six boxes are `CanCollide=true` and
located at the intended local offsets. These Studio edits still need the user
to save the place and export the edited MyMap model to its source `.rbxm`.

The reproducible runtime template now includes the same three boxes, with the
housing and barrel parented under the moving head. The template check and a
Rojo place build passed. A Studio Play session showed all six collidable boxes
under the two live `Workspace.Map.Geometry.Turrets` models. Studio was returned
to Edit mode. A second Play check found both the player and collider in the
`Default` collision group, with their group pairing enabled. Walking a player
character into them and target-device checks
are still pending. Keep the visual mesh
pieces noncollidable; their arbitrary scan chunks are unsuitable as physics
shapes.

## October 4 test-session update

The user confirmed `121549226728648_AutoRecovery_2.rbxl` (PlaceId 0) is the
intended test session. After confirming four existing Studio scripts matched
repository `HEAD`, I synced the turret sources and installed the textured
template in `ServerStorage.EnvironmentArt`. A Play session built two runtime
turrets with prompts. Client prompt input operated the Blue turret; the camera
tracked `HeadPivot`, and firing reduced its ammo from 60 to 59. The original
Blue site had an ice spike 21.4 studs ahead, so I changed the mirrored sites
to `(-170, 2, -60)` and `(170, 2, 60)`. Live rays showed 120 studs clear in
both forward lanes and terrain at Y=2. A second Play session built turrets at
those revised sites. Its damage test was interrupted before completion.

Next: rerun local gates after the site change, then test damage, team access,
reload, exit, and both-team play in Studio. Do not claim these are verified or
that the recovery file was saved or published. The numbered instructions below
predate this update; use this section for current state.

## Approved direction and current truth

The user supplied `source/reference.png` as the desired appearance and asked to
place this as a **working, walk-up turret** in **Snow Fortress**, approximately
**eight studs high**, with **one turret for each team**. Those decisions are
settled. The user has not reviewed or approved the optimized export's appearance
in a normal Roblox match.

The source appraisal found a 281,613-triangle textured 3D scan, 230,367 open
edges, and UVs. The production export is nine named meshes with 70,403 total
triangles, two embedded PNG textures, and an eight-stud Y-up height. Front,
opposite and rear source renders and a rendered final export were inspected.
The local model was uploaded as asset `110074246078061` under user `3678531109`;
the upload receipt reports moderation **Approved**. The exact export SHA256 is
`ab532fd74137b01370633bd78dc62db7902b83df5d2ba381d27258c60130dd9a`.

A Studio review insertion exposed nine MeshParts and populated color,
roughness and metalness maps. The import's initial gray `MeshPart.Color` was
changed to white so it does not dim the texture. Review screenshots showed the
textured silhouette, but not at its intended map site. The connected Studio
instance was `121549226728648_AutoRecovery_2.rbxl`, PlaceId 0, with
`MyMap — EDITABLE` in Workspace. The review model was found under its
`Geometry.Turrets` folder after insertion. Do not infer that this file is the
published Snow Fortress place, that the review model was saved, or that the
runtime turret was tested.

The Rojo-backed template, two Snow Fortress site declarations, and walk-up
gameplay source are implemented locally. `stylua`, targeted `selene`, `rojo
build`, `check_maps`, `check_decor`, and the template check passed. The shared
`check_assets` gate now passes this package but still fails a pre-existing
missing appraisal at `assets/scenery/mud-grassland`.

## First unverified stage and next action

1. Establish a connected Studio session for the intended Snow Fortress game or
   a fresh repository-built place. The current MCP connection only reported
   the AutoRecovery file above, even after the user said Snow Fortress was open.
2. Start a fresh Play session with Rojo-synced source. Confirm
   `ServerStorage.EnvironmentArt.DoubleLedgeTurret` exists and
   `workspace.Map.Turrets` contains `BlueOuter` and `RedOuter` at the declared
   sites. Do not use the review model at Y=1000 as this evidence.
3. From each team, walk to the matching prompt, operate, aim, fire, reload,
   exit, die, respawn, switch maps and restart a match. Verify enemies take
   damage, teammates do not, and the other team cannot operate the turret.
4. Inspect the moving head seam, muzzle direction, source texture brightness,
   spawn routes, visual cover, touch/controller controls, and phone performance.
   Adjust source or code and repeat local build plus Studio checks as needed.
5. Save the verified place and record its actual place ID, screenshots,
   effective tuning, and any published-game evidence here. Do not mark
   publication or match integration based on the local build alone.

## Rebuild caution

Read `README.md`, `appraisal.json`, `validation.json`, and
`studio_import.json`. `python tools/build_double_ledge_lmg.py` rebuilds the GLB
and textures; `tools/build_double_ledge_template.luau` rebuilds the Roblox
template from imported asset IDs. The current `studio_import.json` belongs to
the exact uploaded GLB hash above. If the GLB changes, upload/import again
under the game's owner and replace the manifest before rebuilding the template.
Preserve the reference, source, final export, and receipt. Never replace a
working upload with a local preview or infer ownership from IDs alone.
