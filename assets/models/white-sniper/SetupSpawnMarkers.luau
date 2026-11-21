-- Run once in the ENGAGE Studio command bar while editing the place.
-- Existing markers are preserved so moving them never gets reset.
local folder = workspace:FindFirstChild("WhiteSniperSpawns")
if not folder then
    folder = Instance.new("Folder")
    folder.Name = "WhiteSniperSpawns"
    folder.Parent = workspace
end

for name, pos in {
    BlueOutpost = Vector3.new(-90, 1.596, -145),
    RedOutpost = Vector3.new(90, 1.596, -145),
} do
    if not folder:FindFirstChild(name) then
        local marker = Instance.new("Part")
        marker.Name = name
        marker.Size = Vector3.new(2, 0.25, 2)
        marker.Position = pos
        marker.Anchored = true
        marker.CanCollide = false
        marker.CanTouch = false
        marker.CanQuery = false
        marker.Color = Color3.fromRGB(255, 255, 255)
        marker.Material = Enum.Material.Neon
        marker.Transparency = 0.35
        marker.Parent = folder
    end
end
