-- Select exactly the imported OrangeBoxRansacked model or MeshPart in Studio,
-- then run in the Command Bar. GLB import does not set Roblox physics.
-- Decoration is the provisional default; set SOLID=true for a solid prop.
-- Gameplay cover must instead be represented in the map's Lua geometry.
local SOLID = false
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported orange box")
local unit = selected[1]
assert(unit:IsA("Model") or unit:IsA("MeshPart"), "Select its Model or MeshPart")
local parts = {}
if unit:IsA("BasePart") then table.insert(parts, unit) end
for _, descendant in unit:GetDescendants() do
    if descendant:IsA("BasePart") then table.insert(parts, descendant) end
end
assert(#parts == 1 and parts[1]:IsA("MeshPart"), "Expected one mesh")
assert(math.abs(parts[1].Size.Y - 3.8) < 0.05, "Import with Stud units; height must be 3.8")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = SOLID
    part.CanTouch = false
    part.CanQuery = false
    if SOLID then part.CollisionFidelity = Enum.CollisionFidelity.Box end
end
unit:SetAttribute("AssetRole", if SOLID then "SolidProp" else "Decoration")
unit:SetAttribute("AssetKey", "orangebox-ransacked")
print("Orange box configured as anchored " .. (if SOLID then "solid prop" else "decoration"))
