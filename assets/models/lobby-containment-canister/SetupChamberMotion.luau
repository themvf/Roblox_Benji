-- Run in Studio's Command Bar after importing the canister. Select exactly
-- the imported model. Decoration physics and motion are set together and stored
-- as children of the model, so it survives saving Lobby.Geometry to file.
local Selection = game:GetService("Selection")

local selected = Selection:Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select exactly one canister Model")
local canister = selected[1]
local parts = {}
for _, descendant in canister:GetDescendants() do
    if descendant:IsA("MeshPart") then
        table.insert(parts, descendant)
    end
end
assert(#parts == 18, "Expected 18 canister MeshParts; inspect the imported model")

-- Reuse the image already uploaded with the imported plume. If the importer
-- gave it a different name or did not upload that image, set the model's
-- EnergyTextureId attribute to the uploaded blue energy image ID first.
local textureId = canister:GetAttribute("EnergyTextureId")
if type(textureId) ~= "string" or textureId == "" then
    for _, part in canister:GetDescendants() do
        if part:IsA("MeshPart") and (part.Name:find("Energy_Textured_Plume") or part.Name == "Energy volume plane") then
            local appearance = part:FindFirstChildOfClass("SurfaceAppearance")
            if appearance then
                local ok, colorMap = pcall(function()
                    return appearance.ColorMap
                end)
                if ok and colorMap ~= "" then
                    textureId = colorMap
                    break
                end
            end
        end
    end
end
assert(
    type(textureId) == "string" and textureId ~= "",
    "Upload the blue energy PNG and set EnergyTextureId on the canister"
)

local box, size = canister:GetBoundingBox()
assert(size.Y > 7 and size.Y < 9, "Check the imported canister scale; expected about 8 studs high")
local bottom = box.Position.Y - size.Y / 2
local anchor = canister:FindFirstChild("ChamberMotionAnchor")
if anchor then
    assert(
        anchor:IsA("BasePart") and anchor:GetAttribute("AssetKey") == "lobby-containment-canister",
        "An unrelated ChamberMotionAnchor exists"
    )
end
for _, part in parts do
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    -- Studio's GLB importer preserves the cap and plume image maps, but the
    -- source's untextured material colors and alpha arrive as gray opaque
    -- MeshParts. Reapply those authored properties by their saved mesh names.
    if part.Name == "Clear chamber shell" then
        part.Color = Color3.fromRGB(53, 145, 190)
        part.Material = Enum.Material.SmoothPlastic
        part.Transparency = 0.82
    elseif part.Name == "Dark far-side lining" then
        part.Color = Color3.fromRGB(5, 21, 35)
        part.Material = Enum.Material.SmoothPlastic
        part.Transparency = 0.85
    elseif part.Name == "Torus" then
        part.Color = Color3.fromRGB(14, 31, 44)
        part.Material = Enum.Material.Metal
    elseif part.Name == "Torus.002" then
        part.Color = Color3.fromRGB(35, 210, 255)
        part.Material = Enum.Material.Neon
    elseif part.Name:find("Energy_Bright_Wisps") then
        part.Color = Color3.fromRGB(150, 240, 255)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.1
    elseif part.Name:find("Energy_Cyan_Wisps") then
        part.Color = Color3.fromRGB(25, 190, 255)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.24
    elseif part.Name:find("Energy_Faint_Wisps") then
        part.Color = Color3.fromRGB(40, 145, 255)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.55
    elseif part.Name == "Layered blue vapor" then
        part.Color = Color3.fromRGB(35, 140, 235)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.78
        part.DoubleSided = true
    elseif part.Name == "Energy volume plane" then
        part.Color = Color3.fromRGB(135, 215, 255)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.18
        part.DoubleSided = true
    elseif part.Name == "Sphere" then
        part.Color = Color3.fromRGB(35, 165, 255)
        part.Material = Enum.Material.Neon
        part.Transparency = 0.35
    elseif part.Name:find("Glass_Reflection") then
        part.Color = Color3.fromRGB(135, 230, 255)
        part.Material = Enum.Material.Glass
        part.Transparency = 0.62
    end
end
if not anchor then
    anchor = Instance.new("Part")
    anchor.Name = "ChamberMotionAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor:SetAttribute("AssetKey", "lobby-containment-canister")
    anchor.Parent = canister
end
anchor.CFrame = CFrame.new(box.Position.X, bottom + 1.25, box.Position.Z)

local attachment = anchor:FindFirstChild("EnergySource") or Instance.new("Attachment")
attachment.Name = "EnergySource"
attachment.Parent = anchor

local vapor = attachment:FindFirstChild("RisingBlueVapor") or Instance.new("ParticleEmitter")
vapor.Name = "RisingBlueVapor"
vapor.Texture = textureId
vapor.Color = ColorSequence.new(Color3.fromRGB(165, 235, 255))
vapor.LightInfluence = 0
vapor.LightEmission = 0.55
vapor.Rate = 3
vapor.Lifetime = NumberRange.new(2.2, 3.1)
vapor.Speed = NumberRange.new(0.45, 0.75)
vapor.Drag = 0.7
vapor.EmissionDirection = Enum.NormalId.Top
vapor.SpreadAngle = Vector2.new(12, 12)
vapor.Rotation = NumberRange.new(0, 360)
vapor.RotSpeed = NumberRange.new(-8, 8)
vapor.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.55),
    NumberSequenceKeypoint.new(0.35, 1.15),
    NumberSequenceKeypoint.new(1, 1.55),
})
vapor.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.7),
    NumberSequenceKeypoint.new(0.3, 0.4),
    NumberSequenceKeypoint.new(1, 1),
})
vapor.Enabled = true
vapor.Parent = attachment

local glow = anchor:FindFirstChild("BlueCoreGlow") or Instance.new("PointLight")
glow.Name = "BlueCoreGlow"
glow.Color = Color3.fromRGB(55, 190, 255)
glow.Brightness = 0.7
glow.Range = 6
glow.Shadows = false
glow.Parent = anchor

canister:SetAttribute("ChamberMotionVersion", 1)
canister:SetAttribute("AssetRole", "BackgroundDecoration")
canister:SetAttribute("AssetKey", "lobby-containment-canister")
print("Set decoration physics and contained rising blue vapor on", canister:GetFullName())
