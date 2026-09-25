-- Builds the arena from a layout table in Shared/Maps at server start, and
-- spawns players at their team's spawn points. Supports plain greybox layouts
-- (parts) and themed layouts (terrain, trees, rocks, lighting).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Config = require(ReplicatedStorage.Shared.Config)
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local Uploads = require(ReplicatedStorage.Shared.Uploads)
local Validate = require(ReplicatedStorage.Shared.Maps.Validate)
local MapAuthoring = require(ReplicatedStorage.Shared.MapAuthoring)

-- The startup map is Config.StartupMap, from Shared/Config.lua only -- TuningService
-- clears any saved StartupMap attribute before this reads it, because one set in an old
-- session used to beat every later edit to the file. This is the last resort if that
-- name does not resolve, so the server still comes up with a playable arena.
local FALLBACK_MAP = "Arena"

local MapService = Knit.CreateService({ Name = "MapService" })

-- Map geometry uses the darker world variants of the same team hues; they read lighter once
-- lit and surfaced. Kept in step with the UI colours in Shared.Palette.
local TEAM_COLORS = {
    Red = Palette.World.Red,
    Blue = Palette.World.Blue,
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

local PREFABS = {}

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
    -- An arctic map wants Glacier, not Rock. Default stays Rock with the module
    -- colour, so maps that declare neither render exactly as before.
    local mountainMaterial = t.MountainMaterial or Enum.Material.Rock
    local mountainColor = t.MountainColor or MOUNTAIN
    if mountainColor then
        terrain:SetMaterialColor(mountainMaterial, mountainColor)
    end
    -- Water appearance is a map decision: a swamp basin and a tropical sea are not the same
    -- colour. These were hard-coded before any layout data was read, so every map got the
    -- same bright blue. Defaults match the old constants exactly, so existing maps that
    -- declare no Terrain.Water render identically.
    local water = t.Water or {}
    terrain.WaterColor = water.Color or Color3.fromRGB(70, 180, 255)
    terrain.WaterTransparency = water.Transparency or 0.6
    terrain.WaterReflectance = water.Reflectance or 0.4
    if water.WaveSize then
        terrain.WaterWaveSize = water.WaveSize
    end
    if water.WaveSpeed then
        terrain.WaterWaveSpeed = water.WaveSpeed
    end
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
        terrain:FillBall(Vector3.new(m[1], m[2], m[3]), m[4], mountainMaterial)
    end
    if t.Lake then
        local x, z, rx, rz, depth = table.unpack(t.Lake)
        terrain:FillCylinder(CFrame.new(x, -depth / 2, z), depth, math.max(rx, rz), Enum.Material.Air)
        terrain:FillCylinder(CFrame.new(x, -depth / 2 - 0.5, z), depth - 1, math.max(rx, rz) - 1, Enum.Material.Water)
    end
end

-- Skybox faces, in Roblox's own naming. A horizon painted here costs no parts and
-- no triangles, cannot be mis-oriented and has no geometry seams -- which is what
-- distant scenery in this project should be. See tools/blender/make_sky_range.py.
local SKY_FACES = { "Up", "Dn", "Lf", "Rt", "Ft", "Bk" }

-- Open Cloud can only mint Decal assets for images, and Sky wants the image *inside*
-- the decal, not the decal itself -- pointing a face at a decal id renders nothing at
-- all. Unwrap it by loading the asset and reading the Decal's Texture. Cached per id,
-- because six faces times every map build is six web calls otherwise.
local skyImage = {}

local function imageForFace(ref)
    local cached = skyImage[ref]
    if cached ~= nil then
        return cached
    end
    local numeric = tonumber(tostring(ref):match("(%d+)"))
    local resolved = nil
    if numeric then
        local ok, model = pcall(function()
            return InsertService:LoadAsset(numeric)
        end)
        if ok and model then
            local decal = model:FindFirstChildWhichIsA("Decal", true)
            if decal and decal.Texture ~= "" then
                resolved = decal.Texture
            end
        end
    end
    -- An id that is already an image has no decal to unwrap, so it is used as given.
    skyImage[ref] = resolved or ref
    return skyImage[ref]
end

local function applySky(env)
    local existing = Lighting:FindFirstChildOfClass("Sky")
    local spec = env.Sky
    local ids = {}
    local missing = nil
    if spec then
        for _, face in SKY_FACES do
            local id = Uploads.resolve(spec[face])
            if not id then
                -- Five faces and a hole is worse than the stock sky, so a partial
                -- upload degrades all the way back rather than part of the way.
                missing = face
                spec = nil
                break
            end
            ids[face] = imageForFace(id)
        end
    end
    -- Say what happened either way. A skybox that silently declines to apply looks
    -- identical to one that was never wired, and telling those apart from the
    -- outside cost a long round of guessing.
    if not spec then
        -- A map that declares no Sky leaves whatever the place has alone. Destroying
        -- it would mean a skybox chosen in Studio -- which is how you actually shop
        -- for one -- gets wiped on every build.
        if missing then
            warn(("[MapSky] %s face is unresolved; leaving the place's own sky"):format(missing))
        else
            print("[MapSky] map declares no Sky; leaving the place's own")
        end
        return
    end
    print(("[MapSky] applied 6 faces, Ft image = %s"):format(tostring(ids.Ft)))
    local skybox = existing or Instance.new("Sky")
    for _, face in SKY_FACES do
        skybox["Skybox" .. face] = ids[face]
    end
    skybox.CelestialBodiesShown = spec.CelestialBodiesShown == true
    skybox.StarCount = spec.StarCount or 0
    skybox.Parent = Lighting
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

    -- Lighting.LightingStyle and Lighting.PrioritizeLightingQuality are NOT set here on purpose.
    -- Both are Security.Write = RobloxScriptSecurity in the API dump, so a game script cannot write
    -- them -- an assignment throws, and wrapping it in pcall only hides that it never took effect.
    -- They are place-level settings: set them in Studio's Properties panel on Lighting (both are
    -- Security.Read = None, so they are visible there). Lighting.Technology is Read and Write
    -- RobloxScriptSecurity, which is why it does not appear in the panel at all.
    -- Verify with: lune run tools/roblox_api.luau property Lighting LightingStyle
    --
    -- What we CAN do is read them back and complain, so a map that needs Realistic lighting fails
    -- loudly in Studio instead of just looking wrong. Read is unrestricted on both.
    if env.RequireLightingStyle and Lighting.LightingStyle ~= env.RequireLightingStyle then
        warn(
            ("[MapService] this map needs Lighting.LightingStyle = %s, place is %s. "):format(
                env.RequireLightingStyle.Name,
                Lighting.LightingStyle.Name
            ) .. "Not script-writable (RobloxScriptSecurity) -- set it on Lighting in Studio."
        )
    end
    if
        env.RequirePrioritizeLightingQuality ~= nil
        and Lighting.PrioritizeLightingQuality ~= env.RequirePrioritizeLightingQuality
    then
        warn(
            ("[MapService] this map needs Lighting.PrioritizeLightingQuality = %s, place is %s. "):format(
                tostring(env.RequirePrioritizeLightingQuality),
                tostring(Lighting.PrioritizeLightingQuality)
            ) .. "Not script-writable (RobloxScriptSecurity) -- set it on Lighting in Studio."
        )
    end

    if env.ShadowSoftness then
        Lighting.ShadowSoftness = env.ShadowSoftness -- Security.Write = None: this one is scriptable
    end

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
        local part = makePart(folder, piece.name, at(piece.pos), piece.size, piece.rot, pal[piece.color] or GREY)
        -- accent strips are the only emissive surfaces in the room, so they read as signal
        if piece.color == "Accent" or (piece.color == "Ego" and piece.name:find("Ring")) then
            part.Material = Enum.Material.Neon
        end
    end

    -- One controlled light per destination instead of a uniformly blown-out floor. The room
    -- should read as three lit places in a dark hall, which is what makes the hierarchy legible.
    for _, spec in layout.Lights or {} do
        local anchor = makePart(folder, spec.name, at(spec.pos), { 1, 1, 1 }, nil, pal[spec.color] or GREY)
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.CanQuery = false
        local light = Instance.new("PointLight")
        light.Color = pal[spec.color] or Color3.new(1, 1, 1)
        light.Range = spec.range or 30
        light.Brightness = spec.brightness or 1.5
        light.Shadows = true
        light.Parent = anchor
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
        if spec.kind == "Convergence" and not spec.solo then
            -- team sizes come from Config/Tuning so tests can shrink the featured mode.
            -- A solo pad is exempt: its whole point is that one person can start, and
            -- inheriting a team size of six would make it as unusable as the pad it
            -- exists to work around.
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
        Palette.worldText(label)
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
            Palette.worldText(tag)
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
            Solo = spec.solo == true,
        })
    end

    self.LobbySpawns = {}
    for _, p in layout.Spawns do
        table.insert(self.LobbySpawns, v3(at(p)))
    end

    -- Leaderboard wall
    local b = layout.Board
    if b then
        local wall = makePart(
            folder,
            "LeaderboardWall",
            at({ b.pos[1], b.pos[2] + b.size[2] / 2, b.pos[3] }),
            b.size,
            nil,
            pal.Wall
        )
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Front
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 40
        sg.Parent = wall
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0.14, 0)
        title.BackgroundTransparency = 1
        title.Text = "LEADERBOARDS"
        title.TextScaled = true
        title.Font = Enum.Font.GothamBlack
        title.TextColor3 = pal.Accent
        title.Parent = sg
        self.BoardLabels = {}
        local names = { "Rating", "BestStreak", "Wins", "BountiesClaimed" }
        local titles = { "CONVERGENCE RATING", "BEST STREAK", "WINS", "BOUNTIES CLAIMED" }
        for i, name in names do
            local col = Instance.new("TextLabel")
            col.Position = UDim2.new((i - 1) * 0.25, 4, 0.15, 0)
            col.Size = UDim2.new(0.25, -8, 0.85, 0)
            col.BackgroundTransparency = 1
            col.TextScaled = true
            col.TextYAlignment = Enum.TextYAlignment.Top
            col.TextXAlignment = Enum.TextXAlignment.Left
            col.Font = Enum.Font.GothamBold
            col.TextColor3 = Color3.fromRGB(240, 240, 245)
            col.Text = titles[i] .. "\n(loading)"
            col.Parent = sg
            self.BoardLabels[name] = { Label = col, Title = titles[i] }
        end
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
        text.Text = "ARMORY"
        text.TextScaled = true
        text.Font = Enum.Font.GothamBlack
        text.TextColor3 = pal.Accent
        text.Parent = sign

        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "WeaponKiosk"
        prompt.ActionText = "Open Loadout"
        prompt.ObjectText = "Armory"
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

