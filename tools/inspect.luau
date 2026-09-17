local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local path = process.args[1]
local maxDepth = tonumber(process.args[2]) or 3
local roots = roblox.deserializeModel(fs.readFile(path))
local function walk(inst, d)
    local val = ""
    if inst:IsA("ValueBase") then
        val = " = " .. tostring(inst.Value)
    end
    if d <= maxDepth then
        print(string.rep("  ", d) .. inst.ClassName .. " " .. inst.Name .. val)
    end
    for _, c in inst:GetChildren() do
        walk(c, d + 1)
    end
end
for _, r in roots do
    walk(r, 0)
end
