-- Persist approved MilitaryWaveRunner meshes (asset 102870506274928) in Rojo; no runtime InsertService dependency.
local fs = require("@lune/fs")
local r = require("@lune/roblox")

local SCALE = 0.80
local Y_SHIFT = -1.10 -- seat keel naturally into Y=0 sea beneath the Hull (spawned at Y=0.35)
-- No yaw fix. Roblox imports glTF turned half a turn, so the bow (glTF +Z) already sits at Roblox -Z,
-- which is the way VehicleSeat and the drive code face. Measured from the tile data: the handlebar
-- peak (4.53 tall) is in the z = -1.39 row and the low seat is behind it at +Z. An earlier 180-degree
-- turn here made the craft drive stern-first.

local root = r.Instance.new("Folder")
root.Name = "MilitaryWaveRunner"

local MAPS = {
	ColorMap = "85092293551185",
	RoughnessMap = "112248916807063",
	-- MetalnessMap ("138972594578249") is left off on purpose. In game the craft rendered tan and gold
	-- although the colour map is dark olive (mean RGB 40, 42, 36): a metal surface takes its colour
	-- from what it reflects, here bright sand and sky. Without the map it is plain painted material.
}

local TILES = {
	{
		name = "geometry_0.001",
		mesh = "136790609495580",
		size = { 1.8748300075531006, 3.0192553997039797, 2.7146155834198 },
		rel = { 1.8882883787155152, 2.13616943359375, -4.143362522125244 },
	},
	{
		name = "geometry_0.002",
		mesh = "104459915267468",
		size = { 1.9019718170166016, 4.344330787658691, 2.786055088043213 },
		rel = { 1.9019100666046143, 2.23431396484375, -1.3930275440216065 },
	},
	{
		name = "geometry_0.003",
		mesh = "106772631853126",
		size = { 1.5763399600982667, 2.5410470962524416, 2.786055088043213 },
		rel = { 1.7391353845596314, 1.35150146484375, 1.3930273056030274 },
	},
	{
		name = "geometry_0.004",
		mesh = "74049081563523",
		size = { 1.3920457363128663, 2.2198987007141115, 2.7734251022338869 },
		rel = { 1.6469885110855103, 1.70635986328125, 4.172767162322998 },
	},
	{
		name = "geometry_0.005",
		mesh = "124490272484502",
		size = { 1.9019310474395753, 3.3623971939086916, 2.786055326461792 },
		rel = { -3.5762786865234377e-7, 2.12213134765625, -4.17908239364624 },
	},
	{
		name = "geometry_0.006",
		mesh = "82749722578374",
		size = { 1.9019310474395753, 4.53359842300415, 2.78615140914917 },
		rel = { -1.1920928955078126e-7, 2.26678466796875, -1.3929791450500489 },
	},
	{
		name = "geometry_0.007",
		mesh = "75064034244473",
		size = { 1.9019310474395753, 4.359973907470703, 2.786055088043213 },
		rel = { 1.1920928955078126e-7, 2.250244140625, 1.393027424812317 },
	},
	{
		name = "geometry_0.008",
		mesh = "71864356917357",
		size = { 1.9019463062286378, 3.40236759185791, 2.7860968112945558 },
		rel = { 0.000008016824722290039, 2.1856689453125, 4.1790618896484379 },
	},
	{
		name = "geometry_0.009",
		mesh = "74827792440178",
		size = { 1.86220383644104, 3.01420259475708, 2.713273048400879 },
		rel = { -1.8820675611495972, 2.13525390625, -4.142691135406494 },
	},
	{
		name = "geometry_0.010",
		mesh = "82111238221764",
		size = { 1.9019310474395753, 4.353794097900391, 2.786055088043213 },
		rel = { -1.9019309282302857, 2.23602294921875, -1.3930273056030274 },
	},
	{
		name = "geometry_0.011",
		mesh = "115706666540431",
		size = { 1.5664751529693604, 2.5238420963287355, 2.786055088043213 },
		rel = { -1.7342027425765992, 1.364013671875, 1.3930275440216065 },
	},
	{
		name = "geometry_0.012",
		mesh = "88217193889776",
		size = { 1.3907674551010132, 2.2319769859313967, 2.763871431350708 },
		rel = { -1.6463069915771485, 1.7080078125, 4.167949199676514 },
	},
}

for _, tile in ipairs(TILES) do
	local p = r.Instance.new("MeshPart")
	p.Name = tile.name
	p.MeshContent = r.Content.fromUri("rbxassetid://" .. tile.mesh)
	p.InitialSize = r.Vector3.new(tile.size[1], tile.size[2], tile.size[3])
	p.Size = r.Vector3.new(tile.size[1] * SCALE, tile.size[2] * SCALE, tile.size[3] * SCALE)
	p.CFrame = r.CFrame.new(tile.rel[1] * SCALE, tile.rel[2] * SCALE + Y_SHIFT, tile.rel[3] * SCALE)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	-- The generated mesh is thin open shells, not a sealed solid (204,735 open edges at source), so
	-- with one-sided drawing you look through every gap and see nothing behind it. Blender draws both
	-- sides, which is why the local renders looked solid and the game did not.
	p.DoubleSided = true
	p.CollisionFidelity = r.Enum.CollisionFidelity.Box
	-- Automatic lets the engine swap in its generated low-detail mesh, and on a dense
	-- image-to-3D mesh that version is shards and smeared texture (seen in game on
	-- 2026-11-16). Precise always draws the uploaded triangles. Only a model file can
	-- carry this: scripts cannot write RenderFidelity at runtime.
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
if fs.isFile("assets/environment/runtime/MilitaryWaveRunner.rbxmx") then
	fs.removeFile("assets/environment/runtime/MilitaryWaveRunner.rbxmx")
end
fs.writeFile("assets/environment/runtime/MilitaryWaveRunner.rbxm", r.serializeModel({ root }))
print("Built MilitaryWaveRunner mesh templates (12 tiles, scale=" .. tostring(SCALE) .. ")")
