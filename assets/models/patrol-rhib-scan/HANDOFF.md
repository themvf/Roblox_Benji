# PatrolRhibScan handoff

## Current stage

- Stage: 6, uploaded and wired in (2026-11-17). Not yet seen in Studio.
- Roblox asset id: 106441761252352, recorded in `src/shared/AssetRegistry.json` as `patrol-rhib-scan`.
- Next action: Stop/Start a Five Islands Hurricane test and run the six checks below, then
  `python tools/asset_generate.py verify patrol-rhib-scan --check loads --check facing --check scale --check materials --check collision`.
- Blockers: none.

## What it is

The realistic patrol RIB, made by Tripo from `source/reference.png` and reduced by Tripo's own
Retopo (Triangle, 25,872 polygons). It replaces the shape-built `patrol-rhib` at the Five Islands
Hurricane docks. `VehicleService` tries this body first, then `patrol-rhib`, then the block boat.

## Approved decisions

- User, 2026-11-17, after seeing the audit sheets of the 25,000-triangle model: "Remove the logo,
  and upload it to replace the current boat. Then make it driveable". They had not seen the sheets
  of this exact build (label removed, turned, scaled) when it was uploaded.
- Length 30 studs to match the boat it replaces; height 11.57 and width 10.9 follow the picture.
- One working seat, the helm (front port seat). No moving parts.

## How the source was prepared

Tripo's file was changed in two ways before `import`, by scripts that were not kept in the repo:

1. The maker's label on the port side of the collar near the stern was painted out of the colour,
   normal and roughness textures (the texels that map into a 1.5 x 0.6 stud box, filled with the
   median of the collar around it).
2. A parent node turns the model a quarter turn so the bow is the front (Roblox -Z).

`source/PatrolRhibScan.glb` is the result. To redo it from a new Tripo file, repeat both steps.

## Triangle budget: over, waived

27,348 triangles in four meshes against 15,000 for a vehicle. Cutting Tripo's 25,154 to the budget
with our own reduction made 3.33% of the model see-through (build failed). A lighter version has to
come from Tripo's Retopo at about 13,000 polygons, then `import`, `pick --replace`, `build`.
Tripo's full-detail file (1.98 million triangles) cut by us to 25,614 failed the same way at 1.75%.

## Known flaws (review/findings.json)

- One small flipped sliver on each side of the collar amidships (0.09% see-through).
- A faintly lighter rectangle on the port collar where the label was.
- Seats and engine cowls are lumpy at this triangle count; the console screen is a smeared texture.

## Studio checks, not done

1. It loads at the docks (no "did not load" warning in the output).
2. The bow points away from the dock, the way the boat drives forward.
3. It sits in the water at the collar, not on it and not sunk; the engines' lower legs are under water.
4. The helm seat is the front port seat and the character sits on it, not in or above it.
5. You can walk on the deck and the collar stops you; nothing invisible blocks the bow.
6. It drives and turns like the previous boat.

Numbers to change if a check fails: the mounts with `asset_generate.py brief patrol-rhib-scan --mount ...`
then `build` and `publish`; the collision blocks (`Deck`, `CollarOffset`, `Collar`) in `RHIB_BODIES`
in `src/server/Services/VehicleService.lua`.

## Local artifacts

- Brief: `brief.json`. Rebuild: `python tools/asset_generate.py build patrol-rhib-scan`.
- Source: `source/PatrolRhibScan.glb`. Export: `exports/PatrolRhibScan.glb`.
- Sheets: `review/audit.png`, `review/audit_closeups.png`, `review/mounts.png`.
