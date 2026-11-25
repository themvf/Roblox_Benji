-- Reusable Industrial & Sci-Fi Map Assembly Kit for Lune map build scripts.
-- Eliminates bespoke boilerplate and produces detailed, X-symmetrical, gritty architecture
-- compatible with tools/map.luau, Validate.lua, and MapMotionController.lua.
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local Instance = roblox.Instance

local Kit = {}

Kit.COLORS = {
    FloorSeam = Color3.fromRGB(22, 26, 34),
    FloorDark = Color3.fromRGB(48, 54, 64),
    FloorMid = Color3.fromRGB(60, 68, 80),
    FloorSouthA = Color3.fromRGB(54, 52, 60),
    FloorSouthB = Color3.fromRGB(66, 62, 70),
    CatwalkSteel = Color3.fromRGB(82, 92, 108),
    PatchSteel = Color3.fromRGB(92, 102, 116),
    OilSlick = Color3.fromRGB(12, 15, 20),
    Wall = Color3.fromRGB(40, 46, 56),
    WallPanel = Color3.fromRGB(58, 66, 78),
    WallRib = Color3.fromRGB(26, 30, 38),
    DarkSteel = Color3.fromRGB(36, 42, 52),
    PipeSteel = Color3.fromRGB(82, 92, 106),
    Bridge = Color3.fromRGB(66, 74, 88),
    Cover = Color3.fromRGB(102, 112, 126),
    CeilingDeck = Color3.fromRGB(30, 35, 44),
    SkylightWhite = Color3.fromRGB(210, 232, 255),
    SkylightWarm = Color3.fromRGB(255, 210, 174),
    AmberDeck = Color3.fromRGB(124, 52, 22),
    TrimOrange = Color3.fromRGB(255, 68, 8),
    OrangeLight = Color3.fromRGB(255, 102, 24),
    TrimCyan = Color3.fromRGB(0, 196, 255),
    CryoGlow = Color3.fromRGB(16, 180, 255),
    CryoSpill = Color3.fromRGB(58, 206, 248),
    FaultRed = Color3.fromRGB(255, 58, 42),
    HazardYellow = Color3.fromRGB(235, 156, 18),
    HazardBlack = Color3.fromRGB(22, 24, 28),
    TrimNeutral = Color3.fromRGB(215, 230, 246),
    CableBlack = Color3.fromRGB(20, 24, 30),
    GlassBlue = Color3.fromRGB(120, 190, 224),
    GlassWarm = Color3.fromRGB(224, 156, 112),
}

Kit.VARIANTS = {
    ConcreteFloor = "Ind_ConcreteFloor",
    GunmetalWall = "Ind_GunmetalWall",
    DiamondTread = "Ind_DiamondTread",
    ForgeSoot = "Ind_ForgeSootMetal",
}

local function resolveColor(colorKeyOrColor)
    if typeof(colorKeyOrColor) == "Color3" then
        return colorKeyOrColor
    end
    return Kit.COLORS[colorKeyOrColor] or Kit.COLORS.Cover
end

function Kit.makePart(parent, name, pos, size, rot, colorKey, materialName, decor, shape, matVariant)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Shape = shape or Enum.PartType.Block
    p.CanCollide = not decor
    p.CanQuery = not decor
    p.CanTouch = false
    p.CastShadow = not decor
    p.Size = Vector3.new(size[1], size[2], size[3])
    local cf = CFrame.new(pos[1], pos[2], pos[3])
    if rot then
        cf = cf * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
    end
    p.CFrame = cf
    p.Color = resolveColor(colorKey)
    p.Material = Enum.Material[materialName or "Metal"]
    if matVariant and matVariant ~= "" then
        p.MaterialVariant = matVariant
    end
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function Kit.makeMirrored(parent, name, pos, size, rot, colorKey, materialName, decor, shape, matVariant)
    local a = Kit.makePart(parent, "Red_" .. name, pos, size, rot, colorKey, materialName, decor, shape, matVariant)
    local mPos = { -pos[1], pos[2], pos[3] }
    local mRot = rot and { rot[1], -rot[2], -rot[3] } or nil
    local b = Kit.makePart(parent, "Blue_" .. name, mPos, size, mRot, colorKey, materialName, decor, shape, matVariant)
    return a, b
end

