-- If this desk is approved as decoration, import SimpleSciFiDesk.glb with
-- Stud units, select only the resulting MeshPart/Model, and run in Studio.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported simple desk")
local desk = selected[1]
assert(desk:IsA("MeshPart") or desk:IsA("Model"), "Select a MeshPart or Model")
local parts = {}
if desk:IsA("MeshPart") then
    table.insert(parts, desk)
else
    for _, child in desk:GetDescendants() do
        if child:IsA("MeshPart") then
            table.insert(parts, child)
        end
    end
end
assert(#parts == 1, "Expected one desk MeshPart")
assert(math.abs(parts[1].Size.Y - 5.425) < 0.1, "Import with Stud units: expected 5.425 studs high")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
desk:SetAttribute("AssetKey", "simple-sci-fi-desk")
desk:SetAttribute("AssetRole", "Decoration")
print("Simple sci-fi desk configured as anchored, non-colliding decoration")
