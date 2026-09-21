-- Authoritative topology: SNOW_FORTRESS_MAP_SPEC.md and the user's drawing.
-- North = -Z, Blue = west (-X), Red = east (+X). GRAYBOX ONLY.
-- Dimensions are blockout hypotheses; topology is locked pending designer review.
local map = {
    Name = "SnowFortress",
    Revision = "enclosed-fortress-v3",
    Size = 500,
    WallHeight = 12,
    Seed = 1129,
    Finale = { EligibleIds = { "gate", "yard", "keep" } },
    Spawns = { Blue = {}, Red = {} },
    Objectives = {
        {
            Id = "gate",
            Name = "A — North Field",
            pos = { 0, 0.2, -128 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
        {
            Id = "yard",
            Name = "B — South Field",
            pos = { 0, 0.2, 128 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
        {
            Id = "keep",
            Name = "C — Fortress Upper Floor",
            pos = { 0, 18.2, 0 },
            radius = 18,
            halfHeight = 7,
            Phases = { 1, 2, 3 },
        },
    },
    Vista = { pos = { -225, 80, -190 }, look = { 0, 8, 0 }, seconds = 3 },
    SafetyAlwaysOn = true,
    RecoveryY = -8,
    Bounds = { min = { -245, -12, -185 }, max = { 245, 85, 185 } },
    InvalidRegions = {},
    SafeRegions = {},
    SafePoints = {
        { name = "Blue exterior", pos = { -200, 1, 0 } },
        { name = "Red exterior", pos = { 200, 1, 0 } },
        { name = "North field", pos = { 0, 1, -128 } },
        { name = "South field", pos = { 0, 1, 128 } },
        { name = "Fortress upper centre", pos = { 0, 19, 0 } },
        { name = "Upper landing southwest", pos = { -60, 19, 46 } },
        { name = "Upper landing northeast", pos = { 60, 19, -46 } },
    },
    Barrier = {
        { pos = { 0, 6, -186.5 }, size = { 490, 12, 1.5 } },
        { pos = { 0, 6, 186.5 }, size = { 490, 12, 1.5 } },
        { pos = { -246.5, 6, 0 }, size = { 1.5, 12, 370 } },
        { pos = { 246.5, 6, 0 }, size = { 1.5, 12, 370 } },
    },
    -- Scenic horizon built the way Carrier, Forest and Swamp build theirs: native
    -- terrain spheres, not meshes. Terrain textures correctly from every angle, has
    -- real LOD, costs no MeshParts, and has no plate edge to hide -- all of which a
    -- top-down terrain scan viewed from the side gets wrong. Each entry is
    -- {x, y, z, radius} and a sphere's top is y + radius, so these peak at +110..130
    -- on a ring 760-790 studs out: clear of the barrier at 246.5, and inside the
    -- ground slab buildTerrain lays out to Size * 4.
    Terrain = {
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(226, 233, 240),
        MountainMaterial = Enum.Material.Glacier,
        MountainColor = Color3.fromRGB(198, 214, 228),
        Mountains = {
            { 0, -150, -760, 280 },
            { -560, -140, -610, 250 },
            { -790, -170, -40, 290 },
            { -540, -130, 600, 240 },
            { 40, -160, 780, 270 },
            { 590, -140, 620, 255 },
            { 780, -175, 30, 295 },
            { 560, -135, -590, 245 },
        },
        -- A nearer, lower row so the horizon reads with depth rather than as one
        -- wall of spheres. Checked against the barrier: the closest of these clears
        -- y = 0 only within 110 studs of its centre, and the nearest centre is 270
        -- studs from the corner of the playable box.
        Hills = {
            { -360, -70, -430, 130 },
            { 420, -60, 380, 120 },
            { -430, -65, 360, 125 },
            { 380, -75, -400, 135 },
        },
    },
    Palette = {
        Floor = Color3.fromRGB(180, 184, 190),
        Wall = Color3.fromRGB(102, 110, 122),
        Cover = Color3.fromRGB(122, 130, 140),
        Upper = Color3.fromRGB(154, 165, 180),
        Ramp = Color3.fromRGB(200, 204, 212),
    },
    Environment = {
        ClockTime = 12,
        Brightness = 2,
        Ambient = Color3.fromRGB(160, 160, 160),
        OutdoorAmbient = Color3.fromRGB(170, 170, 170),
        -- Nothing sits beyond about 1080 studs now, so this only adds depth haze
        -- to the horizon. The arena is under 620 studs corner to corner, so no
        -- fog falls inside it.
        FogStart = 900,
        FogEnd = 3000,
        FogColor = Color3.fromRGB(190, 195, 205),
        Atmosphere = { Density = 0, Haze = 0, Glare = 0, Color = Color3.fromRGB(255, 255, 255) },
        SunRays = 0,
        Bloom = 0,
        Saturation = 0,
        Contrast = 0,
        Tint = Color3.fromRGB(255, 255, 255),
    },
    Center = {},
    Mirrored = {},
    Symmetry = { SniperOutposts = "rotational" },
    GroundRoutes = {},
    SniperOutposts = {
        {
            Id = "northwest",
            Name = "Northwest Outpost",
            pos = { -145, 19, -126 },
            radius = 12,
            GroundRouteId = "blue-north",
        },
        {
            Id = "southeast",
            Name = "Southeast Outpost",
            pos = { 145, 19, 126 },
            radius = 12,
            GroundRouteId = "red-south",
        },
    },
    LaunchPads = {},
    ZipLines = {
        {
            Id = "southwest-upper",
            From = { -150, 4, 130 },
            To = { -55, 38, 50 },
            GroundAlternative = "blue-centre",
            Purpose = "Southwest exterior to roof hatch",
        },
        {
            Id = "northeast-upper",
            From = { 150, 4, -130 },
            To = { 55, 38, -50 },
            GroundAlternative = "red-centre",
            Purpose = "Northeast exterior to roof hatch",
        },
    },
    -- No grapple routes in the new authoritative sketch.
    GrappleAnchors = {},
    ReviewViews = {
        { Name = "01-overhead", Eye = { 0, 470, 0 }, Look = { 0, 0, 0 }, Up = { 0, 0, -1 } },
        { Name = "02-blue-spawn", Eye = { -210, 6, 0 }, Look = { 0, 10, 0 } },
        { Name = "03-red-spawn", Eye = { 210, 6, 0 }, Look = { 0, 10, 0 } },
        { Name = "04-capture-a", Eye = { 0, 6, -143 }, Look = { 0, 8, -35 } },
        { Name = "05-capture-b", Eye = { 0, 6, 143 }, Look = { 0, 8, 35 } },
        { Name = "06-capture-c", Eye = { -16, 24, 16 }, Look = { 18, 22, -18 } },
        { Name = "07-northwest-outpost", Eye = { -145, 24, -126 }, Look = { 0, 20, 0 } },
        { Name = "08-southeast-outpost", Eye = { 145, 24, 126 }, Look = { 0, 20, 0 } },
        { Name = "09-southwest-zip", Eye = { -162, 7, 142 }, Look = { -60, 20, 46 } },
        { Name = "10-northeast-zip", Eye = { 162, 7, -142 }, Look = { 60, 20, -46 } },
        { Name = "11-second-story", Eye = { -61, 24, 43 }, Look = { 60, 19, -43 } },
        { Name = "12-ground-entrances", Eye = { -115, 60, -105 }, Look = { 0, 3, 0 } },
    },
}

local function block(name, pos, size, color, rot)
    table.insert(map.Center, {
        kind = "block",
        name = name,
        pos = pos,
        size = size,
        color = color or "Wall",
        material = "SmoothPlastic",
        rot = rot,
    })
end

-- Ground floor top at 4. Full upper floor at 18 except two stairwell slots.
block("ExteriorFloor", { 0, -0.5, 0 }, { 490, 1, 370 }, "Floor")
block("FortressGround", { 0, 2, 0 }, { 140, 4, 110 }, "Floor")
block("UpperCentre", { 0, 17.5, 0 }, { 66, 1, 110 }, "Upper")
for _, side in { -1, 1 } do
    block("UpperOuter" .. side, { side * 58.5, 17.5, 0 }, { 23, 1, 110 }, "Upper")
    block("UpperBeforeStair" .. side, { side * 40, 17.5, -side * 27 }, { 14, 1, 56 }, "Upper")
    block("UpperAfterStair" .. side, { side * 40, 17.5, side * 46 }, { 14, 1, 18 }, "Upper")
    -- Split low walls around cardinal doors and launch corridors at z +/-30.
    for _, z in { -48, -15, 15, 48 } do
        block("SideWall" .. side .. "_" .. z, { side * 69, 8, z }, { 2, 8, 10 })
    end
    for _, x in { -42, 42 } do
        block("EndWall" .. side .. "_" .. x, { x, 8, side * 54 }, { 54, 8, 2 })
        block("Support" .. side .. "_" .. x, { x, 10.5, side * 46 }, { 3, 13, 3 })
    end
    -- Guard only the stairwell sides and low end; the upper exit stays open.
    for _, edge in { -1, 1 } do
        block("StairRail" .. side .. edge, { side * 40 + edge * 7.5, 20, side * 19 }, { 1, 4, 36 })
    end
    block("StairBackRail" .. side, { side * 40, 20, side * 0.5 }, { 16, 4, 1 })
end

-- Four cardinal ramps: 4-stud rise, 20-degree incline, 24-stud width.
local angle = 20
local run = 4 / math.tan(math.rad(angle))
local length = math.sqrt(run * run + 4 * 4)
block("RampWest", { -70 - run / 2, 1.75, 0 }, { length, 0.5, 24 }, "Ramp", { 0, 0, angle })
block("RampEast", { 70 + run / 2, 1.75, 0 }, { length, 0.5, 24 }, "Ramp", { 0, 0, -angle })
block("RampNorth", { 0, 1.75, -55 - run / 2 }, { length, 0.5, 24 }, "Ramp", { 0, 90, -angle })
block("RampSouth", { 0, 1.75, 55 + run / 2 }, { length, 0.5, 24 }, "Ramp", { 0, 90, angle })

-- Two straightforward stairs connect both upper landings to the ground floor.
-- Each rises through its dedicated floor cutout, never through an overhead slab.
for _, side in { -1, 1 } do
    for step = 1, 14 do
        block(
            "UpperStair" .. side .. "_" .. step,
            { side * 40, 4 + step / 2, side * (1 + step * 2.5) },
            { 10, step, 2.5 },
            "Ramp"
        )
    end
end

for _, team in { "Blue", "Red" } do
    local side = team == "Blue" and -1 or 1
    for index = 1, 6 do
        table.insert(map.Spawns[team], { side * 210, 0, (index - 3.5) * 8 })
    end
    -- Open exterior staging. A detached screen interrupts spawn shooting lanes;
    -- no enclosing bunker or fortified starting structure.
    -- Half-length 33, not 29: opening the outposts' inward window exposes a lane to
    -- the enemy spawn point at z -20, whose rays cross this screen at |z| ~30. The
    -- objective and the spawn sit only ~18 degrees apart from an outpost, so no
    -- aperture at the outpost wall can separate them; the restriction has to be
    -- downrange. 33 still leaves 5 studs clear of the centre route detour at z 38.
    block(team .. "SightlineScreen", { side * 179, 7, 0 }, { 3, 14, 66 })
    for _, direction in { -1, 1 } do
        table.insert(map.LaunchPads, {
            Id = team .. (direction == -1 and "-north-launch" or "-south-launch"),
            pos = { side * 125, 0.3, direction * 30 },
            target = { side * 84, 2, direction * 5 },
            vy = 62,
            size = 8,
            GroundAlternative = team:lower() .. "-centre",
        })
        table.insert(map.GroundRoutes, {
            Id = team:lower() .. (direction == -1 and "-north" or "-south"),
            DistrictId = direction == -1 and "gate" or "yard",
            Side = team,
            Kind = "covered",
            From = { side * 210, 1, direction * 24 },
            To = { 0, 1, direction * 128 },
            Waypoints = {
                { side * 210, 1, direction * 24 },
                { side * 180, 1, direction * 48 },
                { side * 95, 1, direction * 95 },
                { 0, 1, direction * 128 },
            },
        })
        block("ApproachCover" .. team .. direction, { side * 130, 3, direction * 70 }, { 16, 6, 8 }, "Cover")
    end
    table.insert(map.GroundRoutes, {
        Id = team:lower() .. "-centre",
        DistrictId = "keep",
        Side = team,
        Kind = "direct",
        From = { side * 210, 1, 0 },
        To = { 0, 5, 0 },
        Waypoints = {
            { side * 210, 1, 0 },
            { side * 190, 1, 38 },
            { side * 160, 1, 38 },
            { side * 95, 1, 0 },
            { side * 70, 5, 0 },
            { 0, 5, 0 },
        },
    })
end

for _, direction in { -1, 1 } do
    table.insert(map.GroundRoutes, {
        Id = direction == -1 and "north-ramp" or "south-ramp",
        DistrictId = "keep",
        Side = "Both",
        Kind = "direct",
        From = { 0, 1, direction * 128 },
        To = { 0, 5, 0 },
        Waypoints = { { 0, 1, direction * 128 }, { 0, 1, direction * 72 }, { 0, 5, direction * 54 }, { 0, 5, 0 } },
    })
    -- Sketch's NE/SW walls stand beside, not across, the diagonal zip routes.
    block("ZipSightlineWall" .. direction, { direction * 115, 7, -direction * 141 }, { 3, 14, 36 })
end

for _, post in map.SniperOutposts do
    local x, z = post.pos[1], post.pos[3]
    block(post.Id .. "LowerFloor", { x, 0.5, z }, { 28, 1, 26 }, "Floor")
    block(post.Id .. "Deck", { x, 17.5, z }, { 28, 1, 26 }, "Upper")
    block(post.Id .. "Roof", { x, 29.5, z }, { 30, 1, 28 })
    -- Geometry is load-bearing here: check_fortress_layout's head-clearance test
    -- passes with exactly zero margin at a 1-stud rise on a 2.5-stud run, so both
    -- steepening and lengthening the treads trip it. The stair that used to run at
    -- the Blue spawn is removed outright below, which is the real fix.
    -- The map interior is +Z from the northwest post at z -126 and -Z from the
    -- southeast one, so the sign of the post's own z picks the face worth glazing
    -- and rotational symmetry falls out of it.
    local inward = z < 0 and 1 or -1
    for _, direction in { -1, 1 } do
        for step = 1, 18 do
            block(
                post.Id .. "Stair" .. direction .. "_" .. step,
                { x + direction * (59 - step * 2.5), step / 2, z },
                { 2.5, step, 10 },
                "Ramp"
            )
        end
        -- Lower-level shelter; two open side doors beneath the firing deck.
        block(post.Id .. "LowerWall" .. direction, { x, 8.5, z + direction * 12 }, { 28, 15, 2 })
        -- Only the inward Z face earns a window: sill top 21.5, header bottom 25.5,
        -- roof at 29. The outward face looks at the dead strip between the outpost
        -- and the boundary, so it is a solid backstop. Building both a slit and a
        -- full-height wall on the same face, as the old SpawnShield did, left two
        -- solids coplanar at the same z and the same 2-stud thickness.
        if direction == inward then
            block(post.Id .. "Sill" .. direction, { x, 19.75, z + direction * 12 }, { 28, 3.5, 2 }, "Cover")
            block(post.Id .. "Header" .. direction, { x, 27.25, z + direction * 12 }, { 28, 3.5, 2 })
            block(post.Id .. "WindowDivider" .. direction, { x, 23.5, z + direction * 12 }, { 4, 4, 2 })
        else
            block(post.Id .. "UpperBackstop", { x, 23.5, z + direction * 12 }, { 28, 11, 2 })
        end
        for _, corner in { -1, 1 } do
            block(post.Id .. "Corner" .. direction .. corner, { x + direction * 13, 15, z + corner * 10 }, { 2, 28, 6 })
        end
    end
end

-- Ordinary approaches to C continue up an existing stair, then onto its floor.
for _, route in map.GroundRoutes do
    if route.DistrictId == "keep" then
        local side = route.Side == "Blue" and -1 or 1
        table.insert(route.Waypoints, { side * 40, 5, 0 })
        table.insert(route.Waypoints, { side * 40, 19, side * 40 })
        table.insert(route.Waypoints, { 0, 19, side * 40 })
        table.insert(route.Waypoints, { 0, 19, 0 })
        route.To = { 0, 19, 0 }
    end
end

-- Enclosed shell: ground access is exclusively through the four ramp doors.
for _, side in { -1, 1 } do
    for _, wing in { -1, 1 } do
        block("GroundClosure" .. side .. wing, { side * 69, 10.5, wing * 31.5 }, { 2, 13, 23 }, "Wall")
    end
    block("UpperWallX" .. side, { side * 69, 25, 0 }, { 2, 14, 110 }, "Wall")
    block("UpperWallZ" .. side, { 0, 25, side * 54 }, { 140, 14, 2 }, "Wall")
end
-- Roof top 33. Two 10x10 hatches provide drops into the second storey.
map.RoofHatches = { { -55, 33, 40 }, { 55, 33, -40 } }
for x = -65, 65, 10 do
    for z = -50, 50, 10 do
        if not ((x == -55 and z == 40) or (x == 55 and z == -40)) then
            block("FortressRoof" .. x .. "_" .. z, { x, 32.5, z }, { 10, 1, 10 }, "Upper")
        end
    end
end
for _, hatch in map.RoofHatches do
    for _, edge in { -1, 1 } do
        block("HatchRim" .. hatch[1] .. edge, { hatch[1] + edge * 5.25, 33.2, hatch[3] }, { 0.5, 0.4, 10 }, "ArtAmber")
    end
end
-- Each outpost has one exterior staircase and one upper doorway, with firing windows.
-- The stair faces its own team's spawn, so the approach from spawn climbs straight
-- into the firing room: the northwest outpost sits on Blue's side at x -145, so its
-- stair and door are on the -X face. `entry` is that face, and the opposite stair is
-- the one removed.
for _, post in map.SniperOutposts do
    local x, z = post.pos[1], post.pos[3]
    local entry = x < 0 and -1 or 1
    for i = #map.Center, 1, -1 do
        local prefix = post.Id .. "Stair" .. -entry .. "_"
        if map.Center[i].name:sub(1, #prefix) == prefix then
            table.remove(map.Center, i)
        end
    end
    for _, side in { -1, 1 } do
        block(post.Id .. "LowerEnd" .. side, { x + side * 13, 9, z }, { 2, 16, 26 })
    end
    -- The face opposite the door looks over the map, so it is a firing window, not
    -- a wall: same sill/header split as the Z faces, leaving a slit at y 21.5..25.5.
    local watch = x - entry * 13
    block(post.Id .. "WatchSill", { watch, 19.75, z }, { 2, 3.5, 26 }, "Cover")
    block(post.Id .. "WatchHeader", { watch, 27.25, z }, { 2, 3.5, 26 })
    block(post.Id .. "WatchDivider", { watch, 23.5, z }, { 2, 4, 4 })
    for _, side in { -1, 1 } do
        block(post.Id .. "DoorJamb" .. side, { x + entry * 13, 23.5, z + side * 9 }, { 2, 11, 8 })
    end
    block(post.Id .. "DoorHeader", { x + entry * 13, 27.5, z }, { 2, 4, 10 })
end

local AlpineFortress = require(script.Parent.Parent.MapArt.AlpineFortress)
AlpineFortress.applyMap(map)

return map
