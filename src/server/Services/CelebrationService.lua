-- End-of-match celebrations: favourites, the 3 s choice window, the podium sequence
-- (props, effects, audio, reactive teammates, skip vote), all inside the 8 s cap.
-- Motion (emotes) and camera are played on clients from the data this service sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Celebrations = require(ReplicatedStorage.Shared.Celebrations)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local CelebrationService = Knit.CreateService({
    Name = "CelebrationService",
    Client = {
        Choose = Knit.CreateSignal(), -- (favorites: {id}, seconds) to each winner
        Start = Knit.CreateSignal(), -- (sequence) to every match participant
        End = Knit.CreateSignal(), -- () to every match participant
        SkipVotes = Knit.CreateSignal(), -- (votes, needed) to losers
    },
})

local PODIUM_ORIGIN = Vector3.new(0, 14, 0) -- above the arena centre
local SPOT_GAP = 6
local CAP = Celebrations.Validate.MAX_LENGTH

local TEAM_COLORS = {
    Red = Palette.Ui.Red,
    Blue = Palette.Ui.Blue,
}

local warned = {}
local function warnOnce(key, msg)
    if not warned[key] then
        warned[key] = true
        warn("[Celebrations] " .. msg)
    end
end

-- ===== favourites =====

local function parseFavorites(player)
    local raw = player:GetAttribute("CelebrationFavorites")
    local out = {}
    if type(raw) == "string" and raw ~= "" then
        for id in raw:gmatch("[^,]+") do
            if Celebrations.get(id) then
                table.insert(out, id)
            end
        end
    end
    if #out == 0 then
        out[1] = Celebrations.DEFAULT_ID
    end
    return out
end

function CelebrationService.Client:GetOptions(_player)
    local out = {}
    for _, c in Celebrations.all() do
        table.insert(
            out,
            { Id = c.Id, Tier = c.Tier, Name = c.Name, Concept = c.Concept, Length = c.Length, Flashing = c.Flashing }
        )
    end
    return out
end

function CelebrationService.Client:GetFavorites(player)
    return parseFavorites(player)
end

-- ids: ordered list, first = default; at most MAX_FAVORITES
function CelebrationService.Client:SetFavorites(player, ids)
    if type(ids) ~= "table" then
        return false
    end
    local clean = {}
    for _, id in ids do
        if type(id) == "string" and Celebrations.get(id) and not table.find(clean, id) then
            table.insert(clean, id)
        end
        if #clean >= Celebrations.MAX_FAVORITES then
            break
        end
    end
    player:SetAttribute("CelebrationFavorites", table.concat(clean, ","))
    return true
end

-- ===== choice window =====

local pending = {} -- [player] = chosen id during the window

function CelebrationService.Client:Pick(player, id)
    if pending[player] ~= nil and Celebrations.get(id) and table.find(parseFavorites(player), id) then
        pending[player] = id
        return true
    end
    return false
end

function CelebrationService.Client:ReducedEffects(player, on)
    player:SetAttribute("ReducedEffects", on and true or nil)
end

-- ===== podium props / effects / audio =====

local function spotColor(player)
    return TEAM_COLORS[player:GetAttribute("Team")] or Color3.fromRGB(255, 220, 80)
end

local function makePart(folder, name, cf, size, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Parent = folder
    return p
end

local function buildPodium(folder, count)
    local width = math.max(count, 1) * SPOT_GAP + 6
    local floor = makePart(
        folder,
        "PodiumFloor",
        CFrame.new(PODIUM_ORIGIN),
        Vector3.new(width, 1.5, 10),
        Color3.fromRGB(240, 236, 228)
    )
    floor.CanCollide = true
    floor.CanQuery = true
    local trim = makePart(
        folder,
        "PodiumTrim",
        CFrame.new(PODIUM_ORIGIN + Vector3.new(0, 0.85, 0)),
        Vector3.new(width + 0.4, 0.2, 10.4),
        Color3.fromRGB(255, 200, 70),
        Enum.Material.Neon
    )
    trim.Transparency = 0.2
    -- spots: left to right along +X, facing -Z (the results camera sits at -Z)
    local spots = {}
    for i = 1, count do
        local x = (i - (count + 1) / 2) * SPOT_GAP
        local pos = PODIUM_ORIGIN + Vector3.new(x, 0.75 + 0.15, 0)
        local pad = makePart(
            folder,
            "Spot" .. i,
            CFrame.new(pos),
            Vector3.new(4, 0.3, 4),
            Color3.fromRGB(255, 255, 255),
            Enum.Material.Neon
        )
        pad.Transparency = 0.5
        spots[i] = CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, -10))
    end
    return spots
