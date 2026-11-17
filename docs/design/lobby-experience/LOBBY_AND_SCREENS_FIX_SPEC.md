# ENGAGE lobby and screen redesign — implementation specification

Status: G1 design draft · 2026-11-09 · Owner: lobby experience

## 1. Outcome and scope

Make the first five seconds in the lobby answer **Where am I? What do I do next? What am I taking into the match?** The primary route is Play → mode/team → queued → match. Preparation remains available before and during queue. The world communicates Convergence through a memorable science-fiction gate and character presentation, while screen controls stay readable over that world.

This is an extension of the [existing lobby design packet](design-packet.md), not a new queue or loadout system. The supplied BedWars screenshots are references for character, scale and action hierarchy; they do not describe the current ENGAGE build. The [2026-11-09 Studio audit](PROFESSIONALISM_PASS.md) is the baseline evidence.

**Decided:** preserve the current server-owned queue, physical pads, immediate loadout saves, mode/team choices, and explicit Leave. Use the existing `Screen` and `Theme` modules. Preserve the Studio-editable lobby source workflow.

**Hypothesis to test:** a Play-first menu, one hero destination and quieter secondary controls will make the first action obvious without reducing exploration. Test with fresh players and comparable arrival captures.

**Dependency:** the future Kits entry and pre-match lock-in require the server-owned kit implementation described in [the kit selection spec](../kits/KIT_SELECTION_UI_SPEC.md). Until then, keep existing loadout behavior accurately labeled; do not create a decorative Kits button that implies a working selection.

## 2. Baseline problems to resolve

| ID | Observed fact or source evidence | Required correction |
| --- | --- | --- |
| B-01 | In the captured 1287 × 665 Studio Play view, the four-button lobby bar covered the weapon hotbar. | Separate the controls on desktop, phone, tablet and console; verify the updated source in a fresh build. |
| B-02 | The captured arrival view showed mostly floor and the avatar. The gate was not in frame. | Audit every spawn, character scale and initial camera pitch/facing before altering geometry. Compose the gate in the initial view. |
| B-03 | The Play drawer source placed five loadout chips before the mode choices. | Lead with modes and team counts; move setup below or into a compact secondary row. A local source change exists but is not yet verified in synced Studio. |
| B-04 | `HudController` displays “Choose PLAY or enter the arena gate” throughout Lobby state. | Replace persistent generic instruction with short first-use guidance and contextual feedback. Preserve an always-available route to Play. |
| B-05 | Current navigation is PLAY / LOADOUT / CUSTOMIZE / PROFILE; the world still has an ALTER EGO bay. | Align labels and world presentation with the actual shipped systems now; transition to Kits only with its working service. |
| B-06 | The connected Studio session showed older UI after a source edit and Stop/Play. | Establish the exact place/source revision and Rojo sync before judging a fix. |
| B-07 | Studio Output reported SnowFortress turret-template failure and Arena fallback. | Track as a separate test blocker for end-to-end match verification; do not count fallback gameplay as SnowFortress acceptance. |

The single Studio capture does not prove how all five spawns look. There is no fresh-player usability sample yet.

## 3. Target player journey

| Beat | Player sees | Action | Feedback / recovery |
| --- | --- | --- | --- |
| Arrival | Gate and Play focal point; one primary screen action; a quieter preparation entry | Open Play or walk to a mode pad | Same available modes whichever route is used |
| Choose | Mode cards first; team names and counts; current setup summarized second | Choose mode and Red/Blue | Server response updates queue state or explains why joining failed |
| Queue | Persistent mode/team/status and Leave; preparation still reachable | Edit Loadout, wait, or Leave | Save acknowledgment; queue remains active until Leave or commitment |
| Commit | Queue controls close once server commits roster | No new lobby choice | Current acknowledged setup is used in match |
| Return | Lobby view and Play control restore once | Requeue or prepare | No duplicate modal, stuck focus, or stale queue badge |

The existing [kit screen specification](../kits/KIT_SELECTION_UI_SPEC.md) adds a later browser and lock-in beat after its server dependencies are implemented. It does not change this baseline journey yet.

## 4. Screen structure and behavior

### Persistent lobby navigation