-- Ramp whose TOP surface meets lowPt and highPt flush (zero top-lip overhang or drop)
function Kit.makeRamp(parent, name, lowPt, highPt, width, thickness, colorKey, materialName, decor, matVariant)
    local low = Vector3.new(lowPt[1], lowPt[2], lowPt[3])
    local high = Vector3.new(highPt[1], highPt[2], highPt[3])
    local diff = high - low
    local len = diff.Magnitude
    assert(len > 0.1, "Ramp length too short: " .. name)
    local fwd = diff.Unit
    local right = fwd:Cross(Vector3.new(0, 1, 0)).Unit
    local up = right:Cross(fwd).Unit
    local t = thickness or 1
    local center = (low + high) * 0.5 - up * (t * 0.5)

    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = Vector3.new(width, t, len)
    p.CFrame = CFrame.fromMatrix(center, right, up)
    p.CanCollide = not decor
    p.CanQuery = not decor
    p.CanTouch = false
    p.CastShadow = true
    p.Color = resolveColor(colorKey or "Bridge")
    p.Material = Enum.Material[materialName or "DiamondPlate"]
    if matVariant and matVariant ~= "" then
        p.MaterialVariant = matVariant
    end
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

function Kit.makeRampMirrored(parent, name, lowPt, highPt, width, thickness, colorKey, materialName, decor, matVariant)
    local a =
        Kit.makeRamp(parent, "Red_" .. name, lowPt, highPt, width, thickness, colorKey, materialName, decor, matVariant)
    local b = Kit.makeRamp(
        parent,
        "Blue_" .. name,
        { -lowPt[1], lowPt[2], lowPt[3] },
        { -highPt[1], highPt[2], highPt[3] },
        width,
        thickness,
        colorKey,
        materialName,
        decor,
        matVariant
    )
    return a, b
end

-- Grounded steel stringer curbs + vertical underside stanchions so ramps never look like floating slabs
function Kit.addRampSupportMirrored(solidParent, decorParent, name, lowPt, highPt, width, thickness, accentKey)
    local t = thickness or 1
    for _, sx in { -1, 1 } do
        local lp = { sx * lowPt[1], lowPt[2], lowPt[3] }
        local hp = { sx * highPt[1], highPt[2], highPt[3] }
        local prefix = (sx == 1 and "Red_" or "Blue_") .. name
        local low = Vector3.new(lp[1], lp[2], lp[3])
        local high = Vector3.new(hp[1], hp[2], hp[3])
        local diff = high - low
        local len = diff.Magnitude
        local fwd = diff.Unit
        local right = fwd:Cross(Vector3.new(0, 1, 0)).Unit
        local up = right:Cross(fwd).Unit
        local midTop = (low + high) * 0.5
        -- Angled side steel stringers + neon guide trim along left/right ramp edges
        for sideIdx, sideSign in { -1, 1 } do
            local edgeOffset = right * (sideSign * (width * 0.5 + 0.16)) + up * 0.12 - up * (t * 0.5)
            local curb = Instance.new("Part")
            curb.Name = ("%s_Curb_%d"):format(prefix, sideIdx)
            curb.Anchored = true
            curb.Size = Vector3.new(0.32, t + 0.35, len)
            curb.CFrame = CFrame.fromMatrix(midTop + edgeOffset, right, up)
            curb.CanCollide = false
            curb.CanQuery = false
            curb.CanTouch = false
            curb.CastShadow = true
            curb.Color = Kit.COLORS.WallRib
            curb.Material = Enum.Material.Metal
            curb.Parent = decorParent

            local neon = Instance.new("Part")
            neon.Name = ("%s_EdgeGlow_%d"):format(prefix, sideIdx)
            neon.Anchored = true
            neon.Size = Vector3.new(0.14, 0.16, math.max(1, len - 0.8))
            neon.CFrame = CFrame.fromMatrix(midTop + edgeOffset + up * ((t + 0.35) * 0.5 + 0.08), right, up)
            neon.CanCollide = false
            neon.CanQuery = false
            neon.CanTouch = false
            neon.CastShadow = false
            neon.Color = resolveColor(accentKey or "TrimCyan")
            neon.Material = Enum.Material.Neon
            neon.Parent = decorParent
        end
        -- Vertical steel stanchion pairs supporting the upper half of the ramp cleanly to floor Y=0
        for _, frac in { 0.55, 0.85 } do
            local topPt = low + diff * frac - up * (t * 0.9)
            local h = math.max(0.6, topPt.Y)
            for sIdx, sideSign in { -1, 1 } do
                local colPt = topPt + right * (sideSign * (width * 0.5 - 0.8))
                Kit.buildIBeam(
                    solidParent,
                    ("%s_Stanchion_%d_%d"):format(prefix, math.round(frac * 100), sIdx),
                    colPt.X,
                    colPt.Z,
                    h,
                    1.1,
                    1.1,
                    "WallRib",
                    false
                )
            end
        end
    end
