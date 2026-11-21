-- After importing Desk.glb in Studio, select only that desk and run this in the
-- Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected desk only; it does not publish or save the place.
-- Provisional role: non-colliding decoration. If the user approves the desk as a
-- solid prop instead, set SOLID = true (box collision, still not raycast cover).
local SOLID = false
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported desk")
local desk = selected[1]
assert(desk:IsA("Model") or desk:IsA("MeshPart"), "Select the imported Model or MeshPart")
local parts = {}
if desk:IsA("BasePart") then
	table.insert(parts, desk)
end
for _, descendant in desk:GetDescendants() do
	if descendant:IsA("BasePart") then
		table.insert(parts, descendant)
	end
end
assert(#parts == 1 and parts[1]:IsA("MeshPart"), "Expected the single-mesh desk export")
local size = parts[1].Size
assert(math.abs(math.max(size.X, size.Z) - 14) < 0.05, "Import using Stud units: desk length must be 14")
assert(math.abs(size.Y - 3) < 0.1, "Import using Stud units: desk height must be about 3")
for _, part in parts do
	part.Anchored = true
	part.CanCollide = SOLID
	part.CanTouch = false
	part.CanQuery = false
	if SOLID then
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	end
end
desk:SetAttribute("AssetRole", if SOLID then "SolidProp" else "Decoration")
desk:SetAttribute("AssetKey", "desk")
print("Desk configured as anchored " .. (if SOLID then "solid prop" else "non-colliding decoration"))
