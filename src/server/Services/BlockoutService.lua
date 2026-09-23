-- Place map decor by standing where you want it, instead of describing a coordinate.
--
-- The loop this replaces was: say roughly where something should go, have a number
-- guessed from that description, build, look at it, say it is wrong, repeat. Every
-- round trip costs a restart and the description is never as precise as the thing in
-- your head. Here the game writes the coordinate, so it is right the first time.
--
-- In a Play session (F5), walk to a spot and type in chat:
--
--     /mark            drop a marker sized 20 studs across
--     /mark 35         ... or any size; the marker is that wide, so you see the scale
--     /unmark          take back the last one
--     /marks           print every mark as map data, ready to paste
--     /marks clear     remove them all
--
-- And to take something out of the map, stand near it and:
--
--     /remove          flag the nearest piece; it turns red so you can see which
--     /unremove        take back the last flag
--     /removals        print the flagged names
--     /removals clear  unflag them all
--
-- Flagging changes nothing on its own. It turns "the ugly rock over there" into a
-- name that appears in the map file, which is the part that was hard to say out loud.
--
-- A marker is a translucent box the size the prop would be, so the footprint is
-- visible while placing rather than after building. It never collides and never
-- answers a raycast, so it cannot change how the map plays while you walk around it.
--
-- Studio only. This is a level-design aid, not a game feature, and it takes chat
-- input -- there is no version of it that should exist on a live server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BlockoutService = Knit.CreateService({ Name = "BlockoutService" })

local DEFAULT_FIT = 20
local MARKER_COLOR = Color3.fromRGB(120, 235, 255)

local function folder()
    local existing = workspace:FindFirstChild("Blockout")
    if existing then
        return existing
    end
    local made = Instance.new("Folder")
    made.Name = "Blockout"
    made.Parent = workspace
    return made
end

