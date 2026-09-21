-- Scenic glacier horizon. Backdrop only: it is never playable, never collidable and
-- never standable, so it changes no route, sightline or capture volume.
--
-- The mesh is the decimated GlacialIceflats scan (tools/blender/scene_kit.py),
-- exaggerated 4x vertically so its relief ratio is 0.476 rather than the source's
-- 0.119: below about 0.2 a heightfield reads as a flat plate, not as mountains.
-- 2400 x 1146 x 2400 studs with a centred pivot, uploaded and loaded by asset id.
-- Dropping a model named GlacierScenery into ReplicatedStorage.Uploads overrides
-- the id, so the look can be retuned in Studio without a code change.
--
-- Placement rule learned the hard way: this is a finite heightfield, so every edge
-- of the plate is a cliff, and no rotation hides that (measured edge heights run
-- 38-53% of relief on average and up to 100%). Putting a plate near the arena
-- therefore always shows a wall. Instead the ring sits far out and a flat snow
-- plain fills the foreground, so the plates read as mountains rising from a
-- snowfield and their low ground is simply hidden beneath it.

local Art = {}

-- Eight plates on a ring, not four. Four leaves a gap at each diagonal that is
-- plainly visible from inside the arena; at 45-degree spacing the 2400-stud plates
-- overlap (adjacent centres are 1684 apart) and the horizon closes.
-- Radius 2200 puts the nearest backdrop geometry about 755 studs from the arena
-- edge with peaks near 20 degrees of elevation: present, not looming.
local RING_RADIUS = 2200
local RING_Y = 300 -- plate spans -273..873, so roughly three quarters clears the plain
local RING_COUNT = 8
local PLAIN = 9000 -- flat snowfield; the plates' low ground hides beneath it

function Art.applyMap(map)
    -- The snowfield goes down first so the plates rise out of it. It sits just
    -- below the arena floor, is never collidable in practice because the barrier
    -- keeps players inside, and is marked decor so the art pass leaves it alone.
    table.insert(map.Center, {
        kind = "block",
        name = "BackdropPlain",
        pos = { 0, -2.5, 0 },
        size = { PLAIN, 3, PLAIN },
        color = "Floor",
        material = "Snow",
        decor = true,
    })
    for index = 0, RING_COUNT - 1 do
        local degrees = index * (360 / RING_COUNT)
        local radians = math.rad(degrees)
        -- Yaw tracks the bearing so each plate presents a different face inward;
        -- the source is one square heightfield, and eight unrotated copies of it
        -- would read as an obvious repeat.
        table.insert(map.Center, {
            kind = "scenery",
            name = ("GlacierBackdrop%03d"):format(degrees),
            model = "GlacierScenery",
            assetId = 115957483177465,
            pos = { math.cos(radians) * RING_RADIUS, RING_Y, math.sin(radians) * RING_RADIUS },
            rot = { 0, degrees, 0 },
            decor = true,
        })
    end
    -- Fog has to clear the farthest ridge at RING_DISTANCE + 1200, or the backdrop
    -- is paid for and then hidden. The arena is under 600 studs across, so pushing
    -- FogStart out this far changes nothing inside it.
    map.Environment.FogStart = 3000
    map.Environment.FogEnd = 12000
    return map
end

return Art
