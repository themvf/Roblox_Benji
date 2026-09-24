-- The blank Convergence starter: the one model a designer opens, edits and saves.
--
-- Everything that decides where gameplay happens is a marker in here, not a number in a
-- Lua file. Move a marker in Studio, save, run the converter, and the game follows it.
-- The markers live under `Authoring` and carry a `Role` attribute, which is what the
-- converter reads -- never their names, so renaming or relabelling one cannot break it.
--
--     <Name> — EDITABLE        Model, MapSource = <Name>
--       Ground                 the floor, baked
--       Geometry               buildings, cover, scenery: baked
--       Authoring              never baked
--         Objectives/A, B, C   Role=Objective: capture cylinder + pole + label
--         Spawns/Blue, Red     Role=Spawn pads
--         Bounds               Role=Bounds: the playable box
--         Helpers              a NORTH marker, orientation only
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local Instance = roblox.Instance

local T = {}

T.FORMAT = 1
-- Editable starting values, not balance rules. Snow Fortress's floor and radius, so kit
-- pieces cut from it fit without resizing.
T.DEFAULTS = {
    Floor = { x = 490, z = 370 },
    Bounds = { minY = -12, maxY = 85 },
    Radius = 18,
    HalfHeight = 7,
    Objectives = {
        { id = "A", pos = { 0, 0, -128 } },
        { id = "B", pos = { 0, 0, 128 } },
        { id = "C", pos = { 0, 0, 0 } },
    },
    SpawnX = 210,
    SpawnZ = { -20, -12, -4, 4, 12, 20 },
}

local AMBER = Color3.fromRGB(255, 196, 70)
local WHITE = Color3.fromRGB(255, 255, 255)
local TEAM = { Blue = Color3.fromRGB(70, 130, 230), Red = Color3.fromRGB(220, 70, 70) }
local FLOOR = Color3.fromRGB(180, 184, 190)