-- mirror: nil = place as authored, "x" = flip across X (the Red/Blue team mirror),
-- "z" = flip across Z (the two wings of an asymmetric map, same team both sides).
-- Reflecting one axis negates the rotations about the other two, so an X-mirror keeps rot.x
-- and a Z-mirror keeps rot.z. A ramp moved between the two tables does not survive the move.
local function mirrorOf(pos, rot, mirror)
    if mirror == "x" then
        return { -pos[1], pos[2], pos[3] }, rot and { rot[1], -rot[2], -rot[3] } or nil
    elseif mirror == "z" then
        return { pos[1], pos[2], -pos[3] }, rot and { -rot[1], -rot[2], rot[3] } or nil
    end
    return pos, rot
end

-- Dressing never changes the map players move and shoot through: a piece marked `decor`
-- is visual only, so a detail pass cannot invalidate the geometry audit or block a bullet.
-- Decor a designer arranged in Studio and saved to assets/environment/decor/<Map>.rbxmx,
-- which Rojo maps to ServerStorage.MapDecor. No coordinates pass through a source file
-- and no round trip through anybody: it is moved with the move tool and committed as a
-- model. The only property forced here is Anchored, because an unanchored part falls
-- through the world and that is never what was meant. Collision is left exactly as
-- authored -- Studio is the authoring tool, so what was set there is the intent -- and
-- tools/check_decor.luau audits collidable decor against the traversal routes, which is
-- the one thing a designer cannot see from inside the viewport.
local function authoredDecor(parent, mapName)
    local store = ServerStorage:FindFirstChild("MapDecor")
    local set = store and store:FindFirstChild(mapName)
    if not set then
        return
    end
    local count = 0
    for _, child in set:GetChildren() do
        local copy = child:Clone()
        if copy:IsA("BasePart") then
            copy.Anchored = true
        end
        for _, d in copy:GetDescendants() do
            if d:IsA("BasePart") then
                d.Anchored = true
            end
        end
        copy.Parent = parent
        count += 1
    end
    if count > 0 then
        print(("[MapService] %d authored decor pieces for %s"):format(count, mapName))
    end
