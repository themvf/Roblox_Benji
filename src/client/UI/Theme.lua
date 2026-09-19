-- Theme: the one palette, type ramp and surface treatment for every HUD in the game.
--
-- Why this exists: the colour tokens were copy-pasted into eight controllers, which is how the
-- team red drifted into three values and how "dark panel" became two. A restyle, or a
-- colour-blind pass, should be a one-file change.
--
-- It also enforces the two legibility rules the old HUD broke:
--
--   1. Contrast against the sky. Panels sat at BackgroundTransparency 0.25-0.4. Muted grey on the
--      dark panel is a healthy 7.4:1, but composited over a bright sky it falls to 4.2:1 at 0.25
--      and 2.8:1 at 0.4 -- below the 4.5:1 AA threshold, i.e. a HUD that reads in a hangar and
--      washes out on the horizon. Theme.Transparency.Panel (0.12) holds it at 5.8:1.
--   2. Text drawn over the 3D world, rather than on a panel, has no guaranteed backdrop at all
--      and must carry a stroke. Theme.overWorld does that.
--
-- Sizes here are design pixels. Screen's UIScale shrinks them per device, so the floor that keeps
-- a label legible after scaling is Theme.minTextSize, not the raw number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.Palette)
local Screen = require(script.Parent.Screen)

local Theme = {}

-- Team colours come from the shared palette so the HUD, the world and the server agree.
Theme.Team = Palette.Ui
Theme.team = Palette.ui

Theme.Color = {
    -- Surfaces. Panel is the HUD readout; PanelRaised is a surface sitting *on* a panel, which is
    -- why the modals (loadout, celebration) are a step lighter rather than a second dark grey.
    Panel = Color3.fromRGB(20, 22, 28),
    PanelRaised = Color3.fromRGB(28, 30, 38),
    PanelHigh = Color3.fromRGB(44, 47, 58),
    PanelSelected = Color3.fromRGB(62, 66, 82), -- a toggled-on control
    Track = Color3.fromRGB(45, 48, 58), -- empty half of a progress bar

    -- Text. Text on Panel is 16.6:1, TextMuted on Panel is 7.4:1; both clear WCAG AA.
    Text = Color3.fromRGB(245, 245, 250),
    TextMuted = Color3.fromRGB(160, 165, 180),

    -- Status. Accent is the game's gold; the rest are semantic, not decorative.
    Accent = Color3.fromRGB(255, 200, 70),
    Energy = Color3.fromRGB(255, 120, 40), -- mutation / alter ego
    Fly = Color3.fromRGB(90, 200, 255), -- jetpack
    Good = Color3.fromRGB(90, 230, 130),
    Warn = Color3.fromRGB(255, 160, 60),
    Danger = Color3.fromRGB(255, 90, 50),
}

-- Rarity tiers, matching the four the validators accept (Shared/Celebrations/Validate.lua and
-- Shared/Skins/Validate.lua): Common, Rare, Legendary, Mythical. These had drifted too -- Rare was
-- blue in the celebration wheel and gold in the loadout, where it was also indistinguishable from
-- Accent. Blue wins: it keeps every tier a distinct hue from the gold accent.
Theme.Tier = {
    Common = Color3.fromRGB(170, 175, 185),
    Rare = Color3.fromRGB(80, 150, 255),
    Legendary = Color3.fromRGB(255, 160, 60),
    Mythical = Color3.fromRGB(230, 80, 255),
}

-- Loadout slot identity colours.
Theme.Slot = {
    Primary = Color3.fromRGB(80, 230, 120),
    Secondary = Color3.fromRGB(80, 150, 255),
    Melee = Color3.fromRGB(255, 120, 90),
    Utility = Color3.fromRGB(200, 120, 255),
    Celebration = Color3.fromRGB(255, 200, 70),
    AlterEgo = Color3.fromRGB(255, 120, 40),
}

-- Four sizes, not the seven ad-hoc ones this replaced. Display is a banner or a score, Title is a
-- panel heading, Body is the default, Label is a caption or a unit. Sizes only: the three Gotham
-- weights in use are already applied consistently and do not need a token.
Theme.Type = {
    Display = 30,
    Title = 22,
    Body = 16,
    Label = 14,
}

-- Opacity for a panel that carries text. 0.12 keeps TextMuted at 5.8:1 over a bright sky, clear of
-- the 4.5:1 AA floor; the old 0.25-0.4 gave 4.2:1 and 2.8:1. Scrim is the full-screen dim behind a
-- modal, which carries no text of its own.
Theme.Transparency = {
    Panel = 0.12,
    Scrim = 0.45,
}

-- Smallest text that still reads on the current device, in design pixels. Screen's UIScale shrinks
-- text along with the panel, so a design-time 12 becomes roughly 7 px on a phone -- gone. Console
-- is read from across a room and needs more.
function Theme.minTextSize()
    local class = Screen.get().Class
    if class == "Console" then
        return 18
    elseif class == "Phone" then
        return 14
    end
    return 12
end

-- Clamp a design size so it still clears the floor once Screen's UIScale has shrunk it. It divides
-- by the device class's *smallest* scale, not the current one, so the answer does not change when
-- the player rotates the device -- a size sampled at one orientation would otherwise go under the
-- floor in the other.
function Theme.textSize(size)
    local floor = Screen.ScaleFloor[Screen.get().Class] or 1
    return math.max(size, Theme.minTextSize() / floor)
end

-- WCAG relative luminance and contrast ratio. Used by the checks below and available for any new
-- colour pair: AA body text wants 4.5:1, large text 3:1.
local function luminance(color)
    local function channel(c)
        return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

function Theme.contrast(foreground, background)
    local a, b = luminance(foreground), luminance(background)
    if a < b then
        a, b = b, a
    end
    return (a + 0.05) / (b + 0.05)
end

-- Effective contrast once a translucent panel is composited over a backdrop. `backdrop` defaults
-- to a bright sky, which is the worst case this HUD actually faces.
local SKY = Color3.fromRGB(150, 195, 235)

function Theme.contrastOverBackdrop(foreground, panel, panelTransparency, backdrop)
    backdrop = backdrop or SKY
    local t = panelTransparency
    local blended = Color3.new(
        panel.R * (1 - t) + backdrop.R * t,
        panel.G * (1 - t) + backdrop.G * t,
        panel.B * (1 - t) + backdrop.B * t
    )
    return Theme.contrast(foreground, blended)
end

-- Text drawn straight over the 3D world, rather than on a panel, has no guaranteed backdrop and
-- needs a stroke. The server builds world billboards too, so the implementation is shared.
Theme.overWorld = Palette.worldText

return Theme
