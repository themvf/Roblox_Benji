-- Sprint, crouch and slide, Rivals-style.
--
--   Sprint  hold Shift | click the left stick (toggle) | automatic on touch
--   Crouch  hold Ctrl or C | hold B | CROUCH button (toggle)
--   Slide   crouch while sprinting: a burst that fades to crouch speed over SlideSeconds
--
-- The character is client-owned, so this controller moves it: it is the only writer of
-- the local player's WalkSpeed, combining the stance with every server speed effect
-- (Shared/Movement). The Weapons Kit's own sprint and aim-slow are switched off in its
-- Configuration (tools/build_weapons.luau) and reproduced here with the same numbers, so
-- the two no longer fight over WalkSpeed every frame. The server owns the replicated
-- `Stance` attribute and the slide cooldown (MovementService).
--
-- Crouching and sliding lower the character (HipHeight) and bend the legs. The bend is
-- procedural -- joint transforms layered over whatever animation is playing -- because
-- custom animations need uploaded ids; every client poses every character from its
-- `Stance`, so opponents see it too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Movement = require(ReplicatedStorage.Shared.Movement)

local MovementController = Knit.CreateController({ Name = "MovementController" })

local SPRINT_KEYS = { [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true }
local CROUCH_KEYS = { [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.C] = true, [Enum.KeyCode.ButtonB] = true }
local SPRINT_TOGGLE = Enum.KeyCode.ButtonL3

-- How far down each stance sits, as a fraction of the character's normal HipHeight.
local HIP = { Crouch = 0.55, Slide = 0.35 }

-- Joint bends in degrees about each joint's X axis (R15). Positive at the hip swings the
-- thigh forward. These are a first pass that needs a look in Studio; flip a sign here if
-- a leg bends the wrong way.
local POSE = {
    Crouch = {
        LeftHip = 55,
        RightHip = 55,
        LeftKnee = -90,
        RightKnee = -90,
        LeftAnkle = 35,
        RightAnkle = 35,
        Waist = 12,
    },
    Slide = { LeftHip = 80, RightHip = 70, LeftKnee = -15, RightKnee = -70, Waist = -25 },
}

MovementController.Stance = nil -- nil (walking), "Sprint", "Crouch" or "Slide"
MovementController.SlideReadyAt = 0 -- os.clock() when the next slide is allowed

local held = { sprint = false, crouch = false }
local toggles = { sprint = false, crouch = false } -- controller sprint, touch crouch
local slide = nil -- { Started, Dir }
local crouchPressed = false -- a crouch press waiting to become a slide
-- HipHeight while standing, captured when a crouch or slide begins and put back when it
-- ends. HipHeight is left alone the rest of the time: a Titan mutation rescales the
-- character, and writing a remembered value back every frame would undo it.
local standingHip = setmetatable({}, { __mode = "k" }) -- [humanoid] = HipHeight
local sentStance = nil

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

local function settings()
    return Movement.settings(Config.Movement, tuning())
end

-- The Weapons Kit's camera knows whether the player is aiming down sights.
local kitCamera = nil
local function aiming()
    if not kitCamera then
        local folder = ReplicatedStorage:FindFirstChild("WeaponsSystem")
        local module = folder and folder:FindFirstChild("WeaponsSystem")
        if module then
            local ok, system = pcall(require, module)
            kitCamera = ok and system and system.camera or nil
        end
    end
    return kitCamera ~= nil and kitCamera.enabled == true and kitCamera.zoomState == true
end

local function isTouch()
    return Knit.GetController("TouchController").IsTouch()
end

-- Things that own the character's movement while they last: no sprint, crouch or slide.
local function blocked(character)
    return character:GetAttribute("Charging") ~= nil
        or character:GetAttribute("Launched") ~= nil
        or character:GetAttribute("TraversalState") ~= nil
        or character:GetAttribute(Movement.PREFIX .. "Celebration") == 0
end

local function send(stance)
    if stance ~= sentStance then
        sentStance = stance
        Knit.GetService("MovementService").Stance:Fire(stance)
    end
end

-- Touch CROUCH button: slide if sprinting, otherwise toggle crouch.
function MovementController:TouchCrouch()
    if self.Stance == "Sprint" then
        crouchPressed = true
    else
        toggles.crouch = not toggles.crouch
    end
end

function MovementController:CanSlide()
    return self.Stance == "Sprint" and os.clock() >= self.SlideReadyAt
end

function MovementController:Step()
    local me = Players.LocalPlayer
    local character = me.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then
        self.Stance, slide, crouchPressed = nil, nil, false
        return
    end

    local s = settings()
    local now = os.clock()
    local mods = Movement.modifiers(character)
    local aim = aiming()
    local mutated = me:GetAttribute("Mutated") ~= nil
    local stop = blocked(character)
    local moving = hum.MoveDirection.Magnitude > 0.1
    local grounded = hum.FloorMaterial ~= Enum.Material.Air
    local auto = if isTouch() then s.AutoSprintTouch else s.AutoSprintDesktop
    local wantSprint = (held.sprint or toggles.sprint or auto) and moving and not aim
    local wantCrouch = (held.crouch or toggles.crouch) and not mutated

    local stance
    if stop then
        slide = nil
        stance = nil
    elseif slide then
        local t = now - slide.Started
        local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        local jumped = hum.Jump or hum:GetState() == Enum.HumanoidStateType.Jumping
        local stalled = t > 0.15 and horizontal.Magnitude < s.WalkSpeed * s.CrouchMultiplier * mods * 0.8
        if t >= s.SlideSeconds or jumped or stalled or (not grounded and t > 0.25) then
            slide = nil
            self.SlideReadyAt = now + s.SlideCooldown
            toggles.crouch = false
            stance = (held.crouch and not mutated) and "Crouch" or nil
        else
            stance = "Slide"
            local speed = Movement.slideSpeed(s, mods, t)
            root.AssemblyLinearVelocity =
                Vector3.new(slide.Dir.X * speed, root.AssemblyLinearVelocity.Y, slide.Dir.Z * speed)
        end
    elseif
        crouchPressed
        and self.Stance == "Sprint"
        and grounded
        and moving
        and not mutated
        and now >= self.SlideReadyAt
    then
        local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
        slide = { Started = now, Dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector }
        stance = "Slide"
    elseif wantCrouch and grounded then
        stance = "Crouch"
    elseif wantSprint then
        stance = "Sprint"
    end
    crouchPressed = false

    self.Stance = stance
    local speed = Movement.resolve(s, mods, stance, aim)
    if math.abs(hum.WalkSpeed - speed) > 0.01 then
        hum.WalkSpeed = speed
    end
    local lowered = HIP[stance]
    if lowered then
        standingHip[hum] = standingHip[hum] or hum.HipHeight
        local hip = standingHip[hum] * lowered
        if math.abs(hum.HipHeight - hip) > 0.01 then
            hum.HipHeight = hip
        end
    elseif standingHip[hum] then
        hum.HipHeight = standingHip[hum]
        standingHip[hum] = nil
    end
    send(stance)
end

-- Bend the legs of every crouching or sliding R15 character, after animation has run.
local function pose()
    local me = Players.LocalPlayer
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local stance = if player == me
            then MovementController.Stance
            else character and character:GetAttribute("Stance")
        local bends = stance and POSE[stance]
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        if bends and hum and hum.RigType == Enum.HumanoidRigType.R15 then
            for _, part in character:GetChildren() do
                if part:IsA("BasePart") then
                    for _, joint in part:GetChildren() do
                        local deg = joint:IsA("Motor6D") and bends[joint.Name]
                        if deg then
                            joint.Transform *= CFrame.Angles(math.rad(deg), 0, 0)
                        end
                    end
                end
            end
        end
    end
end

function MovementController:KnitStart()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if SPRINT_KEYS[input.KeyCode] then
            held.sprint = true
        elseif input.KeyCode == SPRINT_TOGGLE then
            toggles.sprint = not toggles.sprint
        elseif CROUCH_KEYS[input.KeyCode] then
            -- C is Charge while mutated (MutationController); Titans do not crouch
            if Players.LocalPlayer:GetAttribute("Mutated") ~= nil then
                return
            end
            held.crouch = true
            crouchPressed = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if SPRINT_KEYS[input.KeyCode] then
            held.sprint = false
        elseif CROUCH_KEYS[input.KeyCode] then
            held.crouch = false
        end
    end)
    -- a held key whose release the window never saw (alt-tab) must not stay held
    UserInputService.WindowFocusReleased:Connect(function()
        held.sprint, held.crouch = false, false
    end)
    Players.LocalPlayer.CharacterAdded:Connect(function()
        held.sprint, held.crouch = false, false
        toggles.sprint, toggles.crouch = false, false
        slide, crouchPressed, sentStance = nil, false, nil
        self.Stance = nil
    end)

    RunService.Heartbeat:Connect(function()
        self:Step()
    end)
    RunService.Stepped:Connect(pose)
end

return MovementController
