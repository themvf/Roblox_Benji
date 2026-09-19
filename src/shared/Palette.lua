-- Team colours, shared by the server (3D world objects) and the client (HUD).
--
-- These had drifted into three different reds: the Convergence bar used 255,70,70, the scoreboard
-- used 255,90,90 and MapService used 200,60,60, so the top bar and the scoreboard disagreed about
-- what "red" meant. Team colour is the most load-bearing semantic in a team shooter, so there is
-- now exactly one source for it.
--
-- `Ui` is the on-screen colour: bright enough to hold contrast against a dark HUD panel.
-- `World` is the same hue darkened for parts, which read lighter once lit and surfaced. The two
-- are deliberately different values of the same colour, not a drift -- keep them in step.
local Palette = {}

Palette.Ui = {
    Red = Color3.fromRGB(255, 70, 70),
    Blue = Color3.fromRGB(70, 140, 255),
    Neutral = Color3.fromRGB(200, 200, 205),
    Closed = Color3.fromRGB(80, 80, 85),
}

Palette.World = {
    Red = Color3.fromRGB(200, 60, 60),
    Blue = Color3.fromRGB(60, 110, 200),
    Neutral = Color3.fromRGB(160, 160, 165),
}

-- Team colour for a side name, with a safe fallback for spectators and unassigned players.
function Palette.ui(team)
    return Palette.Ui[team] or Palette.Ui.Neutral
end

function Palette.world(team)
    return Palette.World[team] or Palette.World.Neutral
end

-- Text drawn over the 3D world (billboard labels, zone names, nameplates) has no guaranteed
-- backdrop: white text on a bright sky disappears, which is what the zone names did. The legacy
-- TextStrokeTransparency is a single soft pixel and is not enough under TextScaled, so use a
-- UIStroke. Shared so the server's billboards and the client's look identical.
function Palette.worldText(label, thickness)
    local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    stroke.Thickness = thickness or 2
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Transparency = 0.15
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = label
    return label
end

return Palette
