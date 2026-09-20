# Snow Fortress — sketch graybox v3

**Current matchmaking preset:** Player voting is restored (`Debug_ForceMap` empty, `MapVoteEnabled` true). Convergence offers three candidates drawn from Carrier, Forest, Snow and Snow Fortress. Five bots per team apply to every Convergence map through the shared mode startup. StartupMap is Forest; it does not override the voted match map. Earlier forced-map test instructions below are historical. Duel bot support is outside this preset.

## Approved revision v4

User requested two-story protected outposts, C upstairs, and a full-width second floor retaining both stairs. Implemented as `sketch-graybox-v4`; build: `builds/SnowFortress-sketch-graybox-v4.rbxl`. The v3 descriptions below are historical wherever they describe the atrium, low outposts, or ground-floor C.

The upper fortress floor is continuous at y=18 except two 14-by-36-stud stair slots. Side/back guardrails leave both upper stair exits open. C sits at y=18.2 with a seven-stud capture half-height, excluding players on the ground floor. Both outposts have lower shelter, firing decks at y=18, roofs, parapets, divided firing slits, full spawn-facing shields, and two exterior stair approaches. Outpost positions and other sketch topology remain unchanged.

Verification: shared map validator passes all five maps with zero warnings. Regression samples full fortress floor coverage, both stair holes, headroom on all fortress/outpost stair treads, zip/launch clearance, and vertical C membership. Manual test: climb both fortress stairs, capture C upstairs and verify no progress downstairs, then climb each outpost from both sides and inspect protected firing angles. No Computer Use or live gameplay verification performed for v4.

2026-09-20. Implementation ready for the user's manual Studio test. No Computer Use, new screenshots, gameplay measurements or art approval claimed.

## Authority and implemented layout

The [user's sketch](../../design/snow-fortress/authoritative-topology.png) and [specification](../../../SNOW_FORTRESS_MAP_SPEC.md) replace the previous fortress concept. The mode remains Convergence with server-selected eligible finales, no consecutive repeat, and reveal at Phase 2.

- Blue exterior spawn west; Red exterior spawn east. Six positions per team.
- A north outside, B south outside, C within the central fortress.
- Northwest and southeast outposts, each reachable by ordinary stairs. Detached sightline blockers protect spawn bearings without enclosing spawns in forts.
- Four side launch pads: northwest/west, southwest/west, northeast/east and southeast/east.
- Southwest and northeast ziplines arrive on the second story. Shared server-authorized traversal uses G, gamepad X, or the native touch proximity prompt.
- Four cardinal ground ramps and two internal stairs. Upper floor is a simple perimeter ring with central atrium; no complex interior added.
- Southwest and northeast sightline-breaking walls. No grapple routes or decorative assets.

## Blockout tuning choices

Fortress footprint 140 × 110 studs; ground floor top 4, second-story top 18. Ramps 24 studs wide at 20 degrees. Spawns x ±210; A/B z ±128; objective radii 18. Outposts at (-145, -126) and (145, 126), platform top 8. Launch vertical speed 62; landing points 2.5 studs above the ground-floor surface. These are starting values, not measured balance claims.

## Load and identify

Build: `builds/SnowFortress-sketch-graybox-v3.rbxl`.

The Rojo development preset sets `StartupMap` and `Debug_ForceMap` to `SnowFortress`. Reconnect/sync Rojo if needed, Stop the old test, then start a fresh test. Output must show `[MapBuild] SnowFortress / sketch-graybox-v3`. A cached running server will not reload the module.

For a match, use two Studio clients and queue opposite sides of Convergence. Current testing preset adds five bots to each human team. Check the actual roster. To restore normal map voting later, clear `Debug_ForceMap`; restore `StartupMap` to Forest if desired.

## Manual acceptance checklist

- Compare an overhead view with the sketch: Blue left, Red right, A top, B bottom, C middle; diagonal outposts and zips in their specified corners; four launches and four ramps.
- Walk every ramp both ways; ascend and descend both internal stairs and both outposts. Check for snagging, overhead obstructions and falls outside the boundary.
- Ride each zip to the second story. Use each launch pad ten times and record successful landings; verify ground routes remain practical alternatives.
- Record spawn-to-A/B/C, outpost and second-story times for both teams. Report direct spawn firing lanes and overly dominant sniper sightlines.
- Complete a 6v6 match. Verify 3 → 2 → 1 active objectives, Phase 2 final reveal, and that upper-floor players cannot capture ground-floor C through the ceiling. Check Output for errors, recovery and repeated pathing failures.
- Review the simple upper ring and interior before requesting additional geometry or art.

Twelve standardized camera poses remain in `SnowFortress.ReviewViews` for the overhead and POV captures specified in the source document. Screenshots and playtest are assigned to the user by their latest instruction. Stop at graybox until explicit approval.

## Automated evidence

Entry regression fixed after the lobby integration: QueueService now owns map voting, but Convergence retained a call to the removed `MapVoteService:Pick`. That raised after setting both busy flags and before respawning players. Convergence now uses the map supplied by the queue, checks load success, and catches asynchronous failures to abort and release the lobby. `tools/check_convergence_entry.luau` executes the real service with the current vote API and verifies chosen-map loading and busy-flag cleanup for failed/empty maps. Restart a previously stuck Studio server after syncing.

Layout regression checks topology, district spacing, bounds, traversal inventory and sampled zip/launch clearance against authored solids. The shared validator checks all five maps; the new map explicitly requests rotational outpost pairing, with negative cases proving missing/misplaced pairs still fail. Lighting fields and terrain material satisfy the current map builder. Automated checks do not substitute for Studio physics, bot pathing, mobile input or balance testing.
