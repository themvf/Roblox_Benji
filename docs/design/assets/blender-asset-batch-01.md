# Asset batch 01: Titan jetpack, jump pad

> The glacier backdrop was part of this batch and has been withdrawn. See
> "Why the glacier backdrop was dropped" at the end.

Status: **exports and wiring complete, live-gameplay verification outstanding.**
Follows [ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md](../ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md).
Target map: Snow Fortress (Convergence).

Per that spec an asset is not complete until it is recognizable in a normal game
session. Everything below has cleared the build gates and the Blender-side checks;
none of it has been seen in a running match, because that needs Studio and a
Roblox upload. Section 5 is the part a human has to close.

## 1. What shipped

| | Glacier backdrop | Titan jetpack | Jump pad |
| --- | --- | --- | --- |
| Source | `MapLocations/rocky-glacier-snowy-landscape-terrain` | `Jetpacks/gearspec-titan-cameraman-jetpack` | `Snow Fortress/v2701-jumppad-2018-spring-ue4jam` |
| Source form | OBJ, 712,818 tris | OBJ + MTL, 3,984 tris | FBX, 972 tris |
| Export | `assets/models/glacier/Glacier.glb` | `assets/models/jetpack/JetpackPack.glb` | `assets/models/jumppad/JumpPad.glb` |
| Exported tris | 16,873 over 4 tiles, max 5,381 | 3,984 | 972 |
| Exported size (studs) | 2400 x 1146 x 2400, 4x vertical exaggeration | 4.0 x 2.55 x 0.91 | 8.0 x 0.42 x 8.0 |
| Pivot | bbox centre | bbox centre | underside centre |
| Textures | 4033² -> 1024² (diffuse, roughness, normal) | 512² diffuse, unchanged | 2048² -> 1024², 5 maps |

Reproduce any of them from tools/blender/scenes.json with:

```bash
blender -b -noaudio --python tools/blender/scene_kit.py -- --asset jumppad
```

## 2. Decisions worth knowing

**The glacier is scenery, not terrain.** The source is a 712k-triangle scan, 71x over
Roblox's 10,000-triangle per-mesh ceiling, so it is decimated to ~40k and bisected into
a 4x4 grid; empty cells are dropped, leaving 15 tiles that each clear the limit. It is
placed as four rings outside the playable box rather than under it, because the brief
asked for a view, not a playable surface. `Validate.lua` now rejects any `scenery`
piece whose pivot falls inside `Bounds`, so this cannot quietly become arena geometry.

**The jetpack keeps its greybox skeleton.** Its nozzles carry the `Flame` attachments
that `UtilityService:SetThrusting` toggles, so the mesh hides those parts rather than
replacing them. The mesh's intake turbines sit at x ~ +/-0.57 studs, close enough to the
existing +/-0.5 nozzle anchors that the flames should still read as coming from them --
this is the single measurement most worth checking in-game.

**The outpost stairs face their own spawn.** Each outpost keeps the staircase on its
own team's side, so the approach from spawn climbs straight into the firing room, and
the upper doorway moved with it. The northwest outpost sits on Blue's side at x -145,
so its stair spans x -202.8 to -157.8 and its door is the -X face.

**An earlier revision shortened the stairs instead.** An earlier revision of this branch shortened
them from 45 to 27 studs. `check_fortress_layout`'s head-clearance test passes with
exactly zero margin at the authored 1-stud rise on a 2.5-stud run, so any steepening
trips it; the only shortening that still passes is a 2.25-stud run, worth 4.5 studs.
enclosed-fortress-v3 removes the spawn-facing stair outright, which was the real
problem, so the shortening was reverted rather than fought for.

**The glacier is exaggerated 4x vertically.** The source scan has 286 studs of
relief over 2400, a ratio of 0.119; below roughly 0.2 a heightfield reads as a flat
plate at any distance, which is why the first attempt looked like slabs rather than
mountains. At 0.476 it reads as a range. It is also a finite heightfield, so every
edge of the plate is a cliff that no rotation hides -- hence a ring pushed well out
with a flat snow plain filling the foreground, and eight plates rather than four,
because four leaves a visible gap at each diagonal.

