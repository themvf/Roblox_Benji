-- Editable lobby source commands: new, convert, status.
-- In Studio the Workspace copy is read live on Play. Conversion stores a
-- validated copy for Rojo builds and for sessions without an editing copy.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum

local Template = require("./lobbyauthor/template")
local Reader = require("../src/shared/LobbyAuthoring")
local base = require("../src/shared/Maps/Lobby")
local source = "assets/environment/source/Lobby.rbxm"
local baked = "assets/environment/baked/Lobby.rbxm"

local function stop(message)
    print("Lobby NOT updated: " .. message)
    process.exit(1)
end

local function parse(bytes)
    local ok, roots = pcall(roblox.deserializeModel, bytes)
    if not ok or #roots ~= 1 then
        return nil, { "Expected one editable Lobby model." }
    end
    local root = roots[1]
    local layout, errors = Reader.read(root, base)
    return layout and root or nil, errors
end

local command = process.args[1] or "status"
if command == "new" then
    if fs.isFile(source) then
        stop(source .. " already exists; open it in Studio instead of recreating it")
    end
    fs.writeFile(source, roblox.serializeModel({ Template.create(base) }))
    print("Created " .. source .. " from the current lobby layout.")
    command = "convert"
end

if command == "convert" then
    if not fs.isFile(source) then
        stop("No saved source. Run: .\\tools\\save_lobby.cmd new")
    end
    local bytes = fs.readFile(source)
    local root, errors = parse(bytes)
    if not root then
        for _, message in errors do
            print("  - " .. message)
        end
        stop("Fix the saved editable model in Studio; the previous playable copy remains")
    end
    -- The runtime reader clones only Geometry. Authoring markers stay in the
    -- stored model as data and never enter the playable Workspace lobby.
    fs.writeFile(baked, roblox.serializeModel({ root }))
    print("Lobby UPDATED: " .. baked)
    print("Restart Play to see the saved design, or keep the editable model in Workspace for live testing.")
elseif command == "status" then
    if not fs.isFile(source) then
        print("No editable lobby source yet. Run: .\\tools\\save_lobby.cmd new")
    elseif not fs.isFile(baked) then
        print("Lobby source saved; no playable copy. Run: .\\tools\\save_lobby.cmd")
    else
        local sourceRoot = parse(fs.readFile(source))
        local bakedRoot = parse(fs.readFile(baked))
        if not sourceRoot or not bakedRoot then
            stop("Source or playable copy is invalid; run convert for details")
        end
        -- Studio's Save to File and Lune's serializer can encode the same
        -- instances differently. Compare their canonical model content.
        local same = roblox.serializeModel({ sourceRoot }) == roblox.serializeModel({ bakedRoot })
        print(same and "Lobby source and playable copy match." or "Lobby is STALE: save/convert the latest edit.")
    end
else
    stop("Unknown command. Use new, convert, or status.")
end
