# Neutron (`Neutron`)

Definition: [Neutron.lua](../../../../src/shared/Kits/Registry/Neutron.lua) · Checklist:
[KIT_MINIMUM_CHECKLIST.md](../KIT_MINIMUM_CHECKLIST.md) · Workflow: the `kit-from-prompt` skill.

The worked example for the kit workflow, taken from the mock kit card in
`src/client/UI/MockCatalog.lua`. It is a design, not a kit anyone can play.

- Status / gate: Design. Passes `check_kits`; no handler, no art, nothing played.
- Owner / updated: Claude, 2026-11-17.
- Role and one-sentence fantasy: **Decided.** Defense. "Hold territory by resisting displacement."
- Access type / rotation eligible: **Decided.** Purchasable, rotation eligible. **Pending:** Credit price.
- Fallback starter kit: Titan.
- Player decision: **Hypothesis.** When to plant on a point and brace, and when to give ground.
- Passive: **Hypothesis.** Inertial Frame: 50% less knockback while standing in an objective zone.
- Tactical / Utility-slot behavior: **Hypothesis.** Degenerate Armor: 3 s frontal brace, 50% less damage from the front, 0.6x speed, no aiming down sights. 12 s cooldown.
- Cost or vulnerable window: slow and unable to aim for the whole brace; back and sides take full damage.
- Enemy counterplay: flank, or wait out the brace.
- Duplicate/stacking rule: each Neutron braces separately; a new brace refreshes, never adds.
- Tuning source and valid ranges: the definition file; ranges are written there.
- Keyboard / gamepad / touch action: G / DPadRight / BRACE.
- Ready / active / cooldown / failure feedback: not designed.
- Server handler and validation: `ObjectiveKnockbackResist`, `FrontalBrace`. Neither exists. The mutation Brace in `AbilityService` is the closest code to reuse.
- Visual reference and asset handoff: none.
- Team-readability treatment: not designed.
- Telemetry events: tactical attempts, accepted, rejected by reason, hits blocked; passive triggers.
- Acceptance evidence: none.
- Known limitations / next concrete action: build the kit runtime (selection, ownership, the shared kit action), then the two handlers.

## Not verified

Nothing has been played. Every number is a placeholder.
