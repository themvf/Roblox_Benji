-- Cut a baked map into reusable pieces, so a new map is assembled by dragging prefabs
-- rather than by cloning a 1400-instance folder and editing it in place.
--
-- Each piece is written to assets/environment/kit/<Name>.rbxm, which Rojo maps to
-- ServerStorage.MapKit. Drag one into Workspace, put it where you want it, repeat.
--
-- Pieces are recentred: horizontally on their own middle, vertically so the lowest point
-- sits at y 0. Dropping one at a spot then puts it ON that spot, which is what dragging
-- something in should mean -- the alternative is every piece arriving at the world
-- coordinate it happened to occupy in Snow Fortress.
--
--     lune run tools/build_kit.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SOURCE = "assets/environment/baked/SnowFortress.rbxm"
local OUT = "assets/environment/kit"

-- name -> which instances belong to it. `one` keeps a single representative where the map
-- holds many copies (roof tiles, ice spikes); the rest take everything that matches.
local PIECES = {
    { name = "IceSpike", match = "^IceSpike", one = true },
    { name = "CrashedHelicopter", match = "^RoofHelicopter" },
    { name = "Helipad", match = "^Helipad" },
    { name = "SniperOutpost", match = "^northwest" },
    { name = "Staircase", match = "^UpperStair1_" },
    -- These two were deleted from the map in an editing pass, so they are pulled from the
    -- first bake instead. Both are cover, not scenery: the screens are what stops a sniper
    -- in an outpost seeing into the enemy spawn, and the approach blocks are the cover
    -- beside the launch targets. Keeping them in the kit means removing them stays a
    -- decision rather than becoming a one-way door.
    { name = "SightlineScreen", match = "SightlineScreen$", one = true, from = "assets/environment/baked/_original.rbxm" },
    { name = "ApproachCover", match = "^ApproachCoverRed1$", from = "assets/environment/baked/_original.rbxm" },
    { name = "CeilingLamp", match = "^CeilingLamp", one = true },
}

local loaded = {}
local function flatten(path)
    if loaded[path] then
        return loaded[path]
    end
    local root = roblox.deserializeModel(fs.readFile(path))[1]
    local flat = {}
    local function collect(inst)
        for _, child in inst:GetChildren() do
            table.insert(flat, child)
            collect(child)
        end
    end
    collect(root)
    loaded[path] = flat
    return flat
end

local function extents(list)
    local minx, miny, minz = math.huge, math.huge, math.huge
    local maxx, maxy, maxz = -math.huge, -math.huge, -math.huge
    local found = false
    for _, inst in list do
        local walkList = { inst }
        local i = 1
        while i <= #walkList do
            local node = walkList[i]
            if node:IsA("BasePart") then
                local ok, cf = pcall(function()
                    return node.CFrame
                end)
                local oks, size = pcall(function()
                    return node.Size
                end)
                if ok and oks then
                    found = true
                    local p = cf.Position
                    local r = math.max(size.X, size.Y, size.Z) / 2
                    minx, miny, minz = math.min(minx, p.X - r), math.min(miny, p.Y - r), math.min(minz, p.Z - r)
                    maxx, maxy, maxz = math.max(maxx, p.X + r), math.max(maxy, p.Y + r), math.max(maxz, p.Z + r)
                end
            end
            for _, c in node:GetChildren() do
                table.insert(walkList, c)
            end
            i += 1
        end
    end
    if not found then
        return nil
    end
    return { minx, miny, minz }, { maxx, maxy, maxz }
end

local function shift(inst, dx, dy, dz)
    local walkList = { inst }
    local i = 1
    while i <= #walkList do
        local node = walkList[i]
        if node:IsA("BasePart") then
            local ok, cf = pcall(function()
                return node.CFrame
            end)
            if ok then
                node.CFrame = cf + roblox.Vector3.new(dx, dy, dz)
            end
        end
        for _, c in node:GetChildren() do
            table.insert(walkList, c)
        end
        i += 1
    end
end

local made = 0
for _, spec in PIECES do
    local hits = {}
    for _, inst in flatten(spec.from or SOURCE) do
        if inst.Name:match(spec.match) then
            table.insert(hits, inst)
            if spec.one then
                break
            end
        end
    end
    if #hits == 0 then
        print(("SKIP  %-20s nothing matched %q"):format(spec.name, spec.match))
        continue
    end

    local model = roblox.Instance.new("Model")
    model.Name = spec.name
    local copies = {}
    for _, inst in hits do
        local copy = inst:Clone()
        copy.Parent = model
        table.insert(copies, copy)
    end

    local low, high = extents(copies)
    if low then
        shift(model, -(low[1] + high[1]) / 2, -low[2], -(low[3] + high[3]) / 2)
    end

    local count = 0
    local walkList = { model }
    local i = 1
    while i <= #walkList do
        count += 1
        for _, c in walkList[i]:GetChildren() do
            table.insert(walkList, c)
        end
        i += 1
    end

    fs.writeFile(OUT .. "/" .. spec.name .. ".rbxm", roblox.serializeModel({ model }))
    made += 1
    local size = low and ("%.0f x %.0f x %.0f studs"):format(high[1] - low[1], high[2] - low[2], high[3] - low[3])
        or "no parts"
    print(("OK    %-20s %3d instances, %s"):format(spec.name, count - 1, size))
end

print(("\n%d kit pieces written to %s"):format(made, OUT))
