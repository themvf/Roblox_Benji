# Sprint, crouch and slide — design packet

Status: G2 code complete. Feel and device checks are pending in Studio. · Owner: Claude (author, implementer and scripted verifier; no independent review) · Updated: 2026-09-26

Request: add run and slide, including buttons for mobile (iPad and phone), in the Rivals style.
Reference: Rivals controls, where Shift sprints, Ctrl crouches (a slide while sprinting),
and mobile has auto sprint plus one crouch/slide button
([Pro Game Guides](https://progameguides.com/roblox/roblox-rivals-controls-pc-controller-and-mobile-layouts/),
[Deltia's Gaming](https://deltiasgaming.com/roblox-rivals-controls-guide/)).

## Feature checklist (ROBLOX_BEST_PRACTICES §10)

- **Player objective and success feedback.** Move faster between fights, drop low to dodge or peek, and slide into cover. Feedback is the character's speed, the camera dropping with the lowered body, and the touch button's label and status (CROUCH/SLIDE, "ON", "SLIDING", cooldown seconds).
- **Server-owned state and allowed transitions.** `MovementService` owns the replicated `Stance` attribute: nil (walk), Sprint, Crouch or Slide.
  - Crouch and slide are refused while mutated, celebrating or dead.
  - A slide is refused within `SlideCooldown` of the last one.
  - Requests are rate-limited to 20 per second.
  - Unknown or non-string stances are dropped.
  - Movement itself is applied by the client, because characters are client-owned and sprint must respond on the frame the key goes down.
- **Shared definitions.** `Shared/Config.Movement` holds the defaults. `Shared/Movement` holds the resolver, the slide easing and the speed effects. Maps need nothing new.
- **External art.** None. The pose is procedural joint bends, so no uploaded animations are needed.
- **Bindings.**
  - Sprint: hold Shift, click L3 on a controller (toggle), or automatic on touch (`AutoSprintTouch`).
  - Crouch: hold Ctrl or C, or hold B on a controller. Touch: the CROUCH button toggles it.
  - Slide: crouch while sprinting.
  - While mutated, C stays Charge and Titans don't crouch.
- **Touch button.** One button in the existing action column, LayoutOrder 80, just above MUTATE.
  - It reads CROUCH, or SLIDE while running.
  - Sub-label: tap / ON / SLIDING / cooldown seconds.
  - It's a tap action with no hold.
  - It's hidden while mutated, and shown in the lobby too, because maps are walked there.
- **Tuning (Movement_*, read live every frame).**

  | Setting | Default | Valid range |
  | --- | --- | --- |
  | WalkSpeed | 16 | 4-60 |
  | SprintMultiplier | 1.5 | 1-3 |
  | AimMultiplier | 0.5 | 0.1-1 |
  | CrouchMultiplier | 0.5 | 0.1-1 |
  | SlideSpeed | 42 | 10-120 |
  | SlideSeconds | 0.75 | 0.1-3 |
  | SlideCooldown | 1 | 0-10 |
  | AutoSprintTouch | true | |
  | AutoSprintDesktop | false | |

  An out-of-range or non-finite value falls back to the default.
- **Cleanup.** On respawn every held key, toggle and slide is cleared. Held keys are released when the window loses focus. The server's per-player state is dropped when the player leaves.
- **Edge cases.**
  - Launch pads, zip lines, Charge and celebrations block sprint, crouch and slide.
  - Aiming cancels sprint.
  - A jump, leaving the ground, or stalling against a wall ends a slide.
  - Speed effects combine in any order.
- **Build and validation.** `check_movement` passes 32 checks. `stylua`, `selene`, `rojo build` and all project gates pass.
- **Devices tested.** None yet; see below.

## Decisions

| Decision | Reason |
| --- | --- |
| One speed owner, `Shared/Movement`. Effects are `SpeedMul_<Source>` attributes. | Four systems wrote WalkSpeed directly and restored stale "base" values. A speed pickup during Brace left the player permanently at the wrong speed. |
| The Weapons Kit's sprint and aim-slow are switched off in `build_weapons`, with the same numbers (16/24/8) reproduced. | The kit sprang WalkSpeed toward its own value every frame while a gun was out, silently overriding Brace and pickups. Two sprints would fight each other. |
| The client moves the character. The server owns `Stance` and the cooldown. | Characters are client-owned (see LaunchController). Round-tripping sprint through the server would feel laggy. The stance must replicate so opponents see a crouch or slide. |
| Auto sprint on touch, with no RUN button. | This is the Rivals mobile default. It means one less button, and the thumb stays on the stick. |
| The pose is procedural (joint transforms over animation) plus a lowered HipHeight. | Custom animations need uploaded ids. HipHeight lowers the actual body, so the hitbox drops too. |

## Acceptance

| ID | Check | Status |
| --- | --- | --- |
| M1 | Shift sprints to 24, aiming drops to 8, crouch is 8 | Scripted PASS. Feel pending in Studio. |
| M2 | Brace + pickup in either order restores the exact base speed | Scripted PASS |
| M3 | Slide: burst to 42 fading to 8 over 0.75 s, then a 1 s cooldown; jump cancels it | Resolver scripted PASS. Movement pending in Studio. |
| M4 | Server refuses crouch/slide while mutated, celebrating or dead, and during a slide cooldown or a flood of requests | Scripted PASS (real service source) |
| M5 | Nothing but Movement writes WalkSpeed | Scripted PASS (source scan) |
| M6 | The kit's sprint and aim-slow are off in the built kit | Scripted PASS |
| M7 | Pose: crouching and sliding legs bend the right way, for self and for opponents | **Pending Studio.** Joint signs are a first pass (`POSE` in MovementController). |
| M8 | Touch: CROUCH/SLIDE button on a small iPhone and on an iPad (landscape and Split View) doesn't overlap jump, fire or the thumbstick | **Pending.** Use the device emulator or `Debug_ForceTouchUi`. |
| M9 | Controller: L3 sprint toggle, B crouch/slide | **Pending Studio** |
| M10 | Brace, speed pickup and Charge still behave with a gun out (previously overridden by the kit) | **Pending Studio** |
