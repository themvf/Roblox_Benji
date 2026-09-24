-- Writes the two kit pieces that are generated rather than cut out of a map: the ground
-- to stand things on, and a guide showing where the gameplay anchors are.
--
-- Placing geometry against an empty void is guesswork. The guide puts the bounds, the
-- three objective circles, both spawn lines and the centre in the viewport, so a fortress
-- goes down in a place that means something rather than wherever the drag ended.
--
-- The GUIDE is legacy and visual only: nothing ever read its positions back. New maps
-- start from the Convergence template instead (tools/mapauthor/template.luau via
-- `bash tools/save_map.sh new <Name>`), whose markers ARE the map data. The converter
-- and check_bake both refuse a map that has a GUIDE dragged into it.
--
--     lune run tools/build_guide.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3
local OUT = "assets/environment/kit"

-- Snow Fortress's numbers, as a starting point. Every one of these is meant to be moved.
local BOUNDS = { x = 245, z = 185 }
local OBJECTIVES = {
    { name = "Objective_A_North", pos = { 0, 0, -128 }, radius = 18 },
    { name = "Objective_B_South", pos = { 0, 0, 128 }, radius = 18 },
    { name = "Objective_C_Centre", pos = { 0, 18, 0 }, radius = 18 },
}
local SPAWNS = { { "Spawn_Blue_West", -210 }, { "Spawn_Red_East", 210 } }

local function part(parent, name, size, cf, colour, transparency)
    local p = roblox.Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = roblox.Enum.Material.Neon
    p.Color = colour
    p.Transparency = transparency or 0.6
    p.Size = size
    p.CFrame = cf
    p.Parent = parent
    return p
end

-- ===== Ground =====
local ground = roblox.Instance.new("Model")
ground.Name = "Ground"
local slab = roblox.Instance.new("Part")
slab.Name = "ExteriorFloor"
slab.Anchored = true
slab.CanCollide = true
slab.Material = roblox.Enum.Material.SmoothPlastic
slab.Color = Color3.fromRGB(180, 184, 190)
slab.Size = Vector3.new(BOUNDS.x * 2, 1, BOUNDS.z * 2)
slab.CFrame = CFrame.new(0, -0.5, 0)
slab.Parent = ground
fs.writeFile(OUT .. "/Ground.rbxm", roblox.serializeModel({ ground }))
print(("OK    Ground        one slab, %d x %d studs, top at y 0"):format(BOUNDS.x * 2, BOUNDS.z * 2))

-- ===== Guide =====
local guide = roblox.Instance.new("Model")
guide.Name = "GUIDE"

local white = Color3.fromRGB(255, 255, 255)
local amber = Color3.fromRGB(255, 196, 70)
local blue = Color3.fromRGB(110, 170, 255)
local red = Color3.fromRGB(255, 120, 120)

-- bounds outline
for _, side in { -1, 1 } do
    part(guide, "Bound_X" .. side, Vector3.new(2, 8, BOUNDS.z * 2), CFrame.new(side * BOUNDS.x, 4, 0), white, 0.75)
    part(guide, "Bound_Z" .. side, Vector3.new(BOUNDS.x * 2, 8, 2), CFrame.new(0, 4, side * BOUNDS.z), white, 0.75)
end

-- objective circles: a flat disc at the capture radius, plus a pole so it reads from afar
for _, o in OBJECTIVES do
    local at = Vector3.new(o.pos[1], o.pos[2], o.pos[3])
    local disc = part(
        guide,
        o.name,
        Vector3.new(0.5, o.radius * 2, o.radius * 2),
        CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
        amber,
        0.65
    )
    disc.Shape = roblox.Enum.PartType.Cylinder
    part(guide, o.name .. "_Pole", Vector3.new(1, 40, 1), CFrame.new(at + Vector3.new(0, 20, 0)), amber, 0.5)
end

-- spawn lines: six pads per team, as Snow Fortress has
for _, s in SPAWNS do
    local name, x = s[1], s[2]
    local colour = x < 0 and blue or red
    for i, z in { -20, -12, -4, 4, 12, 20 } do
        part(guide, ("%s_%d"):format(name, i), Vector3.new(6, 0.5, 6), CFrame.new(x, 0.25, z), colour, 0.4)
    end
end

-- centre
part(guide, "Centre", Vector3.new(4, 0.5, 4), CFrame.new(0, 0.25, 0), white, 0.3)
part(guide, "Centre_Pole", Vector3.new(0.8, 60, 0.8), CFrame.new(0, 30, 0), white, 0.6)

fs.writeFile(OUT .. "/GUIDE.rbxm", roblox.serializeModel({ guide }))
local n = 0
local function count(i)
    n += 1
    for _, c in i:GetChildren() do
        count(c)
    end
end
count(guide)
print(("OK    GUIDE         %d markers: bounds, 3 objectives, 12 spawn pads, centre"):format(n - 1))
print("\nBoth written to " .. OUT)
