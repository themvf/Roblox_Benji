local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3
local layout = require("../src/shared/Maps/SnowFortress")

local roots = roblox.deserializeModel(fs.readFile("assets/environment/baked/SnowFortress.rbxm"))
local sites = {}
for _, turret in layout.Turrets do
    table.insert(sites, { name = turret.Id, x = turret.pos[1], z = turret.pos[3] })
end

for _, site in sites do
    print("\nSITE", site.name, site.x, site.z)
    local point = roblox.Vector3.new(site.x, 0, site.z)
    local nearestSpawn = math.huge
    for _, teamSpawns in layout.Spawns do
        for _, spawn in teamSpawns do
            local distance = (point - roblox.Vector3.new(spawn[1], spawn[2], spawn[3])).Magnitude
            nearestSpawn = math.min(nearestSpawn, distance)
        end
    end
    print(("nearest spawn %.1f studs"):format(nearestSpawn))
    local near = {}
    for _, root in roots do
        for _, part in root:GetDescendants() do
            local okCf, cf = pcall(function()
                return part.CFrame
            end)
            local okSize, size = pcall(function()
                return part.Size
            end)
            local okCollide, collide = pcall(function()
                return part.CanCollide
            end)
            if part:IsA("BasePart") and okCf and okSize and okCollide and collide then
                local delta = cf.Position - roblox.Vector3.new(site.x, 0, site.z)
                local horizontal = math.sqrt(delta.X ^ 2 + delta.Z ^ 2)
                if horizontal < 18 and math.abs(delta.Y) < 18 then
                    table.insert(near, { distance = horizontal, name = part.Name, position = cf.Position, size = size })
                end
            end
        end
    end
    table.sort(near, function(a, b)
        return a.distance < b.distance
    end)
    for i = 1, math.min(15, #near) do
        local part = near[i]
        print(
            ("%s dist=%.1f pos=%s size=%s"):format(
                part.name,
                part.distance,
                tostring(part.position),
                tostring(part.size)
            )
        )
    end
end