function BlockoutService:Mark(player, fit)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        warn("[Blockout] no character to mark from")
        return
    end
    -- Round to whole studs. Map data is hand-read and hand-edited, and nobody wants
    -- to see 37.4182 in a table they have to scan.
    local x = math.floor(root.Position.X + 0.5)
    local z = math.floor(root.Position.Z + 0.5)
    -- Find the floor by looking for it, not by assuming how tall a character is. The
    -- first version subtracted a hardcoded 3 studs and reported y 2 while standing on
    -- a floor whose top is y 0: an R15 root sits about 5 studs up, and that figure
    -- moves with rig scale anyway. A ray also gets the roof right, where the answer
    -- should be 33 rather than the ground far below it.
    local filter = RaycastParams.new()
    filter.FilterType = Enum.RaycastFilterType.Exclude
    filter.FilterDescendantsInstances = { character, workspace:FindFirstChild("Blockout") }
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), filter)
    local y = math.floor((hit and hit.Position.Y or root.Position.Y - 5) + 0.5)

    local marker = Instance.new("Part")
    marker.Name = ("Mark%d_%d"):format(x, z)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false
    marker.Material = Enum.Material.Neon
    marker.Color = MARKER_COLOR
    marker.Transparency = 0.6
    marker.Size = Vector3.new(fit, fit * 0.6, fit)
    marker.CFrame = CFrame.new(x, y + fit * 0.3, z)
    marker.Parent = folder()

    self.Marks = self.Marks or {}
    table.insert(self.Marks, { x = x, y = y, z = z, fit = fit, part = marker })
    print(("[Blockout] mark %d at %d, %d, %d, fit %d"):format(#self.Marks, x, y, z, fit))
end

function BlockoutService:Unmark()
    local marks = self.Marks
    if not marks or #marks == 0 then
        print("[Blockout] nothing to remove")
        return
    end
    local last = table.remove(marks)
    if last.part then
        last.part:Destroy()
    end
    print(("[Blockout] removed mark at %d, %d, %d; %d left"):format(last.x, last.y, last.z, #marks))
end

function BlockoutService:Clear()
    for _, mark in self.Marks or {} do
        if mark.part then
            mark.part:Destroy()
        end
    end
    self.Marks = {}
    print("[Blockout] cleared")
end

function BlockoutService:Dump()
    local marks = self.Marks or {}
    if #marks == 0 then
        print("[Blockout] no marks yet -- stand somewhere and type /mark")
        return
    end
    -- Printed in the shape the map files already use for a prop seed, so it can go
    -- straight into a layout without anyone retyping a number.
    local lines = { ("[Blockout] %d marks, paste into the map's seed table:"):format(#marks) }
    for _, mark in marks do
        table.insert(lines, ("        { x = %d, z = %d, fit = %d, yaw = 0 },"):format(mark.x, mark.z, mark.fit))
    end
    local ys = {}
    for _, mark in marks do
        if mark.y ~= 0 then
            table.insert(ys, ("%d,%d is at y %d"):format(mark.x, mark.z, mark.y))
        end
    end
    if #ys > 0 then
        -- `sit` handles the ground, so a non-zero y only matters on a raised surface.
        table.insert(lines, "    -- not at ground level: " .. table.concat(ys, "; "))
    end
    print(table.concat(lines, "\n"))
end

-- The map is rebuilt from data every match, so "remove this" has to come back as a
-- name that can be found in the map file. Only the pieces that belong to the built
-- map are candidates, and only ones small enough to have been meant: the floor is
-- 490 studs across and is always the thing you are standing closest to.
local REMOVE_RADIUS = 80
-- Skip the ground and nothing else. A piece broad in BOTH horizontal directions is a
-- floor or a deck, and you are always standing on one, so by surface distance it would
-- win every time. The first rule here was "longest axis under 60 studs", which also
-- quietly refused to flag a 66-stud sightline screen -- exactly the kind of thing
-- somebody wants gone.
local GROUND_FOOTPRINT = 100

local function extents(piece)
    if piece:IsA("Model") then
        local cf, size = piece:GetBoundingBox()
        return cf.Position, size
    elseif piece:IsA("BasePart") then
        return piece.Position, piece.Size
    end
    return nil, nil
end

function BlockoutService:Remove(player)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        warn("[Blockout] no character to measure from")
        return
    end
    local map = workspace:FindFirstChild("Map")
    if not map then
        warn("[Blockout] no built map to remove from")
        return
    end

    self.Removals = self.Removals or {}
    local flagged = {}
    for _, entry in self.Removals do
        flagged[entry.piece] = true
    end

    local best, bestAt, bestGap
    for _, piece in map:GetChildren() do
        local centre, size = extents(piece)
        if centre and not flagged[piece] and math.min(size.X, size.Z) <= GROUND_FOOTPRINT then
            -- Distance to the piece's surface, not its centre. Standing beside a long
            -- wall should flag the wall, not some small thing further off whose middle
            -- happens to be nearer. The box is treated as axis-aligned, which is true
            -- of nearly everything a map places and close enough for a dev aid.
            local d = centre - root.Position
            local gap = Vector3.new(
                math.max(0, math.abs(d.X) - size.X / 2),
                math.max(0, math.abs(d.Y) - size.Y / 2),
                math.max(0, math.abs(d.Z) - size.Z / 2)
            ).Magnitude
            if gap <= REMOVE_RADIUS and (not bestGap or gap < bestGap) then
                best, bestAt, bestGap = piece, centre, gap
            end
        end
    end
    if not best then
        print(("[Blockout] nothing within %d studs that is not already flagged"):format(REMOVE_RADIUS))
        return
    end

    -- Show which one. Reading a name out of a log and hoping it was the right rock is
    -- how the wrong thing gets deleted.
    local glow = Instance.new("Highlight")
    glow.FillColor = Color3.fromRGB(255, 70, 70)
    glow.OutlineColor = Color3.fromRGB(255, 170, 170)
    glow.FillTransparency = 0.55
    glow.Adornee = best
    glow.Parent = best

    table.insert(self.Removals, { name = best.Name, piece = best, at = bestAt, glow = glow })
    print(
        ("[Blockout] flagged %q, %.0f studs away at %d, %d, %d"):format(
            best.Name,
            bestGap,
            math.floor(bestAt.X + 0.5),
            math.floor(bestAt.Y + 0.5),
            math.floor(bestAt.Z + 0.5)
        )
    )
end

function BlockoutService:Unremove()
    local removals = self.Removals
    if not removals or #removals == 0 then
        print("[Blockout] nothing flagged")
        return
    end
    local last = table.remove(removals)
    if last.glow then
        last.glow:Destroy()
    end
    print(("[Blockout] unflagged %q; %d still flagged"):format(last.name, #removals))
end

function BlockoutService:ClearRemovals()
    for _, entry in self.Removals or {} do
        if entry.glow then
            entry.glow:Destroy()
        end
    end
    self.Removals = {}
    print("[Blockout] removal flags cleared")
end

function BlockoutService:DumpRemovals()
    local removals = self.Removals or {}
    if #removals == 0 then
        print("[Blockout] nothing flagged -- stand near something and type /remove")
        return
    end
    local lines = { ("[Blockout] %d flagged for removal:"):format(#removals) }
    for _, entry in removals do
        table.insert(
            lines,
            ("    %s  at %d, %d, %d"):format(
                entry.name,
                math.floor(entry.at.X + 0.5),
                math.floor(entry.at.Y + 0.5),
                math.floor(entry.at.Z + 0.5)
            )
        )
    end
    print(table.concat(lines, "\n"))
end

function BlockoutService:KnitStart()
    if not RunService:IsStudio() then
        return
    end
    self.Marks = {}
    self.Removals = {}
    local function watch(player)
        player.Chatted:Connect(function(msg)
            local text = msg:lower()
            if text == "/marks clear" then
                self:Clear()
            elseif text == "/marks" then
                self:Dump()
            elseif text == "/unmark" then
                self:Unmark()
            elseif text:sub(1, 5) == "/mark" then
                local fit = tonumber(text:match("^/mark%s+([%d%.]+)$")) or DEFAULT_FIT
                self:Mark(player, math.clamp(fit, 1, 200))
            elseif text == "/removals clear" then
                self:ClearRemovals()
            elseif text == "/removals" then
                self:DumpRemovals()
            elseif text == "/unremove" then
                self:Unremove()
            elseif text == "/remove" then
                self:Remove(player)
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
    print("[Blockout] ready: /mark <size>, /unmark, /marks, /marks clear")
    print("[Blockout]        /remove, /unremove, /removals, /removals clear")
end

return BlockoutService
