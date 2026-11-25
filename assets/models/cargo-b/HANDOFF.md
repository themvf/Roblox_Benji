# Resume here: white cargo unit, ransacked revision

## Current truth and next action (2026-10-11)

The user asked to “fix this one” for
`Cargo/sample_2026-09-27T182032.482.glb` after asking that the cargo assets
look more weathered, broken and ransacked. The selected file matches the
existing cargo-b intake exactly: SHA-256
`c768671f5c5e8d87837b0fed4ec02abb87b3ef64810c5d0096b090fa56d1ad54`.
Before changing it, `python tools/build_cargo_b.py --check-only` passed for
the old intact package. The old export is preserved at
`trials/CargoUnit_intact_20260928.glb` (SHA-256
`9bcf63d83e5d7e9a9ca731085780c0596d512dfe4dcbd3142e425e13c5c691b5`)
with its front-quarter preview in `trials/`.

The intact voxel result could not convey the new damaged brief. A clean
hard-surface revision now keeps the white ribbed panels, dark corner caps,
roughly six-stud height, and rectangular proportions from the Midjourney
reference, while adding a real torn side opening, pried metal edges, roof
tear, forced end doors, a detached door, opened cases, a fallen rack, bent
shelves and loose scrap. The reproducible source is
`tools/blender/build_cargo_b_wrecked.py` and `source/CargoB_Wreck.blend`;
`python tools/build_cargo_b_wrecked.py` runs the full local pipeline.

**Stage 4 passed for the new `exports/CargoUnit.glb`.** Full authoring,
appraisal and four rendered views passed; a separate
`python tools/build_cargo_b_wrecked.py --check-only` passed afterward.
`validation.json` records the hashes and measurements. Current export SHA-256
`6a79edf82f87fe275ec741a84adcb34316aac2be040eab00268257ea48e020a6`;
3,508 triangles, one mesh/material, two embedded 1024 PNG maps, 1.41 MB,
bounds X -4.6871..4.6871, Y 0..6, Z -3.1139..3.1139, bottom-centred pivot.
The wider footprint includes the opened door. The separate texture sources
are in `textures/CargoB_Wreck_*.png`.

`lune run tools/check_assets.luau` could not start in this sandbox: Lune
panicked while canonicalizing the current directory with Windows access
denied (OS error 5). This is a tool-environment limit, not a passing asset
gate. The export's independent GLB and file checks passed as stated above.

All four `review/wreck-*.png` views were opened. Agent assessment, **not user
approval**: the side and end apertures show the fallen contents, and chips,
scrapes and dark exposed metal make the new unit read as ransacked. The far
side and rear are calmer, so orient the damaged side toward the intended
viewpoint. This is a stylized clean rebuild and the chipped atlas is more
graphic than the old baked TRELLIS surface.

**Stage 5 visual approval is next.** Show the front-quarter, side and end
views to the user and record whether the weathering/damage are right. Six
studs and decoration collision role are still provisional. The new GLB has
never been imported into Studio. The prior intact GLB repeatedly failed in
Studio's Import Queue at 71%, so that history does not verify or condemn this
different file. After visual approval, try importing this new GLB once with
Stud units and verify owner, mesh/texture IDs, materials, six-stud height and
physics; use `SetupCargoUnit.luau` on the selected mesh. Map placement and
restart testing are still a separate final stage.

## Prior intact prototype and Studio history

### Record as of 2026-09-28

Stage 4, local verification, has passed. Stage 5, visual approval, is next and
needs the user.

The user chose this GLB (`Cargo/sample_2026-09-27T182032.482.glb`) and asked for it
to be taken through the pipeline. That settles which asset. The user has **not**
approved the look, the six-stud height (8.2 x 4.8 x 6 studs) or the role. The agent
chose those and they are unconfirmed.

The delivery file is `exports/CargoUnit.glb`, SHA-256
`9bcf63d83e5d7e9a9ca731085780c0596d512dfe4dcbd3142e425e13c5c691b5` (3.86 MB).
Nothing in `trials/` is a delivery file. Local checks passed:

- 7,498 triangles, within the 8,000 budget and the 10,000 Roblox per-mesh cap.
- One mesh and one material.
- Three embedded 1024 PNG maps: colour, packed metallic/roughness, and normal.
- Bottom-centre pivot, height exactly 6, centred on X and Z.
- Long axis on X, which the wrapper now asserts.

Evidence is `validation.json` (`checkedAtUtc` `20260928T210937844018Z`, status
`passed`), `appraisal.json`, `source/build-metrics.json`, the per-stage logs under
`.mapbuild/cargo-b/20260928T210937844018Z/`, and the four `review/prototype-*.png`
renders, all of which were viewed. `lune run tools/check_assets.luau` reports
`OK assets/models/cargo-b`.

