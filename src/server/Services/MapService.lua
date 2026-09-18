-- Builds the arena from a layout table in Shared/Maps at server start, and
-- spawns players at their team's spawn points. Supports plain greybox layouts
-- (parts) and themed layouts (terrain, trees, rocks, lighting).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local ACTIVE_MAP = "Forest" -- "Greybox" or "Forest"

local MapService = Knit.CreateService({ Name = "MapService" })

local TEAM_COLORS = {
    Red = Color3.fromRGB(200, 60, 60),
    Blue = Color3.fromRGB(60, 110, 200),
}

local GREY = Color3.fromRGB(160, 160, 160)
-- Theme palette; overwritten from layout.Palette when a map is built
local ROCK = Color3.fromRGB(96, 98, 92)
local ROCK_EDGE = nil
local BARK = Color3.fromRGB(78, 56, 40)
local WOOD = Color3.fromRGB(110, 75, 45)
local NEEDLE = { Color3.fromRGB(34, 68, 44), Color3.fromRGB(42, 80, 50), Color3.fromRGB(28, 58, 40) }
local MARKER = Color3.fromRGB(255, 240, 80)
local MOUNTAIN = nil
local PALETTE = {} -- full palette table for blocks that name a colour

local function applyPalette(pal)
    PALETTE = pal or {}
    if not pal then
        return
    end
    ROCK = pal.Rock or ROCK
    ROCK_EDGE = pal.RockEdge
    BARK = pal.Bark or BARK
    WOOD = pal.Wood or WOOD
    NEEDLE = pal.Needles or NEEDLE
    MARKER = pal.Marker or MARKER
    MOUNTAIN = pal.Mountain
end

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

local function cframe(pos, rot)
    local cf = CFrame.new(v3(pos))
    if rot then
        cf = cf * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
    end
    return cf
end

