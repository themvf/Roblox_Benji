-- Scenic glacier horizon. Backdrop only: it is never playable, never collidable and
-- never standable, so it changes no route, sightline or capture volume.
--
-- The mesh is the decimated GlacialIceflats scan (tools/blender/process_assets.py),
-- 2400 x 286 x 2400 studs with a centred pivot, uploaded as asset 134061547604589
-- and loaded by id at build time. Dropping a model named GlacierScenery into
-- ReplicatedStorage.Uploads overrides the id, so the look can be retuned in Studio
-- without a code change. If neither resolves the map builds as it does today.
local Art = {}

-- Four rings placed just outside the playable box. Snow Fortress bounds are
-- x +/-245 and z +/-185, so a 2400-stud tile centred 1500 out on x (1400 on z)
-- keeps its nearest edge at 300 (200 on z) -- clear of the barrier with margin.
-- Sunk to y = -60 the ridge line tops out at +83, just under the 85 ceiling.
local RING = {
    { name = "West", pos = { -1500, -60, 0 }, rot = { 0, 0, 0 } },
    { name = "East", pos = { 1500, -60, 0 }, rot = { 0, 180, 0 } },
    { name = "North", pos = { 0, -60, -1400 }, rot = { 0, 90, 0 } },
    { name = "South", pos = { 0, -60, 1400 }, rot = { 0, 270, 0 } },
}

function Art.applyMap(map)
    for _, ring in RING do
        table.insert(map.Center, {
            kind = "scenery",
            name = "GlacierBackdrop" .. ring.name,
            model = "GlacierScenery",
            assetId = 134061547604589,
            pos = ring.pos,
            rot = ring.rot,
            decor = true,
        })
    end
    -- A distant ice horizon only reads if the fog stops hiding it. The map's own
    -- FogEnd of 3000 already clears the farthest ridge at ~2700 studs.
    return map
end

return Art
