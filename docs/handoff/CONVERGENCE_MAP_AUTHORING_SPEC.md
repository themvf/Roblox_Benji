# Reusable Convergence map authoring specification

Date: 2026-09-24  
Status: Ready for engineering implementation; proposed behavior, not an implemented feature.

## 1. Purpose and user outcome

Give the designer a reusable, editable Convergence starter map in Roblox Studio. The designer can duplicate it, add buildings and scenery, move objectives and team spawn points, adjust the boundary, and test the result without code edits or routine LLM conversations.

The user’s core request: “I want a reusable map for convergence where I can design the map. This includes moving markers and spawn points.”

The primary success criterion is independence: the designer creates and tests a second distinct map using prepared assets, without asking an engineer or agent to create configuration, transcribe coordinates, register objectives, or troubleshoot ordinary authoring mistakes.

Normal loop:

**Open editable map → place pieces and move markers → save source → convert and validate → playtest → reopen and adjust.**

## 2. Scope and priorities

### Required first release

- A genuinely blank, reusable Convergence template.
- Create, duplicate, name, and select a draft without editing code.
- Persistent, movable objective and spawn markers; adjustable bounds.
- Existing Studio move, rotate, scale, duplicate, and undo tools for authoring.
- Existing prepared model/GLB-derived asset workflow for scenery and structures.
- One explicit conversion command that creates all required map settings automatically.
- An unambiguous way to reopen the editable source in Studio.
- Direct draft selection for exploration and Convergence testing.
- Actionable validation, stale-output detection, and failure recovery.
- Drafts remain separate from normal matchmaking/rotation and publishing.
- Short designer instructions that do not require knowledge of Lua, Lune internals, Git, or the map-service architecture.

### Deferred

- A custom Studio toolbar/plugin, asset browser, ghost-placement interface, or replacement transform tools.
- A file watcher; add only if the explicit conversion command proves inconvenient.
- Procedural generation, automatic balance design, and automatic repair of arbitrary imported assets.
- New game modes or changes to Convergence scoring and phase rules.
- Full publishing automation and multi-user map merging.
- Pickups, launch pads, events, and advanced route metadata as mandatory starter content.

Do not expand the first release into the full scope of `Roblox_Map_Builder_Plugin_v1.md`.

## 3. Current implementation and problems to resolve

These observations came from source review, not a live Studio playtest. Reconfirm relevant code before implementation.

| Current behavior | Required change |
| --- | --- |
| `tools/build_guide.luau` creates visual markers, but runtime positions come from `src/shared/Maps/<Name>.lua`. | Convert source markers into the data used by both runtime and validation. |
| Guide comments say save markers; kit documentation says delete them. | Always retain markers in editable source; automatically exclude them from generated playable output. |
| Objective C inherits Snow Fortress’s Y=18 placement. | All starter objectives sit on the flat ground; elevation is an intentional later edit. |
| `tools/check_bake.luau` requires at least 50 parts for a required bake. | A minimal functional draft is valid. Replace arbitrary part-count requirements with meaningful structural checks. |
| The bake marker-name check misses the `Centre` pad. | Detect all authoring helpers, preferably through a dedicated subtree/metadata rather than incomplete name patterns. |
| A new map requires a hand-written Lua module with many fields. | Generate a complete usable definition and defaults on first conversion. |
| `tools/save_map.sh` runs global checks and stops on any failure. | Routine conversion validates the selected draft; unrelated-map checks remain in full-project validation/CI. |
| The script stages only `assets/environment/baked` and, with `-c`, pushes to `master`. | Saving/conversion is separate from version control and publishing; any explicit commit includes the related source and generated files. |
| Editing Rojo-owned instances under ServerStorage can be overwritten. | Document and expose a clear Workspace editing copy and a safe source reopen path. |

Useful implementation references:

- `tools/build_guide.luau`, `tools/build_kit.luau`
- `tools/save_map.sh`, `tools/check_bake.luau`, `tools/check_maps.luau`, `tools/bakedsolids.luau`
- `src/shared/Maps/Validate.lua`, `src/shared/Maps/SnowFortress.lua`
- `src/server/Services/MapService.lua`, `src/server/Services/ConvergenceService.lua`
- `src/server/FinalePlan.lua`, `src/shared/Config.lua`, `default.project.json`
- `assets/environment/kit/README.md`, `assets/environment/baked/README.md`
- `docs/design/SCENERY_ASSET_WORKFLOW.md`, `docs/handoff/MUD_GRASSLAND_HANDOFF.md`

