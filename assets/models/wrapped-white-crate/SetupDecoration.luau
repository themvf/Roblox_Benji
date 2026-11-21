-- Run in Studio's Command Bar with exactly the imported wrapped-crate Model selected.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported wrapped-crate Model")
local model = selected[1]
local parts = 0
for _, descendant in model:GetDescendants() do
    if descendant:IsA("BasePart") then
        descendant.Anchored = true
        descendant.CanCollide = false
        descendant.CanTouch = false
        descendant.CanQuery = false
        parts += 1
    end
end
assert(parts == 8, "Expected eight imported mesh parts; inspect the import before use")
model.Name = "WrappedWhiteCrate"
print("Configured decoration:", model:GetFullName(), parts, "parts")
