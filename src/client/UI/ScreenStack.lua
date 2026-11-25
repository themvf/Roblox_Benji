-- ScreenStack: one Back rule for every lobby screen.
--
-- Opening a screen from another one hides the first and keeps it; closing the top one (its X,
-- controller B, or ScreenStack.back) shows the one underneath again with its focus where the
-- player left it. Without this each screen invents its own idea of "back" and a player three
-- screens deep has to close three unrelated things.
--
--   ScreenStack.push(screen)     hide the current top, open `screen`
--   ScreenStack.back()           close the top; true when there was one
--   ScreenStack.clear()          close everything without showing what was underneath
--                                (a match is starting)
--   ScreenStack.onChange(fn)     fn(depth, top) now and whenever the stack changes
--
-- A screen needs Open, Resume, Suspend and Close, and must call `self.Stack.closed(self)` at
-- the end of its own Close. UI/CatalogScreen does.
local ScreenStack = {}

local entries = {}
local listeners = {}
local clearing = false

local function changed()
    for _, fn in listeners do
        fn(#entries, entries[#entries])
    end
end

function ScreenStack.depth()
    return #entries
end

function ScreenStack.top()
    return entries[#entries]
end

function ScreenStack.push(screen)
    local top = entries[#entries]
    if top == screen then
        return
    end
    if top then
        top:Suspend()
    end
    -- a screen appears once: reopening one from deeper down moves it to the top
    local at = table.find(entries, screen)
    if at then
        table.remove(entries, at)
    end
    table.insert(entries, screen)
    screen.Stack = ScreenStack
    screen:Open()
    changed()
end

function ScreenStack.back()
    local top = entries[#entries]
    if not top then
        return false
    end
    top:Close() -- which calls ScreenStack.closed
    return true
end

-- Called by a screen at the end of its own Close.
function ScreenStack.closed(screen)
    local at = table.find(entries, screen)
    if not at or clearing then
        return
    end
    local wasTop = at == #entries
    table.remove(entries, at)
    if wasTop then
        local below = entries[#entries]
        if below then
            below:Resume()
        end
    end
    changed()
end

function ScreenStack.clear()
    clearing = true
    for index = #entries, 1, -1 do
        local screen = entries[index]
        entries[index] = nil
        screen:Close()
    end
    clearing = false
    changed()
end

-- Redraw the top screen: something outside it changed the room it has (the queue strip).
function ScreenStack.refresh()
    local top = entries[#entries]
    if top and top.Render then
        top:Render()
    end
end

function ScreenStack.onChange(fn)
    table.insert(listeners, fn)
    fn(#entries, entries[#entries])
    return function()
        local at = table.find(listeners, fn)
        if at then
            table.remove(listeners, at)
        end
    end
end

return ScreenStack
