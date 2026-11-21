-- Pre-play visual, lighting, grounding, and collision audit for authored source maps.
-- Usage: lune run tools/audit_map_visuals.luau [MapName]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local mapName = process.args[1] or "SciFiFoundry"
local sourcePath = ("assets/environment/source/%s.rbxm"):format(mapName)
assert(fs.isFile(sourcePath), "Missing map source: " .. sourcePath)

local root = roblox.deserializeModel(fs.readFile(sourcePath))[1]
local geometry = root:FindFirstChild("Geometry")
assert(geometry ~= nil, "Missing Geometry folder in " .. sourcePath)

local function getMaterialVariant(d)
    local ok, mv = pcall(function()
        return d.MaterialVariant
    end)
    if ok and type(mv) == "string" then
        return mv
    end
    return ""
end

local nanFrames = 0

local function boxOf(d, fromDecor)
    local cf = d.CFrame
    local s = d.Size * 0.5
    local rx = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
    local ry = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
    local rz = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
    local p = cf.Position
    if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z or rx ~= rx or ry ~= ry or rz ~= rz then
        nanFrames += 1
        print(string.format("     [NAN-CFRAME] %-30s (%s)", d.Name, d.Parent and d.Parent.Name or "?"))
    end
    return {
        inst = d,
        name = d.Name,
        parent = d.Parent and d.Parent.Name or "?",
        pos = p,
        size = d.Size,
        min = roblox.Vector3.new(p.X - rx, p.Y - ry, p.Z - rz),
        max = roblox.Vector3.new(p.X + rx, p.Y + ry, p.Z + rz),
        solid = d.CanCollide,
        mat = d.Material.Name,
        matVariant = getMaterialVariant(d),
        fromDecor = fromDecor == true,
    }
end

local items = {}
local lights = {}
local sourceCount = 0
local decorCount = 0

local function collectDescendants(container, fromDecor)
    for _, d in container:GetDescendants() do
        if d:IsA("BasePart") then
            table.insert(items, boxOf(d, fromDecor))
            if fromDecor then
                decorCount += 1
            else
                sourceCount += 1
            end
        elseif d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") then
            local rng = d:IsA("PointLight") and d.Range or (d:IsA("SpotLight") and d.Range or 0)
            table.insert(lights, {
                pos = d.Parent.CFrame.Position,
                range = rng,
                bright = d.Brightness,
            })
        end
    end
end

collectDescendants(geometry, false)

local decorPath = ("assets/environment/decor/%s.rbxmx"):format(mapName)
if fs.isFile(decorPath) then
    local decorModel = roblox.deserializeModel(fs.readFile(decorPath))[1]
    if decorModel then
        collectDescendants(decorModel, true)
    end
end

print(
    ("Visual Audit: %s (%d source + %d decor = %d BaseParts, %d Lights)"):format(
        mapName,
        sourceCount,
        decorCount,
        #items,
        #lights
    )
)

-- 1. Floor illumination coverage across [-114, 114] x [-114, 114]
local dimZones = 0
for x = -114, 114, 24 do
    for z = -114, 114, 24 do
        local sample = roblox.Vector3.new(x, 2, z)
        local score = 0
        for _, l in lights do
            local dist = (l.pos - sample).Magnitude
            if dist < l.range then
                score += l.bright * (1 - dist / l.range)
            end
        end
        if score < 0.35 then
            dimZones += 1
            print(string.format("  [LIGHT] Dim floor pocket (score=%.2f) at (%d, %d)", score, x, z))
        end
    end
end
print("  1) Dim floor zones (score < 0.35):", dimZones)

-- 2. Ramp centerline endpoints
print("  2) Ramp centerline endpoints:")
for _, item in items do
    if item.name:find("Ramp") and item.solid and not item.name:find("Stanchion") then
        local cf = item.inst.CFrame
        local halfD = item.size.Z * 0.5
        local pA = cf * roblox.Vector3.new(0, item.size.Y * 0.5, -halfD)
        local pB = cf * roblox.Vector3.new(0, item.size.Y * 0.5, halfD)
        print(
            string.format(
                "     %-22s topEdgeA=(%.1f, %.2f, %.1f)  topEdgeB=(%.1f, %.2f, %.1f)",
                item.name,
                pA.X,
                pA.Y,
                pA.Z,
                pB.X,
                pB.Y,
                pB.Z
            )
        )
    end
end

