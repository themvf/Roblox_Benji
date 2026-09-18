-- Build gate for celebrations. Run: lune run tools/check_celebrations.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local Validate = require("../src/shared/Celebrations/Validate")

local dir = "src/shared/Celebrations/Registry"
local files = fs.readDir(dir)
table.sort(files)
local failures = 0
for _, file in files do
    if file:sub(-4) == ".lua" then
        local cel = require("../" .. dir .. "/" .. file:sub(1, -5))
        local ok, errors, info = Validate.check(cel)
        if file ~= (cel.Id or "?") .. ".lua" then
            ok = false
            table.insert(errors, "file name should be " .. tostring(cel.Id) .. ".lua")
        end
        if ok then
            print(("OK    %-24s %-9s %ss  %s"):format(cel.Id, cel.Tier, cel.Length, table.concat(info.Systems, ",")))
        else
            failures += 1
            print("FAIL  " .. file)
            for _, e in errors do
                print("        - " .. e)
            end
        end
    end
end
print(("\n%d celebrations checked, %d failed"):format(#files, failures))
if failures > 0 then
    process.exit(1)
end