Preserve existing maps, gameplay rules, prepared assets, and unrelated local work.

## 4. Starter template

The template includes only:

1. A flat, anchored, collidable ground surface.
2. Objective handles labeled A, B, and C, with visible capture-area guides.
3. Two labeled team spawn groups containing individually movable spawn markers.
4. A visible, adjustable playable boundary.
5. A clearly named container for buildings, scenery, and props.

Initial defaults may reuse the existing 490 × 370 stud floor, 18-stud objective radius, and six spawn markers per team. These are editable starting values, not universal balance requirements. All initial objective locations must be supported by the ground. Do not inherit a fortress, elevated objective, launch pad, or fortress-specific geometry requirement.

Guides must use text as well as color: A, B, C, Blue Spawn, Red Spawn, and Map Boundary. Helper parts must not affect collision, touch, or raycasts. Objective labels, poles, and capture previews move together through one handle; users must not have to reposition each visual separately.

The capture preview must match the generated radius and vertical extent. Elevated objectives must not unintentionally capture players on a different floor. Boundary height and recovery behavior must be explicit, even if advanced controls are initially in Studio Properties.

Proposed logical hierarchy (exact names may change consistently):

```text
<MapName> — EDITABLE
  Ground
  Geometry
  Authoring
    Objectives
      A
      B
      C
    Spawns
      Blue
      Red
    Bounds
    Helpers
```

Stable marker metadata identifies gameplay roles and IDs. Display labels may change without changing objective identity. Missing, duplicate, or malformed IDs are errors. Do not classify arbitrary scenery as markers merely because its name begins with a common letter.

## 5. One authored source, generated runtime outputs

Required file ownership:

| File | Ownership and purpose |
| --- | --- |
| `assets/environment/source/<Name>.rbxm` | Authoritative editable map, including persistent markers and helpers. |
| `assets/environment/baked/<Name>.rbxm` | Generated playable geometry; contains no authoring helpers. Never edit directly. |
| Generated map data | Positions, capture dimensions, bounds, stable IDs, finale eligibility, and other derived spatial settings. |
| `src/shared/Maps/<Name>.lua` | Runtime map entry, automatically created with usable defaults; may compose generated data and optional presentation overrides. |

Engineering must select and document the generated-data location so it works in both Roblox and Lune. Existing validators enumerate Lua files in `src/shared/Maps`; do not accidentally expose a generated support module as an additional map.

No hand-written file is required to create or duplicate a map. Supply sensible palette, environment, and terrain defaults automatically. Optional presentation overrides must survive subsequent conversions. Spatial values must not be editable in two competing authoritative locations.

The converter reads source markers, generates runtime-compatible data, and creates a separate playable copy without guides. Runtime and validators consume the same generated values. Do not introduce a second runtime-only marker interpretation path.

Never strip markers from or overwrite the editable source during conversion.

### Spatial behavior

- Moving an objective changes the actual capture location on the next successful conversion/test.
- Moving a spawn changes the corresponding runtime spawn location.
- Moving the entire editable map carries all geometry and gameplay anchors together.
- Resizing ground does not silently redefine bounds. Keep bounds explicit and warn about unsupported/out-of-ground placements, or provide a clearly labeled fit-bounds action.
- Derive barriers and recovery/safe positions from authoritative spatial data or provide explicit optional markers. Never retain copied Snow Fortress coordinates.
- Define whether whole-map rotation and scaling are supported. Implement consistent conversion if supported; otherwise reject the unsupported transform with a useful message. Do not silently produce incorrect bounds or capture volumes.
- Changing objective display labels does not break stable IDs or finale eligibility.

## 6. Convergence contract

Preserve existing Convergence rules. The mode scores owned locations and progresses from three active locations to two, then one. Holding all three is advantageous; it is not itself the victory condition.

The starter generates exactly three unique stable objective IDs, defaulting to A/B/C, and finale settings that make all three eligible. Existing `FinalePlan` requires valid eligibility with at least two entries; this template intentionally defaults to all three.

The current finale implementation selects among eligible locations while excluding the previous revealed finale and reveals the choice in phase 2. Each objective therefore needs to support a final fight. Missing finale settings must not silently downgrade the intended template behavior.

Do not introduce new scoring, phase timing, capture rules, or bot privileges as part of this authoring work.

## 7. Save, conversion, and recovery

First-release user action:

