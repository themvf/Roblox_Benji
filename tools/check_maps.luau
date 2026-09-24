-- Build gate: validates every arena layout in src/shared/Maps against the map spec.
-- Run: lune run tools/check_maps.luau     (exit code 1 on any failure)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Map data uses these as globals. Lune has no Roblox globals, so publish them first.
Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Validate = require("../src/shared/Maps/Validate")
local Baked = require("./bakedsolids")
local Weapons = require("../src/shared/Weapons")

local dir = "src/shared/Maps"
-- Not arena layouts: the validator itself, and the lobby (its own schema, built by buildLobby).
local SKIP = { ["Validate.lua"] = true, ["Lobby.lua"] = true }

-- Derived maps (Snow) do `require(script.Parent.Forest)`. Give them a `script` to walk and a
-- `require` that hands back an already-loaded layout table.
local preloaded = {}
script = { Parent = preloaded }
local luneRequire = require
require = function(target)
    if type(target) == "table" then
        return target
    end
    return luneRequire(target)
end

local files = fs.readDir(dir)
table.sort(files)

local checked, failures = 0, 0
for _, file in files do
    if file:sub(-4) == ".lua" and not SKIP[file] then
        checked += 1
        local layout = luneRequire("../" .. dir .. "/" .. file:sub(1, -5))
        -- Where a map is baked, check the geometry that actually ships. It carries
        -- collision the layout never described -- the facade kit authors 282 parts on
        -- Snow Fortress alone -- so tracing against it is stricter, not looser.
        local solids = Baked.load(layout.Name or file:sub(1, -5), Validate)
        local ok, errors, warnings, info = Validate.check(layout, Weapons, solids)
        if ok then
            print(
                ("OK    %-10s %4d solids  %d pads  %d pickups  %d warnings"):format(
                    layout.Name or file,
                    info.Solids,
                    info.LaunchPads,
                    info.Pickups,
                    #warnings
                )
            )
        else
            failures += 1
            print(("FAIL  %s"):format(file))
            for _, e in errors do
                print("        ERROR   " .. e)
            end
        end
        for _, w in warnings do
            print("        warning " .. w)
        end
    end
end

print(("\n%d maps checked, %d failed"):format(checked, failures))
if failures > 0 then
    process.exit(1)
end
