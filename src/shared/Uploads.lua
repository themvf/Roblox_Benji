-- Studio-side asset hookup. Anything the game references as "upload:<Name>" is resolved from
-- ReplicatedStorage.Uploads.<Name>, an instance you create in Studio and never touch in code:
--   Decal / Texture   -> its Texture id      (skin patterns, camo)
--   Sound             -> its SoundId         (fire sounds, stings)
--   Animation         -> its AnimationId     (reloads, celebrations)
--   StringValue       -> its Value           (any raw rbxassetid)
-- Rojo leaves the Uploads folder alone because it is not part of the project tree, so edits
-- made in Studio survive syncs and publishes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")

local Uploads = {}

-- Open Cloud only mints Model assets, and a Model id cannot be assigned to
-- SpecialMesh.MeshId, so a dressed prop needs the Model as an *instance* to read the
-- mesh off. Placing one by hand in ReplicatedStorage.Uploads is a Studio step that
-- Rojo cannot do for you, which leaves the game greybox until somebody remembers.
-- These ids let the server load the same Models itself, so a fresh clone of the repo
-- renders correctly with no manual step. An instance in Uploads still wins, so the
-- art can be swapped in Studio without a code change.
Uploads.FALLBACK_ASSETS = {
    JetpackMesh = 73494627185081,
    JumpPadMesh = 101685278186013,
}

-- LoadAsset yields and can fail: the place must be owned by the account that owns
-- the asset, and there may be no network. Cache the outcome either way so a failure
-- is not retried on every dressing call.
local loaded = {}

local function loadFallback(name)
    local assetId = Uploads.FALLBACK_ASSETS[name]
    if not assetId or not RunService:IsServer() then
        return nil
    end
    local cached = loaded[assetId]
    if cached == nil then
        local ok, model = pcall(function()
            return InsertService:LoadAsset(assetId)
        end)
        cached = (ok and model) or false
        loaded[assetId] = cached
        if not cached then
            warn(("Uploads: asset %d for %q could not be loaded; %s stays greybox"):format(assetId, name, name))
        end
    end
    return cached or nil
end

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

-- Some uploads are whole models rather than a single id: a Blender scene imported
-- through Studio's 3D Importer lands as a Model of MeshParts. Callers clone it.
function Uploads.model(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local folder = Uploads.folder()
    local inst = folder and folder:FindFirstChild(name)
    if inst and (inst:IsA("Model") or inst:IsA("BasePart")) then
        return inst
    end
    return loadFallback(name)
end

function Uploads.isReady(ref)
    return Uploads.resolve(ref) ~= nil
end

return Uploads
