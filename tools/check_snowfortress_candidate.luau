-- Validate the MyMap geometry candidate against Snow Fortress gameplay data.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
Color3, Enum, Vector3 = roblox.Color3, roblox.Enum, roblox.Vector3

local Validate = require("../src/shared/Maps/Validate")
local MapAuthoring = require("../src/shared/MapAuthoring")
local Weapons = require("../src/shared/Weapons")
local map = require("../src/shared/Maps/SnowFortress")
local roots = roblox.deserializeModel(fs.readFile(".mapbuild/SnowFortress-from-MyMap.rbxm"))
local solids, parts = MapAuthoring.solids(roots, Validate)
local ok, errors, warnings = Validate.check(map, Weapons, solids)
print(
    ("Snow Fortress candidate: %d parts, %d collidable solids, %d errors, %d warnings"):format(
        #parts,
        #solids,
        #errors,
        #warnings
    )
)
for _, issue in errors do
    print("ERROR: " .. issue)
end
for _, issue in warnings do
    print("warning: " .. issue)
end
assert(ok, "candidate geometry does not pass Snow Fortress validation")
