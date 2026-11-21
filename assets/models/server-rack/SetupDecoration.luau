-- After importing ServerRack.glb in Studio, select only that rack and run this
-- in the Command Bar. GLB files do not enforce Roblox physics properties.
-- This edits the selected rack only; it does not publish or save the place.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported server rack")
local rack = selected[1]
assert(rack:IsA("Model") or rack:IsA("MeshPart"), "Select the imported Model or MeshPart")
local parts = {}
if rack:IsA("BasePart") then
    table.insert(parts, rack)
end
for _, descendant in rack:GetDescendants() do
    if descendant:IsA("BasePart") then
        table.insert(parts, descendant)
    end
end
assert(#parts == 1 and parts[1]:IsA("MeshPart"), "Expected the single-mesh rack export")
assert(math.abs(parts[1].Size.Y - 8) < 0.05, "Import using Stud units: rack height must be 8")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
rack:SetAttribute("AssetRole", "BackgroundDecoration")
rack:SetAttribute("AssetKey", "server-rack")
print("Server rack configured as anchored, non-colliding background decoration")
