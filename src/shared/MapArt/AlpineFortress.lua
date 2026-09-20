-- Reusable visual treatment. Never alters gameplay positions, dimensions or routes.
local Art = {}

function Art.applyEntrance(map)
    map.Palette.ArtSlate = Color3.fromRGB(64, 76, 91)
    map.Palette.ArtSteel = Color3.fromRGB(111, 123, 136)
    map.Palette.ArtSnow = Color3.fromRGB(232, 239, 246)
    map.Palette.ArtAmber = Color3.fromRGB(255, 216, 150)
    map.Palette.ArtFloor = Color3.fromRGB(172, 179, 186)
    map.Palette.ArtFoundation = Color3.fromRGB(47, 57, 70)

    local additions = {}
    local function trim(name, pos, size, color, material)
        table.insert(additions, {
            kind = "block",
            name = "ArtWest" .. name,
            pos = pos,
            size = size,
            color = color,
            material = material,
            decor = true,
        })
    end
    for _, piece in map.Center do
        if piece.name:match("^SideWall%-1_") then
            piece.color = "ArtSlate"
            piece.material = "Slate"
            local z = piece.pos[3]
            -- Face strips sit on the existing solid, never across an opening.
            for _, y in { 6, 10 } do
                trim("Course" .. z .. "_" .. y, { -70.02, y, z }, { 0.04, 0.1, 10 }, "ArtSteel", "Metal")
            end
            trim("SnowCap" .. z, { -69, 12.08, z }, { 2, 0.16, 10 }, "ArtSnow", "Snow")
        elseif piece.name == "RampWest" or piece.name == "UpperOuter-1" then
            piece.color = "ArtFloor"
            piece.material = "Concrete"
        end
    end
    -- Door jambs occupy the solid wall edges at z +/-10..12. They do not
    -- narrow the central 20-stud opening or change either launch corridor.
    for _, side in { -1, 1 } do
        trim("Jamb" .. side, { -70.04, 8, side * 11 }, { 0.08, 8, 2 }, "ArtSteel", "Metal")
        trim("LampBacking" .. side, { -70.1, 9, side * 14 }, { 0.1, 2.8, 1 }, "ArtSteel", "Metal")
        trim("Lamp" .. side, { -70.17, 9, side * 14 }, { 0.04, 2.2, 0.5 }, "ArtAmber", "Neon")
    end
    trim("InteriorLamp", { -59, 16.94, 0 }, { 3, 0.08, 1 }, "ArtAmber", "Neon")
    for index, position in { { -72, 10, 0 }, { -59, 14, 0 } } do
        table.insert(additions, {
            kind = "light",
            name = "ArtWestLight" .. index,
            pos = position,
            color = "ArtAmber",
            range = 24,
            brightness = 1.2,
        })
    end
    for _, piece in additions do
        table.insert(map.Center, piece)
    end
end