end

function Kit.addLight(parent, color, brightness, range, shadows)
    local light = Instance.new("PointLight")
    light.Color = resolveColor(color)
    light.Brightness = brightness
    light.Range = range
    light.Shadows = shadows == true
    light.Parent = parent
    return light
end

function Kit.addSpotLight(parent, face, color, brightness, range, angleDeg, shadows)
    local spot = Instance.new("SpotLight")
    spot.Face = face
    spot.Color = resolveColor(color)
    spot.Brightness = brightness
    spot.Range = range
    spot.Angle = angleDeg or 95
    spot.Shadows = shadows == true
    spot.Parent = parent
    return spot
end

function Kit.makeCylinder(
    parent,
    name,
    pos,
    height,
    diameter,
    colorKey,
    materialName,
    decor,
    transparency,
    rot,
    matVariant
)
    local r = rot or { 0, 0, 90 }
    local p = Kit.makePart(
        parent,
        name,
        pos,
        { height, diameter, diameter },
        r,
        colorKey,
        materialName,
        decor,
        Enum.PartType.Cylinder,
        matVariant
    )
    if transparency then
        p.Transparency = transparency
    end
    return p
end

-- Pipe between two 3D points with automatic bolted dark-steel flange clamps every clampStep studs
function Kit.makePipeSegment(parent, name, p1, p2, diameter, colorKey, matName, clampStep, matVariant)
    local v1 = Vector3.new(p1[1], p1[2], p1[3])
    local v2 = Vector3.new(p2[1], p2[2], p2[3])
    local diff = v2 - v1
    local len = diff.Magnitude
    if len < 0.05 then
        return nil
    end
    local mid = (v1 + v2) * 0.5
    local dir = diff.Unit
    local up = if math.abs(dir.Y) > 0.98 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
    local lookCF = CFrame.lookAt(mid, v2, up)
    -- Cylinder height axis is local X; rotate lookCF (-Z look) -> +X cylinder axis via +90 deg around Y
    local pipeCF = lookCF * CFrame.Angles(0, math.rad(90), 0)

    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Shape = Enum.PartType.Cylinder
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Size = Vector3.new(len, diameter, diameter)
    p.CFrame = pipeCF
    p.Color = resolveColor(colorKey or "PipeSteel")
    p.Material = Enum.Material[matName or "Metal"]
    if matVariant then
        p.MaterialVariant = matVariant
    end
    p.Parent = parent

    local step = clampStep or 16
    if step > 0 and len > step * 0.75 then
        local count = math.floor(len / step)
        for i = 1, count do
            local frac = (i / (count + 1)) - 0.5
            local offset = diff * frac
            local clamp = Instance.new("Part")
            clamp.Name = name .. "_Clamp_" .. i
            clamp.Anchored = true
            clamp.Shape = Enum.PartType.Cylinder
            clamp.CanCollide = false
            clamp.CanQuery = false
            clamp.CanTouch = false
            clamp.CastShadow = false
            clamp.Size = Vector3.new(math.min(1.1, diameter * 0.65), diameter * 1.28, diameter * 1.28)
            clamp.CFrame = (pipeCF + offset)
            clamp.Color = Kit.COLORS.WallRib
            clamp.Material = Enum.Material.Metal
            clamp.Parent = parent
        end
    end
    return p
end

-- Smooth draped hanging power cable between two anchors (visual grit)
function Kit.makeDrapedCable(parent, name, p1, p2, sag, segments, diameter, colorKey)
    local n = math.max(3, segments or 6)
    local d = diameter or 0.35
    local drop = sag or 2.0
    local pts = {}
    for i = 0, n do
        local t = i / n
        local x = p1[1] + (p2[1] - p1[1]) * t
        local z = p1[3] + (p2[3] - p1[3]) * t
        local baseY = p1[2] + (p2[2] - p1[2]) * t
        local curve = 4 * t * (1 - t) * drop
        table.insert(pts, { x, baseY - curve, z })
    end
    for i = 1, n do
        Kit.makePipeSegment(
            parent,
            ("%s_Seg%d"):format(name, i),
            pts[i],
            pts[i + 1],
            d,
            colorKey or "CableBlack",
            "Rubber",
            0
        )
    end
