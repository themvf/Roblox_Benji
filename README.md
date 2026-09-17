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
4. Build a map with a SpawnLocation for each team, then test with Test > Clients and Servers (2+ players).

## Layout
- `src/server/Services`   Knit services. RoundService is the match loop, WeaponService gives loadouts and hooks the Weapons Kit.
- `src/client/Controllers` input handling and HUD
- `src/shared`             Config, map layouts, and Rivals weapon stats
- `assets/WeaponsSystem.rbxm`  Roblox Weapons Kit (firing, bullets, recoil, GUI, camera)
- `assets/weapons/tools/`      One Tool per Rivals weapon, generated from the kit models
- `tools/build_weapons.luau`   Rebuilds those tools from `src/shared/Weapons` stats: `lune run tools/build_weapons.luau`

## Controls
Mouse1 fire, Mouse2 aim, R reload, 1/2 switch weapons, Shift sprint. All handled by the Weapons Kit.

## Next steps
- Team-specific spawn points (SpawnLocation.TeamColor + real Teams service)
- Melee, utility, and projectile weapons (Rivals kit has these; the Weapons Kit supports bows and launchers)
- Kits/abilities like Rivals (dash, grapple)
- ProfileStore for saving wins, kills, and unlocked weapons
