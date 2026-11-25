-- Run in Studio's Command Bar with one imported drum MeshPart or Model selected.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select one imported fuel drum or three-pack")
local root = selected[1]
assert(root:IsA("MeshPart") or root:IsA("Model"), "Select a drum MeshPart or Model")
local parts = {}
if root:IsA("MeshPart") then
    table.insert(parts, root)
else
    for _, descendant in root:GetDescendants() do
        if descendant:IsA("MeshPart") then
            table.insert(parts, descendant)
        end
    end
end
assert(#parts == 1 or #parts == 3, "Expected one drum or a three-drum set")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
print("Configured static fuel drums:", root:GetFullName(), #parts)