function Art.applyMap(map)
    Art.applyEntrance(map)
    local additions = {}
    local function detail(name, pos, size, color, material)
        table.insert(additions, {
            kind = "block",
            name = "ArtFull" .. name,
            pos = pos,
            size = size,
            color = color,
            material = material,
            decor = true,
        })
    end
    local function light(name, position, range, brightness)
        table.insert(additions, {
            kind = "light",
            name = "ArtFull" .. name,
            pos = position,
            color = "ArtAmber",
            range = range,
            brightness = brightness,
        })
    end
    -- Copy the approved entrance details to the opposite approach.
    for _, piece in map.Center do
        if piece.name:match("^ArtWest") then
            local copy = table.clone(piece)
            copy.name = piece.name:gsub("^ArtWest", "ArtEast")
            copy.pos = { -piece.pos[1], piece.pos[2], piece.pos[3] }
            table.insert(additions, copy)
        end
    end
    for _, piece in map.Center do
        if piece.kind ~= "block" or piece.decor then
            continue
        end
        local name, pos, size = piece.name, piece.pos, piece.size
        local outpost = name:match("^northwest") or name:match("^southeast")
        -- Broad structural accents read at combat distance. All skins remain
        -- attached to existing solids, with no collision or raycast footprint.
        if name:find("EndWall") or name:find("LowerWall") then
            for _, side in { -1, 1 } do
                detail(
                    name .. "Plinth" .. side,
                    { pos[1], pos[2] - size[2] / 2 + 0.7, pos[3] + side * (size[3] / 2 + 0.04) },
                    { size[1], 1.4, 0.08 },
                    "ArtFoundation",
                    "Concrete"
                )
            end
        end
        if name:match("^UpperStair") or (outpost and name:find("Stair")) then
            -- Inset high-contrast tread markings leave the step silhouette intact.
            detail(
                name .. "Tread",
                { pos[1], pos[2] + size[2] / 2 + 0.015, pos[3] },
                { outpost and 0.3 or size[1] - 1, 0.03, outpost and size[3] - 1 or 0.3 },
                "ArtAmber",
                "Metal"
            )
        end
        if name == "ExteriorFloor" then
            piece.color, piece.material = "ArtSnow", "Snow"
        elseif
            name:find("Stair")
            or name:find("Ramp")
            or name:find("Floor")
            or name:find("Deck")
            or name:match("^Upper")
            or name == "FortressGround"
        then
            piece.color, piece.material = "ArtFloor", "Concrete"
        elseif
            name:find("Rail")
            or name:find("Header")
            or name:find("Divider")
            or name:find("Support")
            or name:find("Corner")
        then
            piece.color, piece.material = "ArtSteel", "Metal"
        else
            piece.color, piece.material = "ArtSlate", "Slate"
        end
        if name:find("Rail") then
            piece.color, piece.material = "ArtSteel", "Metal"
        end
        -- Snow lies only on existing roof/wall/cover tops, never in doorways,
        -- on stairs, across upper-floor paths, or in a firing slit.
        if
            name:find("Roof")
            or name:find("Sightline")
            or name:find("ApproachCover")
            or name:find("EndWall")
            or name:match("^SideWall1_")
        then
            detail(
                name .. "Snow",
                { pos[1], pos[2] + size[2] / 2 + 0.08, pos[3] },
                { size[1], 0.16, size[3] },
                "ArtSnow",
                "Snow"
            )
        end
        -- Large horizontal stone courses on solid end walls and outpost shelter.
        if name:find("EndWall") or (outpost and name:find("LowerWall")) then
            for _, direction in { -1, 1 } do
                for _, offset in { -2, 2 } do
                    detail(
                        name .. "Course" .. direction .. offset,
                        { pos[1], pos[2] + offset, pos[3] + direction * (size[3] / 2 + 0.02) },
                        { size[1], 0.1, 0.04 },
                        "ArtSteel",
                        "Metal"
                    )
                end
            end
        end
        if name:find("ApproachCover") then
            detail(
                name .. "Band",
                { pos[1], pos[2] + size[2] / 2 - 0.35, pos[3] - size[3] / 2 - 0.02 },
                { size[1], 0.18, 0.04 },
                "ArtAmber",
                "Metal"
            )
        end
    end
    -- North/south access uses the same steel/amber vocabulary on existing walls.
    -- Continuous slab-edge fascia makes the full upper floor legible from outside.
    for _, side in { -1, 1 } do
        detail("DeckEdgeX" .. side, { side * 70.04, 17.5, 0 }, { 0.08, 0.9, 110 }, "ArtSteel", "Metal")
        detail("DeckEdgeZ" .. side, { 0, 17.5, side * 55.04 }, { 140, 0.9, 0.08 }, "ArtSteel", "Metal")
    end
    for _, side in { -1, 1 } do
        for _, x in { -16, 16 } do
            detail("EndJamb" .. side .. x, { x, 8, side * 55.04 }, { 2, 8, 0.08 }, "ArtSteel", "Metal")
            detail("EndLamp" .. side .. x, { x, 9, side * 55.1 }, { 0.5, 2.2, 0.04 }, "ArtAmber", "Neon")
        end
        light("EndEntryLight" .. side, { 0, 12, side * 51 }, 26, 1.2)
    end
    for _, post in map.SniperOutposts do
        local x, z = post.pos[1], post.pos[3]
        for _, side in { -1, 1 } do
            detail(post.Id .. "Lamp" .. side, { x + side * 14.04, 23, z + 8 }, { 0.04, 2, 0.6 }, "ArtAmber", "Neon")
        end
        light(post.Id .. "ShelterLight", { x, 14, z }, 20, 0.8)
        light(post.Id .. "UpperLight", { x, 27, z }, 18, 0.6)
    end
    for _, piece in additions do
        table.insert(map.Center, piece)
    end
    map.Terrain.GroundMaterial = Enum.Material.Snow
    map.Terrain.GroundColor = map.Palette.ArtSnow
    -- Clear daylight, restrained atmosphere, no bloom washing out team colors.
    map.Environment.ClockTime = 13.2
    map.Environment.Ambient = Color3.fromRGB(150, 161, 178)
    map.Environment.OutdoorAmbient = Color3.fromRGB(174, 188, 207)
    map.Environment.Atmosphere = { Density = 0.12, Haze = 0.4, Glare = 0, Color = Color3.fromRGB(219, 231, 245) }
    map.Environment.Bloom = 0
end

return Art