end

-- Crisp industrial hazard chevron strip rendered purely with SurfaceGui (no texture upload needed)
function Kit.makeHazardStrip(parent, name, pos, length, width, rotY, yPos)
    local strip = Kit.makePart(
        parent,
        name,
        { pos[1], yPos or pos[2], pos[3] },
        { length, 0.04, width },
        { 0, rotY or 0, 0 },
        "HazardBlack",
        "SmoothPlastic",
        true
    )
    local gui = Instance.new("SurfaceGui")
    gui.Name = "HazardStripes"
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 16
    gui.LightInfluence = 0.6
    gui.Parent = strip

    local container = Instance.new("Frame")
    container.Size = roblox.UDim2.new(1, 0, 1, 0)
    container.BackgroundColor3 = Kit.COLORS.HazardBlack
    container.BorderSizePixel = 0
    container.ClipsDescendants = true
    container.Parent = gui

    local numBars = math.max(4, math.floor(length / 2.2))
    local barStep = 1 / numBars
    for i = -1, numBars + 1 do
        local bar = Instance.new("Frame")
        bar.Size = roblox.UDim2.new(barStep * 0.48, 0, 2.2, 0)
        bar.Position = roblox.UDim2.new(i * barStep, 0, -0.6, 0)
        bar.Rotation = 28
        bar.BackgroundColor3 = Kit.COLORS.HazardYellow
        bar.BackgroundTransparency = 0.14
        bar.BorderSizePixel = 0
        bar.Parent = container
    end
    return strip
end

function Kit.makeOilSlick(parent, name, x, z, diameter)
    return Kit.makeCylinder(parent, name, { x, 0.068, z }, 0.02, diameter, "OilSlick", "Glass", true, 0.32)
end

function Kit.makePatchPlate(parent, name, x, z, w, d, yawDeg)
    local plate = Kit.makePart(
        parent,
        name,
        { x, 0.075, z },
        { w, 0.05, d },
        { 0, yawDeg or 4, 0 },
        "PatchSteel",
        "DiamondPlate",
        true
    )
    return plate
end

-- Structural steel H/I-beam column (web + 2 end flanges)
function Kit.buildIBeam(parent, name, x, z, height, w, d, colorKey, decor)
    local y = height * 0.5
    local c = colorKey or "WallRib"
    Kit.makePart(parent, name .. "_Web", { x, y, z }, { w * 0.38, height, d }, nil, c, "Metal", decor)
    Kit.makePart(parent, name .. "_FlangeN", { x, y, z - d * 0.42 }, { w, height, d * 0.18 }, nil, c, "Metal", decor)
    Kit.makePart(parent, name .. "_FlangeS", { x, y, z + d * 0.42 }, { w, height, d * 0.18 }, nil, c, "Metal", decor)
end

-- Diagonal X-brace bay between spans (along X or Z)
function Kit.buildXBrace(parent, name, pos, spanLen, height, axis, thickness, colorKey)
    local diag = math.sqrt(spanLen * spanLen + height * height)
    local angleDeg = math.deg(math.atan2(height, spanLen))
    local thick = thickness or 0.45
    if axis == "X" then
        Kit.makePart(
            parent,
            name .. "_DiagA",
            pos,
            { diag, thick, thick },
            { 0, 0, angleDeg },
            colorKey or "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            parent,
            name .. "_DiagB",
            pos,
            { diag, thick, thick },
            { 0, 0, -angleDeg },
            colorKey or "WallRib",
            "Metal",
            true
        )
    else
        Kit.makePart(
            parent,
            name .. "_DiagA",
            pos,
            { thick, thick, diag },
            { angleDeg, 0, 0 },
            colorKey or "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            parent,
            name .. "_DiagB",
            pos,
            { thick, thick, diag },
            { -angleDeg, 0, 0 },
            colorKey or "WallRib",
            "Metal",
            true
        )
    end
end

