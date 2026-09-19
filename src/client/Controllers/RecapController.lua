-- End-of-match recap card: transparent MVP breakdown, your score, XP, streak status and checkpoints,
-- bounty survived / claims. Shown for ~6 s before celebrations take the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Screen = require(script.Parent.Parent.UI.Screen)
local Theme = require(script.Parent.Parent.UI.Theme)

local RecapController = Knit.CreateController({ Name = "RecapController" })

local PANEL = Theme.Color.Panel
local TEXT = Theme.Color.Text
local MUTED = Theme.Color.TextMuted
local ACCENT = Theme.Color.Accent
local GREEN = Theme.Color.Good

local function label(parent, text, size, color, font, order)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, size + 8)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = Theme.textSize(size)
    l.Font = font or Enum.Font.GothamMedium
    l.TextColor3 = color or TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.LayoutOrder = order or 0
    l.Parent = parent
    return l
end

function RecapController:BuildGui()
    local gui = Screen.newScreenGui("RecapGui", Screen.Layers.Recap)
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    self.Gui = gui
    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.45)
    panel.Size = UDim2.fromOffset(520, 380)
    panel.BackgroundColor3 = PANEL
    panel.BackgroundTransparency = 0.1
    panel.Parent = gui
    -- 520x380 is a desktop card; scaled and capped it stays on screen on a phone in landscape.
    Screen.autoScale(panel)
    Screen.fitWithin(panel, 0.94, 0.9)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = panel
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 20)
    pad.PaddingRight = UDim.new(0, 20)
    pad.Parent = panel
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 2)
    list.Parent = panel
    self.Panel = panel
end

function RecapController:Show(r)
    for _, c in self.Panel:GetChildren() do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
    local o = 0
    local function line(text, size, color, font)
        o += 1
        return label(self.Panel, text, size or 16, color, font, o)
    end
    line(r.Won and "VICTORY" or "DEFEAT", 30, r.Won and GREEN or MUTED, Enum.Font.GothamBlack)
    if not r.Valid then
        line("Practice match: no stats, streak or XP recorded", 14, MUTED)
    end
    if r.MVP then
        line(("MVP: %s  (%d)"):format(r.MVP, r.MVPScore or 0), 20, ACCENT, Enum.Font.GothamBlack)
    end
    local b = r.Breakdown
    line(
        ("Your score %d   =  Objective %d + Defense %d + Teamplay %d + Combat %d + Discipline %d"):format(
            r.Score,
            b.Objective,
            b.Defense,
            b.Teamplay,
            b.Combat,
            b.Discipline
        ),
        15,
        TEXT
    )
    line(
        ("%d captures · %d stops · %d kills · %d assists · %d deaths"):format(
            r.Captures,
            r.Stops,
            r.Kills,
            r.Assists,
            r.Deaths
        ),
        15,
        MUTED
    )
    if r.Valid then
        line(("+%d XP%s"):format(r.XP, r.IsMVP and "  (includes MVP bonus)" or ""), 18, GREEN, Enum.Font.GothamBold)
        if r.BountySurvived then
            line("MOST WANTED SURVIVES: you finished the match while marked", 16, ACCENT, Enum.Font.GothamBold)
        end
        if r.BountyClaims > 0 then
            line(("Bounties claimed this match: %d"):format(r.BountyClaims), 16, ACCENT)
        end
        if (r.Mutations or 0) > 0 then
            line(
                ("Mutations: %d · mutant kills %d · objective score while mutated %d"):format(
                    r.Mutations,
                    r.MutantKills or 0,
                    r.ObjectiveWhileMutated or 0
                ),
                16,
                Theme.Color.Energy
            )
        end
        if r.Won then
            local status = r.StatusAfter and ("  ·  " .. r.StatusAfter) or ""
            line(("Win streak: %d%s"):format(r.StreakAfter, status), 18, ACCENT, Enum.Font.GothamBold)
            if r.Checkpoint then
                line(("Checkpoint saved: %d-win badge is yours to keep"):format(r.Checkpoint), 16, GREEN)
            end
        elseif r.StreakBefore >= 2 then
            line(
                ("Streak ended at %d. Legacy saved: best streak and checkpoints stay on your profile."):format(
                    r.StreakBefore
                ),
                16,
                MUTED
            )
        end
    end
    self.Gui.Enabled = true
    self.Token = (self.Token or 0) + 1
    local mine = self.Token
    task.delay(7, function()
        if self.Token == mine then
            self.Gui.Enabled = false
        end
    end)
end

function RecapController:KnitStart()
    self:BuildGui()
    Knit.GetService("StatsService").Recap:Connect(function(recap)
        self:Show(recap)
    end)
end

return RecapController
