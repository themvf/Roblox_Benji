-- Rigid R15 armor layers for the two generated-character references. The
-- original meshes are unrigged; these pieces follow the existing R15 joints.
local Definitions = require(script.Parent.Definitions)

local Visuals = {}

local function color(hex: string): Color3
    return Color3.fromRGB(
        tonumber(hex:sub(2, 3), 16) or 0,
        tonumber(hex:sub(4, 5), 16) or 0,
        tonumber(hex:sub(6, 7), 16) or 0
    )
end

local function vector(values): Vector3
    return Vector3.new(values[1], values[2], values[3])
end

local function makePiece(parent: Instance, body: BasePart, piece): BasePart
    local part = Instance.new("Part")
    part.Name = piece.name
    part.Size = vector(piece.size)
    part.Color = color(piece.color)
    part.Material = Enum.Material[piece.material] or Enum.Material.Metal
    part.Shape = piece.shape == "ball" and Enum.PartType.Ball
        or (piece.shape == "cylinder" and Enum.PartType.Cylinder or Enum.PartType.Block)
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
    part.CastShadow = true
    local offset = vector(piece.offset)
    local rotation = piece.rotation
    local axis = piece.shape == "cylinder" and CFrame.Angles(0, 0, math.pi / 2) or CFrame.identity
    part.CFrame = body.CFrame
        * CFrame.new(offset)
        * CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
        * axis
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = body
    weld.Part1 = part
    weld.Parent = part
    part.Parent = parent
    return part
end

function Visuals.apply(character: Model, id: string): boolean
    local definition = Definitions[id]
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not definition or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return false
    end

    local old = character:FindFirstChild("CharacterSkinArmor")
    if old then
        old:Destroy()
    end
    for _, child in character:GetChildren() do
        if
            child:IsA("Accessory")
            or child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic")
            or child.Name == "EgoMark"
        then
            child:Destroy()
        end
    end
    local blocker = character.ChildAdded:Connect(function(child)
        if
            child:IsA("Accessory")
            or child:IsA("Shirt")
            or child:IsA("Pants")
            or child:IsA("ShirtGraphic")
            or child.Name == "EgoMark"
        then
            child:Destroy()
        end
    end)
    humanoid.Died:Once(function()
        blocker:Disconnect()
    end)

    local baseColor = color(definition.bodyColor)
    for _, child in character:GetChildren() do
        if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
            child.Color = baseColor
            child.Material = Enum.Material.SmoothPlastic
            if child:IsA("MeshPart") then
                child.TextureID = ""
            end
            for _, surface in child:GetChildren() do
                if surface:IsA("SurfaceAppearance") or surface:IsA("Decal") then
                    surface:Destroy()
                end
            end
        end
    end

    local armor = Instance.new("Folder")
    armor.Name = "CharacterSkinArmor"
    armor:SetAttribute("SkinId", id)
    armor.Parent = character
    for _, piece in definition.pieces do
        local body = character:FindFirstChild(piece.attach)
        if body and body:IsA("BasePart") then
            makePiece(armor, body, piece)
        end
    end
    return true
end

return Visuals
