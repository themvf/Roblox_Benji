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

## Controls
Mouse1 fire or swing, Mouse2 aim, R reload, 1-4 switch slots (Primary, Secondary, Melee, Utility), Shift sprint. With the Jetpack equipped, hold Jump to fly. Guns are the Weapons Kit; melee is MeleeService; utility is UtilityService.

## Next steps
- Shooting range with target dummies, leaderboard, skins
- More utility (Flamethrower, Exogun), the Gunblade dash, more melee (Knife, Scythe), party queue
- Kits/abilities like Rivals (dash, grapple)
- ProfileStore for saving wins, kills, and unlocked weapons
