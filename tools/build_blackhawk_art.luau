-- Persist approved BlackHawk meshes (asset 106361454815274) in Rojo; no runtime InsertService dependency.
local fs = require("@lune/fs")
local r = require("@lune/roblox")

local SCALE = 0.56 -- fits ~28.4 x 24.2 x 8.4 studs cleanly inside the 28x28 Red/Blue helipads & spawn walls
local YAW_FIX = r.CFrame.Angles(0, math.pi / 2, 0) -- rotate +X nose to -Z forward matching VehicleSeat

local root = r.Instance.new("Folder")
root.Name = "BlackHawk"

local MAPS = {
	ColorMap = "140185784642926",
	RoughnessMap = "119735082987711",
	MetalnessMap = "92775384725824",
}

local TILES = {
	{
		name = "geometry_0.002",
		mesh = "88936026256429",
		size = { 6.344444274902344, 10.121155738830567, 9.150156021118164 },
		rel = { 22.20555877685547, 6.462747097015381, -4.575079917907715 },
	},
	{
		name = "geometry_0.003",
		mesh = "83553914183485",
		size = { 2.7572364807128908, 3.375082015991211, 3.4755077362060549 },
		rel = { 20.411954879760743, 3.0851221084594728, 1.7377519607543946 },
	},
	{
		name = "geometry_0.006",
		mesh = "70497671814681",
		size = { 6.344446182250977, 11.5181884765625, 6.408200263977051 },
		rel = { 15.861113548278809, 5.802401542663574, -3.204101085662842 },
	},
	{
		name = "geometry_0.007",
		mesh = "88772099131224",
		size = { 6.34444522857666, 8.145196914672852, 5.503056526184082 },
		rel = { 15.861114501953125, 4.0930986404418949, 2.751526355743408 },
	},
	{
		name = "geometry_0.010",
		mesh = "105916409940317",
		size = { 6.344446659088135, 12.33913803100586, 6.358069896697998 },
		rel = { 9.516668319702149, 6.16956901550293, -3.1790354251861574 },
	},
	{
		name = "geometry_0.011",
		mesh = "132452452574812",
		size = { 6.344529628753662, 12.310279846191407, 5.511000633239746 },
		rel = { 9.516627311706543, 6.179128646850586, 2.7554991245269777 },
	},
	{
		name = "geometry_0.013",
		mesh = "125362577404543",
		size = { 4.149351119995117, 0.5837249755859375, 10.814711570739746 },
		rel = { 3.431835651397705, 11.246118545532227, -16.222068786621095 },
	},
	{
		name = "geometry_0.014",
		mesh = "90070969456809",
		size = { 6.344445705413818, 11.13952350616455, 10.814714431762696 },
		rel = { 3.172222375869751, 7.0465874671936039, -5.407357215881348 },
	},
	{
		name = "geometry_0.015",
		mesh = "118186578576415",
		size = { 6.344445705413818, 11.117477416992188, 10.814714431762696 },
		rel = { 3.172222852706909, 7.052512168884277, 5.407356262207031 },
	},
	{
		name = "geometry_0.016",
		mesh = "102437258443708",
		size = { 2.624387741088867, 0.5118246078491211, 10.774870872497559 },
		rel = { 3.8878302574157717, 11.273849487304688, 16.2021484375 },
	},
	{
		name = "geometry_0.018",
		mesh = "140552896074897",
		size = { 6.34444522857666, 9.90903377532959, 4.489259243011475 },
		rel = { -3.17222261428833, 6.616867542266846, -2.244629144668579 },
	},
	{
		name = "geometry_0.019",
		mesh = "98598389408632",
		size = { 6.344445705413818, 9.968847274780274, 4.464123249053955 },
		rel = { -3.172222375869751, 6.638132095336914, 2.2320616245269777 },
	},
	{
		name = "geometry_0.022",
		mesh = "79645438496195",
		size = { 6.344446182250977, 10.355203628540039, 1.8060076236724854 },
		rel = { -9.516668319702149, 6.362292289733887, -0.9030026197433472 },
	},
	{
		name = "geometry_0.023",
		mesh = "81074695474833",
		size = { 6.344446182250977, 10.348934173583985, 1.8563669919967652 },
		rel = { -9.516668319702149, 6.352760314941406, 0.9281839728355408 },
	},
	{
		name = "geometry_0.026",
		mesh = "136699123818949",
		size = { 6.34444522857666, 11.161356925964356, 6.095433235168457 },
		rel = { -15.861114501953125, 5.8680100440979, -3.047715187072754 },
	},
	{
		name = "geometry_0.027",
		mesh = "116909858716202",
		size = { 6.34444522857666, 14.728612899780274, 6.156094551086426 },
		rel = { -15.861114501953125, 7.6342878341674809, 3.0780482292175295 },
	},
	{
		name = "geometry_0.030",
		mesh = "109086968469211",
		size = { 3.266876220703125, 7.861366271972656, 5.801339149475098 },
		rel = { -20.66677474975586, 6.847928047180176, -2.900667667388916 },
	},
	{
		name = "geometry_0.031",
		mesh = "87139002550056",
		size = { 6.344444274902344, 11.918087005615235, 5.779484748840332 },
		rel = { -22.20555877685547, 8.930158615112305, 2.8897440433502199 },
	},
}

for _, tile in ipairs(TILES) do
	local p = r.Instance.new("MeshPart")
	p.Name = tile.name
	p.MeshContent = r.Content.fromUri("rbxassetid://" .. tile.mesh)
	p.InitialSize = r.Vector3.new(tile.size[1], tile.size[2], tile.size[3])
	p.Size = r.Vector3.new(tile.size[1] * SCALE, tile.size[2] * SCALE, tile.size[3] * SCALE)
	-- Rotate +pi/2 around Y: (x, y, z) -> (z, y, -x), putting +X nose at -Z forward
	p.CFrame = r.CFrame.new(tile.rel[3] * SCALE, tile.rel[2] * SCALE, -tile.rel[1] * SCALE) * YAW_FIX
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.DoubleSided = false
	p.CollisionFidelity = r.Enum.CollisionFidelity.Box
	-- Preserve full detail without Automatic LOD sharding
	p.RenderFidelity = r.Enum.RenderFidelity.Precise
	p.Color = r.Color3.new(1, 1, 1)

	local surface = r.Instance.new("SurfaceAppearance")
	surface.AlphaMode = r.Enum.AlphaMode.Overlay
	for property, asset in pairs(MAPS) do
		surface[property .. "Content"] = r.Content.fromUri("rbxassetid://" .. asset)
	end
	surface.Parent = p
	p.Parent = root
end

fs.writeDir("assets/environment/runtime")
fs.writeFile("assets/environment/runtime/BlackHawk.rbxm", r.serializeModel({ root }))
print("Built BlackHawk.rbxm mesh templates (18 tiles, RenderFidelity=Precise, scale=" .. tostring(SCALE) .. ")")
