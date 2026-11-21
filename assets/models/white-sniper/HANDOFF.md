# White Sniper handoff

## Approved decisions

- Source: `Weapons/White Sniper.glb`; use as a player-held map sniper.
- Put two White Sniper pickups in the active Snow Fortress map (`MyMapPublic`)
  and its TDM copy (`MyMapTDM`). The old `SnowFortress.lua` is not in rotation.
- A shot is 90% of target maximum health, with no headshot multiplier.
- Carrier loses the gun on death; its pickup returns 24 seconds after that death.
- The creator can place each spawn by moving a marker in Studio.
- On 2026-11-14 the creator asked to edit the Tool in Studio Properties and
  save it with ENGAGE, outside Rojo's asset sync. The active WhiteSniper Tool
  is therefore Studio-owned; game services and map definitions remain in Rojo.
- On 2026-11-12 the creator chose to keep the optimized rifle file local for now.
  They then explicitly reversed that choice and requested upload, Tool attachment,
  and private gameplay testing. That later request authorizes the import.

## Current stage and evidence (2026-11-13)

1. Intake: complete. Source copied to `source/White Sniper.glb`; appraisal
   records 292,816 triangles, one-metre length, UVs, and the textured source
   views. Purpose recorded in `appraisal.json`.
2. Authoring/export: complete locally. Builder produces editable
   `source/WhiteSniper.blend` and `exports/WhiteSniper.glb` at about 5.5 studs.
   Eight meshes total 72,000 triangles, with two embedded PNG textures.
3. Local verification: passed `python tools/check_white_sniper.py`; see
   `validation.json`. Side, front, and rear textured views of the exported GLB
   are in `review/`. Source and export silhouette visibly match.
4. Gameplay code: implemented locally. MyMapPublic and MyMapTDM pass
   `lune run tools/check_maps.luau` with two pickups and no map warnings.
   `rojo build` passed. `selene` could not obtain the Roblox API dump in this
   environment, so lint is unverified. Runtime results are recorded below.
5. Studio marker placement: `Workspace.WhiteSniperSpawns` has BlueOutpost and
   RedOutpost parts at safe fallback coordinates (-90, 1.596, -145) and
   (90, 1.596, -145) in ENGAGE place `121549226728648`. The positions were
   checked against the active MyMap bake. Studio save succeeded as version 320.
   The user may move
   either part in Edit mode and save again. No custom positions chosen yet.
   Edit-mode inspection confirmed the synced MyMapPublic script contains
   WhiteSniper and PickupService contains the death-respawn rule.
6. Studio import: complete for private testing. The import queue showed a green
   check. `Workspace.WhiteSniperArt` held eight MeshParts with eight textured
   SurfaceAppearances, about 5.5 studs long. Its detailed white surface was
   visibly rendered in the Studio viewport. The import was saved to
   `source/WhiteSniperImported.rbxmx` and `.rbxm`; the XML records root
   SourceAssetId `136724154526766` and all uploaded mesh and texture IDs.
   `studio_import.json` is extracted from that saved XML.
7. Tool attachment: complete in the local Rojo source. `tools/build_weapons.luau`
   now welds the eight imported MeshParts to the kit Rifle while preserving
   firing attachments and hiding the old geometry. Rojo synced eight art
   sections into `ReplicatedStorage.WeaponTools.WhiteSniper` in ENGAGE.
   Studio dropped `Sniper.PrimaryPart` during Rojo import, so `WeaponService`
   restores it from `HandleAttachment` at runtime. A private Play check printed
   `RUNTIME_PRIMARY Rifle`.
8. Private gameplay test: `MapService:Load("MyMapPublic")` produced two
   WhiteSniper pickups. Moving a live test player to the first pad granted the
   Tool (`PICKUP_RESULT true false Rifle`). Killing the carrier destroyed the
   Tool and started the return timer (`DEATH_RESULT nil true`); the pickup was
   ready after the configured 24-second window (`RESPAWN_RESULT true`). A server damage callback
   test, using a 100-health dummy and a head hit, left 10 health
   (`SNIPER_DAMAGE 10 0.9`). `MyMapTDM` loaded with two pickups; after reviving
   the test character, the second pad granted the Tool
   (`TDM_RETRY 100 true false`). The first TDM attempt used a dead character
   and was correctly rejected.
