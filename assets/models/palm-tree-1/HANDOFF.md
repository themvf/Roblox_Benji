# Palm Tree 1 handoff

## Current stage

- Stage: **3D self-AO & sky/underside shaded matte export uploaded (`84316532447768`), updated & baked into `FiveIslands` (`src-ad11033138`) — pending live Studio Play restart & visual inspection**
- Next action: Stop and restart Play in Roblox Studio (with `rojo serve` running) and inspect `/explore FiveIslandsHurricane` to verify the added foliage/bark shading on all 6 `*_PalmTree1` trees (`CenterPalm1..4_PalmTree1`, `RedPalm6_PalmTree1`, `BluePalm6_PalmTree1`).
- Blockers: None locally.

## Approved decisions

- **Role:** Background / hero tropical palm tree prop (`BackgroundDecoration`), replacing 6 blocky palms in `FiveIslandsHurricane` (`CenterPalm1..4` corners and `RedPalm6` / `BluePalm6` spawn courtyards) inside `Geometry > NatureAndLights`.
- **Scale & pivot:** 19 studs tall (~9.6 x 9.3 studs crown spread), bottom-center pivot (`0.0 .. 19.0` studs about pivot).
- **Physics:** `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `DoubleSided = true`, `CastShadow = true`, `CollisionFidelity = Box`.
- **Lighting & 3D shading:** Re-exported via `make_opaque_matte.py` directly from `source/Palm_Tree_1.glb`'s `2048x2048` diffuse texture, computing 3D vertex directional sky/underside lighting, `cKDTree` canopy self-AO, crown-heart trunk shadow, and bark/frond rib detail baked into an opaque dilated `1024x1024` RGB PNG (`alphaMode = "OPAQUE"`, `metallicFactor = 0.0`, `roughnessFactor = 0.90`). Zero `SurfaceAppearance` glare on Roblox import; `MeshPart`s use `TextureContent = rbxassetid://115128353982109` + `Material = Enum.Material.Fabric` + `Color = (255, 255, 255)`.

## Local artifacts

- Manifest entry: `tools/blender/scenes.json` -> `"palm-tree-1"`
- Source GLB: `assets/models/palm-tree-1/source/Palm_Tree_1.glb` (`17,295,944` bytes; SHA-256 `143fccbd8e33baa120a5d0c81b4559ac6f6f28fd2bb0034d869f76616a07423b`; `295,281` tris)
- Appraisal: `assets/models/palm-tree-1/appraisal.json` and `assets/models/palm-tree-1/views.png`
- Export GLB: `assets/models/palm-tree-1/exports/PalmTree1.glb` (`3.13 MB`, `27,881` tris across 4 meshes: `geometry_0.001` `7,923`, `geometry_0.002` `4,905`, `geometry_0.003` `8,949`, `geometry_0.004` `6,104`; single shaded opaque `1024x1024` RGB `image/png`)
- Opaque shaded matte processor: `assets/models/palm-tree-1/make_opaque_matte.py`
- Studio physics/attribute helper: `assets/models/palm-tree-1/SetupDecoration.luau`

## Roblox IDs and verification status

- Latest Open Cloud upload (`.\tools\roblox\upload_asset.ps1 -Name "PalmTree1_ShadedMatte"`):
  - **Root Model Asset ID:** `84316532447768` (`moderationState: Approved`, SHA-256 `ebbfb5efb079eeffd2a1552183b3f448b1d1b987b8981a24ea7fefd953f0f66f`)
  - *(Supersedes prior flat-lit matte upload `86353472484125` and initial translucent upload `83201972379597`)*
  - **Uploaded MeshPart `MeshId`s** (verified via `InsertService:LoadAsset(84316532447768)` in Studio Edit mode; `0` child `SurfaceAppearance` instances):
    - `geometry_0.001`: `rbxassetid://78980782799662`
    - `geometry_0.002`: `rbxassetid://118444302495828`
    - `geometry_0.003`: `rbxassetid://89309762934764`
    - `geometry_0.004`: `rbxassetid://133776163275473`
  - **Shaded opaque diffuse `TextureID`:** `rbxassetid://115128353982109` (`Material = Fabric`)
- **Baked map integration:**
  - Updated all 6 `*_PalmTree1` Models in `assets/environment/source/FiveIslands.rbxm` (`Geometry > NatureAndLights`) with `SourceAssetId = "84316532447768"`, `TextureContent = rbxassetid://115128353982109`, and `Material = Fabric`.
  - Baked cleanly via `.\tools\save_map.cmd FiveIslands` (`src-ad11033138`, `923` parts, `3` objectives, `6 + 6` spawns).
- **Pending checks (requires user / Studio Play restart):**
  - Live viewport render inspection in Studio / Play (`rojo serve` running + Play restarted).
