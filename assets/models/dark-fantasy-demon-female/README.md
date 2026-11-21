# DarkFantasyDemonFemale

Stylized dark-fantasy female demon character package targeting both a Roblox Marketplace R15 character bundle candidate and a selectable in-match / team-shooter skin (`Violet` default + `TeamRed` / `TeamBlue` variants).

## Rebuild

From the repository root (`c:\Docs\_AI Python Projects\Roblox_Benji`):

```powershell
# Full rebuild from source GLB + reference PNG:
& "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --factory-startup --background --python tools/blender/build_dark_fantasy_demon_female.py

# Fast in-place geometry polish + 1024x1024 PBR texture rebuild (Neutral/Red/Blue) + GLB re-export:
& "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --factory-startup --background --python tools/blender/build_dark_fantasy_demon_female.py -- --textures-only

# Local readiness & Marketplace precheck (outputs marketplace_readiness.json + updates validation.json hashes):
python tools/check_dark_fantasy_demon_readiness.py

# Render all 9 Cycles preview views into review/:
& "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" --factory-startup --background --python tools/blender/render_dark_fantasy_demon_previews.py
```

## Package contents

- `source/DarkFantasyDemonFemaleSource.glb` — Original TRELLIS scan (shape/texture reference only; never rigged or uploaded).
- `source/DarkFantasyDemonFemaleReference.png` — Approved Midjourney reference image.
- `source/DarkFantasyDemonFemale.blend` — Editable Blender 4.3 authoring scene (`15` R15 regions, 3D dynamic-head eye/mouth geometry, `15` template `*_OuterCage` body cages, R15 armature, `6` accessories, and template clothing cages).
- `source/roblox-cages/` — Official Roblox `Body_Cage_Template.fbx` & `Clothing_Cage_Template.fbx`.
- `textures/` — `1024×1024` PBR albedo (`_ALB.png`, `_TeamRed_ALB.png`, `_TeamBlue_ALB.png`), roughness (`_RGH.png`), and normal (`_NRM.png`) maps for `DarkFantasyDemonBody_*` and `DarkFantasyDemonAcc_*`.
- `exports/DarkFantasyDemonFemaleBody.glb` — `15`-region R15 body (`9,580 / 10,742` tris, `openEdges = 0`, `nonManifoldEdges = 0`) + 3D eye/mouth head geometry + `15` `*_OuterCage` meshes + R15 rig.
- `exports/DarkFantasyDemonFemaleFull.glb` — Combined body + accessories preview GLB.
- `exports/DemonHorns.glb`, `exports/DemonHair.glb`, `exports/LeftWristFeathers.glb`, `exports/RightWristFeathers.glb` — Watertight rigid accessories (`<= 4,000` tris each).
- `exports/FeatheredShoulderMantle.glb`, `exports/HipTassets.glb` — Watertight layered accessories (`<= 4,000` tris each) with R15 skinning weights and `2,690`-tri official Roblox template `_InnerCage` / `_OuterCage` preserving `'map1'` UVs.
- `review/` — `front.png`, `side.png`, `rear.png`, `quarter.png`, `head_closeup.png`, `posed_limbs.png`, `posed_stress_side.png`, `team_colors.png`, and `ingame_scale.png`.
- `marketplace_readiness.json`, `validation.json`, `appraisal.json`, `HANDOFF.md`, `STUDIO_SETUP.md`.

## Known limitations

- `check_dark_fantasy_demon_readiness.py` sets `gameSkinPassed = true`, `marketplaceLocalPrecheckPassed = true`, and **`marketplaceUploadReady = false`**. Dynamic Head FACS facial poses (`17+` `FaceControls`), layered cage deformation, and Marketplace character validation must still be executed and verified inside **Roblox Studio Avatar Setup** (`STUDIO_SETUP.md`) before publication.
