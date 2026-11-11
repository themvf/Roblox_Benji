# Kit minimum specification and acceptance checklist

Use this checklist for every gameplay kit. It defines the minimum information and
evidence needed to begin implementation and to call a kit release-ready. A checked
box means the linked decision or evidence exists; code merely existing does not
satisfy a verification item.

Copy the checklist into the kit's design packet or link each item to its evidence.
Use **Decided**, **Hypothesis**, **Verified**, or **Not applicable — reason** where a
binary answer would hide uncertainty.

## 1. Identity and access — required before implementation

- [ ] Stable internal ID uses the agreed naming convention and will not be reused.
- [ ] Player-facing name, one-sentence fantasy, and role are defined.
- [ ] The kit's repeatable player decision is stated; it is not only a visual theme.
- [ ] Access is declared as `Starter`, `Purchasable`, or another approved type.
- [ ] Rotation eligibility is declared. A starter kit cannot consume a rotation slot.
- [ ] Purchasable access specifies the intended permanent-unlock method; unimplemented
      product IDs or prices are labeled pending rather than invented.
- [ ] The fallback starter kit is defined for unavailable, expired, or invalid access.
- [ ] The server-owned selection lock boundary is defined. Selection cannot change
      after the pre-match lock-in expires or during a match.

## 2. Gameplay contract — required before implementation

- [ ] One passive trait is defined in observable player terms.
- [ ] One tactical action is defined in observable player terms.
- [ ] The tactical occupies the Utility slot unless an approved system-level decision
      changes that rule for every kit.
- [ ] The kit has an explicit cost, limitation, or vulnerable window.
- [ ] At least one practical enemy counter is documented.
- [ ] The kit is a sidegrade. Purchase status does not justify greater combat power.
- [ ] No kit directly modifies a weapon's damage, fire rate, accuracy, recoil, range,
      magazine size, reload time, projectile count, or other weapon definition.
- [ ] Any health, resistance, healing, movement, reveal, crowd-control, or objective
      effect is visible, bounded, and separately tunable.
- [ ] Effect stacking, duplicate kits, refresh behavior, and maximum simultaneous
      effect are defined.
- [ ] Rules for spawn, death, respawn, disconnect, match end, and a second match in the
      same server are defined.

## 3. Tuning and authority — required before implementation

- [ ] Every gameplay number has a named default, valid range, unit, and application
      timing.
- [ ] The server owns eligibility, targets, damage, healing, effects, cooldowns, and
      objective interaction.
- [ ] The client sends an action request, not a claimed result.
- [ ] Requests validate type, finite numeric values, match participation, alive/state
      eligibility, target/team, distance or line of sight where relevant, cooldown,
      and request rate.
- [ ] Client-owned movement uses the project's server-approved movement pattern and
      does not trust client-reported hits or destinations.
- [ ] Temporary modifiers have a unique source and are removed on every exit path.
- [ ] Any movement-speed effect uses `Shared/Movement`; kit code does not write
      `Humanoid.WalkSpeed` directly.

## 4. Input and feedback — required before implementation

- [ ] The tactical has a named input action shared by keyboard, gamepad, and touch.
- [ ] Keyboard and gamepad bindings are defined and do not conflict with weapons,
      movement, scores, or menus.
- [ ] The touch button has a short action label, tap/hold behavior, and intended HUD
      region outside reserved controls.
- [ ] Ready, active, cooldown, blocked, failed, death, and match-ended states have
      player-visible feedback.
- [ ] An unavailable action reports a useful reason; color is not the only state cue.
- [ ] Hold actions define release on input end, focus loss, death, HUD disable, and
      character or kit removal.
- [ ] Opponents can recognize activation, affected area or direction, duration, and
      recovery window from combat distance.

## 5. Visual and audio package — required before final asset production

- [ ] Authoritative references and their ownership or license are recorded.
- [ ] Front, side, and rear designs exist, or the missing views are explicitly approved
      as an authoring decision rather than inferred silently.
- [ ] Neutral, tactical-active, and team-readability states are shown.
- [ ] Scale is compared with the standard R15 character and normal weapon grip.
- [ ] Camera, doorway, cover, objective, crouch, slide, and weapon-clearance risks are
      identified.