-- A part that exists only to be seen in Studio: no collision, touch, raycast or shadow.
local function helper(parent, name, size, cf, colour, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = colour
    p.Transparency = transparency
    p.Size = size
    p.CFrame = cf
    p:SetAttribute("AuthoringHelper", true)
    p.Parent = parent
    return p
end

-- World-space label, sized in studs so it reads the same from any distance setting.
local function label(parent, text, colour, studs)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Label"
    gui.Size = roblox.UDim2.new(studs * 3, 0, studs, 0)
    gui.StudsOffset = Vector3.new(0, studs, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = parent
    local t = Instance.new("TextLabel")
    t.Name = "Text"
    t.Size = roblox.UDim2.new(1, 0, 1, 0)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextScaled = true
    t.FontFace = roblox.Font.fromEnum(Enum.Font.GothamBlack)
    t.TextColor3 = colour
    t.TextStrokeTransparency = 0
    t.Parent = gui
    return gui
end

local function folder(parent, name)
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

-- Upright cylinder: Roblox cylinders run along X, so stand it on end.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

function T.objective(parent, id, pos, radius, halfHeight)
    local model = Instance.new("Model")
    model.Name = id
    model:SetAttribute("Role", "Objective")
    model:SetAttribute("ObjectiveId", id)
    model:SetAttribute("Label", id)
    model:SetAttribute("FinaleEligible", true)
    local at = Vector3.new(pos[1], pos[2], pos[3])
    -- The cylinder IS the capture area above the floor: its bottom is the objective's
    -- point, its radius the capture radius, its height the capture half-height.
    local capture = helper(
        model,
        "Capture",
        Vector3.new(halfHeight, radius * 2, radius * 2),
        CFrame.new(at + Vector3.new(0, halfHeight / 2, 0)) * UPRIGHT,
        AMBER,
        0.8
    )
    capture.Shape = Enum.PartType.Cylinder
    local pole =
        helper(model, "Pole", Vector3.new(1, 30, 1), CFrame.new(at + Vector3.new(0, halfHeight + 15, 0)), AMBER, 0.4)
    label(pole, "OBJECTIVE " .. id, AMBER, 6)
    model.PrimaryPart = capture
    model.Parent = parent
    return model
end

function T.spawn(parent, team, name, pos)
    local pad = helper(
        parent,
        name,
        Vector3.new(6, 0.5, 6),
        CFrame.new(pos[1], pos[2] + 0.25, pos[3]),
        TEAM[team],
        0.3
    )
    pad:SetAttribute("Role", "Spawn")
    pad:SetAttribute("Team", team)
    label(pad, team:upper() .. " SPAWN", TEAM[team], 1.5)
    return pad
end

-- Bounds is one box. Transparent and Locked so it does not swallow every click in the
-- viewport; select it in Explorer (Authoring > Bounds) and use Move / Scale. The outline
-- and the MAP BOUNDARY text on each side show where it is.
function T.bounds(parent, minV, maxV)
    local size = Vector3.new(maxV[1] - minV[1], maxV[2] - minV[2], maxV[3] - minV[3])
    local centre = Vector3.new((maxV[1] + minV[1]) / 2, (maxV[2] + minV[2]) / 2, (maxV[3] + minV[3]) / 2)
    local box = helper(parent, "Bounds", size, CFrame.new(centre), WHITE, 1)
    box.Locked = true
    box:SetAttribute("Role", "Bounds")
    -- Leaving the box, or falling below it, sends a player to the nearest spawn or
    -- objective. Set false to make it lethal, as shipped maps are.
    box:SetAttribute("TeleportOnExit", true)
    local outline = Instance.new("SelectionBox")
    outline.Name = "Outline"
    outline.Adornee = box
    outline.Color3 = WHITE
    outline.LineThickness = 0.6
    outline.SurfaceTransparency = 1
    outline.Parent = box
    for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
        local gui = Instance.new("SurfaceGui")
        gui.Name = "Label" .. face.Name
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 10
        gui.LightInfluence = 0
        gui.Parent = box
        local t = Instance.new("TextLabel")
        t.AnchorPoint = roblox.Vector2.new(0.5, 1)
        t.Position = roblox.UDim2.new(0.5, 0, 1, -20)
        t.Size = roblox.UDim2.new(0, 900, 0, 140)
        t.BackgroundTransparency = 1
        t.Text = "MAP BOUNDARY"
        t.TextScaled = true
        t.FontFace = roblox.Font.fromEnum(Enum.Font.GothamBlack)
        t.TextColor3 = WHITE
        t.TextStrokeTransparency = 0
        t.Parent = gui
    end
    return box
end

function T.build(name)
    local D = T.DEFAULTS
    local root = Instance.new("Model")
    root.Name = name .. " — EDITABLE"
    root:SetAttribute("MapSource", name)
    root:SetAttribute("MapFormat", T.FORMAT)
    root.WorldPivotData = CFrame.new()

    local ground = Instance.new("Model")
    ground.Name = "Ground"
    ground.Parent = root
    local slab = Instance.new("Part")
    slab.Name = "Floor"
    slab.Anchored = true
    slab.CanCollide = true
    slab.Material = Enum.Material.SmoothPlastic
    slab.Color = FLOOR
    slab.Size = Vector3.new(D.Floor.x, 1, D.Floor.z)
    slab.CFrame = CFrame.new(0, -0.5, 0)
    slab.Parent = ground

    folder(root, "Geometry")

    local authoring = folder(root, "Authoring")
    authoring:SetAttribute("AuthoringHelper", true)
    local objectives = folder(authoring, "Objectives")
    for _, o in D.Objectives do
        T.objective(objectives, o.id, o.pos, D.Radius, D.HalfHeight)
    end
    local spawns = folder(authoring, "Spawns")
    for _, team in { "Blue", "Red" } do
        local group = folder(spawns, team)
        local x = team == "Blue" and -D.SpawnX or D.SpawnX
        for i, z in D.SpawnZ do
            T.spawn(group, team, "Spawn " .. i, { x, 0, z })
        end
    end
    local hx, hz = D.Floor.x / 2, D.Floor.z / 2
    T.bounds(authoring, { -hx, D.Bounds.minY, -hz }, { hx, D.Bounds.maxY, hz })
    -- Orientation only. Objective C already marks the centre, so this points north
    -- instead: callouts ("north field") need an agreed direction.
    local helpers = folder(authoring, "Helpers")
    local north = helper(helpers, "North", Vector3.new(4, 0.5, 4), CFrame.new(0, 0.25, -hz + 12), WHITE, 0.3)
    label(north, "NORTH", WHITE, 3)
    return root
end

return T
