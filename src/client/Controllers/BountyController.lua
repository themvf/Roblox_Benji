-- Bounty visibility tiers on the client:
--   Tier 1  a marker above a bounty target only while the local camera has line of sight
--   Tier 2  approximate zone pings from the server (banner text, never a position)
--   Tier 3  objective callouts when the target captures
-- Also the "Set / Claimed / Survived" banners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Theme = require(script.Parent.Parent.UI.Theme)

local BountyController = Knit.CreateController({ Name = "BountyController" })

local ACCENT = Theme.Color.Accent
local markers = {} -- [player] = BillboardGui

local function ensureMarker(player)
    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    if not head then
        return nil
    end
    local bb = markers[player]
    if bb and bb.Parent == head then
        return bb
    end
    bb = Instance.new("BillboardGui")
    bb.Name = "BountyMarker"
    bb.Size = UDim2.fromOffset(180, 44)
    bb.StudsOffset = Vector3.new(0, 3.6, 0)
    bb.AlwaysOnTop = false -- must be visible, not through walls
    bb.MaxDistance = 140
    bb.Enabled = false
    bb.Parent = head
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.TextScaled = true
    l.Font = Enum.Font.GothamBlack
    l.TextColor3 = ACCENT
    Theme.overWorld(l)
    l.Text = "★ " .. (player:GetAttribute("Bounty") or "WANTED")
    l.Parent = bb
    markers[player] = bb
    return bb
end

local function hasLos(fromPos, character)
    local head = character:FindFirstChild("Head")
    if not head then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances =
        { Players.LocalPlayer.Character, workspace:FindFirstChild("Objectives") or character }
    -- Same defect as BotService.los: without this a bounty marker vanishes whenever the line
    -- to the target clips a water surface, on a map whose centre objective sits in water.
    params.IgnoreWater = true
    local hit = workspace:Raycast(fromPos, head.Position - fromPos, params)
    return hit ~= nil and hit.Instance:IsDescendantOf(character)
end

function BountyController:KnitStart()
    local svc = Knit.GetService("StatsService")
    local conv = Knit.GetController("ConvergenceController")
    svc.Bounty:Connect(function(kind, data)
        if kind == "Set" then
            local mine = data.Target == Players.LocalPlayer.Name
            conv:ShowBanner(
                mine and ("YOU ARE MARKED: " .. data.Name:upper())
                    or (data.Target:upper() .. " IS " .. data.Name:upper()),
                ACCENT
            )
        elseif kind == "Ping" then
            local verb = data.Reason == "capturing" and "capturing" or "near"
            conv:ShowBanner(("Target %s %s %s"):format(data.Target, verb, conv:GlyphChar(data.Index)), ACCENT)
        elseif kind == "Claimed" then
            conv:ShowBanner(
                ("BOUNTY CLAIMED: %s by %s%s"):format(
                    data.Target,
                    data.Hunter,
                    data.XP > 0 and (" (+" .. data.XP .. " XP)") or " (no payout)"
                ),
                ACCENT
            )
        end
    end)

    -- LOS-only markers
    RunService.Heartbeat:Connect(function()
        local cam = workspace.CurrentCamera
        local t = os.clock()
        if t - (self.LastCheck or 0) < 0.2 then
            return
        end
        self.LastCheck = t
        for _, p in Players:GetPlayers() do
            local bounty = p:GetAttribute("Bounty")
            if p ~= Players.LocalPlayer and bounty and p.Character then
                local bb = ensureMarker(p)
                if bb then
                    bb.TextLabel.Text = "★ " .. bounty
                    bb.Enabled = p:GetAttribute("Team") ~= Players.LocalPlayer:GetAttribute("Team")
                        and hasLos(cam.CFrame.Position, p.Character)
                end
            elseif markers[p] then
                markers[p]:Destroy()
                markers[p] = nil
            end
        end
    end)
end

return BountyController
