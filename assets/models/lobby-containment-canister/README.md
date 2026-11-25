# Lobby containment canister

`exports/LobbyContainmentCanister.glb` is the reference-led high-detail local candidate. The unchanged `source/trellis-original.glb` came from `Lobby/sample_2026-11-09T205221.614.glb`. After the first opaque-blue export, the user supplied `source/reference-clear-blue-chamber.png` and asked for that appearance. The new version preserves the original dark mechanical end caps but replaces the cloudy opaque middle with separate translucent glass, a dark interior, and blue plasma concentrated near the bottom. Its 8-stud height and approximately 4.75-stud diameter are provisional. The bottom cap is grounded. Blender is +Z up and the export is +Y up.

The source has 290,582 triangles in one mesh and two embedded 2048 WebP maps. Textured 15% and 25% reduction trials are preserved under `trials/` and `review/`. The 25% trial retained cleaner cap and ring geometry, so it supplies the top and bottom only. The middle is clean geometry: a translucent shell, faint dark liner, seal and light rings, blue vapor, and a few luminous inner wisps. The revised export has 72,673 triangles across 18 meshes, each below 10,000 triangles. Its three embedded PNGs are the 1024 cap color and packed metal/roughness maps plus the transparent 1086 × 1448 blue energy texture.

The energy sprite was generated with the built-in image tool from the user's reference. Prompt: “Isolate a photorealistic luminous electric-blue plasma vapor plume on transparent background; dense organic smoke at the bottom thinning into upward tendrils; no jar, glass, metal, floor, backdrop, text, or person.” The selected output is stored at `textures/LobbyContainmentCanister_Energy.png`. The crossed planes and 3D wisps are deterministic in the Blender builder.

## Rebuild and check

From the repository root:

```powershell
python tools/build_lobby_containment_canister.py
python tools/build_lobby_containment_canister.py --check-only
```

The wrapper backs up generated outputs under `.mapbuild/lobby-containment-canister/<timestamp>/`, rebuilds the Blender scene and export, renders four textured views from the saved GLB, reappraises it, and writes `validation.json`. `tools/blender/build_lobby_containment_canister.py` is the procedural source; direct edits to `source/LobbyContainmentCanister.blend` will be overwritten by a rebuild.

The saved GLB renders with transparency and a blue lower plume in Blender. ENGAGE Studio import on 2026-11-09 flattened untextured material colors and transparency to opaque gray; the Studio helper below restores the intended appearance. The corrected canister was inspected from front, side and rear. This is a high-detail feature prop; lower graphics quality and performance at multiple placements remain unverified. See `HANDOFF.md` for stage status and the next action.

`SetupChamberMotion.luau` is the required Studio appearance and setup helper for the animated version: it sets colors, transparency, decoration physics, slow rising vapor and a small core light together. Motion is a Roblox particle effect, not an animation inside the GLB. The image already used by the static energy planes is reused from its uploaded ColorMap. The helper was run in ENGAGE Edit mode and the particle effect was visually isolated in Play; see `STUDIO_SETUP.md`. `SetupDecoration.luau` remains available for a static version, but it does not restore the Studio material colors.

The current ENGAGE lobby placement is saved in `assets/environment/source/Lobby.rbxm` and its validated baked copy: `Geometry.Cannister.BlueContainmentCanister`, pivot `(-2, 400, 984)`, approximately 31 studs high. The original 8-stud GLB remains available for a differently sized placement. See `review/lobby-placed-play.jpg` and `HANDOFF.md` for the Play test and remaining review.
