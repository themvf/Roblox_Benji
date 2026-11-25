# Studio verification for separate props

After visual approval, import only the needed GLBs from `exports/` with Scale Unit **Stud** under the game asset owner. Reuse an existing upload of the same approved export hash where possible.

For each imported prop, verify the actual appearance, size, texture or material loading, and ground pivot against its own `review/` images. Record the owner and asset IDs in `HANDOFF.md`. The table imports as five MeshParts, the lamp rig as five, the monitor as six, and the IV stand as four in the current candidate. These counts may change only after another reviewed export.

Each prop can be placed by itself. To rebuild the reference arrangement, use `source/assembly-layout.json` as local Roblox XYZ offsets from a chosen set origin. Keep each prop's ground pivot at the recorded offset and orient all four the same way. Adjust their placements in Studio as needed; this arrangement has not been verified in a live map.

Choose decoration or interaction per prop. For decoration, anchor the imported MeshParts and configure collisions, touch and query for the map location. For interaction, add explicit Roblox scripts, collision geometry, Seat or other gameplay components as needed. The GLBs alone do not provide those behaviors. The lamp lenses are visual only; add and test Roblox lights separately if illumination is desired.

Save approved placements in the intended map's decor or prop collection, preserving existing objects. Restart the map and record appearance and persistence evidence in `HANDOFF.md`.
