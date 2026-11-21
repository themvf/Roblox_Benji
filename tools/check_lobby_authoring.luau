-- Check the saved lobby source, playable copy, and the shared marker reader.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
Color3 = roblox.Color3
Vector3 = roblox.Vector3
Enum = roblox.Enum

local Reader = require("../src/shared/LobbyAuthoring")
local base = require("../src/shared/Maps/Lobby")
local source = fs.readFile("assets/environment/source/Lobby.rbxm")
local baked = fs.readFile("assets/environment/baked/Lobby.rbxm")
assert(
    roblox.serializeModel(roblox.deserializeModel(source)) == roblox.serializeModel(roblox.deserializeModel(baked)),
    "saved lobby is stale; run tools/save_lobby.cmd"
)

local roots = roblox.deserializeModel(source)
assert(#roots == 1, "lobby source must contain one model")
local root = roots[1]
local layout, errors = Reader.read(root, base)
assert(layout, table.concat(errors, "; "))
assert(#layout.Pads == #base.Pads and #layout.Spawns == #base.Spawns)
assert(#layout.SourceGeometry:GetChildren() > 0)
assert(not layout.SourceGeometry:FindFirstChild("Authoring"), "markers entered playable geometry")
local mist = assert(layout.ArrivalMist, "central arrival mist is missing")
assert(mist.Columns * mist.Rows == 15 and mist.RatePerEmitter <= 5, "arrival mist budget changed")
for index, point in layout.Spawns do
    assert(
        math.abs(point[1] - mist.Center[1]) <= (mist.Columns - 1) * mist.Spacing[1] / 2
            and math.abs(point[3] - mist.Center[3]) <= (mist.Rows - 1) * mist.Spacing[2] / 2,
        "lobby spawn " .. index .. " is outside the mist field"
    )
end

local pad = root.Authoring.QueuePads.PadTDM
local originalPadCFrame = pad.CFrame
local before = layout.Pads[4].pos[1]
pad.CFrame *= roblox.CFrame.new(2, 0, 0)
local moved, moveErrors = Reader.read(root, base)
assert(moved, table.concat(moveErrors, "; "))
assert(math.abs(moved.Pads[4].pos[1] - before - 2) < 0.001, "Studio pad move did not reach runtime layout")
assert(moved.Pads[4].kind == "TDM" and moved.Pads[4].teamSize == 5, "pad move changed mode rules")

local sign = root.Authoring.Wayfinding.Play
sign:SetAttribute("Title", "PLAY TEST")
local changedSign = Reader.read(root, base)
assert(changedSign.Wayfinding[1].title == "PLAY TEST", "sign text edit did not reach runtime layout")

pad.CFrame = root.Authoring.QueuePads.PadConvergence.CFrame
local overlap, overlapErrors = Reader.read(root, base)
assert(not overlap and table.concat(overlapErrors, " "):find("overlaps"), "overlapping queue pads were accepted")
pad.CFrame = originalPadCFrame

pad.CFrame *= roblox.CFrame.new(200, 0, 0)
local bad, badErrors = Reader.read(root, base)
assert(not bad and table.concat(badErrors, " "):find("outside the Floor"), "off-floor pad was accepted")
pad.CFrame *= roblox.CFrame.new(-200, 0, 0) * roblox.CFrame.Angles(0, math.rad(20), 0)
local rotated, rotationErrors = Reader.read(root, base)
assert(not rotated and table.concat(rotationErrors, " "):find("rotation is not supported"), "rotated pad was accepted")

pad.CFrame = originalPadCFrame

-- Stations may turn to face their island; the turn must reach the runtime layout.
assert(math.abs(layout.Kiosk.yaw - (base.Kiosk.yaw or 0)) < 0.05, "kiosk yaw did not reach runtime layout")
assert(math.abs(layout.Board.yaw - (base.Board.yaw or 0)) < 0.05, "leaderboard yaw did not reach runtime layout")
local board = root.Authoring.Stations.Board
board.CFrame = roblox.CFrame.new(board.CFrame.Position) * roblox.CFrame.Angles(0, math.rad(30), 0)
local turned = assert(Reader.read(root, base), "a turned leaderboard was rejected")
assert(math.abs(turned.Board.yaw - 30) < 0.05, "leaderboard turn did not reach runtime layout")

-- The islands float: a lobby that has no fall box would leave a player falling forever.
local fall = assert(layout.FallRecovery, "lobby needs a FallRecovery box under the islands")
assert(fall.max[2] < 0, "FallRecovery must sit below the island tops")
for index, point in layout.Spawns do
    assert(point[2] > fall.max[2], "lobby spawn " .. index .. " is inside the fall box")
end

print("Editable lobby source, live marker moves, and playable copy passed")
