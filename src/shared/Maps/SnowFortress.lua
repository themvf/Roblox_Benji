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
    -- The horizon is a skybox (tools/blender/make_sky_range.py), not geometry:
    -- FillBall domes read as bald mounds and a terrain scan smears when seen from
    -- the side. Terrain here is only the snowfield the arena sits on.
    Terrain = {
        GroundMaterial = Enum.Material.Snow,
        GroundColor = Color3.fromRGB(226, 233, 240),
    },
    Palette = {
        Floor = Color3.fromRGB(180, 184, 190),
        Wall = Color3.fromRGB(102, 110, 122),
        Cover = Color3.fromRGB(122, 130, 140),
        Upper = Color3.fromRGB(154, 165, 180),
        Ramp = Color3.fromRGB(200, 204, 212),
        -- The roof is its own surface, not more of the interior. It was `Upper`, the
        -- same near-white as the floor below, which left a white wreck on a white deck
        -- under a white sky with nothing to separate them. Darker and slightly bluer
        -- so it reads as built structure against snow, and so red and blue players on
        -- it have something to contrast against.
        Deck = Color3.fromRGB(116, 124, 136),
        -- Helipad. The deck is dark enough to anchor the wreck; the markings are the
        -- only warm value on the map, which is what makes them read as paint.
        PadDeck = Color3.fromRGB(74, 80, 88),
        PadMark = Color3.fromRGB(214, 196, 110),
        -- Burn under the wreck, over the pad. The point is contrast, not colour.
        Scorch = Color3.fromRGB(58, 56, 58),
    },
    Environment = {
        -- "Snowy Sky Box" by @DonTheBears, Creator Store asset 2029216718, found under
        -- Visual Effects / Sky and Atmosphere -- the category that holds real Sky
        -- objects rather than skyboxes faked out of parts. Six distinct face images,
        -- which is what a continuous range needs; a skybox repeating one image on all
        -- four sides cannot be one. Two generated ranges were tried first and neither
        -- was good enough; see docs/design/ASSET_INTAKE_AND_LESSONS.md.
        Sky = {
            Ft = "rbxassetid://2029211409",
            Bk = "rbxassetid://2029210131",
            Lf = "rbxassetid://2029212393",
            Rt = "rbxassetid://2029212849",
            Up = "rbxassetid://2029213271",
            Dn = "rbxassetid://2029210773",
            CelestialBodiesShown = true,
        },
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
            block("FortressRoof" .. x .. "_" .. z, { x, 32.5, z }, { 10, 1, 10 }, "Deck")
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

-- Ice spike scatter. Jagged Ice Rock 139945743433812, authored 41.4 x 29.8 x 50.0
-- studs. The other model this was once compared against, ICE ROCK 72083045344532,
-- does not load -- InsertService returned nothing and three rocks went quietly missing
-- from the map -- so only ids that have been seen to load are placed here.
--
-- `fit` and `sit`, never `scale` and a y. The first pass multiplied a size nobody had
-- measured: scale 1.4 meant a seventy-stud boulder. `fit` names the studs it should end
-- up and lets MapService derive the multiplier from the model that actually loaded;
-- `sit` puts the lowest visible point on the ground rather than the bounding-box
-- centre, which is what buried them and made them read as upside down.
--
-- Each seed is placed twice, rotated 180 degrees about the map centre. That is not
-- decoration for its own sake: this map is rotationally symmetric, and while a prop
-- cannot be stood on or shot through, it DOES hide a player from view. An unpaired one
-- hands that side a sightline break the other side has not got.
--
-- The yaw is offset on the twin so a pair does not read as a copy of itself.
--
-- Positions are checked against the gameplay geometry, not placed by eye. Across all
-- sixteen the tightest clearances are 49 studs from a zip line, 85 from a launch arc,
-- 30 from an objective circle, 44 from a safe point and 35 from an outpost, and none
-- falls inside the fortress footprint. Sizes run 12 to 45 studs so the field reads as
-- a range rather than a row of identical lumps.
local ICE_SPIKE = 139945743433812
for _, seed in
    {
        { x = 205, z = 165, fit = 45, yaw = 20 },
        { x = -205, z = 172, fit = 40, yaw = 145 },
        { x = 208, z = 92, fit = 38, yaw = 250 },
        { x = 60, z = 168, fit = 30, yaw = 60 },
        { x = -212, z = 118, fit = 28, yaw = 200 },
        { x = 228, z = -48, fit = 24, yaw = 320 },
        { x = 120, z = 176, fit = 18, yaw = 95 },
        { x = 24, z = 176, fit = 12, yaw = 170 },
        -- Hand-placed with /mark, then checked the same way as the rest. Both clear
        -- their nearest launch arc by 22 and 15 studs, which is clearance rather than
        -- contact. A third mark at 106,-78 was dropped: it stood one stud off the
        -- northeast zip cable.
        { x = 155, z = -40, fit = 20, yaw = 35 },
        { x = 144, z = 46, fit = 20, yaw = 285 },
    }
do
    for _, turn in { 0, 180 } do
        local flip = turn == 0 and 1 or -1
        table.insert(map.Center, {
            kind = "prop",
            name = ("IceSpike%d_%d"):format(seed.x * flip, seed.z * flip),
            assetId = ICE_SPIKE,
            pos = { seed.x * flip, 0, seed.z * flip },
            rot = { 0, seed.yaw + turn, 0 },
            fit = seed.fit,
            sit = true,
            decor = true,
        })
    end
end

-- Crashed helicopter on the fortress roof, directly above objective C. Generated from
-- a reference image by TRELLIS.2, built by scene_kit (tools/blender/scenes.json) and
-- uploaded as Model 106313001013090.
--
-- `sit` puts its lowest point on the roof at y 33, so the height no longer has to be
-- hand-corrected for the fact that a Model's pivot is its bounding-box CENTRE.
--
-- The texture is tinted to charcoal in the pipeline rather than here: a white wreck on
-- a white roof was invisible from more than a few studs away, and MeshPart colour does
-- not tint an applied texture. The burn patch below does the other half of the job.
--
-- Roof centre is the only symmetry-neutral spot: this map is rotationally symmetric,
-- so anything off-centre favours one side, and check_maps cannot catch it because
-- decor is not a gameplay list. It will look slightly off-centre anyway -- the pivot
-- centres the bounding box, which includes the debris scattered around the airframe.
--
-- `collide` makes this the one prop on the map that is real geometry. Players walk
-- around the hull and stand on it instead of through it, and it stops bullets as well
-- as bodies -- a prop that blocks one and not the other is worse than no cover at all.
--
-- The mesh carries its own collision rather than a hand-authored block beside it. A box
-- would have had to guess the airframe's facing, which nothing outside Studio can tell
-- us. The shape is approximate -- CollisionFidelity is plugin-security, so nothing at
-- runtime can ask for a precise decomposition, and Open Cloud gives no say over import
-- settings either -- so expect roughly the hull: solid to stand on and walk around,
-- and probably filling in the cabin.
--
-- The cost is real: no layout gate can audit a bought mesh, so this geometry is in the
-- fight without check_maps or check_fortress_layout seeing it. It is allowed here
-- because the roof is a flat open deck where the wreck is the only feature, and because
-- it sits about 38 studs clear of both zip line landings and both roof hatches.
-- Helipad, centred on the roof, with the wreck sitting on it. Every slab is 0.1 thick
-- and flush with the roof top at y 33, so the whole pad is a colour change rather than
-- a step -- a player crosses it without feeling anything, and the 0.25 stud of stacking
-- between deck, paint and burn is below what a character notices.
--
-- The three layers sit at 33.05, 33.12 and 33.2 so no two faces are ever coplanar.
-- Equal heights would z-fight, which reads as flickering paint from across the map.
-- Nothing overlaps within a layer either: the border bars stop short of each other and
-- the H's crossbar stops at its uprights rather than running through them.
--
-- 40 x 40 at the centre clears both roof hatches (x +/-55) and both zip line landings
-- by about 38 studs, and centred is the only placement a rotationally symmetric map
-- can take without favouring a side.
block("HelipadDeck", { 0, 33.05, 0 }, { 40, 0.1, 40 }, "PadDeck")
for _, edge in { -1, 1 } do
    block("HelipadEdgeZ" .. edge, { 0, 33.12, edge * 18 }, { 36, 0.1, 1.5 }, "PadMark")
    block("HelipadEdgeX" .. edge, { edge * 17.25, 33.12, 0 }, { 1.5, 0.1, 33 }, "PadMark")
    block("HelipadH" .. edge, { edge * 4, 33.12, 0 }, { 2, 0.1, 12 }, "PadMark")
end
block("HelipadHBar", { 0, 33.12, 0 }, { 6, 0.1, 2 }, "PadMark")
-- Burn over the paint, where the airframe came down. Wide enough to sit under it
-- wherever the importer lands the model, since its mass is offset from its
-- bounding-box centre by about 6 studs in a direction this file cannot know.
block("HelipadScorch", { 0, 33.2, 0 }, { 24, 0.1, 18 }, "Scorch")

table.insert(map.Center, {
    kind = "prop",
    name = "RoofHelicopter",
    assetId = 130015473244475,
    pos = { 0, 33, 0 },
    rot = { 0, 0, 0 },
    fit = 34,
    sit = true,
    collide = true,
    decor = true,
})

local AlpineFortress = require(script.Parent.Parent.MapArt.AlpineFortress)
AlpineFortress.applyMap(map)

return map
