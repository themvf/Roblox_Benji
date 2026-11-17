# patrol-rhib handoff

## Approved decisions (user, 2026-11-16)

- Subject: black rigid inflatable patrol boat with centre console, twin outboards and radar arch.
- Where: Five Islands Hurricane. It replaces the block-built RHIBs (two per team dock, four in all).
- Use: driven. Role `interactive`, kind `vehicle`, game name `RHIB`, one working seat for now.
- Size: 30 studs long, 10 wide ("the size is fine"). The current block RHIB is about 14 long and 6 wide,
  so this is over twice as long; the dock positions will need moving when it is wired in.
- Style: the user wants to see both a realistic and a chunky version.
- Logo: left off. It was painted out of `source/reference.png` before anything used it.
- Share: might be shared -> `public`. Rights are NOT cleared: the reference is a manufacturer's product
  render supplied by the user. Fill the rights note before the asset leaves this game.
- Upload once the user has approved the pictures.
- Agent-chosen: height 8 studs, no self-moving parts, package name.

## Stage

Stage 4 (local verification) reached for the chunky version. Stage 5 (user approval) not done.

## Evidence

- Chunky version: `tools/blender/build_patrol_rhib.py` -> `exports/PatrolRhibClean.glb`, 2,104 triangles in
  one mesh (budget 15,000). Size 10.22 x 8 x 30.0 studs. Holes 0.28% worst view (limit 1.5%).
  The first build failed the hole gate at 53%: the lower hull was inside out. Fixed in the builder.
- Mounts: `DriverSeat` [0, 2.92, -1.2], `HullCentre` [0, 1.2, 0]; `review/mounts.png`. HullCentre sets the
  waterline and is a first guess; check it in Studio.
- Written review: `review/findings.json` (six findings).
- Realistic version: NOT built. `generate` stopped on the Hugging Face ZeroGPU quota (about 23 hours to
  reset from 20:07 on 2026-11-16). No candidate exists. Note that a scan of this boat is expected to fail
  the gates as an interactive asset (thin arch and rails, 15,000-triangle budget).

## Next action

1. User looks at `review/audit.png` and `review/audit_closeups.png`; record their words with `verdict`.
2. When quota is back: `generate source/reference.png --name patrol-rhib-scan` under its own package for the
   realistic comparison, if the user still wants it.
3. After approval: `publish patrol-rhib --confirm`, then wire it in: `buildRHIB` in
   `src/server/Services/VehicleService.lua` reads the id and mounts from the registry (the wave runner is the
   worked example), and the `RHIB` docks in `src/shared/Maps/FiveIslandsHurricane.lua` move apart for the
   longer hull. Then Studio: enter, drive forward, waterline, seat height, exit.

## Update 2026-11-16 (evening) - approved, uploaded, wired in

- User on the review sheets: "It looks great. Please replace and make it driveable" -> `review/verdict.json` good.
- `publish patrol-rhib --confirm` -> asset **70498391528292**, recorded in `src/shared/AssetRegistry.json`.
- Mount change after upload: `DriverSeat` lowered to [0, 2.52, -1.2] so the seat part's top is the cushion.
  The rebuild is byte-identical to the uploaded file (same sha256), so the upload is still current.
- Game code: `buildRHIB` in `src/server/Services/VehicleService.lua` loads the mesh from the registry, with an
  invisible deck block (6.8 x 1.1 x 22) and two collar blocks for collision and one `DriverSeat`. If the asset
  does not load it falls back to the old block-built boat.
- Map: `src/shared/Maps/FiveIslandsHurricane.lua` RHIB docks moved to x = +/-262, z = +/-10 (alongside the dock,
  stern one stud clear of the beach at x = 278), seats 1. Wave runner docks moved to x = +/-272, z = +/-20.
- Gates: stylua, selene, rojo build, check_maps, check_live_map, check_map_authoring, check_asset_registry pass.
  check_bake fails on MyMap only (its source .rbxm was already modified before this work).

## Stage

Stage 6 (Studio verification) NOT done. Nothing below has been seen running.

## Next action

In Studio on Five Islands Hurricane (Stop/Start the playtest first): the boat loads at each dock, faces away
from the beach, sits with the collar just above the water, "Drive" prompt reachable from the dock end, the
driver sits on the helm seat, it drives forward bow-first, and you can stand on the deck. Then
`python tools/asset_generate.py verify patrol-rhib --check loads --check facing --check scale --check materials --check collision`.
If it rides too high or low, change `HullCentre` with `brief patrol-rhib --mount HullCentre=0,<y>,0` and rebuild.
