# Reusable Team Deathmatch map authoring specification

Date: 2026-09-25  
Status: Public TDM mode implemented in source on 2026-10-11; Snow Fortress became the sole public TDM map on 2026-11-10. Ten-player runtime verification and the reusable Studio authoring workflow remain open. See [the TDM design packet](team-deathmatch/design-packet.md).

## 1. Purpose and user outcome

Give the designer a reusable, editable Team Deathmatch (TDM) starter map in Roblox Studio. The designer can duplicate it, add buildings and scenery, move both teams' spawn points, adjust the boundary, and test the result without code edits or routine engineering help.

The primary success criterion is independence: the designer creates and tests a second distinct TDM map using prepared assets, without asking an engineer or agent to create configuration, transcribe coordinates, register spawns, or troubleshoot ordinary authoring mistakes.

Normal loop: **Open editable map → place pieces and move spawns → save source → convert and validate → playtest → reopen and adjust.**

This specification is for TDM. Another engineer owns Convergence work. TDM authoring must neither require Convergence objectives/finale data nor change Convergence scoring, phase rules, or map behavior.

## 2. Scope and priorities

### Required first release

- A genuinely blank, reusable TDM template.
- Create, duplicate, name, and select a draft without editing code.
- Persistent, individually movable team spawn markers and an adjustable playable boundary.
- Existing Studio move, rotate, scale, duplicate, and undo tools for authoring.
- Existing prepared model/GLB-derived asset workflow for scenery and structures.
- One explicit conversion command that creates required TDM map settings automatically.
- An unambiguous way to reopen the editable source in Studio.
- Direct draft selection for walking exploration and TDM testing.
- A public TDM choice in the PLAY menu and a clearly labeled physical TDM join area in the lobby, with boxes players can stand on to join Red or Blue.
- Actionable validation, stale-output detection, and failure recovery.
- Drafts remain separate from public map rotation, matchmaking, and publishing.
- Short designer instructions that require no Lua, Lune, Git, or map-service knowledge.
- A playable TDM test path. The current repository has Duel and Convergence, but no TDM mode; this is a required dependency for end-to-end acceptance.

### Deferred

- Custom Studio toolbar/plugin, asset browser, ghost placement, or replacement transform tools.
- File watcher; add only if explicit conversion proves inconvenient.
- Procedural generation, automatic balance design, and automatic repair of arbitrary imported assets.
- Full publishing automation and multi-user map merging.
- Pickups, launch pads, events, and advanced route metadata as mandatory starter content.
- Changes to Duel or Convergence rules.

Do not expand this release into the full scope of `Roblox_Map_Builder_Plugin_v1.md`.

## 3. Current implementation and problems to resolve

These observations came from source review, not a live Studio playtest. Reconfirm them before implementation.

| Current behavior | Required TDM change |
| --- | --- |
| `tools/build_guide.luau` creates spawn and boundary guides, but runtime positions come from `src/shared/Maps/<Name>.lua`. | Convert persistent source markers into the data used by runtime and validation. |
| Guide comments say save markers; kit documentation says delete them. | Retain markers in editable source; exclude them automatically from generated playable output. |
| The existing guide inherits a raised Convergence objective and fortress-specific framing. | Build a blank TDM guide with no objectives, capture previews, finale, fortress, or required elevated structure. |
| `tools/check_bake.luau` requires at least 50 parts for a required bake. | Accept a minimal functional draft; use structural checks instead of an arbitrary part count. |
| The bake marker-name check misses the `Centre` pad. | Detect all helpers by dedicated authoring subtree/metadata, including legacy guide pieces. |
| A new map requires a hand-written Lua module. | Generate a complete usable TDM map definition and defaults on first conversion. |
| `tools/save_map.sh` runs global checks and may commit and push. | Validate the selected draft by default; separate conversion, version control, and publishing. |
| `MapService` and `Validate` currently assume map data may include objectives and symmetric spawn layouts. | Add mode-aware TDM handling without weakening checks required by existing maps or Convergence. |
| `RoundService` runs round-based elimination; `ConvergenceService` runs objective scoring. | Add a separate TDM match path with respawns and team kill scoring; do not relabel Duel as TDM. |
| The lobby has physical Duel and Convergence pads and a PLAY menu, but no TDM join area. | Add a distinct TDM section with physical Red and Blue join boxes, and expose the same public TDM queue in PLAY. |
| Editing Rojo-owned instances in ServerStorage can be overwritten. | Expose a clear Workspace editing copy and safe source reopen path. |

