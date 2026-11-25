# Resume here: ransacked small orange cargo box

## Realism revision, current candidate (2026-10-12)

The user asked for a more realistic version of the partial-blast box. The
previous blast export (SHA-256
`13322f33c34d35316e48f9cd45335552b5560c7568093ca094be4d8bb12def1e`)
and its front-quarter render are preserved in
`trials/OrangeBoxRansacked_v3_blast*`. The user has not visually approved a
version, and no Studio import or map placement is verified.

The current build retains the broken roof rail, torn side, forced door and
visible contents. It extracts the original TRELLIS color image to
`source/trellis-basecolor.png` and uses its fine surface variation in the
authored atlas. Exposed chips now have varied metalness and roughness, a
tangent-space normal map gives the paint shallow surface depth, and the
palette and soot are less stark. Floating bent strips and an oversized flat
scorch sheet were removed; fragments outside the box were lowered to the
ground. The four current `review/ransacked-*.png` images were rendered from
the written GLB and inspected. Agent assessment: the wear reads more like
painted, damaged metal while keeping the orange-box identity. Visual
approval remains pending; the model still has a stylized hard-surface look.

**Stage 4 local verification passed:** the full
`python tools/build_orangebox_wrecked.py` author, appraisal, four-view
render and validation pipeline passed. The current
`exports/OrangeBoxRansacked.glb` SHA-256 is
`51ee49cdfbd6ce7e0b594ae34d8dc0fa1c50091e6e2be3e449a2d15e01b5efe7`.
The written export has 9,011 triangles, one mesh/material, three embedded
1024 PNG maps (color, metallic-roughness and normal), 2,949,480 bytes, a
bottom pivot and 3.8-stud height. Bounds in glTF/Roblox axes are X
-3.4379..3.4379, Y 0..3.8, Z -2.6526..2.6526. Exact file hashes and
limitations are in `validation.json`. A subsequent `python
tools/build_orangebox_wrecked.py --check-only` also passed against the saved
files.

**Next action:** show the current front-quarter, side and end previews for
stage 5 visual approval. The 3.8-stud height and decoration role remain
provisional. Once approved, import this exact GLB with Stud units, verify
owner, IDs, materials and physics in Studio, and handle map integration as a
separate stage. The repository-wide Lune gate previously could not start in
this sandbox because Windows denied current-directory canonicalization.

## Previous partial-blast revision (2026-10-11)

The user asked to make the detailed box look “blown up a bit.” The pre-blast
detail export (SHA-256
`b8fb4b51ddfa97750dd84fcf3223bfdb9c112ecfb74d40ed6738997a6a1fdd7b`)
and its quarter preview are preserved in `trials/OrangeBoxRansacked_v2_detail*`.
The earlier simpler ransacked version and original 9,000-triangle TRELLIS
optimization remain in `trials/`. No version has user visual approval or
verified Studio import.

The current builder breaks the front roof rail and upper near wall, leaving
an uneven blast opening. Localized soot, rusty exposed edges, bent and
sheared plates, a damaged hinge, exposed ribs and attached fragments by the
base make the damage read as a partial explosion. The far wall and reference
white/charcoal/orange crate identity remain intact. All four current
`review/ransacked-*.png` views were inspected; the blast is clear from the
long damaged side and front quarter. This is agent assessment, not approval.

