# Reproducible asset delivery

Use this alongside ASSET_INTAKE_AND_LESSONS.md and
ROBLOX_BLENDER_ASSET_PIPELINE_SPEC.md. The completed local example is
`assets/models/server-rack/HANDOFF.md`.

## User handoff

Collect the authoritative reference, original GLB if available, approximate size,
and intended role: decoration, cover, interactive object, or wearable. Save the
approved answers in the asset package. Do not depend on temporary screenshots,
browser sessions, or chat history as the only record.

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
