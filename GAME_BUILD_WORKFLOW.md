# Game design and build workflow

Version 1.0 · 2026-09-20

Every map and game mode uses the same design packet and acceptance process. The packet explains the player experience, the reusable pieces, and the evidence required to ship. [ROBLOX_BEST_PRACTICES.md](ROBLOX_BEST_PRACTICES.md) remains the engineering reference; feature specifications hold detailed requirements. Link those documents rather than copying their values into competing sources of truth.

## 1. Required design packet

Copy [the design packet template](docs/templates/DESIGN_PACKET_TEMPLATE.md) into `docs/design/<feature-id>/design-packet.md`. For an existing feature, populate it from its spec and identify unanswered questions; do not restart approved work.

Every answer must be one of:

- **Decided:** answer plus reference or rationale.
- **Hypothesis:** proposed answer plus the experiment that will resolve it.
- **Unknown:** what evidence is missing, who will obtain it, and which work depends on it.
- **Not applicable:** reason; never leave a required section silently blank.

No major geometry work without a route plan. No full-map art pass without an approved visual target. No new screen without its input and empty/error/unavailable states. Reversible prototypes can resolve hypotheses before those decisions are final.

The author is accountable for completeness, the implementer for behavior, and the verifier for evidence. One agent may fill multiple roles; record that fact rather than implying an independent review occurred. User direction already given counts as authorization—do not repeatedly ask permission for routine work.

## 2. Separate the reusable layers

| Layer | Owns | Must not own |
| --- | --- | --- |
| Shared gameplay systems | Damage, inventory/equip contracts, team identity, ability execution, persistence, input actions | Snow Fortress coordinates or a particular map's route rules |
| Mode definition and logic | Scoring, phases, win/tie/overtime, eligibility, required map capabilities, match lifecycle | Bespoke copies of weapon buttons or hardcoded map geometry |
| Map definition | Geometry, spawns, objective anchors/volumes, routes, boundaries, landmarks, environmental presentation | Its own alternate scoring implementation or progression writer |
| Shared UI components | Weapon cards, objective chips, buttons, meters, dialogs, responsive layout and state presentation | Independent damage, ammo, score, or cooldown authority |
| Theme / asset kit | Materials, structural modules, landmark assets, sounds, effects within agreed limits | Changes to interaction or collision hidden in a cosmetic variant |

A map declares the capabilities a mode needs. A compatibility check verifies those declarations before a match starts. For example, a mode requiring three phase-aware objectives must reject an incomplete map with a useful diagnostic before placing players. The general compatibility validator is a target pattern, not a claim it already exists.

When adding functionality, label each component **reuse unchanged**, **extend shared**, or **new**. Explain why a new component cannot use an existing one. Extend shared code when behavior is genuinely shared; keep unique landmarks local. Do not build a universal framework for hypothetical future modes.

## 3. Six gates

| Gate | Questions answered | Deliverable | Exit condition |
| --- | --- | --- | --- |
| G0 — Establish baseline | What build, mode, map and effective settings are we changing? What is already authorized? | Design packet identity and evidence record | Source/build mapping known; unrelated work preserved |
| G1 — Design the experience | What does the player do, see, choose and understand? Which components are reused? | Storyboard, top-down route plan, art target, input/UI states, compatibility contract | Major choices resolved or bounded as experiments; measurable acceptance written |
| G2 — Prove playability | Are routes, encounters, scoring and recovery correct? | Simple playable geometry and state tests | Intended roster can complete the loop; no invalid objective membership, traps or broken transitions |
| G3 — Prove one complete section | Does actual combat meet the visual and usability target? | Finished route/entrance/objective or equivalent mode slice, complete HUD | In-engine captures, input tests and target-device evidence support the intended experience |
| G4 — Extend consistently | Can approved parts produce the rest without new rules or UI copies? | Full map/mode assembled from the accepted patterns | Feature acceptance and shared-component regressions pass |
| G5 — Release candidate | Can another developer reproduce and verify it? | Evidence record, known limitations, build artifact and handoff | Required gates pass; no unresolved blocking defects; deployment remains a separately authorized action |

G1 and G3 are product reviews of concrete artifacts. Resolve major new visual/interaction directions with the user when not already authorized; continue independent implementation and testing meanwhile. Technical fixes and routine layout choices do not require another approval. A gate can be marked failed or pending without stopping unrelated work.

Gate status is **Not started / In progress / Ready for review / Accepted / Needs changes**. Implementation status is separately **Not started / Implemented, unverified / Verified / Blocked**. Code existing does not mean its gate is accepted.

## 4. The storyboard is a player journey

Use 6–8 frames, beginning with arrival and ending with results/replay. Each frame must show the player's view, immediate question, available action, feedback, and the reusable component involved. Include at least one setback—death, contest, denial, or lost objective—and recovery.

Each frame needs a visual: a sketch, mockup, annotated screenshot, or in-engine capture. A text-only row is a storyboard brief, not a completed visual storyboard. Label visuals **concept**, **baseline**, or **implemented capture**. Never present a generated concept as a running-game screenshot.

For maps, add a top-down view distinguishing building footprint, playable space, objective volumes, routes, spawn exits, sightlines, and outer boundary. For modes, add a state-transition diagram showing start, active play, overtime if applicable, finish, abort, and cleanup. A mode on several maps references each map packet instead of duplicating its layout.

## 5. Acceptance is specified before implementation

Every requirement gets an ID, test method, threshold, and evidence link. Set numerical targets for the actual feature, not one universal travel time or button size. Use existing feature-spec targets when available.

Cover five kinds of evidence:

1. **Rules:** state transitions, eligibility, scoring, timers, and cleanup.
2. **Spatial play:** navigation, encounter/rotation times, spawn safety, sightlines, boundaries, human/bot parity.
3. **Understanding:** can new players identify equipment, objective, next action and alternate route?
4. **Presentation:** combat-camera screenshots, animation/effect states, long labels, contrast and device layouts.
5. **Runtime:** intended population, performance on named devices, second match, reconnect where relevant, and shared-system regressions.

Record source revision plus local diff, actual map ID, effective overrides, human/bot counts, device/viewport, graphics settings, scenario and date. Distinguish physical-device evidence from simulator results. Preserve before/after captures at comparable settings.

Build/lint checks are prerequisites. They do not pass the presentation, usability or balance gates. Do not let high scores in one area cancel a broken essential action in another.

## 6. Change control and handoff

When changing a shared component, record which maps/modes/screens consume it and run representative regressions. When changing a rule, update its authoritative definition, UI meaning, and tests together. When changing a candidate design, state the evidence for the revision and which gate needs rechecking.

Keep the packet short through links. Preserve accepted decisions and replace obsolete answers; retain only consequential changes in a small decision log. Each handoff names the current gate, next concrete task, dependencies, changed files, and missing verification. Another agent must be able to continue without reconstructing the conversation.

Start with [Snow Fortress's seeded packet](docs/design/snow-fortress/design-packet.md). Its existing detailed spec remains authoritative. The packet exposes what is settled and what still needs design evidence.