-- Chamfered octagonal Blast-Door Portal Frame (matches Mockup 2)
function Kit.buildChamferedPortal(
    solidParent,
    decorParent,
    name,
    x,
    z,
    width,
    lintelY,
    topY,
    depth,
    alongX,
    trimKey,
    labelText
)
    local hh = topY - lintelY
    local cy = lintelY + hh * 0.5
    local halfW = width * 0.5
    if alongX then
        -- Top header beam + heavy chamfered diagonal shoulder gussets
        Kit.makePart(
            solidParent,
            name,
            { x, cy, z },
            { width, hh, depth },
            nil,
            "Wall",
            "Metal",
            false,
            nil,
            Kit.VARIANTS.GunmetalWall
        )
        Kit.makePart(
            decorParent,
            name .. "_TopCap",
            { x, topY - 0.5, z },
            { width + 2, 1.1, depth + 0.8 },
            nil,
            "WallRib",
            "Metal",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_LintelLip",
            { x, lintelY + 0.35, z },
            { width + 0.4, 0.7, depth + 0.7 },
            nil,
            "WallRib",
            "DiamondPlate",
            true
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonLintel",
            { x, lintelY + 0.08, z },
            { width - 2, 0.3, depth + 0.85 },
            nil,
            trimKey,
            "Neon",
            true
        )

        -- Left & Right heavy jamb buttresses + horizontal louvers + angled top bevel struts
        for _, sx in { -1, 1 } do
            local jx = x + sx * (halfW + 1.4)
            Kit.makePart(
                solidParent,
                ("%s_JambSolid_%d"):format(name, sx),
                { jx, topY * 0.5, z },
                { 2.8, topY, depth + 0.8 },
                nil,
                "WallRib",
                "Metal",
                false
            )
            Kit.makePart(
                decorParent,
                ("%s_JambGlow_%d"):format(name, sx),
                { jx - sx * 1.42, (lintelY - 2) * 0.5, z },
                { 0.28, lintelY - 2, depth + 0.9 },
                nil,
                trimKey,
                "Neon",
                true
            )
            -- 45-degree chamfer shoulder gussets clipping upper portal corners
            Kit.makePart(
                solidParent,
                ("%s_Chamfer_%d"):format(name, sx),
                { x + sx * (halfW - 2.4), lintelY - 1.8, z },
                { 7.2, 2.2, depth + 0.95 },
                { 0, 0, sx * -45 },
                "WallRib",
                "Metal",
                false
            )
            Kit.makePart(
                decorParent,
                ("%s_ChamferGlow_%d"):format(name, sx),
                { x + sx * (halfW - 2.2), lintelY - 2.1, z },
                { 6.6, 0.32, depth + 1.05 },
                { 0, 0, sx * -45 },
                trimKey,
                "Neon",
                true
            )
            -- Horizontal armor louvers on jamb faces
            for ly = 2.0, 9.5, 2.5 do
                Kit.makePart(
                    decorParent,
                    ("%s_Louver_%d_%g"):format(name, sx, ly),
                    { jx, ly, z },
                    { 2.2, 0.7, depth + 1.2 },
                    nil,
                    "DarkSteel",
                    "Metal",
                    true
                )
            end
        end

        -- Overhead bundled manifold conduits across the portal lintel face
        for i, py in { lintelY + 1.8, lintelY + 3.0, lintelY + 4.2 } do
            Kit.makePipeSegment(
                decorParent,
                ("%s_HeaderPipe_%d"):format(name, i),
                { x - halfW + 1, py, z + (depth * 0.5 + 0.45) },
                { x + halfW - 1, py, z + (depth * 0.5 + 0.45) },
                0.55,
                "PipeSteel",
                "Metal",
                10
            )
            Kit.makePipeSegment(
                decorParent,
                ("%s_HeaderPipeB_%d"):format(name, i),
                { x - halfW + 1, py, z - (depth * 0.5 + 0.45) },
                { x + halfW - 1, py, z - (depth * 0.5 + 0.45) },
                0.55,
                "PipeSteel",
                "Metal",
                10
            )
        end

        -- Portal ceiling worklight pool + hazard threshold border
        local pLight = Kit.makePart(
            decorParent,
            name .. "_DownLight",
            { x, lintelY - 0.15, z },
            { 6, 0.3, 1.8 },
            nil,
            trimKey,
            "Neon",
            true
        )
        Kit.addLight(pLight, trimKey == "TrimOrange" and Kit.COLORS.OrangeLight or Kit.COLORS.CryoGlow, 1.6, 38, true)
        Kit.makeHazardStrip(decorParent, name .. "_ThresholdHazard", { x, 0.08, z }, width - 2, 1.8, 0, 0.08)

        if labelText then
            local sign = Kit.makePart(
                decorParent,
                name .. "_Sign",
                { x, lintelY + 6.2, z },
                { math.min(20, width - 6), 2.4, depth + 0.6 },
                nil,
                "WallRib",
                "Metal",
                true
            )
            local guiF = Instance.new("SurfaceGui")
            guiF.Name = "PortalSignF"
            guiF.Face = Enum.NormalId.Front
            guiF.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            guiF.PixelsPerStud = 18
            guiF.Parent = sign
            local lblF = Instance.new("TextLabel")
            lblF.Size = roblox.UDim2.new(1, 0, 1, 0)
            lblF.BackgroundColor3 = Kit.COLORS.WallRib
            lblF.BackgroundTransparency = 0.08
            lblF.BorderSizePixel = 0
            lblF.Text = labelText
            lblF.TextScaled = true
            local f = roblox.Font.fromEnum(Enum.Font.RobotoMono)
            f.Weight = Enum.FontWeight.Bold
            lblF.FontFace = f
            lblF.TextColor3 = resolveColor(trimKey)
            lblF.Parent = guiF
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = roblox.UDim.new(0.06, 0)
            pad.PaddingRight = roblox.UDim.new(0.06, 0)
            pad.PaddingTop = roblox.UDim.new(0.14, 0)
            pad.PaddingBottom = roblox.UDim.new(0.14, 0)
            pad.Parent = lblF
            local stroke = Instance.new("UIStroke")
            stroke.Color = resolveColor(trimKey)
            stroke.Thickness = 2
            stroke.Transparency = 0.35
            stroke.Parent = lblF
            local guiB = guiF:Clone()
            guiB.Name = "PortalSignB"
            guiB.Face = Enum.NormalId.Back
            guiB.Parent = sign
        end
    else
        Kit.makePart(
            solidParent,
            name,
            { x, cy, z },
            { depth, hh, width },
            nil,
            "Wall",
            "Metal",
            false,
            nil,
            Kit.VARIANTS.GunmetalWall
        )
        Kit.makePart(
            decorParent,
            name .. "_NeonLintel",
            { x, lintelY + 0.25, z },
            { depth + 0.7, 0.35, width },
            nil,
            trimKey,
            "Neon",
            true
        )
        for _, sz in { -1, 1 } do
            local jz = z + sz * halfW
            Kit.makePart(
                solidParent,
                ("%s_Jamb_%d"):format(name, sz),
                { x, topY * 0.5, jz },
                { depth + 1.0, topY, 2.2 },
                nil,
                "WallRib",
                "Metal",
                false,
                nil,
                Kit.VARIANTS.GunmetalWall
            )
        end
        if labelText then
            local sign = Kit.makePart(
                decorParent,
                name .. "_Sign",
                { x, lintelY + 4.2, z },
                { depth + 0.6, 2.2, math.min(16, width - 2) },
                nil,
                "WallRib",
                "Metal",
                true
            )
            local guiL = Instance.new("SurfaceGui")
            guiL.Name = "PortalSignL"
            guiL.Face = Enum.NormalId.Left
            guiL.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            guiL.PixelsPerStud = 18
            guiL.Parent = sign
            local lbl = Instance.new("TextLabel")
            lbl.Size = roblox.UDim2.new(1, 0, 1, 0)
            lbl.BackgroundColor3 = Kit.COLORS.WallRib
            lbl.BackgroundTransparency = 0.08
            lbl.BorderSizePixel = 0
            lbl.Text = labelText
            lbl.TextScaled = true
            local f = roblox.Font.fromEnum(Enum.Font.RobotoMono)
            f.Weight = Enum.FontWeight.Bold
            lbl.FontFace = f
            lbl.TextColor3 = resolveColor(trimKey)
            lbl.Parent = guiL
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = roblox.UDim.new(0.06, 0)
            pad.PaddingRight = roblox.UDim.new(0.06, 0)
            pad.PaddingTop = roblox.UDim.new(0.14, 0)
            pad.PaddingBottom = roblox.UDim.new(0.14, 0)
            pad.Parent = lbl
            local stroke = Instance.new("UIStroke")
            stroke.Color = resolveColor(trimKey)
            stroke.Thickness = 2
            stroke.Transparency = 0.35
            stroke.Parent = lbl
            local guiR = guiL:Clone()
            guiR.Name = "PortalSignR"
            guiR.Face = Enum.NormalId.Right
            guiR.Parent = sign
        end
    end
