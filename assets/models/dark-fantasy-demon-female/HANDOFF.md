# DarkFantasyDemonFemale — Character Handoff

## Current truth

- **Goal:** One approved character design delivered twice: (a) a Roblox Marketplace character bundle candidate, and (b) a selectable in-match / team-shooter skin in this game (`Neutral Violet` + `TeamRed` / `TeamBlue` shooter variants).
- **Method (`v21`):** Procedural R15 retopology (`Head` + 14 R15 limbs, `9,580 / 10,742` tris) paired with 6 watertight sculpted accessories (`DemonHorns`, `DemonHair`, `FeatheredShoulderMantle`, `HipTassets`, `LeftWristFeathers`, `RightWristFeathers`), official Roblox `Clothing_Cage_Template.fbx` & `Body_Cage_Template.fbx` conformal cages (`source/roblox-cages/`), High-DPI `492×338` face UV island (`DarkFantasyDemonBody_*`), and art-directed **Dark-Fantasy Charcoal & Accent Trim** `1024×1024` PBR textures (`_ALB`, `_TeamRed_ALB`, `_TeamBlue_ALB`, `_RGH`, `_NRM`).
- **Key upgrades since the `v18` audit:**
  - **Real 3D Dynamic Head Geometry (`Head`, `3,028 / 4,000` tris):** Carved 3D orbital sockets (`depth=0.055`), separate visible 3D eyeballs (`anteriorEyeComponents = 2`), and parted 3D mouth pocket with upper/lower teeth & tongue (`anteriorMouthComponents = 3`). *(Note: facial rig still reports `no_facial_bones` — Roblox Studio Avatar Setup must generate the 17+ FACS `FaceControls` before Marketplace submission.)*
  - **Bold Segmented U/Lyre Horns (`DemonHorns`, `3,072 / 4,000` tris):** Thickened base (`r_base = 0.255`) with 8 broad sculpted plate segments and softened obsidian-to-accent shading.
  - **Crafted Broadside Feather Blades (`FeatheredShoulderMantle` `1,776` tris; `Left/RightWristFeathers` `288` tris each):** Replaced hairline edge-on spikes with X-Z fanned, overlapping sculpted lanceolate blades and a draped shoulder capelet bridging the shoulder socket cleanly.
  - **Natural Swept Bob (`DemonHair`, `3,456 / 4,000` tris):** Lowered skull-hugging crown (`z = 5.688`) with softened asymmetrical forehead bangs.
  - **Team-Shooter Color Readability (`Palette.World` matched):** Added `DarkFantasyDemonBody_TeamRed_ALB.png` / `_TeamBlue_ALB.png` and `DarkFantasyDemonAcc_TeamRed_ALB.png` / `_TeamBlue_ALB.png` highlighting horns, gorget collar, chest V-piping, outer shoulder/wrist feathers, hip tasset borders, and boot cuffs.
  - **Official Roblox Template Cages:** Replaced all `80`-tri placeholder boxes with conformal fits built from official Roblox `Clothing_Cage_Template.fbx` (`1,358` verts / `2,690` tris per `_InnerCage`/`_OuterCage`) and `Body_Cage_Template.fbx` (`15` `*_OuterCage` meshes), preserving `'map1'` UVs.
  - **Honest Readiness Gate & Stress Pose (`check_dark_fantasy_demon_readiness.py`):** Splits checks cleanly into `gameSkinPassed: true`, `marketplaceLocalPrecheckPassed: true`, and **`marketplaceUploadReady: false`**, plus renders an aggressive overhead arm-raise (~102°), deep knee-bend (~75°), torso-twist (~28°) stress pose.
- **Commercial rights:** **Confirmed by owner** ("It's my image. Proceed", 2026-11-12).

## Stage status

