-- Write the opening state of a map's .rbxm: ground, and a wall around it.
--
-- A map whose geometry lives in a .rbxm has a chicken-and-egg problem on day one. The
-- module says RequiresBake, so the map refuses to load without a bake; the bake is made
-- in Studio, so it does not exist until someone has already built something. Between
-- those two the game will not start, and the failure looks like the map being broken
-- rather than the map being new.
--
-- So the bake starts here, with the least that is still a place you can stand: a floor
-- and a boundary. Everything after this comes out of Studio and overwrites it.
--
-- This runs ONCE per map, to create the file. It is not a gate and nothing calls it
-- automatically -- re-running it would throw away whatever has been built since.
--
--     lune run tools/build_starter_bake.luau Crucible
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

local name = process.args[1]
if not name then
    error("usage: lune run tools/build_starter_bake.luau <MapName>", 0)
end

local modulePath = ("src/shared/Maps/%s.lua"):format(name)
if not fs.isFile(modulePath) then
    error(("no map module at %s -- write the data file first"):format(modulePath), 0)
end

local out = ("assets/environment/baked/%s.rbxm"):format(name)
if fs.isFile(out) then
    error(
        ("%s already exists. This tool only creates the FIRST bake; overwriting it would "):format(out)
            .. "discard everything built in Studio since. Delete the file by hand if that is really what you want.",
        0
    )
end

-- Read the map's own Bounds rather than hardcoding a size, so the floor is the arena and
-- the walls line up with the barrier the map rebuilds at runtime.
local source = fs.readFile(modulePath)
local minx, minz = source:match("Bounds%s*=%s*{%s*min%s*=%s*{%s*(%-?[%d%.]+)%s*,%s*%-?[%d%.]+%s*,%s*(%-?[%d%.]+)")
if not minx then
    error(("could not read Bounds.min out of %s"):format(modulePath), 0)
end
local halfX, halfZ = math.abs(tonumber(minx)), math.abs(tonumber(minz))

local model = roblox.Instance.new("Model")
model.Name = name

local function block(partName, size, cf, colour, material)
    local p = roblox.Instance.new("Part")
    p.Name = partName
    p.Anchored = true
    p.CanCollide = true
    p.Material = material
    p.Color = colour
    p.Size = size
    p.CFrame = cf
    p.Parent = model
    return p
end

local floor = Color3.fromRGB(180, 184, 190)
local wall = Color3.fromRGB(102, 110, 122)

-- The floor, top at y 0. Every kit piece is recentred with its base at y 0, so a piece
-- dropped at ground level lands exactly on this rather than 4 studs into it.
block(
    "ExteriorFloor",
    Vector3.new(halfX * 2, 1, halfZ * 2),
    CFrame.new(0, -0.5, 0),
    floor,
    roblox.Enum.Material.SmoothPlastic
)

-- Solid walls on the boundary. The runtime barrier at the same place is a force field and
-- stops players; this is what stops the eye, so the map does not read as a slab floating
-- in sky. Both exist because they do different jobs.
local h = 12
for _, side in { -1, 1 } do
    block(
        ("BoundaryWallX%d"):format(side),
        Vector3.new(2, h, halfZ * 2),
        CFrame.new(side * halfX, h / 2, 0),
        wall,
        roblox.Enum.Material.SmoothPlastic
    )
    block(
        ("BoundaryWallZ%d"):format(side),
        Vector3.new(halfX * 2, h, 2),
        CFrame.new(0, h / 2, side * halfZ),
        wall,
        roblox.Enum.Material.SmoothPlastic
    )
end

fs.writeFile(out, roblox.serializeModel({ model }))
print(("OK  %s -- floor %d x %d studs, top at y 0, walls %d high"):format(out, halfX * 2, halfZ * 2, h))
print("Open it in Studio, build on it, and Save to File back over the same path.")
