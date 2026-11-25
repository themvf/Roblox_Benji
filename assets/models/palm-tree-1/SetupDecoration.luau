-- After importing PalmTree1.glb in Studio, select only the imported palm tree Model
-- and run this in the Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected palm tree only; it does not publish or save the place.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported PalmTree1 Model")
local tree = selected[1]
assert(tree:IsA("Model"), "Select the imported Model")
local parts = {}
for _, descendant in tree:GetDescendants() do
    if descendant:IsA("BasePart") then
        table.insert(parts, descendant)
    end
end
assert(#parts == 4, "Expected the 4-tile PalmTree1 export (geometry_0.001..0.004)")
for _, part in parts do
    assert(part:IsA("MeshPart"), "Expected MeshPart children")
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.DoubleSided = true
    part.Material = Enum.Material.Fabric
    part.Color = Color3.fromRGB(255, 255, 255)
end
local _, size = tree:GetBoundingBox()
assert(math.abs(size.Y - 19) < 0.75, "Import using Stud units: palm tree height should be ~19 studs")
tree:SetAttribute("AssetRole", "BackgroundDecoration")
tree:SetAttribute("AssetKey", "palm-tree-1")
tree:SetAttribute("SourceAssetId", "84316532447768")
print("Palm tree configured as anchored, non-colliding, double-sided background decoration")
