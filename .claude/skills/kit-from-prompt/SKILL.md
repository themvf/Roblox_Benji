---
name: kit-from-prompt
description: Design and build a gameplay kit a player can unlock and buy in game (a passive trait plus one tactical ability) from a short description, with one round of questions up front and no check-ins after (intake -> scaffold -> definition + design record -> check_kits gate -> look -> handlers -> price -> verification). Use whenever the user asks for a new kit, class, hero or ability set, e.g. "make a kit that can teleport" or "I want a healer kit players can buy". Not for cosmetics (skins change no numbers) and not for the Alter Ego mutation abilities.
---

# A kit from a prompt

A kit is **one passive and one tactical**, picked before a match, sold for Credits that can
also be earned by playing. It is a sidegrade: it adds a decision, never a stronger weapon.
Every rule a computer can check is in `src/shared/Kits/init.lua` and enforced by
`lune run tools/check_kits.luau`; the rest is in
[KIT_MINIMUM_CHECKLIST.md](../../../docs/design/kits/KIT_MINIMUM_CHECKLIST.md).

## Where things are

| Piece | File |
| --- | --- |
| Rules, limits, caps, the shared action key, the catalog card | `src/shared/Kits/init.lua` |
| One kit's numbers and words | `src/shared/Kits/Registry/<Id>.lua` |
| One kit's design record (the checklist's bare-minimum record) | `docs/design/kits/<id>/KIT_RECORD.md` |
| Scaffold both | `lune run tools/new_kit.luau <Id>` |
| Gate (in CI) | `lune run tools/check_kits.luau` |
| Server handlers, one per ability | `src/server/KitAbilities/<Handler>.lua` (none yet) |
| Worked example | `Neutron` (design only) |
| Selection and shop screen | [KIT_SELECTION_UI_SPEC.md](../../../docs/design/kits/KIT_SELECTION_UI_SPEC.md), the `ui-from-prompt` skill |
| Purchases | [store-foundation packet](../../../docs/design/store-foundation/design-packet.md) |

## 1. Ask once

Put these to the user in **one** message, skipping any the request already answers. Record
the answers under "Intake answers" in the design record. That is the only check-in.

1. **Name and fantasy.** What is it called, and what does a player feel they are? (Or: name it for you from the lore.)
2. **Role.** Defense, Offense, Mobility, Control, Recon, Support, Sustain or Infiltration.
3. **Passive.** What is always true while you play it?
4. **Tactical.** What does the button do, and what does it cost you to press it?
5. **Counter.** How should an enemy beat it? (Or: propose one.)
6. **Price in Credits**, and whether it can also be bought with Robux, or leave it pending. A kit is never Robux-only, and the Robux amount is set in Creator Hub, not in code.
7. **Free rotation.** May it be one of the two free kits of the week?
8. **Look.** Default character, an existing model (the `Kits/` folder holds Mage, Pulsar, Robot, Mercenary, Dark Fantasy Demon), or new art.

Do not ask about numbers, keys, cooldowns, HUD placement or colours. Decide them by the rules below.

## 2. Write it

1. `lune run tools/new_kit.luau <Id>`. Both new files are full of `TODO`, which the gate refuses.
2. Fill the definition. Every number is `{ Default, Min, Max, Unit }`. Start from these:
   tactical cooldown 10 to 15 s (floor 4), effect durations 2 to 5 s (cap 12), resistances at
   most 0.5 by default (cap 0.7), speed multipliers at most 1.25 (cap 1.35).
3. **Reuse before you write.** Look in `src/server/KitAbilities` and in `AbilityService`
   (ground slam, brace, charge) for a handler that already does it with different numbers.
   A second kit using `FrontalBrace` with other tuning is far cheaper than a new handler.
4. Fill the design record. Mark each line Decided, Hypothesis, Verified or Not applicable.
   Every number you chose yourself is a Hypothesis.
5. `lune run tools/check_kits.luau` until it passes. Fix the kit, not the gate. A cap is
   raised only as a decision for every kit, recorded in `Kits.Caps` with its reason.

The gate refuses: weapon or movement keys (fire rate, recoil, reload, ammo, `WalkSpeed`…),
a Robux price without a Credits price, a starter with a price or a rotation slot, more than one
starter, a number without range or unit, an over-cap effect, a tactical under 4 s, text too
long for the card on a phone, a kit with no design record, and a kit marked `Built` whose
handlers do not exist.

## 3. Look

The character goes through the `kit-look` skill (`tools/kit_look.py`), to the BedWars-kit
minimum bar: bar, a concept sheet the user approves, one Tripo piece per body part, a review
sheet beside the benchmarks. Not `asset-from-prompt`, and never armour built from shapes.
Kit art is cosmetic: massless, non-colliding, the R15 hitbox unchanged, team colour still
readable. Record `assets/kit-looks/<Kit>` in `Look.Package`.

## 4. Build: needs the kit runtime

**Not built yet.** No `KitService` exists: nothing stores which kit a player picked or owns,
the shared kit action (G / D-pad right / one touch button) is not bound, and
`src/server/KitAbilities` is empty. Until it exists, a kit stops at `Status = "Design"` and
the report says so. When it does, each handler must:

- Run on the server, validate every request (alive, in a match, cooldown, rate) and receive
  the client's request, never its result.
- Read its numbers from Tuning (`Kit_<Id>_<Ability>_<Key>`), never from literals.
- Change speed only through `Movement.setModifier`, and remove every modifier on death,
  respawn, kit change, match end and disconnect.
- Show ready, active, cooldown and refused states through `roblox-ui-layout` (one shared
  kit button, outside the reserved zones), with a cue that is not only colour.

Then set `Status = "Built"`; the gate checks both handlers exist.

## 5. Sell: needs the store

Buying goes through `StoreService` from the store-foundation packet: Credits checked and
deducted on the server, ownership saved in the profile, the client never deciding. That
service is not built either. Until it is, a priced kit shows LOCKED / BUY on its card and an
unpriced one shows COMING SOON (`Kits.defaultCard`). Never create a Roblox product, set a
Robux price, or publish.

## 6. Verify

`Status = "Verified"` only with the checklist's section 8 evidence: two clients, every
device, every map, death/respawn/match-end leaving nothing behind. A passing gate or a
Studio import is not that evidence.

## What you bring back

One message: the kit as a player would read it (card text), the numbers you chose and why,
what the gate said, which stage it stopped at and what blocks the next one, and what was not
played. Do not commit unless asked.