local function makePart(folder, name, pos, size, rot, color, material, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Shape = shape or Enum.PartType.Block
    part.Size = v3(size)
    part.CFrame = cframe(pos, rot)
    part.Color = color or GREY
    part.Material = material or Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = folder
    return part
end

-- ===== Themed pieces =====

local function makeRock(folder, name, pos, size, rot, rng)
    -- A few overlapping blocks with slight tilt reads as a boulder.
    local model = Instance.new("Model")
    model.Name = name
    local base =
        makePart(model, "Base", { pos[1], pos[2] + size[2] / 2, pos[3] }, size, rot, ROCK, Enum.Material.SmoothPlastic)
    if ROCK_EDGE then
        -- accent band near the top so cover height reads instantly
        local band = makePart(
            model,
            "Band",
            { pos[1], pos[2] + size[2] - 0.6, pos[3] },
            { size[1] + 0.1, 0.5, size[3] + 0.1 },
            rot,
            ROCK_EDGE,
            Enum.Material.Neon
        )
        band.CanCollide = false
    end
    for i = 1, 2 do
        local s = {
            size[1] * rng:NextNumber(0.5, 0.8),
            size[2] * rng:NextNumber(0.6, 0.9),
            size[3] * rng:NextNumber(0.5, 0.8),
        }
        local off = { rng:NextNumber(-0.3, 0.3) * size[1], size[2] * 0.15 * i, rng:NextNumber(-0.3, 0.3) * size[3] }
        makePart(model, "Lump" .. i, { pos[1] + off[1], pos[2] + s[2] / 2 + off[2], pos[3] + off[3] }, s, {
            rng:NextNumber(-12, 12),
            rng:NextNumber(0, 360),
            rng:NextNumber(-12, 12),
        }, ROCK, Enum.Material.SmoothPlastic)
    end
    model.PrimaryPart = base
    model.Parent = folder
    return model
end

local function makeLog(folder, name, pos, size, rot)
    -- Cylinder parts point along X, so rotate 90 on Y to lay along Z.
    local r = rot or { 0, 0, 0 }
    local log = makePart(folder, name, { pos[1], pos[2] + size[2] / 2, pos[3] }, { size[3], size[2], size[2] }, {
        r[1],
        r[2] + 90,
        r[3],
    }, WOOD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
    return log
end

local function makeStump(folder, name, pos, size)
    return makePart(folder, name, { pos[1], pos[2] + size[2] / 2, pos[3] }, { size[2], size[1], size[3] }, {
        0,
        0,
        90,
    }, WOOD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

local function makeTree(folder, pos, height, rng)
    local model = Instance.new("Model")
    model.Name = "Pine"
    local trunkR = height * 0.045
    local trunk = makePart(
        model,
        "Trunk",
        { pos[1], pos[2] + height * 0.45, pos[3] },
        { height * 0.9, trunkR * 2, trunkR * 2 },
        {
            0,
            0,
            90,
        },
        BARK,
        Enum.Material.SmoothPlastic,
        Enum.PartType.Cylinder
    )
    trunk.CanCollide = true

    -- Foliage: stacked flattened balls shrinking upward = pine silhouette
    local color = NEEDLE[rng:NextInteger(1, #NEEDLE)]
    local tiers = 3
    for i = 1, tiers do
        local t = (i - 1) / (tiers - 1)
        local y = pos[2] + height * (0.42 + 0.5 * t)
        local w = height * (0.5 - 0.28 * t)
        local ball = makePart(model, "Foliage" .. i, { pos[1], y, pos[3] }, { w, w * 0.8, w }, {
            0,
            rng:NextNumber(0, 360),
            0,
        }, color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
        ball.CanCollide = false
        ball.CastShadow = true
    end
    model.PrimaryPart = trunk
    model.Parent = folder
end

local function inRect(x, z, rect)
    return math.abs(x - rect[1]) < rect[3] and math.abs(z - rect[2]) < rect[4]
end

local function scatterTrees(folder, layout, rng)
    local spec = layout.Trees
    local half = layout.Size / 2 - 6
    local placed = {}
    local attempts = 0
    while #placed < spec.Count and attempts < spec.Count * 30 do
        attempts += 1
        local x, z = rng:NextNumber(-half, half), rng:NextNumber(-half, half)
        local ok = true
        for _, rect in spec.Exclude do
            if inRect(x, z, rect) then
                ok = false
                break
            end
        end
        if ok then
            for _, p in placed do
                if (Vector2.new(x, z) - p).Magnitude < spec.MinSpacing then
                    ok = false
                    break
                end
            end
        end
        if ok then
            table.insert(placed, Vector2.new(x, z))
            makeTree(folder, { x, 0, z }, rng:NextNumber(spec.Height[1], spec.Height[2]), rng)
        end
    end
end

local function makeGrove(folder, pos, size, count, rng)
    for _ = 1, count do
        local x = pos[1] + rng:NextNumber(-size[1] / 2, size[1] / 2)
        local z = pos[3] + rng:NextNumber(-size[3] / 2, size[3] / 2)
        makeTree(folder, { x, 0, z }, rng:NextNumber(24, 38), rng)
    end
end

local function buildTerrain(layout)
    local terrain = workspace.Terrain
    terrain:Clear()
    local t = layout.Terrain
    if t.GroundColor then
        terrain:SetMaterialColor(t.GroundMaterial, t.GroundColor)
    end
    if MOUNTAIN then
        terrain:SetMaterialColor(Enum.Material.Rock, MOUNTAIN)
    end
    terrain.WaterColor = Color3.fromRGB(70, 180, 255)
    terrain.WaterTransparency = 0.6
    terrain.WaterReflectance = 0.4
    if t.Sea then
        -- open water far below the structure, out to the horizon
        local level = t.SeaLevel or -30
        terrain:FillBlock(
            CFrame.new(0, level - 20, 0),
            Vector3.new(layout.Size * 6, 40, layout.Size * 6),
            Enum.Material.Water
        )
    else
        -- Ground slab, extended well past the walls so the backdrop has a floor
        terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(layout.Size * 4, 12, layout.Size * 4), t.GroundMaterial)
    end
    for _, h in t.Hills or {} do
        terrain:FillBall(Vector3.new(h[1], h[2], h[3]), h[4], t.GroundMaterial)
    end
    for _, m in t.Mountains or {} do
        terrain:FillBall(Vector3.new(m[1], m[2], m[3]), m[4], Enum.Material.Rock)
    end
    if t.Lake then
        local x, z, rx, rz, depth = table.unpack(t.Lake)
        terrain:FillCylinder(CFrame.new(x, -depth / 2, z), depth, math.max(rx, rz), Enum.Material.Air)
        terrain:FillCylinder(CFrame.new(x, -depth / 2 - 0.5, z), depth - 1, math.max(rx, rz) - 1, Enum.Material.Water)
    end
end

local function applyLighting(env)
    Lighting.ClockTime = env.ClockTime
    Lighting.Brightness = env.Brightness
    Lighting.Ambient = env.Ambient
    Lighting.OutdoorAmbient = env.OutdoorAmbient
    Lighting.FogColor = env.FogColor
    Lighting.FogStart = env.FogStart
    Lighting.FogEnd = env.FogEnd
    Lighting.GlobalShadows = true
    Lighting.EnvironmentDiffuseScale = 0.6
    Lighting.EnvironmentSpecularScale = 0.4

    for _, child in Lighting:GetChildren() do
        if child:IsA("Atmosphere") or child:IsA("PostEffect") then
            child:Destroy()
        end
    end
    local atmo = Instance.new("Atmosphere")
    atmo.Density = env.Atmosphere.Density
    atmo.Haze = env.Atmosphere.Haze
    atmo.Glare = env.Atmosphere.Glare
    atmo.Color = env.Atmosphere.Color
    atmo.Decay = Color3.fromRGB(120, 110, 100)
    atmo.Parent = Lighting

    local rays = Instance.new("SunRaysEffect")
    rays.Intensity = env.SunRays
    rays.Spread = 0.8
    rays.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Intensity = env.Bloom
    bloom.Threshold = 0.9
    bloom.Parent = Lighting

    local cc = Instance.new("ColorCorrectionEffect")
    cc.Saturation = env.Saturation or -0.1
    cc.Contrast = env.Contrast or 0.08
    cc.TintColor = env.Tint or Color3.fromRGB(240, 235, 225)
    cc.Parent = Lighting
end

-- ===== Lobby =====

local function buildLobby(self, layout)
    local old = workspace:FindFirstChild("Lobby")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "Lobby"
    folder.Parent = workspace

    local o = layout.Origin
    local pal = layout.Palette
    local function at(p)
        return { o[1] + p[1], o[2] + p[2], o[3] + p[3] }
    end

    local w, d = layout.Size[1], layout.Size[2]
    makePart(folder, "Floor", at({ 0, -1, 0 }), { w, 2, d }, nil, pal.Floor)
    -- thin grid lines so the floor reads as a designed surface
    for x = -w / 2 + 10, w / 2 - 10, 10 do
        local line = makePart(folder, "GridX", at({ x, 0.02, 0 }), { 0.3, 0.04, d }, nil, pal.FloorGrid)
        line.CanCollide = false
    end
    for z = -d / 2 + 10, d / 2 - 10, 10 do
        local line = makePart(folder, "GridZ", at({ 0, 0.02, z }), { w, 0.04, 0.3 }, nil, pal.FloorGrid)
        line.CanCollide = false
    end
    -- invisible rails so nobody walks off
    local h = 30
    for _, wall in
        {
            { at({ 0, h / 2, -d / 2 }), { w, h, 1 } },
            { at({ 0, h / 2, d / 2 }), { w, h, 1 } },
            { at({ -w / 2, h / 2, 0 }), { 1, h, d } },
            { at({ w / 2, h / 2, 0 }), { 1, h, d } },
        }
    do
        local p = makePart(folder, "Rail", wall[1], wall[2])
        p.Transparency = 1
    end

    for _, piece in layout.Pieces do
        makePart(folder, piece.name, at(piece.pos), piece.size, piece.rot, pal[piece.color] or GREY)
    end

    -- Each mode pad is two halves: stand on the RED half to be Red, BLUE half to be Blue.
    -- A match starts when both halves hold teamSize players. Friends pick a side together.
    local function floorLabel(part, text, color)
        local gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Top
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 30
        gui.Parent = part
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextScaled = true
        t.Font = Enum.Font.GothamBlack
        t.TextColor3 = color
        t.Rotation = 180
        t.Parent = gui
        return t
    end

    self.Pads = {}
    for _, spec in layout.Pads do
        if spec.kind == "Convergence" then
            -- team sizes come from Config/Tuning so tests can shrink the featured mode
            local rules = Config.GetConvergence()
            spec = table.clone(spec)
            spec.teamSize = rules.TeamSize
            spec.minTeamSize = rules.MinTeamSize
        end
        local pw, ph, pd = spec.size[1], spec.size[2], spec.size[3]
        local gap = 1.5
        local halfW = (pw - gap) / 2
        -- ring in the mode colour around both halves
        local ring = makePart(
            folder,
            spec.name .. "Ring",
            at({ spec.pos[1], spec.pos[2] + 0.1, spec.pos[3] }),
            { pw + 3, 0.2, pd + 3 },
            nil,
            spec.color,
            Enum.Material.Neon
        )
        ring.Transparency = 0.5
        ring.CanCollide = false

        local sides = {}
        for _, side in { { team = "Red", dx = -1 }, { team = "Blue", dx = 1 } } do
            local part = makePart(
                folder,
                spec.name .. side.team,
                at({ spec.pos[1] + side.dx * (halfW + gap) / 2, spec.pos[2] + ph / 2, spec.pos[3] }),
                { halfW, ph, pd },
                nil,
                TEAM_COLORS[side.team],
                Enum.Material.Neon
            )
            local count = (spec.minTeamSize and spec.minTeamSize < spec.teamSize)
                    and (spec.minTeamSize .. "-" .. spec.teamSize .. " PLAYERS")
                or (spec.teamSize .. (spec.teamSize == 1 and " PLAYER" or " PLAYERS"))
            floorLabel(part, side.team:upper() .. "\n" .. count, Color3.fromRGB(20, 24, 30))
            sides[side.team] = part
        end

        -- one floating sign per mode above the middle
        local anchor = makePart(
            folder,
            spec.name .. "Sign",
            at({ spec.pos[1], spec.pos[2] + ph / 2, spec.pos[3] }),
            { 1, 1, 1 },
            nil,
            spec.color
        )
        anchor.Transparency = 1
        local sign = Instance.new("BillboardGui")
        sign.Name = "Sign"
        sign.Size = spec.featured and UDim2.fromOffset(420, 150) or UDim2.fromOffset(280, 100)
        sign.StudsOffset = Vector3.new(0, spec.featured and 10 or 7, 0)
        sign.AlwaysOnTop = true
        sign.MaxDistance = 200
        sign.Parent = anchor
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        label.TextColor3 = spec.color
        label.TextStrokeTransparency = 0.3
        label.Text = spec.mode
        label.Parent = sign
        if spec.featured then
            local tag = Instance.new("TextLabel")
            tag.AnchorPoint = Vector2.new(0.5, 0)
            tag.Position = UDim2.new(0.5, 0, 0, -26)
            tag.Size = UDim2.new(1, 0, 0, 24)
            tag.BackgroundTransparency = 1
            tag.Text = "FEATURED"
            tag.TextScaled = true
            tag.Font = Enum.Font.GothamBlack
            tag.TextColor3 = Color3.fromRGB(255, 200, 70)
            tag.TextStrokeTransparency = 0.3
            tag.Parent = sign
            -- gold frame around the whole featured pad
            local frame = makePart(
                folder,
                spec.name .. "Frame",
                at({ spec.pos[1], spec.pos[2] + 0.05, spec.pos[3] }),
                { pw + 6, 0.15, pd + 6 },
                nil,
                Color3.fromRGB(255, 200, 70),
                Enum.Material.Neon
            )
            frame.Transparency = 0.4
            frame.CanCollide = false
        end

        table.insert(self.Pads, {
            Sides = sides,
            Label = label,
            Mode = spec.mode,
            Kind = spec.kind or "Duel",
            TeamSize = spec.teamSize,
            MinTeamSize = spec.minTeamSize or spec.teamSize,
        })
    end

    self.LobbySpawns = {}
    for _, p in layout.Spawns do
        table.insert(self.LobbySpawns, v3(at(p)))
    end

    -- Weapon kiosk
    local k = layout.Kiosk
    if k then
        local counter = makePart(
            folder,
            "WeaponKiosk",
            at({ k.pos[1], k.pos[2] + k.size[2] / 2, k.pos[3] }),
            k.size,
            nil,
            pal.Pillar
        )
        local top = makePart(
            folder,
            "KioskTop",
            at({ k.pos[1], k.pos[2] + k.size[2] + 0.2, k.pos[3] }),
            { k.size[1] + 0.6, 0.4, k.size[3] + 0.6 },
            nil,
            pal.Accent,
            Enum.Material.Neon
        )
        top.CanCollide = false
        local backboard = makePart(
            folder,
            "KioskBoard",
            at({ k.pos[1], k.pos[2] + 7, k.pos[3] - k.size[3] / 2 - 0.5 }),
            { k.size[1], 6, 1 },
            nil,
            pal.Wall
        )

        local sign = Instance.new("SurfaceGui")
        sign.Face = Enum.NormalId.Front
        sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sign.PixelsPerStud = 40
        sign.Parent = backboard
        local text = Instance.new("TextLabel")
        text.Size = UDim2.fromScale(1, 1)
        text.BackgroundTransparency = 1
        text.Text = "WEAPONS"
        text.TextScaled = true
        text.Font = Enum.Font.GothamBlack
        text.TextColor3 = pal.Accent
        text.Parent = sign

        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "WeaponKiosk"
        prompt.ActionText = "Choose Loadout"
        prompt.ObjectText = "Weapons"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 12
        prompt.RequiresLineOfSight = false
        prompt.Parent = counter

        -- Showcase model on the counter, scaled up so it reads from across the hub
        local tool = ReplicatedStorage:FindFirstChild("WeaponTools")
            and ReplicatedStorage.WeaponTools:FindFirstChild(k.showcase)
        local source = tool and tool:FindFirstChildOfClass("Model")
        if source then
            local show = source:Clone()
            show.Name = "Showcase"
            for _, desc in show:GetDescendants() do
                if desc:IsA("BasePart") then
                    desc.Anchored = true
                    desc.CanCollide = false
                elseif
                    desc:IsA("Script")
                    or desc:IsA("LocalScript")
                    or desc:IsA("Sound")
                    or desc:IsA("ProximityPrompt")
                then
                    desc:Destroy()
                end
            end
            show:ScaleTo(2.5)
            local _, size = show:GetBoundingBox()
            show:PivotTo(
                CFrame.new(v3(at({ k.pos[1], k.pos[2] + k.size[2] + 0.4 + size.Y / 2 + 1, k.pos[3] })))
                    * CFrame.Angles(0, math.rad(90), 0)
            )
            show.Parent = folder
            self.Showcase = show
        end
    end
end

-- ===== Builder =====

local function placePiece(folder, prefix, piece, rng, mirrored)
    local pos = mirrored and { -piece.pos[1], piece.pos[2], piece.pos[3] } or piece.pos
    local rot = piece.rot
    if mirrored and rot then
        rot = { rot[1], -rot[2], -rot[3] }
    end
    local name = prefix .. (piece.name or piece.kind)
    local kind = piece.kind or "block"
    if kind == "block" then
        local tint
        if type(piece.color) == "string" then
            tint = PALETTE[piece.color] or GREY
        elseif typeof(piece.color) == "Color3" then
            tint = piece.color
        else
            tint = mirrored and Color3.fromRGB(140, 160, 190) or Color3.fromRGB(190, 140, 140)
            if prefix == "" then
                tint = Color3.fromRGB(190, 190, 120)
            end
        end
        makePart(folder, name, pos, piece.size, rot, tint, piece.material and Enum.Material[piece.material] or nil)
    elseif kind == "rock" then
        makeRock(folder, name, pos, piece.size, rot, rng)
    elseif kind == "log" then
        makeLog(folder, name, pos, piece.size, rot)
    elseif kind == "stump" then
        makeStump(folder, name, pos, piece.size)
    elseif kind == "grove" then
        makeGrove(folder, pos, piece.size, piece.count, rng)
    elseif kind == "marker" then
        local strip =
            makePart(folder, name, { pos[1], pos[2] + 0.15, pos[3] }, piece.size, rot, MARKER, Enum.Material.Neon)
        strip.CanCollide = false
    end
end

function MapService:Build(layout)
    local old = workspace:FindFirstChild("Map")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "Map"
    folder.Parent = workspace

    local rng = Random.new(layout.Seed or 0)
    local themed = layout.Terrain ~= nil
    applyPalette(layout.Palette)

    -- Objectives for ConvergenceService (absolute positions)
    self.Objectives = {}
    for _, o in layout.Objectives or {} do
        table.insert(self.Objectives, { Name = o.Name, Position = v3(o.pos), Radius = o.radius, Phases = o.Phases })
    end

    if themed then
        buildTerrain(layout)
    else
        workspace.Terrain:Clear()
        makePart(
            folder,
            "Floor",
            { 0, -1, 0 },
            { layout.Size, 2, layout.Size },
            nil,
            Color3.fromRGB(90, 90, 95),
            Enum.Material.Concrete
        )
    end

    -- Outer walls: visible for greybox, invisible for themed maps
    local half = layout.Size / 2
    local h = layout.WallHeight
    local walls = {
        { "WallN", { 0, h / 2, -half }, { layout.Size, h, 2 } },
        { "WallS", { 0, h / 2, half }, { layout.Size, h, 2 } },
        { "WallW", { -half, h / 2, 0 }, { 2, h, layout.Size } },
        { "WallE", { half, h / 2, 0 }, { 2, h, layout.Size } },
    }
    for _, w in walls do
        local wall = makePart(folder, w[1], w[2], w[3])
        if themed then
            wall.Transparency = 1
        end
    end

    for _, piece in layout.Center do
        placePiece(folder, "", piece, rng, false)
    end
    for _, piece in layout.Mirrored do
        placePiece(folder, "Red_", piece, rng, false)
        placePiece(folder, "Blue_", piece, rng, true)
    end
    if layout.Trees then
        scatterTrees(folder, layout, rng)
    end

    self.Spawns = {}
    for team, points in layout.Spawns do
        self.Spawns[team] = {}
        for i, p in points do
            local pad = makePart(
                folder,
                team .. "Spawn" .. i,
                { p[1], 0.25, p[3] },
                { 6, 0.5, 6 },
                nil,
                TEAM_COLORS[team],
                Enum.Material.Neon
            )
            pad.CanCollide = false
            table.insert(self.Spawns[team], v3(p))
        end
    end

    if layout.Environment then
        applyLighting(layout.Environment)
    end

    -- Studio's template place adds these; the map provides its own
    for _, name in { "Baseplate", "SpawnLocation" } do
        local inst = workspace:FindFirstChild(name)
        if inst then
            inst:Destroy()
        end
    end
end

function MapService:PlaceCharacter(player, character)
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then
        return
    end
    task.wait() -- let Roblox finish its own spawn placement first

    if player:GetAttribute("InMatch") then
        local team = player:GetAttribute("Team")
        local points = self.Spawns and self.Spawns[team]
        if not points or #points == 0 then
            return
        end
        local idx = (player.UserId % #points) + 1
        local pos = points[idx] + Vector3.new(0, 3, 0)
        root.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
    else
        local points = self.LobbySpawns
        if not points or #points == 0 then
            return
        end
        local idx = (player.UserId % #points) + 1
        local pos = points[idx] + Vector3.new(0, 3, 0)
        -- face the pads (toward -Z of the lobby)
        root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -10))
    end
end

-- Rebuild the arena for a named map (module name under Shared/Maps). Safe between matches.
function MapService:Load(name)
    local module = ReplicatedStorage.Shared.Maps:FindFirstChild(name)
    if not module then
        warn("[MapService] unknown map " .. tostring(name))
        return false
    end
    self:Build(require(module))
    self.CurrentMap = name
    return true
end

function MapService:KnitInit()
    local layoutModule = ReplicatedStorage.Shared.Maps:FindFirstChild(ACTIVE_MAP == "Greybox" and "Arena" or ACTIVE_MAP)
    self.CurrentMap = layoutModule.Name
    self:Build(require(layoutModule))
    buildLobby(self, require(ReplicatedStorage.Shared.Maps.Lobby))

    -- Hook spawns here, in KnitInit, so this runs before RoundService (KnitStart) can
    -- load anyone's character. Otherwise the first spawn lands at the world origin.
    local function watch(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(self.PlaceCharacter, self, player, character)
        end)
        if player.Character then
            task.defer(self.PlaceCharacter, self, player, player.Character)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return MapService
