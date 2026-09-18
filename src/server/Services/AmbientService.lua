-- Living-world layer (Carrier spec S6, S7, S10, S15): overhead flyovers, a background fleet, and the
-- kraken set piece. Everything here is non-playable, lightweight, and staggered so nothing competes.
-- Layout data: layout.Flyovers = { Interval = {min,max}, Height, Sound }, layout.Fleet = { {pos, kind, heading} },
--              events with Kind = "Kraken" or Flyover = true (run by ConvergenceService via RunSignature).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local AmbientService = Knit.CreateService({
    Name = "AmbientService",
    Client = {
        Rumble = Knit.CreateSignal(), -- (strength, seconds) mild camera shake on clients
    },
})

local JET = Color3.fromRGB(96, 102, 112)
local SHIP = Color3.fromRGB(105, 112, 124)
local WAKE = Color3.fromRGB(220, 235, 245)

local function part(folder, name, cf, size, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CastShadow = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.Metal
    p.Parent = folder
    return p
end

-- low-detail jet for flyovers (5 parts)
local function jetModel(folder)
    local m = Instance.new("Model")
    m.Name = "Flyover"
    local body = part(m, "Body", CFrame.new(), Vector3.new(4, 3, 22), JET)
    part(m, "WingL", CFrame.new(-8, -0.4, 2), Vector3.new(12, 0.5, 8), JET)
    part(m, "WingR", CFrame.new(8, -0.4, 2), Vector3.new(12, 0.5, 8), JET)
    part(m, "Tail", CFrame.new(0, 2.8, 9), Vector3.new(0.5, 5, 5), JET)
    local burner = part(
        m,
        "Burner",
        CFrame.new(0, 0, 11.5),
        Vector3.new(1.6, 1.6, 1.5),
        Color3.fromRGB(255, 150, 60),
        Enum.Material.Neon
    )
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 150, 60)
    light.Range = 30
    light.Brightness = 2
    light.Parent = burner
    m.PrimaryPart = body
    m.Parent = folder
    return m
end

-- ===== S6 flyovers =====
function AmbientService:Flyover(opts)
    opts = opts or {}
    local folder = self.Folder
    if not folder then
        return
    end
    local size = (self.Layout and self.Layout.Size or 300)
    local height = opts.Height or (self.Layout and self.Layout.Flyovers and self.Layout.Flyovers.Height) or 90
    local low = opts.Low
    if low then
        height = 40
    end
    -- random crossing line over the map
    local angle = math.random() * math.pi * 2
    local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
    local from = -dir * (size * 1.2)
        + Vector3.new(0, height, 0)
        + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40))
    local to = dir * (size * 1.2) + Vector3.new(0, height, 0)
    local count = opts.Formation and 3 or 1
    for i = 1, count do
        local offset = (i - 2) * Vector3.new(-dir.Z, 0, dir.X) * 14 + Vector3.new(0, (i - 2) * 3, 0)
        local jet = jetModel(folder)
        jet:PivotTo(CFrame.lookAt(from + offset, to + offset))
        local speed = opts.Speed or 220
        local duration = (to - from).Magnitude / speed
        local tw = TweenService:Create(jet.PrimaryPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            CFrame = CFrame.lookAt(to + offset, to + offset + dir),
        })
        -- move the whole model with the primary part
        local conn
        conn = jet.PrimaryPart:GetPropertyChangedSignal("CFrame"):Connect(function()
            jet:PivotTo(jet.PrimaryPart.CFrame)
        end)
        tw:Play()
        -- moving shadow: flat dark disc on the deck under the jet
        local shadow = part(folder, "JetShadow", CFrame.new(), Vector3.new(14, 0.1, 22), Color3.new(0, 0, 0))
        shadow.Transparency = 0.6
        shadow.Material = Enum.Material.SmoothPlastic
        local deckY = (self.Layout and self.Layout.ShadowY) or 16.2
        local sc
        sc = jet.PrimaryPart:GetPropertyChangedSignal("CFrame"):Connect(function()
            local p = jet.PrimaryPart.Position
            shadow.CFrame = CFrame.new(p.X, deckY, p.Z) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
        end)
        Debris:AddItem(jet, duration + 0.5)
        Debris:AddItem(shadow, duration + 0.5)
        task.delay(duration + 0.5, function()
            conn:Disconnect()
            sc:Disconnect()
        end)
    end
    -- audio: build-up then pass
    local snd = Uploads.resolve(opts.Sound or (self.Layout and self.Layout.Flyovers and self.Layout.Flyovers.Sound))
    if snd then
        local anchor = part(folder, "FlyoverSound", CFrame.new(0, height, 0), Vector3.new(1, 1, 1), Color3.new())
        anchor.Transparency = 1
        local s = Instance.new("Sound")
        s.SoundId = snd
        s.Volume = low and 1 or 0.6
        s.RollOffMaxDistance = 600
        s.Parent = anchor
        s:Play()
        Debris:AddItem(anchor, 6)
    end
    if low then
        self.Client.Rumble:FireAll(0.6, 1.2)
    end
