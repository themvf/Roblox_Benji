-- Generates MaterialVariants.rbxm for Roblox Studio MaterialService import (Desert Ridge).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Enum, Instance = roblox.Enum, roblox.Instance

local folder = Instance.new("Folder")
folder.Name = "DesertRidgeMaterials"

local defs = {
    {
        name = "Desert_Sandstone",
        base = Enum.Material.Rock,
        studs = 24,
    },
    {
        name = "Desert_SandstoneDark",
        base = Enum.Material.Basalt,
        studs = 28,
    },
    {
        name = "Desert_Boulder",
        base = Enum.Material.Slate,
        studs = 12,
    },
    {
        name = "Desert_SandFloor",
        base = Enum.Material.Sand,
        studs = 18,
    },
}

for _, def in defs do
    local mv = Instance.new("MaterialVariant")
    mv.Name = def.name
    mv.BaseMaterial = def.base
    mv.StudsPerTile = def.studs
    mv:SetAttribute("TextureFolder", "assets/environment/materials/desert-ridge-v1/" .. def.name)
    mv.Parent = folder
end

local outPath = "assets/environment/materials/desert-ridge-v1/MaterialVariants.rbxm"
fs.writeFile(outPath, roblox.serializeModel({ folder }))
print("Saved Studio MaterialService preset:", outPath)
