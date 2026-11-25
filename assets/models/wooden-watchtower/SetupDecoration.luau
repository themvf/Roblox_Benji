-- After importing WoodenWatchtower.glb in Studio, select only the imported watchtower
-- Model and run this in the Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected watchtower only; it does not publish or save the place.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported WoodenWatchtower Model")
local tower = selected[1]
assert(tower:IsA("Model"), "Select the imported Model")
local parts = {}
for _, descendant in tower:GetDescendants() do
    if descendant:IsA("BasePart") then
        table.insert(parts, descendant)
    end
end
assert(#parts == 4, "Expected the 4-tile WoodenWatchtower export (geometry_0.001..0.004)")
for _, part in parts do
    assert(part:IsA("MeshPart"), "Expected MeshPart children")
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = true
end
local _, size = tower:GetBoundingBox()
assert(math.abs(size.Y - 28.1) < 1.0, "Import using Stud units: watchtower height should be ~28.1 studs")
tower:SetAttribute("AssetRole", "HybridArchitectureShell")
tower:SetAttribute("AssetKey", "wooden-watchtower")
tower:SetAttribute("SourceAssetId", "116938500732390")
print("Wooden watchtower configured as anchored, non-colliding visual shell/prop")
