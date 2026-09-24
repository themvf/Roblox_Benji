-- Turn a baked map into the box list Validate understands, plus a flat part list for
-- gates that assert on named pieces.
--
-- A baked map has no piece descriptions, only parts. That is the point: the parts are
-- what the server actually creates, including collision the layout never described --
-- the facade kit alone authors 282 of them, and no gate has ever seen those.
--
-- Collidable is the whole test for a solid. An invisible wall still stops a launched
-- player, and this map is full of them: greybox blocks hidden behind facade meshes.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local M = {}

M.DIR = "assets/environment/baked"

function M.path(mapName)
    for _, ext in { ".rbxm", ".rbxmx" } do
        local candidate = M.DIR .. "/" .. mapName .. ext
        if fs.isFile(candidate) then
            return candidate
        end
    end
    return nil
end

-- Returns solids (Validate box list) and parts ({name, pos, size, collide}), or nil.
function M.load(mapName, Validate)
    local path = M.path(mapName)
    if not path then
        return nil, nil
    end
    local solids, parts = {}, {}
    for _, root in roblox.deserializeModel(fs.readFile(path)) do
        local function walk(inst)
            if inst:IsA("BasePart") then
                local okCf, cf = pcall(function()
                    return inst.CFrame
                end)
                local okSize, size = pcall(function()
                    return inst.Size
                end)
                local okCollide, collide = pcall(function()
                    return inst.CanCollide
                end)
                if okCf and okSize then
                    local x, y, z, a, b, c, d, e, f, g, h, k = cf:GetComponents()
                    local pos = { x, y, z }
                    local dim = { size.X, size.Y, size.Z }
                    -- Axis-aligned within a hair. Gates that test a point against a
                    -- box with an abs() per axis are only correct for unrotated parts,
                    -- which is why the layout versions skipped anything with a `rot`.
                    local square = math.abs(math.abs(a) - 1) < 1e-4
                        and math.abs(math.abs(e) - 1) < 1e-4
                        and math.abs(math.abs(k) - 1) < 1e-4
                    table.insert(parts, {
                        name = inst.Name,
                        pos = pos,
                        size = dim,
                        collide = okCollide and collide or false,
                        axisAligned = square,
                    })
                    if okCollide and collide then
                        table.insert(
                            solids,
                            Validate.boxFrom(inst.Name, pos, dim, { { a, b, c }, { d, e, f }, { g, h, k } })
                        )
                    end
                end
            end
            for _, child in inst:GetChildren() do
                walk(child)
            end
        end
        walk(root)
    end
    return solids, parts
end

return M