end

-- A map saved from workspace.Map after MapService built it, synced by Rojo from
-- assets/environment/baked. Cloning one skips the geometry loops entirely: the parts are
-- already parts, the facade meshes keep their SurfaceAppearances, and the props are real
-- instead of arriving later over InsertService.
--
-- SafetyService's barrier is regenerated live rather than taken from the file. It is in
-- the bake, because it is built into the Map folder, but it is the one thing here that is
-- safety-critical and derived from Bounds -- it should follow the data, not a snapshot.
-- Geometry for maps read live from Workspace in Studio (see readLiveMaps), by name.
local LIVE_BAKES = {}

local function bakedModel(name)
    if LIVE_BAKES[name] then
        return LIVE_BAKES[name]
    end
    -- Presence decides, not a flag. A flag defaulting to false was migration scaffolding,
    -- and once SnowFortress had given up its geometry it became a trap: the toggle only
    -- ever lived at runtime, so a restart put it back to false, the map then had neither a
    -- builder nor a bake, and the match aborted to the lobby. A map either has a baked
    -- model or it does not, and that question has one honest answer.
    local store = ServerStorage:FindFirstChild("BakedMaps")
    local model = store and store:FindFirstChild(name)
    if not model and store == nil then
        -- No BakedMaps folder at all, which is a setup problem rather than a map problem:
        -- Rojo does not reload default.project.json, so a session started before that
        -- mapping existed has no folder. Worth saying, because the alternative is a map
        -- that silently builds the old way or, for a RequiresBake map, does not build.
        warn(
            "[MapBuild] ServerStorage.BakedMaps does not exist -- restart `rojo serve`, "
                .. "which does not reload default.project.json on its own."
        )
    end
    return model
end

local function cloneBaked(folder, baked)
    local parts = 0
    for _, child in baked:GetChildren() do
        if child.Name:sub(1, 13) == "SafetyBarrier" then
            continue
        end
        local copy = child:Clone()
        copy.Parent = folder
        parts += 1
    end
    print(("[MapBuild] cloned %d baked children"):format(parts))
end

local function applyDecor(part, piece)
    if piece.decor then
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = piece.shadow ~= false
    end
end

local function tintOf(piece)
    if type(piece.color) == "string" then
        return PALETTE[piece.color] or GREY
    elseif typeof(piece.color) == "Color3" then
        return piece.color
    end
    return GREY
end

-- A prefab is an assembly authored once in layout.Prefabs and stamped many times: a buttress,
-- a railing run, a lamp. Children are local to the instance, so moving the instance moves the
-- whole thing. Mirroring reflects the instance AND each child on the same axis, so a mirrored
-- assembly is a true mirror rather than a translated copy.
local function placePrefab(folder, name, inst, mirror)
    local def = PREFABS[inst.prefab]
    if not def then
        warn("[MapService] unknown prefab " .. tostring(inst.prefab))
        return
    end
    local basePos, baseRot = mirrorOf(inst.pos, inst.rot, mirror)
    local baseCF = cframe(basePos, baseRot)
    local scale = inst.scale or 1
    for i, child in def do
        local cPos, cRot = mirrorOf(child.pos, child.rot, mirror)
        local worldCF = baseCF * cframe({ cPos[1] * scale, cPos[2] * scale, cPos[3] * scale }, cRot)
        local childName = name .. "_" .. (child.name or tostring(i))
        if child.kind == "light" then
            local anchor = makePart(folder, childName, { 0, 0, 0 }, { 1, 1, 1 }, nil, tintOf(child))
            anchor.CFrame = worldCF
            anchor.Transparency = 1
            anchor.CanCollide = false
            anchor.CanQuery = false
            local light = Instance.new("PointLight")
            light.Color = tintOf(child)
            light.Range = child.range or 24
            light.Brightness = child.brightness or 1.2
            light.Shadows = true
            light.Parent = anchor
        else
            local size = { child.size[1] * scale, child.size[2] * scale, child.size[3] * scale }
            local part = makePart(
                folder,
                childName,
                { 0, 0, 0 },
                size,
                nil,
                tintOf(child),
                child.material and Enum.Material[child.material] or nil
            )
            part.CFrame = worldCF
            if child.transparency then
                part.Transparency = child.transparency
            end
            applyDecor(part, child)
        end
    end
end

-- A specific Creator Store model, placed as map decor. Loaded once per asset id and
-- cached, because a map can place the same rock twenty times and LoadAsset yields
-- and hits the network. A failed load warns once and leaves the prop out rather than
-- taking the build down with it.
local CORNERS = {
    Vector3.new(-1, -1, -1),
    Vector3.new(-1, -1, 1),
    Vector3.new(-1, 1, -1),
    Vector3.new(-1, 1, 1),
    Vector3.new(1, -1, -1),
    Vector3.new(1, -1, 1),
    Vector3.new(1, 1, -1),
    Vector3.new(1, 1, 1),
}

-- World-axis bounds over the parts you can actually SEE, which is not what
-- Model:GetBoundingBox gives you. That box spans every part in the model, so an
-- invisible collision hull or a stray anchor part sitting below the mesh makes it
-- taller than the rock looks -- and then `sit`, which lifts by half that height,
-- leaves the rock hanging in the air above its own shadow. It is also pivot-aligned
-- rather than world-aligned, so it only agrees with the world for a yaw-only pivot.
-- Eight corners per part, min and max: exact, and no assumptions about orientation.
local function visibleExtents(model)
    local min, max
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") and d.Transparency < 1 then
            for _, corner in CORNERS do
                local point = d.CFrame * (corner * d.Size / 2)
                min = min and min:Min(point) or point
                max = max and max:Max(point) or point
            end
        end
    end
    return min, max
end

local propTemplates = {}

local function propTemplate(assetId)
    if type(assetId) ~= "number" then
        return nil
    end
    local cached = propTemplates[assetId]
    if cached == nil then
        local ok, model = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        cached = (ok and model) or false
        propTemplates[assetId] = cached
        if not cached then
            warn(("[MapService] prop asset %d could not be loaded; it will be missing"):format(assetId))
        elseif model:IsA("Model") then
            -- Say how big it actually arrives. A bought model is whatever size its
            -- author chose and there is no way to know before it loads, so the
            -- alternative is guessing a `scale` and reading the result off the
            -- screen. Print it once per asset and use `fit` instead.
            local _, size = model:GetBoundingBox()
            local min, max = visibleExtents(model)
            local span = (min and max - min) or size
            print(
                ("[MapService] prop %d loads at %.1f x %.1f x %.1f visible (%.1f x %.1f x %.1f with hidden parts)"):format(
                    assetId,
                    span.X,
                    span.Y,
                    span.Z,
                    size.X,
                    size.Y,
                    size.Z
                )
            )
        end
    end
    return cached or nil
