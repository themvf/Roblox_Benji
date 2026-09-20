-- Carrier Testability and Safety Fix Spec v1 (S2, S5, S6, S7).
--
-- Detection always runs: a character below layout.RecoveryY, outside layout.Bounds, or inside an
-- InvalidRegion (and not in a SafeRegion) is somewhere the map does not want them. What happens
-- next depends on the mode:
--
--   Production (default): they die and respawn through the normal flow. This has to be the
--     shipped behaviour, because a map over water has no kill plane -- Roblox only destroys parts
--     below FallenPartsDestroyHeight, and the Carrier's sea is swimmable, so a player who went
--     over the deck edge used to swim until the match ended. Death is also the honest outcome:
--     teleporting a player back to safety would let them dodge a lost fight by jumping off.
--
--   Testing (Tuning Debug_CarrierTestSafety): the same detection teleports to the nearest
--     SafePoint instead of killing, and adds the perimeter barrier (layout.Barrier), launch pad
--     debug markers and RECOVERY logging, so a QA run is not interrupted by every fall. The
--     barrier is built with the map, so toggling this mid-session applies on the next map load.
--
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

-- Testing aids only. Detection and the production response do not depend on this.
function SafetyService:TestAids()
    local t = tuning()
    return t ~= nil and t:GetAttribute("Debug_CarrierTestSafety") == true
end

function SafetyService:Enabled(layout)
    return (layout and layout.SafetyAlwaysOn == true) or self:TestAids()
end

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

local function inBox(pos, box)
    local c, s = v3(box.pos), v3(box.size)
    return math.abs(pos.X - c.X) <= s.X / 2 and math.abs(pos.Y - c.Y) <= s.Y / 2 and math.abs(pos.Z - c.Z) <= s.Z / 2
end

-- ===== S2 perimeter barrier =====
local BARRIER_HEIGHT = 12
local BARRIER_THICKNESS = 1.5
local BARRIER_OFFSET = 1.5 -- studs outside the edge

-- Snow Fortress D3: expand one enclosure declaration into its wall segments.
-- `around = {pos, size}` is the walkable footprint (pos.y is the floor, size.y is ignored); walls
-- stand `offset` studs outside each edge. `gaps` are ranges along the side's own axis relative to
-- the footprint centre, so a launch pad landing is declared on the edge that owns it rather than
-- as a slab someone has to remember not to author.
local function expandEnclosure(enc, out)
    local c, s = v3(enc.around.pos), v3(enc.around.size)
    local height = enc.height or BARRIER_HEIGHT
    local thick = enc.thickness or BARRIER_THICKNESS
    local offset = enc.offset or BARRIER_OFFSET
    local y = c.Y + height / 2
    local halfX, halfZ = s.X / 2, s.Z / 2

    for _, side in { "-x", "+x", "-z", "+z" } do
        local alongX = side == "-z" or side == "+z"
        local span = alongX and halfX or halfZ

        local cuts = {}
        for _, g in enc.gaps or {} do
            if g.side == side then
                local from, to = math.max(g.from, -span), math.min(g.to, span)
                if to > from then
                    table.insert(cuts, { from, to })
                end
            end
        end
        table.sort(cuts, function(a, b)
            return a[1] < b[1]
        end)

        -- walls fill the runs between the cuts
        local runs, cursor = {}, -span
        for _, cut in cuts do
            if cut[1] > cursor then
                table.insert(runs, { cursor, cut[1] })
            end
            cursor = math.max(cursor, cut[2])
        end
        if cursor < span then
            table.insert(runs, { cursor, span })
        end

        for _, run in runs do
            local mid, len = (run[1] + run[2]) / 2, run[2] - run[1]
            if alongX then
                local z = c.Z + (side == "+z" and halfZ + offset or -(halfZ + offset))
                table.insert(out, { pos = { c.X + mid, y, z }, size = { len, height, thick } })
            else
                local x = c.X + (side == "+x" and halfX + offset or -(halfX + offset))
                table.insert(out, { pos = { x, y, c.Z + mid }, size = { thick, height, len } })
            end
        end
    end
end

function SafetyService:BuildBarrier(layout, folder)
    if not self:Enabled(layout) then
        return
    end
    -- flat segments (Carrier) and enclosures (Snow Fortress) both end up as the same parts
    local segments = {}
    for _, seg in layout.Barrier or {} do
        table.insert(segments, seg)
    end
    for _, enc in layout.BarrierEnclosures or {} do
        expandEnclosure(enc, segments)
    end

    for i, seg in segments do
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

-- Production response: the map has decided this position is not playable, so the character dies
-- and the mode's own respawn timer takes over. No killer is credited (nothing sets LastHitBy),
-- unless an enemy shot them just before they went over, which is the outcome we want anyway.
function SafetyService:Eliminate(character, why)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return
    end
    self.Stats.Eliminations += 1
    self.Stats.Reasons[why] = (self.Stats.Reasons[why] or 0) + 1
    hum.Health = 0
end

-- The out-of-bounds rule, for anything that is not a Player: BotService runs its rigs through
-- this so a bot cannot swim in the sea for the rest of a bot test.
-- Returns a reason string, or nil when the position is fine (or the map declares no safety data).
function SafetyService:OutOfBounds(position)
    local layout = Knit.GetService("MapService").Layout
    if not layout then
        return nil
    end
    return reason(layout, position)
end

function SafetyService:KnitStart()
    self.Stats = { Recoveries = 0, Eliminations = 0, Reasons = {} }
    self.OutSince = {}
    task.spawn(function()
        while true do
            task.wait(CHECK)
            local MapService = Knit.GetService("MapService")
            local layout = MapService.Layout
            if not layout or not self:Enabled(layout) then
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
                    and not character:GetAttribute("TraversalState")
                then
                    local why = reason(layout, root.Position)
                    if why then
                        self.OutSince[player] = self.OutSince[player] or os.clock()
                        if os.clock() - self.OutSince[player] >= GRACE then
                            self.OutSince[player] = nil
                            if self:TestAids() then
                                self:Recover(player, character, layout, why)
                            else
                                self.Client.Notice:Fire(player, "Out of bounds")
                                self:Eliminate(character, why)
                            end
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
