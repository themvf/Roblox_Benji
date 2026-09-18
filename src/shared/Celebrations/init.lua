-- Celebration registry. Every module under Registry/ is one celebration; see Validate.lua.
local Celebrations = {}

Celebrations.Validate = require(script.Validate)
Celebrations.DEFAULT_ID = "cel_common_wave"
Celebrations.MAX_FAVORITES = 3

local all = {}
local byId = {}

local registry = script:FindFirstChild("Registry")
if registry then
    for _, mod in registry:GetChildren() do
        if mod:IsA("ModuleScript") then
            local cel = require(mod)
            table.insert(all, cel)
            byId[cel.Id] = cel
        end
    end
end
table.sort(all, function(a, b)
    return a.Id < b.Id
end)

function Celebrations.all()
    return all
end

function Celebrations.get(id)
    return byId[id]
end

return Celebrations