Relevant references: `tools/build_guide.luau`, `tools/build_kit.luau`, `tools/save_map.sh`, `tools/check_bake.luau`, `tools/check_maps.luau`, `tools/bakedsolids.luau`, `src/shared/Maps/Validate.lua`, `src/server/Services/MapService.lua`, `src/server/Services/QueueService.lua`, `src/server/Services/MapVoteService.lua`, `src/server/Services/RoundService.lua`, `src/shared/Config.lua`, `default.project.json`, and the environment kit/baked and scenery workflow documentation.

Preserve existing maps, gameplay rules, prepared assets, and unrelated local work. Coordinate any shared map-service, validator, queue, and documentation changes with the Convergence engineer before integration.

## 4. Blank TDM starter template

The template includes only:

1. A flat, anchored, collidable ground surface.
2. Two labeled team spawn groups, each with individually movable spawn markers.
3. A visible, adjustable playable boundary.
4. A clearly named container for buildings, scenery, and props.

An initial 490 × 370 stud ground and six markers per team may reuse familiar dimensions, but they are editable starting values, not universal balance requirements. All initial spawns must be supported by ground. No objective, capture zone, finale marker, fortress, launch pad, or fortress-specific geometry is required.

Guides use text as well as color: **Blue Spawn**, **Red Spawn**, and **Map Boundary**. Each spawn has a visible identity such as `Blue 1` or `Red 3`. Helper parts do not affect collision, touch, or raycasts. A marker's visible label and preview move with its handle.

Proposed logical hierarchy (exact names may change consistently):

```text
<MapName> — EDITABLE
  Ground
  Geometry
  Authoring
    Spawns
      Blue
      Red
    Bounds
    Helpers
```

Stable metadata identifies the marker role, team, and spawn ID. Display labels may change without changing identity. Missing, duplicate, or malformed IDs are errors. Do not classify arbitrary scenery as a marker because its name begins with a common word.

The boundary has explicit height and out-of-bounds/recovery behavior, even if advanced controls initially live in Studio Properties. A multi-floor map may place a spawn at elevation only when a walkable surface supports it.

## 5. One authored source, generated runtime outputs

| File | Ownership and purpose |
| --- | --- |
| `assets/environment/source/<Name>.rbxm` | Authoritative editable map, including persistent markers and helpers. |
| `assets/environment/baked/<Name>.rbxm` | Generated playable geometry; contains no authoring helpers. Never edit directly. |
| Generated map data | Spawn positions, bounds, recovery/safety positions, stable IDs, and other derived spatial settings. |
| `src/shared/Maps/<Name>.lua` | Runtime entry, automatically created with usable TDM defaults; may compose generated data and optional presentation overrides. |

Engineering must choose and document a generated-data location that works in Roblox and Lune. Existing validators enumerate Lua files in `src/shared/Maps`; a support module must not appear as an additional map.

No hand-written file is required to create or duplicate a map. Supply sensible palette, environment, and terrain defaults automatically. Optional presentation overrides survive later conversions. Spatial values have one authority: the editable source. Generated outputs are replaceable artifacts, never a second editing surface.

The converter reads source markers, generates runtime-compatible data, and creates a separate playable copy without guides. Runtime and validators consume the same generated values. Never strip markers from or overwrite the editable source during conversion.

### Spatial behavior

- Moving a spawn changes the corresponding runtime spawn on the next successful conversion/test.
- Moving the entire editable map carries geometry, spawns, and bounds together.
- Resizing ground does not silently redefine bounds. Keep bounds explicit and warn about unsupported/out-of-ground placements, or provide a clearly labeled fit-bounds action.
- Derive barriers and recovery/safe positions from authoritative spatial data or optional explicit markers. Never retain copied Snow Fortress coordinates.
- Define whether whole-map rotation and scaling are supported. Convert consistently if supported; otherwise reject the transform with a useful message.
- Changing a display label does not change team or stable spawn identity.
- Spawn order is deterministic. Duplicating a marker cannot silently overwrite another spawn ID.

