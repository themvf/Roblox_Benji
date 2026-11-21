-- Select only the imported PurpleColumn model in Studio.
-- This sets it up as non-colliding lobby decoration. Architectural collision
-- needs a simple separate collider and placement review.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported column")
local column = selected[1]
assert(column:IsA("Model"), "Select the imported column Model")
local parts = {}
for _, child in column:GetDescendants() do
    if child:IsA("MeshPart") then
        table.insert(parts, child)
    end
end
assert(#parts == 6, "Expected six purple column MeshParts")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
column:SetAttribute("AssetRole", "BackgroundDecoration")
column:SetAttribute("AssetKey", "purple-column")
print("Configured selected purple column as anchored, non-colliding decoration")
