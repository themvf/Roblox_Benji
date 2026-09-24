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

local SOURCE = "assets/kitsource/SnowFortress.rbxm"
local OUT = "assets/environment/kit"

-- name -> which instances belong to it. `one` keeps a single representative where the map
-- holds many copies (roof tiles, ice spikes); the rest take everything that matches.
local PIECES = {
    -- The whole central building, by exclusion: everything that is not an outpost, a
    -- prop, the outer boundary, or the ground the arena sits on. Listing what it is made
    -- of would be a hundred patterns and would rot the moment anything is renamed.
    -- The whole central building. Taken from the ROOT's direct children only: the map's
    -- parts sit at the root beside two folders, Decor and BlenderEntrances, and walking
    -- all descendants would copy the facade twice -- once as its folder and once part by
    -- part. Defined by exclusion because listing what a fortress is made of would be a
    -- hundred patterns that rot the first time anything is renamed.
    {
        name = "Fortress",
        match = ".",
        topOnly = true,
        except = {
            "^Decor$",
            "^ExteriorFloor$",
            "^Wall[NSEW]$",
            "^northwest",
            "^southeast",
            "^ArtFullnorthwest",
            "^ArtFullsoutheast",
            "^IceSpike",
            "^RoofHelicopter",
            "^Helipad",
            "^SafetyBarrier",
            -- MapService draws these from layout.Spawns on every build, so a copy in the
            -- kit is a duplicate that also drags the piece 426 studs wide.
            "Spawn%d",
            "^Part$",
            "SightlineScreen",
            "ApproachCover",
        },
    },
    -- One 10x10 roof tile, all three layers: greybox slab, snow-dressed art and paving
    -- mesh. Anchored patterns, because "15_20" is also a substring of "-15_20".
    {
        name = "RoofTile",
        match = { "^FortressRoof15_20$", "^ArtFullFortressRoof15_20Snow$", "^RoofPaving15_20$" },
    },
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
    { name = "SightlineScreen", match = "SightlineScreen$", one = true, from = "assets/kitsource/_original.rbxm" },
    { name = "ApproachCover", match = "^ApproachCoverRed1$", from = "assets/kitsource/_original.rbxm" },
    { name = "CeilingLamp", match = "^CeilingLamp", one = true },

    -- Plain structural blocks. A fresh map needs something to stand on, something to hide
    -- behind and something to walk up long before it needs a fortress, and until now the
    -- kit went straight from "a 500-instance building" to "a rock". Each of these is one
    -- representative taken from Snow Fortress, so a wall dropped next to the fortress is
    -- the same slate at the same scale rather than a grey box that reads as unfinished.
    { name = "Wall", match = "^SideWall%-1_48$" },
    { name = "WallLong", match = "^EndWall1_%-42$" },
    { name = "BoundaryWall", match = "^WallE$" },
    { name = "Pillar", match = "^Support1_%-42$" },
    { name = "Railing", match = "^StairRail%-11$" },
    -- The 24 hand-authored blocks that were merged in by hand. They are not used by any
    -- rule in the map, so dropping the map would be the end of them; here they stay
    -- available as heavy cover.
    { name = "StoneBlock", match = "^Part$", one = true },
}

local roots = {}
local function rootChildren(path)
    if not roots[path] then
        roots[path] = roblox.deserializeModel(fs.readFile(path))[1]:GetChildren()
    end
    return roots[path]
end

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
                    -- Proper world-axis half-extents. Using max(size)/2 as a radius treats
                    -- a 140 x 4 x 110 floor slab as a 140-stud sphere, which inflated the
                    -- fortress to 163 studs tall and -- because this drives the recentring
                    -- -- would have dropped every piece well off the spot you placed it.
                    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
                    local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
                    local ex = math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz
                    local ey = math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz
                    local ez = math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
                    minx, miny, minz = math.min(minx, p.X - ex), math.min(miny, p.Y - ey), math.min(minz, p.Z - ez)
                    maxx, maxy, maxz = math.max(maxx, p.X + ex), math.max(maxy, p.Y + ey), math.max(maxz, p.Z + ez)
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
    local patterns = type(spec.match) == "table" and spec.match or { spec.match }
    local source = spec.from or SOURCE
    -- A `from` that is not on disk means the piece was cut from a bake that no longer
    -- exists -- the screens and the approach cover came out of the map's first bake,
    -- which was a scratch file and never committed. The .rbxm they produced IS committed,
    -- so the right answer is to leave it alone and say so. Failing here instead made the
    -- whole builder unrunnable, which is how five other pieces went unwritten above.
    if not fs.isFile(source) then
        print(("KEEP  %-20s %s is gone; keeping the committed .rbxm as-is"):format(spec.name, source))
        continue
    end
    local pool = spec.topOnly and rootChildren(source) or flatten(source)
    for _, inst in pool do
        local take = false
        for _, pattern in patterns do
            if inst.Name:match(pattern) then
                take = true
                break
            end
        end
        for _, pattern in spec.except or {} do
            if inst.Name:match(pattern) then
                take = false
                break
            end
        end
        if take then
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
