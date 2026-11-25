-- Select only the imported SnowUtilityVehicle model in Studio.
-- This sets it up as stationary decoration; it does not create a drivable car.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported vehicle")
local vehicle = selected[1]
assert(vehicle:IsA("Model"), "Select the imported vehicle Model")
local parts = {}
for _, child in vehicle:GetDescendants() do
    if child:IsA("MeshPart") then
        table.insert(parts, child)
    end
end
assert(#parts == 9, "Expected nine vehicle MeshParts")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
vehicle:SetAttribute("AssetRole", "BackgroundDecoration")
vehicle:SetAttribute("AssetKey", "snow-utility-vehicle")
print("Configured selected utility vehicle as anchored, non-colliding decoration")
