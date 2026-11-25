# Ransacked small orange cargo box

**Read [HANDOFF.md](HANDOFF.md) before continuing.** Current status: locally
verified model awaiting visual approval. Studio import and map integration
have not been verified.

## Files

- `source/design-reference.png`: matching Midjourney white/charcoal/orange
  cargo-box image from `Cargo/`.
- `source/trellis-original.glb`: byte-identical copy of
  `Cargo/smallorangebox.glb`; `source/trellis-appraisal.json` preserves its
  measurements and the earlier purpose decision. `source/trellis-basecolor.png`
  is the extracted original color texture used for fine surface variation.
- `source/OrangeBox_Ransacked.blend`: editable authored parts plus joined
  export. The generator `tools/blender/build_orangebox_wrecked.py` is the
  authoritative source; rebuilding overwrites manual `.blend` changes.
- `exports/OrangeBoxRansacked.glb`: **current delivery candidate**. One
  9,011-triangle mesh and one material, 3.8 studs tall with bottom pivot.
  White chipped shell, dark frame, orange accents, open side/end, peeled lid
  and ransacked contents, with a partial blast through the upper near wall
  and front roof rail. The opened door and attached fragments widen the
  footprint to about 6.88 x 5.31 studs.
- `textures/OrangeBox_{Color,Roughness,Metalness,Normal}.png`: 1024 texture
  atlas sources. The GLB embeds color, packed metallic-roughness and
  tangent-space normal PNG maps.
- `review/ransacked-{front-quarter,side,end,rear}.png`: textured views of
  the **written GLB**. `review/legacy-quarter.png` shows the prior export.
- `trials/OrangeBox_legacy_9000.glb`: preserved earlier optimized model.
  The original `OrangeBox.glb` at the package root is also retained for
  historical recovery; neither is a current delivery file.
- `trials/OrangeBoxRansacked_v1.glb` and its quarter preview: preserved
  simpler first rebuild, before the user requested more detail.
- `trials/OrangeBoxRansacked_v2_detail.glb` and its quarter preview:
  preserved detailed version before the partial-blast pass.
- `trials/OrangeBoxRansacked_v3_blast.glb` and its quarter preview:
  preserved partial-blast version before the realism pass.
- `SetupOrangeBox.luau`: scoped Studio Command Bar helper for one selected
  imported mesh. Decoration is provisional until the user chooses its role.

## Build and verification

```text
python tools/build_orangebox_wrecked.py
python tools/build_orangebox_wrecked.py --check-only
```

The first command backs up generated outputs under `.mapbuild/orangebox-wrecked/`,
authors the mesh and textures in Blender 4.3, appraises the exported GLB,
renders four views, and validates the written file. It does not import into
Studio, place the model, or publish the game. `validation.json` has hashes,
measurements and current verification limits.

## Design and known limits

The old 9,000-triangle `scene_kit` reduction retained the closed reference
shape and color but its small manufactured panels looked softened in the
textured view. The user then asked to continue the weathered, broken cargo
series with this asset. Clean geometry makes the side aperture, forced end
door and visible contents unambiguous. The reference's white case, orange
latches and charcoal frame remain recognizable.

The 2026-10-11 detail pass added modeled roof ribs, orange service slats,
vents, panel seams, fasteners, latch controls, hinge pins, base grilles,
an instrument housing, case clasps and loose cartridges. The four current
previews were inspected after rebuilding from the written export. The
surface detail is carried by geometry and the color/roughness atlas.

The later partial-blast pass broke the front roof rail and upper near wall,
then added asymmetric soot, exposed rusty metal, bent and sheared plates,
a damaged hinge and a few attached fragments near the base. The far wall
remains comparatively intact so the damage reads as localized. The current
export stays below Roblox's 10,000-triangle limit by 811 triangles.

The 2026-10-12 realism pass uses fine variation from the original TRELLIS
texture, varied exposed-metal roughness and a normal map. It also grounds
loose fragments and removes an overly flat scorch sheet. The damaged side
and end are the intended presentation angles; the reverse side is calmer.
The look remains stylized. The 3.8-stud height and non-colliding decoration
setup are provisional; user visual approval and Studio checks are separate
stages.
