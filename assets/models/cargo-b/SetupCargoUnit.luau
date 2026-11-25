-- After importing CargoUnit.glb in Studio, select only that unit and run this
-- in the Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected unit only; it does not publish or save the place.
-- Provisional role: non-colliding decoration. SOLID = true gives box collision
-- so players cannot walk through it. It still ignores raycasts: cover players rely
-- on for gunfights belongs in the map's Lua blocks, not in decor.
local SOLID = false
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported cargo unit")
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
assert(#parts == 1 and parts[1]:IsA("MeshPart"), "Expected the single-mesh cargo export")
assert(math.abs(parts[1].Size.Y - 6) < 0.05, "Import using Stud units: cargo height must be 6")
for _, part in parts do
	part.Anchored = true
	part.CanCollide = SOLID
	part.CanTouch = false
	part.CanQuery = false
	if SOLID then
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	end
end
unit:SetAttribute("AssetRole", if SOLID then "SolidProp" else "Decoration")
unit:SetAttribute("AssetKey", "cargo-b")
print("Cargo unit configured as anchored " .. (if SOLID then "solid prop" else "non-colliding decoration"))