end

-- ===== S7 background fleet =====
local function shipModel(folder, kind)
    local m = Instance.new("Model")
    m.Name = kind
    local len = kind == "cruiser" and 180 or (kind == "supply" and 140 or 110)
    local hull = part(m, "Hull", CFrame.new(), Vector3.new(len, 14, 22), SHIP)
    part(m, "Super", CFrame.new(len * 0.05, 12, 0), Vector3.new(len * 0.35, 10, 14), Color3.fromRGB(125, 132, 145))
    part(m, "Mast", CFrame.new(len * 0.05, 26, 0), Vector3.new(2, 18, 2), Color3.fromRGB(125, 132, 145))
    if kind ~= "supply" then
        part(m, "Turret", CFrame.new(len * 0.3, 8.5, 0), Vector3.new(10, 3, 8), Color3.fromRGB(90, 96, 108))
        part(m, "Gun", CFrame.new(len * 0.3 + 8, 9, 0), Vector3.new(12, 0.8, 0.8), Color3.fromRGB(70, 74, 84))
    end
    local nav = part(
        m,
        "NavLight",
        CFrame.new(len * 0.05, 36, 0),
        Vector3.new(1, 1, 1),
        Color3.fromRGB(255, 60, 50),
        Enum.Material.Neon
    )
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 60, 50)
    light.Range = 40
    light.Parent = nav
    local dish = part(m, "Radar", CFrame.new(len * 0.05, 32, 0), Vector3.new(8, 0.5, 2), Color3.fromRGB(150, 156, 165))
    local wake = part(
        m,
        "Wake",
        CFrame.new(-len * 0.55, -6.5, 0),
        Vector3.new(len * 0.6, 0.2, 18),
        WAKE,
        Enum.Material.SmoothPlastic
    )
    wake.Transparency = 0.5
    m.PrimaryPart = hull
    m.Parent = folder
    -- radar rotation + nav blink, staggered per ship
    task.spawn(function()
        local phase = math.random() * 3
        while m.Parent do
            task.wait(0.1)
            dish.CFrame = dish.CFrame * CFrame.Angles(0, math.rad(9), 0)
            local t = os.clock() + phase
            nav.Transparency = (t % 2) < 1 and 0 or 0.9
        end
    end)
    return m
end

function AmbientService:BuildFleet(layout)
    for i, spec in layout.Fleet or {} do
        local m = shipModel(self.Folder, spec.kind or "escort")
        local pos = Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3])
        local heading = math.rad(spec.heading or 0)
        m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, heading, 0))
        -- slow drift along heading, then back, over minutes (no physics)
        task.spawn(function()
            local dir = (CFrame.Angles(0, heading, 0) * CFrame.new(1, 0, 0)).Position
            local t0 = os.clock() + i * 7
            while m.Parent do
                task.wait(0.2)
                local t = os.clock() - t0
                local drift = math.sin(t / 60) * 60
                local bob = math.sin(t * 0.8 + i) * 0.4
                m:PivotTo(
                    CFrame.new(pos + dir * drift + Vector3.new(0, bob, 0))
                        * CFrame.Angles(0, heading, math.rad(math.sin(t * 0.6 + i) * 1.2))
                )
            end
        end)
    end
end

