# Snow Fortress — traversal and combat

> Topology superseded by [SNOW_FORTRESS_MAP_SPEC.md](SNOW_FORTRESS_MAP_SPEC.md): Blue west, Red east, exterior A/B, central C, FOUR launches and TWO diagonal upper-story ziplines. No grapple routes in this blockout. Earlier traversal inventory below is historical. FIN rules remain applicable. See [graybox v3](docs/reviews/snow-fortress/graybox-v3.md).

Version 1.1 · 2026-09-20 · Dynamic finale selection/reveal implemented in working source; live verification and announcer audio asset pending. Traversal remains unimplemented. See [implementation evidence](docs/reviews/snow-fortress/implementation-status.md).

Companion to [the redesign spec](SNOW_FORTRESS_REDESIGN_SPEC.md). User decisions in this document supersede the previous fixed-finale design. Locations below describe tactical roles, not approved coordinates.

## Locked map identity

- Both teams spawn outside the fortress on opposite sides. Neither begins as defender or owns a district.
- Three dependable ground approaches, with limited optional roof access.
- Gate Courtyard: more open, mid-range encounters.
- Service Yard: dense cover and flank routes.
- Command Keep: vertical, close-quarters encounters.
- Phase 1: all three districts active. Phase 2: one district closes. Phase 3: one eligible surviving district remains as the finale.
- The finale varies between two or three eligible locations. Command Keep is not the permanent ending.
- Exterior boundaries enclose approach routes, outposts, landings and traversal endpoints; building walls are not the map perimeter.

## Finale selection contract

Target all three districts as finale candidates; allow only two if the third fails documented access/readability tests. Every eligible finale must support two ground approaches, fair access from both exterior spawns, and counters to entrenched defenders.

The server must generate and retain the match's closure order. Clients receive the same announced plan; bots consume the same active-objective state. Never mutate the shared map definition in place between matches. Keep stable A/B/C IDs and district names when phase assignments change. Other Convergence maps can retain their existing fixed phases unless explicitly opted in.

**Locked:** the server selects the finale from map-defined eligible districts, excludes the previous finale for that map on the same server, and chooses randomly among the remaining candidates. The reveal occurs at the start of phase 2. No player vote or predictable fixed cycle. Server-local repeat prevention does not guarantee global history across servers or server restarts.

**FIN-01 — Eligibility and selection:** each opted-in map declares eligible stable objective IDs and any server-evaluated map-specific eligibility parameters. The generic mode consumes the resulting eligible set; it must not branch on map names. Eligibility is resolved before match start and held stable for that match. Invalid IDs, fewer than two eligible districts, or an empty set after excluding the previous finale fail preflight with a diagnostic; never silently violate the no-repeat rule or choose an ineligible district. Other maps may retain fixed-phase behavior without opting into rotation.

Choose the final district and the non-final district that will close first at match initialization. Both decisions remain server-only during phase 1; do not replicate future phase lists, reveal flags, or an equivalent client-visible clue to the chosen finale. Remember the last finale when phase 2 is actually revealed, so an aborted opening does not consume an unseen finale. Scope history by map ID within the server and preserve it across intervening maps.

**FIN-02 — Phase transition:** phase 2 atomically closes one non-final district and reveals the chosen survivor as FINAL DISTRICT. Keep the other surviving district active and worth contesting through phase 2. Phase 3 closes that remaining non-final district; only the chosen finale scores. Do not reset surviving ownership/progress as part of the reveal. A final district is never closed and reopened. Normal early wins and existing overtime rules still apply.

**FIN-03 — Reveal presentation:** issue one synchronized phase-2 reveal event containing the stable objective ID and district name. Present a brief banner such as `FINAL DISTRICT: SERVICE YARD`, a distinct icon/border and persistent FINAL label on that district's HUD marker, a brief world-marker/map pulse, and an announcer cue with matching visible text. Here, map pulse means the world objective marker; this does not require introducing a minimap. Ownership colors retain their meaning and cannot be reused as the sole finale cue.

The revealed marker remains identifiable throughout phases 2 and 3. Phase 2 copy must say it is the upcoming finale, not imply the second surviving point has already stopped scoring. Candidate banner: `FINAL DISTRICT: SERVICE YARD — 2 DISTRICTS STILL ACTIVE`. Phase 3 uses `FINAL DISTRICT ACTIVE` and the district name.

An optional architectural beacon/light treatment may reinforce the reveal, but must not obstruct opponents, change collision, or become necessary to understand it. Use a short restrained pulse with a static reduced-motion alternative; no repeated flashing. Missing/unuploaded announcer audio must not prevent the visual reveal.

**FIN-04 — Replication and recovery:** authoritative snapshots carry the revealed state once phase 2 starts. Late observers, respawned clients, or a rebuilt HUD receive the persistent final marker without needing the original event. Repeated snapshots must not replay announcement audio or pulse animations. Bots receive and act on the same phase-2 reveal timing rather than gaining advance knowledge of the hidden finale.

**FIN-05 — Acceptance:** test every eligible final district and first-closure pairing; repeated map plays never reveal the same finale consecutively; intervening maps do not erase that map's history. Test exclusions, invalid IDs, too few candidates, aborts before/after reveal, phase-1 data exposure, late snapshots and duplicate events. Verify both districts score correctly in phase 2, only the final district scores in phase 3, and survivors retain ownership. On phone and desktop, testers must identify the revealed finale within five seconds with audio muted and without relying solely on color or animation.

Closing removes scoring/capture eligibility, not route access. The map compresses strategically around the finale; do not add a physical shrinking boundary or remove valid approaches as an implied rule. Assess early entrenchment in each finale location during playtests.

