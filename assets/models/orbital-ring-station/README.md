# Orbital ring station visual prop

The user's `Spaceship/sample_2026-10-04T221204.010.glb` is preserved as
`source/original.glb`. `source/reference.png` is the nearby concept image.
The source is a textured 3D scan of a pale, ring-shaped station, not a
flat backdrop. It has 291,943 triangles, UVs, and two embedded material maps.

## Delivery

`exports/OrbitalRingStation.glb` is the intended Roblox import file. It is
80 studs tall with its lowest visible point at Y=0, centered on X/Z, and has
a roughly 77-by-78-stud ring envelope. The visual mesh has 72,985 triangles
split into 12 named sectors; each sector is under the 10,000-triangle-per-mesh
limit. Color and metallic-roughness PNG maps are embedded. The separate copies
in `textures/` document those maps. `review/` contains actual source and
export renders; `validation.json` records counts, bounds, and hashes.

The current use is a **non-walkable visual prop**. The scan has many open edges
and is not collision or traversal geometry. Turn off collision on imported
MeshParts. If players need to walk on it, author separate floors, railings,
access, and collision in the map system. The 80-stud scale is a working size
until the user confirms distant or nearby use and a target map.

## Rebuild

From the repository root:

```powershell
python tools/build_orbital_ring_station.py
```

The script extracts and resizes the two material maps, reduces the dense scan
to about 25% of its original triangles, splits it into sectors, writes the GLB,
and validates the written file. Keep experiments in `trials/`, not `exports/`.

## Roblox Studio import

Import the GLB through the intended creator account. Verify the imported model
contains 12 MeshParts, its color and material maps load, and the full model is
about 80 studs tall. Set each MeshPart to `Anchored = true`, `CanCollide = false`,
`CanTouch = false`, and `CanQuery = false` for scenery. Check the imported
MeshPart `Color`: white preserves the pale blue-white texture. Save the place
or decor collection only after inspecting it in the intended map. Record the
actual asset ID, owner, scale, placement, and Play test in `HANDOFF.md`.

No Roblox upload, Studio import, saved placement, or publication has been
verified for this package yet.
