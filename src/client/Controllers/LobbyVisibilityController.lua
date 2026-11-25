-- Hides the lobby on this client while the player is out on a map.
--
-- The lobby is built in the sky at Lobby.Origin, about a thousand studs from the arena.
-- That is inside the maps' fog range, so from the map it showed as a dark slab hanging
-- over the horizon. Matches never need it, so this client takes it out of its own
-- Workspace while the character is far away and puts it back before they return.
--
-- Keyed on distance, not on the InMatch attribute: InMatch turns on during the
-- intermission, while the player is still standing on the lobby floor, and the
-- character is client-owned -- hiding the floor under it would drop it through.
-- The server's copy is untouched, so collisions and other players are unaffected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local LobbyLayout = require(ReplicatedStorage.Shared.Maps.Lobby)

local LobbyVisibilityController = Knit.CreateController({ Name = "LobbyVisibilityController" })

-- Hide beyond this many studs from the lobby origin; the lobby itself is ~150 x 130.
local HIDE_DISTANCE = 400

local origin = Vector3.new(table.unpack(LobbyLayout.Origin))
local hidden = nil -- the lobby folder while this client has it out of Workspace

-- nil between characters: the state is left as it is until the next one appears
local function focusPosition()
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

local function show()
    if hidden then
        -- cleared first: reparenting fires ChildAdded, which must not see it as hidden
        local lobby = hidden
        hidden = nil
        -- the server may have rebuilt the lobby meanwhile; then the stale copy just goes
        if workspace:FindFirstChild("Lobby") then
            lobby:Destroy()
        else
            lobby.Parent = workspace
        end
    end
end

local function hide()
    local lobby = workspace:FindFirstChild("Lobby")
    if lobby and lobby:IsA("Folder") then
        hidden = lobby
        lobby.Parent = nil
    end
end

function LobbyVisibilityController:KnitStart()
    -- PreSimulation runs before physics each frame, so a character that respawns on the
    -- lobby floor gets it back before it can fall.
    RunService.PreSimulation:Connect(function()
        local at = focusPosition()
        if not at then
            return
        end
        local far = (at - origin).Magnitude > HIDE_DISTANCE
        if far and not hidden then
            hide()
        elseif not far then
            show()
        end
    end)
    -- A lobby rebuilt by the server while this client is on a map is hidden as well.
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Lobby" and hidden and child:IsA("Folder") then
            hidden:Destroy()
            hidden = nil
            hide()
        end
    end)
end

return LobbyVisibilityController
