-- Builds a blocky Tool model for each weapon out of Parts. Placeholder art:
-- swap any entry for a real mesh later and the rest of the game will not care.
-- Sizes are {x, y, z} in studs relative to the Handle; the barrel points -Z.
local WeaponModels = {}

local GUNMETAL = Color3.fromRGB(60, 62, 66)
local DARK = Color3.fromRGB(35, 35, 38)
local WOOD = Color3.fromRGB(110, 75, 45)
local ENERGY = Color3.fromRGB(80, 200, 255)

-- Each spec: list of parts { name, size, offset, color, shape? }
-- Handle is where the hand grips. Offsets are from the Handle center.
local SPECS = {
    AssaultRifle = {
        { "Body", { 0.35, 0.5, 2.2 }, { 0, 0.35, -0.6 }, GUNMETAL },
        { "Barrel", { 0.15, 0.15, 1.4 }, { 0, 0.42, -2.3 }, DARK, "Cylinder" },
        { "Stock", { 0.3, 0.4, 1.0 }, { 0, 0.3, 0.9 }, DARK },
        { "Mag", { 0.25, 0.7, 0.3 }, { 0, -0.2, -0.7 }, DARK },
        { "Sight", { 0.12, 0.2, 0.5 }, { 0, 0.7, -0.6 }, DARK },
    },
    BurstRifle = {
        { "Body", { 0.35, 0.5, 2.0 }, { 0, 0.35, -0.5 }, GUNMETAL },
        { "Barrel", { 0.14, 0.14, 1.2 }, { 0, 0.42, -2.0 }, DARK, "Cylinder" },
        { "Stock", { 0.25, 0.35, 0.9 }, { 0, 0.3, 0.9 }, GUNMETAL },
        { "Mag", { 0.25, 0.6, 0.3 }, { 0, -0.15, -0.6 }, DARK },
        { "Carry", { 0.12, 0.25, 0.9 }, { 0, 0.7, -0.5 }, GUNMETAL },
    },
    Shotgun = {
        { "Body", { 0.35, 0.45, 1.6 }, { 0, 0.3, -0.4 }, GUNMETAL },
        { "Barrel", { 0.2, 0.2, 2.0 }, { 0, 0.4, -2.0 }, DARK, "Cylinder" },
        { "Tube", { 0.16, 0.16, 1.8 }, { 0, 0.18, -1.9 }, DARK, "Cylinder" },
        { "Pump", { 0.32, 0.32, 0.6 }, { 0, 0.18, -1.6 }, WOOD },
        { "Stock", { 0.3, 0.45, 1.1 }, { 0, 0.25, 0.9 }, WOOD },
    },
    Sniper = {
        { "Body", { 0.3, 0.45, 2.4 }, { 0, 0.3, -0.7 }, GUNMETAL },
        { "Barrel", { 0.13, 0.13, 2.4 }, { 0, 0.4, -3.1 }, DARK, "Cylinder" },
        { "Scope", { 0.22, 0.22, 1.0 }, { 0, 0.75, -0.6 }, DARK, "Cylinder" },
        { "Stock", { 0.28, 0.5, 1.2 }, { 0, 0.25, 1.0 }, WOOD },
        { "Mag", { 0.22, 0.4, 0.4 }, { 0, -0.05, -0.8 }, DARK },
        { "Bipod", { 0.5, 0.1, 0.1 }, { 0, 0.15, -2.6 }, DARK },
    },
    Wildcat = {
        { "Body", { 0.35, 0.5, 1.5 }, { 0, 0.35, -0.3 }, GUNMETAL },
        { "Barrel", { 0.14, 0.14, 0.8 }, { 0, 0.42, -1.4 }, DARK, "Cylinder" },
        { "Stock", { 0.15, 0.15, 0.9 }, { 0, 0.4, 0.8 }, DARK },
        { "Mag", { 0.25, 0.8, 0.3 }, { 0, -0.25, -0.4 }, DARK },
        { "Mag2", { 0.25, 0.8, 0.3 }, { 0, -0.25, -0.05 }, DARK },
    },
    Minigun = {
        { "Body", { 0.6, 0.7, 1.6 }, { 0, 0.4, 0.2 }, GUNMETAL },
        { "Barrels", { 0.45, 0.45, 2.6 }, { 0, 0.45, -1.8 }, DARK, "Cylinder" },
        { "Ring", { 0.55, 0.55, 0.15 }, { 0, 0.45, -2.9 }, GUNMETAL, "Cylinder" },
        { "Ammo", { 0.5, 0.6, 0.6 }, { 0, -0.1, 0.6 }, DARK },
        { "Grip2", { 0.2, 0.5, 0.2 }, { 0, -0.1, -0.8 }, DARK },
    },
    EnergyRifle = {
        { "Body", { 0.4, 0.5, 2.0 }, { 0, 0.35, -0.5 }, Color3.fromRGB(230, 230, 235) },
        { "Core", { 0.25, 0.25, 1.2 }, { 0, 0.4, -0.5 }, ENERGY, "Cylinder", true },
        { "Emitter", { 0.3, 0.3, 0.6 }, { 0, 0.4, -1.8 }, ENERGY, "Cylinder", true },
        { "Stock", { 0.3, 0.35, 0.8 }, { 0, 0.3, 0.9 }, Color3.fromRGB(230, 230, 235) },
    },
    Handgun = {
        { "Slide", { 0.28, 0.3, 1.1 }, { 0, 0.45, -0.35 }, GUNMETAL },
        { "Barrel", { 0.1, 0.1, 0.3 }, { 0, 0.47, -1.0 }, DARK, "Cylinder" },
        { "Frame", { 0.26, 0.2, 0.9 }, { 0, 0.25, -0.25 }, DARK },
    },
    Revolver = {
        { "Barrel", { 0.18, 0.22, 1.3 }, { 0, 0.45, -0.7 }, GUNMETAL },
        { "Cylinder", { 0.36, 0.36, 0.45 }, { 0, 0.4, -0.05 }, GUNMETAL, "Cylinder" },
        { "Frame", { 0.22, 0.25, 0.5 }, { 0, 0.3, 0.1 }, DARK },
        { "Hammer", { 0.08, 0.2, 0.15 }, { 0, 0.55, 0.3 }, DARK },
    },
    Shorty = {
        { "Body", { 0.3, 0.35, 0.8 }, { 0, 0.35, -0.2 }, WOOD },
        { "Barrel1", { 0.18, 0.18, 1.0 }, { 0.1, 0.45, -1.0 }, DARK, "Cylinder" },
        { "Barrel2", { 0.18, 0.18, 1.0 }, { -0.1, 0.45, -1.0 }, DARK, "Cylinder" },
    },
    Spray = {
        { "Slide", { 0.3, 0.32, 1.2 }, { 0, 0.45, -0.4 }, GUNMETAL },
        { "Barrel", { 0.1, 0.1, 0.4 }, { 0, 0.47, -1.15 }, DARK, "Cylinder" },
        { "Frame", { 0.28, 0.2, 0.9 }, { 0, 0.25, -0.25 }, DARK },
        { "Mag", { 0.22, 0.6, 0.25 }, { 0, -0.35, 0 }, DARK },
    },
    Uzi = {
        { "Body", { 0.3, 0.45, 1.1 }, { 0, 0.4, -0.3 }, GUNMETAL },
        { "Barrel", { 0.12, 0.12, 0.5 }, { 0, 0.45, -1.05 }, DARK, "Cylinder" },
        { "Mag", { 0.22, 0.8, 0.25 }, { 0, -0.3, 0 }, DARK },
        { "Stock", { 0.12, 0.12, 0.7 }, { 0, 0.5, 0.6 }, DARK },
    },
    EnergyPistols = {
        { "Body", { 0.3, 0.35, 1.0 }, { 0, 0.4, -0.3 }, Color3.fromRGB(230, 230, 235) },
        { "Emitter", { 0.2, 0.2, 0.4 }, { 0, 0.42, -0.95 }, ENERGY, "Cylinder", true },
        { "Frame", { 0.26, 0.2, 0.7 }, { 0, 0.2, -0.15 }, DARK },
    },
}