end

local function spawnEffects(folder, spot, def, player, reduced)
    if reduced then
        return
    end
    local color = def.UseTeamColor and spotColor(player) or Color3.fromRGB(255, 220, 80)
    local anchor = makePart(folder, "FxAnchor", spot * CFrame.new(0, 4, 0), Vector3.new(1, 1, 1), color)
    anchor.Transparency = 1
    local att = Instance.new("Attachment")
    att.Parent = anchor
    local pe = Instance.new("ParticleEmitter")
    pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
    pe.Lifetime = NumberRange.new(1.2, 2.2)
    pe.Speed = NumberRange.new(8, 16)
    pe.SpreadAngle = Vector2.new(60, 60)
    pe.Rate = 0
    pe.Size = NumberSequence.new(0.35)
    pe.Transparency = NumberSequence.new(0, 1)
    pe.LightEmission = 0.6
    pe.Parent = att
    if def.Type == "Fireworks" then
        pe.Acceleration = Vector3.new(0, -8, 0)
        pe.Speed = NumberRange.new(20, 30)
        pe.SpreadAngle = Vector2.new(180, 180)
        task.spawn(function()
            for _ = 1, def.Bursts or 3 do
                pe:Emit(def.Count or 40)
                task.wait(1.1)
            end
        end)
    elseif def.Type == "Sparkle" then
        pe.Speed = NumberRange.new(2, 5)
        pe.Rate = 20
        task.delay(6, function()
            pe.Enabled = false
        end)
    else -- Confetti
        pe.Acceleration = Vector3.new(0, -12, 0)
        pe.Rotation = NumberRange.new(0, 360)
        pe.RotSpeed = NumberRange.new(-200, 200)
        pe:Emit(def.Count or 100)
    end
end

local function spawnProps(folder, spot, def, player, reduced)
    if reduced then
        return
    end
    local color = def.UseTeamColor and spotColor(player) or Color3.fromRGB(255, 220, 80)
    if def.Type == "Flag" then
        local base = spot * CFrame.new(2.5, -2.4, 0)
        local pole = makePart(
            folder,
            "FlagPole",
            base * CFrame.new(0, 3.5, 0),
            Vector3.new(0.25, 7, 0.25),
            Color3.fromRGB(230, 230, 235),
            Enum.Material.Metal
        )
        local flag = makePart(
            folder,
            "Flag",
            base * CFrame.new(1.4, 5.8, 0),
            Vector3.new(2.6, 1.6, 0.1),
            color,
            Enum.Material.Neon
        )
        Debris:AddItem(pole, def.DespawnAt)
        Debris:AddItem(flag, def.DespawnAt)
    elseif def.Type == "Weapon" then
        -- the player's primary tool, with its skin, floating above the spot
        local loadout = Knit.GetService("LoadoutService"):Get(player)
        local tools = ReplicatedStorage:FindFirstChild("WeaponTools")
        local template = tools and loadout.Primary and tools:FindFirstChild(loadout.Primary)
        local model = template and template:FindFirstChildOfClass("Model")
        if model then
            local tool = template:Clone()
            Knit.GetService("SkinService"):Apply(tool, player)
            local show = tool:FindFirstChildOfClass("Model"):Clone()
            tool:Destroy()
            for _, d in show:GetDescendants() do
                if d:IsA("BasePart") then
                    d.Anchored = true
                    d.CanCollide = false
                elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
                    d:Destroy()
                end
            end
            show:ScaleTo(1.8)
            show.Name = "PropWeapon"
            show:PivotTo(spot * CFrame.new(0, 4.5, 0))
            show.Parent = folder
            task.spawn(function()
                local t0 = os.clock()
                while show.Parent and os.clock() - t0 < def.DespawnAt do
                    show:PivotTo(
                        spot
                            * CFrame.new(0, 4.5 + math.sin((os.clock() - t0) * 2) * 0.3, 0)
                            * CFrame.Angles(0, (os.clock() - t0) * 1.2, 0)
                    )
                    task.wait()
                end
                show:Destroy()
            end)
        end
    end
end

