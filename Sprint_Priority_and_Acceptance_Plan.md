# Sprint Priority and Acceptance Plan

## Purpose
Sequence the Alter Ego / Mutation System and Roblox Map Builder Plugin so the team validates the highest-risk ideas before expanding them.

Operating rule:

> Build the smallest playable vertical slice, test it, then expand.

## Priority
### A. Alter Ego / Mutation Prototype
Do first because it may become a signature gameplay differentiator.

### B. Map Builder Plugin Foundation
Do next because it lowers long-term content-production cost.

## Ownership

### Product
- Goals
- Scope
- Player experience
- Acceptance criteria
- Final gameplay calls

### Design
- Alter Ego visuals
- Mutant visuals
- Ability readability
- Modular environment assets
- Map polish

### Engineering
- Architecture
- Networking
- Server authority
- Plugin implementation
- Performance
- Telemetry

### Shared
- Balance
- Playtest interpretation
- Iteration priorities

# Track A — Mutation

## A1 — Selection + Meter
Deliver:
- Titan selection
- Mutation meter
- Server-authoritative energy
- Kill/objective rewards
- `MUTATION READY`

Gate:
- No meter desync
- Client cannot spoof energy
- Objective energy works
- HUD readable

## A2 — Transformation
Deliver:
- Manual activation
- Validation
- Transformation effect
- 25-sec timer
- Reversion

Gate:
- Reliable activation
- Death/respawn handled
- Reversion clean
- Other players see state correctly

## A3 — Colossus Abilities
Deliver:
- Ground Slam
- Brace
- Charge
- Cooldown UI
- Server-authoritative effects

Gate:
- All three work
- Cooldowns correct
- No client spoofing
- No map-bound exploits

## A4 — Telemetry + Playtest
Log:
- Time to mutation
- Activations
- Ability use
- Objective contribution
- Mutant kills/deaths
- Team outcomes

Questions:
- Is earning mutation understandable?
- Is it exciting?
- Does objective play contribute enough?
- Is 25 sec right?
- Does it feel fair?
- Does it create memorable moments?

Only expand roster if players clearly want more.

# Track B — Map Builder

## B1 — Metadata + Placement
Deliver:
- Standard metadata
- Plugin panel
- Structure/cover library
- Place/rotate/delete/duplicate
- Grid snap

Gate:
- Designer can greybox a simple map without engineering help.

## B2 — Gameplay Components
Deliver:
- Spawns
- Objectives
- Weapon pickups
- Speed pickups
- Jetpack pickups
- Launch pads
- Recovery zones
- Boundaries

Gate:
- Designer can create a playable test map with no manual scripting.

## B3 — Validation
Deliver:
- Missing spawn detection
- Missing objective detection
- Duplicate ID detection
- Out-of-bounds detection
- Launch-pad validation
- Pickup metadata validation

Gate:
- Designer can identify configuration errors without reading code.

## B4 — Bot Test Hook
Deliver:
- Test current map
- Spawn bots
- Run Convergence
- Output telemetry
- Log stuck positions
- Log objective participation

Gate:
- Designer can run a basic automated flow test independently.

## Suggested Sprint Sequence

### Sprint 1
- Titan selection
- Mutation meter
- Server authority
- Titan/Colossus greybox

Exit:
- Meter works correctly.

### Sprint 2
- Transformation
- Reversion
- Three abilities
- HUD

Exit:
- Full Titan → Colossus loop works.

### Sprint 3
- Mutation telemetry
- Human playtest
- Balance iteration
- Begin Map Builder schema/plugin shell in parallel

Exit:
- Decide whether mutation earns expansion.

### Sprint 4
- Map Builder placement
- Structure/cover kit

Exit:
- Designer can greybox a map.

### Sprint 5
- Gameplay component placement
- Validation

Exit:
- Designer can create a playable test map.

### Sprint 6
- Bot test hook
- Map QA workflow

Exit:
- Designer can build, validate, and bot-test with minimal engineering help.

## Dependencies

### Mutation
Requires:
- Match service
- Combat events
- Objective events
- HUD framework
- Server-side damage validation
- Player state/profile layer

### Map Builder
Requires stable interfaces for:
- Spawn
- Objective
- Pickup
- Launch pad
- Map boundary
- Recovery zone

Do not hard-code plugin behavior around carrier-only scripts.

## Definition of Done
A feature is done only when it is:
- Functional
- Multiplayer-safe
- Server-authoritative where required
- Instrumented
- Playtested
- Acceptance-tested
- Edge cases documented
- Free of critical blockers

## Engineering Delivery Format
Every milestone should include:

### Implementation Summary
What changed.

### Files / Services Changed
Major modules.

### Known Limitations
What was intentionally deferred.

### Test Instructions
Exact reproduction steps.

### Acceptance Results
Pass/fail against spec.

### Telemetry Added
What gets logged.

### Open Questions
Only unresolved decisions.

## Change Control
If engineering wants to change requested behavior, use:

```text
Requested behavior:
Engineering concern:
Recommended alternative:
Impact:
Decision needed:
```

Do not silently redesign the feature.

## Scope Protection

### Mutation — Do Not Add Yet
- Multiple forms
- Skill trees
- Paid boosts
- Alternate ultimates
- Passive stat ecosystems

### Map Builder — Do Not Add Yet
- AI map generation
- Procedural generation
- External web editor
- Full publishing pipeline
- Complex collaboration tools

## Final Success Criteria

### Mutation
Success means:
- Players understand it.
- Players care when meter hits 100.
- Activation timing matters.
- Objective behavior remains strong.
- Mutations create memorable moments.
- Players ask for more Alter Egos.

### Map Builder
Success means:
- Designer can build a playable greybox independently.
- Core gameplay objects are drag-and-drop.
- Validation catches errors.
- Bot tests reveal pathing/flow problems.
- New-map production becomes faster and more consistent.
