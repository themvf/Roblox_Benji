-- UI gallery: every catalog screen, in every state, from made-up data.
--
-- Set the Tuning attribute Debug_UiGallery to "Browser", "LockIn", "Track" or "Shell" in Studio
-- (ReplicatedStorage > Tuning) and the screen opens; set it back to "" to close it. Use it with
-- the device emulator to capture phone, tablet, desktop and console layouts before the real
-- service exists.
--
-- The answers here are faked on the client so each state can be reached by pressing things:
-- equip works, a purchase goes pending and then lands, and the season track's premium purchase
-- is always refused the way a server rejection would be. None of this is evidence that
-- ownership or purchases work.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CatalogScreen = require(script.Parent.Parent.UI.CatalogScreen)
local Components = require(script.Parent.Parent.UI.Components)
local LobbyShell = require(script.Parent.Parent.UI.LobbyShell)
local MockCatalog = require(script.Parent.Parent.UI.MockCatalog)
local ScreenStack = require(script.Parent.Parent.UI.ScreenStack)

local UiGalleryController = Knit.CreateController({ Name = "UiGalleryController" })

local LOCK_IN_SECONDS = 20

local function find(items, id)
    for _, item in items do
        if item.Id == id then
            return item
        end
    end
    return nil
end

-- What a server would send back after accepting a selection.
local function markSelected(items, id, selectedAction, idleAction)
    for _, item in items do
        if item.Kind == "Kit" and (item.Action == selectedAction or item.Action == idleAction) then
            item.Selected = item.Id == id
            item.Action = item.Selected and selectedAction or idleAction
        end
    end
end

function UiGalleryController:Screen(template)
    self.Screens = self.Screens or {}
    if self.Screens[template] then
        return self.Screens[template]
    end
    local now = Components.now()
    local screen
    if template == "Browser" then
        local items = MockCatalog.items(now)
        screen = CatalogScreen.new({
            Name = "UiGalleryBrowser",
            Template = "Browser",
            Title = "GALLERY: BROWSER",
            Tabs = MockCatalog.Tabs,
            ConfirmNote = "Kits are sidegrades, not upgrades.",
            Preview = function()
                return false -- no model: the screen shows its "visual in development" state
            end,
            OnAction = function(item, action)
                if action == "Equip" then
                    screen:SetStatus("Saving...", "TextMuted")
                    task.delay(0.4, function()
                        markSelected(items, item.Id, "Equipped", "Equip")
                        screen:SetItems(items)
                        screen:SetStatus(item.Title .. " equipped.", "Good")
                    end)
                elseif action == "Buy" then
                    local record = find(items, item.Id)
                    record.Action = "Pending"
                    screen:SetItems(items)
                    screen:SetStatus("Checking purchase...", "TextMuted")
                    task.delay(1.5, function()
                        record.Access = "Owned"
                        record.Action = record.Kind == "Kit" and "Equip" or "None"
                        record.Price = nil
                        screen:SetItems(items)
                        screen:SetStatus(item.Title .. " unlocked.", "Good")
                    end)
                end
            end,
        })
        screen:SetItems(items)
    elseif template == "LockIn" then
        local items = MockCatalog.lockIn(now)
        screen = CatalogScreen.new({
            Name = "UiGalleryLockIn",
            Template = "LockIn",
            Title = "KIT LOCK-IN",
            OnAction = function(item, action)
                if action == "Select" then
                    markSelected(items, item.Id, "LockedIn", "Select")
                    screen:SetItems(items)
                    screen:SetStatus(item.Title .. " locked in.", "Good")
                end
            end,
        })
        screen:SetItems(items)
    else
        screen = CatalogScreen.new({
            Name = "UiGalleryTrack",
            Template = "Track",
            Title = "GALLERY: SEASON TRACK",
            OnAction = function(target, action)
                if action == "Claim" then
                    screen:SetStatus(("Tier %d reward claimed (not really)."):format(target.Tier), "Good")
                else
                    screen:SetStatus("The server refused the purchase (gallery).", "Danger")
                end
            end,
        })
        screen:SetTrack(MockCatalog.track(now))
    end
    self.Screens[template] = screen
    return screen
end

-- The lobby shell on made-up data. PLAY joins a pretend queue; SHOP and PASS open the gallery
-- screens on the shared stack, so Back and the queue strip above a modal can be tried.
function UiGalleryController:Shell()
    if self.ShellScreen then
        return self.ShellScreen
    end
    local mock = MockCatalog.shell(Components.now())
    local shell
    shell = LobbyShell.new({
        Name = "UiGalleryShell",
        Destinations = mock.Destinations,
        OnNavigate = function(id)
            if id == "Play" then
                shell:SetQueue({
                    State = "Searching",
                    Mode = mock.Queue.Mode,
                    Team = mock.Queue.Team,
                    Since = Components.now(),
                })
                shell:Toast("Joined the queue (gallery).", "Good")
            elseif id == "Shop" then
                ScreenStack.push(self:Screen("Browser"))
            elseif id == "Pass" then
                ScreenStack.push(self:Screen("Track"))
            else
                shell:SetActive(id)
                shell:Toast(id .. " is not built yet.", "Warn")
            end
        end,
        OnLeaveQueue = function()
            shell:SetQueue(nil)
            shell:Toast("Left the queue.", "TextMuted")
        end,
        OnWallet = function()
            shell:Toast("The wallet opens the shop (not built).", "Warn")
        end,
    })
    shell:SetDots(mock.Dots)
    -- the profile arrives a moment later, so the LOADING readout can be seen
    task.delay(1.5, function()
        shell:SetProfile(mock.Profile)
    end)
    self.ShellScreen = shell
    return shell
end

function UiGalleryController:Show(template)
    ScreenStack.clear()
    for _, screen in self.Screens or {} do
        screen:Close()
    end
    if self.ShellScreen then
        self.ShellScreen:Hide()
    end
    if template == "Shell" then
        self:Shell():Show()
        return
    end
    if template ~= "Browser" and template ~= "LockIn" and template ~= "Track" then
        return
    end
    local screen = self:Screen(template)
    if template == "LockIn" then
        screen:SetDeadline(Components.now() + LOCK_IN_SECONDS, "Penthouse")
    end
    screen:Open()
end

function UiGalleryController:KnitStart()
    task.spawn(function()
        local tuning = ReplicatedStorage:WaitForChild("Tuning", 30)
        if not tuning then
            return
        end
        local function refresh()
            self:Show(tuning:GetAttribute("Debug_UiGallery"))
        end
        tuning:GetAttributeChangedSignal("Debug_UiGallery"):Connect(refresh)
        refresh()
    end)
end

return UiGalleryController
