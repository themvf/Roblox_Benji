-- One reader for the editable lobby model in Studio and its saved project copy.
-- Geometry and marker transforms come from the model; mode rules and text remain
-- in Maps/Lobby.lua so moving a pad cannot change matchmaking behavior.
local LobbyAuthoring = {}

local function relative(part, origin)
    local p = part.CFrame.Position - origin
    return { p.X, p.Y, p.Z }
end

function LobbyAuthoring.read(root, base)
    local errors = {}
    local function fail(message)
        table.insert(errors, message)
    end
    if not root or root:GetAttribute("LobbySource") ~= true then
        return nil, { "The model needs the LobbySource=true attribute." }
    end
    local geometry = root:FindFirstChild("Geometry")
    local authoring = root:FindFirstChild("Authoring")
    if not geometry or not authoring then
        return nil, { "The lobby needs Geometry and Authoring folders." }
    end
    for _, item in root:GetDescendants() do
        if item:IsA("LuaSourceContainer") then
            fail("Editable lobby contains a script: " .. item:GetFullName())
        end
    end
    local partCount = 0
    for _, item in geometry:GetDescendants() do
        if item:IsA("BasePart") then
            partCount += 1
            if not item.Anchored then
                fail("Geometry part is not anchored: " .. item:GetFullName())
            end
        end
    end
    if partCount == 0 then
        fail("Geometry has no parts.")
    end
    local floor = geometry:FindFirstChild("Floor")
    if not floor or not floor:IsA("BasePart") then
        fail("Geometry needs a Floor part to support the lobby markers.")
    end

    local markers = {}
    for _, item in authoring:GetDescendants() do
        if item:IsA("BasePart") then
            local role = item:GetAttribute("Role")
            local id = item:GetAttribute("Id")
            if type(role) ~= "string" or type(id) ~= "string" then
                fail("Marker needs Role and Id attributes: " .. item:GetFullName())
            else
                local key = role .. ":" .. id
                if markers[key] then
                    fail("Duplicate lobby marker: " .. key)
                else
                    markers[key] = item
                end
            end
            if not item.Anchored or item.CanCollide or item.CanTouch or item.CanQuery then
                fail("Marker must be anchored and noninteractive: " .. item:GetFullName())
            end
            local right, up = item.CFrame.RightVector, item.CFrame.UpVector
            if math.abs(right.X - 1) > 0.01 or math.abs(up.Y - 1) > 0.01 then
                fail("Marker rotation is not supported yet; move or resize " .. item:GetFullName())
            end
        end
    end
    local used = {}
    local function get(role, id)
        local key = role .. ":" .. id
        local item = markers[key]
        if not item then
            fail("Missing " .. role .. " marker " .. id)
        else
            used[key] = true
        end
        return item
    end
    local origin = Vector3.new(table.unpack(base.Origin))
    local function onFloor(part, width, depth)
        if not floor then
            return
        end
        local offset = part.CFrame.Position - floor.CFrame.Position
        if math.abs(offset.X) + width / 2 > floor.Size.X / 2 or math.abs(offset.Z) + depth / 2 > floor.Size.Z / 2 then
            fail(part.Name .. " sits outside the Floor. Move it or enlarge the Floor.")
        end
    end
    local layout = table.clone(base)
    layout.Spawns = {}
    for index = 1, #base.Spawns do
        local part = get("Spawn", tostring(index))
        if part then
            onFloor(part, 3, 3)
            table.insert(layout.Spawns, relative(part, origin))
        end
    end
    layout.Pads = {}
    local padParts = {}
    for _, spec in base.Pads do
        local part = get("QueuePad", spec.name)
        if part then
            local halfWidth = (part.Size.X - 1.5) / 2
            if halfWidth < math.max(3, spec.teamSize * 2.4) or part.Size.Z < 6 then
                fail(spec.name .. " is too small for both team join areas.")
            end
            onFloor(part, part.Size.X, part.Size.Z)
            local updated = table.clone(spec)
            updated.pos = relative(part, origin)
            updated.size = { part.Size.X, part.Size.Y, part.Size.Z }
            updated.color = part.Color
            table.insert(layout.Pads, updated)
            table.insert(padParts, part)
        end
    end
    for i = 1, #padParts do
        for j = i + 1, #padParts do
            local a, b = padParts[i], padParts[j]
            local delta = a.CFrame.Position - b.CFrame.Position
            if math.abs(delta.X) < (a.Size.X + b.Size.X) / 2 and math.abs(delta.Z) < (a.Size.Z + b.Size.Z) / 2 then
                fail(a.Name .. " overlaps " .. b.Name .. "; separate their join areas.")
            end
        end
    end
    local board = get("Board", "Board")
    if board then
        layout.Board = { pos = relative(board, origin), size = { board.Size.X, board.Size.Y, board.Size.Z } }
    end
    local kiosk = get("Kiosk", "Kiosk")
    if kiosk then
        layout.Kiosk = table.clone(base.Kiosk)
        layout.Kiosk.pos = relative(kiosk, origin)
        layout.Kiosk.size = { kiosk.Size.X, kiosk.Size.Y, kiosk.Size.Z }
        local showcase = kiosk:GetAttribute("Showcase")
        if showcase ~= nil and type(showcase) ~= "string" then
            fail("Kiosk Showcase must be a weapon name.")
        end
        layout.Kiosk.showcase = showcase or base.Kiosk.showcase
    end
    layout.Wayfinding = {}
    for _, spec in base.Wayfinding or {} do
        local part = get("Wayfinding", spec.name)
        if part then
            local updated = table.clone(spec)
            updated.pos = relative(part, origin)
            updated.size = { part.Size.X, part.Size.Y }
            updated.color = part.Color
            local title, detail = part:GetAttribute("Title"), part:GetAttribute("Detail")
            if title ~= nil and type(title) ~= "string" then
                fail(spec.name .. " Title must be text.")
            end
            if detail ~= nil and type(detail) ~= "string" then
                fail(spec.name .. " Detail must be text.")
            end
            updated.title = type(title) == "string" and title or spec.title
            updated.detail = type(detail) == "string" and detail or spec.detail
            table.insert(layout.Wayfinding, updated)
        end
    end
    layout.Lights = {}
    for _, spec in base.Lights or {} do
        local part = get("Light", spec.name)
        if part then
            local updated = table.clone(spec)
            updated.pos = relative(part, origin)
            updated.color = part.Color
            local range, brightness = part:GetAttribute("Range"), part:GetAttribute("Brightness")
            if range ~= nil and (type(range) ~= "number" or range <= 0 or range > 120) then
                fail(spec.name .. " Range must be between 0 and 120.")
            end
            if brightness ~= nil and (type(brightness) ~= "number" or brightness < 0 or brightness > 10) then
                fail(spec.name .. " Brightness must be between 0 and 10.")
            end
            updated.range = type(range) == "number" and range or spec.range
            updated.brightness = type(brightness) == "number" and brightness or spec.brightness
            table.insert(layout.Lights, updated)
        end
    end
    for key in markers do
        if not used[key] then
            fail("Unknown lobby marker " .. key .. "; new gameplay areas need a matching mode definition.")
        end
    end
    if #errors > 0 then
        return nil, errors
    end
    layout.SourceGeometry = geometry:Clone()
    layout.Pieces = {}
    return layout, {}
end

return LobbyAuthoring
