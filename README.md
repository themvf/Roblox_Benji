# Arena (Rivals-style team shooter)

Round-based 3v3 arena shooter. Teams are assigned at match start, a round ends
when one team is eliminated or the timer runs out, first team to 5 rounds wins.

## One-time setup
1. Install Rokit: https://github.com/rokit-tools/rokit/releases
2. In this folder run:
   ```
   rokit install
   wally install
   rojo serve
   ```
3. In Roblox Studio, install the Rojo plugin (Plugins > Rojo > Connect) while `rojo serve` is running.
4. Test with Test > Clients and Servers (2+ players). Everyone spawns in the lobby; stand on the RED or BLUE half of the big gold CONVERGENCE pad (or a DUEL side pad) to queue on that team; friends stand on the same half.

## Layout
- `src/server/Services`   Knit services. QueueService watches the lobby pads, RoundService runs a match, MapService builds arena + lobby, WeaponService hooks the Weapons Kit.
- `src/client/Controllers` input handling and HUD
- `src/shared`             Config, map layouts, and Rivals weapon stats
- `assets/WeaponsSystem.rbxm`  Roblox Weapons Kit (firing, bullets, recoil, GUI, camera)
- `assets/weapons/tools/`      One Tool per Rivals weapon, generated from the kit models
- `tools/build_weapons.luau`   Rebuilds those tools from `src/shared/Weapons` stats: `lune run tools/build_weapons.luau`
- `src/shared/Skins/`          Skin registry + validator (the Weapon & Skin Design Spec as code)
- `tools/check_skins.luau`     Build gate: `lune run tools/check_skins.luau` fails on any spec violation
- `src/shared/Celebrations/`   Celebration registry + validator; `lune run tools/check_celebrations.luau`
- `src/shared/Maps/Validate.lua` Map validator (the spec's VALIDATE MAP as code); `lune run tools/check_maps.luau`
- `src/server/ProfileStore.luau` MadStudioRoblox ProfileStore (vendored); DataService saves loadout, favourites, skins, stats

## Editing in Studio (no code)
TuningService creates two Studio-owned objects the first time the game runs; Rojo never touches them:
- `ReplicatedStorage.Tuning`  a Configuration with attributes (RoundSeconds, RoundsToWin, IntermissionSeconds,
  RespawnSeconds). Change them in the Properties panel; they apply to the next round or match.
- `ReplicatedStorage.Uploads` a folder for assets you upload: add a Decal, Sound or Animation, name it, and
  reference it as `upload:<Name>` from any skin or celebration. Example: a Decal named `BlueCamo` finishes every
  Uncommon camo skin at once; a Sound named `WinSting` can be `Audio.Sting = "upload:WinSting"` in a celebration.
Map layouts (`src/shared/Maps/*.lua`), weapon stats (`src/shared/Weapons`), skins and celebrations remain code
files, but each is a plain table of numbers and names.

## Saving
DataService loads a ProfileStore profile per player into attributes (`Loadout*`, `CelebrationFavorites`, `Skin_*`,
`Wins`, `Kills`, `Matches`) and mirrors attribute changes back. In Studio, enable
Game Settings > Security > "Enable Studio Access to API Services" to save for real; otherwise ProfileStore uses a
mock store and prints a warning.

## Alter Ego and Mutation (v1 prototype: Titan -> Colossus)
Pick an Alter Ego at the kiosk (Titan only in v1; persisted). In a match, energy is server-authoritative:
kill +20, assist +10, capture +25 (+15 if the zone was contested in the last 10 s), +5 per 10 s defending,
bounty kill +30; cap 100. `MUTATION READY` -> press Q. Colossus lasts 25 s, scales 1.35x with a molten glow, then
reverts (or on death). Abilities: E Ground Slam (14-stud knockback, 35 dmg, 7 s), F Brace (60% frontal damage
resistance, 60% speed, 3 s, 8 s cd), C Charge (0.6 s rush at 70 studs/s with limited steering, 20 dmg + push, 6 s).
Knockback and charge movement are applied on the victim's / charger's client (client-owned characters); all
validation, damage, cooldowns and timers are server side. A MUTATION REPORT prints at match end (energy by source,
time to first mutation, activations and timing, mutant K/D, objective score while mutated, survival time, players
who reached 100 and never activated, ability uses and hits). Numbers live in `Shared/AlterEgos`.

## Competitive loop (Phases 1-2 of the bounty/streak design)
- Match score = Objective + Defense + Teamplay + Combat + Discipline (weights in `Shared/Progression`). MVP is the
  top scorer on the winning team; the recap card shows the breakdown. Hold Tab for the scoreboard.
- Only completed public matches count (>= 90 s, not aborted). Bot matches count while `Debug_CountBotMatches` is on.
- Streaks: 2 Heating Up, 3 Hot Streak, 5 On Fire, 8 Elite, 10 Legendary, 15 Mythic. Checkpoints at 3/5/8/10 are
  saved forever. A loss resets the run, not the legacy. Lobby nameplates and the pre-match card show streak status.
- Match bounties (XP + titles only): Combat (4/7/10 kills in one life -> Marked / Priority Target / Overrun) and
  Objective (2 captures in a life, 90 s held in a life, or 3 stops). Markers show only with line of sight; a zone
  ping every 75 s; capture callouts. Claimed on elimination; XP split 60% opposing team / 25% hunter / 15% top
  objective contributor; eligibility needs 90 s match age, target score >= 100, hunter present >= 60 s, and repeat
  kills on the same target pay 100% / 50% / 0%. Surviving to a win while marked pays survival XP.
- Persistent stats (ProfileStore): wins, losses, K/D/A, captures, MVPs, objective score, bounties, XP/level, streaks.
- Lobby leaderboard wall (OrderedDataStore): Convergence Rating, Best Streak, Wins, Bounties Claimed.
- Not yet (Phase 3-4 by design): cross-match streak bounties with currency, rivalry ledger, weekly boards.

## Modes
- **Convergence (featured)**: 6v6 objective battle, starts at 4v4 after a 30 s wait. (Currently set to 1v1 for
  testing via `Convergence_TeamSize` / `Convergence_MinTeamSize` on Tuning; set 6 / 4 to restore.) Three capture zones close
  3 -> 2 -> 1 over three 3-minute phases; held zones score 1/s, kills 5; first to 1200 or highest at the 12-minute
  cap, with up to 60 s overtime if the final zone is in play. Respawns 5 s with 2 s protection. Capture: 8 s solo
  from neutral, +50% per teammate (max 3), enemy points neutralize first, contested freezes, empty holds.
  Every rule is a `Convergence_*` attribute on `ReplicatedStorage.Tuning`.
  Test bots implement "FPS Playtest Bot Specification v1" (see BotService.lua header): `/bots 6` adds 6 per team
  (2 Assault / 2 Anchor / 2 Flanker; 4 Normal, 1 Easy, 1 Hard). `/botlevel easy|normal|hard|mix`,
  `/botdebug off`, `/botreport` prints telemetry (spawn-to-contact, spawn-to-objective, accuracy, stuck events,
  per-bot state time) against the spec's benchmarks; a report also prints when the match ends. Any map with an `Objectives` table works;
  `Carrier` is the first built for it (Flight Deck -> Hangar -> Bridge).
- **Duel**: 1v1 / 2v2 elimination, first to 5 rounds. Side pads in the lobby.

## Out of bounds (Testability & Safety Fix Spec v1)
Detection always runs, in production as well as in testing: anyone who reaches water, below-deck or an invalid
void (`RecoveryY` / `Bounds` / `InvalidRegions`, minus `SafeRegions`) is caught within ~1.5 s. **In production
they die and respawn normally** — a map over water has no kill plane, so before this a fall into the Carrier's
sea meant swimming until the match ended, and teleporting them to safety instead would let a player escape a
lost fight by jumping off. Bots go through the same rule (`OUT_OF_BOUNDS` in the bot report, target 0).

`Debug_CarrierTestSafety` (Tuning, default true) switches the response to testing aids: recovery teleports the
player to the nearest safe point instead of killing them (logged as `RECOVERY: ...` with a reason and position),
adds an invisible perimeter barrier (bullets pass, players don't), and shows launch pad trigger volumes,
direction arrows and landing markers. The barrier is built with the map, so a mid-session toggle applies on the
next map load.
`/map carrier` (or any map name) forces the next Convergence map; `/map off` restores rotation. Launch pads use a
server-side trigger volume and apply velocity on the client (character is client-owned), 1 s re-trigger guard.

## Carrier v1 (Map Design Specification)
Data-driven layers on `Carrier.lua`: `Pickups` (weapon / speed / jetpack, S11-S13), `LaunchPads` (ballistic arcs,
S14), `SniperOutposts` (telemetry, S9), `Flyovers` (30-60 s, formations and low passes, S6), `Fleet` (background
ships with radar, nav lights and drift, S7), events with `Kind = "Kraken"` (visual only, S10) or `Flyover = true`.
Sounds are upload slots: JetPass, LaunchPad, Pickup, Kraken, Siren. A MAP REPORT prints at match end with score by
phase, outpost occupancy and kill share, launch/pickup uses and deaths (S22/S23).

## Map events and atmosphere
A map can declare `Vista` (hero camera on entry), `Events` (signature moments fired by Convergence phase: warning
banner + siren via `upload:Siren`, beacons flash, a blast shield rises, a lethal region for the duration) and living
pieces: `light`, `beacon` (flashing), `elevator` (moving platform), `jet` (chunky parked aircraft). Carrier uses all
of them; the jet-launch event fires when phase 2 begins.

## Maps
`Config.Maps` lists the rotation; each match picks one at random (never the same twice in a row) and rebuilds the
arena during the intermission. `Snow.lua` shows how to make a variant from an existing layout with a new palette.
Type `/celebrate` in the lobby to preview your default celebration on the podium.

## Celebrations
Winners pick from up to 3 favourites (kiosk, Celebration column; first = default) in a 3 s wheel after the final round,
then stand on a podium above the arena in MVP order (most kills). Common = emote only, Rare adds audio or effects,
Legendary adds props, Mythical adds a camera orbit and teammate reactions. 8 s cap; losers press V to vote skip.
Emotes are Roblox built-ins until custom animations are uploaded (swap `Motion.Emote` for `Motion.Animation`).

## Skins
A skin is one module in `src/shared/Skins/Registry/` named after its Id (`skn_<weapon>_<tier>_<concept>`).
It declares a concept sentence, materials story, sound palette, and which of the nine systems it replaces.
Rules enforced by the validator: no gameplay numbers anywhere, tier = lowest tier that admits the systems,
tier must-replace sets, naming, and concept word present in the sentence. Run the check before committing.
Pick skins at the lobby kiosk: chips under the 3D preview, coloured by tier. Assets a skin references live in
`assets/skins/Models/*.rbxm` (weapon Model templates with PrimaryPart, TipAttachment, HandleAttachment) and
`assets/skins/Shots/*.rbxm` (shot effect templates), or use the kit's built-in shot effects by name.
A system whose asset is still `TODO` is skipped at equip with one warning, so draft skins never break the game.

## Touch UI (iPhone / iPad)

`TouchController` shows a touch HUD whenever the device has a touchscreen and no keyboard
(set Tuning `Debug_ForceTouchUi = true` to preview it in Studio, or use Studio's device emulator).
Guns keep the Weapons Kit's own fire button and drag-to-aim; movement and jump are Roblox's
default thumbstick and jump button. The touch HUD adds:

- **MUTATE** (big button left of the jump button): fills with mutation energy, pulses at 100%,
  tap to transform. Replaced by **SLAM / BRACE / CHARGE** buttons while mutated, each with a
  cooldown fill and seconds remaining.
- **FLY** (above the jump button, only with a jetpack equipped): hold to burn fuel; the fill
  shows fuel. The jump button also works as a hold-to-fly control on touch and gamepad.
- **SCORES** (top right): tap to toggle the scoreboard. **SKIP CELEBRATION** (bottom center)
  during the winner celebration. Katana swings on any screen tap, as before.
- All buttons call the same controller methods as the keys, so the server-side validation and
  cooldowns are identical on every platform. Hints ("press Q") switch to "tap MUTATE" on touch.
- Not yet verified on a real device: overlap between the FLY button and the Weapons Kit fire
  button on small phones. Positions are constants at the top of `TouchController:BuildGui`.

## Controls
Mouse1 fire or swing, Mouse2 aim, R reload, 1-4 switch slots (Primary, Secondary, Melee, Utility), Shift sprint. With the Jetpack equipped, hold Jump to fly. Guns are the Weapons Kit; melee is MeleeService; utility is UtilityService.

## Next steps
- Shooting range with target dummies, leaderboard, skins
- More utility (Flamethrower, Exogun), the Gunblade dash, more melee (Knife, Scythe), party queue
- Kits/abilities like Rivals (dash, grapple)
- ProfileStore for saving wins, kills, and unlocked weapons
