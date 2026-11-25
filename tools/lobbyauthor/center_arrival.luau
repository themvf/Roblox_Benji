-- Move the five existing lobby spawn markers into the central arrival mist.
-- Run once, then run `lune run tools/lobby.luau convert` to refresh the playable copy.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum

local Reader = require("../../src/shared/LobbyAuthoring")
local base = require("../../src/shared/Maps/Lobby")
local source = "assets/environment/source/Lobby.rbxm"
local backupDir = ".mapbuild/lobby-center-mist"
local backup = backupDir .. "/Lobby-before-center-arrival.rbxm"
local bytes = fs.readFile(source)
local roots = roblox.deserializeModel(bytes)
assert(#roots == 1, "expected one editable lobby model")
local root = roots[1]
local markers = root.Authoring.Spawns
local origin = base.Origin

for index, point in base.Spawns do
    local marker = assert(markers:FindFirstChild(tostring(index)), "missing lobby spawn marker " .. index)
    marker.CFrame = roblox.CFrame.new(origin[1] + point[1], origin[2] + point[2], origin[3] + point[3])
end

local layout, errors = Reader.read(root, base)
assert(layout, table.concat(errors, "; "))
for index, point in base.Spawns do
    for axis, value in point do
        assert(math.abs(layout.Spawns[index][axis] - value) < 0.001, "spawn marker did not move")
    end
end

fs.writeDir(backupDir)
if not fs.isFile(backup) then
    fs.writeFile(backup, bytes)
end
fs.writeFile(source, roblox.serializeModel({ root }))
print("Moved five lobby spawn markers into the central arrival area; original source backed up")
