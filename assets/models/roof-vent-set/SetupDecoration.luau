-- Run in Studio's Command Bar with exactly one imported roof-vent Model selected.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported roof-vent Model")
local model = selected[1]
local count = 0
for _, descendant in model:GetDescendants() do
    if descendant:IsA("BasePart") then
        descendant.Anchored = true
        descendant.CanCollide = false
        descendant.CanTouch = false
        descendant.CanQuery = false
        count += 1
    end
end
assert(count >= 2 and count <= 4, "Expected two to four mesh parts; inspect the selected import")
print("Configured static roof vent:", model:GetFullName(), count, "parts")
