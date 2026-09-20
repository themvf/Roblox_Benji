# <Feature name> — design packet

Status: <gate and status> · Owner: <name/agent> · Updated: <date>

## 1. Identity and intent

| Required question | Answer / evidence |
| --- | --- |
| Is this a map, mode, or shared feature? What is its stable internal ID and display name? | |
| Which modes/maps must it support? Where is the authoritative spec? | |
| What player fantasy and repeatable decision make it worthwhile? | |
| Who is it for, and which devices/input types must work? | |
| What is the target roster, expected session length, and human/bot test preset? | |
| What is already authorized? What is explicitly out of scope? | |
| Which exact source/build/tuning produced the baseline? | |
| What problem will the player notice is fixed? | |

Use Decided / Hypothesis / Unknown / Not applicable with a reason. Link authoritative values instead of duplicating them.

## 2. Game-mode questions

For a map using an existing mode, link that mode's existing answers and record only map compatibility or deviations.

- What is the objective? How is progress earned, denied, and communicated?
- What wins, loses, ties, extends, or aborts a match?
- What are the states and legal transitions? Who owns the clock and resolution?
- Which comeback choices exist, and what do they cost?
- What can a new player do immediately? What rewards expert play?
- What happens on death, disconnect, late entry, invalid configuration, and a second match?
- Which rewards persist, and which practice/private/bot matches qualify?
- What map data is required? How does incompatibility fail before gameplay?
- Which inputs invoke the same shared action, and what can make that action unavailable?

State diagram: <link or inline diagram>. Rule source: <link>. Open hypotheses: <test and owner>.

## 3. Map questions

- What are the distinct districts and player callouts? What landmark identifies each?
- Where do teams spawn, and what prevents immediate spawn fire or a trapped exit?
- What are the main, alternate, and specialist routes? Where do they meet?
- What time/exposure/position does each route trade? What are measured route-time endpoints?
- Can one position control every entrance or multiple objectives? What counters elevation?
- Where are objective volumes, and can a reachable position count toward two?
- What remains traversable when a phase or objective closes?
- Where are the building footprint, playable perimeter, collision boundary and recovery volume?
- Are entrances, floor changes, ramps, cover and limits visually honest?
- Can bots and every supported character/movement form navigate the same legitimate space?
- Which districts/assets are reusable, and which are unique to this map?

Top-down plan: <link>. Route-time/sightline evidence: <link>. Compatibility matrix: <map × mode, Supported / Unsupported / Untested, with reason>.

## 4. Player storyboard

Replace these example beats as needed, keeping one setback and one recovery. Visuals are required before G1 acceptance; mark each concept/baseline/implemented.

| Frame | Player view / visual link | Player question | Decision/action | Feedback and next state | Shared component |
| --- | --- | --- | --- | --- | --- |
| 1 Arrival | | Where am I and what matters? | | | |
| 2 Prepare | | What equipment/role should I choose? | | | |
| 3 Approach | | Which way should I go and why? | | | |
| 4 Encounter | | Who is a threat; what can I use now? | | | |
| 5 Objective | | Am I helping; why did progress stop? | | | |
| 6 Setback/recovery | | What happened; how do I rejoin or change approach? | | | |
| 7 Climax | | What changed; how do we finish? | | | |
| 8 Result/replay | | Why did we win/lose; what did I earn? | | | |

## 5. Visual and interaction contract

- Art target/reference board and asset provenance:
- Architecture, scale, material and landmark vocabulary:
- Color/value roles for environment, cover, teams and interactions:
- Camera policy and large-avatar/mutation occlusion cases:
- HUD regions and safe areas across supported devices:
- Persistent labels, selection indicators and non-color state cues:
- Input map: keyboard, touch, controller; tap/hold; cancel/release:
- Default / loading / empty / unavailable / selected / active / cooldown / failure / completed states:
- Long-name/localization behavior, text contrast, reduced motion and supported accessibility preferences:
- Named reference devices, graphics settings and performance targets:

## 6. Reuse and ownership contract

| Component | Reuse unchanged / extend shared / new | Existing owner/path | Data/input → result/event | Consumers affected | Regression evidence |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

For every new component: explain why existing code is insufficient. Specify lifecycle/cleanup and authority. Map/theme variation should be data where practical; client UI must not become a second gameplay authority.

## 7. Acceptance and evidence

| ID | Player-visible requirement | Test scenario/method | Threshold | Implementation status | Evidence / verifier |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

Include rule, spatial, understanding, presentation and runtime checks. Unknown thresholds require an experiment before being treated as accepted. Note test sample sizes and device-specific failures.

## 8. Gates and handoff

| Gate | Status | Evidence / decision / who reviewed |
| --- | --- | --- |
| G0 Baseline | | |
| G1 Design | | |
| G2 Playability | | |
| G3 Complete section | | |
| G4 Extension | | |
| G5 Release candidate | | |

Next concrete task:

Dependencies / unresolved choices:

Work that can continue independently:

Changes to shared consumers that need regression checks:

Reproduce command/build/tuning and evidence location:

Decision log: <date, decision, reason, affected requirement/gate>. Do not mark accepted without a real review/evidence record.