end

local function placePiece(folder, prefix, piece, rng, mirror)
    local pos, rot = mirrorOf(piece.pos, piece.rot, mirror)
    local name = prefix .. (piece.name or piece.kind)
    local kind = piece.kind or "block"
    if kind == "block" then
        local tint
        if type(piece.color) == "string" then
            tint = PALETTE[piece.color] or GREY
        elseif typeof(piece.color) == "Color3" then
            tint = piece.color
        else
            tint = mirror == "x" and Color3.fromRGB(140, 160, 190) or Color3.fromRGB(190, 140, 140)
            if prefix == "" then
                tint = Color3.fromRGB(190, 190, 120)
            end
        end
        local part =
            makePart(folder, name, pos, piece.size, rot, tint, piece.material and Enum.Material[piece.material] or nil)
        if piece.transparency then
            part.Transparency = piece.transparency
        end
        applyDecor(part, piece)
    elseif kind == "prefab" then
        placePrefab(folder, name, piece, mirror)
    elseif kind == "rock" then
        makeRock(folder, name, pos, piece.size, rot, rng)
    elseif kind == "log" then
        makeLog(folder, name, pos, piece.size, rot)
    elseif kind == "stump" then
        makeStump(folder, name, pos, piece.size)
    elseif kind == "grove" then
        makeGrove(folder, pos, piece.size, piece.count, rng)
    elseif kind == "prop" then
        -- Decor by default: a prop is somebody else's mesh, so the layout gates cannot
        -- audit its shape, and letting it block movement or bullets silently puts
        -- geometry into the fight that nothing checks.
        --
        -- `collide` opts one back in when the shape is wanted as real cover. It then
        -- has to answer raycasts as well, because cover that stops players but not
        -- bullets -- or the reverse -- is worse than no cover at all. The gates still
        -- cannot see it, so a collidable prop is a deliberate, reviewed exception.
        local template = propTemplate(piece.assetId)
        if template then
            local model = template:Clone()
            local solid = piece.collide == true
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    d.Anchored = true
                    d.CanCollide = solid
                    d.CanQuery = solid
                    d.CanTouch = false
                    -- CollisionFidelity is deliberately NOT set here. It carries plugin
                    -- security, so a server script writing it throws "lacking capability
                    -- Plugin", and because that happens inside the build it took the
                    -- whole map down and fell it back to Arena -- a greybox, on a map
                    -- that had looked fine a moment earlier.
                    --
                    -- A prop therefore keeps whatever fidelity it was imported with, and
                    -- Open Cloud gives no control over import settings either, so a
                    -- collidable prop is roughly its hull: solid to stand on and walk
                    -- around, approximate up close. Author a block where shape matters.
                end
            end
            model.Name = name
            local cf = CFrame.new(pos[1], pos[2], pos[3])
            if rot then
                cf = cf * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
            end
            -- Orient first: `fit` and `sit` both measure the bounding box, and the
            -- box a rotated model occupies is not the one it started with.
            model:PivotTo(cf)
            if model:IsA("Model") then
                -- `fit` is the honest lever. `scale` is a multiplier on a size the
                -- author never measured, so it is a guess that reads wrong in game
                -- until somebody eyeballs it; `fit` names the studs it should end up
                -- and lets the number come from the model that actually loaded.
                local min, max = visibleExtents(model)
                if piece.fit and min then
                    local span = max - min
                    local longest = math.max(span.X, span.Z)
                    if longest > 0 then
                        model:ScaleTo(piece.fit / longest)
                        min, max = visibleExtents(model)
                    end
                elseif piece.scale and piece.scale ~= 1 then
                    model:ScaleTo(piece.scale)
                    min, max = visibleExtents(model)
                end
                -- A Model's pivot is its bounding-box CENTRE, so placing one at ground
                -- level buries half of it. `sit` puts its lowest VISIBLE point on pos.y,
                -- which is what "on the floor" always meant.
                if piece.sit and min then
                    model:PivotTo(model:GetPivot() + Vector3.new(0, pos[2] - min.Y, 0))
                    min, max = visibleExtents(model)
                end
                if (piece.fit or piece.sit) and min then
                    -- Report what was actually placed, not what was asked for. Every
                    -- prop problem so far -- buried, floating, seventy studs wide --
                    -- was invisible until a number said so.
                    local span = max - min
                    print(
                        ("[MapService] %s placed %.1f x %.1f x %.1f studs, base at y %.1f"):format(
                            name,
                            span.X,
                            span.Y,
                            span.Z,
                            min.Y
                        )
                    )
                end
            end
            model.Parent = folder
        end
    elseif kind == "marker" then
        local strip =
            makePart(folder, name, { pos[1], pos[2] + 0.15, pos[3] }, piece.size, rot, MARKER, Enum.Material.Neon)
        strip.CanCollide = false
    elseif kind == "light" then
        -- invisible anchor with a PointLight: interior and bridge lighting
        local anchor = makePart(folder, name, pos, { 1, 1, 1 }, nil, PALETTE[piece.color] or GREY)
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        local light = Instance.new("PointLight")
        light.Color = PALETTE[piece.color] or Color3.new(1, 1, 1)
        light.Range = piece.range or 40
        light.Brightness = piece.brightness or 1
        light.Shadows = true
        light.Parent = anchor
    elseif kind == "beacon" then
        -- flashing warning light: neon ball + point light, toggled by a loop the folder owns
        local color = PALETTE[piece.color] or Color3.fromRGB(255, 60, 50)
        local ball = makePart(folder, name, pos, { 1.2, 1.2, 1.2 }, nil, color, Enum.Material.Neon, Enum.PartType.Ball)
        ball.CanCollide = false
        local light = Instance.new("PointLight")
        light.Color = color
        light.Range = 18
        light.Brightness = 2
        light.Parent = ball
        ball:SetAttribute("Beacon", true)
        task.spawn(function()
            local on = true
            while ball.Parent do
                on = not on
                ball.Transparency = on and 0 or 0.8
                light.Enabled = on
                task.wait(ball:GetAttribute("BeaconFast") and 0.25 or 1.2)
            end
        end)
    elseif kind == "elevator" then
        -- aircraft elevator: a platform cycling between deck level and hangar level
        local plat = makePart(folder, name, pos, piece.size, rot, PALETTE.Steel or GREY, Enum.Material.DiamondPlate)
        local stripe = makePart(
            folder,
            name .. "Stripe",
            { pos[1], pos[2] + piece.size[2] / 2 + 0.05, pos[3] },
            { piece.size[1], 0.1, 1 },
            rot,
            PALETTE.Hazard or MARKER
        )
        stripe.CanCollide = false
        local low, high, period = piece.low or 0.5, piece.high or pos[2], piece.period or 12
        -- Keep each part's rotation and re-apply it at the target height. Rebuilding the CFrame
        -- from pos alone squared up a rotated elevator on its first cycle.
        local platRot = plat.CFrame - plat.CFrame.Position
        local stripeRot = stripe.CFrame - stripe.CFrame.Position
        local stripeLift = stripe.CFrame.Position.Y - plat.CFrame.Position.Y
        task.spawn(function()
            local goingDown = true
            while plat.Parent do
                task.wait(period / 2)
                if not plat.Parent then
                    break
                end
                local targetY = goingDown and low or high
                local info = TweenInfo.new(period / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                TweenService:Create(plat, info, { CFrame = CFrame.new(pos[1], targetY, pos[3]) * platRot }):Play()
                TweenService
                    :Create(stripe, info, {
                        CFrame = CFrame.new(pos[1], targetY + stripeLift, pos[3]) * stripeRot,
                    })
                    :Play()
                goingDown = not goingDown
            end
        end)
    elseif kind == "steam" then
        -- steam vent: small particle plume, ambient only
        local vent = makePart(folder, name, pos, { 1.5, 0.6, 1.5 }, nil, PALETTE.HullDark or GREY, Enum.Material.Metal)
        vent.CanCollide = false
        local att = Instance.new("Attachment")
        att.Parent = vent
        local pe = Instance.new("ParticleEmitter")
        pe.Color = ColorSequence.new(Color3.fromRGB(230, 235, 240))
        pe.Size = NumberSequence.new(1, 3)
        pe.Transparency = NumberSequence.new(0.5, 1)
        pe.Lifetime = NumberRange.new(1.5, 2.5)
        pe.Speed = NumberRange.new(4, 7)
        pe.SpreadAngle = Vector2.new(15, 15)
        pe.Rate = 6
        pe.Parent = att
    elseif kind == "radar" then
        -- rotating radar dish on a pivot
        local pivot = makePart(folder, name .. "Pivot", pos, { 1, 1, 1 }, nil, PALETTE.Steel or GREY)
        pivot.Transparency = 1
        pivot.CanCollide = false
        local dish = makePart(
            folder,
            name,
            { pos[1], pos[2], pos[3] },
            { 10, 0.6, 3 },
            { 0, 0, 15 },
            PALETTE.Steel or GREY
        )
        dish.CanCollide = false
        task.spawn(function()
            local angle = 0
            while dish.Parent do
                task.wait(0.05)
                angle += 0.05 * 1.5
                dish.CFrame = CFrame.new(v3(pos)) * CFrame.Angles(0, angle, math.rad(15))
            end
        end)
    elseif kind == "helicopter" then
        local model = Instance.new("Model")
        model.Name = name
        local r = rot or { 0, 0, 0 }
        local base = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(0, math.rad(r[2]), 0)
        local col = PALETTE.Jet or GREY
        local function hp(n, off, size, color, material)
            local p = Instance.new("Part")
            p.Name = n
            p.Anchored = true
            p.Size = Vector3.new(size[1], size[2], size[3])
            p.CFrame = base * CFrame.new(off[1], off[2], off[3])
            p.Color = color or col
            p.Material = material or Enum.Material.Metal
            p.Parent = model
            return p
        end
        hp("Cabin", { 0, 3, 0 }, { 5, 4, 12 })
        hp("Tail", { 0, 3.5, 11 }, { 1.2, 1.4, 12 })
        hp("TailFin", { 0, 5.5, 16 }, { 0.4, 3, 2 })
        hp("Skid1", { -2, 0.6, 0 }, { 0.4, 0.4, 10 }, Color3.fromRGB(40, 40, 45))
        hp("Skid2", { 2, 0.6, 0 }, { 0.4, 0.4, 10 }, Color3.fromRGB(40, 40, 45))
        hp("Canopy", { 0, 4, -4.5 }, { 4, 2.4, 3 }, Color3.fromRGB(60, 70, 90), Enum.Material.Glass)
        local rotor = hp("Rotor", { 0, 5.6, 0 }, { 22, 0.15, 1 }, Color3.fromRGB(40, 40, 45))
        hp("Rotor2", { 0, 5.6, 0 }, { 1, 0.15, 22 }, Color3.fromRGB(40, 40, 45))
        rotor.Name = "RotorA"
        model.Parent = folder
    elseif kind == "jet" then
        -- chunky parked jet: fuselage, wings, tail, canopy. One big readable prop.
        local model = Instance.new("Model")
        model.Name = name
        local r = rot or { 0, 0, 0 }
        local base = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(0, math.rad(r[2]), 0)
        local jet = PALETTE.Jet or GREY
        local function jp(n, off, size, color, material)
            local p = Instance.new("Part")
            p.Name = n
            p.Anchored = true
            p.Size = Vector3.new(size[1], size[2], size[3])
            p.CFrame = base * CFrame.new(off[1], off[2], off[3])
            p.Color = color or jet
            p.Material = material or Enum.Material.Metal
            p.Parent = model
            return p
        end
        jp("Fuselage", { 0, 2.2, 0 }, { 4, 3, 22 })
        jp("Nose", { 0, 2.2, -13 }, { 2.5, 2.2, 5 })
        jp("WingL", { -8, 1.8, 2 }, { 12, 0.5, 8 })
        jp("WingR", { 8, 1.8, 2 }, { 12, 0.5, 8 })
        jp("Tail", { 0, 5, 9 }, { 0.5, 5, 5 })
        jp("Canopy", { 0, 4.2, -5 }, { 2.4, 1.4, 5 }, Color3.fromRGB(60, 70, 90), Enum.Material.Glass)
        jp("Gear1", { 0, 0.6, -8 }, { 0.6, 1.4, 0.6 }, Color3.fromRGB(40, 40, 45))
        jp("Gear2", { -2, 0.6, 3 }, { 0.6, 1.4, 0.6 }, Color3.fromRGB(40, 40, 45))
        jp("Gear3", { 2, 0.6, 3 }, { 0.6, 1.4, 0.6 }, Color3.fromRGB(40, 40, 45))
        model.Parent = folder
    else
        -- a typo in `kind` used to place nothing at all: an invisible hole in the map
        warn(("[MapService] unknown piece kind %q on %s, nothing placed"):format(kind, name))
    end
end

function MapService:Build(layout)
    -- Check before touching the world: bailing out after the old Map is destroyed would leave
    -- players standing in an empty skybox.
    for _, key in { "Name", "Size", "WallHeight", "Spawns" } do
        if layout[key] == nil then
            error(("[MapService] layout is missing %s"):format(key), 0)
        end
    end
    if RunService:IsStudio() then
        -- The build gate (tools/check_maps.luau) is the real check; this catches a layout edited
        -- in Studio since the last run. Warn only, never block a test session.
        -- A baked map's geometry is its bake, not its layout's (empty) piece lists; checking
        -- without it reported every barrier and launch landing as floating in empty space.
        local bake = bakedModel(layout.Name)
        local ok, errors = Validate.check(layout, nil, bake and MapAuthoring.solids({ bake }, Validate) or nil)
        if not ok then
            warn(("[MapService] %s fails validation (%d):"):format(layout.Name, #errors))
            for _, e in errors do
                warn("    " .. e)
            end
        end
    end
    print(("[MapBuild] %s / %s"):format(layout.Name, layout.Revision or "default"))
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
    PREFABS = layout.Prefabs or {}

    self.Layout = layout
    self.Vista = layout.Vista
    self.Events = layout.Events or {}
    self.MapFolder = folder
    Knit.GetService("SafetyService"):BuildBarrier(layout, folder)
    self.SniperOutposts = {}
    for _, o in layout.SniperOutposts or {} do
        table.insert(self.SniperOutposts, { Name = o.Name, Position = v3(o.pos), Radius = o.radius })
    end
    -- gameplay pickups / launch pads and the living-world layer
    Knit.GetService("PickupService"):Build(layout)
    Knit.GetService("TraversalService"):Build(layout)
    Knit.GetService("AmbientService"):Build(layout)

    -- Objectives for ConvergenceService (absolute positions)
    self.Objectives = {}
    for _, o in layout.Objectives or {} do
        table.insert(self.Objectives, {
            Id = o.Id,
            Name = o.Name,
            Position = v3(o.pos),
            Radius = o.radius,
            HalfHeight = o.halfHeight or 12,
            Phases = o.Phases,
        })
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

    -- Either the geometry is built from data, or it is cloned from a bake of that same
    -- build. Never both. Everything outside this block -- terrain, lighting, spawns,
    -- objectives, pickups, traversal, the barrier -- comes from the layout either way,
    -- because none of it is geometry.
    local baked = bakedModel(layout.Name)
    -- A map whose geometry lives only in its bake has nothing to fall back to. Failing
    -- here is the honest outcome: MapService:Load pcalls this and falls back to a map
    -- that works, which beats dropping players into an empty skybox.
    if layout.RequiresBake and not baked then
        error(
            ("[MapService] %s has no geometry of its own and no baked model. Restart `rojo serve` "):format(
                tostring(layout.Name)
            ) .. "so ServerStorage.BakedMaps exists, or re-bake the map.",
            0
        )
    end
    if baked then
        cloneBaked(folder, baked)
    else
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

        for _, piece in layout.Center or {} do
            placePiece(folder, "", piece, rng, nil)
        end

        -- Decoration lives in its own folder, separate from the geometry that decides
        -- fights. Two reasons, and neither is tidiness. A decor change should never need
        -- the review a wall needs, and a designer arranging rocks in Studio should have no
        -- way to nudge a sightline screen by accident -- one folder is theirs, the other
        -- is the map's.
        local decor = Instance.new("Folder")
        decor.Name = "Decor"
        decor.Parent = folder
        for _, piece in layout.Decor or {} do
            placePiece(decor, "", piece, rng, nil)
        end
        authoredDecor(decor, layout.Name)
        for _, piece in layout.Mirrored or {} do
            placePiece(folder, "Red_", piece, rng, nil)
            placePiece(folder, "Blue_", piece, rng, "x")
        end
        -- Asymmetric maps (Snow Fortress) are symmetric about Z instead: author one wing, mirror to the other.
        for _, piece in layout.MirroredZ or {} do
            placePiece(folder, "N_", piece, rng, nil)
            placePiece(folder, "S_", piece, rng, "z")
        end
        if layout.Trees then
            scatterTrees(folder, layout, rng)
        end
    end

    self.Spawns = {}
    for team, points in layout.Spawns or {} do
        if not TEAM_COLORS[team] then
            -- a misspelt team builds a pad nobody spawns on and strands that side at the origin
            warn(("[MapService] %s: Spawns.%s is not a team, ignoring"):format(layout.Name or "?", tostring(team)))
            continue
        end
        self.Spawns[team] = {}
        for i, p in points do
            local pad = makePart(
                folder,
                team .. "Spawn" .. i,
                { p[1], p[2] + 0.25, p[3] },
                { 6, 0.5, 6 },
                nil,
                TEAM_COLORS[team],
                Enum.Material.Neon
            )
            pad.CanCollide = false
            table.insert(self.Spawns[team], v3(p))
        end
    end

    for _, team in Config.Teams do
        if not self.Spawns[team] or #self.Spawns[team] == 0 then
            warn(("[MapService] %s: no %s spawns; that team will spawn at the origin"):format(layout.Name or "?", team))
        end
    end

    if layout.Environment then
        applyLighting(layout.Environment)
        applySky(layout.Environment)
    end

    -- Studio's template place adds these; the map provides its own
    for _, name in { "Baseplate", "SpawnLocation" } do
        local inst = workspace:FindFirstChild(name)
        if inst then
            inst:Destroy()
        end
    end
end

-- Pick a spawn point that nobody is standing on. `UserId % #points` gave a player the same pad
-- every round (learnable by the enemy) and stacked players whose ids collided modulo the count.
-- Studs: another live character this close counts as taking the pad. Sized to the 6x6 spawn
-- pad, so one character marks its own pad and not its neighbour's. check_maps enforces that
-- pads stay at least this far apart (Validate.RULES.SpawnSpacingMin).
local OCCUPIED = 6

-- Anything that could be standing on a pad. Player characters and BotService rigs are both
-- Models under workspace with a Humanoid, so one scan covers both and neither service has to
-- know about the other.
local function liveRoots(exclude)
    local roots = {}
    for _, inst in workspace:GetChildren() do
        if inst ~= exclude and inst:IsA("Model") then
            local hum = inst:FindFirstChildOfClass("Humanoid")
            local root = inst:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                table.insert(roots, root)
            end
        end
    end
    return roots
end

local function pickSpawn(points, exclude)
    local roots = liveRoots(exclude)
    local free, taken = {}, {}
    for _, point in points do
        local occupied = false
        for _, root in roots do
            if (root.Position - point).Magnitude < OCCUPIED then
                occupied = true
                break
            end
        end
        table.insert(occupied and taken or free, point)
    end
    local pool = #free > 0 and free or taken
    return pool[math.random(#pool)]
end

-- Shared by PlaceCharacter and BotService:SpawnFor so players and bots never pick the same pad.
-- `exclude` is the character being placed, when it already exists. Returns nil if the map has
-- no spawns for that team.
function MapService:PickSpawn(team, exclude)
    local points = self.Spawns and self.Spawns[team]
    if not points or #points == 0 then
        return nil
    end
    return pickSpawn(points, exclude)
end

function MapService:PlaceCharacter(player, character)
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then
        return
    end
    task.wait() -- let Roblox finish its own spawn placement first

    if player:GetAttribute("InMatch") then
        local team = player:GetAttribute("Team")
        local point = self:PickSpawn(team, character)
        if not point then
            warn(
                ("[MapService] no spawns for team %s; %s left where Roblox put them"):format(
                    tostring(team),
                    player.Name
                )
            )
            return
        end
        local pos = point + Vector3.new(0, 3, 0)
        root.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
    elseif
        self.ExploreMap
        and self.CurrentMap == self.ExploreMap
        and player:GetAttribute("Exploring") ~= false
        and self:PickSpawn("Blue")
    then
        -- Studio with a map in Workspace: Play puts you on it, not in the lobby.
        local pos = self:PickSpawn("Blue", character) + Vector3.new(0, 3, 0)
        root.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
    else
        local points = self.LobbySpawns
        if not points or #points == 0 then
            return
        end
        local pos = pickSpawn(points, character) + Vector3.new(0, 3, 0)
        -- face the pads (toward -Z of the lobby)
        root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, -10))
    end
end

-- ===== Map events (signature moments) =====
-- Runs one event's visuals + hazard on a timeline. onWarning/onStart/onEnd are optional callbacks.
-- Returns a function that tells whether a position is inside the lethal region right now.
function MapService:RunEvent(event, callbacks)
    callbacks = callbacks or {}
    local folder = self.MapFolder
    local active = false
    local region = event.Region

    local function inside(position)
        if not active or not region then
            return false
        end
        local p, sz = region.pos, region.size
        return math.abs(position.X - p[1]) <= sz[1] / 2
            and math.abs(position.Y - p[2]) <= sz[2] / 2
            and math.abs(position.Z - p[3]) <= sz[3] / 2
    end

    task.spawn(function()
        -- Warning: siren, beacons fast, hazard box outline
        local soundId = Uploads.resolve(event.Sound)
        local anchor
        if region then
            anchor = makePart(folder, "EventAnchor", region.pos, { 1, 1, 1 }, nil, Color3.new())
            anchor.Transparency = 1
            anchor.CanCollide = false
        end
        if soundId and anchor then
            local snd = Instance.new("Sound")
            snd.SoundId = soundId
            snd.Volume = 1
            snd.RollOffMaxDistance = 400
            snd.Looped = true
            snd.Parent = anchor
            snd:Play()
            task.delay((event.WarningSeconds or 5) + (event.DurationSeconds or 20), function()
                snd:Stop()
            end)
        end
        if event.Beacons and folder then
            for _, d in folder:GetDescendants() do
                if d:GetAttribute("Beacon") then
                    d:SetAttribute("BeaconFast", true)
                end
            end
        end
        local outline
        if region then
            outline = makePart(
                folder,
                "EventZone",
                region.pos,
                region.size,
                nil,
                Color3.fromRGB(255, 80, 40),
                Enum.Material.ForceField
            )
            outline.Transparency = 0.7
            outline.CanCollide = false
            outline.CanQuery = false
        end
        if callbacks.onWarning then
            callbacks.onWarning()
        end
        task.wait(event.WarningSeconds or 5)

        -- Start: blast shield rises, region lethal
        local shield
        if event.Shield then
            shield = folder:FindFirstChild("BlastShield")
            if shield then
                TweenService:Create(shield, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
                    CFrame = shield.CFrame
                        * CFrame.Angles(0, 0, math.rad(-60))
                        * CFrame.new(0, (event.Shield.rise or 6) / 2, 0),
                    Size = Vector3.new(shield.Size.X, event.Shield.rise or 6, shield.Size.Z),
                }):Play()
            end
        end
        if outline then
            outline.Transparency = 0.4
            outline.Color = Color3.fromRGB(255, 120, 40)
        end
        active = true
        if callbacks.onStart then
            callbacks.onStart()
        end
        task.wait(event.DurationSeconds or 20)

        -- End: restore
        active = false
        if shield then
            TweenService
                :Create(shield, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
                    CFrame = CFrame.new(event.Shield.pos[1], event.Shield.pos[2], event.Shield.pos[3]),
                    Size = Vector3.new(event.Shield.size[1], event.Shield.size[2], event.Shield.size[3]),
                })
                :Play()
        end
        if outline then
            outline:Destroy()
        end
        if anchor then
            anchor:Destroy()
        end
        if event.Beacons and folder then
            for _, d in folder:GetDescendants() do
                if d:GetAttribute("Beacon") then
                    d:SetAttribute("BeaconFast", nil)
                end
            end
        end
        if callbacks.onEnd then
            callbacks.onEnd()
        end
    end)
    return inside
end

-- The canonical name of a map, matched case-insensitively: a map read live from
-- Workspace (Studio) or a module under Shared/Maps. Lobby and Validate are not maps.
function MapService:FindMap(name)
    if type(name) ~= "string" then
        return nil
    end
    local lower = name:lower()
    for live in self.LiveMaps or {} do
        if live:lower() == lower then
            return live
        end
    end
    for _, m in ReplicatedStorage.Shared.Maps:GetChildren() do
        if m:IsA("ModuleScript") and m.Name:lower() == lower and m.Name ~= "Lobby" and m.Name ~= "Validate" then
            return m.Name
        end
    end
    return nil
end

-- The layout table for a map. A live map beats the saved module of the same name, so
-- Play always shows what is in the viewport.
function MapService:GetLayout(name)
    if self.LiveMaps and self.LiveMaps[name] then
        return self.LiveMaps[name]
    end
    local module = type(name) == "string" and ReplicatedStorage.Shared.Maps:FindFirstChild(name)
    if not module or not module:IsA("ModuleScript") then
        return nil, "unknown map " .. tostring(name)
    end
    -- A map module could have a mistake in it; that should not take the server down, so
    -- the caller can fall back to a map that works.
    local ok, layout = pcall(require, module)
    if not ok or type(layout) ~= "table" then
        return nil, ("%s failed to load: %s"):format(name, tostring(layout))
    end
    return layout
end

-- Rebuild the arena for a named map. Safe between matches.
function MapService:Load(name)
    local layout, why = self:GetLayout(name)
    if not layout then
        warn("[MapService] " .. tostring(why))
        return false
    end
    local built, failure = pcall(self.Build, self, layout)
    if not built then
        warn(("[MapService] %s failed to build: %s"):format(name, tostring(failure)))
        return false
    end
    self.CurrentMap = name
    if layout.Draft then
        -- The revision is the one tools/map.luau printed, so a designer can tell the build
        -- they just converted from an older one still synced.
        local text = layout.Revision == "live" and ("DRAFT %s · live from Studio"):format(name)
            or ("DRAFT %s · build %s"):format(name, tostring(layout.Revision))
        print("[MapAuthoring] " .. text)
        -- at server start nobody is here yet, and the toast would go nowhere
        if #Players:GetPlayers() > 0 then
            Knit.GetService("SafetyService").Client.Notice:FireAll(text)
        end
    end
    return true
end

local IGNORED_IN_WORKSPACE = { Baseplate = true, SpawnLocation = true, Map = true, Lobby = true }

-- In a Studio play session, an editable map in Workspace IS the map: it is read here,
-- with the same code the converter uses (Shared.MapAuthoring), and played as it stands.
-- No Save to File, no command, no Rojo round trip -- Stop, edit, Play again.
--
-- The play session is a copy, so the model and anything left loose beside it are
-- removed from it: loose pieces are not part of the map, and showing them would make
-- the test lie about what the saved map will contain.
--
-- Outside Studio nothing is read; a stray source is just removed.
function MapService:ReadLiveMaps()
    self.LiveMaps, self.LiveProblems, self.LooseRemoved = {}, {}, {}
    local sources = {}
    for _, inst in workspace:GetDescendants() do
        if inst:GetAttribute("MapSource") ~= nil then
            table.insert(sources, inst)
        end
    end
    if #sources == 0 then
        return
    end
    if not RunService:IsStudio() then
        for _, root in sources do
            root:Destroy()
        end
        return
    end
    for _, root in sources do
        if not root.Parent then
            continue
        end
        local name = tostring(root:GetAttribute("MapSource"))
        -- sky and terrain from the last conversion, if there was one; defaults otherwise
        local presentation = MapAuthoring.defaultPresentation()
        local saved = self:GetLayout(name)
        if saved and saved.Authored then
            for _, key in { "Terrain", "Palette", "Environment", "Seed" } do
                presentation[key] = saved[key]
            end
        end
        local layout, bake, errors, warnings = MapAuthoring.read(root, name, {
            Instance = Instance,
            Validate = Validate,
            presentation = presentation,
            revision = "live",
        })
        root:Destroy()
        for _, w in warnings do
            warn("[MapAuthoring] " .. w)
        end
        if #errors > 0 then
            warn(("[MapAuthoring] %s can't be played yet -- fix these and press Play again:"):format(name))
            for _, e in errors do
                warn("    " .. e)
            end
            self.LiveProblems[name] = errors
        else
            print(("[MapAuthoring] playing %s straight from Workspace"):format(name))
            self.LiveMaps[name] = layout
            LIVE_BAKES[name] = bake
        end
    end
    for _, child in workspace:GetChildren() do
        local keep = IGNORED_IN_WORKSPACE[child.Name]
            or child:IsA("Camera")
            or child:IsA("Terrain")
            or child:IsA("LuaSourceContainer")
            or Players:GetPlayerFromCharacter(child) ~= nil
        if not keep then
            table.insert(self.LooseRemoved, child.Name)
            child:Destroy()
        end
    end
    if #self.LooseRemoved > 0 then
        warn(
            ("[MapAuthoring] %d thing(s) were loose in Workspace, not inside the map, so they are not part of it "):format(
                #self.LooseRemoved
            )
                .. "and were left out of this test: "
                .. table.concat(self.LooseRemoved, ", ")
                .. ". Drag them into the map's Geometry folder to include them."
        )
    end
end

-- What a designer needs to hear on joining a Studio test with a map in Workspace.
function MapService:LiveNotice(player)
    local notice = Knit.GetService("SafetyService").Client.Notice
    for name, errors in self.LiveProblems or {} do
        notice:Fire(player, ("%s has %d problem(s) -- see the Output window"):format(name, #errors))
    end
    if self.ExploreMap then
        notice:Fire(
            player,
            ("Playing %s from Studio. /lobby for the lobby; the PRACTICE pad plays a match here"):format(
                self.ExploreMap
            )
        )
        if #(self.LooseRemoved or {}) > 0 then
            notice:Fire(player, ("%d loose piece(s) left out -- see Output"):format(#self.LooseRemoved))
        end
    end
end

function MapService:KnitInit()
    -- Tuning must exist before the first Build: the layout name and the safety switch both
    -- come from it, and Knit does not order KnitInit between services.
    Knit.GetService("TuningService"):EnsureSetup()

    self:ReadLiveMaps()
    local live = {}
    for name in self.LiveMaps do
        table.insert(live, name)
    end
    table.sort(live)
    local startup = live[1] or Config.StartupMap
    if not self:Load(startup) then
        warn("[MapService] falling back to " .. FALLBACK_MAP)
        self:Load(FALLBACK_MAP)
    elseif live[1] then
        self.ExploreMap = startup
    end
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
        if self.ExploreMap or next(self.LiveProblems) then
            task.delay(3, function()
                if player.Parent then
                    self:LiveNotice(player)
                end
            end)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, p in Players:GetPlayers() do
        watch(p)
    end
end

return MapService
