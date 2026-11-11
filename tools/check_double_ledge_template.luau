local fs = require("@lune/fs")
local r = require("@lune/roblox")

local xml = fs.readFile("assets/environment/runtime/DoubleLedgeTurret.rbxmx")
local roots = r.deserializeModel(xml)
assert(#roots == 1 and roots[1].Name == "DoubleLedgeTurret", "Missing turret root")
local root = roots[1]
assert(root.PrimaryPart and root.PrimaryPart.Name == "Root", "Missing root pivot")
local base = root:FindFirstChild("Base")
local head = root:FindFirstChild("Head")
assert(base and head and head.PrimaryPart and head.PrimaryPart.Name == "HeadPivot", "Missing moving head pivot")
assert(root:FindFirstChild("UsePoint") and head:FindFirstChild("Muzzle"), "Missing interaction anchors")
for _, holder in { base, head } do
    for _, part in holder:GetChildren() do
        if part.Name:sub(1, 9) == "Collision" then
            assert(
                part:IsA("Part") and part.Anchored and part.CanCollide and part.CanQuery,
                "Invalid turret collider: " .. part.Name
            )
            assert(
                part.Transparency == 1 and not part.CanTouch,
                "Collider must be invisible and non-touching: " .. part.Name
            )
        end
    end
end
assert(base:FindFirstChild("CollisionPedestal"), "Missing pedestal collider")
assert(head:FindFirstChild("CollisionHousing") and head:FindFirstChild("CollisionBarrel"), "Missing head colliders")
local count = 0
for _, part in root:GetDescendants() do
    if part:IsA("MeshPart") then
        count += 1
        local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
        assert(appearance, "Surface appearance missing: " .. part.Name)
        assert(math.abs(appearance.Color.R - 120 / 255) < 0.01, "Turret tint missing: " .. part.Name)
        assert(not part.CanCollide and not part.CanQuery, "Art mesh has gameplay collision: " .. part.Name)
    end
end
assert(count == 9, "Expected nine mesh chunks, found " .. count)
local _, meshes = xml:gsub('<Content name="MeshContent">', "")
local _, colorMaps = xml:gsub('<Content name="ColorMapContent">', "")
local _, white = xml:gsub('<Color3uint8 name="Color3uint8">16777215</Color3uint8>', "")
assert(meshes == 9 and colorMaps == 9 and white == 9, "Serialized art IDs or white tint missing")
print("OK DoubleLedgeTurret template: nine textured meshes, pivots, and three colliders")