-- ===== S10 kraken =====
function AmbientService:Kraken(event)
    local folder = self.Folder
    if not folder then
        return
    end
    local origin = event.Origin and Vector3.new(event.Origin[1], event.Origin[2], event.Origin[3])
        or Vector3.new(0, -30, -220)
    local seaY = origin.Y
    local duration = event.DurationSeconds or 12

    -- churn: rings of white water + spray particles
    local churn = part(
        folder,
        "Churn",
        CFrame.new(origin.X, seaY + 0.3, origin.Z) * CFrame.Angles(0, 0, math.rad(90)),
        Vector3.new(0.4, 70, 70),
        WAKE,
        Enum.Material.SmoothPlastic
    )
    churn.Shape = Enum.PartType.Cylinder
    churn.Transparency = 0.5
    local att = Instance.new("Attachment")
    att.Parent = churn
    local spray = Instance.new("ParticleEmitter")
    spray.Color = ColorSequence.new(Color3.new(1, 1, 1))
    spray.Size = NumberSequence.new(3, 0.5)
    spray.Transparency = NumberSequence.new(0.3, 1)
    spray.Lifetime = NumberRange.new(1.5, 2.5)
    spray.Speed = NumberRange.new(20, 35)
    spray.SpreadAngle = Vector2.new(50, 50)
    spray.Rate = 60
    spray.Parent = att
    -- low-frequency cue
    local snd = Uploads.resolve(event.Sound)
    if snd then
        local s = Instance.new("Sound")
        s.SoundId = snd
        s.Volume = 1
        s.RollOffMaxDistance = 900
        s.Parent = churn
        s:Play()
    end
    self.Client.Rumble:FireAll(0.4, 2.5)

    -- tentacle: stacked tapering segments, rises, curls, descends
    local tent = Instance.new("Model")
    tent.Name = "Kraken"
    local segs = {}
    local height = event.Height or 120
    local n = 9
    for i = 1, n do
        local w = 18 - i * 1.6
        local seg = part(
            tent,
            "Seg" .. i,
            CFrame.new(),
            Vector3.new(w, height / n + 1, w),
            Color3.fromRGB(70, 30, 60),
            Enum.Material.SmoothPlastic
        )
        seg.Shape = Enum.PartType.Cylinder
        segs[i] = seg
        if i % 2 == 0 then
            local sucker = part(
                tent,
                "Sucker" .. i,
                CFrame.new(),
                Vector3.new(w * 0.35, w * 0.35, 1),
                Color3.fromRGB(200, 120, 150),
                Enum.Material.SmoothPlastic
            )
            sucker.Shape = Enum.PartType.Ball
            seg:SetAttribute("Sucker", sucker.Name)
        end
    end
    tent.Parent = folder

    local function pose(rise, curl)
        -- rise: 0..1 how far out of the water; curl: bend angle at the tip
        local cf = CFrame.new(origin.X, seaY - height + rise * height, origin.Z)
        for i, seg in segs do
            local bend = curl * (i / n) ^ 2
            cf = cf * CFrame.new(0, height / n / 2, 0)
            seg.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
            local sucker = tent:FindFirstChild("Sucker" .. i)
            if sucker then
                sucker.CFrame = cf * CFrame.new(seg.Size.X / 2, 0, 0)
            end
            cf = cf * CFrame.new(0, height / n / 2, 0) * CFrame.Angles(math.rad(bend), 0, 0)
        end
    end

    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < duration do
            local t = (os.clock() - t0) / duration
            local rise = math.sin(t * math.pi) -- up then down
            local curl = math.sin(t * math.pi * 2) * 18 + 10
            pose(rise, curl)
            task.wait()
        end
        tent:Destroy()
        spray.Enabled = false
        task.delay(3, function()
            churn:Destroy()
        end)
    end)
end

-- ===== build / lifecycle =====
function AmbientService:Build(layout)
    self:Clear()
    self.Layout = layout
    local folder = Instance.new("Folder")
    folder.Name = "Ambient"
    folder.Parent = workspace
    self.Folder = folder
    self:BuildFleet(layout)
    -- flyover scheduler
    if layout.Flyovers then
        local interval = layout.Flyovers.Interval or { 30, 60 }
        self.FlyoverThread = task.spawn(function()
            task.wait(8)
            while self.Folder == folder do
                self:Flyover({ Formation = math.random() < 0.3, Low = math.random() < 0.25 })
                task.wait(interval[1] + math.random() * (interval[2] - interval[1]))
            end
        end)
    end
end

function AmbientService:Clear()
    if self.Folder then
        self.Folder:Destroy()
        self.Folder = nil
    end
    self.Layout = nil
end

return AmbientService
