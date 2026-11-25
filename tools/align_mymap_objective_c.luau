-- Put the editable C capture marker on the actual upper floor before conversion.
-- Keeps a copy of the Studio export so this local repair can be reversed.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local source = "assets/environment/source/MyMap.rbxm"
local backup = ".mapbuild/MyMap-before-C-alignment.rbxm"
local bytes = fs.readFile(source)
local roots = roblox.deserializeModel(bytes)
assert(#roots == 1 and roots[1]:GetAttribute("MapSource") == "MyMap", "unexpected MyMap source")
local root = roots[1]
local c = assert(root.Authoring.Objectives:FindFirstChild("C"), "missing C objective")
local capture = assert(c:FindFirstChild("Capture"), "missing C capture cylinder")
local upper = nil
for _, part in root.Geometry:GetDescendants() do
    if part.Name == "UpperCentre" and part:IsA("BasePart") then
        assert(upper == nil, "multiple upper centre floors")
        upper = part
    end
end
assert(upper, "missing upper centre floor")
local floorY = upper.CFrame.Position.Y + upper.Size.Y / 2
-- Capture is a cylinder whose axial height is Size.X; MapAuthoring reads its
-- floor point from the model pivot, half that axial height below the centre.
local currentY = capture.CFrame.Position.Y - capture.Size.X / 2
local rise = floorY + 0.02 - currentY
print(("C marker current floor %.2f, upper floor top %.2f, proposed rise %.2f"):format(currentY, floorY, rise))
assert(rise >= -0.1 and rise < 20, "unexpected C marker height")
if rise > 0.1 then
    if not fs.isFile(backup) then
        fs.writeFile(backup, bytes)
    end
    local delta = roblox.CFrame.new(0, rise, 0)
    for _, part in c:GetDescendants() do
        if part:IsA("BasePart") then
            part.CFrame = delta * part.CFrame
        end
    end
    fs.writeFile(source, roblox.serializeModel({ root }))
end
print(("C capture floor: %.2f -> %.2f; upper floor top: %.2f"):format(currentY, currentY + rise, floorY))