## V1 traversal inventory

| Feature | Count | Placement role | Problem solved |
| --- | --- | --- | --- |
| Sniper outposts | 2 total | One on each opposing exterior approach edge | Cover a push without overlooking the entire fortress |
| Zip lines | 4 total, 2 associated with each approach side | One ridge-to-outer-wall route and one side-route connection per side | Reduce long exposed approach travel and provide alternate entry angles |
| Launch pads | 2 total, 1 per side | From contested exterior approaches toward a wall/courtyard edge | Bypass a choke or challenge an outpost through a committed flight |
| Grapple anchors | 3–5 total | Wall access, outpost counter-route, and at most one inner/roof connection | Resolve specific local access problems without universal freeform grappling |

Start anchor blockout with four for easier mirrored comparison; this is a candidate within the authorized 3–5 range. Do not add the optional third outpost or extra interior pad in v1. Counts are ceilings/targets for a designed network, not a reason to place a route that lacks a purpose.

## Route requirements

### Outposts

Each outpost must have at least two ways to challenge it, including a dependable ground route. No outpost can see all three capture areas or shoot directly into protected spawn space. Its useful sightline should cover an approach segment. Compare exposure, access time, cover and ammunition opportunities between the two sides. Elevated positions need a recognizable silhouette and a flank that does not require winning a sniper duel.

### Zip lines

Anchors, cable, direction and landing must be visibly readable. Routes begin outside the protected spawn pocket so boarding remains a tactical choice. Riders remain vulnerable; lines must not grant spawn protection or invulnerability. No line should deposit a player directly inside an active capture volume or behind an unavoidable spawn-kill position.

Directionality, speed, dismount behavior and shooting while riding remain implementation design parameters. Proposed initial behavior: fixed endpoints, one-way directed rides, no midair aim-to-anywhere travel. Provide safe landings and ground alternatives. Early dismount and firing rules require an explicit decision before implementation, not accidental behavior inherited from physics.

### Launch pads

Show destination/direction before commitment and make launch/landing readable through both visual and audio cues. Flight remains vulnerable with predictable landing space. Landing zones must clear walls, recovery limits and occupied cover. Both sides get comparable counterplay, not necessarily identical decoration. Test at least ten launches per route, including the largest supported form; invalid recoveries and trapped landings fail the route regardless of average success.

### Grapple anchors

Use context anchors, not a universal default grapple or arbitrary surface targeting. Display an explicit action when an eligible anchor is available; use the same action path for touch, keyboard and controller. The server validates anchor ID, range, state, cooldown and destination. Broken or unavailable anchors must not start movement.

Give every anchor a authored destination and ground alternative. Limit simultaneous roof ingress into each district so attack directions remain comprehensible. Charges are not required for fixed context anchors; cooldown, use duration and interruption rules must be specified and tested before acceptance.

## Outer, middle and inner areas

- **Outer:** exterior spawns, two outposts, four zip-line origins/connections and two pad origins. Preserve ground approach choices and avoid empty running lanes.
- **Middle:** contested entrances, cover, selected grapple access, visible arrival points. Traversal should help contest a choke rather than bypass all combat.
- **Inner:** district combat remains primary. At most one of the anchor routes should provide an inner/roof shortcut in the first candidate. Do not add an interior web of cables or pads.

Each route record must name its specific problem, endpoints, travel time versus the ground route, visibility/audio, exposure, landing space, counters, bot behavior, supported forms and phase availability. Delete or relocate routes that merely duplicate another without a useful tradeoff.

## Modular implementation

Map data owns outpost regions and traversal endpoint records. Shared services own authorization, movement lifecycle, cooldown and cancellation; shared UI owns prompts. Do not embed Snow Fortress coordinates in controllers.

Extend existing launch-pad functionality. Inspect existing systems before introducing zip-line or grapple services; these are new capability work until located in source. Use a common traversal-state contract where helpful: idle → available → committed → traversing → landed/canceled. Define cleanup for death, disconnect, map unload, tool changes and invalid destination. Prevent conflicting traversal modes from fighting over character movement.

Bots must either use a supported traversal action or choose a complete ground route; they must not stall at anchors they cannot activate. Test flight, existing jetpacks and mutation abilities against the new network so combined movement does not erase intended limits.

## Verification and rollout

1. Draw the ground network and all candidate finale approaches first.
2. Prove ground-only capture/retake in every eligible finale district.
3. Add the two outposts and demonstrate their counters.
4. Add zip lines, then launch pads, then anchors, testing each class before combining them.
5. Run the complete network at intended population on phone and desktop. Verify alternate routes are used and that defenders can identify incoming threats.

Acceptance:

- Both exterior teams can reach and retake every finale candidate without mandatory mobility equipment.
- All finale possibilities and closure orders receive explicit phase-transition tests; no mismatched client/bot state or reopened closed point.
- No outpost controls all three objectives; both counter-routes are traversable.
- Every traversal route has a documented reason, readable endpoint, vulnerable travel and a valid landing/cancel outcome.
- No freeform universal grapple, extra pads/outposts, or uncontrolled roof network appears through scope drift.
- Effective roster, movement settings, selected finale/order and device settings are logged with test evidence.
- Test results are recorded separately for ground-only and combined traversal, so a new mobility feature cannot conceal a broken base layout.

## Open questions for the next design decision

Finale selection and reveal timing are settled. Remaining decisions: zip-line firing/dismount and grapple interruption behavior after the initial route storyboard; these do not block drawing the ground network.
