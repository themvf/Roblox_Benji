-- Dresses a character in a kit's look: generated armour pieces welded to its R15 body parts.
--
-- A look is made and approved with tools/kit_look.py (the kit-look skill), exported as one
-- model and uploaded; its registry entry (`<kit-id>-look` in Shared/AssetRegistry) holds the
-- asset id and `kitLook`: each piece's mesh name, body part and offset from that part's
-- centre in studs, and which body parts the armour replaces.
--
-- The pieces are cosmetic. Each is massless, does not collide, touch or take raycasts, and
-- is welded to the body part it belongs to, so it animates with the character and the R15
-- hitbox is unchanged. A body part the armour replaces is made invisible (as BedWars kits do)
-- but keeps its collision and stays the thing shots hit.
--
-- Who gets a look: the player attribute `Kit` once KitService exists, and for testing,
-- Tuning `Debug_KitLook` (a kit id such as BlackKnight) dresses everyone who spawns.
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AssetRegistry = require(ReplicatedStorage.Shared.AssetRegistry)
local Palette = require(ReplicatedStorage.Shared.Palette)

local KitLookService = Knit.CreateService({ Name = "KitLookService", Client = {} })

local FOLDER = "KitLook"
local APPEARANCE_WAIT = 0.6 -- avatar clothes and accessories arrive after CharacterAdded
local templates = {} -- [kitId] = { pieces = { [meshName] = MeshPart }, look = entry.kitLook } | false

-- BlackKnight -> black-knight-look, the key kit_look.py export writes.
local function registryKey(kitId: string): string
    return (kitId:gsub("(%l)(%u)", "%1-%2"):lower()) .. "-look"
end

local function lookFor(kitId: string)
    if templates[kitId] ~= nil then
        return templates[kitId] or nil
    end
    templates[kitId] = false
    local entry = AssetRegistry[registryKey(kitId)]
    if not (entry and entry.kitLook) then
        warn("[KitLookService] no look in the asset registry for", kitId)
        return nil
    end
    if not entry.assetId then
        warn("[KitLookService] the look for", kitId, "is exported but not uploaded yet")
        return nil
    end
    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(entry.assetId)
    end)
    if not ok or not loaded then
        warn("[KitLookService] could not load the look for", kitId, loaded)
        return nil
    end
    local pieces = {}
    for _, part in loaded:GetDescendants() do
        if part:IsA("MeshPart") then
            pieces[part.Name] = part
        end
    end
    local template = { pieces = pieces, look = entry.kitLook }
    templates[kitId] = template
    return template
end

-- What a kit look replaces: the avatar's clothes and accessories, and the Titan Alter Ego's
-- orange shoulder plates (AlterEgoService names them EgoMark), as character skins do.
local function isClothing(child: Instance): boolean
    return child:IsA("Accessory")
        or child:IsA("Shirt")
        or child:IsA("Pants")
        or child:IsA("ShirtGraphic")
        or child.Name == "EgoMark"
end

