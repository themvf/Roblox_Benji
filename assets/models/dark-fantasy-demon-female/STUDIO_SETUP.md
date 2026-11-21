# DarkFantasyDemonFemale — Roblox Studio Setup & Verification Guide

> **STOP / Stage 5 & 6 Gate:** `marketplace_readiness.json` certifies `gameSkinPassed = true` and `marketplaceLocalPrecheckPassed = true`, while keeping **`marketplaceUploadReady = false`**. Do not upload, publish, or modify a Roblox Studio place until Stage 5 (`v21`) visual review is approved by the owner and the owner confirms:
> 1. **Target Studio Place ID / Name** (for private import & animation testing)
> 2. **Creator Account or Group** (owner of uploaded MeshParts, Textures, Accessories, and Bundle)
> 3. **Catalog Bundle & Accessory Titles and Pricing**
> 4. **Approval for any paid upload / publishing fees**

---

## 1. Delivery Manifest (Verified `v21` Files to Import)

All files below are verified by `python tools/check_dark_fantasy_demon_readiness.py` (`checkedAt`: `2026-11-14T20:05:11.843573+00:00`, `openEdges = 0`, `nonManifoldEdges = 0`).

### A. R15 Character Body & Accessories (`exports/`)

| File | Role / Type | Attachment / Cages / Skinning | Triangles (Budget) | SHA-256 |
| :--- | :--- | :--- | :--- | :--- |
| `exports/DarkFantasyDemonFemaleBody.glb` | 15-Region R15 Body + 3D Eye/Mouth Head | R15 Armature (`15` joints) + `15` template `*_OuterCage` meshes (`map1` UVs) | `9,580` (`<= 10,742`) | `842c854bbfa28696433979b2631e68ffd88dcee13b68abd0c780ecef9fcf8591` |
| `exports/DemonHorns.glb` | Rigid Accessory (Head) | `HatAttachment` (`Head`) | `3,072` (`<= 4,000`) | `b166c3ff5777276206a12864a46f5ec620b51c4d66d5c7d5c385358ce63242ea` |
| `exports/DemonHair.glb` | Rigid Accessory (Hair) | `HairAttachment` (`Head`) | `3,456` (`<= 4,000`) | `4adbb684b6ff5a525e2845593021870fa1d70b7b9e87bea5ca03175caee74181` |
| `exports/FeatheredShoulderMantle.glb` | Layered Accessory (Shoulders) | R15-skinned + official template `_InnerCage` / `_OuterCage` (`2,690` tris each, `map1` UVs) | `1,776` (`<= 4,000`) | `5bcb6a32ed40a7ba268c41c6254225ff779d5e76fab183bdcbd1f432838b6b47` |
| `exports/HipTassets.glb` | Layered Accessory (Waist) | R15-skinned + official template `_InnerCage` / `_OuterCage` (`2,690` tris each, `map1` UVs) | `3,456` (`<= 4,000`) | `04c58e4594436d7152962049ac5139be2c534d1aefce5ad90e92de391a0001db` |
| `exports/LeftWristFeathers.glb` | Rigid Accessory (Left Wrist) | `LeftGripAttachment` / `LeftLowerArm` | `288` (`<= 4,000`) | `4cdf04db7d321ba4d9e99105495416647682c7248bd507aa14194cc6733fc6bc` |
| `exports/RightWristFeathers.glb` | Rigid Accessory (Right Wrist) | `RightGripAttachment` / `RightLowerArm` | `288` (`<= 4,000`) | `436b7658603ebb0d52f0ee34289fe6f6377cb659a5aab02e06847df82b416a5f` |
| `exports/DarkFantasyDemonFemaleFull.glb` | Combined Preview Only | Full assembled character (do not upload to catalog) | `21,916` | `53b9df32eb4a2d5d4494a742f42b98b5107cf3c852b32e6d5e9ba62f34fdfbda` |

### B. PBR SurfaceAppearance Textures (`textures/`, all `1024×1024` PNG)

| Texture File | Target / Variant | `SurfaceAppearance` Slot | Color Space | SHA-256 |
| :--- | :--- | :--- | :--- | :--- |
| `textures/DarkFantasyDemonBody_ALB.png` | 15 R15 Body Regions (Default Violet) | `ColorMap` | sRGB | `1a0993946e5238d04df6cff6317de2b857ab697e8b137aa68e92f4088d2710ef` |
| `textures/DarkFantasyDemonBody_TeamRed_ALB.png` | 15 R15 Body Regions (Team Red Shooter) | `ColorMap` | sRGB | `851ebb25909457429b4b7c64deddec2c89c0095829841110cbcee19f64d8ccd7` |
| `textures/DarkFantasyDemonBody_TeamBlue_ALB.png` | 15 R15 Body Regions (Team Blue Shooter) | `ColorMap` | sRGB | `505e333add8e680007b8b2edf1dabbb8c121752938dc2f4ce0da90b04313606e` |
| `textures/DarkFantasyDemonBody_RGH.png` | 15 R15 Body Regions | `RoughnessMap` | Non-Color | `aacce8b41d53e8fade1ae4a63154520b43d145d845f8acf7d71cf633d3f738b8` |
| `textures/DarkFantasyDemonBody_NRM.png` | 15 R15 Body Regions | `NormalMap` | Non-Color | `5fb8158232da252df9aa40bd84112444104ea57d3c41e93d2c5a7401ed21905e` |
| `textures/DarkFantasyDemonAcc_ALB.png` | All 6 Accessories (Default Violet) | `ColorMap` | sRGB | `2ae4723311c62de3f38b752cb587da3e3b5cd34fd6af9a177faa35442ec9f8d6` |
| `textures/DarkFantasyDemonAcc_TeamRed_ALB.png` | All 6 Accessories (Team Red Shooter) | `ColorMap` | sRGB | `e5ba2fee26f8e96e01ba908ec69629b05c91fc6dc5c0aa57b1036266c21d9e0b` |
| `textures/DarkFantasyDemonAcc_TeamBlue_ALB.png` | All 6 Accessories (Team Blue Shooter) | `ColorMap` | sRGB | `790b32cda0960db411b37f4313fac150cc0befe9db0b8962dac2ef4682a7e57b` |
| `textures/DarkFantasyDemonAcc_RGH.png` | All 6 Accessories | `RoughnessMap` | Non-Color | `8c2fe43fbd1fc0a937aea449753dc96898af44f6dc43b0ee00ba5560051ec532` |
| `textures/DarkFantasyDemonAcc_NRM.png` | All 6 Accessories | `NormalMap` | Non-Color | `3255677590ac9efcfed3db963689721bb1ac3868269c3d9bf8069d742e5451a3` |