1. Save the editable Studio map to `assets/environment/source/<Name>.rbxm`.
2. Run `bash tools/save_map.sh <Name>` through a documented, Windows-compatible entry point.
3. Read the short result, then stop/start the Studio test after successful synchronization.

This is explicitly two actions. Ordinary Studio Save or Save to File does not automatically invoke the converter. Do not describe it as automatic conversion on save unless a real integration exists.

The command must:

1. Resolve a valid map name and source; prevent accidental overwrites during creation/duplication.
2. Parse and validate the authored structure and marker identities.
3. Generate candidate bake and data in a staging location.
4. Validate the candidate outputs together, not the previous files still on disk.
5. Replace the related outputs as a coherent revision only after successful validation.
6. Roll back if replacement fails partway; avoid leaving new geometry paired with old settings.
7. Print the selected map, success/failure, concise changes, and the next action.

Failed conversion preserves editable source and previous working output. The designer may always save unfinished source, even when it cannot yet produce a playable map. Distinguish “source saved” from “playable version updated.”

Provide a clear stale-output status so a failed conversion cannot be mistaken for a successful test of the latest edit. For a brand-new failed draft, say that no playable version exists yet.

Preserve a recoverable previous editable version through documented backup/versioning behavior. Generated-output rollback alone does not restore accidentally deleted source geometry.

Default conversion neither stages nor commits nor pushes files. If an explicit commit option is provided, include source, bake, generated data, and required map settings together; do not sweep unrelated staged work into the commit. Publishing/pushing must remain explicit and separate from routine design testing. A PR flow is optional repository policy, not a prerequisite for local editing.

## 8. Validation and deterministic generation

Routine validation targets the named map. Full-project checks still run independently in CI/release validation; do not weaken them globally to accommodate drafts. Fortress-specific assertions apply only to Snow Fortress.

Required draft checks include:

- Exactly three valid objectives and complete finale settings.
- Both teams have usable spawn markers.
- Finite, valid positions/dimensions, boundary inclusion, and required ground/support checks.
- No authoring helpers in generated playable geometry, including `Centre` and its pole.
- Required map definition and selected-draft registration/loadability.
- Matching authored and generated spatial values within an explicitly defined serialization tolerance.
- Candidate geometry/data consistency and no unsupported transforms silently accepted.

Missing optional scenery, cover, pickups, and decorative content must not prevent draft conversion. A low part count is not itself an error. Unsupported spawns, missing objectives, or malformed boundaries receive blocking errors; balance and presentation concerns are warnings.

Every error identifies the map and authored object, explains the problem in plain language, and suggests a correction. Example: “TestMap: Blue spawn 3 is outside Map Boundary. Move the spawn inside or enlarge the boundary.” An error need not select an object automatically in v1, but names must let the user locate it in Studio.

Generation must be repeatable. Re-running against unchanged source and defaults produces equivalent outputs without timestamps/random ordering causing false changes. A freshness check regenerates and compares both bake and spatial data (canonical comparison is acceptable if binary serialization is not stable), catching stale output and hand edits.

Passing `check_maps` alone is insufficient evidence of positional agreement or playability. Include direct source-to-generated comparisons and a real Studio acceptance test. Existing geometry validators may approximate mesh collision; do not claim they prove every imported mesh is navigable.

## 9. Reopening and testing drafts

Document one unmistakable way to load `source/<Name>.rbxm` into an editable Workspace copy. If source files are exposed through Rojo/ServerStorage, clearly distinguish the stored source from the Workspace editing copy and avoid syncing over active edits. Generated models must not appear to be the recommended editing target.

Provide a simple draft selector or equivalent development-only mechanism with two test paths:

- **Explore:** inspect scale, floor support, collision, stairs, routes, and scenery without navigating a match lobby. Include a walking/player view; a free camera alone cannot verify collision.
- **Play Convergence:** start the selected draft with working objectives and spawns; support the existing bot test capability where practical.

Selecting a draft must not require Lua edits, modifications to the public map rotation, or repeated agent assistance. Testing must not publish it. Identify the active map and successful build revision so the designer can distinguish old output from the latest edit.

Validate repeated stop/start and map reload: no duplicate geometry, stale objective positions, leftover guides, or retained state from the preceding test.

## 10. Reusable assets and map design guidance

Preserve the existing GLB preparation workflow and reusable map kit. Prepared models should have understandable names, consistent scale, and useful placement pivots. The designer can add, remove, duplicate, or swap them without regenerating gameplay logic by hand.

