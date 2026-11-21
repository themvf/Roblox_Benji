-- Generates MaterialVariants.rbxm for Roblox Studio MaterialService one-click import.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Enum, Instance = roblox.Enum, roblox.Instance

local folder = Instance.new("Folder")
folder.Name = "IndustrialFoundryMaterials"

local defs = {
	{
		name = "Ind_ConcreteFloor",
		base = Enum.Material.Concrete,
		studs = 14,
		color = "rbxassetid://121723371555002",
		normal = "rbxassetid://88383592969535",
		roughness = "rbxassetid://129650011003939",
		metalness = "rbxassetid://73167221630017",
	},
	{
		name = "Ind_GunmetalWall",
		base = Enum.Material.Metal,
		studs = 12,
		color = "rbxassetid://140402221082596",
		normal = "rbxassetid://127277854519294",
		roughness = "rbxassetid://78605493761422",
		metalness = "rbxassetid://128478406431585",
	},
	{
		name = "Ind_DiamondTread",
		base = Enum.Material.DiamondPlate,
		studs = 8,
		color = "rbxassetid://130171604412391",
		normal = "rbxassetid://106966685051394",
		roughness = "rbxassetid://80323098606652",
		metalness = "rbxassetid://92666831235355",
	},
	{
		name = "Ind_ForgeSootMetal",
		base = Enum.Material.Basalt,
		studs = 12,
		color = "rbxassetid://123501650022379",
		normal = "rbxassetid://103123402360357",
		roughness = "rbxassetid://111100047933715",
		metalness = "rbxassetid://70470329673720",
	},
}

for _, def in defs do
	local mv = Instance.new("MaterialVariant")
	mv.Name = def.name
	mv.BaseMaterial = def.base
	mv.StudsPerTile = def.studs
	mv.ColorMap = def.color
	mv.NormalMap = def.normal
	mv.RoughnessMap = def.roughness
	mv.MetalnessMap = def.metalness
	mv:SetAttribute("TextureFolder", "assets/environment/materials/industrial-foundry-v1/" .. def.name)
	mv.Parent = folder
end

local outPath = "assets/environment/materials/industrial-foundry-v1/MaterialVariants.rbxm"
fs.writeFile(outPath, roblox.serializeModel({ folder }))
print("Saved Studio MaterialService preset:", outPath)