No Studio import, upload, asset IDs, owner, physics or placement has been observed.
Nothing was committed.

## Stage 6 attempt 1: FAILED on Roblox's side, not ours (2026-09-28)

The user imported this GLB through Studio's 3D Importer, in a batch with
`assets/models/cargo/exports/CargoDestroyed.glb` and
`assets/models/desk/exports/Desk.glb`. Observed from a screenshot of the Import
Queue: the other two show green/success, this one shows failure.

    CargoB_Baked
    PublishService AssetUpload failed. Info: Unknown Error ErrorCode: Internal
    Operation Id: 116f605a-c102-441e-946f-c54e29e8c027

This is not a problem with `exports/CargoUnit.glb`, and the file must not be
rebuilt in response to it. Checked directly against the sibling file that
succeeded in the same batch:

| | CargoUnit.glb (failed) | CargoDestroyed.glb (succeeded) |
|---|---|---|
| materials | 1, `CargoB_Baked` | 1, `Cargo_Baked` |
| meshes | 1, `geometry_0.001` | 1, `geometry_0.001` |
| images | 3 x 1024x1024, 8-bit RGB PNG | 3 x 1024x1024, 8-bit RGB PNG |
| bytes | 3,861,248 | 3,947,368 |

Identical structure, and the failing file is the smaller one. A malformed mesh or
an unsupported texture produces a parse or validation message; `ErrorCode: Internal`
with an Operation Id is Roblox's backend reporting a server-side fault. The error
names the material, so the geometry was accepted and the upload died on the texture
set. Most likely cause is upload throttling or a transient backend fault: that one
queue submitted 3 meshes and 9 textures at once.

## Stage 6 attempts 2+: reproducible, stalls at 71% (2026-09-28)

Unbatched retries fail the same way and stall at 71% every time. That is not a
corrupt byte partway through the file: the importer publishes the mesh and then each
image, so every upload failure in that sequence surfaces at the same percentage,
which is simply where it waits on the network.

The mesh has been cleared as a suspect by reading the written file directly and
comparing it with the sibling that uploaded successfully:

| | CargoUnit.glb (fails) | CargoDestroyed.glb (uploaded) |
|---|---|---|
| vertices | 13,241 | 12,473 |
| triangles | 7,498 | 7,470 |
| degenerate triangles | 0 | 0 |
| normals | all unit length | all unit length |
| UV range | u 0.004..0.996, v 0.006..0.996 | u 0.004..0.986, v 0.004..0.996 |
| non-finite values | none | none |
| attributes | POSITION, NORMAL, TEXCOORD_0 | POSITION, NORMAL, TEXCOORD_0 |

Clean, in range, and near-identical to a file Roblox accepted. So the remaining
suspect is the texture publishing, and the next step is a diagnostic that splits the
publish sequence rather than another blind retry.

`assets/models/cargo-b/trials/strip_textures.py` writes two reduced copies from the
existing export. Regenerate them with
`python assets/models/cargo-b/trials/strip_textures.py`. Neither is a delivery file:

- `trials/CargoUnit_MeshOnly.glb`, 0.47 MB, zero images, 7,498 triangles, height 6.
  If this imports, the mesh is fine and the fault is in texture publishing.
- `trials/CargoUnit_ColorOnly.glb`, 1.52 MB, one image, 7,498 triangles, height 6.
  If this imports but the full export does not, the constraint is the number or
  total size of the texture uploads, not their content.

Both were verified after writing: geometry intact, bottom pivot, height exactly 6,
and `CargoUnit_ColorOnly.glb` still has `baseColorTexture` wired.

Interpreting the result:

- MeshOnly fails too: the problem is not textures at all, and the account or the
  Roblox backend is the thing to investigate. Try a different upload path, the
  Asset Manager or the Creator Dashboard, which does not go through the 3D
  Importer's `PublishService` call.
- MeshOnly succeeds, ColorOnly fails: a single texture upload is failing. Check
  account upload limits and moderation.
- Both succeed, the full export fails: deliver with fewer maps as a fallback.
  Dropping the baked normal map is a real quality loss, not a free win, because at
  7,498 triangles the normal map carries most of the panel relief. Prefer retrying
  the full set later over shipping the flatter version.

Do not rebuild `exports/CargoUnit.glb` in response to any of this. Its hash is
unchanged at `9bcf63d8...c5c691b5` and `--check-only` still passes, so a rebuild
reproduces the same bytes.

## Agent assessment of the renders (not user approval)

Compared against `source/design-reference.png` and the dense `review/source-*.png`:

- Holding up: silhouette, dark corner caps top and bottom, double-door hardware on
  the +X end, vertical rib panels on the long sides, base skid with vent slots, top
  ribs. The white-and-dark-grey colour tracks the reference closely, noticeably
  better than the destroyed unit, whose bake came out too blue.
