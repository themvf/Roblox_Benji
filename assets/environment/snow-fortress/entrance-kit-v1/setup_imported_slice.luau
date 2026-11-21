-- Select the imported SnowFortress_ReviewSlice Model in a NEW test place.
-- Paste this file into Studio's Command Bar in EDIT mode, then press Play.
local HttpService = game:GetService("HttpService")
assert(not game:GetService("RunService"):IsRunning(), "Stop play before setup")
local selected = game:GetService("Selection"):Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select the imported review Model")
local model = selected[1]
assert(not model:FindFirstChild("KitTestSetup"), "This model is already configured")
local ground
for _, part in model:GetDescendants() do
    if
        part:IsA("BasePart")
        and math.abs(part.Size.X - 110) < 0.1
        and math.abs(part.Size.Z - 110) < 0.1
        and part.Size.Y < 1
    then
        ground = part
    end
end
assert(ground, "Expected 110-stud test floor: import GLB with Scale Unit Stud, Y up")
local origin = ground.Position + Vector3.new(0, 4.3, 0)
local manifest = HttpService:JSONDecode(
    [==[{"version": 1, "unit": "stud", "axes": "X lateral, Y inward, Z up", "modules": {"SF_Portal_20": {"triangles": 3252, "boundsMin": [-14.600000381469727, -2.8499999046325684, 0.0], "boundsMax": [14.600000381469727, 2.6750001907348633, 19.027687072753906], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Portal jamb", "center": [-12, 0.65, 7], "size": [4, 3.3, 14]}, {"name": "Portal jamb", "center": [12, 0.65, 7], "size": [4, 3.3, 14]}, {"name": "Portal lintel", "center": [0, 0.65, 14], "size": [28, 3.3, 2]}, {"name": "Drip cornice", "center": [0, -0.2, 15.3], "size": [29, 5.3, 0.6]}, {"name": "Upper crest", "center": [0, 0.55, 16.9], "size": [28, 3.4, 2.6]}, {"name": "Crest coping", "center": [0, 0.55, 18.4], "size": [29, 4.1, 0.4]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_Portal_20_Color.png", "Normal": "textures/SF_Portal_20_Normal.png", "Roughness": "textures/SF_Portal_20_Roughness.png", "Metalness": "textures/SF_Portal_20_Metalness.png"}}, "SF_WallBay_10": {"triangles": 1404, "boundsMin": [-5.0, -1.5, 0.0], "boundsMax": [5.0, 1.9500000476837158, 13.0], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Wall backing", "center": [0, 0.5, 6.5], "size": [10, 2.8, 13]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_WallBay_10_Color.png", "Normal": "textures/SF_WallBay_10_Normal.png", "Roughness": "textures/SF_WallBay_10_Roughness.png", "Metalness": "textures/SF_WallBay_10_Metalness.png"}}, "SF_Pier_21": {"triangles": 828, "boundsMin": [-3.075000047683716, -2.375, 0.0], "boundsMax": [3.075000047683716, 3.075000047683716, 21.045318603515625], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Pier body", "center": [0, 0.5, 10], "size": [5, 4.4, 20]}, {"name": "Pier shoe", "center": [0, 0.35, 0.8], "size": [5.6, 5, 1.6]}, {"name": "Pier crown", "center": [0, 0.35, 20.3], "size": [6, 5.3, 0.6]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_Pier_21_Color.png", "Normal": "textures/SF_Pier_21_Normal.png", "Roughness": "textures/SF_Pier_21_Roughness.png", "Metalness": "textures/SF_Pier_21_Metalness.png"}}, "SF_Parapet_10": {"triangles": 624, "boundsMin": [-5.0, -1.274999976158142, 0.0], "boundsMax": [5.0, 2.2750000953674316, 3.650050401687622], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Parapet wall", "center": [0, 0.5, 1.45], "size": [10, 2.8, 2.9]}, {"name": "Parapet coping", "center": [0, 0.5, 3.1], "size": [10, 3.4, 0.4]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_Parapet_10_Color.png", "Normal": "textures/SF_Parapet_10_Normal.png", "Roughness": "textures/SF_Parapet_10_Roughness.png", "Metalness": "textures/SF_Parapet_10_Metalness.png"}}, "SF_InteriorBay_20": {"triangles": 1188, "boundsMin": [-12.300000190734863, -1.709999918937683, 0.0], "boundsMax": [12.299999237060547, 1.4500000476837158, 13.700000762939453], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Interior column", "center": [-11, 0, 6.5], "size": [2, 2.4, 13]}, {"name": "Interior column", "center": [11, 0, 6.5], "size": [2, 2.4, 13]}, {"name": "Ceiling beam", "center": [0, 0, 13.35], "size": [24, 2.4, 0.7]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_InteriorBay_20_Color.png", "Normal": "textures/SF_InteriorBay_20_Normal.png", "Roughness": "textures/SF_InteriorBay_20_Roughness.png", "Metalness": "textures/SF_InteriorBay_20_Metalness.png"}}, "SF_Floor_10": {"triangles": 540, "boundsMin": [-5.0, -5.0, -1.0], "boundsMax": [5.0, 5.0, 0.019999980926513672], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Floor slab", "center": [0, 0, -0.5], "size": [10, 10, 1]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_Floor_10_Color.png", "Normal": "textures/SF_Floor_10_Normal.png", "Roughness": "textures/SF_Floor_10_Roughness.png", "Metalness": "textures/SF_Floor_10_Metalness.png"}}, "SF_Cover_8": {"triangles": 756, "boundsMin": [-4.199999809265137, -1.7000000476837158, 0.0], "boundsMax": [4.199999809265137, 1.7000000476837158, 3.95550799369812], "origin": [0, 0, 0], "collisionBoxes": [{"name": "Cover core", "center": [0, 0, 1.7], "size": [8, 3, 3.4]}], "textureResolution": 1024, "textures": {"Color": "textures/SF_Cover_8_Color.png", "Normal": "textures/SF_Cover_8_Normal.png", "Roughness": "textures/SF_Cover_8_Roughness.png", "Metalness": "textures/SF_Cover_8_Metalness.png"}}}}]==]
)
local assembly = HttpService:JSONDecode(
    [==[{"placements": [{"module": "SF_Portal_20", "position": [0.0, 0.0, 0.0], "rotationZ": 0.0}, {"module": "SF_WallBay_10", "position": [-19.0, 0.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Parapet_10", "position": [-19.0, 0.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Pier_21", "position": [-26.0, 0.0, 0.0], "rotationZ": 0.0}, {"module": "SF_WallBay_10", "position": [-26.0, 7.0, 0.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Parapet_10", "position": [-26.0, 7.0, 14.0], "rotationZ": 1.5707963705062866}, {"module": "SF_WallBay_10", "position": [-26.0, 17.0, 0.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Parapet_10", "position": [-26.0, 17.0, 14.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Pier_21", "position": [-26.0, 24.0, 0.0], "rotationZ": 0.0}, {"module": "SF_WallBay_10", "position": [19.0, 0.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Parapet_10", "position": [19.0, 0.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Pier_21", "position": [26.0, 0.0, 0.0], "rotationZ": 0.0}, {"module": "SF_WallBay_10", "position": [26.0, 7.0, 0.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Parapet_10", "position": [26.0, 7.0, 14.0], "rotationZ": 1.5707963705062866}, {"module": "SF_WallBay_10", "position": [26.0, 17.0, 0.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Parapet_10", "position": [26.0, 17.0, 14.0], "rotationZ": 1.5707963705062866}, {"module": "SF_Pier_21", "position": [26.0, 24.0, 0.0], "rotationZ": 0.0}, {"module": "SF_InteriorBay_20", "position": [0.0, 8.0, 0.0], "rotationZ": 0.0}, {"module": "SF_InteriorBay_20", "position": [0.0, 20.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 5.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 5.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 15.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 15.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 25.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-20.0, 25.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 5.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 5.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 15.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 15.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 25.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [-10.0, 25.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 5.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 5.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 15.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 15.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 25.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [0.0, 25.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 5.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 5.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 15.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 15.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 25.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [10.0, 25.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 5.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 5.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 15.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 15.0, 14.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 25.0, 0.0], "rotationZ": 0.0}, {"module": "SF_Floor_10", "position": [20.0, 25.0, 14.0], "rotationZ": 0.0}], "note": "Review assembly only. New piers and returns change collision; not a live map patch."}]==]
)

local function point(p)
    return Vector3.new(p[1], p[3], -p[2])
end
local setup = Instance.new("Folder")
setup.Name = "KitTestSetup"
local function solid(name, size, cf)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, true, false
    p.Transparency, p.CastShadow = 1, false
    p.Parent = setup
    return p
end
for _, placement in assembly.placements do
    local base = CFrame.new(origin + point(placement.position)) * CFrame.Angles(0, placement.rotationZ or 0, 0)
    for _, box in manifest.modules[placement.module].collisionBoxes do
        solid(
            placement.module .. "_" .. box.name,
            Vector3.new(box.size[1], box.size[3], box.size[2]),
            base * CFrame.new(point(box.center))
        )
    end
end
solid("Test ground", Vector3.new(110, 0.6, 110), CFrame.new(origin + Vector3.new(0, -4.3, 0)))
solid("Foundation", Vector3.new(58, 3.98, 32), CFrame.new(origin + Vector3.new(0, -2.01, -12)))
local angle = math.rad(20)
local run = 4 / math.tan(angle)
solid(
    "Entrance ramp",
    Vector3.new(24, 0.5, 4 / math.sin(angle)),
    CFrame.new(origin + Vector3.new(0, -2 - 0.25 * math.cos(angle), run / 2)) * CFrame.Angles(angle, 0, 0)
)
for _, depth in { 2, 10, 22 } do
    local anchor = solid("Light anchor", Vector3.new(0.1, 0.1, 0.1), CFrame.new(origin + Vector3.new(0, 12.5, -depth)))
    anchor.CanCollide, anchor.CanQuery = false, false
    local light = Instance.new("PointLight")
    light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 214, 155), 1.5, 24
    light.Shadows = true
    light.Parent = anchor
end
-- Detailed visual meshes do not determine collision: the authored boxes do.
for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then
        part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
    end
end
setup.Parent = model
local spawn = Instance.new("SpawnLocation")
spawn.Name = "KitTestSpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(origin + Vector3.new(0, -3.5, 38))
spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
spawn.Parent = setup
model:SetAttribute("KitReviewReady", true)
workspace.CurrentCamera.CFrame = CFrame.lookAt(origin + Vector3.new(-25, 2, 55), origin + Vector3.new(0, 8, -3))
print(
    "Kit ready for an isolated test. Remove the baseplate's default SpawnLocation so Play uses KitTestSpawn. This is not installed in Convergence."
)
