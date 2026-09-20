-- Client side of celebrations: the radial choice wheel, playing emotes on the local
-- character, reactive emotes for teammates, the results camera and MVP orbit, skip vote UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)
local Celebrations = require(ReplicatedStorage.Shared.Celebrations)
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local CelebrationController = Knit.CreateController({ Name = "CelebrationController" })

-- A modal surface sits *on* the HUD, so it is the raised panel tone, not a second dark grey.
local PANEL = Theme.Color.PanelRaised
local ACCENT = Theme.Color.Accent
local TEXT = Theme.Color.Text
local TIER_COLORS = Theme.Tier

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = inst
end

local playEmote
local function playMotion(character, motion)
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    -- Custom animation wins when its asset is ready; otherwise the built-in emote
    local animId = Uploads.resolve(motion.Animation)
    if animId then
        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local track = animator:LoadAnimation(anim)
        track.Priority = Enum.AnimationPriority.Action
        track:Play()
        return
    end
    playEmote(character, motion.Emote)
end

playEmote = function(character, emote)
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local ok = pcall(function()
        hum:PlayEmote(emote)
    end)
    if not ok then
        warn("[Celebrations] emote not available: " .. tostring(emote))
    end
end

function CelebrationController:BuildGui()
    local gui = Screen.newScreenGui("CelebrationGui", Screen.Layers.Celebration)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui

    -- Radial wheel: default in the centre, favourites around it
    local wheel = Instance.new("Frame")
    wheel.Name = "Wheel"
    wheel.AnchorPoint = Vector2.new(0.5, 0.5)
    wheel.Position = UDim2.fromScale(0.5, 0.55)
    wheel.Size = UDim2.fromOffset(340, 340)
    wheel.BackgroundTransparency = 1
    wheel.Visible = false
    wheel.Parent = gui
    self.Wheel = wheel
    -- A 340 px wheel is taller than a phone's safe area in landscape. Scale it, and keep the
    -- petals' own tap targets at 44pt minimum (see the button sizes below).
    Screen.autoScale(wheel)

    local timer = Instance.new("TextLabel")
    timer.AnchorPoint = Vector2.new(0.5, 1)
    timer.Position = UDim2.new(0.5, 0, 0, -10)
    timer.Size = UDim2.fromOffset(300, 34)
    timer.BackgroundTransparency = 1
    timer.Text = "CHOOSE YOUR CELEBRATION"
    timer.TextSize = Theme.textSize(Theme.Type.Title)
    timer.Font = Enum.Font.GothamBlack
    timer.TextColor3 = ACCENT
    timer.TextStrokeTransparency = 0.4
    timer.Parent = wheel
    self.WheelTitle = timer

    -- Skip vote hint for losers
    local skip = Instance.new("TextLabel")
    skip.AnchorPoint = Vector2.new(0.5, 1)
    skip.Position = UDim2.new(0.5, 0, 1, -40)
    skip.Size = UDim2.fromOffset(420, 36)
    skip.BackgroundColor3 = PANEL
    skip.BackgroundTransparency = Theme.Transparency.Panel
    skip.Text = "Press V to vote skip  (0 / 3)"
    skip.TextSize = Theme.textSize(Theme.Type.Body)
    skip.Font = Enum.Font.GothamBold
    skip.TextColor3 = TEXT
    skip.Visible = false
    skip.Parent = gui
    corner(skip, 10)
    self.SkipLabel = skip
end

function CelebrationController:ShowWheel(favorites, seconds)
    local wheel = self.Wheel
    for _, c in wheel:GetChildren() do
        if c:IsA("TextButton") then
            c:Destroy()
        end
    end
    local picked = false
    local function button(id, cf, size)
        local cel = Celebrations.get(id)
        if not cel then
            return
        end
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Position = cf
        b.Size = size
        b.BackgroundColor3 = PANEL
        b.Text = cel.Name
        b.TextSize = Theme.textSize(Theme.Type.Body)
        b.Font = Enum.Font.GothamBold
        b.TextColor3 = TIER_COLORS[cel.Tier] or TEXT
        b.AutoButtonColor = true
        b.Parent = wheel
        corner(b, 16)
        local stroke = Instance.new("UIStroke")
        stroke.Color = TIER_COLORS[cel.Tier] or TEXT
        stroke.Thickness = 2
        stroke.Parent = b
        b.Activated:Connect(function()
            if picked then
                return
            end
            picked = true
            Knit.GetService("CelebrationService"):Pick(id)
            b.BackgroundColor3 = TIER_COLORS[cel.Tier] or ACCENT
            b.TextColor3 = PANEL
        end)
    end
    -- centre = default (first favourite); others around a ring
    -- Petal heights are checked against Screen.MIN_TAP so the wheel stays tappable once the
    -- UIScale on `wheel` has shrunk it for a phone.
    local petalH = math.max(70, math.ceil(Screen.MIN_TAP / math.max(Screen.get().Scale, 0.1)))
    button(favorites[1], UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(120, 120))
    local ring = {}
    for i = 2, #favorites do
        table.insert(ring, favorites[i])
    end
    for i, id in ring do
        local a = (i - 1) / #ring * math.pi * 2 - math.pi / 2
        button(id, UDim2.new(0.5, math.cos(a) * 125, 0.5, math.sin(a) * 125), UDim2.fromOffset(110, petalH))
    end

    wheel.Visible = true
    self.Gui.Enabled = true
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < seconds do
            self.WheelTitle.Text = ("CHOOSE YOUR CELEBRATION  %.1f"):format(seconds - (os.clock() - t0))
            task.wait(0.1)
        end
        wheel.Visible = false
    end)
