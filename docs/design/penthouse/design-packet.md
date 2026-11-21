# Penthouse — design packet

Status: G1 Design, Ready for review · G2 Playability, Not started · Owner: Claude (author, implementer and verifier; no independent review) · Updated: 2026-11-16

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Map, mode or shared feature? ID and display name? | **Decided:** map. ID `Penthouse`, display name Penthouse. |
| Which modes must it support? Authoritative spec? | **Decided:** Convergence (three objectives). This packet plus `assets/environment/source/Penthouse.design.luau` are the spec. TDM is **Untested**. |
| Player fantasy and repeatable decision? | **Decided:** a firefight through the top floor of a tower. Each push is a choice of lane: the open terrace (long views), the atrium (the balcony fight) or the gallery (close quarters). |
| Who is it for, which devices? | **Unknown:** same audience and devices as the other Convergence maps; nothing device-specific was tested. |
| Target roster and test preset? | **Hypothesis:** sized for 6v6 (six pads a team). Test with `/map Penthouse`, `/bots 5`. |
| What is authorized? Out of scope? | **Decided:** the user asked on 2026-11-16 for a first generated map "in a penthouse building", mirrored skeleton with different dressing per side. Out of scope: rotation, uploads, props from the asset system, ranked. |
| Baseline source/build? | **Decided:** new map. Source revision `src-690340886c` or later; see `measure.json` for the revision actually measured. |
| What problem does the player notice is fixed? | **Not applicable:** new map, nothing replaced. |

## 2. Game-mode questions

**Not applicable:** uses Convergence unchanged. Map compatibility: three objectives A, B, C, all finale-eligible; six spawn pads a team; bounds teleport on exit.

## 3. Map questions

Top-down plan: [plan.png](plan.png). Route and sightline evidence: [measure.json](measure.json), written by `lune run tools/measure_map.luau Penthouse`. Player's-eye blockout previews: [views.png](views.png).

- **Districts and callouts (Decided):** Terrace (north, open air, objective A "Pool Deck"); Foyer; Atrium (double height, objective C, a mezzanine balcony each side); Kitchen; Gallery (objective B, sculpture at the south end); Service hall; Spawn hall. Outside the glass the west side has a spire tower and the east a helipad tower, and cover bands, rugs and furniture are blue-toned west and amber east, so the two mirrored halves are told apart.
- **Spawns (Decided, measured):** each team spawns in a hall at its end with three exits: a main door to the foyer and a vestibule door to the terrace and to the service hall. An elevator core and a reception wall stand either side of the main door; each side door opens into an L-shaped vestibule. No pad sees an enemy pad or an objective, and a pad can be shot from at most 61 studs away.
- **Routes (Decided, measured, walking at 16 studs/s):** north lane 12.9 s to A, middle 11.4 s to C, south 13.9 s to B; shortest routes are 10.7 s, 10.0 s and 11.9 s. Spawn to spawn 18.9 s. Narrowest point 8 to 10 studs on every lane. The lanes meet at the foyer (doors north and south), at the atrium (doors on all four sides) and through the mezzanine, which joins the atrium and the gallery upstairs.
- **What each route trades (Hypothesis):** terrace is longest and most exposed; atrium is fastest but overlooked by both balconies; gallery is slowest and has the shortest views. To be confirmed in play.
- **Control (Decided, measured):** each mezzanine sees objective C only, has two ways up (atrium stair, gallery stair), stays reachable with either one held, and is exposed to the enemy balcony and to the atrium floor. No held choke locks an objective out; the worst detour is 1.37 times the direct route (spawn main door).
- **Lines of fire (Decided, measured):** none over 120 studs between sampled standing positions. The first draft had a 215-stud line through five doors; the fix was a rule, written at the top of the design file: every doorway has a full-height screen wider than itself about 10 studs behind it.
- **Objective volumes (Decided):** radius 12, half-height 7, on the ground floor. The mezzanine is at 14 studs, above the capture height.
- **Boundary and recovery (Decided):** floor 280 by 180 studs; glass walls round the rooms, a 6-stud glass rail round the terrace; bounds 4 studs outside the floor, teleport on exit. There is no ground below: the presentation sets a sea level 430 studs down under fog.
- **Honest visuals (Unknown):** not seen in Studio. Glass is collidable; whether bullets pass through Glass parts in the Weapons Kit is unchecked, and the measurements assume they do not.
- **Bots and movement forms (Unknown):** no bot match run. Times ignore sprint, slide, jump, launch pads and jetpacks; a jetpack reaches the roof, which is inside bounds and untested.
- **Reusable pieces (Decided):** the generator, measuring tool, plan and view renderers are map-independent. Nothing in the layout is reused from another map.

