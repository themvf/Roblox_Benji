# Asset batch 01: glacier backdrop, Titan jetpack, jump pad

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
| Exported tris | 40,087 over 15 tiles, max 5,858 | 3,984 | 972 |
| Exported size (studs) | 2400 x 286 x 2400 | 4.0 x 2.55 x 0.91 | 8.0 x 0.42 x 8.0 |
| Pivot | bbox centre | bbox centre | underside centre |
| Textures | 4033² -> 1024² (diffuse, roughness, normal) | 512² diffuse, unchanged | 2048² -> 1024², 5 maps |

Reproduce any of them with:

```bash
blender -b -noaudio --python tools/blender/process_assets.py -- jumppad "<src>" assets/models/jumppad/JumpPad.glb assets/models/jumppad/textures
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

**The outpost stairs were left alone.** An earlier revision of this branch shortened
them from 45 to 27 studs. `check_fortress_layout`'s head-clearance test passes with
exactly zero margin at the authored 1-stud rise on a 2.5-stud run, so any steepening
trips it; the only shortening that still passes is a 2.25-stud run, worth 4.5 studs.
enclosed-fortress-v3 removes the spawn-facing stair outright, which was the real
problem, so the shortening was reverted rather than fought for.

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

## 4. Upload checklist (Studio)

Import each GLB with the 3D Importer, then create these under
`ReplicatedStorage.Uploads`. `StringValue` entries hold a `rbxassetid://...`.

| Name | Type | Holds |
| --- | --- | --- |
| `JetpackMesh` | StringValue | mesh ID from `JetpackPack.glb` |
| `JetpackTexture` | StringValue | `Handle1_diff.png` |
| `JumpPadMesh` | StringValue | mesh ID from `JumpPad.glb` |
| `JumpPadTexture` | StringValue | `JumpPad_Base_Color.png` |
| `GlacierScenery` | Model | the imported `Glacier.glb` model, all 15 tiles |

Only the maps Roblox can consume today are committed: colour, normal and the pad's
emissive. Metalness, roughness and AO are regenerated on demand with
`tools/blender/resize_textures.py` rather than stored as unused binaries.

`GlacierScenery` is a Model, not an ID: the backdrop is cloned wholesale so it needs
no per-tile IDs. Rojo leaves the `Uploads` folder alone, so these survive syncs.

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
