-- Paste into Studio's Command Bar (View > Command Bar) and press Enter. It loads the uploaded
-- Lightning Carbine and prints studio_import.json for tools/build_weapons.luau. Copy the
-- printed line from the Output window back to Claude. Nothing is left in the place.
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local ASSET_ID = 120268419196134

local root = InsertService:LoadAsset(ASSET_ID)
local centre = root:GetBoundingBox()
local function round(v)
	return { math.round(v.X * 1e4) / 1e4, math.round(v.Y * 1e4) / 1e4, math.round(v.Z * 1e4) / 1e4 }
end
local parts = {}
for _, part in root:GetDescendants() do
	if part:IsA("MeshPart") then
		table.insert(parts, {
			name = part.Name,
			meshId = part.MeshId,
			textureId = part.TextureID,
			size = round(part.Size),
			offset = round(centre:PointToObjectSpace(part.Position)),
		})
	end
end
root:Destroy()
print(HttpService:JSONEncode({
	source = "InsertService:LoadAsset(" .. ASSET_ID .. "), the model publish uploaded on 2026-11-23; offsets are from the model's bounding-box centre (the export's centre), Roblox axes, -Z forward. Arc is made Neon by tools/build_weapons.luau",
	assetId = ASSET_ID,
	parts = parts,
}))
