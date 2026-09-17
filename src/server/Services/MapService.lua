-- Builds the arena from a layout table in Shared/Maps at server start, and
-- spawns players at their team's spawn points.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MapService = Knit.CreateService({ Name = "MapService" })

local TEAM_COLORS = {
    Red = Color3.fromRGB(200, 60, 60),
    Blue = Color3.fromRGB(60, 110, 200),
}

local function v3(t)
    return Vector3.new(t[1], t[2], t[3])
end

local function makePart(folder, name, pos, size, rot, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = v3(size)
    local cf = CFrame.new(v3(pos))
    if rot then
        cf = cf * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
    end
    part.CFrame = cf
    part.Color = color or Color3.fromRGB(160, 160, 160)
    part.Material = material or Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = folder
    return part
end

function MapService:Build(layout)
    local old = workspace:FindFirstChild("Map")
    if old then
        old:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = "Map"
    folder.Parent = workspace

    local half = layout.Size / 2
    makePart(
        folder,
        "Floor",
        { 0, -1, 0 },
        { layout.Size, 2, layout.Size },
        nil,
        Color3.fromRGB(90, 90, 95),
        Enum.Material.Concrete
    )

    -- Outer walls
    local h = layout.WallHeight
    makePart(folder, "WallN", { 0, h / 2, -half }, { layout.Size, h, 2 })
    makePart(folder, "WallS", { 0, h / 2, half }, { layout.Size, h, 2 })
    makePart(folder, "WallW", { -half, h / 2, 0 }, { 2, h, layout.Size })
    makePart(folder, "WallE", { half, h / 2, 0 }, { 2, h, layout.Size })

    for _, piece in layout.Center do
        makePart(folder, piece.name, piece.pos, piece.size, piece.rot, Color3.fromRGB(190, 190, 120))
    end

    for _, piece in layout.Mirrored do
        makePart(folder, "Red_" .. piece.name, piece.pos, piece.size, piece.rot, Color3.fromRGB(190, 140, 140))
        local mirrorPos = { -piece.pos[1], piece.pos[2], piece.pos[3] }
        local mirrorRot = piece.rot and { piece.rot[1], -piece.rot[2], -piece.rot[3] } or nil
        makePart(folder, "Blue_" .. piece.name, mirrorPos, piece.size, mirrorRot, Color3.fromRGB(140, 160, 190))
    end

    -- Spawn pads (visual only; MapService positions characters itself)
    self.Spawns = {}
    for team, points in layout.Spawns do
        self.Spawns[team] = {}
        for i, p in points do
            local pad = makePart(
                folder,
                team .. "Spawn" .. i,
                { p[1], 0.25, p[3] },
                { 6, 0.5, 6 },
                nil,
                TEAM_COLORS[team],
                Enum.Material.Neon
            )
            pad.CanCollide = false
            table.insert(self.Spawns[team], v3(p))
        end
    end

    -- Remove the default baseplate if Studio added one
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate:Destroy()
    end
end

-- Teleport a freshly loaded character to its team spawn, facing the map center.
function MapService:PlaceCharacter(player, character)
    local team = player:GetAttribute("Team")
    local points = self.Spawns and self.Spawns[team]
    if not points or #points == 0 then
        return
    end
    local root = character:WaitForChild("HumanoidRootPart", 5)
    if not root then
        return
    end
    local idx = (player.UserId % #points) + 1
    local pos = points[idx] + Vector3.new(0, 3, 0)
    root.CFrame = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end

function MapService:KnitInit()
    self:Build(require(ReplicatedStorage.Shared.Maps.Arena))
end

function MapService:KnitStart()
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(self.PlaceCharacter, self, player, character)
        end)
    end)
end

return MapService
