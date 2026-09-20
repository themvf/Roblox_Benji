-- MutationService: energy, activation, mutant state, duration, reversion, telemetry.
-- Energy is server-authoritative and per match; the client only sees the MutationEnergy attribute
-- and may request activation. Transformation scales the rig, tints it, announces, and reverts on
-- expiry or death. Ability cooldowns live in AbilityService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AlterEgos = require(ReplicatedStorage.Shared.AlterEgos)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local MutationService = Knit.CreateService({
    Name = "MutationService",
    Client = {
        Announce = Knit.CreateSignal(), -- (text, playerName) to everyone in the match
        Ready = Knit.CreateSignal(), -- () to the player whose meter just filled
    },
})

local states = {} -- [player] = PlayerMutationState + telemetry
local matchPlayers = nil
local matchStartedAt = nil

local function now()
    return os.clock()
end

local function newState(player)
    local egoId = Knit.GetService("AlterEgoService"):Get(player)
    return {
        AlterEgoId = egoId,
        Energy = 0,
        IsMutated = false,
        MutationEndsAt = 0,
        DefenseAccum = 0,
        Telemetry = {
            EnergyBySource = {},
            Activations = 0,
            FirstMutationAt = nil,
            ActivationTimes = {},
            MutantKills = 0,
            MutantDeaths = 0,
            ObjectiveWhileMutated = 0,
            SurvivalTimes = {},
            ReachedFullAt = nil,
            ReachedFullNeverActivated = false,
        },
    }
end

function MutationService:State(player)
    return states[player]
end

-- ===== energy =====
function MutationService:AddEnergy(player, source, amount)
    local st = states[player]
    if not st or st.IsMutated or not matchPlayers then
        return
    end
    local before = st.Energy
    st.Energy = math.min(AlterEgos.Energy.Cap, st.Energy + amount)
    st.Telemetry.EnergyBySource[source] = (st.Telemetry.EnergyBySource[source] or 0) + (st.Energy - before)
    player:SetAttribute("MutationEnergy", st.Energy)
    if before < AlterEgos.Energy.Cap and st.Energy >= AlterEgos.Energy.Cap then
        st.Telemetry.ReachedFullAt = now()
        self.Client.Ready:Fire(player)
    end
end

-- objective score earned while mutated (telemetry)
function MutationService:NoteObjective(player, points)
    local st = states[player]
    if st and st.IsMutated then
        st.Telemetry.ObjectiveWhileMutated += points
    end
end

-- called by StatsService.Tick with seconds inside an owned zone this tick
function MutationService:DefenseTime(player, dt)
    local st = states[player]
    if not st then
        return
    end
    st.DefenseAccum += dt
    if st.DefenseAccum >= AlterEgos.Energy.DefenseTickSeconds then
        st.DefenseAccum -= AlterEgos.Energy.DefenseTickSeconds
        self:AddEnergy(player, "DefenseTick", AlterEgos.Energy.DefenseTick)
    end
end

-- ===== transformation =====
local function setScale(character, scale)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    for _, name in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" } do
        local v = hum:FindFirstChild(name)
        if v then
            TweenService
                :Create(v, TweenInfo.new(AlterEgos.Mutation.TransformSeconds, Enum.EasingStyle.Back), { Value = scale })
                :Play()
        end
    end
end

local function playSound(parent, ref, volume)
    local id = Uploads.resolve(ref)
    if not id then
        return
    end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 1
    s.RollOffMaxDistance = 150
    s.Parent = parent
    s:Play()
    Debris:AddItem(s, 5)
end

local function fx(character, color)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local att = Instance.new("Attachment")
    att.Parent = root
    local pe = Instance.new("ParticleEmitter")
    pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
    pe.Size = NumberSequence.new(1.2, 0)
    pe.Lifetime = NumberRange.new(0.6, 1.0)
    pe.Speed = NumberRange.new(14, 22)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.LightEmission = 1
    pe.Rate = 0
    pe.Parent = att
    pe:Emit(80)
    Debris:AddItem(att, 2)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 24
    light.Brightness = 3
    light.Parent = root
    Debris:AddItem(light, 1.5)
end

function MutationService:Revert(player, reason)
    local st = states[player]
    if not st or not st.IsMutated then
        return
    end
    st.IsMutated = false
    st.MutationEndsAt = 0
    player:SetAttribute("Mutated", nil)
    player:SetAttribute("MutationEndsAt", nil)
    local character = player.Character
    if character then
        setScale(character, 1)
        local hl = character:FindFirstChild("MutantGlow")
        if hl then
            hl:Destroy()
        end
        local core = character:FindFirstChild("MutantCore")
        if core then
            core:Destroy()
        end
        fx(character, Color3.fromRGB(200, 200, 220))
    end
    if st.MutatedAt then
        table.insert(st.Telemetry.SurvivalTimes, now() - st.MutatedAt)
    end
    Knit.GetService("AbilityService"):OnRevert(player)
    self.Client.Announce:FireAll(("%s reverted (%s)"):format(player.Name, reason), player.Name)
end