- One visually dominant **PLAY** control. One secondary preparation entry remains visible. Profile and Customize can move into a secondary **MORE** surface only after direct access and back/focus paths are verified. Do not remove a working route just to simplify the bar.
- Do not place the bar over the Roblox backpack, movement controls, jump/fire controls, topbar or player list. Use `Screen.onChange` and safe insets; test the actual rendered rectangles. A fixed desktop offset is a provisional repair, not device acceptance.
- The lobby bar appears only in Lobby/Queued states; it hides at commitment and restores once on return. The queue badge does not cover the Play control or hotbar.
- When queued, status must state mode and team and provide one obvious **LEAVE QUEUE** action in the Play surface. It must never say “Searching” after commitment or cancellation.

### Play surface

Content order: title → queue state/error if applicable → mode/team cards → compact current setup → Edit Loadout. The first mode must be visible without scrolling at 1287 × 665 and at the supported small-phone landscape height. If this cannot fit, use a responsive mode list rather than shrinking type or targets.

- Each mode card gives name, short purpose, Red/Blue counts and usable actions. Counts and queue state come from `QueueService`, including when the player joins through a physical pad.
- Loading shows “Loading modes…” and disables join actions. Empty/unavailable shows a specific reason and a retry/close path. A failed join leaves the player in the Play surface with the reason visible.
- Joining the same mode/team while already queued shows the selected state without issuing a misleading second request. Joining another queue must follow the server's actual switch behavior.
- A queue badge is a summary; the Play surface remains the place for full status and Leave. Any edit acknowledgment comes from the relevant service, not optimistic client text.
- Escape, controller B and the visible close control return to lobby navigation. Controller focus lands on Play after close and remains valid after a status refresh.

### Preparation and future Kits

- Today's Loadout remains accurate, including the existing Alter Ego slot. Avoid renaming that slot Kits until kit selection is authoritative.
- Once the KitService is ready, replace Alter Ego presentation and world bay with Kits as a separate acceptance slice. Show the selected kit name and access state near the preparation entry; two permanent free kits and two rotating free kits need distinct text labels. Purchases belong in the full browser, never in a short match countdown.
- A saved, usable starter kit must allow match entry without visiting the browser. The server owns selection, trial expiry, rotation and committed match snapshot.

## 5. Lobby world and camera

- Treat the [editable source model](../../../assets/environment/source/Lobby.rbxm) as the source of truth. Follow [the Studio editing workflow](EDITING.md); save and validate before testing the baked copy. Do not hand-edit generated lobby geometry.
- From each of the five spawns, the initial player camera must show a single readable Play gate or its unmistakable near-field marker. Record the actual camera view at default avatar scale and with a large character silhouette. If the camera points down or the avatar occludes the gate, fix spawn facing/camera framing before adding signage.
- Give the Play hall the strongest shape and light contrast. Put Armory/preparation and character displays to the sides. Limit the arrival sightline to one primary destination label and at most two subordinate destination labels. Remove redundant overhead copy and distant billboards that intersect the gate or main UI.
- Develop a Convergence-specific focal object: a contained dark-matter anomaly/energy aperture within the Play gate. It should read as a controlled scientific hazard, with restrained motion and light. A static, low-effects version must keep the same silhouette and wayfinding.
- Character displays may show kit fantasy later; they must not imply a kit is owned or selectable before the backing system exists. Preserve safe walking routes and pad footprints. Art changes must not silently change queue rules or collision.
- Define the final environment art target with comparable Studio captures before a full art pass. The existing blockout is sufficient to test layout and flow, but it is not the visual quality target.

## 6. Visual system and accessibility

- Use `Theme` surfaces, type ramp, status colors and over-world text treatment; team red/blue are reserved for teams, amber for the primary interaction. Text and shape also identify selected, queued, locked and unavailable states.
- Panels carrying text must remain readable against both bright sky and dark lobby materials. World signs use a bounded viewing distance and do not stack over one another at spawn.
- Use `Screen.newScreenGui`, `Screen.autoScale`/`fitWithin`, `Screen.onChange` and `Screen.tapSize` as applicable. No raw screen-edge placement, controller-local colors or sub-44-point touch actions.
- Support mouse/keyboard, touch and controller on the same flow. Validate focus order, close/back behavior, long mode names, localized text expansion, and reduced effects. Do not rely on hover or color alone.
- Use at most one informational banner in the top-center strip at a time. First-use guidance should dismiss after a successful queue and must not obscure the gate; later Lobby returns show contextual queue or event status only when relevant.

## 7. Ownership and implementation order

