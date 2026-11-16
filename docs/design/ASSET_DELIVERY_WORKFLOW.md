# Reproducible asset delivery

Use this alongside ASSET_INTAKE_AND_LESSONS.md and
ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md. The completed local example is
`assets/models/server-rack/HANDOFF.md`.

## User handoff

Collect the authoritative reference, original GLB if available, approximate size,
and intended role: decoration, cover, interactive object, or wearable. Save the
approved answers in the asset package. Do not depend on temporary screenshots,
browser sessions, or chat history as the only record.

For a character meant for the Roblox Marketplace (and as a game skin), start from
`docs/templates/MARKETPLACE_CHARACTER_BRIEF.md`: the Midjourney/TRELLIS input checklist
and the Codex brief.

## The repeatable flow, in order

Each step stops the next one if it fails. The rules are in `tools/asset_rules.py`; the
gates are `tools/check_asset_registry.luau` and `tools/check_large_files.luau`, both in CI.

| Step | Command | What it settles |
| --- | --- | --- |
| 1. Brief | `asset_generate.py brief <name> --purpose --role --height` | role, size, route and triangle budget, before any GPU time |
| 2. Reference | `prompt` (Midjourney) or `reference` (built in) | one subject, white background, nothing cropped; checked on intake |
| 3. Mesh | `generate`, then `pick` | one candidate on the clean route, three on scan; `pick` writes `provenance.json` |
| 4. Build | `build` | per-mesh cap, role budget, size and pivot against the brief, detail against the source |
| 5. Approve | look at the review sheets; `verdict --looks good\|bad` for a scan | the eye is the gate for looks |
| 6. Publish | `publish` (dry run), then `publish --confirm` | uploads once, records the id in `src/shared/AssetRegistry.json` |
| 7. Studio | `verify --check loads --check facing ...` | what only Studio shows; the gate lists what is still open |

