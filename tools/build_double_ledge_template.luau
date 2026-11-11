-- Persist Studio-imported asset IDs in a Rojo-backed, operable turret template.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local r = require("@lune/roblox")

local manifest = serde.decode("json", fs.readFile("assets/models/double-ledge-lmg/studio_import.json"))
assert(#manifest.parts == 9, "Expected nine imported mesh chunks")

local root = r.Instance.new("Model")
root.Name = "DoubleLedgeTurret"

local function anchor(name, pos, parent)
    local part = r.Instance.new("Part")
    part.Name = name
    part.Size = r.Vector3.new(0.25, 0.25, 0.25)
    part.CFrame = r.CFrame.new(pos[1], pos[2], pos[3])
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Transparency = 1
    part.Parent = parent
    return part
end

local function collider(name, pos, size, parent)
    local part = r.Instance.new("Part")
    part.Name = name
    part.Size = r.Vector3.new(unpack(size))
    part.CFrame = r.CFrame.new(pos[1], pos[2], pos[3])
    part.Anchored = true
    part.CanCollide = true
    part.CanTouch = false
    part.CanQuery = true
    part.Transparency = 1
    part.Parent = parent
    return part
end

root.PrimaryPart = anchor("Root", { 0, 0, 0 }, root)

local base = r.Instance.new("Model")
base.Name = "Base"
base.Parent = root
local head = r.Instance.new("Model")
head.Name = "Head"
head.Parent = root
head.PrimaryPart = anchor("HeadPivot", { 0, 4.55, 0 }, head)

-- Mesh chunks are split for Roblox's triangle limit, so they make poor physical
-- collision shapes. These few simple parts stop players walking through the
-- turret while leaving the operator prompt approachable.
collider("CollisionPedestal", { 0, 2.4, 0 }, { 3.5, 4.6, 3.5 }, base)
collider("CollisionHousing", { 0, 5.7, -0.7 }, { 5, 3, 4 }, head)
collider("CollisionBarrel", { -3.3, 5.7, 2.3 }, { 5, 1.4, 2.2 }, head)

for _, record in manifest.parts do
    local part = r.Instance.new("MeshPart")
    part.Name = record.name
    part.MeshId = record.meshId
    part.Size = r.Vector3.new(unpack(record.size))
    part.CFrame = r.CFrame.new(record.cframe[1], record.cframe[2], record.cframe[3])
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Color = r.Color3.new(1, 1, 1)
    local surface = r.Instance.new("SurfaceAppearance")
    -- Reduce the snowy map's bright reflections while preserving texture detail.
    surface.Color = r.Color3.new(120 / 255, 130 / 255, 140 / 255)
    surface.ColorMap = record.colorMap
    surface.MetalnessMap = record.metalnessMap
    surface.RoughnessMap = record.roughnessMap
    if record.normalMap ~= "" then
        surface.NormalMap = record.normalMap
    end
    surface.Parent = part
    part.Parent = record.name:sub(1, 5) == "Base_" and base or head
end

-- Nominal barrel direction in the imported model's local X/Z plane.
local forward = r.Vector3.new(-0.771, 0, 0.637)
local muzzle = anchor("Muzzle", { -5.0, 5.85, 4.15 }, head)
local muzzlePosition = r.Vector3.new(-5.0, 5.85, 4.15)
muzzle.CFrame = r.CFrame.lookAt(muzzlePosition, muzzlePosition + forward)
anchor("UsePoint", { 3.6, 2.7, -3.0 }, root)

fs.writeDir("assets/environment/runtime")
fs.writeFile("assets/environment/runtime/DoubleLedgeTurret.rbxmx", r.serializeModel({ root }, true))
print("Built DoubleLedgeTurret template from Studio import")