**Stage 4 local verification passed:**
`python tools/build_orangebox_wrecked.py` completed authoring, appraisal,
four rendered views and validation end to end after its footprint allowance
was updated for one displaced fragment. The current
`exports/OrangeBoxRansacked.glb` SHA-256 is
`13322f33c34d35316e48f9cd45335552b5560c7568093ca094be4d8bb12def1e`.
It has 9,189 triangles (below Roblox's 10,000-per-mesh cap), one mesh/material,
two embedded 1024 PNG maps, a bottom pivot and 3.8-stud height. Bounds in
glTF/Roblox axes are X -3.4379..3.4379, Y 0..3.8, Z -2.6526..2.6526.
`validation.json` has exact hashes and limits. The first local check failed
only because the old depth allowance ended at 5.3 studs; the fragment made
the measured depth 5.3053. After measuring that fragment, the allowance was
set to 5.6 and the full pipeline passed.

Next action: show the **current** front-quarter and side previews for visual
approval of the blast strength. The 3.8-stud size and role remain provisional.
After approval, import this exact GLB with Stud units, verify owner, asset IDs,
materials and physics in Studio, then handle map integration separately. No
Studio import or placement of this hash has been observed.

## Previous detail revision record

## Previous detail revision (2026-10-11)

The user asked for more detail after seeing the first ransacked rebuild. The
previous GLB, SHA-256
`a161663b9c182fbd8a7bf4e22bc1895f4d68a582aac44a29e2c8837e03402826`,
and its front-quarter preview are preserved in `trials/OrangeBoxRansacked_v1.*`.
No visual approval or Studio import had occurred, so the existing clean
builder was extended rather than starting from TRELLIS again.

The new geometry adds roof ribs and orange service slats, exposed fasteners,
panel reveals, a latch control, bent latch tongues, opening-rim hardware,
base grilles, door vents and hinge pins, a vented instrument panel on the
quiet end, interior tie-downs, case clasps and loose cartridges. The side
and end openings and overall white/charcoal/orange design remain readable
in all four current `review/ransacked-*.png` renders, which were inspected.
The reverse side now has panel seams and an instrument housing. This is the
agent's visual assessment; user approval is still pending.

**Stage 4 passed for the detail revision:** the full
`python tools/build_orangebox_wrecked.py` author/appraise/render/validate run
passed. `exports/OrangeBoxRansacked.glb` has SHA-256
`b8fb4b51ddfa97750dd84fcf3223bfdb9c112ecfb74d40ed6738997a6a1fdd7b`,
7,860 triangles, one mesh/material, two embedded 1024 PNG maps, and a
3.8-stud height with bottom pivot. Bounds in glTF/Roblox axes are X
-3.4379..3.4379, Y 0..3.8, Z -2.5260..2.5260. The latest exact hashes
and limitations are in `validation.json`. Stage 5 visual approval is next;
Studio import, owner, IDs, physics and map placement remain unverified.

The next engineer should run `python tools/build_orangebox_wrecked.py
--check-only`, show the current front-quarter, side and end previews, and
record the user's reaction before any Studio or map work. Keep the prior
versions in `trials/`; they are comparison artifacts, not delivery files.

## Previous ransacked prototype record

## Current truth (2026-10-11)

The user selected `Cargo/smallorangebox.glb` and said “now this one” after
asking that the cargo assets look more weathered, broken and ransacked. The
source SHA-256 is
`7c047dd46eba8482bf2799af0f0122d9eedcfc03b93f4e71f556b30e31bf5ce6`.
It matches the older `assets/models/orangebox/appraisal.json` intake. No
HANDOFF existed before this session, and no user visual or size approval was
recorded. The older appraisal called it a waist-high cover prop, but that was
an agent decision; gameplay role remains unresolved.

The matching Midjourney reference is `source/design-reference.png`. The
original TRELLIS mesh is in `source/trellis-original.glb`, unchanged. The
prior `scene_kit` export, `OrangeBox.glb` in this package root, was a
9,000-triangle mostly closed white/charcoal box with orange accents. Its
SHA-256 is `a11bff9ffce1656e6674916b9f769265450ec41b703c26765a885bd14ec9def0`;
the unchanged file is also in `trials/OrangeBox_legacy_9000.glb`, with its
textured quarter view in `review/legacy-quarter.png`. The old appraisal is
preserved as `source/trellis-appraisal.json`. No evidence of Studio import,
upload or map placement for the old file was found.

## First ransacked candidate (superseded)

The clean authored rebuild in `exports/OrangeBoxRansacked.glb` keeps the
small crate's white panel, charcoal frame and orange latch language. It
adds a genuine torn side aperture, a forced end door, peeled lid sections,
orange cargo cases and scattered interior pieces. The body is modelled
directly because the closed original silhouette could not express these
openings by reduction alone. `tools/blender/build_orangebox_wrecked.py` is
the authoritative geometry and texture source;
`source/OrangeBox_Ransacked.blend` contains editable parts and the export.

**Stage 4 local verification passed.** The full
`python tools/build_orangebox_wrecked.py` build, appraisal, four-view render
and GLB inspection passed, followed by
`python tools/build_orangebox_wrecked.py --check-only` passing. The final
GLB SHA-256 is
`a161663b9c182fbd8a7bf4e22bc1895f4d68a582aac44a29e2c8837e03402826`:
3,536 triangles, one mesh/material, two embedded 1024 PNG maps, 1.62 MB.
Bounds in glTF/Roblox axes are X -3.4088..3.4088, Y 0..3.8, Z
-2.5260..2.5260. Its bottom pivot and centered footprint were checked in
the written file. The open door widens the footprint beyond the body.
`validation.json` records full hashes and measurements.

All four `review/ransacked-{front-quarter,side,end,rear}.png` views were opened
and inspected. Agent assessment, **not user approval**: the large side and
end openings show the orange cases and fallen panels; the rear remains calmer.
The atlas has restrained chips, soot and edge wear. The look is a stylized
clean rebuild, with less tiny baked detail than the dense original. Show a
damaged side toward players if this is used as decoration.

The repository-wide `lune run tools/check_assets.luau` could not start in
this sandbox: Lune panicked while canonicalizing the current working directory
with Windows access denied (OS error 5). The package-specific checks passed;
the repository gate is unverified here.

## Next action and unverified stages

Stage 5: get the user's visual approval of the current front-quarter, side
and end previews. The 3.8-stud height and decoration role are provisional.
The earlier “cover” label was not user approval. If this is to decide fights,
the cover shape belongs in the map Lua geometry rather than decor.

Stage 6: after appearance and role are settled, import
`exports/OrangeBoxRansacked.glb` with Stud units and the correct asset owner.
Verify its texture resolution, 3.8-stud height and collision in Studio.
`SetupOrangeBox.luau` is scoped to one selected imported mesh and defaults to
anchored, non-colliding decoration. Record mesh/texture IDs and owner here.

Stage 7: save the actual placement in the chosen map's decor collection,
preserve existing decor, restart the map and record runtime evidence. No
Studio import, asset IDs, target map, placement or published-game result has
been observed for the new file.

## Studio record (fill from observed evidence)

- Visual approval: pending
- Studio import of current SHA: unverified
- Owner and mesh/texture asset IDs: unknown
- Imported size and materials: unverified
- Physics: unverified
- Target map and decor file: unknown
- Restart persistence / publication: unverified
