-- After importing SnowFieldShelter.glb, select only that model in Studio.
-- Run this in the Command Bar after inspecting its textures and scale.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported shelter")
local shelter = selected[1]
assert(shelter:IsA("Model"), "Select the imported shelter Model")
local parts = {}
for _, child in shelter:GetDescendants() do
    if child:IsA("MeshPart") then
        table.insert(parts, child)
    end
end
assert(#parts == 7, "Expected seven material-grouped shelter MeshParts")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
shelter:SetAttribute("AssetRole", "BackgroundDecoration")
shelter:SetAttribute("AssetKey", "snow-field-shelter")
print("Configured selected shelter as anchored, non-colliding decoration")
