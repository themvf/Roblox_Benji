# Alter Ego and Mutation System v1

## Goal
Create a signature system where each player chooses an **Alter Ego** before the match and earns access to a temporary **Mutant Form** through strong in-match performance.

Core fantasy:

> Choose who you are. Earn your mutation. Decide when to unleash it.

The system must reinforce objective play rather than reward kill farming alone.

## v1 Scope
Prototype only:
- Alter Ego: **Titan**
- Mutant Form: **Colossus**
- Mutation Meter: 0–100
- Manual activation
- Transformation duration: **25 seconds**
- Abilities: Ground Slam, Brace, Charge

Out of scope:
- Full 4–6 Alter Ego roster
- Mutant skins
- Skill trees
- Ranked balance
- Paid combat advantages
- Cross-match mutation persistence

## Player Flow
1. Select Titan in lobby.
2. Enter match.
3. Earn Mutation Energy.
4. Meter reaches 100.
5. HUD shows `MUTATION READY`.
6. Player activates manually.
7. Transform into Colossus.
8. Mutant abilities become active.
9. Revert automatically after 25 seconds.
10. Meter resets.

## Mutation Energy
Recommended starting values:

| Event | Energy |
|---|---:|
| Kill | +20 |
| Assist | +10 |
| Objective capture | +25 |
| Objective defense tick | +5 |
| Bounty kill | +30 |
| Save/support action | +10 |
| Win contested objective | +15 |

Rules:
- Cap at 100.
- Server authoritative.
- No duplicate event rewards.
- Resets after transformation.
- No carry-over between matches in v1.

## Activation
Do not auto-transform.

When full:
`MUTATION READY`

Default keyboard input:
`Q`

Server rejects activation when:
- Dead
- Respawning
- Already mutated
- Match ended
- Invalid player state

## Transformation
Target animation/effect length:
- 1.0–1.5 seconds

Include:
- Character transformation
- Sound
- VFX
- HUD announcement
- Announcer call

Example:
`TITAN HAS MUTATED`

## Colossus Abilities

### Ground Slam
- Area knockback
- Moderate damage
- Strong visual cue
- Initial cooldown: 7 sec

### Brace
- Temporary frontal resistance
- Slower movement while active
- Duration: 3 sec
- Cooldown: 8 sec

### Charge
- Short forward rush
- Pushes enemies hit
- Limited steering
- Cooldown: 6 sec

## Balance Guardrails
Mutation should add new gameplay, not just larger numbers.

Avoid:
- Massive damage multipliers
- Massive permanent HP bonuses
- Instant-kill attacks
- Endless transformation

Focus on:
- Disruption
- Movement
- Objective pressure
- Positioning

## Recommended Architecture

### AlterEgoService
Owns:
- Selection
- Validation
- Spawn integration
- Current Alter Ego state

### MutationService
Owns:
- Energy
- Activation
- Mutant state
- Duration
- Reversion
- Cooldowns

### AbilityService
Owns:
- Ability validation
- Damage
- Knockback
- Cooldowns
- Replication

## Client Responsibilities
Client may:
- Display meter
- Display ability UI
- Play cosmetic effects
- Send activation requests

Client must not decide:
- Energy gain
- Damage
- Knockback
- Cooldown completion
- Mutation duration
- Reward eligibility

## Suggested State
```lua
PlayerMutationState = {
    AlterEgoId = "Titan",
    Energy = 0,
    IsMutated = false,
    MutationEndsAt = 0,
    AbilityCooldowns = {
        GroundSlam = 0,
        Brace = 0,
        Charge = 0,
    }
}
```

## UI
Lobby:
- Selected Alter Ego
- Portrait/name
- Change button

Match HUD:
- Mutation meter
- Percentage
- `MUTATION READY`
- Mutant timer
- Ability cooldowns

Results:
- Mutation activations
- Mutant kills
- Objective contribution while mutated

## Telemetry
Log:
- Energy earned by source
- Time to first mutation
- Mutations per match
- Mutation activation timing
- Mutant kills/deaths
- Objective score while mutated
- Ability usage
- Ability hit rate
- Average transformation survival time
- Players reaching 100 but never activating

## Acceptance Criteria
Pass when:
- Titan can be selected.
- Meter fills correctly.
- Objective actions award energy.
- Meter caps at 100.
- Activation is manual.
- Server rejects invalid activation.
- Transformation lasts ~25 sec.
- All three abilities work.
- Cooldowns work.
- State replicates to other players.
- Reversion is clean.
- Meter resets correctly.
- Client cannot spoof energy.

## Future Expansion
Only after the prototype is fun:
- Ghost → Wraith
- Titan → Colossus
- Hunter → Predator
- Volt → Tempest
- Medic → Reclaimer
- Marksman → Overseer
