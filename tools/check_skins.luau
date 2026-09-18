-- Build gate: validates every skin in src/shared/Skins/Registry against the spec.
-- Run: lune run tools/check_skins.luau     (exit code 1 on any failure)
local fs = require("@lune/fs")
local process = require("@lune/process")
local Validate = require("../src/shared/Skins/Validate")
local Weapons = require("../src/shared/Weapons")

local dir = "src/shared/Skins/Registry"
local files = fs.readDir(dir)
table.sort(files)

local failures = 0
local seen = {}
for _, file in files do
    if file:sub(-4) == ".lua" then
        local skin = require("../" .. dir .. "/" .. file:sub(1, -5))
        local ok, errors, info = Validate.check(skin, Weapons)
        local expectName = (skin.Id or "?") .. ".lua"
        if file ~= expectName then
            ok = false
            table.insert(errors, "file name should be " .. expectName)
        end
        if skin.Id and seen[skin.Id] then
            ok = false
            table.insert(errors, "duplicate Id")
        end
        seen[skin.Id or file] = true

        if ok then
            print(("OK    %-32s %-9s %s"):format(skin.Id, skin.Tier, table.concat(info.Systems, ",")))
        else
            failures += 1
            print(("FAIL  %s"):format(file))
            for _, e in errors do
                print("        - " .. e)
            end
        end
    end
end

print(("\n%d skins checked, %d failed"):format(#files, failures))
if failures > 0 then
    process.exit(1)
end
