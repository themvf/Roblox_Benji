-- Build gate: RangeService behaviour, run from its real source against stand-in instances.
--
--   * the range builds: six dummies, each known to IsDummy, nothing else is
--   * entry is refused mid-match; on entry you are moved onto the range holding a gun
--   * the picker only hands out listed guns, and only inside the range
--   * the magazine is put straight back after every shot
--   * a hit reports kit damage, spec damage, falloff and zone to the shooter
--   * enough hits down a dummy with a time-to-kill; it ignores hits while down, stands back
--     up after DownSeconds, and heals to full after HealSeconds without a hit
--   * walking or being teleported out ends range mode and returns the loadout
--
-- Instances are plain tables here (Lune's own have no events and no PivotTo); the datatypes,
-- Enum and every Shared module are real.
--
--     lune run tools/check_range_service.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local Config = require("../src/shared/Config")
local Palette = require("../src/shared/Palette")
local Range = require("../src/shared/Range")
local Weapons = require("../src/shared/Weapons")
local Lobby = require("../src/shared/Maps/Lobby")

local passed, failed = 0, 0
local function check(what, cond, detail)
    if cond then
        passed += 1
        print("PASS  " .. what)
    else
        failed += 1
        print("FAIL  " .. what .. (detail and ("\n        " .. tostring(detail)) or ""))
    end
end
local function near(a, b)
    return math.abs(a - b) < 1e-6
end

-- ===== stand-in instances =====
local function signal()
    local s = { handlers = {} }
    function s:Connect(fn)
        table.insert(self.handlers, fn)
        return { Disconnect = function() end }
    end
    s.Once = s.Connect
    function s:Fire(...)
        for _, fn in table.clone(self.handlers) do
            fn(...)
        end
    end
    return s
end

local SIGNALS = { Changed = true, Destroying = true, Triggered = true, CharacterAdded = true, PlayerAdded = true }
local PARTS = { Part = true }
local Mock = {}
local methods = {}

local function new(class, name)
    local self = setmetatable({ _props = {}, _children = {}, _attrs = {}, _class = class, _signals = {} }, Mock)
    self._props.Name = name or class
    return self
end

Mock.__index = function(self, key)
    if methods[key] then
        return methods[key]
    end
    if key == "ClassName" then
        return rawget(self, "_class")
    end
    local props = rawget(self, "_props")
    if props[key] ~= nil then
        return props[key]
    end
    if SIGNALS[key] then
        local s = signal()
        props[key] = s
        return s
    end
    if key == "Parent" then
        return rawget(self, "_parent")
    end
    if key == "Position" and props.CFrame then
        return props.CFrame.Position
    end
    return methods.FindFirstChild(self, key)
end

Mock.__newindex = function(self, key, value)
    if key == "Parent" then
        local old = rawget(self, "_parent")
        if old then
            local list = rawget(old, "_children")
            local i = table.find(list, self)
            if i then
                table.remove(list, i)
            end
        end
        rawset(self, "_parent", value)
        if value then
            table.insert(rawget(value, "_children"), self)
        end
        return
    end
    local props = rawget(self, "_props")
    local before = props[key]
    props[key] = value
    if key == "Value" and before ~= value and props.Changed then
        props.Changed:Fire(value)
    end
end

function methods:IsA(class)
    local c = rawget(self, "_class")
    return c == class or (class == "BasePart" and PARTS[c] == true)
end
function methods:FindFirstChild(name)
    for _, child in rawget(self, "_children") do
        if rawget(child, "_props").Name == name then
            return child
        end
    end
    return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildOfClass(class)
    for _, child in rawget(self, "_children") do
        if rawget(child, "_class") == class then
            return child
        end
    end
    return nil
end
function methods:GetChildren()
    return table.clone(rawget(self, "_children"))
end
function methods:Destroy()
    local d = rawget(self, "_props").Destroying
    if d then
        d:Fire()
    end
    self.Parent = nil
end
function methods:ClearAllChildren()
    for _, child in self:GetChildren() do
        child:Destroy()
    end
end
function methods:Clone()
    local copy = new(rawget(self, "_class"))
    for k, v in rawget(self, "_props") do
        if not SIGNALS[k] then
            rawget(copy, "_props")[k] = v
        end
    end
    for k, v in rawget(self, "_attrs") do
        rawget(copy, "_attrs")[k] = v
    end
    for _, child in rawget(self, "_children") do
        child:Clone().Parent = copy
    end
    return copy
end
function methods:SetAttribute(key, value)
    rawget(self, "_attrs")[key] = value
end
function methods:GetAttribute(key)
    return rawget(self, "_attrs")[key]
end
function methods:GetAttributeChangedSignal()
    return signal()
end
function methods:GetPivot()
    return rawget(self, "_pivot") or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.new()
end
function methods:PivotTo(cf)
    rawset(self, "_pivot", cf)
end
function methods:SetStateEnabled() end
function methods:EquipTool(tool)
    tool.Parent = self.Parent
end
function methods:GetPlayers()
    return rawget(self, "_players") or {}
end

local MockInstance = {
    new = function(class)
        if class == "Part" then
            local p = new("Part")
            p.CFrame = CFrame.new()
            return p
        end
        return new(class)
    end,
}
-- Shared/Palette builds its world-text stroke with the global Instance
Instance = MockInstance

-- ===== a stand-in place =====
local now = 0
local workspace = new("Workspace")
local replicated = new("ReplicatedStorage")
local tuning = new("Configuration", "Tuning")
tuning.Parent = replicated
local toolsFolder = new("Folder", "WeaponTools")
toolsFolder.Parent = replicated
for _, file in fs.readDir("assets/weapons/tools") do
    local name = file:gsub("%.rbxm$", "")
    local tool = new("Tool", name)
    local config = new("Configuration", "Configuration")
    config.Parent = tool
    local cap = new("IntValue", "AmmoCapacity")
    cap.Value = Weapons[name] and Weapons[name].Ammo and math.min(999, Weapons[name].Ammo[1]) or 1
    cap.Parent = config
    local ammo = new("IntValue", "CurrentAmmo")
    ammo.Value = cap.Value
    ammo.Parent = tool
    tool.Parent = toolsFolder
end

local players = new("Players")
local heartbeat = signal()
local hits = {}
local loadouts = {}
local LOBBY_SPAWN = Vector3.new(Lobby.Origin[1], Lobby.Origin[2] + 3, Lobby.Origin[3] + 42)

local function module(name, value)
    local m = new("ModuleScript", name)
    rawset(m, "_module", value)
    return m
end
local shared = new("Folder", "Shared")
shared.Parent = replicated
module("Config", Config).Parent = shared
module("Palette", Palette).Parent = shared
module("Range", Range).Parent = shared
module("Weapons", Weapons).Parent = shared
local maps = new("Folder", "Maps")
maps.Parent = shared
module("Lobby", Lobby).Parent = maps

local Knit = {
    CreateService = function(def)
        return def
    end,
    CreateSignal = function()
        return {
            Fire = function(_, player, payload)
                table.insert(hits, { player = player, report = payload })
            end,
        }
    end,
    GetService = function(name)
        if name == "SkinService" then
            return { Apply = function() end }
        elseif name == "LoadoutService" then
            return {
                Get = function()
                    return { Primary = "Shotgun", Secondary = "Handgun" }
                end,
            }
        elseif name == "WeaponService" then
            return {
                GiveLoadout = function(_, player)
                    table.insert(loadouts, player)
                end,
            }
        elseif name == "MapService" then
            return { LobbySpawns = { LOBBY_SPAWN } }
        end
        error("unexpected service " .. name)
    end,
}
local packages = new("Folder", "Packages")
packages.Parent = replicated
module("Knit", Knit).Parent = packages

local RangeService = luau.load(fs.readFile("src/server/Services/RangeService.lua"), {
    debugName = "RangeService harness",
    injectGlobals = true,
    environment = {
        game = {
            GetService = function(_, name)
                if name == "Players" then
                    return players
                elseif name == "ReplicatedStorage" then
                    return replicated
                elseif name == "RunService" then
                    return { Heartbeat = heartbeat }
                end
                error("unexpected GetService " .. name)
            end,
        },
        workspace = workspace,
        require = function(target)
            return assert(rawget(target, "_module"), "require of a non-module")
        end,
        Instance = MockInstance,
        Color3 = Color3,
        Enum = Enum,
        Vector3 = Vector3,
        Vector2 = roblox.Vector2,
        CFrame = CFrame,
        UDim2 = roblox.UDim2,
        UDim = roblox.UDim,
        os = {
            clock = function()
                return now
            end,
        },
        task = {
            spawn = function(fn, ...)
                fn(...)
            end,
            delay = function(_, fn, ...)
                fn(...)
            end,
        },
    },
})()

RangeService:KnitStart()

-- ===== build =====
local folder = workspace:FindFirstChild("WeaponRange")
check("the range is built into workspace.WeaponRange", folder ~= nil)
local dummies = {}
for _, child in folder:GetChildren() do
    if child:GetAttribute("RangeDummy") then
        dummies[child:GetAttribute("RangeDummy")] = child
    end
end
check("one dummy per lane", #dummies == #Range.Lanes)
local allKnown = true
for _, d in dummies do
    allKnown = allKnown and RangeService:IsDummy(d) and d.PrimaryPart and d.PrimaryPart.Name == "HumanoidRootPart"
end
check("every dummy is known to IsDummy and has a HumanoidRootPart primary (the kit's getHumanoid)", allKnown)
check(
    "a model that is not a dummy is not one",
    not RangeService:IsDummy(new("Model")) and not RangeService:IsDummy(nil)
)
check("the entrance and the exit carry prompts", (function()
    local e, x = folder:FindFirstChild("RangeEntrance"), folder:FindFirstChild("RangeExit")
    return e and x and e:FindFirstChildOfClass("ProximityPrompt") and x:FindFirstChildOfClass("ProximityPrompt")
end)() ~= nil)

-- ===== a player =====
local function makePlayer(name)
    local player = new("Player", name)
    local character = new("Model", name)
    local root = new("Part", "HumanoidRootPart")
    root.CFrame = CFrame.new(LOBBY_SPAWN)
    root.Parent = character
    character.PrimaryPart = root
    local humanoid = new("Humanoid")
    humanoid.Health = 100
    humanoid.Parent = character
    player.Character = character
    local backpack = new("Backpack")
    backpack.Parent = player
    return player, root
end
local player, root = makePlayer("Tester")
rawset(players, "_players", { player })

local function held(p)
    local tools = {}
    for _, holder in { p:FindFirstChildOfClass("Backpack"), p.Character } do
        for _, c in holder:GetChildren() do
            if c:IsA("Tool") then
                table.insert(tools, c.Name)
            end
        end
    end
    return tools
end

check(
    "equip is refused outside the range",
    RangeService.Client.Equip({ Server = RangeService }, player, "Sniper") == false
)

player:SetAttribute("InMatch", true)
local ok = RangeService:Enter(player)
check("entry is refused mid-match", ok == false and not player:GetAttribute("InRange"))
player:SetAttribute("InMatch", nil)

ok = RangeService:Enter(player)
check("entry puts you in range mode", ok == true and player:GetAttribute("InRange") == true)
check("entry moves you onto the range", Range.inside(root.CFrame.Position), tostring(root.CFrame.Position))
local tools = held(player)
check("you arrive holding your loadout's primary", #tools == 1 and tools[1] == "Shotgun", table.concat(tools, ","))

local client = { Server = RangeService }
check("melee is not on offer", RangeService.Client.Equip(client, player, "Katana") == false)
check("nor is a name that is not a weapon", RangeService.Client.Equip(client, player, "Banana") == false)
check("a listed gun is handed over at once", RangeService.Client.Equip(client, player, "Sniper") == true)
tools = held(player)
check("and it replaces what you held", #tools == 1 and tools[1] == "Sniper", table.concat(tools, ","))
check("the pick is remembered", player:GetAttribute("RangeWeapon") == "Sniper")

local sniper = player.Character:FindFirstChild("Sniper")
local cap = sniper.Configuration.AmmoCapacity.Value
sniper.CurrentAmmo.Value = cap - 1
check("a shot's round is put straight back", sniper.CurrentAmmo.Value == cap)

-- ===== hits =====
local ar = toolsFolder:FindFirstChild("AssaultRifle")
local dummy50 = dummies[3]
check("lane 3 is the 50-stud dummy", Range.Lanes[3].distance == 50)

local function hit(dummy, amount, d, head, tool)
    hits = {}
    RangeService:OnDummyHit(player, dummy, amount, head, { d = d }, tool or ar)
    return hits[1] and hits[1].report
end

now = 10
local r = hit(dummy50, 12, 48, false)
check("a hit is reported to the shooter", r ~= nil and hits[1].player == player)
check(
    "the report carries kit damage, spec, falloff and zone",
    r and r.Damage == 12 and near(r.Spec, 12) and near(r.Falloff, 1) and r.Zone == "FULL" and r.Weapon == "AssaultRifle"
)
check("it names the lane and the measured distance", r and r.Marked == 50 and r.Band == "MID" and r.Distance == 48)
check("the dummy loses the damage", r and r.Health == 100 - 12 and r.MaxHealth == Config.Range.DummyHealth)

r = hit(dummy50, 7.5, 125, false)
check("in falloff: the spec value and zone follow the curve", r and near(r.Spec, 7.5) and r.Zone == "FALLOFF")
r = hit(dummy50, 15, 20, true)
check("a headshot is measured against the crit value", r and r.Headshot and r.Near == 15 and near(r.Falloff, 1))

-- 100 - 12 - 7.5 - 15 = 65.5 left; six more 12s = 72 downs it on the sixth
local downed
for i = 1, 6 do
    now = 10 + i * 0.1
    downed = hit(dummy50, 12, 48, false)
end
check("enough hits down the dummy", downed and downed.Down == true and downed.Health == 0)
check("with a time-to-kill and a hit count", downed and near(downed.TTK, 0.6) and downed.Hits == 9)
check("a downed dummy falls over", dummy50:GetPivot() ~= dummy50.PrimaryPart.CFrame)
check("a downed dummy ignores hits", hit(dummy50, 12, 48, false) == nil)

now += Config.Range.DownSeconds + 0.01
RangeService:Tick()
r = hit(dummy50, 12, 48, false)
check("it stands back up at full health after DownSeconds", r and r.Health == 88 and r.Hits == 1)
check("upright again", near((dummy50:GetPivot().Position - dummy50.PrimaryPart.CFrame.Position).Magnitude, 0))

now += Config.Range.HealSeconds + 0.01
RangeService:Tick()
r = hit(dummy50, 12, 48, false)
check("an idle dummy heals to full after HealSeconds", r and r.Health == 88 and r.Hits == 1)

-- a Tuning override is read live
tuning:SetAttribute("Range_DummyHealth", 150)
now += Config.Range.HealSeconds + 0.01
RangeService:Tick()
r = hit(dummy50, 12, 48, false)
check("dummy health follows the Range_DummyHealth attribute", r and r.MaxHealth == 150 and r.Health == 138)
tuning:SetAttribute("Range_DummyHealth", nil)

-- ===== leaving =====
loadouts = {}
root.CFrame = CFrame.new(LOBBY_SPAWN + Vector3.new(0, 0, -20))
RangeService:Tick()
check("moving out of the range ends range mode", player:GetAttribute("InRange") == false)
check("and gives the loadout back", #loadouts == 1 and loadouts[1] == player)

RangeService:Enter(player)
loadouts = {}
RangeService:Leave(player)
check(
    "leaving sends you to the lobby",
    not Range.inside(root.CFrame.Position) and player:GetAttribute("InRange") == false
)
check("with your loadout", #loadouts == 1)

RangeService:Enter(player)
loadouts = {}
player:SetAttribute("InMatch", true)
root.CFrame = CFrame.new(0, 0, 0)
RangeService:Tick()
check(
    "teleported into a match: range mode ends, the match hands out the loadout",
    player:GetAttribute("InRange") == false and #loadouts == 0
)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