**The outposts watch their own objective.** Each upper firing room now has a window
on the inward X face and on the inward Z face, with a solid backstop on the outward
Z face. Ray-casting the authored solids from 18 firing positions per outpost puts
objective A clear from the northwest post 18/18 and B clear from the southeast post
17/18, with zero open lanes to either enemy spawn across 108 samples each. Closing
those lanes needed the sightline screens widened from 58 to 66 studs: the objective
and the enemy spawn sit only about 18 degrees apart from an outpost, so no aperture
at the wall can separate them and the restriction has to sit downrange.

**The jump pad's pivot is deliberate.** A `SpecialMesh` hangs its mesh origin on the
part's centre, so exporting with an underside pivot and centring the part on the
layout position rests the pad on the floor. The greybox slab needed a +0.3 lift
because its origin was its middle; the dressed pad does not.

**Normal maps were converted.** The jump pad ships a DirectX normal map; its green
channel is flipped on resize for Roblox's OpenGL convention.

## 3. Wiring

Nothing hard-codes an asset ID. Everything resolves through the existing
`upload:<Name>` indirection in `src/shared/Uploads.lua`, and every call site degrades
to the current greybox when the upload is absent -- so this branch is safe to run
before anything is uploaded.

- `src/shared/MeshDressing.lua` (new) applies an uploaded mesh to a placeholder part.
- `src/server/Services/UtilityService.lua` dresses the jetpack templates once at
  `KnitStart`, so the worn pack and the kiosk preview both inherit it.
- `src/server/Services/PickupService.lua` dresses each launch pad. The procedural
  trampoline from enclosed-fortress-v3 is the greybox: its rim, springs and legs are
  siblings of the pad, so a dressed pad simply never builds them.
- `src/server/Services/MapService.lua` gains a `scenery` piece kind: clones a model
  from `Uploads`, forces `CanCollide`/`CanQuery`/`CanTouch` off on every part.
- `src/shared/MapArt/GlacierBackdrop.lua` (new) places the four rings.

## 4. Uploads

All three are uploaded and moderation-approved, as user 3678531109, via
`tools/roblox/upload_asset.ps1`:

| Asset | Roblox asset ID | Uploads entry name |
| --- | --- | --- |
| `JetpackPack.glb` | 73494627185081 | `JetpackMesh` |
| `JumpPad.glb` | 101685278186013 | `JumpPadMesh` |
| `Glacier.glb` | 122603760493454 | `GlacierScenery` |

Receipts, keyed by content hash, are in `%LOCALAPPDATA%/RobloxCodex/uploads`. Re-running
an upload of identical bytes resumes the receipt instead of creating a duplicate asset.

Open Cloud's Assets API only mints **Model** assets; there is no mesh asset type, and
the uploader hardcodes `assetType: "Model"`. So each of these is a Model containing
MeshParts, not a bare mesh id. `MeshDressing` handles both: given an Uploads entry that
is a Model it reads the mesh and texture off the first MeshPart inside, so nothing has
to be copied out by hand.

The glacier backdrop needs no Studio step: `MapService` loads asset 122603760493454
through `InsertService:LoadAsset` at build time, caching the outcome so four ring
placements cost one load. Dropping a Model named `GlacierScenery` into
`ReplicatedStorage.Uploads` still overrides the id, so the look can be retuned in
Studio without a code change.

The jetpack and jump pad need no Studio step either. Open Cloud only mints Model
assets, and a Model id cannot be assigned to `SpecialMesh.MeshId`, so a dressed prop
needs the Model as an *instance* to read the mesh off. Rather than leave that as a
hand-placement in `ReplicatedStorage.Uploads` that somebody has to remember,
`Uploads.FALLBACK_ASSETS` records the ids and the server loads the Models itself
through `InsertService:LoadAsset`, cached, on the server only.