end

function CelebrationController:RunCamera(sequence)
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable
    local focus = sequence.Focus + Vector3.new(0, 3, 0)
    local results = CFrame.lookAt(focus + Vector3.new(0, 6, -26), focus)
    cam.CFrame = results
    self.CameraActive = true
    local t0 = os.clock()
    local mvpSpot = sequence.MvpSpot
    local orbit = sequence.Camera and sequence.Camera.Type == "Orbit" and sequence.Camera or nil
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not self.CameraActive then
            conn:Disconnect()
            return
        end
        local t = os.clock() - t0
        if t >= sequence.Duration - 3 then
            -- final 3 s: hold on the MVP
            local target = mvpSpot.Position
            if orbit and t < (orbit.ReturnAt or sequence.Duration) then
                local a = t * 1.1
                local eye = target + Vector3.new(math.cos(a) * orbit.Radius, orbit.Height, math.sin(a) * orbit.Radius)
                cam.CFrame = CFrame.lookAt(eye, target)
            else
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(target + Vector3.new(0, 3, -12), target), 0.08)
            end
        else
            cam.CFrame = results
        end
    end)
end

function CelebrationController:OnStart(sequence)
    local me = Players.LocalPlayer
    self.Gui.Enabled = true
    self.Wheel.Visible = false
    local mine
    for _, entry in sequence.Spots do
        if entry.UserId == me.UserId then
            mine = entry
        end
    end
    if mine then
        local cel = Celebrations.get(mine.Celebration)
        task.delay(mine.StartAt, function()
            if cel and cel.Systems.Motion then
                playMotion(me.Character, cel.Systems.Motion)
            end
        end)
        if mine.Reactive then
            -- teammates react when the MVP's celebration starts
            local mvpEntry
            for _, e in sequence.Spots do
                if e.UserId == sequence.MvpUserId then
                    mvpEntry = e
                end
            end
            task.delay((mvpEntry and mvpEntry.StartAt or 0) + 0.3, function()
                playEmote(me.Character, mine.Reactive)
            end)
        end
        self.SkipLabel.Visible = false
    else
        self.SkipLabel.Visible = true
        self.SkipLabel.Text = self:SkipHint() .. "  (0 / 3)"
    end
    self:RunCamera(sequence)
end

function CelebrationController:OnEnd()
    self.CameraActive = false
    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Custom
    self.SkipLabel.Visible = false
    self.Wheel.Visible = false
    self.Gui.Enabled = false
end

function CelebrationController:VoteSkip()
    if self.SkipLabel.Visible then
        Knit.GetService("CelebrationService"):VoteSkip()
    end
end

-- Lobby-only local preview used by Customize. It deliberately plays only the motion:
-- podium props/cameras remain match presentation and never interrupt the shared lobby.
function CelebrationController:Preview(id)
    local player = Players.LocalPlayer
    if player:GetAttribute("InMatch") or player:GetAttribute("QueueState") == "Committed" then
        return false
    end
    local celebration = Celebrations.get(id)
    local motion = celebration and celebration.Systems.Motion
    if not motion or not player.Character then
        return false
    end
    playMotion(player.Character, motion)
    return true
end

function CelebrationController:SkipHint()
    return Knit.GetController("TouchController").IsTouch() and "Tap SKIP to vote skip" or "Press V to vote skip"
end

function CelebrationController:KnitStart()
    self:BuildGui()
    local svc = Knit.GetService("CelebrationService")
    svc.Choose:Connect(function(favorites, seconds)
        self:ShowWheel(favorites, seconds)
    end)
    svc.Start:Connect(function(sequence)
        self:OnStart(sequence)
    end)
    svc.End:Connect(function()
        self:OnEnd()
    end)
    svc.SkipVotes:Connect(function(votes, needed)
        self.SkipLabel.Text = (self:SkipHint() .. "  (%d / %d)"):format(votes, needed)
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if input.KeyCode == Enum.KeyCode.V then
            self:VoteSkip()
        end
    end)
end

return CelebrationController
