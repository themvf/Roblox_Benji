-- Select only the imported LobbyContainmentCanister model in Studio.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "Select exactly one imported canister")
local canister = selected[1]
assert(canister:IsA("Model"), "Select the imported canister Model")
local parts = {}
for _, child in canister:GetDescendants() do
    if child:IsA("MeshPart") then
        table.insert(parts, child)
    end
end
assert(#parts == 18, "Expected 18 canister MeshParts")
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
end
canister:SetAttribute("AssetRole", "BackgroundDecoration")
canister:SetAttribute("AssetKey", "lobby-containment-canister")
print("Configured selected lobby canister as anchored, non-colliding decoration")