Asset roles must be clear:

- Decoration: visual only, with collision disabled as appropriate.
- Solid cover: intentional movement/projectile interaction.
- Walkable structure: dependable floors, stairs/ramps, and authored collision.

The template does not guarantee automatic repair of arbitrary new GLBs. Broken materials, unusual scale, or complex collision may still require asset preparation. Routine reuse of prepared assets must require no chat.

Starting design suggestions, subject to playtesting:

- Give each objective multiple usable approaches.
- Protect spawn exits from direct enemy sightlines.
- Compare team travel times rather than assuming visual symmetry guarantees balance.
- Avoid one perch dominating all three locations.
- Test every eligible finale and both teams’ routes.
- Prove movement and encounters before adding dense decoration.

These are design guidance, not mandatory fortress-shaped geometry checks.

## 11. Acceptance criteria

| ID | Test | Pass condition |
| --- | --- | --- |
| A01 | Create a blank draft. | Ground, A/B/C, both team spawn groups, and boundary are present; all required settings are created without code edits. |
| A02 | Inspect default guide. | All objectives are grounded; viewport labels identify A/B/C and both teams; previews match generated capture dimensions. |
| A03 | Move A and one spawn, save and convert. | Generated positions match authored positions; actual gameplay uses those positions. |
| A04 | Reopen source and edit again. | Guides remain; a second move/convert/test works without reconstructing markers. |
| A05 | Add fortress or another prepared model. | Placement persists, intended collision works in Studio, and conversion requires no manual data edits. |
| A06 | Duplicate to a second named map. | Source/settings are independent; editing the second map does not change the first. |
| A07 | Adjust boundary and move the whole map. | Generated bounds/spawns/objectives stay consistent; unsupported transforms receive clear errors. |
| A08 | Remove an objective or duplicate its ID. | Source can still be saved; conversion names the problem and preserves the previous playable revision. |
| A09 | Simulate failure during output replacement. | No mixed bake/data revision remains; previous playable outputs are restored. |
| A10 | Re-run conversion unchanged, then alter generated output. | Unchanged output is deterministic; freshness check catches the manual change/staleness. |
| A11 | Introduce an unrelated Snow Fortress check failure. | Selected valid draft can still convert; full-project checks still report the unrelated failure independently. |
| A12 | Test a minimal low-part starter. | Meaningful map checks pass without an arbitrary 50-part floor. |
| A13 | Inspect generated bake and run twice. | No authoring helpers, duplicated geometry, or stale gameplay anchors appear. |
| A14 | Select Explore and Play Convergence. | Both load the intended successful draft without code edits or public rotation changes. |
| A15 | Verify finale behavior. | Three stable objectives are eligible; existing phase/reveal behavior is preserved; test all possible final locations. |
| A16 | Exercise save/commit separation. | Default conversion makes no commit/push; explicit versioning includes all map files and preserves unrelated work. |
| A17 | Recover a mistaken editable-source change. | Documented recovery restores a previous editable version including guides. |
| A18 | Designer independence trial. | User creates two maps, reuses prepared pieces, moves objectives/spawns, fixes one reported mistake, reopens and tests both without agent chat or code edits. |

Record actual Studio evidence and map/source revision for end-to-end tests. Command checks passing do not substitute for gameplay verification. Report unverified items honestly.

## 12. Build order and engineering handoff

1. Confirm existing map loading, validator assumptions, and test selection; preserve baseline behavior.
2. Define source hierarchy, stable marker schema, generated-data location, and source reopening path.
3. Build the blank source template with grounded objectives and readable guides.
4. Implement deterministic conversion, default map creation, candidate validation, coherent replacement, and rollback.
5. Add named-map checks, source/output agreement tests, helper-leak detection, and freshness verification.
6. Update the save entry point and draft selection/testing workflow; keep commits/publishing separate.
7. Replace conflicting kit/bake instructions with a short designer walkthrough covering creation, reopening, placement, conversion, testing, and recovery.
8. Prove the workflow with two distinct real draft maps and the acceptance criteria above.

Final engineering handoff must include: exact user steps, changed files, supported marker transformations, chosen generated-data location, check results, Studio evidence, known limitations, and any remaining manual steps. Do not call the feature complete while first-map creation or ordinary repositioning still requires an agent to write configuration.

No game implementation is included in this specification. The next implementation should deliver the smallest complete authoring loop before optional watcher/plugin features.
