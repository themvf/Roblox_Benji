-- Studio-side asset hookup. Anything the game references as "upload:<Name>" is resolved from
-- ReplicatedStorage.Uploads.<Name>, an instance you create in Studio and never touch in code:
--   Decal / Texture   -> its Texture id      (skin patterns, camo)
--   Sound             -> its SoundId         (fire sounds, stings)
--   Animation         -> its AnimationId     (reloads, celebrations)
--   StringValue       -> its Value           (any raw rbxassetid)
-- Rojo leaves the Uploads folder alone because it is not part of the project tree, so edits
-- made in Studio survive syncs and publishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Uploads = {}

Uploads.FOLDER_NAME = "Uploads"

function Uploads.folder()
    return ReplicatedStorage:FindFirstChild(Uploads.FOLDER_NAME)
end

local function idFrom(inst)
    if inst:IsA("Decal") or inst:IsA("Texture") then
        return inst.Texture
    elseif inst:IsA("Sound") then
        return inst.SoundId
    elseif inst:IsA("Animation") then
        return inst.AnimationId
    elseif inst:IsA("StringValue") then
        return inst.Value
    elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
        return inst.Image
    end
    return nil
end

-- Returns the asset id string for a reference, or nil if it is not ready.
-- Accepts "upload:Name", a direct "rbxassetid://..." string, or nil/"TODO".
function Uploads.resolve(ref)
    if type(ref) ~= "string" or ref == "" or ref == "TODO" then
        return nil
    end
    local name = ref:match("^upload:(.+)$")
    if not name then
        return ref
    end
    local folder = Uploads.folder()
    local inst = folder and folder:FindFirstChild(name)
    if not inst then
        return nil
    end
    local id = idFrom(inst)
    if type(id) == "string" and id ~= "" then
        return id
    end
    return nil
end

function Uploads.isReady(ref)
    return Uploads.resolve(ref) ~= nil
end

return Uploads