## 6. Team Deathmatch contract

TDM is a separate mode from Duel and Convergence. Two teams, Red and Blue, fight on the selected map, with at most five players per team. Players respawn during the match at valid team spawns. The team's score increases for an eligible opponent elimination. During regulation, the first team to 50 kills wins. If the 10-minute regulation period expires first, the higher score wins. A tie starts a full two-minute overtime. Overtime does not end early for the first kill or for reaching 50 kills. When the two minutes expire, the higher score wins; a remaining tie is a draw.

The TDM implementation must define and consistently test kill attribution, self-eliminations, environmental deaths, team damage, disconnects, simultaneous target scores, spawn protection, and respawn timing. The map authoring system must not infer scoring from marker names or geometry. Reuse existing combat attribution where valid, but verify it handles TDM rather than assuming Duel's lifetime `MatchKills` accounting is team scoring.

**Confirmed mode settings:** 50 team kills, 10-minute regulation, two-minute overtime on a tie, three-second respawn, and a maximum of five players per team. Public matchmaking waits for five joined human players on each side before starting; bots do not count toward that threshold. These are mode settings, not per-map spatial values; do not bake them into individual map files. A one-second spawn-protection window is a proposed starting value and requires confirmation before implementation. Bot use in private draft tests is still undecided. Do not require five humans per side for development-only map testing.

TDM maps require both teams' spawn groups and safety/boundary data. They do **not** require `Objectives`, `Finale`, capture radii, or phase data. The map schema and validators must distinguish TDM from Convergence so TDM drafts are not forced to carry fake objectives and existing Convergence maps keep their own requirements. A map may later support multiple modes only through an explicit, validated declaration; first release needs TDM-only drafts.

## 7. Save, conversion, and recovery

First-release user actions:

1. Save the editable Studio map to `assets/environment/source/<Name>.rbxm`.
2. Run `bash tools/save_map.sh <Name>` through a documented, Windows-compatible entry point.
3. Read the short result, then stop/start the Studio test after successful synchronization.

These are explicitly separate actions. Ordinary Studio Save or Save to File does not invoke conversion.

The command must:

1. Resolve a valid map name and source; prevent accidental overwrites during creation/duplication.
2. Parse and validate structure and marker identities.
3. Generate candidate bake and data in staging.
4. Validate the candidate outputs together, not previous files still on disk.
5. Replace related outputs as one coherent revision only after validation.
6. Roll back a partial replacement, so new geometry cannot pair with old settings.
7. Print selected map, success/failure, concise changes, build revision, and next action.

Failed conversion preserves editable source and previous working output. The designer may save unfinished source even if it cannot yet produce a playable map. Distinguish **source saved** from **playable version updated**. A stale-output status must identify when a test still uses the previous successful revision; for a new failed draft, state that no playable version exists.

Keep a recoverable previous editable version through documented backup/versioning behavior. Generated-output rollback alone cannot restore accidentally deleted source geometry.

Default conversion does not stage, commit, or push. If an explicit commit option exists, include source, bake, generated data, and required map settings together without sweeping unrelated staged work into the commit. Publishing/pushing remains separate from routine design testing.

## 8. Validation and deterministic generation

Routine validation targets the named TDM draft. Full-project checks still run independently in CI/release validation. Fortress-specific and Convergence-specific assertions apply only to maps/modes that use them; they must not be globally weakened to make TDM drafts pass.

Required TDM draft checks include:

- Both teams have valid, usable spawn markers; all stable IDs are unique within their role/team.
- Finite positions and dimensions, valid boundary height, boundary inclusion, and required ground/support checks.
- Spawn clearance and supported landing surfaces; a spawn embedded in solid cover or hanging over a void blocks conversion.
- No authoring helpers in generated geometry, including `Centre` and its pole if legacy guide pieces were imported.
- Required map definition and selected-draft registration/loadability.
- Authored and generated spawn/boundary values agree within an explicit serialization tolerance.
- Candidate geometry/data consistency; unsupported transforms are rejected.
- A TDM draft has no accidental Convergence objective/finale dependency.

