-- Select only the imported SnowFieldShelter_OpenDoor model in Studio.
-- The doorway is visually open, but this setting treats the entire model as decor.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported open shelter")
local shelter = selected[1]
assert(shelter:IsA("Model"), "Select the imported shelter Model")
local parts = {}
for _, child in shelter:GetDescendants() do
    if child:IsA("MeshPart") then
        table.insert(parts, child)
    end
end
assert(#parts == 8, "Expected eight material-grouped shelter MeshParts")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
shelter:SetAttribute("AssetRole", "BackgroundDecoration")
shelter:SetAttribute("AssetKey", "snow-field-shelter-open-door")
print("Configured selected open-door shelter as anchored, non-colliding decoration")
