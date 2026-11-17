-- Current public arena contract: one designer-built map (MyMap), two rule layouts.
-- MyMapPublic promotes the generated draft; MyMapTDM is the same arena without objectives.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3
local Config = require("../src/shared/Config")
local source = require("../src/shared/Maps/MyMap")

local luneRequire = require
require = function(target)
    return type(target) == "table" and target or luneRequire(target)
end
script = { Parent = { MyMap = source } }
local public = luneRequire("../src/shared/Maps/MyMapPublic")
script = { Parent = { MyMapPublic = public } }
local tdm = luneRequire("../src/shared/Maps/MyMapTDM")

local function only(list, name)
    assert(#list == 1 and list[1] == name, name .. " must be the sole public map in this mode")
end

only(Config.Maps, "MyMapPublic")
only(Config.ConvergenceMaps, "MyMapPublic")
only(Config.TDMMaps, "MyMapTDM")
assert(Config.StartupMap == "MyMapPublic", "the server must start on the public map")
assert(public.Draft == nil and public.Authored == nil, "the public release must not be a draft")
assert(#public.Objectives == 3 and public.Finale, "the three objective layout must remain intact")
assert(tdm.Mode == "TDM" and tdm.Objectives == nil and tdm.Finale == nil, "TDM must have no capture objectives")
assert(public.BakedMap == source.Name and tdm.BakedMap == source.Name, "both modes must use MyMap's bake")
assert(fs.isFile("assets/environment/baked/MyMap.rbxm"), "MyMap's bake is missing")
for _, team in { "Red", "Blue" } do
    assert(#tdm.Spawns[team] >= 5, team .. " needs at least five TDM spawns")
    for i, point in source.Spawns[team] do
        for axis, value in point do
            assert(public.Spawns[team][i][axis] == value, "public spawns must match the authored layout")
            assert(tdm.Spawns[team][i][axis] == value, "TDM spawns must match the authored layout")
        end
    end
end

print("PASS: MyMap is the sole public arena for Duel, objective and TDM; TDM has no capture objectives")
