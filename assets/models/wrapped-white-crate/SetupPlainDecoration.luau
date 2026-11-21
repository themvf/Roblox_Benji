-- Run in Studio's Command Bar with exactly the imported plain-crates Model selected.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported plain-crates Model")
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
assert(parts == 2, "Expected two imported mesh parts; inspect the import before use")
model.Name = "PlainWoodenCrates"
print("Configured decoration:", model:GetFullName(), parts, "parts")
