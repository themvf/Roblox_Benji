# Sci-fi chair prototype

Read [HANDOFF.md](HANDOFF.md) before continuing. The delivery candidate is
`exports/SciFiChair.glb`, approved for appearance and five-stud height by the user
on 2026-10-10. Studio import remains unverified. `approval.json` binds that
approval to the exact export hash.
The original TRELLIS GLB and Midjourney design image are unchanged in `source/`.

## Rebuild and check

From the repository root with Blender 4.3.2 and Python 3:

```powershell
python tools/build_sci_fi_chair.py
python tools/build_sci_fi_chair.py --check-only
```

The first command backs up generated artifacts and logs under
`.mapbuild/sci-fi-chair/<UTC timestamp>/`, authors the Blender file and final GLB,
renders four textured views from the **written GLB**, then validates it. It never
uploads or alters Studio. `tools/blender/build_sci_fi_chair.py` is the authoritative
editable recipe. Manual changes to `source/Chair.blend` will be replaced on rebuild.

## Production contract

- Approved size: 5.0 studs tall, about 3.91 wide and 3.01 deep. One Blender
  unit is scaled to five studs from the generated source's one-unit height.
- glTF/Roblox axes: Y up; the seat faces +X. Pivot: ground at Y=0, horizontally
  centered. Import with Studio Scale Unit **Stud**.
- Three MeshParts, 8,910 / 8,911 / 8,911 triangles, one shared material.
- Embedded 2048 PNG color and metallic/roughness maps. Named copies are in
  `textures/`. UVs and surface color come from the supplied TRELLIS source.
- Decoration role approved by the user on 2026-10-10. `SetupDecoration.luau` sets selected imported parts
  anchored and non-colliding. A usable Roblox Seat and player interaction have
  not been authored.

## Geometry decision

The source has 297,023 triangles. A single-mesh 8,613-triangle trial visibly
cracked and faceted the back panel (`review/trial-*.png`). A 26,732-triangle
trial held the reference silhouette and padded forms (`review/trial-27000-quarter.png`).
The builder uses that reduction and divides the unchanged resulting triangles
into three spatial bands, each below Roblox's per-mesh limit. The division adds
no geometric cuts. Four final GLB renders are in `review/final-*.png`.

## Known limits

The generated surface retains small rough seams and irregularities, especially
around the arm edges and rear. The reference is a single front-quarter image,
so unseen surfaces are based on the supplied source. Studio texture loading,
physics, and map placement are not verified.
