-- Dump the playable lobby as boxes for render_built.py, so the built model can be
-- compared with the concept renders. Run from the project root:
--
--   lune run docs/design/lobby-experience/hub-concept/dump_built.luau
--
-- Reads the baked lobby through the same marker reader as the game, then adds what
-- MapService draws from markers (pad halves and rings, leaderboard, kiosk, sign text).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum

local Reader = require("../../../../src/shared/LobbyAuthoring")
local base = require("../../../../src/shared/Maps/Lobby")

local root = roblox.deserializeModel(fs.readFile("assets/environment/baked/Lobby.rbxm"))[1]
local layout = assert(Reader.read(root, base))
local origin = Vector3.new(table.unpack(base.Origin))
local out = {}

local function colour(c)
	return { c.R, c.G, c.B }
end

local function add(shape, cframe, size, c, neon, extra)
	local p = cframe.Position - origin
	local item = {
		shape = shape,
		pos = { p.X, p.Y, p.Z },
		rot = { select(4, cframe:GetComponents()) },
		size = { size.X, size.Y, size.Z },
		colour = colour(c),
		neon = neon,
	}
	for k, v in extra or {} do
		item[k] = v
	end
	table.insert(out, item)
end

for _, part in layout.SourceGeometry:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 0.95 then
		local shape = "Block"
		if part:IsA("Part") then
			shape = part.Shape.Name
		end
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then
			shape = "Ball" -- a squashed sphere: a block drawn as one
		end
		add(shape, part.CFrame, part.Size, part.Color, part.Material == Enum.Material.Neon)
	elseif part:IsA("TextLabel") then
		local plate = part.Parent.Parent
		add("Text", plate.CFrame, plate.Size, part.TextColor3, true, { text = part.Text, flat = plate.Size.Y < 0.2 })
	end
end

local function at(p)
	return roblox.CFrame.new(origin + Vector3.new(p[1], p[2], p[3]))
end
local red, blue = Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 110, 230)
for _, spec in layout.Pads do
	if not spec.disabled then
		local pw, ph, pd = spec.size[1], spec.size[2], spec.size[3]
		add("Block", at({ spec.pos[1], 0.1, spec.pos[3] }), Vector3.new(pw + 3, 0.2, pd + 3), spec.color, true)
		local half = (pw - 1.5) / 2
		for _, side in { { -1, red }, { 1, blue } } do
			add(
				"Block",
				at({ spec.pos[1] + side[1] * (half + 1.5) / 2, ph / 2, spec.pos[3] }),
				Vector3.new(half, ph, pd),
				side[2],
				true
			)
		end
	end
end
-- Stations turn about their marker; their signs are on the -Z (Front) side.
local function turned(spec)
	return at(spec.pos) * roblox.CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
end
local b = layout.Board
local bf = turned({ pos = { b.pos[1], 0, b.pos[3] }, yaw = b.yaw })
add("Block", bf * roblox.CFrame.new(0, b.pos[2] + b.size[2] / 2, 0), Vector3.new(table.unpack(b.size)), base.Palette.Wall, false)
add(
	"Text",
	bf * roblox.CFrame.new(0, b.pos[2] + b.size[2] - 1, -b.size[3] / 2 - 0.1) * roblox.CFrame.Angles(0, math.pi, 0),
	Vector3.new(b.size[1], 1.6, 0.1),
	base.Palette.Accent,
	true,
	{ text = "LEADERBOARDS" }
)
local k = layout.Kiosk
local kf = turned({ pos = { k.pos[1], 0, k.pos[3] }, yaw = k.yaw })
add("Block", kf * roblox.CFrame.new(0, k.size[2] / 2, 0), Vector3.new(table.unpack(k.size)), base.Palette.Pillar, false)
add("Block", kf * roblox.CFrame.new(0, 7, -k.size[3] / 2 - 0.5), Vector3.new(k.size[1], 6, 1), base.Palette.Wall, false)
add(
	"Text",
	kf * roblox.CFrame.new(0, 7, -k.size[3] / 2 - 1.1) * roblox.CFrame.Angles(0, math.pi, 0),
	Vector3.new(k.size[1], 2.5, 0.1),
	base.Palette.Accent,
	true,
	{ text = "ARMORY" }
)
-- Billboard signs turn to face the viewer; draw them facing the arrival point.
for _, spec in layout.Wayfinding do
	local dx, dz = layout.Spawns[1][1] - spec.pos[1], layout.Spawns[1][3] - spec.pos[3]
	local c = typeof(spec.color) == "Color3" and spec.color or base.Palette[spec.color] or base.Palette.Accent
	add("Text", at(spec.pos), Vector3.new(spec.size[1], spec.size[2] * 0.6, 0.1), c, true, {
		text = spec.title,
		yaw = math.deg(math.atan2(dx, dz)),
	})
end

fs.writeDir("docs/design/lobby-experience/hub-concept/built")
fs.writeFile("docs/design/lobby-experience/hub-concept/built/built_parts.json", serde.encode("json", out))
print(("wrote %d pieces"):format(#out))
