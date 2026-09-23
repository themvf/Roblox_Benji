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
--     /unmark          remove the last one
--     /marks           print every mark as map data, ready to paste
--     /marks clear     remove them all
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
    -- The character's root sits about 3 studs above the floor it is standing on.
    local y = math.floor(root.Position.Y - 3 + 0.5)

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

function BlockoutService:KnitStart()
    if not RunService:IsStudio() then
        return
    end
    self.Marks = {}
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
            end
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
    print("[Blockout] ready: /mark, /mark <size>, /unmark, /marks, /marks clear")
end

return BlockoutService