9. Cleanup/save: private Play stopped. The temporary `Workspace.WhiteSniperArt`
   staging model was deleted from the edit place after its source was saved;
   Ctrl+S completed and the tab had no unsaved marker. The two moveable spawn
   markers remain. No publication was performed.
10. Studio ownership handoff (2026-11-14): cloned the working Tool to
    `ReplicatedStorage.StudioWeaponTools.WhiteSniper` in ENGAGE. The copy has
    eight imported art MeshParts, `Sniper.PrimaryPart = Rifle`, four-round
    `AmmoCapacity`, and `DamageFractionOfMaxHealth = 0.9`. The original
    generated Tool was backed up locally at
    `source/WhiteSniperToolPreDetach.rbxm` (SHA-256
    `F340E0D55323F441B3B70F76C5C69C126A9439621A794F9C06ECD43B90D09C77`).
    `default.project.json` ignores only `assets/weapons/tools/WhiteSniper.rbxm`
    and preserves unknown children of `StudioWeaponTools`. `PickupService`
    sources WhiteSniper visuals and equipped Tools from that Studio folder.
    `WeaponService` also repairs PrimaryPart there if Studio loses it.
    A local Rojo build and sourcemap check passed: the generated WeaponTools
    folder no longer contains WhiteSniper; the StudioWeaponTools folder exists.
11. Private ownership test (2026-11-14): reconnected ENGAGE to the original
    Rojo session at localhost:34872. In private Play, changing only the
    Studio-owned template's AmmoCapacity from 4 to 5 produced an equipped Tool
    with 5 rounds and PrimaryPart `Rifle` (`STUDIO_SNIPER_TEST true 5 Rifle`).
    This temporary value existed only in Play; Edit mode still had 4 rounds.
    The old duplicate was moved to `ServerStorage.LegacyWeaponTools` as
    `WhiteSniperPreDetach`, leaving no active WhiteSniper under WeaponTools
    (`SNIPER_DETACHED true 4`). Ctrl+S saved the edit place. No publication
    was performed. The old Rojo server stayed connected; a fresh 34873 server
    could not be reached from Studio, so a full restart-and-sync check of the
    revised project mapping remains open.

## Next action

The creator asked for an appearance mock. An abstract material proposal is in
`review/finish-concept-v1.svg`: off-white enamel, graphite grip and scope
breaks, brushed metal edges, and one restrained cyan indicator. This is a
concept only; it has not been approved or applied to the GLB or Roblox Tool.
The image generator rejected a rifle render, so the board does not depict the
assembled gun. Ask the creator to review the material direction before any
surface changes.

Get the creator's visual approval of the rifle as held and of both pickup pad
previews. Then test actual aiming, firing, and hit registration with two players
in a private session; the direct damage-callback test does not prove a fired
shot can hit. If those pass, publish the saved ENGAGE revision only after a
separate publish decision. The creator may move BlueOutpost or RedOutpost in
Studio Edit mode and save before publication.

For the immediate Studio workflow, edit
`ReplicatedStorage.StudioWeaponTools.WhiteSniper.Configuration` Value objects
in Properties, then save ENGAGE. Keep that Tool in its StudioWeaponTools folder.
On the next fresh Rojo connection, confirm the Studio Tool survives sync and
the retired copy is not recreated in WeaponTools. A clean local Rojo build has
an empty StudioWeaponTools folder by design; the saved ENGAGE place holds the
active Tool. Preserve or export that Studio Tool before rebuilding a place
from source alone.

## Important limits

- The current Config rotations point at MyMapPublic/MyMapTDM, whose display
  name is Snow Fortress. The older `SnowFortress.lua` map is a different legacy
  map and was deliberately left unchanged.
- The imported model was visibly textured in Studio, but a clear held-gun
  inspection and user visual approval are pending. The test avatar's large
  accessories obscured the held rifle in the private client view.
- Direct server callback damage and pickup tests passed. Real two-player
  firing, scope alignment, and post-publication behavior are not verified.
- The Studio-owned Tool is saved in ENGAGE and backed up before detachment, but
  the exact post-detachment Studio copy has not been exported to a separate
  local model file. A fresh place built solely from Rojo source needs that
  Studio-owned Tool inserted before its WhiteSniper pickups can work.