-- Returns true when the look was applied.
function KitLookService:Apply(character: Model, kitId: string): boolean
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return false
    end
    local template = lookFor(kitId)
    if not template then
        return false
    end
    local torso = character:FindFirstChild("UpperTorso")
    if not (torso and torso:IsA("BasePart")) then
        return false
    end

    -- One look at a time: replace an earlier one, and a character skin's armour.
    for _, name in { FOLDER, "CharacterSkinArmor" } do
        local old = character:FindFirstChild(name)
        if old then
            old:Destroy()
        end
    end
    for _, child in character:GetChildren() do
        if isClothing(child) then
            child:Destroy()
        end
    end
    local blocker = character.ChildAdded:Connect(function(child)
        if isClothing(child) then
            child:Destroy()
        end
    end)
    humanoid.Died:Once(function()
        blocker:Disconnect()
    end)

    -- Pieces were fitted to a blocky R15 body; follow this avatar's size.
    local scale = torso.Size.Y / (template.look.templateTorsoHeight or torso.Size.Y)
    local folder = Instance.new("Folder")
    folder.Name = FOLDER
    folder:SetAttribute("Kit", kitId)
    folder.Parent = character
    local missing = {}
    local dressed = {} -- [body part name] = true once a piece is on it
    for _, piece in template.look.pieces do
        local body = character:FindFirstChild(piece.part)
        local source = template.pieces[piece.mesh]
        if body and body:IsA("BasePart") and source then
            dressed[piece.part] = true
            local part = source:Clone()
            part.Anchored = false
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            part.CastShadow = true
            part.Size *= scale
            local offset = CFrame.new(Vector3.new(table.unpack(piece.offset)) * scale) * source.CFrame.Rotation
            part.CFrame = body.CFrame * offset
            local weld = Instance.new("Weld")
            weld.Part0 = body
            weld.Part1 = part
            weld.C0 = offset
            weld.Parent = part
            part.Parent = folder
        else
            table.insert(missing, piece.mesh)
        end
    end
    if #missing > 0 then
        -- The uploaded model's MeshPart names must match the registry's `mesh` names; list both.
        local found = {}
        for name in template.pieces do
            table.insert(found, name)
        end
        warn(
            ("[KitLookService] %s: %d pieces not attached (%s). The model holds: %s"):format(
                kitId,
                #missing,
                table.concat(missing, ", "),
                table.concat(found, ", ")
            )
        )
    end

    -- Hide a body part only when its armour is really on it: a missing piece shows the body,
    -- not a hole (the first upload hid every part and attached nothing).
    local hidden = {}
    for _, name in template.look.hides do
        local body = character:FindFirstChild(name)
        if body and body:IsA("BasePart") and dressed[name] then
            hidden[name] = true
            body.Transparency = 1
            for _, decal in body:GetChildren() do
                if decal:IsA("Decal") then
                    decal.Transparency = 1 -- the face
                end
            end
        end
    end
    -- A sleeve is a slimmer stand-in for a hidden part its piece does not wrap: the upper arm
    -- inside an open shoulder plate, which otherwise leaves a hole between chest and arm.
    -- Cosmetic like the pieces; the hidden part underneath is still the hitbox.
    local under = template.look.bodyColor and Color3.fromHex(template.look.bodyColor)
    for _, sleeve in template.look.sleeves or {} do
        local body = character:FindFirstChild(sleeve.part)
        if body and body:IsA("BasePart") and hidden[sleeve.part] then
            local part = Instance.new("Part")
            part.Name = sleeve.part .. "Sleeve"
            part.Size = Vector3.new(table.unpack(sleeve.size)) * scale
            part.Color = under or body.Color
            part.Material = Enum.Material.SmoothPlastic
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            local offset = CFrame.new(Vector3.new(table.unpack(sleeve.offset)) * scale)
            part.CFrame = body.CFrame * offset
            local weld = Instance.new("Weld")
            weld.Part0 = body
            weld.Part1 = part
            weld.C0 = offset
            weld.Parent = part
            part.Parent = folder
        end
    end

    -- Glows: Neon plates over painted lights (the knight's eyes). A MeshPart texture cannot glow,
    -- and Neon is how Roblox kits make one. Only on a part that is dressed, so a missing helmet
    -- does not leave two floating eyes. `turn` (degrees about Y) lets a slat follow a curved
    -- visor. `color = "team"` is a team band: the player's team colour, kept in step with their
    -- Team attribute, plain paint unless `neon` says otherwise.
    local player = Players:GetPlayerFromCharacter(character)
    local teamParts = {}
    for _, glow in template.look.glows or {} do
        local body = character:FindFirstChild(glow.part)
        if body and body:IsA("BasePart") and dressed[glow.part] then
            local part = Instance.new("Part")
            part.Name = glow.part .. (glow.color == "team" and "Team" or "Glow")
            part.Size = Vector3.new(table.unpack(glow.size)) * scale
            if glow.color == "team" then
                part.Color = Palette.world(player and player:GetAttribute("Team"))
                table.insert(teamParts, part)
            else
                part.Color = Color3.fromHex(glow.color)
            end
            part.Material = if glow.neon == false then Enum.Material.SmoothPlastic else Enum.Material.Neon
            part.CastShadow = false
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            part.Massless = true
            local offset = CFrame.new(Vector3.new(table.unpack(glow.offset)) * scale)
                * CFrame.Angles(0, math.rad(glow.turn or 0), 0)
            part.CFrame = body.CFrame * offset
            local weld = Instance.new("Weld")
            weld.Part0 = body
            weld.Part1 = part
            weld.C0 = offset
            weld.Parent = part
            part.Parent = folder
        end
    end

    if player and #teamParts > 0 then
        local changed
        changed = player:GetAttributeChangedSignal("Team"):Connect(function()
            for _, part in teamParts do
                part.Color = Palette.world(player:GetAttribute("Team"))
            end
        end)
        folder.Destroying:Connect(function()
            changed:Disconnect()
        end)
    end

    -- Body that still shows (a part whose piece failed to attach) is the look's dark
    -- under-layer, not the avatar's skin. BodyColors would repaint it, so it goes.
    if under then
        local bodyColors = character:FindFirstChildOfClass("BodyColors")
        if bodyColors then
            bodyColors:Destroy()
        end
        for _, body in character:GetChildren() do
            if body:IsA("BasePart") and body.Name ~= "HumanoidRootPart" and not hidden[body.Name] then
                body.Color = under
                body.Material = Enum.Material.SmoothPlastic
            end
        end
    end
    return true
end

local function kitFor(player: Player): string?
    local tuning = ReplicatedStorage:FindFirstChild("Tuning")
    local debugKit = tuning and tuning:GetAttribute("Debug_KitLook")
    if type(debugKit) == "string" and debugKit ~= "" then
        return debugKit
    end
    local kit = player:GetAttribute("Kit")
    return type(kit) == "string" and kit ~= "" and kit or nil
end

function KitLookService:KnitStart()
    local function watch(player: Player)
        player.CharacterAdded:Connect(function(character)
            task.defer(function()
                if not character:WaitForChild("Humanoid", 10) then
                    return
                end
                -- After the avatar's own clothes, and after a character skin, so the look wins.
                task.wait(APPEARANCE_WAIT)
                local kit = kitFor(player)
                if kit and character.Parent then
                    self:Apply(character, kit)
                end
            end)
        end)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
end

return KitLookService