-- 3. Large non-collidable objects near player height (exclude architectural wall trim/sign/light/fx)
local passable = 0
for _, item in items do
    if not item.solid and item.min.Y < 7.0 and item.max.Y > 0.6 then
        local vol = item.size.X * item.size.Y * item.size.Z
        local isTrim = item.name:find("Neon")
            or item.name:find("Trim")
            or item.name:find("Slit")
            or item.name:find("Glow")
            or item.name:find("Beam")
            or item.name:find("Brace")
            or item.name:find("Panel")
            or item.name:find("Skirt")
            or item.name:find("Clad")
            or item.name:find("Wainscot")
            or item.name:find("Bevel")
            or item.name:find("Rim")
            or item.name:find("Girder")
            or item.name:find("Curb")
            or item.name:find("Edge")
            or item.name:find("Pilaster")
            or item.name:find("Louver")
            or item.name:find("OuterCyanRing")
            or item.name:find("InnerDarkDeck")
            or item.name:find("HousingBevel")
            or (item.fromDecor and item.name == "Glass")
        if vol > 8 and not isTrim then
            passable += 1
            print(
                string.format(
                    "     [COLLISION?] %-34s (%s) pos=(%.1f,%.1f,%.1f) size=(%.1f,%.1f,%.1f)",
                    item.name,
                    item.parent,
                    item.pos.X,
                    item.pos.Y,
                    item.pos.Z,
                    item.size.X,
                    item.size.Y,
                    item.size.Z
                )
            )
        end
    end
end
print("  3) Non-trim passable structures near player height:", passable)

-- 4. Overhead crane / canister / conduit overlaps
local overlaps = 0
for i = 1, #items do
    local a = items[i]
    if a.name:find("Crane") or a.name:find("Canister") or a.name:find("Pipe") then
        for j = 1, #items do
            if i ~= j then
                local b = items[j]
                if
                    a.parent ~= b.parent
                    and not b.name:find("Ceiling")
                    and not b.name:find("Wall")
                    and not b.name:find("Clamp")
                    and b.size.X > 1.2
                    and b.size.Y > 1.2
                    and b.size.Z > 1.2
                then
                    local ox = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
                    local oy = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
                    local oz = math.min(a.max.Z, b.max.Z) - math.max(a.min.Z, b.min.Z)
                    if ox > 0.4 and oy > 0.4 and oz > 0.4 then
                        overlaps += 1
                        print(
                            string.format(
                                "     [OVERLAP] %s (%s) <-> %s (%s) overlap=(%.1f,%.1f,%.1f)",
                                a.name,
                                a.parent,
                                b.name,
                                b.parent,
                                ox,
                                oy,
                                oz
                            )
                        )
                    end
                end
            end
        end
    end
end
print("  4) High-structure overlaps:", overlaps)

-- 5. Primary-lane traversal, step height, & deck ramp egress
local ramps = {}
for _, item in items do
    if item.name:find("Ramp") and item.solid and not item.name:find("Stanchion") then
        local cf = item.inst.CFrame
        local halfD = item.size.Z * 0.5
        local pA = cf * roblox.Vector3.new(0, item.size.Y * 0.5, -halfD)
        local pB = cf * roblox.Vector3.new(0, item.size.Y * 0.5, halfD)
        local topPt = if pA.Y >= pB.Y then pA else pB
        table.insert(ramps, { item = item, topPt = topPt })
    end
end