Compatibility: Convergence Supported (converter and gates pass, not played); TDM Untested.

## 4. Player storyboard

Text brief only; [views.png](views.png) is a **concept** blockout render, not a running-game capture. A visual storyboard is still owed before G1 can be accepted.

| Frame | Player view | Player question | Decision/action | Feedback and next state |
| --- | --- | --- | --- | --- |
| 1 Arrival | Spawn hall, elevator core ahead | Where am I? | Read the side colour and the three exits | Leaves by one of three doors |
| 3 Approach | Foyer, reception wall then screen | Which lane? | Terrace door, atrium door or kitchen door | Commits to a lane |
| 4 Encounter | Atrium floor, balconies above | Who is above me? | Use the stair mass and sofas, or go up | Fight for C |
| 5 Objective | C under the chandelier | Am I capturing? | Hold inside the ring | Existing Convergence HUD |
| 6 Setback | Killed from the balcony | How do I counter it? | Take either stair, or shoot from the far balcony | Rejoins through another lane |
| 7 Climax | Finale on A, B or C | Where is the final fight? | Rotate through the atrium doors | Existing finale flow |

## 5. Visual and interaction contract

- **Art target (Unknown):** no reference board. The blockout uses flat colours: marble floor, warm white walls, dark concrete cover with a neon band in the side's colour, wood furniture as low cover.
- **Cover language (Decided):** full cover is 6 studs or taller; low cover is 3.5 studs. Team colours are used only on spawn pads; side colours are blue and amber, not team red and blue.
- **HUD, input, states (Not applicable):** no new UI.

### Props (added 2026-11-16)

Props are markers in the source (Authoring > Props), become the map's `Decor` list and are drawn by
MapService with no collision, so they do not change anything measured. Furniture that is cover is a
"shell": the cover block keeps its collision and turns invisible, and the model is drawn over it.

| Prop | Source | Placements | State |
| --- | --- | --- | --- |
| Palm tree | `palm-tree-1`, asset 84316532447768 | 16 (terrace planters, foyer, under each mezzanine) | **In the map.** Not seen in Studio. |
| Black Hawk | `black-hawk`, asset 106361454815274 | 1, on the east helipad tower | **In the map.** Not seen in Studio. |
| Radio tower | registry `radio-tower` | 1, on the west tower | **In the map.** Not seen in Studio. |
| Sofa | registry `penthouse-sofa`, asset 93746109947365 | 2 shells (atrium) | **In the map**, uploaded 2026-11-16 on the user's approval. Not seen in Studio. |
| Daybed | registry `penthouse-daybed`, asset 92760681066971 | 4 shells (terrace, gallery) | In the map, uploaded 2026-11-16. Not seen in Studio. |
| Kitchen island | registry `penthouse-kitchen-island`, asset 126360548080861 | 4 shells (kitchen, reception) | In the map, uploaded 2026-11-16. Not seen in Studio. |
| Sculpture | registry `penthouse-sculpture`, asset 115249129895050 | 1 shell (gallery) | In the map, uploaded 2026-11-16. Built with the detail gate overridden. Not seen in Studio. |

