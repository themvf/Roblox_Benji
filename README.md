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
4. Test with Test > Clients and Servers (2+ players). Everyone spawns in the lobby; walk onto the green pad (1v1) or blue pad (2v2) to queue.

## Layout
- `src/server/Services`   Knit services. QueueService watches the lobby pads, RoundService runs a match, MapService builds arena + lobby, WeaponService hooks the Weapons Kit.
- `src/client/Controllers` input handling and HUD
- `src/shared`             Config, map layouts, and Rivals weapon stats
- `assets/WeaponsSystem.rbxm`  Roblox Weapons Kit (firing, bullets, recoil, GUI, camera)
- `assets/weapons/tools/`      One Tool per Rivals weapon, generated from the kit models
- `tools/build_weapons.luau`   Rebuilds those tools from `src/shared/Weapons` stats: `lune run tools/build_weapons.luau`
- `src/shared/Skins/`          Skin registry + validator (the Weapon & Skin Design Spec as code)
- `tools/check_skins.luau`     Build gate: `lune run tools/check_skins.luau` fails on any spec violation

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
Mouse1 fire or swing, Mouse2 aim, R reload, 1-4 switch slots (Primary, Secondary, Melee, Utility), Shift sprint. Guns are the Weapons Kit; melee is MeleeService.

## Next steps
- Shooting range with target dummies, leaderboard, skins
- Utility weapons (Flamethrower, Exogun) and the Gunblade dash; more melee (Knife, Scythe)
- Kits/abilities like Rivals (dash, grapple)
- ProfileStore for saving wins, kills, and unlocked weapons