local egressIssues = 0
for _, item in items do
    local isDeck = item.solid
        and item.max.Y > 3.5
        and item.max.Y < 20.0
        and item.size.Y <= 2.5
        and (item.size.X * item.size.Z) >= 80
        and (item.name:find("Deck") or item.name:find("Platform") or item.name:find("Bridge") or item.name:find(
            "Gantry"
        ))
        and not item.name:find("Ceiling")
        and not item.name:find("Floor")
        and not item.name:find("Ramp")
    if isDeck then
        local connectedPts = {}
        for _, r in ramps do
            local tp = r.topPt
            local dy = math.abs(tp.Y - item.max.Y)
            local inX = tp.X >= (item.min.X - 1.5) and tp.X <= (item.max.X + 1.5)
            local inZ = tp.Z >= (item.min.Z - 1.5) and tp.Z <= (item.max.Z + 1.5)
            if dy <= 0.4 and inX and inZ then
                local distinct = true
                for _, prev in connectedPts do
                    if (prev - tp).Magnitude < 6.0 then
                        distinct = false
                        break
                    end
                end
                if distinct then
                    table.insert(connectedPts, tp)
                end
            end
        end
        if #connectedPts < 2 then
            egressIssues += 1
            print(
                string.format(
                    "     [DECK-EGRESS] %-28s topY=%.2f has only %d distinct ramp(s) (need >= 2)",
                    item.name,
                    item.max.Y,
                    #connectedPts
                )
            )
        end

        if math.max(item.size.X, item.size.Z) >= 40 then
            local hasCover = false
            for _, other in items do
                if
                    other.solid
                    and other ~= item
                    and not other.name:find("Rail")
                    and not other.name:find("Trim")
                    and not other.name:find("Post")
                    and not other.name:find("Bar")
                    and other.min.Y >= (item.max.Y - 0.15)
                    and other.min.Y <= (item.max.Y + 0.5)
                    and other.size.Y >= 2.0
                    and other.pos.X >= item.min.X
                    and other.pos.X <= item.max.X
                    and other.pos.Z >= item.min.Z
                    and other.pos.Z <= item.max.Z
                then
                    hasCover = true
                    break
                end
            end
            if not hasCover then
                egressIssues += 1
                print(
                    string.format(
                        "     [DECK-BARE] %-30s span=(%.1f x %.1f) has no upper tactical cover",
                        item.name,
                        item.size.X,
                        item.size.Z
                    )
                )
            end
        end
    end
end

local laneIssues = 0
local function isLaneExempt(name, parent)
    local combined = name .. " " .. parent
    return combined:find("MidPylon")
        or combined:find("ReactorCore")
        or combined:find("ThermalCore")
        or combined:find("Portal")
        or combined:find("Arch")
        or combined:find("Ceiling")
        or combined:find("Roof")
        or combined:find("Overhead")
        or combined:find("Crane")
        or combined:find("Pipe")
        or combined:find("Cable")
        or combined:find("Vent")
        or combined:find("Track")
        or combined:find("Beam")
        or combined:find("Floor")
        or combined:find("Terrain")
        or combined:find("Ramp")
end

for _, item in items do
    if item.solid and not isLaneExempt(item.name, item.parent) then
        local inZCorridor = math.abs(item.pos.Z) <= 7.5 and math.abs(item.pos.X) <= 86
        local inXCorridor = math.abs(item.pos.X) <= 6 and math.abs(item.pos.Z) <= 86
        if inZCorridor or inXCorridor then
            if item.min.Y <= 4.5 and item.max.Y > 0.45 and item.max.Y <= 9.5 then
                laneIssues += 1
                print(
                    string.format(
                        "     [LANE-BLOCK] %-30s pos=(%.1f,%.1f,%.1f) y=[%.2f..%.2f]",
                        item.name,
                        item.pos.X,
                        item.pos.Y,
                        item.pos.Z,
                        item.min.Y,
                        item.max.Y
                    )
                )
            elseif
                item.min.Y < 5.5
                and item.max.Y > 9.5
                and math.abs(item.pos.X) < 3.5
                and math.abs(item.pos.Z) > 10
            then
                laneIssues += 1
                print(
                    string.format(
                        "     [CENTER-PILLAR] %-27s pos=(%.1f,%.1f,%.1f) y=[%.2f..%.2f]",
                        item.name,
                        item.pos.X,
                        item.pos.Y,
                        item.pos.Z,
                        item.min.Y,
                        item.max.Y
                    )
                )
            end
        end
    end
end
print(("  5) Deck egress & centerline lane issues: %d deck, %d lane"):format(egressIssues, laneIssues))

