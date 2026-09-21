-- Dresses a placeholder part with an uploaded mesh, using the same "upload:<Name>"
-- indirection as skins, sounds and animations (see Uploads.lua). Until the mesh is
-- uploaded and named in ReplicatedStorage.Uploads the part keeps its greybox look,
-- so a missing upload degrades instead of erroring.
--
-- Meshes are exported at their intended stud size by tools/blender/process_assets.py,
-- so Scale stays at 1 and the authored proportions are what ships. A SpecialMesh
-- replaces the part's own rendering, but the part's Transparency still applies to it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Uploads = require(ReplicatedStorage.Shared.Uploads)

local MeshDressing = {}

-- Returns true when the mesh was applied, false when the upload is not ready yet.
function MeshDressing.apply(part, meshRef, textureRef, scale)
    local meshId = Uploads.resolve(meshRef)
    if not meshId then
        return false
    end
    local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
    if not mesh then
        mesh = Instance.new("SpecialMesh")
    end
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = meshId
    mesh.Scale = scale or Vector3.one
    local textureId = Uploads.resolve(textureRef)
    if textureId then
        mesh.TextureId = textureId
    end
    mesh.Parent = part
    return true
end

-- Hides greybox detail that a dressed mesh supersedes, without unparenting it:
-- attachments and emitters welded to those parts must keep working.
function MeshDressing.hide(parts)
    for _, part in parts do
        part.Transparency = 1
    end
end

return MeshDressing
