-- Server-authorized walk-up mounted guns. Map data chooses sites; the imported art is
-- a Rojo-backed template, and only this service owns occupancy, aim and damage.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local TurretService = Knit.CreateService({
    Name = "TurretService",
    Client = {
        Entered = Knit.CreateSignal(), -- model
        Left = Knit.CreateSignal(), -- reason
    },
})

local SOURCE_FORWARD = Vector3.new(-0.771, 0, 0.637).Unit
local SOURCE_FRAME = CFrame.lookAt(Vector3.zero, SOURCE_FORWARD)
local turrets = {}
local operating = {} -- [player] = turret state

local function v3(values)
    return Vector3.new(values[1], values[2], values[3])
end

local function aliveCharacter(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return nil
    end
    return character, root, humanoid
end

local function finiteDirection(value)
    if typeof(value) ~= "Vector3" then
        return nil
    end
    for _, number in { value.X, value.Y, value.Z } do
        if number ~= number or math.abs(number) == math.huge then
            return nil
        end
    end
    if value.Magnitude < 0.9 or value.Magnitude > 1.1 then
        return nil
    end
    return value.Unit
end

local function legalAim(state, direction, config)
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude < 0.1 then
        return false
    end
    flat = flat.Unit
    local yaw = math.deg(math.atan2(state.forward:Cross(flat).Y, state.forward:Dot(flat)))
    local pitch = math.deg(math.atan2(direction.Y, math.sqrt(direction.X ^ 2 + direction.Z ^ 2)))
    return math.abs(yaw) <= config.MaxYawDegrees and pitch >= config.MinPitchDegrees and pitch <= config.MaxPitchDegrees
end

local function validOperator(player, state)
    if not state or not state.model.Parent or state.operator ~= player then
        return false
    end
    if not player:GetAttribute("InMatch") or player:GetAttribute("Team") ~= state.team then
        return false
    end
    local _, root = aliveCharacter(player)
    return root ~= nil and (root.Position - state.usePoint.Position).Magnitude <= Config.GetTurret().OperatorDistance
end

function TurretService:Exit(player, reason)
    local state = operating[player]
    if not state then
        return false
    end
    operating[player] = nil
    if state.operator == player then
        state.operator = nil
        if state.model.Parent then
            state.model:SetAttribute("OperatorId", nil)
        end
        if state.prompt.Parent then
            state.prompt.ActionText = "Operate"
        end
    end
    self.Client.Left:Fire(player, reason or "exited")
    return true
end

function TurretService:Enter(player, state)
    if state.operator then
        if state.operator == player then
            return self:Exit(player)
        end
        return false
    end
    if operating[player] then
        self:Exit(player, "switched")
    end
    if not player:GetAttribute("InMatch") or player:GetAttribute("Team") ~= state.team then
        return false
    end
    local _, root, humanoid = aliveCharacter(player)
    if not root or (root.Position - state.usePoint.Position).Magnitude > Config.GetTurret().OperatorDistance then
        return false
    end
    humanoid:UnequipTools()
    state.operator = player
    operating[player] = state
    state.model:SetAttribute("OperatorId", player.UserId)
    state.prompt.ActionText = "Leave"
    self.Client.Entered:Fire(player, state.model)
    return true
end

function TurretService:Build(layout, mapFolder)
    for player in operating do
        self:Exit(player, "map changed")
    end
    table.clear(turrets)
    if not layout.Turrets or #layout.Turrets == 0 then
        return
    end
    local art = ServerStorage:FindFirstChild("EnvironmentArt")
    local template = art and art:FindFirstChild("DoubleLedgeTurret")
    if not template then
        warn("[TurretService] DoubleLedgeTurret template is missing from ServerStorage.EnvironmentArt")
        return
    end
    local container = Instance.new("Folder")
    container.Name = "Turrets"
    container.Parent = mapFolder
    for _, site in layout.Turrets do
        local position = v3(site.pos)
        local forward = v3(site.facing).Unit
        local model = template:Clone()
        model.Name = site.Id
        model:SetAttribute("Team", site.Team)
        model:SetAttribute("Ammo", Config.GetTurret().Magazine)
        model:SetAttribute("Magazine", Config.GetTurret().Magazine)
        model.Parent = container
        local orientation = CFrame.lookAt(Vector3.zero, forward) * SOURCE_FRAME:Inverse()
        model:PivotTo(CFrame.new(position) * orientation)
        local head = model:FindFirstChild("Head")
        local usePoint = model:FindFirstChild("UsePoint")
        local muzzle = head and head:FindFirstChild("Muzzle")
        assert(head and head:IsA("Model") and head.PrimaryPart and usePoint and muzzle, "Turret template is incomplete")
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "OperateTurret"
        prompt.ActionText = "Operate"
        prompt.ObjectText = "Double Ledge LMG (" .. site.Team .. ")"
        prompt.HoldDuration = 0.35
        prompt.MaxActivationDistance = 9
        prompt.RequiresLineOfSight = false
        prompt.Parent = usePoint
        local state = {
            model = model,
            head = head,
            muzzle = muzzle,
            usePoint = usePoint,
            prompt = prompt,
            team = site.Team,
            forward = forward,
            mountPosition = head.PrimaryPart.Position,
            ammo = Config.GetTurret().Magazine,
            lastFire = 0,
            lastAim = 0,
            reloadUntil = 0,
        }
        prompt.Triggered:Connect(function(player)
            self:Enter(player, state)
        end)
        table.insert(turrets, state)
    end
end

function TurretService:UpdateAim(player, direction)
    local state = operating[player]
    if not validOperator(player, state) then
        self:Exit(player, "out of range")
        return false
    end
    direction = finiteDirection(direction)
    local config = Config.GetTurret()
    if not direction or not legalAim(state, direction, config) then
        return false
    end
    local now = os.clock()
    if now - state.lastAim < 0.05 then
        return true
    end
    state.lastAim = now
    local orientation = CFrame.lookAt(Vector3.zero, direction) * SOURCE_FRAME:Inverse()
    state.head:PivotTo(CFrame.new(state.mountPosition) * orientation)
    return true
end

local function drawTracer(origin, finish)
    local delta = finish - origin
    local tracer = Instance.new("Part")
    tracer.Name = "TurretTracer"
    tracer.Anchored = true
    tracer.CanCollide = false
    tracer.CanTouch = false
    tracer.CanQuery = false
    tracer.Material = Enum.Material.Neon
    tracer.Color = Color3.fromRGB(255, 183, 79)
    tracer.Size = Vector3.new(0.08, 0.08, delta.Magnitude)
    tracer.CFrame = CFrame.lookAt((origin + finish) / 2, finish)
    tracer.Parent = workspace
    Debris:AddItem(tracer, 0.08)
end

function TurretService:Fire(player, direction)
    local state = operating[player]
    if not validOperator(player, state) then
        self:Exit(player, "out of range")
        return false
    end
    direction = finiteDirection(direction)
    local config = Config.GetTurret()
    if not direction or not legalAim(state, direction, config) then
        return false
    end
    local now = os.clock()
    if now - state.lastFire < 1 / config.FireRate then
        return false
    end
    if state.reloadUntil > 0 then
        if now < state.reloadUntil then
            return false
        end
        state.reloadUntil = 0
        state.ammo = config.Magazine
        state.model:SetAttribute("Ammo", state.ammo)
        state.model:SetAttribute("ReloadUntil", nil)
    end
    if state.ammo <= 0 then
        return false
    end
    self:UpdateAim(player, direction)
    state.lastFire = now
    state.ammo -= 1
    state.model:SetAttribute("Ammo", state.ammo)

    local origin = state.muzzle.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { state.model, player.Character }
    local hit = workspace:Raycast(origin, direction * config.Range, rayParams)
    drawTracer(origin, hit and hit.Position or origin + direction * config.Range)
    if hit then
        local target = hit.Instance:FindFirstAncestorOfClass("Model")
        local humanoid = target and target:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 and target ~= player.Character then
            local victimPlayer = Players:GetPlayerFromCharacter(target)
            local victimTeam = victimPlayer and victimPlayer:GetAttribute("Team") or target:GetAttribute("Team")
            if victimTeam ~= state.team then
                target:SetAttribute("LastHitBy", player.UserId)
                target:SetAttribute("LastHitByName", player.Name)
                target:SetAttribute("LastHitAt", os.clock())
                local damage = Knit.GetService("AbilityService"):ApplyBrace(target, origin, config.Damage)
                Knit.GetService("StatsService"):OnDamage(player, target, math.min(damage, humanoid.Health))
                humanoid:TakeDamage(damage)
            end
        end
    end
    if state.ammo == 0 then
        state.reloadUntil = now + config.ReloadSeconds
        state.model:SetAttribute("ReloadUntil", state.reloadUntil)
        task.delay(config.ReloadSeconds, function()
            if state.model.Parent and state.reloadUntil > 0 and os.clock() >= state.reloadUntil then
                state.reloadUntil = 0
                state.ammo = Config.GetTurret().Magazine
                state.model:SetAttribute("Ammo", state.ammo)
                state.model:SetAttribute("ReloadUntil", nil)
            end
        end)
    end
    return true
end

function TurretService.Client:Exit(player)
    return TurretService:Exit(player)
end

function TurretService.Client:Aim(player, direction)
    return TurretService:UpdateAim(player, direction)
end

function TurretService.Client:Fire(player, direction)
    return TurretService:Fire(player, direction)
end

function TurretService:KnitStart()
    local elapsed = 0
    RunService.Heartbeat:Connect(function(delta)
        elapsed += delta
        if elapsed < 0.25 then
            return
        end
        elapsed = 0
        for player, state in operating do
            if not validOperator(player, state) then
                self:Exit(player, "out of range")
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        self:Exit(player, "left game")
    end)
end

return TurretService