-- 6. Prop-vs-player scale (5.5-stud player height), off-theme check, & .rbxmx overlap/grounding
local propIssues = 0
for i, item in items do
    if item.name:find("ServerRack") or item.name:find("StandingDesk") or item.name:find("Office") then
        propIssues += 1
        print(string.format("     [THEME] Off-theme prop %-30s (%s)", item.name, item.parent))
    end

    if item.fromDecor and item.min.Y < -0.05 then
        propIssues += 1
        print(string.format("     [DECOR-GROUND] %-30s minY=%.2f sinks below floor", item.name, item.min.Y))
    end

    local isHeroProp = (
        item.fromDecor
        or item.name:find("CryoTube")
        or item.name:find("ContainmentCanister")
        or item.name:find("Cargo")
    )
        and not item.name:find("Trim")
        and not item.name:find("Plinth")
        and not item.name:find("Lip")
    if isHeroProp and item.min.Y < 2.2 then
        local maxXZ = math.max(item.size.X, item.size.Z)
        if
            (item.name:find("Container") or item.name:find("Crate") or item.name:find("Box") or item.name:find("Cargo"))
            and (maxXZ > 4.6 or item.size.Y > 4.6)
        then
            propIssues += 1
            print(
                string.format(
                    "     [SCALE] Container %-26s size=(%.1f,%.1f,%.1f) vs 5.5u player",
                    item.name,
                    item.size.X,
                    item.size.Y,
                    item.size.Z
                )
            )
        elseif
            (item.name:find("Panel") or item.name:find("Console") or item.name:find("Control"))
            and (item.size.Y > 5.5 or maxXZ > 6.5)
        then
            propIssues += 1
            print(
                string.format(
                    "     [SCALE] Panel/Console %-22s size=(%.1f,%.1f,%.1f) vs 5.5u player",
                    item.name,
                    item.size.X,
                    item.size.Y,
                    item.size.Z
                )
            )
        elseif item.name:find("Generator") and (item.size.Y > 5.2 or maxXZ > 9.5) then
            propIssues += 1
            print(
                string.format(
                    "     [SCALE] Generator %-26s size=(%.1f,%.1f,%.1f) vs 5.5u player",
                    item.name,
                    item.size.X,
                    item.size.Y,
                    item.size.Z
                )
            )
        elseif (item.name:find("Chamber") or item.name:find("Tube")) and (item.size.Y > 8.5 or maxXZ > 7.5) then
            propIssues += 1
            print(
                string.format(
                    "     [SCALE] Chamber/Gen %-24s size=(%.1f,%.1f,%.1f) vs 5.5u player",
                    item.name,
                    item.size.X,
                    item.size.Y,
                    item.size.Z
                )
            )
        end
    end

    if item.fromDecor and item.solid then
        for j, other in items do
            if i ~= j and other.solid and not other.name:find("Floor") and not other.name:find("Plinth") then
                if not other.fromDecor or i < j then
                    local ox = math.min(item.max.X, other.max.X) - math.max(item.min.X, other.min.X)
                    local oy = math.min(item.max.Y, other.max.Y) - math.max(item.min.Y, other.min.Y)
                    local oz = math.min(item.max.Z, other.max.Z) - math.max(item.min.Z, other.min.Z)
                    local thresh = if other.fromDecor then 0.15 else 0.25
                    if ox > thresh and oy > thresh and oz > thresh then
                        propIssues += 1
                        print(
                            string.format(
                                "     [DECOR-OVERLAP] %s <-> %s overlap=(%.2f,%.2f,%.2f)",
                                item.name,
                                other.name,
                                ox,
                                oy,
                                oz
                            )
                        )
                    end
                end
            end
        end
    end
end
print("  6) Prop scale, grounding & .rbxmx overlap issues:", propIssues)

-- 7. Material & vanilla steel contrast balance
local steelTotal = 0
local steelVanilla = 0
local variantCounts = {}
for _, item in items do
    if not item.fromDecor then
        if item.matVariant ~= "" then
            variantCounts[item.matVariant] = (variantCounts[item.matVariant] or 0) + 1
        end
        if item.mat == "Metal" or item.mat == "DiamondPlate" then
            steelTotal += 1
            if item.matVariant == "" then
                steelVanilla += 1
            end
        end
    end
end
local steelPct = if steelTotal > 0 then (steelVanilla / steelTotal) * 100 else 100
print(
    string.format(
        "  7) Steel texture balance: %d/%d (%.1f%%) Metal+DiamondPlate parts keep vanilla steel",
        steelVanilla,
        steelTotal,
        steelPct
    )
)
local matIssues = 0
if steelTotal > 0 and steelPct < 15.0 then
    matIssues += 1
    print("     [MATERIAL] Less than 15% of steel parts keep native Metal/DiamondPlate finish!")
end

-- 8. Railing overlaps, floor cable tripwires, unplumbed wall fixtures, graybox blocks, & NaN CFrames
local craftsmanshipIssues = nanFrames

-- 8a. Separate railing assemblies overlapping each other (e.g., GantryNRail vs GantryNCenterRail)
local function railGroup(item)
    if item.name:find("Rail") then
        return item.name
    elseif item.parent:find("Rail") then
        return item.parent
    end
    return nil