function MutationService:Transform(player)
    local st = states[player]
    local ego = AlterEgos.get(st.AlterEgoId)
    local character = player.Character
    st.IsMutated = true
    st.Energy = 0
    st.MutatedAt = now()
    st.MutationEndsAt = now() + AlterEgos.Mutation.DurationSeconds
    st.Telemetry.Activations += 1
    st.Telemetry.FirstMutationAt = st.Telemetry.FirstMutationAt or (now() - (matchStartedAt or now()))
    table.insert(st.Telemetry.ActivationTimes, now() - (matchStartedAt or now()))
    st.Telemetry.ReachedFullAt = nil
    player:SetAttribute("MutationEnergy", 0)
    player:SetAttribute("Mutated", ego.Mutant)
    player:SetAttribute("MutationEndsAt", workspace:GetServerTimeNow() + AlterEgos.Mutation.DurationSeconds)

    setScale(character, ego.Scale)
    fx(character, ego.Color)
    playSound(character:FindFirstChild("HumanoidRootPart") or character, "upload:Mutate", 1)
    -- The fill carries the ALTER EGO identity, the outline carries the TEAM. ReadabilityService
    -- stands its team outline down while MutantGlow exists (two Highlights on one model fight),
    -- so without this a mutated player lost all team colour -- and with one alter ego in the
    -- roster both teams' mutants were the same orange. One Highlight, both facts.
    local TEAM_TINT = { Red = Color3.fromRGB(255, 70, 70), Blue = Color3.fromRGB(70, 140, 255) }
    local hl = Instance.new("Highlight")
    hl.Name = "MutantGlow"
    hl.FillColor = ego.Color
    hl.FillTransparency = 0.75
    hl.OutlineColor = TEAM_TINT[player:GetAttribute("Team")] or ego.Color
    hl.OutlineTransparency = 0
    hl.Parent = character
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if torso then
        local core = Instance.new("Part")
        core.Name = "MutantCore"
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(1.2, 1.2, 1.2)
        core.Material = Enum.Material.Neon
        core.Color = ego.Color
        core.CanCollide = false
        core.Massless = true
        local weld = Instance.new("Weld")
        weld.Part0 = torso
        weld.Part1 = core
        weld.C0 = CFrame.new(0, 0.2, -0.6)
        weld.Parent = core
        core.Parent = character
    end
    self.Client.Announce:FireAll(ego.Announce, player.Name)
    Knit.GetService("AbilityService"):OnMutate(player, ego)

    task.delay(AlterEgos.Mutation.DurationSeconds, function()
        if st.IsMutated and st.MutationEndsAt <= now() + 0.05 then
            self:Revert(player, "timer")
        end
    end)
end

-- Server validation of a manual activation (spec: dead, respawning, already mutated, match ended, invalid state)
function MutationService.Client:Activate(player)
    local st = states[player]
    if not st or not matchPlayers or not table.find(matchPlayers, player) then
        return false, "no match"
    end
    if st.IsMutated then
        return false, "already mutated"
    end
    if st.Energy < AlterEgos.Energy.Cap then
        return false, "not ready"
    end
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or not player:GetAttribute("InMatch") then
        return false, "invalid state"
    end
    MutationService:Transform(player)
    return true
end

-- ===== match lifecycle (called by ConvergenceService) =====
function MutationService:StartMatch(players)
    matchPlayers = players
    matchStartedAt = now()
    states = {}
    for _, p in players do
        states[p] = newState(p)
        p:SetAttribute("MutationEnergy", 0)
        p:SetAttribute("Mutated", nil)
        p:SetAttribute("MutationEndsAt", nil)
    end
end

function MutationService:OnDeath(player)
    local st = states[player]
    if st and st.IsMutated then
        st.Telemetry.MutantDeaths += 1
        self:Revert(player, "death")
    end
end

function MutationService:OnKill(killer, victimHadBounty)
    local st = states[killer]
    if not st then
        return
    end
    if st.IsMutated then
        st.Telemetry.MutantKills += 1
    end
    self:AddEnergy(killer, "Kill", AlterEgos.Energy.Kill)
    if victimHadBounty then
        self:AddEnergy(killer, "BountyKill", AlterEgos.Energy.BountyKill)
    end
end

function MutationService:Report()
    local lines = { "=== MUTATION REPORT ===" }
    for p, st in states do
        local tm = st.Telemetry
        if tm.ReachedFullAt and not st.IsMutated and st.Energy >= AlterEgos.Energy.Cap then
            tm.ReachedFullNeverActivated = true
        end
        local src = {}
        for k, v in tm.EnergyBySource do
            table.insert(src, ("%s %d"):format(k, v))
        end
        table.sort(src)
        local surv = 0
        for _, s in tm.SurvivalTimes do
            surv += s
        end
        local abil = Knit.GetService("AbilityService"):TelemetryFor(p)
        table.insert(
            lines,
            ("%-14s ego %s | energy by source: %s | first mutation %s | activations %d at [%s] | mutant K%d D%d | obj while mutated %d | avg survival %.1fs | never activated %s | abilities %s"):format(
                p.Name,
                st.AlterEgoId,
                table.concat(src, ", "),
                tm.FirstMutationAt and ("%.0fs"):format(tm.FirstMutationAt) or "never",
                tm.Activations,
                (function()
                    local t = {}
                    for _, v in tm.ActivationTimes do
                        table.insert(t, ("%.0f"):format(v))
                    end
                    return table.concat(t, ",")
                end)(),
                tm.MutantKills,
                tm.MutantDeaths,
                math.floor(tm.ObjectiveWhileMutated),
                #tm.SurvivalTimes > 0 and surv / #tm.SurvivalTimes or 0,
                tostring(tm.ReachedFullNeverActivated),
                abil
            )
        )
    end
    print(table.concat(lines, "\n"))
end

function MutationService:EndMatch()
    for p, st in states do
        if st.IsMutated then
            self:Revert(p, "match end")
        end
        p:SetAttribute("MutationActivations", st.Telemetry.Activations)
        p:SetAttribute("MutantKills", st.Telemetry.MutantKills)
        p:SetAttribute("ObjectiveWhileMutated", math.floor(st.Telemetry.ObjectiveWhileMutated))
    end
    self:Report()
    matchPlayers = nil
end

function MutationService:KnitStart()
    Players.PlayerRemoving:Connect(function(p)
        states[p] = nil
    end)
end

return MutationService
