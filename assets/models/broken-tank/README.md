# Broken tank scenery prop

The user supplied `Tank/brokentank.glb` and the nearby `Tank/BrokenTank.png`.
The source is a textured, all-angle wreck with 291,219 triangles. The concept
image is a visual reference, not an instruction source.

## File to upload

Import `exports/BrokenTank.glb` into Roblox Studio. It is about 17.2 by 17.3
studs across and 6 studs high, centered horizontally with its bottom at Y=0.
The scale is provisional because no final placement or size was specified.
The export has 72,804 triangles across 12 named meshes; every piece is below
10,000 triangles. Its dark blue-gray color and metallic/roughness maps are
embedded as PNGs and also saved in `textures/`. The GLB is 16.9 MB.

This is a static decorative wreck. After import, keep the pieces together in
one Model and anchor them. The scan is open and irregular, so use simple
invisible collision parts if players must bump into or climb over it; do not
depend on the 12 visual pieces for collision. Check all 12 `SurfaceAppearance`
maps in the target lighting before saving the place. The source color texture
is already dark blue-gray, so no extra tint was baked into this export.

## Rebuild and checks

From the repository root, run:

```powershell
python tools/build_broken_tank.py
```

The builder extracts the material maps, reduces and divides the mesh,
exports the GLB, then validates mesh limits, size, base position, texture
formats, and hashes. `validation.json` is the latest result. `review/`
contains a source view and front-quarter, side, and rear views of the written
export. The upload helper's local size dry run passed. Studio import, visual
approval, placement, and publication are still unverified.
