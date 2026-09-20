# Snow Fortress — design packet

Updated 2026-09-20 · Author: Codex · G0/G1 in progress

## Identity and established decisions

- **Decided:** Snow Fortress is a map within Convergence. Internal ID: `SnowFortress`; player-facing name: Snow Fortress.
- **Decided:** the [redesign spec](../../../SNOW_FORTRESS_REDESIGN_SPEC.md) is authoritative for requirements, candidate timings and acceptance. The [implementation ledger](../../reviews/snow-fortress/implementation-status.md) records code and test status.
- **Decided:** improve visuals, equipment identification, objective separation and exterior approaches; preserve Convergence rather than introduce attack/defend rules.
- **Decided:** target 6v6; two-human testing uses one human and five bots per side. Effective runtime roster still needs checking.
- **Decided:** opposite exterior starts; Gate Courtyard (open/mid-range), Service Yard (cover/flanks), Command Keep (vertical/close-quarters); three ground approaches and limited roof access.
- **Decided:** 3 → 2 → 1 active districts. Server selection uses map-defined eligible districts, excludes the previous finale for that map, and reveals the chosen district at phase 2 start. A persistent distinct HUD/world marker, brief pulse and captioned announcer call make it unmistakable. See FIN-01–05 in the traversal spec.
- **Decided:** v1 traversal inventory is two outposts, four zip lines, two launch pads and 3–5 context grapple anchors. Every route must solve a specific access/rotation/counterplay problem. See [traversal and combat spec](../../../FORTRESS_TRAVERSAL_AND_COMBAT_SPEC.md).
- **Hypothesis:** district coordinates, route timings and exact traversal endpoints need blockout validation against the located fortress.
- **Known source:** local fortress branch at `ae1219b` integrated as working source on `codex/snow-fortress-redesign`. Exact screenshot-producing place version and live tuning remain unverified.

## Map concept

Current playable source/build and Studio connection instructions: [playable v2 record](../../reviews/snow-fortress/playable-v2.md). G2 remains in progress until a full Studio match is verified.

[Top-down concept sketch and interpretation notes](map-concept-notes.md) show the opposing exterior starts, district identities, optional traversal inventory and example finale flow. This is a proposed composition, not measured geometry or current-build evidence; route validation and player-camera storyboard frames remain required.

## Storyboard brief — visuals still required

These rows define what the visual storyboard must demonstrate. Preserved screenshots are problem evidence, not approved target compositions. G1 is not accepted yet.

| Frame | Player view / needed visual | Question and action | Feedback | Reuse |
| --- | --- | --- | --- | --- |
| 1 Arrival | Concept: fortress silhouette with exterior districts visible from a protected spawn | Where is the fight? Identify objective and two exits | District name and concise Convergence goal | Map intro, objective markers |
| 2 Prepare | Concept: readable loadout cards on phone and desktop | What am I carrying? Select weapon with a known role | Named preview and confirmed loadout | Loadout/equip data, weapon cards |
| 3 Approach | Concept: top-down routes plus combat-camera view of a direct and covered approach | Which entry should I take? Choose speed versus exposure | Visible entrances, cover and landmarks agree with map | Map route/spawn data, shared movement |
| 4 Encounter | Implemented capture pending: new named weapon cards and clear opponent silhouette | Who is a threat; which weapon can I use? Switch and fight | Correct equipped state and combat feedback | WeaponBar, weapon kit, team readability |
| 5 Objective | [Baseline problem](../../reviews/snow-fortress/evidence/01-capture-and-weapons.png); replacement concept needed | Is this point scoring? Capture or contest | CAPTURING/DEFENDING/CONTESTED and honest progress | Convergence state, objective UI |
| 6 Recover | Concept: death/re-entry with a second approach visible | How do I return without repeating the same failed attack? | Protected respawn and readable alternate route | Respawn, route data, equipment lifecycle |
| 7 Converge | Concept: final district reachable through multiple approaches | What changed, and where do we regroup? | Phase banner, closed-point status, match clock | Convergence phases and shared HUD |
| 8 Results | Implemented capture pending: readable phone recap | Why did we win/lose, and what counted? | Result, contribution, practice eligibility, replay path | Existing recap/progression and lobby flow |

## Initial reuse inventory

| Component | Decision | Source | Contract / affected consumers |
| --- | --- | --- | --- |
| Match scoring/phase state | Extend shared for specified correctness fixes | ConvergenceService, Config | Map objectives → authoritative state; all Convergence maps need regression |
| Fortress geometry | Extend map-specific data | Maps/SnowFortress.lua | Authored layout → MapService; preserve map ID and mode compatibility |
| Perimeter/recovery | Extend shared data support only where needed | MapService, SafetyService | Bounds/regions → safe traversal; Carrier must not regress |
| Weapon cards | Extend shared | WeaponBarController, WeaponPreview | Existing Tools → named equip UI; all weapon-using maps/modes affected |
| Weapon authority | Reuse | WeaponService / Weapons Kit | Existing equip/ammo/damage behavior; do not duplicate inventory state |
| Mutation/team presentation | Extend shared if required | MutationController, ReadabilityService | Authoritative state → legible combat identity |
| Art kit | Candidate new map asset family | To design | Repeated fortress modules; no gameplay rules inside cosmetic variants |

## Current gates and next work

| Gate | Status | Evidence / missing proof |
| --- | --- | --- |
| G0 | In progress | Source found; live Studio provenance and effective preset pending |
| G1 | In progress | Detailed spec and this storyboard brief exist; top-down visual, art board, HUD mockups and target review pending |
| G2 | Not started for redesigned geometry | Imported original fortress is a baseline, not the expanded battlefield |
| G3 | In progress for weapon UI only | First code pass and automated tests exist; no complete combat-section acceptance |
| G4 | Not started | Depends on approved complete section |
| G5 | Not started | Runtime, device, performance and player evidence pending |

Next: capture the integrated source in Studio, verify the weapon bar, and produce the exterior route plan plus storyboard visuals before committing to full-map art. Independent work: draw concepts from the spec, review prefab proportions, and define compatibility checks. Keep all detailed requirement status in the existing implementation ledger.