**Roles and budgets** (total triangles over all meshes; Roblox's 10,000 is per mesh):
`held` 4,000, `cover` 10,000, `interactive` 15,000, `decor` 30,000, `scenery` 60,000.
These are starting values, not measurements; the device test in
[performance/DEVICE_TEST.md](performance/DEVICE_TEST.md) is how they get replaced with measured ones. An asset that has to exceed its budget
records why: `brief <name> --budget-waiver "<reason>"`.

**Asset ids live in the registry, never in a script.** Game code reads
`require(ReplicatedStorage.Shared.AssetRegistry)["<name>"].assetId`. The gate fails when a
registered id is typed into `src/`, and when the uploaded file is an older build than the
export on disk.

**Looks and collision are separate parts.** The visual mesh never collides
(`CanCollide` off, `CollisionFidelity` Box); the thing players touch is a simple
invisible block. A model template under `assets/environment/runtime` that is named in the
registry is also checked for `RenderFidelity = Precise` and, on a scan, `DoubleSided`.

**Forward is -Z, one unit is one stud, the pivot is the centre of the base.** A Blender
builder puts the front at -Y; the glTF import turns that to Roblox -Z.

**Vehicles and guns need more than a shape.** Say so in the brief with `--kind`; a plain
`prop` needs none of this. A mount is a named point in studs from the pivot (+X right, +Y
up, -Z forward). `build` fails until the kind's mounts are set and plausible, and draws
them on `review/mounts.png`, which also shows which end the pipeline takes as the front.

| | Vehicle (`--kind vehicle`, role `interactive`) | Gun (`--kind weapon`, role `held`) |
| --- | --- | --- |
| Brief | `--game-name WaveRunner` | `--game-name <Name>`, `--length <studs>` |
| Mounts | `DriverSeat`, `HullCentre` (centre of the physics block; sets the waterline), any `Passenger...` | `Grip`, `Muzzle` |
| Build checks | seat above the base, mounts inside the model | long axis runs front to back, muzzle in front of the grip and at the front end |
| Code you still write | a `VEHICLE_SPECS` entry and a builder in `VehicleService.lua` that reads the id and mounts from the registry; a `VehicleSpawns` entry in the map | stats in `src/shared/Weapons`; a kit base in `BASE` and the art welded on in `tools/build_weapons.luau`; then `lune run tools/build_weapons.luau` and commit `assets/weapons/tools/` |
| Studio checks | enter, drive forward, waterline, seat height, exit | held the right way round, flash at the muzzle, first-person view not blocked |

The registry gate lists missing wiring as a reminder until the asset is uploaded, then
fails on it. A gun is drawn by the Weapons Kit: the kit Tool keeps its own muzzle, grip and
scripts, its geometry is hidden, and the art is welded to it (`attachWhiteSniperArt` is the
one existing example and is specific to that rifle; a second gun is the time to make it
read `Grip` and `Muzzle` from the registry).

**One session per package.** Commands that change a package claim it for four hours;
a second session is told who holds it. `claim <name> --release` when finished.

**Large files.** Nothing over 5 MB is committed without a line in
`tools/large_files.json` saying why it cannot be rebuilt. `trials/` is ignored by git.

## Generating candidates from a reference image

`tools/asset_generate.py` replaces the by-hand TRELLIS.2 loop. It calls the same
Hugging Face Space through its API, so set `HF_TOKEN` to use your own GPU quota.

```bash
python tools/asset_generate.py generate <image> --name wooden-crate --seeds 3
python tools/asset_generate.py pick wooden-crate --seed 2
```

With no reference image, make one first from a description (Z-Image Turbo Space, pure
white background), then leave the image argument off `generate`:

```bash
python tools/asset_generate.py reference wooden-crate --prompt "..." --seeds 8
python tools/asset_generate.py reference wooden-crate --use 2
python tools/asset_generate.py generate --name wooden-crate --seeds 2
```

The `asset-from-prompt` skill runs this whole section unattended, from one sentence to
stage 4, and reports once.

`generate` saves the reference, makes one candidate per seed in `trials/`, appraises
each and writes `review/candidates.png`. Look at that sheet, `pick` the winner into
`source/`.

```bash
python tools/asset_generate.py brief wooden-crate --purpose "..." --role decor --height 4
python tools/asset_generate.py build wooden-crate
```

`brief` writes `brief.json` (purpose, role, height in studs, pivot); `pick` copies the
purpose into the appraisal `decision`. `build` generates the package's own `scene.json`
from the brief, runs `scene_kit` on it, checks the export against the triangle cap,
renders `review/views.png` of the written file and records `validation.json`. A dense
generated source (over 50,000 triangles) keeps about a fifth of its triangles spread
over many meshes, the route tested on the snowmobile; heavier reduction crumples
panels. Anything else
wider than 12 studs is built as a 2x2 tile set; override with `--meshes`, or put any
`scene_kit` field (`cull`, `decimate`, `tile`) under `scene` in the brief. If a mesh comes
out over the 10,000-triangle cap, `build` rebuilds with a finer tile grid (up to five
attempts) and records the grid that passed in the brief.

`build` then runs `audit` (also `python tools/asset_generate.py audit <name>` by itself,
about 90 seconds). It renders the written file from ten sides plus six close-ups, twice:
textured and brightened, and as a hole map where front faces are grey and back faces
magenta. Roblox draws a mesh one-sided, so a magenta patch is a spot the game shows
straight through. Outputs: `review/audit.png` (with the reference alongside),
`review/audit_closeups.png`, single panels in `review/audit/`, and `review/audit.json` with
the back-face share per view. `--focus x,y,z` adds a close-up at a point of the bounding
box; `--seed N` audits a candidate before it is picked. The audit finds flaws; it does not
repair a mesh, and it is a Blender render, not Studio. That reaches stage 4. It never uploads: stages 5-7 still need your approval and Studio.

## Two routes: scan or clean

Every brief carries a `route`. `brief` and `build` print which one the numbers suggest.

| Route | Use for | Result |
| --- | --- | --- |
| `scan` | scenery seen from a distance, organic shapes (rocks, trees, rubble, wrecks) | the generated mesh, reduced and split into many meshes |
| `clean` | anything ridden, held or stood beside, anything that animates, anything for sale | one mesh rebuilt from simple shapes, a palette texture |

`clean` is suggested when the role is `interactive` or the mesh needs more than a 90% triangle
cut. Set it with `asset_generate.py brief <name> --route clean`; `build` then runs
`tools/blender/build_<name>.py`, the asset's hand-written builder.
`tools/blender/build_military_wave_runner.py` is the worked example.

A scan build is also checked against its source by `tools/outline_check.py`, which compares
flat outlines and nearest-surface depth from six sides and writes `review/detail.png`.
Surface error is the share of the source's visible surface the export gets wrong:

| Build | Surface error, worst view |
| --- | --- |
| Wave runner, 70,045 triangles in 12 meshes (looked right) | 0.040 |
| Broken tank export | 0.061 |
| Wave runner, 33,994 in 4 meshes (crumpled) | 0.231 |
| Wave runner, 9,000 in 1 mesh (full of holes) | 0.347 |

Over 0.08 the build warns; over 0.15 it fails and the export should not be uploaded.
`--allow-detail-loss` overrides that for something only ever seen from far away. The check
sees tearing and holes. It does not see a surface that keeps its shape but looks lumpy up
close, nor anything Roblox does after import, so the Studio stage still stands.

The two lines rest on four builds. After looking at a scan build, record
`asset_generate.py verdict <name> --looks good|bad`; `asset_generate.py calibrate` then
prints every score beside its verdict and says whether the lines still separate them.

## Stages and evidence

1. Intake: saved source/reference, appraisal, approved purpose and dimensions.
2. Authoring: choose optimization or clean rebuild based on textured review.
3. Export: reproducible builder, final GLB, named textures, pivot/axis contract.
4. Local verification: inspect written file and render front/side/rear views.
5. Visual approval: record what the user approved and what remains unresolved.
6. Studio verification: correct owner, asset IDs, textures, scale and physics.
7. Map integration: saved decor collection, restart test and runtime evidence.

A passing local check does not advance stages 5-7 automatically. Uploading does
not establish successful integration. Update HANDOFF.md whenever work stops or
changes stages, with the next concrete action and actual evidence.

## Every package should contain

- HANDOFF.md: approved decisions, stage, next action, blockers, IDs and map placement.
- README.md: usage, rebuild steps, known limitations and experiment history.
- appraisal.json: provenance measurements and explicit purpose.
- source/: durable reference and editable authoring inputs.
- exports/: only intended delivery assets; experiments belong in trials/.
- textures/ and review/: maps and views of the actual exported file.
- validation.json: latest machine-check result, time, artifact hashes and limitations.
- brief.json and provenance.json: what it is for, and where the reference and mesh came from.
- Studio setup instructions or a narrowly scoped helper for engine-only settings.

## Streamlining rule

Automate repeatable local work behind a single build command. Back up generated
outputs before replacing them, stop on failed steps, keep logs, and never silently
publish. Reuse a verified Roblox upload for more placements; duplicate its model
instead of exporting/uploading the same asset again.

## Recovery

Another agent reads the package handoff, verifies current artifacts, and continues
from the first unverified stage. It should not regenerate an approved asset just
because conversation history is missing. Commit and back up the package plus its
tooling for recovery beyond the current machine.
