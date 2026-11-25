-- After importing CargoWrecked.glb in Studio, select only that unit and run this
-- in the Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected unit only; it does not publish or save the place.
--
-- The current clean rebuild imports as one MeshPart. Select its Model or MeshPart.
-- The previous four-tile voxel export lives in trials/ and is not the delivery file.
--
-- Provisional role: non-colliding decoration. SOLID = true makes the tiles collide.
-- It still ignores raycasts: cover players rely on for gunfights belongs in the
-- map's Lua blocks, not in decor. Box collision is a poor fit here because the front
-- is blown out and players read the opening as walk-in space, so a solid build uses
-- a hollow CollisionFidelity (HOLLOW = true) at a real physics cost.
local SOLID = false
local HOLLOW = true
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported cargo unit (its Model)")
local unit = selected[1]
assert(unit:IsA("Model") or unit:IsA("MeshPart"), "Select the imported Model or MeshPart")
local parts = {}
if unit:IsA("BasePart") then
	table.insert(parts, unit)
end
for _, descendant in unit:GetDescendants() do
	if descendant:IsA("BasePart") then
		table.insert(parts, descendant)
	end
end
assert(#parts == 1, "Expected one MeshPart from the clean cargo export")
for _, part in parts do
	assert(part:IsA("MeshPart"), "Expected only MeshParts; found a " .. part.ClassName)
end
local maxY = 0
for _, part in parts do
	maxY = math.max(maxY, part.Size.Y)
end
assert(math.abs(maxY - 6) < 0.1, "Import using Stud units: assembled cargo height must be 6, got " .. maxY)
for _, part in parts do
	part.Anchored = true
	part.CanCollide = SOLID
	part.CanTouch = false
	part.CanQuery = false
	if SOLID then
		part.CollisionFidelity = if HOLLOW
			then Enum.CollisionFidelity.PreciseConvexDecomposition
			else Enum.CollisionFidelity.Box
	end
end
unit:SetAttribute("AssetRole", if SOLID then "SolidProp" else "Decoration")
unit:SetAttribute("AssetKey", "cargo-c")
print(("Wrecked cargo unit configured: %d MeshPart(s), anchored %s"):format(
	#parts, if SOLID then "solid prop" else "non-colliding decoration"))
