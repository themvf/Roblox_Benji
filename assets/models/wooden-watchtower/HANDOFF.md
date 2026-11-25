# Wooden Watchtower handoff

## Current stage

- Stage: **Option A Blender rebuild uploaded (`116938500732390`), placed backside-facing on expanded cliffs, and baked into `FiveIslands` (`src-db13af53f1`) — pending live Studio Play restart & visual inspection**
- Next action: Stop and restart Play in Roblox Studio (with `rojo serve` running) and run `/explore FiveIslandsHurricane` (confirm `[MapBuild] FiveIslands / src-db13af53f1` in Output) to verify live:
  1. Both towers face their climbing side on the **backside** away from center island (`North_Watchtower` at `(0, 21.0, -246), yaw = 0`; `South_Watchtower` at `(0, 21.0, +246), yaw = 180`), with ~12.3 studs of flat grass behind each ladder (`RidgeTurf` extended to `Z = ±267`).
  2. Two continuous Trellis-style ladders climb up Deck 1 (`LadderTruss`) -> Deck 1 front/backside balcony -> Trellis-cloned upper ladder (`UpperLadderTruss`) -> clean Boolean-cut doorway into the top roofed sniper nest (`Y = 40.9`, `3.3`-stud open entrance, zero walking through wood planks).
  3. Zero walk-through anywhere on lower legs/under-deck (`UnderTowerCore`), middle slatted crate/X-braces (`MidShaftCore`), Deck 1 rails, or upper booth parapets/roof.
  4. `WhiteSniper` pickups spawn cleanly behind each sniper outpost beside the backside ladder foot (`{ 0, 24.8, -258 }` and `{ 0, 24.8, 258 }`).
- Blockers: None locally.

## Approved decisions

- **Option A Blender rebuild (`tools/blender/build_wooden_watchtower.py`):**
  1. Preserves `assets/models/wooden-watchtower/source/WoodenWatchtower.glb` untouched (`295,273` tris) and applies clean Blender 4.3 edits before `scene_kit` decimate/2x2 tile/optimize:
     - **Boolean-cut open upper doorway:** Cut a clean `3.3 × 5.55`-stud doorway through the upper crow's nest parapet (`X[-1.65..+1.65]`, `Z = 20.05..25.60`) using wood-textured UVs on cut jambs (`0` interior verts left).
     - **Matching Trellis-cloned upper ladder:** Extracted the detached lower Trellis ladder (`7,325` tris), centered at `X = 0`, and aligned it cleanly from Deck 1's balcony (`Z = 11.30`) up to the upper booth doorway (`Z = 20.25`) in the exact same wood style and continuous slope.
  2. Exported `assets/models/wooden-watchtower/exports/WoodenWatchtower.glb` (`3.29 MB`, `31,442` tris across 4 meshes `< 10,000` tris each; `1024x1024` PNG textures).
- **Backside placement & zero-walkthrough colliders:**
  - `North_Watchtower` (`(0, 21.0, -246), yaw = 0`) and `South_Watchtower` (`(0, 21.0, +246), yaw = 180`) orient the climbing face (`local -Z`) toward the ocean cliff backside (`Z = ±267` turf behind the tower). Bulky side `WoodPlanks` staircases (`Step1..Stair8`, `StairLanding`) were removed.
  - Invisible structural colliders seal `PostNW/NE/SW/SE`, `UnderTowerCore` (`0..10.4`), perimeter `LowerBrace*`, `MidShaftCore` (`11.4..19.5`), Deck 1 (`TowerDeck` + flush `Rail*` perimeter), `UpperFloor` (`top = 19.9`), `UpperRoof` (`bottom = 26.3`), `UpperCorner*`, and `UpperWall*` (leaving the exact `3.2`-stud rear doorway `X[-1.6..1.6]` clear at the top of `UpperLadderTruss`).
- **Gameplay layout & pickups (`src/shared/Maps/FiveIslandsHurricane.lua`):**
  - `SniperOutposts`: `{ 0, 41, -246 }` and `{ 0, 41, 246 }` (`radius = 12`).
  - `WhiteSniper` pickups: `{ 0, 24.8, -258 }` and `{ 0, 24.8, 258 }` beside the backside ladder foot on North & South Overlooks.

## Local artifacts

- Blender rebuild script: `tools/blender/build_wooden_watchtower.py`
- Manifest entry: `tools/blender/scenes.json` -> `"wooden-watchtower"`
- Source GLB: `assets/models/wooden-watchtower/source/WoodenWatchtower.glb` (`295,273` tris; SHA-256 `e7d584ba41e773c5f33e7818311763e9c1195dc7a1c6a667aa97a2cd451d35b0`)
- Appraisal: `assets/models/wooden-watchtower/appraisal.json` and `assets/models/wooden-watchtower/views.png`
- Export GLB: `assets/models/wooden-watchtower/exports/WoodenWatchtower.glb` (`3.29 MB`, `31,442` tris: `geometry_0.001` `7,309`, `geometry_0.002` `8,275`, `geometry_0.003` `7,147`, `geometry_0.004` `8,711`; `1024x1024` `image/png`)
- Studio helper: `assets/models/wooden-watchtower/SetupDecoration.luau`

## Roblox IDs and verification status

- Latest Open Cloud upload (`.\tools\roblox\upload_asset.ps1 -Name "WoodenWatchtower_OpenBack"`):
  - **Root Model Asset ID:** `116938500732390` (`moderationState: Approved`)
  - *(Supersedes closed-booth upload `114121381377526`)*
  - **Uploaded MeshPart `MeshId`s** (verified via `InsertService:LoadAsset(116938500732390)` in Studio Edit mode):
    - `geometry_0.001`: `rbxassetid://103689051953923`
    - `geometry_0.002`: `rbxassetid://126647486014771`
    - `geometry_0.003`: `rbxassetid://115308934426639`
    - `geometry_0.004`: `rbxassetid://81647950230914`
  - **Shared `SurfaceAppearance` texture IDs:** `118335835034000` (Color), `107891135453078` (Roughness), `138545032867313` (Metalness)
- **Baked map & visual audit integration:**
  - Baked cleanly via `.\tools\save_map.cmd FiveIslands` (`src-db13af53f1`, `877` parts, `166` solids, `3` objectives, `6 + 6` spawns).
  - Visual audit (`tools/audit_map_visuals.luau FiveIslands`): `0` high-structure overlaps, `0` prop/grounding/.rbxmx issues, `0` craftsmanship/rail/NaN CFrame issues.
- **Pending checks (requires user / Studio Play restart):**
  - Live viewport review of the open upper doorway, Trellis-cloned upper ladder, backside cliff approach, and collision feel.
