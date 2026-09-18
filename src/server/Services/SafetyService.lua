-- Carrier Testability and Safety Fix Spec v1 (S2, S5, S6, S7).
-- One switch, Tuning attribute Debug_CarrierTestSafety, enables:
--   perimeter collision barrier (layout.Barrier), water / below-map recovery, invalid-geometry recovery,
--   launch pad debug markers, and RECOVERY logging. Off = production-intent behaviour (none of the above).
-- Map data: layout.RecoveryY, layout.Bounds {min,max}, layout.InvalidRegions, layout.SafeRegions, layout.SafePoints.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SafetyService = Knit.CreateService({
    Name = "SafetyService",
    Client = {
        Notice = Knit.CreateSignal(), -- (text)
    },
})

local CHECK = 0.5
local GRACE = 1.0 -- seconds out of bounds before recovery

local function tuning()
    return ReplicatedStorage:FindFirstChild("Tuning")
end

function SafetyService:Enabled()
    local t = tuning()
    return t ~= nil and t:GetAttribute("Debug_CarrierTestSafety") == true
end

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

local function inBox(pos, box)
    local c, s = v3(box.pos), v3(box.size)
    return math.abs(pos.X - c.X) <= s.X / 2 and math.abs(pos.Y - c.Y) <= s.Y / 2 and math.abs(pos.Z - c.Z) <= s.Z / 2
end

-- ===== S2 perimeter barrier =====
function SafetyService:BuildBarrier(layout, folder)
    if not self:Enabled() or not layout.Barrier then
        return
    end
    for i, seg in layout.Barrier do
        local p = Instance.new("Part")
        p.Name = "SafetyBarrier" .. i
        p.Anchored = true
        p.CanCollide = true
        p.CanQuery = false -- bullets (raycasts) pass through
        p.CanTouch = false
        p.Transparency = 1
        p.Size = v3(seg.size)
        p.CFrame = CFrame.new(v3(seg.pos))
        p.Parent = folder
    end
end

-- ===== S5/S6 recovery =====
local function reason(layout, pos)
    if layout.RecoveryY and pos.Y < layout.RecoveryY then
        return "BelowDeck"
    end
    if layout.Bounds then
        local mn, mx = v3(layout.Bounds.min), v3(layout.Bounds.max)
        if pos.X < mn.X or pos.X > mx.X or pos.Y < mn.Y or pos.Y > mx.Y or pos.Z < mn.Z or pos.Z > mx.Z then
            return "OutOfBounds"
        end
    end
    for _, safe in layout.SafeRegions or {} do
        if inBox(pos, safe) then
            return nil
        end
    end
    for _, bad in layout.InvalidRegions or {} do
        if inBox(pos, bad) then
            return "InvalidGeometry:" .. (bad.name or "?")
        end
    end
    return nil
end

local function nearestSafePoint(layout, pos)
    local best, bestD
    for _, sp in layout.SafePoints or {} do
        local p = v3(sp.pos)
        local d = (p - pos).Magnitude
        if not bestD or d < bestD then
            best, bestD = sp, d
        end
    end
    return best
end

function SafetyService:Recover(player, character, layout, why)
    local root = character:FindFirstChild("HumanoidRootPart")
    local sp = nearestSafePoint(layout, root.Position)
    local pos = root.Position
    if not sp then
        -- no safe points: respawn instead
        local hum = character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
        end
        return
    end
    warn(
        ("RECOVERY: %s | reason=%s | pos=(%.0f,%.0f,%.0f) | to=%s"):format(
            player.Name,
            why,
            pos.X,
            pos.Y,
            pos.Z,
            sp.name or "safe point"
        )
    )
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(v3(sp.pos) + Vector3.new(0, 3, 0))
    self.Client.Notice:Fire(player, "Recovered to " .. (sp.name or "deck"))
    self.Stats.Recoveries += 1
end

function SafetyService:KnitStart()
    self.Stats = { Recoveries = 0 }
    self.OutSince = {}
    task.spawn(function()
        while true do
            task.wait(CHECK)
            if not self:Enabled() then
                continue
            end
            local MapService = Knit.GetService("MapService")
            local layout = MapService.Layout
            if not layout then
                continue
            end
            for _, player in Players:GetPlayers() do
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if
                    root
                    and hum
                    and hum.Health > 0
                    and player:GetAttribute("InMatch")
                    and not character:GetAttribute("Launched")
                then
                    local why = reason(layout, root.Position)
                    if why then
                        self.OutSince[player] = self.OutSince[player] or os.clock()
                        if os.clock() - self.OutSince[player] >= GRACE then
                            self.OutSince[player] = nil
                            self:Recover(player, character, layout, why)
                        end
                    else
                        self.OutSince[player] = nil
                    end
                else
                    self.OutSince[player] = nil
                end
            end
        end
    end)
end

return SafetyService