| Name | Fallback asset |
| --- | --- |
| `JetpackMesh` | 73494627185081 |
| `JumpPadMesh` | 101685278186013 |

An instance placed in `ReplicatedStorage.Uploads` still wins, so the art can be
swapped in Studio without a code change, and a failed load warns once and leaves the
greybox in place rather than erroring.

`LoadAsset` requires the place to be owned by the account that owns the assets
(3678531109). Under a group-owned place it will fail and both props stay greybox.

## 5. Not yet verified — needs a running match

1. **Jetpack orientation and scale on a real R15 torso.** The mesh's axes were read
   from renders, not from a character. Check the pack is not inside-out or clipping,
   and that flames still leave the nozzles.
2. **Jump pad orientation.** The dressed pad yaws to face its launch target; confirm
   the art's own directional markings agree with the arc.
3. **Glacier ring placement.** Chosen arithmetically from `Bounds`, never seen. Check
   for gaps between rings on the horizon, z-fighting where tiles overlap, and whether
   the ridge line reads at the map's `FogEnd` of 3000.
4. **Palette clash.** The jump pad art is purple and lime; Snow Fortress is a grey and
   white arctic map. This may need a hue shift on the base colour to belong.
5. **Frame time on phones.** 15 backdrop tiles plus a dressed pad per launch pad is new
   per-frame cost that has not been measured on a low-end device.


## 6. Why the glacier backdrop was dropped

The Glacial Iceflats scan was processed, uploaded three times and placed as a mesh
ring before being abandoned. It was the wrong tool, and the reasons are worth
keeping so the next backdrop does not repeat them.

- **A terrain scan is baked for top-down viewing.** Its texture is an orthographic
  bake, so seen from the side it smears, and the silhouette is whatever survives
  decimation -- here 712,818 triangles down to 16,873.
- **Its relief ratio is 0.119.** Below roughly 0.2 a heightfield reads as a flat
  plate at any distance. Forcing 4x vertical exaggeration reached 0.476 but
  stretched the bake further.
- **A finite heightfield is a plate with a cliff on every edge.** Measured, those
  edges run 38-53% of relief on average and up to 100%, so no rotation hides them
  and no placement is free of them.
- **Roblox already solves this natively.** Carrier, Forest and Swamp all declare
  `Terrain.Mountains` as `FillBall` spheres. Terrain textures correctly from every
  angle, carries real LOD, costs no MeshParts and has no edges. Snow Fortress now
  does the same, with `Enum.Material.Glacier` and a nearer row of `Hills` for depth.

The mesh pipeline itself was not the mistake: the jetpack and jump pad are props
meant to be seen from any angle, which is exactly what it is for. Reach for
`tools/blender/scene_kit.py` for props, and for terrain data for horizons.

Orphaned uploads, superseded and safe to delete from the Roblox inventory:
134061547604589, 115957483177465, 122603760493454.


## 7. The horizon is a bought skybox, not a generated one

Two generated ranges were tried after the glacier scan was abandoned. Cones with
cloud noise read as blobby lumps; pushing Voronoi displacement hard enough to carve
ridgelines shattered them into foil. What shipped is "Snowy Sky Box" by
@DonTheBears, Creator Store asset 2029216718, found in about a minute.

The filter that matters when looking: **Visual Effects / Sky and Atmosphere**. That
category holds real `Sky` objects. Free-text searching "skybox" also returns models
that fake one out of six giant textured parts, which put geometry back inside the
playable space -- the exact failure this whole exercise was escaping. Two tells: a
real Sky has a blank store thumbnail because there is no model to render, and on
insert it lands in `Lighting` with nothing added to `Workspace`.

A skybox repeating one image on all four sides cannot be a continuous range. Six
distinct face ids is the signature of one that is.

`make_sky_range.py` and `stitch_skybox.py` stay in the repo. They work, and the
stitch check is worth having for any skybox. They are simply outclassed by art made
for the job, and reaching for them before looking at what already exists cost far
more than the search did.