- Softer than the source: the voxel remesh rounds the crisp chamfers, the rib
  panels are lower in contrast than `review/source-c.png`, a few shallow top
  recesses read as dark openings in the rear quarter, and the bottom corners bulge
  slightly. All are recorded in README.md with the levers to change them.

## Decisions made so far

- Optimization, not a rebuild. The silhouette is a plain box and survives
  reduction, so the shape is kept and the detail is baked from the dense source.
  Method and tunings are in README.md.
- Tiling was rejected. The 10,000 cap is per mesh and tiling beats decimating for
  broad ground, but this is a single hand-scale prop.
- `source/design-reference.png` is the matching Midjourney image (807ce1a0
  variant 1). Variants 0 and 3 are a different container and a hard case.
- Six studs tall, to match `assets/models/cargo` so the two read as one family.
- The destroyed unit in `assets/models/cargo` is a separate package at the same
  stage. Approving one does not approve the other.

## Questions for the user (stage 5)

1. Is the look in `review/prototype-front-quarter.png` right? Specifically, are the
   softened edges acceptable, or should it be sharper at the cost of a harsher
   collapse?
2. Is six studs tall right? A character is about 5, so it blocks sight lines.
3. What is its role? Options:
   - Non-colliding decoration. This is the current `SetupCargoUnit.luau` default.
   - A solid prop (`SOLID = true`).
   - Gameplay cover. Cover must be authored as map Lua blocks, not decor.
4. Which map will it go on? Should the remaining `Cargo/` designs follow?

## Next engineer's first steps

1. Read this file, `README.md` and `validation.json`.
2. Run `python tools/build_cargo_b.py --check-only`.
3. Record the answers above here. Change the output only through
   `tools/blender/build_cargo_b.py`, rebuild, and view the renders again.
4. After approval, import `exports/CargoUnit.glb` with **Stud** units and check the
   textures and the height of 6. Use Studio's 3D Importer, not Insert -> Model from
   File: that dialog filters to `.rbxm`/`.rbxmx` and will not list a `.glb`.
5. Select only the unit and run `SetupCargoUnit.luau` from the Command Bar.
6. Place it using `assets/environment/decor/README.md`, preserving the existing
   decor. Restart the map to verify, then record IDs and evidence below.

## Do not repeat failed work

- Do not set `rotation_euler` on a glTF-imported object. The importer leaves
  `rotation_mode` on QUATERNION, so the euler is never read; `transform_apply` then
  returns `FINISHED` and zeroes the euler while the vertices never move. This cost
  one full build cycle. Transform the mesh data instead:
  `ob.data.transform(mathutils.Matrix.Rotation(...))`. Verified in Blender 4.3.2.
  `scene_kit.py`'s `op_orient` has the same latent bug; it is harmless only because
  no GLB manifest entry currently sets `up` to anything but `z`.
- Do not trust `ob.dimensions` after a mesh-data transform. It is a cached
  `bound_box` and does not refresh, so a working rotation looks like a no-op. The
  generator's `spans()` reads the vertices directly; use it.
- Do not bake colour with DIFFUSE. It is base x (1 - metallic), so metal bakes black.
- Do not collapse the raw TRELLIS soup or weld it before collapse. Remesh first.
- Negative preview coordinates need the `--eye=-12,9,15` form, not `--eye -12,...`.
- Write JSON from Python or an editor, not PowerShell 5 `Set-Content -Encoding utf8`,
  which adds a BOM that breaks the wrapper's JSON reads.
- `check_assets` reports cargo-b as OK. It still exits non-zero because of the
  pre-existing missing `assets/scenery/mud-grassland/appraisal.json`, which is
  unrelated to this package.

## Transfer

Keep this package together with `tools/build_cargo_b.py`,
`tools/blender/build_cargo_b.py`, the `cargo-b` entry in
`tools/blender/scenes.json`, and the shared Blender tools (`scene_kit.py`,
`preview_scene.py`, `appraise_asset.py`, `gltf_post.py`). All of it is uncommitted
local work; commit or back up for off-machine recovery. `Cargo/` was left untouched.
Do not put credentials in the handoff.

## Studio record (fill only from observed evidence)

- Stage: 4 passed 2026-10-11 for the ransacked revision. Stage 5 visual approval
  pending. Stage 6 untested for this new hash. The earlier intact hash had
  repeated `PublishService` `Internal` failures at 71%; the diagnostic files
  remain in `trials/` if that specific problem needs investigation.
- Asset selected by the user: yes, 2026-09-28.
- Visual approval: pending
- Asset owner: unknown
- Mesh and texture asset IDs: unknown
- Target map and decor file: unknown
- Imported size / textures: unverified
- Physics settings: unverified
- Restart persistence / published game: unverified