end

-- Symmetric Staggered Angled Blast-Shield Bunker (chest/waist cover)
function Kit.buildBlastShield(solidParent, decorParent, name, pos, yawDeg, width, height, depth, trimKey)
    local x, baseY, z = pos[1], pos[2] or 0, pos[3]
    local rot = { 0, yawDeg, 0 }
    Kit.makePart(
        solidParent,
        name,
        { x, baseY + height * 0.5, z },
        { width, height, depth },
        rot,
        "DarkSteel",
        "Metal",
        false
    )
    Kit.makePart(
        decorParent,
        name .. "_BaseSkirt",
        { x, baseY + 0.35, z },
        { width + 0.7, 0.7, depth + 0.7 },
        rot,
        "WallRib",
        "DiamondPlate",
        true
    )
    Kit.makePart(
        decorParent,
        name .. "_Cap",
        { x, baseY + height + 0.15, z },
        { width + 0.4, 0.35, depth + 0.4 },
        rot,
        "WallRib",
        "Metal",
        false
    )
    Kit.makePart(
        decorParent,
        name .. "_Panel",
        { x, baseY + height * 0.54, z },
        { width * 0.76, height * 0.58, depth + 0.22 },
        rot,
        "WallPanel",
        "CorrodedMetal",
        true
    )
    Kit.makePart(
        decorParent,
        name .. "_Slit",
        { x, baseY + height * 0.68, z },
        { width * 0.66, 0.26, depth + 0.35 },
        rot,
        trimKey,
        "Neon",
        true
    )
