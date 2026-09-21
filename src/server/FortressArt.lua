-- Modular Blender facade. Original floors, stairs and traversal routes stay authoritative.
local ServerStorage = game:GetService("ServerStorage")
local Art = {}

function Art.Build(parent)
    local assets = ServerStorage:FindFirstChild("EnvironmentArt")
    local kit = assets and assets:FindFirstChild("SnowFortress")
    for _, name in { "Portal", "WallBay", "Pier", "Parapet", "Floor" } do
        assert(kit and kit:FindFirstChild(name), "Missing SnowFortress art template: " .. name)
    end
    local folder = Instance.new("Folder")
    folder.Name = "BlenderEntrances"
    local function mesh(kind, name, cf, size)
        local p = kit[kind]:Clone()
        p.Name, p.CFrame = name, cf
        if size then
            p.Size = size
        end
        p.Parent = folder
        return p
    end
    local function solid(name, cf, size)
        local p = Instance.new("Part")
        p.Name, p.CFrame, p.Size = name, cf, size
        p.Anchored, p.CanCollide, p.CanQuery = true, true, true
        p.CanTouch, p.CastShadow, p.Transparency = false, false, 1
        p.Parent = folder
        return p
    end
    local function portal(name, frame, widthScale)
        mesh(
            "Portal",
            name,
            frame * CFrame.new(0, 9.5138435, -0.0875),
            Vector3.new(29.2 * widthScale, 19.027687, 5.525)
        )
        for index, box in
            {
                { -12, 7, -0.65, 4, 14, 3.3 },
                { 12, 7, -0.65, 4, 14, 3.3 },
                { 0, 14, -0.65, 28, 2, 3.3 },
                { 0, 15.3, 0.2, 29, 0.6, 5.3 },
                { 0, 16.9, -0.55, 28, 2.6, 3.4 },
                { 0, 18.4, -0.55, 29, 0.4, 4.1 },
            }
        do
            solid(
                name .. "Collision" .. index,
                frame * CFrame.new(box[1] * widthScale, box[2], box[3]),
                Vector3.new(box[4] * widthScale, box[5], box[6])
            )
        end
    end
    local function bay(name, frame)
        -- Full-height wall bays visually support the deck instead of isolated low blocks.
        mesh("WallBay", name, frame * CFrame.new(0, 6.5, 0), Vector3.new(10, 13, 2.2))
        solid(name .. "Body", frame * CFrame.new(0, 6.5, 0), Vector3.new(10, 13, 2))
        mesh("Parapet", name .. "Parapet", frame * CFrame.new(0, 15.8250255, -0.5))
        solid(name .. "ParapetBody", frame * CFrame.new(0, 15.45, -0.5), Vector3.new(10, 2.9, 2.8))
    end
    for _, side in { -1, 1 } do
        local rotation = CFrame.Angles(0, side * math.pi / 2, 0)
        portal(if side == -1 then "WestPortal" else "EastPortal", CFrame.new(side * 69, 4, 0) * rotation, 1)
        for _, z in { -48, -38, -28, -18, 18, 28, 38, 48 } do
            bay("SideBay" .. side .. "_" .. z, CFrame.new(side * 69, 4, z) * rotation)
        end
        local endRotation = CFrame.Angles(0, if side == -1 then math.pi else 0, 0)
        -- North/south doors retain their wider 30-stud opening.
        portal(if side == -1 then "NorthPortal" else "SouthPortal", CFrame.new(0, 4, side * 54) * endRotation, 1.5)
        for _, wing in { -1, 1 } do
            for _, x in { 20, 30, 40, 50, 60 } do
                bay("EndBay" .. side .. "_" .. wing .. "_" .. x, CFrame.new(wing * x, 4, side * 54) * endRotation)
            end
            local frame = CFrame.new(wing * 68, 4, side * 52)
            mesh("Pier", "CornerPier" .. side .. "_" .. wing, frame * CFrame.new(0, 10.5226595, -0.35))
            solid("CornerPierBody" .. side .. "_" .. wing, frame * CFrame.new(0, 10, -0.5), Vector3.new(5, 20, 4.4))
        end
    end
    -- Upper-storey cladding and roof paving follow the enclosed gameplay shell.
    for _, side in { -1, 1 } do
        for z = -50, 50, 10 do
            mesh(
                "WallBay",
                "UpperCladdingX" .. side .. z,
                CFrame.new(side * 69, 25, z) * CFrame.Angles(0, side * math.pi / 2, 0),
                Vector3.new(10, 14, 2.2)
            )
        end
        for x = -65, 65, 10 do
            mesh(
                "WallBay",
                "UpperCladdingZ" .. side .. x,
                CFrame.new(x, 25, side * 54) * CFrame.Angles(0, side == -1 and math.pi or 0, 0),
                Vector3.new(10, 14, 2.2)
            )
        end
    end
    for x = -65, 65, 10 do
        for z = -50, 50, 10 do
            if not ((x == -55 and z == 40) or (x == 55 and z == -40)) then
                mesh("Floor", "RoofPaving" .. x .. "_" .. z, CFrame.new(x, 32.52, z))
            end
        end
    end
    -- Interior lighting keeps the newly enclosed combat spaces readable.
    for _, y in { 15, 29 } do
        for _, x in { -45, 0, 45 } do
            for _, z in { -30, 30 } do
                local lamp = solid("CeilingLamp", CFrame.new(x, y, z), Vector3.new(3, 0.2, 1))
                lamp.CanCollide, lamp.CanQuery, lamp.Transparency = false, false, 0
                lamp.Material = Enum.Material.Neon
                lamp.Color = Color3.fromRGB(255, 220, 170)
                local light = Instance.new("PointLight")
                light.Color, light.Range, light.Brightness = lamp.Color, 42, 1.4
                light.Parent = lamp
            end
        end
    end
    -- Stage everything before replacing a previous art build.
    local old = parent:FindFirstChild(folder.Name)
    if old then
        old:Destroy()
    end
    folder.Parent = parent
    for _, p in parent:GetChildren() do
        if
            p:IsA("BasePart")
            and (
                p.Name:match("^SideWall")
                or p.Name:match("^EndWall")
                or p.Name:match("^ArtWestCourse")
                or p.Name:match("^ArtEastCourse")
                or p.Name:match("^ArtWestJamb")
                or p.Name:match("^ArtEastJamb")
                or p.Name:match("^ArtWestSnowCap")
                or p.Name:match("^ArtFullSideWall")
                or p.Name:match("^ArtFullEndWall")
                or p.Name:match("^ArtFullEndJamb")
            )
        then
            p.Transparency = 1
        end
    end
    return folder
end
return Art
