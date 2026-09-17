local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local roots = roblox.deserializeModel(fs.readFile("assets/weapons/Pistol.rbxm"))
local ws = roots[1]:FindFirstChild("WeaponsSystem")
fs.writeDir("tools/wsrc")
local function walk(inst, prefix)
    for _, c in inst:GetChildren() do
        if c:IsA("LuaSourceContainer") then
            fs.writeFile("tools/wsrc/" .. prefix .. c.Name .. ".lua", c.Source)
        end
        walk(c, prefix .. c.Name .. "_")
    end
end
walk(ws, "")