---

## 2. 3D Importer Settings (Roblox Studio)

1. Open **Avatar** → **3D Importer** in Roblox Studio.
2. Import `exports/DarkFantasyDemonFemaleBody.glb` first:
   - **Import As:** `Rig` (`R15` / `Platform Avatar` candidate)
   - **Scale Unit:** `Studs` (authored at `~5.6` studs crown height / `~7.2` studs horn-tip height, feet at `Y = 0`, facing `-Z`)
   - **Coordinate Orientation:** Forward `-Z`, Up `+Y`
   - **Body Cages:** Confirm `15` `*_OuterCage` template cages with `map1` UVs are preserved alongside the 15 `MeshPart` regions (`Head` = `3,028` tris).
   - **SurfaceAppearance:** Bind `_ALB` (`ColorMap`), `_RGH` (`RoughnessMap`), and `_NRM` (`NormalMap`) to all 15 R15 regions. (Use `_TeamRed_ALB` / `_TeamBlue_ALB` overrides in team-shooter skin presets.)
3. Import each of the 6 accessory GLBs separately (`DemonHorns.glb`, `DemonHair.glb`, `LeftWristFeathers.glb`, `RightWristFeathers.glb`, `FeatheredShoulderMantle.glb`, `HipTassets.glb`):
   - Assign `DarkFantasyDemonAcc_ALB.png` (or `_TeamRed`/`_TeamBlue` variants), `_RGH.png`, and `_NRM.png`.
   - For `FeatheredShoulderMantle.glb` and `HipTassets.glb`, confirm the importer detects R15 skinning weights and both `2,690`-tri official Roblox template `<Name>_InnerCage` and `<Name>_OuterCage` meshes.

---

## 3. Avatar Setup (`Platform Avatar` Preset — Required Remaining Step for Marketplace)

1. Open **Avatar** → **Avatar Setup** and select the imported `DarkFantasyDemonFemaleBody` model.
2. Select the **Platform Avatar** preset and run **Generate / Auto-Setup** on `Head`:
   - Confirm Studio generates valid **17+ FACS facial animation poses / `FaceControls`** over the carved 3D orbital sockets, visible 3D eyeballs, parted mouth cavity, teeth, and tongue.
   - Confirm all 15 R15 `MeshPart` regions (`9,580 / 10,742` tris) and `15` `*_OuterCage` meshes pass Avatar Setup Character Validation without warnings or errors.
3. Attach and test the 6 accessories in the Avatar Setup **Accessories** tab (`DemonHorns`, `DemonHair`, `FeatheredShoulderMantle`, `HipTassets`, `LeftWristFeathers`, `RightWristFeathers`).

---

## 4. Studio Inspection Checklist

- [ ] **Avatar Setup Character Validation:** Zero errors (`Body <= 10,742`, region limits: `Head 3,028/4,000`, `Torso 1,680/1,750`, `Arms 1,220/1,248`, `Legs 1,216/1,248`, textures `1024×1024`).
- [ ] **Dynamic Head FACS Animation:** Test Blink, JawDrop, MouthSmile, and Frown FACS sliders in Avatar Setup; verify 3D eyeballs, upper/lower teeth, tongue, winged liner, and lips deform cleanly.
- [ ] **Body Joint Closure & Stress Motion:** Play **Idle**, **Run**, **Jump**, **Swim**, overhead raises, and **Emotes**; confirm zero gap at shoulders/waist/knees and clean cage fit on `FeatheredShoulderMantle` and `HipTassets`.
- [ ] **Team Variant Readability:** Test `_TeamRed_ALB` and `_TeamBlue_ALB` overrides on a brightly lit team-shooter map.
- [ ] **Creator Ownership:** Confirm all imported assets are uploaded under the approved creator account or group.

---

## 5. Stage 6 -> Stage 7 Handoff Record (Fill In After Studio Import)

- **Confirmed Studio Place ID:** `<pending>`
- **Confirmed Creator Account / Group:** `<pending>`
- **Catalog Bundle Title & Price:** `<pending>`
- **Uploaded Asset IDs (`rbxassetid://`):**
  - `CharacterBundleId` / `HumanoidDescription` preset: `<pending>`
  - `Body_ColorMap` (`Violet` / `TeamRed` / `TeamBlue`) / `Body_RoughnessMap` / `Body_NormalMap`: `<pending>`
  - `Acc_ColorMap` (`Violet` / `TeamRed` / `TeamBlue`) / `Acc_RoughnessMap` / `Acc_NormalMap`: `<pending>`
  - `DemonHorns` / `DemonHair` / `FeatheredShoulderMantle` / `HipTassets` / `LeftWristFeathers` / `RightWristFeathers`: `<pending>`