local function playAudio(folder, spot, def, celId)
    local stingId = Uploads.resolve(def.Sting)
    if stingId then
        local anchor = makePart(folder, "Sting", spot, Vector3.new(1, 1, 1), Color3.new())
        anchor.Transparency = 1
        local s = Instance.new("Sound")
        s.SoundId = stingId
        s.Volume = 0.7
        s.RollOffMaxDistance = 120
        s.Parent = anchor
        s:Play()
        Debris:AddItem(anchor, CAP)
    else
        warnOnce(celId .. ":Audio", celId .. " sting not ready")
    end
end

-- ===== the sequence =====

-- winners: ordered by MVP first; losers: array. Returns when the sequence has ended.
function CelebrationService:Run(winners, losers)
    if #winners == 0 then
        return
    end
    -- Choice window: winners pick from favourites for 3 s
    for _, p in winners do
        pending[p] = false
        self.Client.Choose:Fire(p, parseFavorites(p), 3)
    end
    task.wait(3)
    local picks = {}
    for _, p in winners do
        local id = pending[p]
        pending[p] = nil
        if not id then
            id = parseFavorites(p)[1]
        end
        picks[p] = Celebrations.get(id) or Celebrations.get(Celebrations.DEFAULT_ID)
    end

    local folder = Instance.new("Folder")
    folder.Name = "Podium"
    folder.Parent = workspace
    local spots = buildPodium(folder, #winners)

    -- Place winners left to right in MVP order (podium order: MVP is index 1, stands leftmost)
    local mvp = winners[1]
    local mvpCel = picks[mvp]
    local sequence = { Spots = {}, MvpUserId = mvp.UserId, Duration = CAP, Focus = PODIUM_ORIGIN }
    for i, p in winners do
        local cel = picks[p]
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = spots[i]
            root.AssemblyLinearVelocity = Vector3.zero
        end
        -- MVP plays last so the camera holds on it for the final 3 s; teammates start at 0
        local startAt = (p == mvp) and math.max(0, CAP - cel.Length) or 0
        table.insert(sequence.Spots, {
            UserId = p.UserId,
            Celebration = cel.Id,
            StartAt = startAt,
            Length = cel.Length,
            Spot = spots[i],
            Reactive = (p ~= mvp and mvpCel.Systems.Reactive) and mvpCel.Systems.Reactive.Emote or nil,
        })
    end
    sequence.Camera = mvpCel.Systems.Camera
    sequence.MvpSpot = spots[1]

    -- Losers watch; freeze everyone in place
    local participants = {}
    for _, p in winners do
        table.insert(participants, p)
    end
    for _, p in losers do
        table.insert(participants, p)
    end
    for _, p in participants do
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
        end
        self.Client.Start:Fire(p, sequence)
    end

    -- Server-side systems on a timeline
    for _, entry in sequence.Spots do
        local p = Players:GetPlayerByUserId(entry.UserId)
        local cel = Celebrations.get(entry.Celebration)
        if p and cel then
            task.delay(entry.StartAt, function()
                local reduced = p:GetAttribute("ReducedEffects") == true
                local sys = cel.Systems
                if sys.Effects then
                    spawnEffects(folder, entry.Spot, sys.Effects, p, reduced)
                end
                if sys.Props then
                    spawnProps(folder, entry.Spot, sys.Props, p, reduced)
                end
                if sys.Audio then
                    playAudio(folder, entry.Spot, sys.Audio, cel.Id)
                end
            end)
        end
    end

    -- Skip vote: losers can end it early; three votes, or every loser when fewer than three
    self.SkipVoters = {}
    self.SkipNeeded = math.min(3, math.max(1, #losers))
    self.SkipAllowed = {}
    for _, p in losers do
        self.SkipAllowed[p] = true
    end
    local t0 = os.clock()
    while os.clock() - t0 < CAP do
        if self.SkipNeeded > 0 and self.SkipCount and self.SkipCount >= self.SkipNeeded then
            break
        end
        task.wait(0.1)
    end
    self.SkipAllowed = nil
    self.SkipCount = nil

    for _, p in participants do
        self.Client.End:Fire(p)
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
    end
    folder:Destroy()
end

function CelebrationService.Client:VoteSkip(player)
    local svc = self.Server
    if not svc.SkipAllowed or not svc.SkipAllowed[player] then
        return false
    end
    svc.SkipVoters = svc.SkipVoters or {}
    if svc.SkipVoters[player] then
        return true
    end
    svc.SkipVoters[player] = true
    svc.SkipCount = (svc.SkipCount or 0) + 1
    for p in svc.SkipAllowed do
        svc.Client.SkipVotes:Fire(p, svc.SkipCount, svc.SkipNeeded)
    end
    return true
end

return CelebrationService
