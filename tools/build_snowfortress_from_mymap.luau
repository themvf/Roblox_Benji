-- Build a SnowFortress geometry candidate from the Studio-authored MyMap source.
-- The source was authored around Z=-145; gameplay data uses Z=0. Preserve the
-- source and move only the baked geometry. This does not change the live map.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local source = "assets/environment/source/MyMap.rbxm"
local output = ".mapbuild/SnowFortress-from-MyMap.rbxm"
local roots = roblox.deserializeModel(fs.readFile(source))
assert(#roots == 1, "MyMap source must contain exactly one root")
local root = roots[1]
assert(root:GetAttribute("MapSource") == "MyMap", "source is not the editable MyMap")

local authoring = assert(root:FindFirstChild("Authoring"), "missing Authoring markers")
local bounds = assert(authoring:FindFirstChild("Bounds"), "missing map boundary")
local geometry = assert(root:FindFirstChild("Geometry"), "missing Geometry folder")
local boundsPos = bounds.CFrame.Position
local delta = roblox.Vector3.new(-boundsPos.X, 0, -boundsPos.Z)
assert(math.abs(delta.X) < 1 and math.abs(delta.Z - 145) < 2, "unexpected MyMap placement")

local function near(actual, expected, label)
    assert((actual - expected).Magnitude < 2, label .. " no longer matches Snow Fortress")
end

local objectives = assert(authoring:FindFirstChild("Objectives"), "missing objectives")
for name, expected in
    {
        A = roblox.Vector3.new(0, 0, -128),
        B = roblox.Vector3.new(0, 0, 128),
        C = roblox.Vector3.new(0, 0, 0),
    }
do
    local marker = assert(objectives:FindFirstChild(name), "missing objective " .. name)
    local capture = assert(marker:FindFirstChild("Capture"), "missing capture part for objective " .. name)
    local pos = capture.CFrame.Position + delta
    near(roblox.Vector3.new(pos.X, 0, pos.Z), expected, "objective " .. name)
end

local spawns = assert(authoring:FindFirstChild("Spawns"), "missing spawns")
for team, x in { Blue = -210, Red = 210 } do
    local folder = assert(spawns:FindFirstChild(team), "missing " .. team .. " spawns")
    assert(#folder:GetChildren() == 6, team .. " must have six spawns")
    for _, marker in folder:GetChildren() do
        local pos = marker.CFrame.Position + delta
        assert(math.abs(pos.X - x) < 2 and math.abs(pos.Z) <= 22, team .. " spawn moved from fortress start")
    end
end

local bake = roblox.Instance.new("Folder")
bake.Name = "SnowFortress"
local copy = geometry:Clone()
copy.Parent = bake
local parts = 0
for _, inst in copy:GetDescendants() do
    if inst:IsA("LuaSourceContainer") then
        error("map geometry contains a script: " .. inst:GetFullName())
    end
    if inst:IsA("BasePart") then
        inst.CFrame = roblox.CFrame.new(delta) * inst.CFrame
        parts += 1
    end
end
assert(parts > 100, "candidate unexpectedly empty")
fs.writeFile(output, roblox.serializeModel({ bake }))
print(("Candidate: %s (%d parts; translated %.2f studs X, %.2f studs Z)"):format(output, parts, delta.X, delta.Z))