1. **Intake (verified):**
   - `source/DarkFantasyDemonFemaleSource.glb` (SHA-256 `1e43724c86c74d4ffd2b3d0789c50cd4603cff86a51276eb8ed3f87607278760`, 299,619 triangles) and `source/DarkFantasyDemonFemaleReference.png` (SHA-256 `0d99fabbb97b9552b7691975f8a469b01f717f265b207a184f997d0b1a8fa438`, 682×1024).
   - Official Roblox cage templates downloaded into `source/roblox-cages/` (`Body_Cage_Template.fbx`, `Clothing_Cage_Template.fbx`).
2. **Plan (verified):**
   - `Head`: `3,028 / 4,000` tris
   - `Torso` (`UpperTorso` + `LowerTorso`): `1,680 / 1,750` tris
   - `LeftArm` / `RightArm`: `1,220 / 1,248` tris each
   - `LeftLeg` / `RightLeg`: `1,216 / 1,248` tris each
   - Total body: `9,580 / 10,742` tris + `15` `*_OuterCage` body cages
   - Accessories: `DemonHorns.glb` (`3,072` tris), `DemonHair.glb` (`3,456` tris), `FeatheredShoulderMantle.glb` (`1,776` tris + 2,690-tri template Inner/Outer cages), `HipTassets.glb` (`3,456` tris + 2,690-tri template Inner/Outer cages), `LeftWristFeathers.glb` (`288` tris), `RightWristFeathers.glb` (`288` tris).
3. **Author (verified locally on `v21`):**
   - Builder: `tools/blender/build_dark_fantasy_demon_female.py`
   - Editable scene: `source/DarkFantasyDemonFemale.blend`
   - Textures (`1024×1024` PNG): Violet (`DarkFantasyDemonBody_*`, `DarkFantasyDemonAcc_*`) + Team Red & Team Blue `_ALB.png` variants in `textures/`.
   - Exports (`exports/*.glb`): SHA-256 hashes recorded in `validation.json` & `marketplace_readiness.json`.
4. **Local checks (passed with honest Studio gate):**
   - `python tools/check_dark_fantasy_demon_readiness.py` (`checkedAt`: `2026-11-14T20:05:11.843573+00:00`):
     - `gameSkinPassed = true`
     - `marketplaceLocalPrecheckPassed = true`
     - `marketplaceUploadReady = false` (Studio Avatar Setup FACS + cage deformation test remain)
5. **Previews & Visual Approval (CURRENT STAGE — rendered `v21`, awaiting owner review):**
   - `tools/blender/render_dark_fantasy_demon_previews.py` rendered 9 Cycles views in `review/`: `front.png`, `side.png`, `rear.png`, `quarter.png`, `head_closeup.png`, `posed_limbs.png`, `posed_stress_side.png`, `team_colors.png`, and `ingame_scale.png`.
   - Awaits owner visual sign-off on `v21` before moving to Stage 6 Studio import.
6. **Studio verification (STOP — blocked on Stage 5 approval + owner confirmations):**
   - Requires Studio 3D Importer + **Avatar Setup** (`Platform Avatar`) to generate FACS `FaceControls`, verify layered accessory cage fit, confirm R15 animation playback, and record uploaded `rbxassetid://` IDs in `STUDIO_SETUP.md`.
7. **Game integration:** Pending uploaded `rbxassetid://` IDs from Stage 6 to wire `DarkFantasyDemonFemale` into `src/shared/CharacterSkins/`.

## Next action

1. **Owner Stage 5 Visual Review (`v21`):** Review `review/front.png`, `side.png`, `rear.png`, `quarter.png`, `head_closeup.png`, `posed_limbs.png`, `posed_stress_side.png`, `team_colors.png`, and `ingame_scale.png`.
2. After approval, follow [STUDIO_SETUP.md](STUDIO_SETUP.md) in Roblox Studio (import Body + 6 Accessories + Neutral/Team textures, run **Avatar Setup**, verify FACS facial sliders & animation playback, and confirm Target Place ID / Creator / Asset IDs).