end

-- Atmospheric Particle Helpers
function Kit.buildSteamVent(parent, name, pos, dirNormal, colorKey)
    local node = Kit.makePart(parent, name, pos, { 0.8, 0.8, 0.8 }, nil, "WallRib", "Metal", true)
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "SteamBurst"
    pe.Color = roblox.ColorSequence.new(resolveColor(colorKey or "TrimNeutral"))
    pe.Size = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.8),
        roblox.NumberSequenceKeypoint.new(1, 3.8),
    })
    pe.Transparency = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.68),
        roblox.NumberSequenceKeypoint.new(1, 1),
    })
    pe.Lifetime = roblox.NumberRange.new(1.2, 2.0)
    pe.Rate = 8
    pe.Speed = roblox.NumberRange.new(6, 10)
    pe.EmissionDirection = dirNormal or Enum.NormalId.Front
    pe.SpreadAngle = roblox.Vector2.new(18, 18)
    pe.Parent = node
    return node
end

function Kit.buildEmberPlume(parent, name, pos)
    local node = Kit.makePart(parent, name, pos, { 1.5, 0.2, 1.5 }, nil, "TrimOrange", "SmoothPlastic", true)
    node.Transparency = 1
    local pe = Instance.new("ParticleEmitter")
    pe.Name = "ForgeEmbers"
    pe.Color = roblox.ColorSequence.new(Kit.COLORS.TrimOrange, Kit.COLORS.OrangeLight)
    pe.LightEmission = 1
    pe.Size = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.25),
        roblox.NumberSequenceKeypoint.new(1, 0.05),
    })
    pe.Transparency = roblox.NumberSequence.new({
        roblox.NumberSequenceKeypoint.new(0, 0.1),
        roblox.NumberSequenceKeypoint.new(1, 1),
    })
    pe.Lifetime = roblox.NumberRange.new(1.5, 2.8)
    pe.Rate = 12
    pe.Speed = roblox.NumberRange.new(4, 8)
    pe.EmissionDirection = Enum.NormalId.Top
    pe.SpreadAngle = roblox.Vector2.new(25, 25)
    pe.Parent = node
    return node
end

