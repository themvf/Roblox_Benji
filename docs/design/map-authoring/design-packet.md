# Convergence map authoring — design packet

Status: G2 tooling complete. Studio acceptance (A14, A18 and the Studio halves of A02, A05 and A07) is pending. · Owner: Claude (author, implementer and scripted verifier. There has been no independent review.) · Updated: 2026-09-24

Spec: *Reusable Convergence map authoring specification* (2026-09-24, supplied in chat).
Designer walkthrough: [assets/environment/source/README.md](../../../assets/environment/source/README.md).

## 1. Identity and intent

| Question | Answer |
| --- | --- |
| Map, mode or shared feature? | **Shared feature (tooling).** Internal ID `map-authoring`. It adds no mode and no public map. |
| Modes/maps supported | Convergence only. Every draft has exactly three objectives. Existing maps are unchanged. |
| Problem the user notices is fixed | A designer can create, edit, move objectives and spawns, convert and test a map without asking anyone to write configuration. |
| Who / devices | The level designer, on Windows Studio and a terminal (Git Bash or cmd). The player-facing result uses the existing HUD. |
| Test preset | `/explore <Name>` (walk around) and `/map <Name>` + PRACTICE pad + `/bots 5` (a match). |
| Authorized / out of scope | Everything in spec §2 "Required first release" is authorized. Out of scope: plugin, file watcher, procedural generation, publishing automation, and pickups, launch pads or events in the starter. |
| Baseline | `master` at `050d198`. Snow Fortress's bake and data are untouched, and every existing gate still passes (see §7). |

## 2. Game-mode questions

Not applicable. Convergence rules, scoring, phases and the finale are unchanged
(`ConvergenceService`, `FinalePlan`). A draft only supplies data those already accept.
Convergence requires three objectives with unique stable IDs and at least two
finale-eligible objectives. The converter enforces this before anything is installed,
and `FinalePlan.create` is run against every eligible final.

## 3. Map questions

Not applicable to the tool itself. These questions belong to each map made with it. The
walkthrough's design tips (spec §10) are guidance, not gates.

## 4. Player storyboard (designer)

| Frame | Designer view | Question | Action | Feedback |
| --- | --- | --- | --- | --- |
| 1 Start | terminal | How do I get a map? | `save_map.sh new TestMap` | "Playable version UPDATED: src-…", plus the path to open |
| 2 Open | Studio Explorer | Which copy do I edit? | Insert from File → `TestMap — EDITABLE` | Labelled markers: OBJECTIVE A/B/C, BLUE/RED SPAWN, MAP BOUNDARY, NORTH |
| 3 Build | viewport | Where do pieces go? | Paste kit pieces into Geometry, move markers | Studio's own move/scale/undo |
| 4 Save | Explorer | Did I save the right thing? | Right-click the model → Save to File | Source is saved. The game hasn't changed yet. |
| 5 Convert | terminal | Did it work? | `save_map.sh TestMap` | UPDATED plus a list of changes, or NOT updated plus named problems with fixes |
| 6 Setback | terminal | Why was it refused? | Read the message, fix it, save again | The previous playable version keeps working. `restore` gets back a bad save. |
| 7 Test | Studio play | Is the game running my edit? | Stop/Play, `/explore` or `/map` | Toast and Output show `DRAFT TestMap · build src-…`, matching step 5 |
| 8 Repeat | Studio | — | The editable copy keeps its markers | `status` shows up to date or STALE |

## 5. Visual and interaction contract

- Markers are drawn in neon, translucent, and never collide, touch or take raycasts (`AuthoringHelper`).
  Every kind has a text label as well as a colour: OBJECTIVE A, BLUE SPAWN, MAP BOUNDARY (on all four sides) and NORTH.
- An objective is one Model (`Role=Objective`). Moving it moves its capture cylinder, pole and label together.
  The cylinder *is* the capture volume above the floor: radius = capture radius, height = `halfHeight`, bottom = capture point.
- The boundary is one transparent, locked box with a SelectionBox outline. Being locked stops it catching viewport clicks, so select it in the Explorer.
- Billboard labels are sized in studs (CLAUDE.md UI rule). No HUD was added. The draft toast reuses `SafetyService.Client.Notice`.

## 6. Reuse and ownership contract

