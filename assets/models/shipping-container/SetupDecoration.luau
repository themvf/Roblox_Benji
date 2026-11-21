-- Run in Studio's Command Bar only after importing ShippingContainer.glb with Stud units.
-- Select exactly the resulting container Model or MeshPart.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported shipping container")
local container = selected[1]
assert(container:IsA("MeshPart") or container:IsA("Model"), "Select a MeshPart or Model")
local parts = {}
if container:IsA("MeshPart") then
    table.insert(parts, container)
else
    for _, child in container:GetDescendants() do
        if child:IsA("MeshPart") then table.insert(parts, child) end
    end
end
assert(#parts == 1, "Expected one container MeshPart")
assert(math.abs(parts[1].Size.Y - 10.78) < 0.1,
    "Import with Stud units: expected about 10.78 studs high")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
container:SetAttribute("AssetKey", "shipping-container")
container:SetAttribute("AssetRole", "Decoration")
print("Shipping container configured as anchored, non-colliding decoration")
