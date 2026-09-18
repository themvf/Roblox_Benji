-- Snow: the forest layout under a winter palette and a different tree seed.
-- Same lanes and cover, so what players learned on Forest carries over; the read is
-- "cold, bright, blue" instead of "green". Map variation for near zero cost.
local Forest = require(script.Parent.Forest)

local function deepCopy(t)
    local out = {}
    for k, v in t do
        out[k] = type(v) == "table" and deepCopy(v) or v
    end
    return out
end

local Snow = deepCopy(Forest)
Snow.Name = "Snow"
Snow.Seed = 4242

Snow.Environment.ClockTime = 14.5
Snow.Environment.Brightness = 2.8
Snow.Environment.Ambient = Color3.fromRGB(150, 165, 190)
Snow.Environment.OutdoorAmbient = Color3.fromRGB(175, 190, 215)
Snow.Environment.FogColor = Color3.fromRGB(225, 235, 250)
Snow.Environment.Atmosphere = { Density = 0.28, Haze = 1.0, Glare = 0.15, Color = Color3.fromRGB(225, 235, 255) }
Snow.Environment.Saturation = 0.1
Snow.Environment.Tint = Color3.fromRGB(240, 245, 255)

Snow.Palette = {
    Rock = Color3.fromRGB(120, 135, 160), -- dark slate cover reads against white ground
    RockEdge = Color3.fromRGB(255, 140, 60), -- warm accent stays loud on a cold palette
    Bark = Color3.fromRGB(90, 70, 60),
    Needles = { Color3.fromRGB(40, 110, 120), Color3.fromRGB(60, 130, 150), Color3.fromRGB(35, 95, 105) },
    Wood = Color3.fromRGB(130, 95, 70),
    Marker = Color3.fromRGB(255, 220, 60),
    Mountain = Color3.fromRGB(200, 210, 230),
}

Snow.Terrain.GroundMaterial = Enum.Material.Snow
Snow.Terrain.GroundColor = Color3.fromRGB(235, 240, 250)
-- frozen lake: keep the shape, the builder fills water; ice look comes from the palette

Snow.Trees.Count = 70
Snow.Trees.Height = { 22, 36 }

return Snow
