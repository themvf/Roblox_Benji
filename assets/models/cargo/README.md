# Destroyed cargo unit: optimized TRELLIS prototype

**Continuing this work? Read [HANDOFF.md](HANDOFF.md) first.**

Status: revised prototype awaiting visual approval. The earlier export was accepted by
Studio's Import Queue on 2026-09-28; this revised export has not been imported,
placed, or verified in Studio.

## Sources

- `source/design-reference.png`: Midjourney "Destroyed cargo unit" (d8366663,
  variant 0), copied unchanged from `Cargo/`. The TRELLIS model matches it.
- `source/trellis-original.glb`: copied unchanged from
  `Cargo/sample_2026-09-27T180812.345.glb`. It is the bake source.
- Other images and `Cargo/sample_2026-09-27T175344.993.glb` in `Cargo/` were
  not used. They are different cargo designs or variants.

## Deliverables

- `exports/CargoDestroyed.glb`: 7,470 triangles, one mesh, one material, 3.9 MB.
- Bounds (glTF/Roblox): X -5.16..5.16, Y 0..6, Z -2.56..2.56. Bottom-centre pivot.
  Long sides face +/-Z.
- Embedded 1024 PNG colour, packed metallic/roughness and normal maps. Separate
  copies are `textures/Cargo_Color.png`, `Cargo_Normal.png`, `Cargo_Roughness.png`
  and `Cargo_Metalness.png`.
- `source/Cargo.blend`: dense source in SOURCE (hidden), low mesh visible.
  The generator `tools/blender/build_cargo.py` is authoritative.
- `review/prototype-{front,front-quarter,rear-quarter,end}.png`: textured renders
  of the final GLB at true scale.
- `trials/CargoDestroyed-pre-warm-20260928.glb` and its front-quarter preview:
  preserved copy of the earlier file that Studio accepted.
- `SetupCargo.luau`: Studio Command Bar helper for the selected unit.

## Rebuild

```text
python tools/build_cargo.py              # backup, author+bake, export, appraise, render, validate
python tools/build_cargo.py --check-only # validate current files only
```

The full build takes about 6 minutes on CPU, mostly the four bakes and renders.
Backups and per-stage logs are written to `.mapbuild/cargo/<timestamp>/`.

## Method and experiment history (2026-09-27)

- Source: 294,974 triangles, two 2048 WebP textures. Renders are
  `review/source-a..d.png`. Silhouette, straps, corner blocks and torn top read well.
- Direct collapse to 9,000 (`trials/decimate_trial.py`) kept the shape but
  shattered the shading (`review/trellis-decimate-9000.png`).
- First bake rounds failed. A DIFFUSE colour bake is black on metallic surfaces.
  Smart UV and cube projection on the collapsed triangle soup gave thousands of
  shards. Welding before collapse stalled it at 41,907 triangles.
- Working method: voxel remesh (0.004 source units) into one manifold shell,
  4-degree planar dissolve, collapse to 7,500. Then smart UV, then
  selected-to-active bakes of normal and roughness. Colour and metalness are
  baked as emission of the source inputs.

## Known limitations

- The 2026-10-11 bake grades the TRELLIS blue-grey toward the warm brown-grey
  Midjourney reference. The latest views are agent-reviewed; user approval is pending.
- The remesh closes very thin gaps. The holes in the top survive, but small
  cracks are carried by the textures only.
- There is no collision proxy. The collision role is still an open decision
  (see HANDOFF.md).
