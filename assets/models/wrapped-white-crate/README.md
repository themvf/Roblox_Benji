# Wrapped white crate

Two Roblox-ready cargo variants derived from the supplied pair of wooden crates: one covered with white plastic film, and one plain with the wood and pallet visible.

## Files

- `exports/WrappedWhiteCrate.glb`: fully wrapped variant for Studio's 3D Importer.
- `exports/PlainWoodenCrates.glb`: plain wooden crates and pallet with no plastic, as a separate Studio import.
- `review/front-quarter.png`, `review/rear-quarter.png`, `review/right-end.png`, `review/top.png`: wrapped variant previews.
- `review/plain-front-quarter.png`, `review/plain-rear-quarter.png`, `review/plain-top.png`: plain variant previews.
- `source/WrappedWhiteCrate.blend` and `source/PlainWoodenCrates.blend`: editable Blender scenes. `tools/blender/build_wrapped_white_crate.py` generates the source wood and film; `tools/blender/build_plain_wooden_crates.py` extracts the same verified wood geometry for the plain variant.
- `source/trellis-original.glb`: untouched supplied GLB. `textures/` contains extracted wood and generated film maps.
- `appraisal.json`, `validation.json`, `trials/`: source assessment, local check results, and rejected reduction evidence.
- `SetupDecoration.luau` and `SetupPlainDecoration.luau`: optional, variant-specific Studio Command Bar helpers after import, for static noncolliding props.

Approximate wrapped size: 8.29 × 3.94 × 4.12 studs, eight mesh parts. Approximate plain size: 7.95 × 3.84 × 3.77 studs, two mesh parts. Both have a ground-level pivot, embedded PNG textures, and meshes below 10,000 triangles. Import the chosen GLB as a Model in Stud units and inspect it before placement. Neither version has gameplay behavior.

From repository root, run `python tools/build_wrapped_white_crate.py --check-only` to verify both saved variants, or `python tools/build_wrapped_white_crate.py` to back up and regenerate both models and previews. The rebuild requires Blender 4.3.2 and writes a backup under `.mapbuild/wrapped-white-crate/`.

See `HANDOFF.md` for stage status and next action.