| Component | Kind | Path | Data → result | Consumers | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| Starter template | new | `tools/mapauthor/template.luau` | name → editable `.rbxm` | `map.luau new` | `check_map_authoring` A01/A02 |
| Converter | new | `tools/mapauthor/convert.luau` | source + presentation → map module + bake. It is the only reader of markers. | `map.luau`, `check_bake` | `check_map_authoring` (60 checks) |
| CLI | new | `tools/map.luau`, `tools/save_map.sh`, `tools/save_map.cmd` | commands → staged, validated, atomic install. History, status, restore, scoped commit. | designer | same |
| Map validator | extended shared | `src/shared/Maps/Validate.lua` | For `Draft = true`, x-mirror fairness is a warning. Every other map is unchanged. | `check_maps`, MapService (Studio) | `check_maps` all OK |
| Baked-solid reader | extended shared | `tools/bakedsolids.luau` | `fromRoots` added for in-memory candidates | `check_maps`, `check_bake`, converter | all gates OK |
| `check_bake` | extended shared | `tools/check_bake.luau` | Removes the 50-part floor. Detects helpers by attribute (Centre included). Adds source freshness for authored maps. | CI | `check_bake` OK |
| `check_maps` | extended shared | `tools/check_maps.luau` | Rotation lists may not contain drafts | CI | OK |
| MapService | extended shared | `MapService.lua` | Removes editable sources from Workspace at play start. Announces draft builds. | all maps | `rojo build`, selene, stylua |
| `/explore` | new | `RoundService.lua` chat | Studio only. Loads a map and places the player on a spawn. Not in a match. | designer | pending Studio (A14) |

Why the new components exist: nothing read marker positions back into data. The GUIDE was
visual only, and every new map needed a hand-written module. Map lifecycle and authority
are unchanged: MapService builds from the module and clones the bake exactly as it does
for Snow Fortress.

### Decisions

| Decision | Reason |
| --- | --- |
| Generated data is the whole `src/shared/Maps/<Name>.lua`. Presentation overrides live in `assets/environment/source/<Name>.presentation.lua` and are merged in at conversion. | There is one module for runtime and validators, with no require shims or extra module under `Maps/` for the gates to mistake for a map. Spatial values have one source (markers). The presentation file rejects spatial keys. |
| Positions are world coordinates. (2026-09-25: this replaced pivot-relative coordinates.) | Studio re-centres a model's pivot on its bounding box when it's inserted from a file, which sank the designer's first map 36.5 studs under the terrain. Moving the whole map now moves every anchor consistently. The converter warns when the map drifts off the origin and refuses a map sunk under the terrain. |
| Supported marker transforms: move, rotate an objective or spawn about vertical, scale a capture cylinder, move/scale the boundary, rotate the boundary by 90°, and move the whole map. **Refused with a message:** a tilted capture cylinder, a tilted spawn pad, a boundary rotated by any angle other than a multiple of 90° (this includes turning the whole map), anything under the terrain, and scripts inside map pieces. | Those can't become the axis-aligned data the runtime uses. |
| Sources are opened with Studio's Insert from File. They aren't exposed through Rojo. | There is one unmistakable editing copy, and Rojo can never sync over live edits. |
| Drafts carry `Draft = true`. Drafts relax only the mirror-fairness rule, and they're banned from `Config.Maps`/`ConvergenceMaps`. | Balance is a warning while designing, as the spec says. A draft can't reach a public rotation. |
| Barrier segments are generated only where ground lies within 6 studs of the boundary edge. Otherwise the converter warns. | A barrier in open air protects nothing, and Validate rejects one. The boundary still recovers players there. |
| Recovery: `RecoveryY` = the bottom of the boundary. `SafePoints` = the spawn pad nearest each team's middle, plus each objective. `SafetyAlwaysOn` = the boundary's `TeleportOnExit` attribute (default true). | Derived from authored data. No Snow Fortress coordinates are copied. |

### 2026-09-25: live play in Studio

The first real session showed the file loop was too heavy for day-to-day building. It
took seven steps per change: Insert from File, keep pieces in Geometry, Save to File, a
terminal command, Rojo, Stop/Play and a chat command. The designer said so directly.

| Decision | Reason |
| --- | --- |
| In a Studio play session, MapService reads an editable map in Workspace **live** and starts on it. The player spawns on it, and the PRACTICE pad plays it. | Build → Play → Stop is the whole loop. Files are only for storing a map in the project. |
| One marker reader, `src/shared/MapAuthoring.lua`, is used by both MapService (live) and the converter (Lune). | The spec forbids a second interpretation path. `check_map_authoring` asserts that the live read and a conversion produce the same data. |
| Pieces loose in Workspace are left out of the live test and named in Output. | The test must show what the stored map will contain. A loose piece was the designer's first mistake. |
| A live map beats the saved module of the same name, and keeps its stored sky and terrain. | Play shows the viewport, not an older save. |
| Outside Studio, an editable map in Workspace is removed and never played. | Live reading is a development path only. |