Missing optional scenery, cover, pickups, and decoration do not block conversion. A low part count is not an error. Team travel asymmetry, weak cover, spawn sightlines, and insufficient spawn variety are warnings or playtest findings, not automatic structural errors. Do not require mirrored Red/Blue coordinates merely to satisfy an existing symmetry rule; intentional asymmetric TDM layouts must be allowed. Keep any symmetry rule that an existing map specifically requires.

Every error identifies the map and authored object, explains the problem plainly, and suggests a correction. Example: “TestMap: Blue spawn 3 is outside Map Boundary. Move the spawn inside or enlarge the boundary.”

Generation is repeatable: unchanged source/defaults produce equivalent outputs without timestamps or random ordering causing false changes. A freshness check regenerates and compares bake and spatial data, catching stale output and hand edits. Passing `check_maps` alone does not prove positional agreement or playability. Include direct source-to-generated comparisons and real Studio acceptance tests. Geometry validation cannot prove every imported mesh is navigable.

## 9. Reopening and testing drafts

Document one unmistakable way to load `source/<Name>.rbxm` into an editable Workspace copy. If source files are exposed through Rojo/ServerStorage, distinguish stored source from Workspace editing copy and avoid syncing over active edits. Do not recommend editing generated models.

Provide a simple development-only selector or equivalent mechanism with two paths:

- **Explore:** load the selected successful TDM draft for walking/player inspection of scale, floor support, collision, stairs, routes, spawn exits, and scenery. Free camera alone is insufficient.
- **Play TDM:** start the selected successful draft with working spawns, respawns, team kill score, timer, and match end. Support existing bot testing where practical.

Selecting a draft requires no Lua edits, public map-rotation changes, or agent help. Testing does not publish it. Show the active map and successful build revision so the designer can distinguish the latest edit from an older output.

Validate repeated stop/start and map reload: no duplicate geometry, stale spawn positions, leftover guides, or retained score/state from the prior test.

### Public lobby entry

The lobby has a distinct, visibly labeled **TEAM DEATHMATCH** area with a physical join box for **Red** and one for **Blue**. Standing on a box joins that team's public TDM queue, using the same queue state as choosing TDM and a team from the PLAY menu. Each side shows its current count out of five and whether it is waiting or starting. The public match starts only with five joined human players on Red and five on Blue. If either side drops below five before the match commits, return to waiting rather than launching an incomplete match. Bots do not fill public queue slots. Players can leave by stepping off or using the menu's leave action; the existing queue behavior must be checked so neither entry route leaves a player silently queued after leaving. A player already committed to another match cannot join TDM.

The public TDM queue uses published/approved TDM maps and may use the existing map-vote flow. Draft maps are excluded from public choices. The private Explore/Play TDM draft selector remains development-only and does not rely on filling the public join boxes. The lobby placement must give the new boxes enough room for up to five players per side without obscuring the existing PLAY, ARMORY, ALTER EGO, Duel, or Convergence entrances.

## 10. Reusable assets and TDM design guidance

Preserve the GLB preparation workflow and reusable map kit. Prepared models need understandable names, consistent scale, and useful placement pivots. Designers may add, remove, duplicate, or swap prepared assets without hand-editing gameplay data.

Asset roles:

- **Decoration:** visual only, with collision disabled as appropriate.
- **Solid cover:** intentional movement/projectile interaction.
- **Walkable structure:** dependable floors, stairs/ramps, and authored collision.

The template cannot automatically repair arbitrary new GLBs. Broken materials, unusual scale, or complex collision may still require asset preparation. Routine reuse of prepared assets must require no chat.

Starting design suggestions, subject to playtesting:

- Provide multiple safe exits from each team spawn area.
- Prevent direct enemy fire into newly spawned players and obvious spawn traps.
- Compare route times and access to strong positions for both teams; visual symmetry alone does not guarantee balance.
- Avoid a single perch controlling both spawn groups.
- Test respawns during a populated match, not only initial deployment.
- Prove movement and encounters before dense decoration.

