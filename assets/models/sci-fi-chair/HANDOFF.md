# Resume here: sci-fi chair

## Current truth (2026-10-10)

The user requested a **Roblox-ready asset** from `Chairs/scifichair.glb`. The approved delivery file is `exports/SciFiChair.glb`, SHA-256 `c2c958617df168f0be089654c6468264eb2f09f33cc915fd37b16a089b735f7c`. The original TRELLIS GLB and matching Midjourney image are unchanged in `source/`. On 2026-10-10 the user chose **decoration** as its role, then approved the presented appearance and five-stud height ("yes"). `approval.json` binds these decisions to this exact GLB. Do not add a usable Seat or regenerate this approved asset without a concrete defect or change request. The non-colliding Studio helper remains an implementation choice until Studio verification.

Stages 1-5 (intake, authoring, export, local verification, user visual approval) have evidence. No Studio import, upload, ownership/texture verification, physics configuration, map placement, runtime test, or publication has been observed. Do not infer any of those from the local check.

## Evidence and geometry decision

- `appraisal.json` and `views.png`: Blender 4.3.2 appraisal of the original source. One mesh, 297,023 triangles, UVMap, two embedded WebP images, 178,393 open edges. The textured source sheet was opened and compared with the supplied design image. It depicts the intended chair and no obvious unrelated props.
- `trials/decimate-8500.glb` and `review/trial-*.png`: single mesh at 8,613 triangles. The padded back visibly cracked and faceted; rejected.
- `trials/decimate-27000.glb` and `review/trial-27000-quarter.png`: 26,732 triangles. The silhouette, angled arms, headrest, seat, and base remained close to the source at the preview scale. Accepted as the geometry method for this prototype.
- `tools/blender/build_sci_fi_chair.py`: reproducibly decimates at 0.09, scales to five studs, divides the retained triangles into three spatial bands without moving vertices, converts both mapped WebP images to PNG, and writes `source/Chair.blend` and `exports/SciFiChair.glb`.
- `review/final-{front,side,rear,quarter}.png`: textured views **reimported from the final GLB**. All four were opened. The design reads as a sci-fi chair from every view. Small generated-surface roughness and specks remain, especially on the arms and rear. The user approved the appearance shown in the final-quarter preview on 2026-10-10.
- `python tools/build_sci_fi_chair.py` passed as a complete rebuild; `python tools/build_sci_fi_chair.py --check-only` passed afterward. `validation.json` records the UTC check time, hashes, bounds, image format, and limitations. Backup and logs: `.mapbuild/sci-fi-chair/20261010T230238009342Z/`.
- `lune run tools/check_assets.luau` could not start in this sandbox: Lune panicked while canonicalizing the current working directory with Windows `Access is denied`. This is a tool/environment limitation, not a passing gate result; rerun it in an unrestricted repository shell before commit.

## Production contract

- GLB glTF axes: Y up, chair front faces +X. Ground pivot at Y approximately zero, centered horizontally.
- User-approved height: five studs. Bounds X -1.945 to 1.965, Y 0.003 to 5.000, Z -1.507 to 1.507 studs. Import with Studio Scale Unit **Stud**.
- Mesh triangles: 8,910 / 8,911 / 8,911. One shared material; two embedded 2048 PNG maps. Final GLB is 7,480,336 bytes.
- User-approved role: decoration; no Seat instance or interaction. `SetupDecoration.luau` configures only a selected imported three-part model as anchored and non-colliding. The GLB does not enforce Roblox physics.

## Next action

1. The approved file is saved at `assets/models/sci-fi-chair/exports/SciFiChair.glb` (absolute path under this repository). Give this file, not a trial GLB, to the Studio importer.
2. Check whether the user has already imported this exact export. Reuse an existing upload if one exists. Import with Stud units only if needed, verify the actual appearance, texture loading, size, pivot, owner, and asset IDs in Studio.
3. Configure decoration physics. If placed in a map, use its saved decor collection without replacing existing decor, restart the map, and record runtime evidence and IDs here.

## Source identity and recovery

- `source/trellis-original.glb`: SHA-256 `747e06dda5a8d5d873a84a1f15a63d81612d040d7afaaa276a7494da5ea18af4`.
- `source/design-reference.png`: SHA-256 `3a1766ed46439f5325b249bd2893ec2db137fc5d91aaf07477f5b4aa3b0c3cc3`.
- Rebuild from the repository root: `python tools/build_sci_fi_chair.py`; inspect generated views after any change. Check existing files without rebuilding: `python tools/build_sci_fi_chair.py --check-only`.
- The original `Chairs/` files are untouched. The package and scripts are local uncommitted work, so commit or project backup is still needed for off-machine recovery.

## Studio record (fill only from observed evidence)

- Asset owner / mesh and texture IDs: unknown.
- Imported five-stud size, orientation, and texture appearance: unverified.
- Decoration role: approved 2026-10-10. Non-colliding Studio physics: unverified. Interactive seat: intentionally absent.
- Destination map and decor file: unknown.
- Restart persistence and published game: unverified.
