-- Builds the arena from a layout table in Shared/Maps at server start, and
-- spawns players at their team's spawn points. Supports plain greybox layouts
-- (parts) and themed layouts (terrain, trees, rocks, lighting).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ACTIVE_MAP = "Forest" -- "Greybox" or "Forest"

local MapService = Knit.CreateService({ Name = "MapService" })

local TEAM_COLORS = {
    Red = Color3.fromRGB(200, 60, 60),
    Blue = Color3.fromRGB(60, 110, 200),
}

local GREY = Color3.fromRGB(160, 160, 160)
local ROCK = Color3.fromRGB(96, 98, 92)
local BARK = Color3.fromRGB(78, 56, 40)
local NEEDLE = { Color3.fromRGB(34, 68, 44), Color3.fromRGB(42, 80, 50), Color3.fromRGB(28, 58, 40) }

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
    local base = makePart(model, "Base", { pos[1], pos[2] + size[2] / 2, pos[3] }, size, rot, ROCK, Enum.Material.Slate)
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
        }, ROCK, Enum.Material.Slate)
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
    }, BARK, Enum.Material.Wood, Enum.PartType.Cylinder)
    return log
end

local function makeStump(folder, name, pos, size)
    return makePart(folder, name, { pos[1], pos[2] + size[2] / 2, pos[3] }, { size[2], size[1], size[3] }, {
        0,
        0,
        90,
    }, BARK, Enum.Material.Wood, Enum.PartType.Cylinder)
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
        Enum.Material.Wood,
        Enum.PartType.Cylinder
    )
    trunk.CanCollide = true

    -- Foliage: stacked flattened balls shrinking upward = pine silhouette
    local color = NEEDLE[rng:NextInteger(1, #NEEDLE)]
    local tiers = 5
    for i = 1, tiers do
        local t = (i - 1) / (tiers - 1)
        local y = pos[2] + height * (0.35 + 0.6 * t)
        local w = height * (0.42 - 0.3 * t)
        local ball = makePart(model, "Foliage" .. i, { pos[1], y, pos[3] }, { w, w * 0.55, w }, {
            0,
            rng:NextNumber(0, 360),
            0,
        }, color, Enum.Material.Grass, Enum.PartType.Ball)
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
    -- Ground slab, extended well past the walls so the backdrop has a floor
    terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(layout.Size * 4, 12, layout.Size * 4), t.GroundMaterial)
    for _, h in t.Hills do
        terrain:FillBall(Vector3.new(h[1], h[2], h[3]), h[4], t.GroundMaterial)
    end
    for _, m in t.Mountains do
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
    cc.Saturation = -0.1
    cc.Contrast = 0.08
    cc.TintColor = Color3.fromRGB(240, 235, 225)
    cc.Parent = Lighting
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
        local tint = mirrored and Color3.fromRGB(140, 160, 190) or Color3.fromRGB(190, 140, 140)
        if prefix == "" then
            tint = Color3.fromRGB(190, 190, 120)
        end
        makePart(folder, name, pos, piece.size, rot, tint)
    elseif kind == "rock" then
        makeRock(folder, name, pos, piece.size, rot, rng)
    elseif kind == "log" then
        makeLog(folder, name, pos, piece.size, rot)
    elseif kind == "stump" then
        makeStump(folder, name, pos, piece.size)
    elseif kind == "grove" then
        makeGrove(folder, pos, piece.size, piece.count, rng)
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

    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate:Destroy()
    end
end

function MapService:PlaceCharacter(player, character)
    local team = player:GetAttribute("Team")
    local points = self.Spawns and self.Spawns[team]
    if not points or #points == 0 then
        return
    end
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then
        return
    end
    local idx = (player.UserId % #points) + 1
    local pos = points[idx] + Vector3.new(0, 3, 0)
    root.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

function MapService:KnitInit()
    local layoutModule = ReplicatedStorage.Shared.Maps:FindFirstChild(ACTIVE_MAP == "Greybox" and "Arena" or ACTIVE_MAP)
    self:Build(require(layoutModule))
end

function MapService:KnitStart()
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(self.PlaceCharacter, self, player, character)
        end)
    end)
end

return MapService
