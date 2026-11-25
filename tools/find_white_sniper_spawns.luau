local roblox = require("@lune/roblox")
Color3, Enum, Vector3 = roblox.Color3, roblox.Enum, roblox.Vector3
local Validate = require("../src/shared/Maps/Validate")
local Baked = require("./bakedsolids")
local Weapons = require("../src/shared/Weapons")
local source = require("../src/shared/Maps/MyMap")
script = { Parent = { MyMap = source } }
local rawRequire = require
require = function(target)
    if type(target) == "table" then
        return target
    end
    return rawRequire(target)
end
local map = rawRequire("../src/shared/Maps/MyMapPublic")
local solids = Baked.load("MyMap", Validate)
for _, x in { 190, 180, 170, 160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60 } do
    for _, z in { -200, -180, -160, -145, -130, -110, -90, -70 } do
        map.Pickups[1].pos = { -x, 1.596, z }
        map.Pickups[2].pos = { x, 1.596, z }
        local ok = Validate.check(map, Weapons, solids)
        if ok then
            print(("SAFE symmetric ±%d, 1.596, %d"):format(x, z))
        end
    end
end