local function makePart(name, size, color, shape, glow)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(size[1], size[2], size[3])
    part.Color = color
    part.Material = glow and Enum.Material.Neon or Enum.Material.Metal
    part.CanCollide = false
    part.CanQuery = false
    part.Massless = true
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if shape == "Cylinder" then
        part.Shape = Enum.PartType.Cylinder
    end
    return part
end

-- Returns a Tool the server can put in a character. Handle is the grip.
function WeaponModels.Build(weaponName)
    local spec = SPECS[weaponName] or SPECS.Handgun
    local tool = Instance.new("Tool")
    tool.Name = weaponName
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ManualActivationOnly = true -- our controller handles clicks
    -- Grip: hand holds the Handle; tilt so the barrel points forward.
    tool.Grip = CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-90), 0, 0)

    local handle = makePart("Handle", { 0.28, 0.75, 0.32 }, DARK)
    handle.Parent = tool

    for _, p in spec do
        local name, size, offset, color, shape, glow = table.unpack(p)
        local part = makePart(name, size, color, shape, glow)
        local cf = CFrame.new(offset[1], offset[2], offset[3])
        if shape == "Cylinder" then
            -- Cylinders point along X, so rotate to point along Z (the barrel axis)
            cf = cf * CFrame.Angles(0, math.rad(90), 0)
            part.Size = Vector3.new(size[3], size[2], size[1])
        end
        part.CFrame = handle.CFrame * cf
        local weld = Instance.new("Weld")
        weld.Part0 = handle
        weld.Part1 = part
        weld.C0 = cf
        weld.Parent = handle
        part.Parent = tool
    end
    return tool
end

return WeaponModels
