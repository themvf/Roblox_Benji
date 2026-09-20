-- Server-authorized, map-driven contextual traversal.
-- Maps own endpoints and route purpose; this service owns validation, prompts,
-- cooldowns, lifecycle, and the client-owned movement handshake.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TraversalService = Knit.CreateService({
    Name = "TraversalService",
    Client = {
        Travel = Knit.CreateSignal(), -- (routeId, target, speed, timeout, kind)
        Cancel = Knit.CreateSignal(), -- (routeId, reason)
        Notice = Knit.CreateSignal(), -- (text)
    },
})

local ACTIVATION_MARGIN = 3
local LANDING_TOLERANCE = 12
local DEFAULT_COOLDOWN = 3
local DEFAULT_ZIP_SPEED = 62
local DEFAULT_GRAPPLE_SPEED = 72

local function v3(value)
    return Vector3.new(value[1], value[2], value[3])
end

local function insideBounds(point, bounds)
    if not bounds then
        return true
    end
    local minimum, maximum = v3(bounds.min), v3(bounds.max)
    return point.X >= minimum.X
        and point.X <= maximum.X
        and point.Y >= minimum.Y
        and point.Y <= maximum.Y
        and point.Z >= minimum.Z
        and point.Z <= maximum.Z
end

local function routeLine(folder, name, from, to, color, thickness, transparency)
    local delta = to - from
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Metal
    part.Color = color
    part.Transparency = transparency or 0
    part.Size = Vector3.new(thickness, thickness, delta.Magnitude)
    part.CFrame = CFrame.lookAt((from + to) / 2, to)
    part.Parent = folder
    return part
end

local function endpoint(folder, name, position, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Shape = Enum.PartType.Cylinder
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Size = Vector3.new(0.5, 3.5, 3.5)
    part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    part.Parent = folder
    return part
end

function TraversalService:ClearPlayer(player, reason)
    local active = self.Active and self.Active[player]
    if not active then
        return
    end
    self.Active[player] = nil
    local character = player.Character
    if character then
        character:SetAttribute("TraversalState", nil)
        character:SetAttribute("TraversalId", nil)
    end
    self.Client.Cancel:Fire(player, active.Id, reason or "Canceled")
end

function TraversalService:Begin(player, route)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not player:GetAttribute("InMatch") or not humanoid or not root or humanoid.Health <= 0 then
        return
    end
    if self.Active[player] or character:GetAttribute("Launched") then
        self.Client.Notice:Fire(player, "Finish current movement first")
        return
    end
    if (root.Position - route.Start).Magnitude > route.ActivationDistance + ACTIVATION_MARGIN then
        return
    end
    if not insideBounds(route.Target, self.Layout and self.Layout.Bounds) then
        warn(("[Traversal] rejected %s: destination is outside map bounds"):format(route.Id))
        return
    end

    local now = os.clock()
    local cooldowns = self.Cooldowns[player]
    if not cooldowns then
        cooldowns = {}
        self.Cooldowns[player] = cooldowns
    end
    if now < (cooldowns[route.Id] or 0) then
        self.Client.Notice:Fire(player, "Route recharging")
        return
    end
    cooldowns[route.Id] = now + route.Cooldown

    local distance = (route.Target - root.Position).Magnitude
    local timeout = math.clamp(distance / route.Speed + 1.25, 1, 8)
    self.Active[player] = { Id = route.Id, Target = route.Target, Deadline = now + timeout }
    character:SetAttribute("TraversalState", route.Kind)
    character:SetAttribute("TraversalId", route.Id)
    self.Client.Travel:Fire(player, route.Id, route.Target, route.Speed, timeout, route.Kind)

    task.delay(timeout + 0.25, function()
        local active = self.Active and self.Active[player]
        if active and active.Id == route.Id then
            self:ClearPlayer(player, "TimedOut")
        end
    end)
end

function TraversalService.Client:Complete(player, routeId, outcome)
    local service = TraversalService
    local active = service.Active and service.Active[player]
    if not active or active.Id ~= routeId then
        return false
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local landed = outcome == "Landed" and root and (root.Position - active.Target).Magnitude <= LANDING_TOLERANCE
    service:ClearPlayer(player, landed and "Landed" or "Canceled")
    return landed == true
end

function TraversalService:AddRoute(folder, spec, kind, index)
    local id = spec.Id or (kind .. tostring(index))
    local start = v3(spec.From or spec.from or spec.pos)
    local target = v3(spec.To or spec.to or spec.destination)
    local speed = spec.speed or (kind == "ZipLine" and DEFAULT_ZIP_SPEED or DEFAULT_GRAPPLE_SPEED)
    local activationDistance = spec.activationDistance or 9
    local route = {
        Id = id,
        Kind = kind,
        Start = start,
        Target = target,
        Speed = math.clamp(speed, 20, 100),
        Cooldown = math.max(spec.cooldown or DEFAULT_COOLDOWN, 0.5),
        ActivationDistance = math.clamp(activationDistance, 5, 14),
    }

    local zip = kind == "ZipLine"
    local color = zip and Color3.fromRGB(80, 220, 240) or Color3.fromRGB(130, 230, 170)
    routeLine(folder, id .. "Cable", start, target, color, zip and 0.35 or 0.18, zip and 0 or 0.3)
    local startPart = endpoint(folder, id .. "Start", start, color)
    endpoint(folder, id .. "Landing", target, color)

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "TraversalPrompt"
    prompt.ActionText = zip and "RIDE ZIP" or "GRAPPLE"
    prompt.ObjectText = spec.name or (zip and "ZIP LINE" or "ANCHOR")
    prompt.KeyboardKeyCode = Enum.KeyCode.G
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = zip and 0.15 or 0
    prompt.MaxActivationDistance = route.ActivationDistance
    prompt.RequiresLineOfSight = true
    prompt.Parent = startPart
    prompt.Triggered:Connect(function(player)
        self:Begin(player, route)
    end)

    table.insert(self.Routes, route)
end

function TraversalService:Build(layout)
    self:Clear()
    self.Layout = layout
    self.Routes = {}
    self.Active = self.Active or {}
    self.Cooldowns = self.Cooldowns or {}

    local folder = Instance.new("Folder")
    folder.Name = "Traversal"
    folder.Parent = workspace
    self.Folder = folder

    for index, spec in layout.ZipLines or {} do
        self:AddRoute(folder, spec, "ZipLine", index)
    end
    for index, spec in layout.GrappleAnchors or {} do
        self:AddRoute(folder, spec, "Grapple", index)
    end
end

function TraversalService:Clear()
    if self.Active then
        for player in self.Active do
            self:ClearPlayer(player, "MapChanged")
        end
    end
    if self.Folder then
        self.Folder:Destroy()
        self.Folder = nil
    end
    self.Routes = {}
    self.Cooldowns = {}
    self.Layout = nil
end

function TraversalService:KnitStart()
    self.Active = self.Active or {}
    self.Cooldowns = self.Cooldowns or {}
    Players.PlayerRemoving:Connect(function(player)
        self.Active[player] = nil
        self.Cooldowns[player] = nil
    end)
    local function watch(player)
        local function watchCharacter(character)
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.Died:Connect(function()
                    self:ClearPlayer(player, "Died")
                end)
            end
        end
        player.CharacterAdded:Connect(watchCharacter)
        if player.Character then
            task.defer(watchCharacter, player.Character)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return TraversalService
