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
- `src/server/Services`   Knit services. RoundService is the match loop, WeaponService validates hits.
- `src/client/Controllers` input handling and HUD
- `src/shared`             Config and weapon stats, read by both sides

## Controls
Mouse1 fire, R reload, 1/2/3 switch weapons.

## Next steps
- Team-specific spawn points (SpawnLocation.TeamColor + real Teams service)
- Weapon models, animations, muzzle flash, hit markers
- Kits/abilities like Rivals (dash, grapple)
- ProfileStore for saving wins, kills, and unlocked weapons