-- World AABB bounds & grounded prop placement helpers
function Kit.computeBounds(inst)
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, d in inst:GetDescendants() do
        if d:IsA("BasePart") then
            local cf = d.CFrame
            local p = cf.Position
            local s = d.Size * 0.5
            local rx = math.abs(cf.RightVector.X) * s.X
                + math.abs(cf.UpVector.X) * s.Y
                + math.abs(cf.LookVector.X) * s.Z
            local ry = math.abs(cf.RightVector.Y) * s.X
                + math.abs(cf.UpVector.Y) * s.Y
                + math.abs(cf.LookVector.Y) * s.Z
            local rz = math.abs(cf.RightVector.Z) * s.X
                + math.abs(cf.UpVector.Z) * s.Y
                + math.abs(cf.LookVector.Z) * s.Z
            minV = Vector3.new(math.min(minV.X, p.X - rx), math.min(minV.Y, p.Y - ry), math.min(minV.Z, p.Z - rz))
            maxV = Vector3.new(math.max(maxV.X, p.X + rx), math.max(maxV.Y, p.Y + ry), math.max(maxV.Z, p.Z + rz))
        end
    end
    return minV, maxV
end

local function isFxNode(d)
    local n = d.Name
    return n:find("Node") ~= nil
        or n:find("Vent") ~= nil
        or n:find("Wisp") ~= nil
        or n:find("Vapor") ~= nil
        or n:find("Plume") ~= nil
        or n:find("Glow") ~= nil
        or n:find("Beam") ~= nil
end

function Kit.placeAssetClone(template, parent, name, targetPos, deltaYawDeg, scale, decor)
    assert(template ~= nil, "Missing asset template for " .. name)
    local s = scale or 1
    local clone = template:Clone()
    clone.Name = name
    local minV, maxV = Kit.computeBounds(clone)
    local origCF = CFrame.new((minV.X + maxV.X) * 0.5, minV.Y, (minV.Z + maxV.Z) * 0.5)
    local targetCF = CFrame.new(targetPos[1], targetPos[2], targetPos[3])
        * CFrame.Angles(0, math.rad(deltaYawDeg or 0), 0)

    local toRemove = {}
    for _, d in clone:GetDescendants() do
        if d:IsA("LuaSourceContainer") or d:IsA("TouchTransmitter") then
            table.insert(toRemove, d)
        elseif d:IsA("BasePart") then
            local rel = origCF:ToObjectSpace(d.CFrame)
            local scaledRel = CFrame.new(rel.Position * s) * (rel - rel.Position)
            d.CFrame = targetCF * scaledRel
            d.Size = d.Size * s
            d.Anchored = true
            local solid = (not decor) and not isFxNode(d) and (d.Transparency < 0.99)
            d.CanCollide = solid
            d.CanQuery = solid
            d.CanTouch = false
        end
    end
    for _, bad in toRemove do
        bad:Destroy()
    end
    clone.Parent = parent
    local placedMin = Kit.computeBounds(clone)
    assert(placedMin.Y >= targetPos[2] - 0.05, string.format("%s sunk below target Y (minY=%.3f)", name, placedMin.Y))
    return clone
end

function Kit.placeOnPlinth(template, parent, decorParent, name, x, z, yawDeg, scale, plW, plD, trimKey, decor)
    local isDecor = decor == true
    Kit.makePart(
        decorParent,
        name .. "_Plinth",
        { x, 0.16, z },
        { plW, 0.32, plD },
        { 0, yawDeg, 0 },
        "WallRib",
        "DiamondPlate",
        isDecor,
        nil,
        Kit.VARIANTS.DiamondTread
    )
    Kit.makePart(
        decorParent,
        name .. "_PlinthLip",
        { x, 0.30, z },
        { plW + 0.18, 0.08, plD + 0.18 },
        { 0, yawDeg, 0 },
        trimKey,
        "Neon",
        true
    )
    return Kit.placeAssetClone(template, parent, name, { x, 0.32, z }, yawDeg, scale, isDecor)
end

function Kit.assertFloorClearance(geometryFolder, minAllowedY)
    local thresh = minAllowedY or -0.02
    local bad = 0
    for _, d in geometryFolder:GetDescendants() do
        if d:IsA("BasePart") and not d.Name:find("Ramp") then
            local cf = d.CFrame
            local s = d.Size * 0.5
            local ry = math.abs(cf.RightVector.Y) * s.X
                + math.abs(cf.UpVector.Y) * s.Y
                + math.abs(cf.LookVector.Y) * s.Z
            local miny = cf.Position.Y - ry
            if miny < thresh then
                bad += 1
                warn(string.format("BELOW FLOOR VIOLATION: %s minY=%.3f", d:GetFullName(), miny))
            end
        end
    end
    assert(bad == 0, "Found parts poking below floor!")
end

return Kit