- [ ] Cosmetic geometry is non-colliding, massless, and does not change gameplay
      hitboxes or raycast targets.
- [ ] Team identity remains readable independently of the kit's palette.
- [ ] Custom art has an asset package with `HANDOFF.md`, `README.md`, `appraisal.json`,
      reproducible source/export instructions, review renders, and `validation.json`.
- [ ] VFX and audio communicate gameplay timing without obscuring targets, crosshairs,
      objectives, or other team effects.
- [ ] Kit skins change presentation only; their definitions contain no gameplay values.

## 6. Data, ownership, and rotation — required before public access

- [ ] The shared kit definition passes the kit validator and references a known
      server-side ability handler.
- [ ] Selected kit and permanent ownership persist through the profile schema.
- [ ] Server-side entitlement checks cover starter, owned, and currently rotating kits.
- [ ] The two permanent starter kits always remain usable.
- [ ] The active rotation contains exactly two eligible, distinct, non-starter kits.
- [ ] Rotation time and timezone are deterministic and visible in the lobby.
- [ ] Rotation changes never remove a kit from an active or committed match.
- [ ] Expired trials fall back safely in the lobby without deleting permanent ownership.
- [ ] Failed or delayed entitlement checks fail to a starter kit rather than granting a
      purchase or blocking play.
- [ ] Purchase receipt handling is idempotent and recoverable before any real-money
      product is enabled.

## 7. Telemetry — required before balance claims or sales

- [ ] Selection, access source (`Starter`, `Trial`, or `Owned`), map, mode, team, and
      relevant loadout are recorded.
- [ ] Tactical attempts, accepted uses, rejections by reason, effects/hits, and cooldown
      availability are recorded.
- [ ] Passive triggers and meaningful outcomes are recorded.
- [ ] Objective contribution, kills, deaths, assists, damage, support, and match result
      can be compared by kit.
- [ ] Duplicate-kit team count is recorded so stacking effects can be evaluated.
- [ ] Trial-to-permanent-unlock conversion can be measured without treating conversion
      as proof of balance.
- [ ] Simulation or match count is not described as calibration or empirical balance
      without representative multiplayer evidence.

## 8. Minimum acceptance evidence — required before release

- [ ] Automated validation, formatting, lint, and build gates pass; unrelated failures
      are reported separately rather than hidden.
- [ ] Server rejection is demonstrated for dead, cooldown, wrong-team, out-of-range,
      malformed, spammed, and match-ended requests where applicable.
- [ ] The complete action works through keyboard, gamepad, and touch using the same
      controller-to-server path.
- [ ] Small-phone and tablet captures show readable status and no overlap with movement,
      jump, fire, aim, weapon selection, chat, or safe areas.
- [ ] Two opposing clients can identify, use, counter, and observe the kit consistently.
- [ ] Intended team population is tested with duplicate kits and overlapping effects.
- [ ] Idle, run, sprint, crouch, slide, jump, aim, fire, reload, melee, death, and
      respawn are checked with the final visual asset.
- [ ] At least one representative match is checked on every supported map; geometry and
      objective interactions remain valid.
- [ ] Death, disconnect, match abort, normal match end, lobby return, and a second match
      leave no stale modifiers, UI, sounds, VFX, or temporary objects.
- [ ] Effective tuning values, source revision, local diff, map, roster, device/input,
      and evidence links are recorded.
- [ ] Known limitations and unverified cases are listed. Studio import, local rendering,
      or a passing build is not reported as live-game acceptance.

## Bare-minimum kit record

Complete this summary before implementation. It is an index, not a substitute for the
evidence above.

```markdown
# <Display name> (`<KitId>`)

- Status / gate:
- Owner / updated:
- Role and one-sentence fantasy:
- Access type / rotation eligible:
- Fallback starter kit:
- Player decision:
- Passive:
- Tactical / Utility-slot behavior:
- Cost or vulnerable window:
- Enemy counterplay:
- Duplicate/stacking rule:
- Tuning source and valid ranges:
- Keyboard / gamepad / touch action:
- Ready / active / cooldown / failure feedback:
- Server handler and validation:
- Visual reference and asset handoff:
- Team-readability treatment:
- Telemetry events:
- Acceptance evidence:
- Known limitations / next concrete action:
```