end
for i = 1, #items do
    local a = items[i]
    local ga = railGroup(a)
    if ga and a.solid then
        for j = i + 1, #items do
            local b = items[j]
            local gb = railGroup(b)
            if gb and b.solid and ga ~= gb then
                local ox = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
                local oy = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
                local oz = math.min(a.max.Z, b.max.Z) - math.max(a.min.Z, b.min.Z)
                if ox > 0.15 and oy > 0.15 and oz > 0.15 then
                    craftsmanshipIssues += 1
                    print(string.format("     [RAIL-OVERLAP] %s <-> %s overlap=(%.2f,%.2f,%.2f)", ga, gb, ox, oy, oz))
                end
            end
        end
    end
end

-- 8b. Long floor cables/pipes crossing open interior combat lanes instead of hugging walls
for _, item in items do
    if
        not item.fromDecor
        and (item.name:find("Cable") or item.name:find("Conduit") or item.name:find("FloorPipe"))
        and item.max.Y < 1.2
        and math.max(item.size.X, item.size.Z) > 12.0
    then
        if math.abs(item.pos.X) < 118 and math.abs(item.pos.Z) < 123 then
            craftsmanshipIssues += 1
            print(
                string.format(
                    "     [FLOOR-CABLE] %-28s pos=(%.1f,%.1f,%.1f) len=%.1f crosses open floor",
                    item.name,
                    item.pos.X,
                    item.pos.Y,
                    item.pos.Z,
                    math.max(item.size.X, item.size.Z)
                )
            )
        end
    end
end

-- 8c. Unplumbed wall valves / cage lights (need adjacent vertical riser or conduit pipe)
for _, item in items do
    if
        item.fromDecor
        and (item.name:find("Valve") or item.name == "Pipe_Valve_Wheel" or item.name == "Light_Cage_Wall")
    then
        local hasConduit = false
        for _, other in items do
            if
                not other.fromDecor
                and (other.name:find("Riser") or other.name:find("Conduit") or other.name:find("Pipe"))
                and other.max.Y >= (item.max.Y + 2.5)
            then
                local dx = math.abs(other.pos.X - item.pos.X)
                local dz = math.abs(other.pos.Z - item.pos.Z)
                if dx <= 2.2 and dz <= 2.2 then
                    hasConduit = true
                    break
                end
            end
        end
        if not hasConduit then
            craftsmanshipIssues += 1
            print(
                string.format(
                    "     [UNPLUMBED] %-28s (%s) at (%.1f,%.1f,%.1f) has no wall riser/conduit",
                    item.name,
                    item.parent,
                    item.pos.X,
                    item.pos.Y,
                    item.pos.Z
                )
            )
        end
    end
end

-- 8d. Large untrimmed featureless floor cover cubes (graybox cover blocks)
for _, item in items do
    if
        not item.fromDecor
        and item.solid
        and item.min.Y < 1.5
        and item.size.X >= 5.5
        and item.size.Y >= 3.0
        and item.size.Z >= 5.5
    then
        local exempt = item.name:find("Wall")
            or item.name:find("Floor")
            or item.name:find("Bulkhead")
            or item.name:find("Screen")
            or item.name:find("Portal")
            or item.name:find("Pillar")
            or item.name:find("Shield")
            or item.name:find("Core")
            or item.name:find("Base")
            or item.name:find("Pylon")
            or item.name:find("Gantry")
            or item.name:find("Ramp")
            or item.name:find("Tube_")
        if not exempt then
            local trimmed = false
            for _, other in items do
                if
                    other ~= item
                    and (
                        other.name:find(item.name .. "_")
                        or (item.parent == other.parent and (other.name:find("Trim") or other.name:find("Cap")))
                    )
                then
                    trimmed = true
                    break
                end
            end
            if not trimmed then
                craftsmanshipIssues += 1
                print(
                    string.format(
                        "     [GRAYBOX] %-30s size=(%.1f,%.1f,%.1f) lacks framing/trim",
                        item.name,
                        item.size.X,
                        item.size.Y,
                        item.size.Z
                    )
                )
            end
        end
    end
end
print(("  8) Craftsmanship, plumbing & CFrame checks: %d issues (%d NaN)"):format(craftsmanshipIssues, nanFrames))

local totalFailures = dimZones
    + passable
    + overlaps
    + egressIssues
    + laneIssues
    + propIssues
    + matIssues
    + craftsmanshipIssues
if totalFailures > 0 then
    print(("AUDIT FAILED: %d total issue(s) found"):format(totalFailures))
    process.exit(1)
end
print("AUDIT PASSED: 0 issues")