- **Decided:** cover blocks were resized to the models, not the reverse: sofa block 4 x 16, island blocks 4 x 12, sculpture block 12 x 16 x 16 tall, daybed blocks lowered to 2 studs (a platform to hop over, no longer low cover). Measurements were re-run and still pass.
- **Hypothesis:** every placement costs the model's full triangle count: about 446,000 for the palms and about 310,000 for the furniture. Whether that is acceptable on phones is untested; fewer palms or a lighter palm is the lever.
- **Unknown:** which way each shell faces in game (sofa back, daybed backrest); the preview cannot confirm the uploaded model's forward axis.

## 6. Reuse and ownership contract

| Component | Reuse / extend / new | Path | Result | Consumers affected | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| Map converter and gates | Reuse unchanged | `tools/map.luau`, `tools/mapauthor/` | playable bake and map module | none | `save_map.sh Penthouse` passes |
| Design to source generator | New | `tools/map_generate.luau` | `Penthouse.rbxm` from `Penthouse.design.luau` | only maps with a design file | converter accepts its output |
| Layout measurement | New | `tools/measure_map.luau` | `measure.json`, pass/fail against the design's targets | any converted map | run on Penthouse only |
| Plan and view renders | New | `tools/map_plan.py`, `tools/map_views.py`, `tools/blender/render_map_views.py` | `plan.png`, `views.png` | none | — |

A new generator was needed because the existing flow assumes the source is built by hand in Studio.

## 7. Acceptance and evidence

| ID | Requirement | Method | Threshold | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| P1 | Converts and passes map rules | `bash tools/save_map.sh Penthouse` | no errors | Verified | converter output, `check_maps`, `check_bake` (Penthouse row), `check_map_authoring`, `check_live_map` |
| P2 | Equal travel for both teams | measure tool | within 0.5 s per objective | Verified | measure.json |
| P3 | Lanes not bottlenecked | measure tool | narrowest 8 studs or more | Verified (8, 10, 8) | measure.json |
| P4 | Every choke has a way round | measure tool | detour at most 2.5 times | Verified (worst 1.37) | measure.json |
| P5 | Controlled lines of fire | measure tool | none over 120 studs | Verified at the sampled positions | measure.json, plan.png |
| P6 | Spawn safety | measure tool | pad unseen by enemy pads and objectives; shot from 70 studs at most | Verified (61) | measure.json |
| P7 | Vantage is contestable | measure tool | two approaches, sees fewer than three objectives, exposed | Verified | measure.json |
| P8 | Walkable in game | Studio: `/explore Penthouse` | every door, both stairs, no stuck spots | Not started | — |
| P9 | Plays well | bot match, then people | no spawn trapping, each lane used | Not started | — |

The thresholds in P3 to P7 are first guesses, not tuned against a map known to play well.

## 8. Gates and handoff

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 Baseline | Accepted (self) | new map, source and tools listed above |
| G1 Design | Ready for review | plan.png, views.png, this packet. Needs the user's review. |
| G2 Playability | Not started | needs Studio |
| G3 to G5 | Not started | |

Next concrete task: in Studio, with `rojo serve` running, Stop and Play, then `/explore Penthouse`; walk every door and both stairs, then `/map Penthouse` with `/bots 5`.

Unresolved: whether glass stops bullets; the measurement targets; props and a real art pass; whether the roof should be reachable.

Reproduce: `lune run tools/map_generate.luau Penthouse`, `bash tools/save_map.sh Penthouse`, `lune run tools/measure_map.luau Penthouse`, `python tools/map_plan.py Penthouse`, `python tools/map_views.py Penthouse`.

Decision log:
- 2026-11-16: mirrored skeleton, different dressing per side (user's choice of the "middle option").
- 2026-11-16: door rule adopted after six measured revisions; staggering doors alone kept opening new alignments.
- 2026-11-16: atrium north and south doors made single and central, and the stair landing given a solid pier, so the stair mass blocks every view from the west door through them.
