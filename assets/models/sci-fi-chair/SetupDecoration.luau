-- After importing SciFiChair.glb with Stud units, select only its model and
-- run this in Studio's Command Bar. This configures a decoration, not a Seat.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported chair Model")
local chair = selected[1]
local parts = {}
for _, item in chair:GetDescendants() do
    if item:IsA("MeshPart") then
        table.insert(parts, item)
    end
end
assert(#parts == 3, "Expected three chair MeshParts")
assert(math.abs(chair:GetExtentsSize().Y - 5) < 0.1, "Import with Stud units: expected about five studs high")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
chair:SetAttribute("AssetKey", "sci-fi-chair")
chair:SetAttribute("AssetRole", "Decoration")
print("Sci-fi chair configured as anchored, non-colliding decoration")