| Slice | Work | Owner / source | Gate |
| --- | --- | --- | --- |
| 0. Reproduce | Open exact built revision; capture all spawns, viewport, output and current UI rectangles. Resolve stale Studio sync. | Studio test record; `default.project.json` | G0 |
| 1. Functional UI | Verify/fix hotbar separation, mode-first Play, queue/Leave status, loading/error/return and focus. | `LobbyNavigationController`, `HudController`, `Screen`, `Theme` | G2 |
| 2. Arrival composition | Adjust source spawn markers, gate framing, wayfinding and low-cost lighting; validate and bake source. | `assets/environment/source/Lobby.rbxm`, `LobbyAuthoring`; [handoff](../../../assets/environment/source/Lobby.HANDOFF.md) | G2/G3 |
| 3. Art and polish | Approved dark-matter focal object, side character displays, restrained signs/VFX/audio; low-effects variant. | Lobby source and asset handoffs | G3/G4 |
| 4. Kits transition | Replace Alter Ego routes and labels only with working kit authority, selection, rotation and lock-in. | KitService, loadout/UI, world bay; [kit spec](../kits/KIT_SELECTION_UI_SPEC.md) | Separate G2–G4 |

Do not implement the visual overhaul by adding a second queue or moving game rules into UI. The current working tree has unrelated changes; inspect diffs and preserve them.

## 8. Acceptance and evidence

| ID | Requirement | Test and pass threshold | Status |
| --- | --- | --- | --- |
| LFX-01 | Arrival action is obvious | Capture every spawn in fresh Studio Play at default camera. In a small fresh-player test, at least 8 of 10 identify Play within five seconds without a prompt. Capture evidence pending. | Unverified |
| LFX-02 | Gate reads as destination | From every spawn at default avatar scale, Play gate or near-field marker is visible without rotating camera; avatar does not fully cover it. Repeat with large character silhouette. | Unverified |
| LFX-03 | No screen-control collision | No overlap with backpack, Roblox chrome, thumbstick, jump/fire or another lobby control on small landscape phone, iPad landscape/Split View, 1287 × 665, 1920 × 1080 and console. Test resize in Play. | Source repair, unverified |
| LFX-04 | Fast mode entry | First mode/team options appear without scrolling on named test views; a returning player joins a preferred queue in no more than five deliberate actions. | Source order changed, unverified |
| LFX-05 | Queue truth and recovery | With two clients, mode/team counts agree; queue badge appears after acceptance; Leave clears it; rejected join shows reason; editing loadout keeps queue. | Unverified |
| LFX-06 | Match boundary | Last server-acknowledged setup before commitment spawns; later edits reject; lobby navigation returns once after match/abort. | Unverified |
| LFX-07 | Input and readable states | All core actions work by mouse, touch and controller; visible focus, Escape/B/close recovery, 44-point touch targets, readable long labels and bright-sky contrast. | Unverified |
| LFX-08 | Source-to-Studio fidelity | Editing copy Play, saved source conversion and fresh baked-copy Play show the same intended lobby; source validation passes. Record place revision and screenshots. | Local validator passed; Studio comparison pending |
| LFX-09 | Visual hierarchy | In comparable spawn captures, one gate/Play destination dominates; secondary signs and character displays remain legible without intersecting the action or each other. Review on low and high graphics. | Design target pending capture |
| LFX-10 | Honest kit transition | No Kits purchase/selection/lock-in UI appears as functional before server acceptance tests in the kit spec pass. | Dependency pending |

These numbers are proposed acceptance targets, not measured user outcomes. Store screenshots and test notes with source revision, place ID, viewport, input, graphics level, client count and effective tuning. Static checks and a successful Rojo build are prerequisites, not proof of in-game presentation.

## 9. Test blockers and handoff

- Verify Rojo sync or open the fresh built place before judging the local UI correction. Studio Stop/Play alone did not load the edited source in the 2026-11-09 session.
- Investigate the SnowFortress incomplete turret template before claiming a full lobby-to-match run on that map. The observed fallback to Arena is a separate defect.
- Studio DataStore access was unavailable in the captured session; use a permitted test setup for persistence claims and label mock-store observations accordingly.
- Run the existing lobby authoring check, formatting/lint and Rojo build, then the device and two-client Studio scenarios above. Update the [design packet](design-packet.md) and [lobby model handoff](../../../assets/environment/source/Lobby.HANDOFF.md) with actual captures and pass/fail evidence.

Next concrete action: open the freshly built place or reconnect Rojo, capture all five spawn views and the Play drawer at 1287 × 665, then fix the first verified sightline or overlap failure before starting the art pass.