These are design guidance, not mandatory fortress-shaped geometry checks.

## 11. Acceptance criteria

| ID | Test | Pass condition |
| --- | --- | --- |
| A01 | Create a blank TDM draft. | Ground, both team spawn groups, boundary, and required settings are created without code edits. |
| A02 | Inspect default guide. | All spawns are grounded; viewport labels identify teams and individual markers; no Convergence objectives or capture guides are present. |
| A03 | Move one Blue and one Red spawn, save and convert. | Generated positions match source; actual respawns use those positions. |
| A04 | Reopen source and edit again. | Guides remain; a second move/convert/test works without reconstructing markers. |
| A05 | Add a prepared structure. | Placement persists, intended collision works in Studio, and conversion needs no manual data edits. |
| A06 | Duplicate to a second named map. | Source/settings are independent; editing the second map does not change the first. |
| A07 | Adjust boundary and move the whole map. | Generated bounds/spawns stay consistent; unsupported transforms get clear errors. |
| A08 | Remove a spawn group or duplicate a spawn ID. | Source can still be saved; conversion names the issue and preserves the previous playable revision. |
| A09 | Simulate failure during output replacement. | No mixed bake/data revision remains; previous playable outputs are restored. |
| A10 | Re-run unchanged, then alter generated output. | Output is deterministic; freshness check catches hand edits/staleness. |
| A11 | Introduce an unrelated Snow Fortress or Convergence check failure. | Selected valid TDM draft can convert; full-project checks still report the unrelated failure. |
| A12 | Test a minimal low-part starter. | Structural checks pass without an arbitrary 50-part floor or fake objectives. |
| A13 | Inspect generated bake and reload twice. | No authoring helpers, duplicate geometry, or stale spawn anchors appear. |
| A14 | Select Explore and Play TDM. | Both load the intended successful draft without code edits or public rotation changes. |
| A15 | Verify TDM match behavior. | Eligible kills score for the correct team; 50 kills ends regulation; a regulation tie starts a full two-minute overtime even if a team then reaches 50; the higher overtime score wins or a remaining tie is a draw; respawns and match cleanup work. |
| A16 | Exercise save/commit separation. | Default conversion makes no commit/push; explicit versioning includes all map files and preserves unrelated work. |
| A17 | Recover a mistaken editable-source change. | Documented recovery restores a previous editable version including guides. |
| A18 | Designer independence trial. | Designer creates two maps, reuses pieces, moves spawns, fixes one reported error, reopens and tests both without agent chat or code edits. |
| A19 | Join public TDM from lobby and PLAY. | Red/Blue physical boxes and the PLAY menu enter the same TDM queue, show counts out of five, permit leaving, wait for five humans per side, and never expose drafts in public map selection. |

Record actual Studio evidence and map/source revision for end-to-end tests. Command checks do not substitute for gameplay verification. Report unverified items honestly.

## 12. Build order and engineering handoff

1. Confirm current map loading, validators, spawn placement, and mode selection. Agree with the Convergence engineer on shared files and schema before editing them.
2. Confirm spawn-protection behavior and private-test bot use. Implement the five-versus-five public queue and TDM mode contract without changing Duel or Convergence.
3. Define source hierarchy, stable marker schema, generated-data location, and source reopen path.
4. Build the blank TDM source template with grounded spawns and readable guides.
5. Implement deterministic conversion, automatic map defaults, candidate validation, coherent replacement, and rollback.
6. Add named-map checks, source/output agreement, helper-leak detection, and freshness verification.
7. Implement or integrate the TDM match/test path and draft selector; keep public rotation and publishing separate.
8. Replace conflicting kit/bake instructions with a short designer walkthrough covering creation, reopening, placement, conversion, testing, and recovery.
9. Prove the workflow with two distinct real TDM drafts and the acceptance criteria above.

Final handoff must include exact designer steps, changed files, supported transforms, generated-data location, check results, Studio evidence, known limitations, and remaining manual steps. Do not call the feature complete while first-map creation, ordinary spawn repositioning, or TDM testing still requires an agent to write configuration.

No game implementation is included in this specification. Build the smallest complete TDM authoring loop before optional watcher/plugin features.