Evidence: `tools/check_live_map.luau` runs the real MapService source against a stand-in
Workspace (12 checks). A Studio session is still pending.

## 7. Acceptance and evidence

Scripted: `lune run tools/check_map_authoring.luau` runs 60 checks in a throwaway tree.
CI runs it on every push. Real drafts: `KitFortress` (Fortress, two outposts and
sightline screens, with C raised onto the keep's upper floor) and `KitOutposts` (teams
north/south, objectives west-east, helipad, wrecks, cover and ice). Both were built from
kit pieces by editing the saved source as Studio would, then converted with the CLI.

| ID | Status | Evidence |
| --- | --- | --- |
| A01 | PASS (script) | `new` creates the source, presentation, bake and module. The map has 3 objectives, 6+6 spawns, bounds, finale and Draft. |
| A02 | PASS (script). Visual check pending in Studio. | Objectives at y 0. Cylinder radius, height and floor point match the generated data. All labels present. Helpers inert. |
| A03 | PASS (script). Playing it is pending. | Moved A and Blue spawn 1, and the generated values match. |
| A04 | PASS (script) | Markers persist, and a second move converts. |
| A05 | PASS (script). In-Studio collision pending. | A SniperOutpost in Geometry converts with no data edits, and it's in the bake. KitFortress/KitOutposts also convert. |
| A06 | PASS (script) | `duplicate` is independent: the original's bytes are unchanged. A case-insensitive clash is refused. Saving the wrong model over a file is caught. |
| A07 | PASS (script) | A pivot re-centred by Studio changes nothing. Moving the whole map shifts every anchor equally. A sunk map and a turned map are refused. A widened boundary is regenerated, with a warning where ground stops short. A rotated boundary and a tilted cylinder are refused. |
| A08 | PASS (script) | A missing objective, a duplicate ID, a spawn outside the boundary and a floating spawn are each named with a fix. Outputs are byte-identical afterwards. |
| A09 | PASS (script) | `MAPAUTHOR_FAIL_AFTER=1` leads to a rollback. Both outputs are byte-identical to before. |
| A10 | PASS (script) | An unchanged source converts to identical bytes. Hand-edited data or bake, or a saved-but-unconverted edit, reads as STALE. `check_bake` does the same in CI. |
| A11 | PASS (script) | The draft converts while a broken map module sits beside it. Per-map conversion never runs other maps' gates, and `--all` and CI still do. |
| A12 | PASS (script) | A 1-part starter converts. The 50-part floor is gone from `check_bake`. |
| A13 | PASS (script) | No `AuthoringHelper`/`Role`/Authoring instances in the bake. `check_bake` detects GUIDE names including `Centre`. |
| A14 | **Pending Studio** | `/explore` and `/map` + PRACTICE are implemented. They pass `rojo build`, and the built place contains both drafts in `BakedMaps` and `Shared.Maps`. Nobody has played them yet. |
| A15 | PASS (script). Live match pending. | Every objective can be chosen as the final. The phases run 3 → 2 → 1 live objectives. A missing `FinaleEligible` is an error. |
| A16 | PASS (script) | The default makes no commit. `--commit` commits exactly the four map files, leaves unrelated staged work staged, and doesn't push. |
| A17 | PASS (script) | The history lists earlier versions. `restore` brings back the pre-mistake source, guides included, and it converts. |
| A18 | **Pending** | This needs the designer's own trial: two maps, prepared pieces, markers moved, one reported mistake fixed, and both reopened and tested without chat. |

Not claimed: collision is checked with part bounding boxes, so an irregular imported mesh
can still differ in play. Studio behaviour of the Locked boundary box's scale handles
hasn't been observed. The walkthrough gives the fallback (untick Locked).

## 8. Gates and handoff

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 Baseline | Done | `050d198`. The existing gates pass before and after the change. |
| G1 Design | Done | This packet and the spec. |
| G2 Playability | Scripted checks done. Studio pending. | §7 |
| G3–G5 | Not started | Per map, once the designer builds real maps. |

Next concrete task: the designer runs A18 in Studio. First restart `rojo serve` in this
worktree (see the project memory note). Then convert, Stop/Play, and try `/explore
KitFortress`, `/map KitOutposts` + PRACTICE + `/bots 5`, and a full match that finishes
on each of the three objectives.

Reproduce: `lune run tools/check_map_authoring.luau`, `bash tools/save_map.sh --all`,
`bash tools/save_map.sh status`.

Spec references not found in this checkout: `docs/design/SCENERY_ASSET_WORKFLOW.md` and
`docs/handoff/MUD_GRASSLAND_HANDOFF.md`. The walkthrough points to
`docs/design/ASSET_INTAKE_AND_LESSONS.md` instead.
