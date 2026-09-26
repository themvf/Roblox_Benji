-- Build gate: sprint, crouch, slide and the speed rules under them.
--
--   * the speed resolver (Shared/Movement): stances, aim, Tuning ranges, slide easing
--   * speed effects combine in any order -- the Brace + speed pickup overlap used to leave
--     a player at the wrong speed permanently
--   * MovementService refuses illegal stances (cooldown, mutated, celebrating, dead, junk,
--     floods), run against the real service source
--   * one writer: nothing but Movement, MovementController and a bot's spawn writes WalkSpeed
--   * the Weapons Kit's own sprint / aim-slow are switched off in the built kit
--
-- What it cannot check is feel and the procedural pose; those need Studio.
--
--     lune run tools/check_movement.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

Color3 = roblox.Color3
Enum = roblox.Enum
Vector3 = roblox.Vector3

local Config = require("../src/shared/Config")
local Movement = require("../src/shared/Movement")

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

-- ===== resolver =====
local defaults = Config.Movement
local s = Movement.settings(defaults, nil)
check("walk is the kit's old 16", near(Movement.resolve(s, 1, nil, false), 16))
check("sprint is the kit's old 24", near(Movement.resolve(s, 1, "Sprint", false), 24))
check("aiming is the kit's old 8, and cancels sprint", near(Movement.resolve(s, 1, "Sprint", true), 8))
check("crouch is half speed", near(Movement.resolve(s, 1, "Crouch", false), 8))
check("a slide's walk speed is crouch speed", near(Movement.resolve(s, 1, "Slide", false), 8))
check("speed effects multiply the stance", near(Movement.resolve(s, 0.6, "Sprint", false), 14.4))
check("a frozen player stays frozen while sprinting", Movement.resolve(s, 0, "Sprint", false) == 0)

check("slide starts at SlideSpeed", near(Movement.slideSpeed(s, 1, 0), s.SlideSpeed))
check("slide ends at crouch speed", near(Movement.slideSpeed(s, 1, s.SlideSeconds), 8))
local falling = true
for i = 1, 20 do
    falling = falling and Movement.slideSpeed(s, 1, i * 0.05) <= Movement.slideSpeed(s, 1, (i - 1) * 0.05)
end
check("slide speed only ever fades", falling)

local fakeTuning = {
    attrs = {
        Movement_SprintMultiplier = 0 / 0,
        Movement_SlideSpeed = 9999,
        Movement_CrouchMultiplier = 0.4,
        Movement_AutoSprintDesktop = true,
        Movement_WalkSpeed = "fast",
    },
    GetAttribute = function(self, k)
        return self.attrs[k]
    end,
}
local t = Movement.settings(defaults, fakeTuning)
check("NaN tuning falls back to the default", t.SprintMultiplier == defaults.SprintMultiplier)
check("out-of-range tuning falls back", t.SlideSpeed == defaults.SlideSpeed)
check("a wrong-type tuning value falls back", t.WalkSpeed == defaults.WalkSpeed)
check("in-range tuning applies", t.CrouchMultiplier == 0.4 and t.AutoSprintDesktop == true)

-- ===== speed effects in any order (the Brace + pickup bug) =====
local function bot()
    local model = roblox.Instance.new("Model")
    local hum = roblox.Instance.new("Humanoid")
    hum.Parent = model
    model:SetAttribute("BaseWalkSpeed", 16)
    hum.WalkSpeed = 16
    return model, hum
end
local model, hum = bot()
Movement.setModifier(model, "Brace", 0.6, false)
Movement.setModifier(model, "Pickup", 1.25, false)
check("Brace and pickup together combine", near(hum.WalkSpeed, 16 * 0.75))
Movement.setModifier(model, "Brace", nil, false)
check("Brace ending leaves the pickup", near(hum.WalkSpeed, 20))
Movement.setModifier(model, "Pickup", nil, false)
check("both ending restores the base exactly", near(hum.WalkSpeed, 16))
model, hum = bot()
Movement.setModifier(model, "Pickup", 1.25, false)
Movement.setModifier(model, "Brace", 0.6, false)
Movement.setModifier(model, "Pickup", nil, false)
Movement.setModifier(model, "Brace", nil, false)
check("the opposite order restores it too", near(hum.WalkSpeed, 16))
model:SetAttribute("SpeedMul_Junk", -3)
model:SetAttribute("SpeedMul_Nan", 0 / 0)
check("malformed speed effects are ignored", Movement.modifiers(model) == 1)

-- ===== MovementService rules, on the real source =====
local function service()
    local tuning = nil
    local storage = { Packages = { Knit = "Knit" }, Shared = { Config = "Config", Movement = "Movement" } }
    local modules = {
        Knit = {
            CreateService = function(def)
                return def
            end,
            CreateSignal = function()
                return {}
            end,
        },
        Config = Config,
        Movement = Movement,
    }
    storage.FindFirstChild = function(_, name)
        return name == "Tuning" and tuning or nil
    end
    return luau.load(fs.readFile("src/server/Services/MovementService.lua"), {
        debugName = "MovementService",
        injectGlobals = true,
        environment = {
            game = {
                GetService = function(_, name)
                    if name == "ReplicatedStorage" then
                        return storage
                    end
                    return { PlayerRemoving = { Connect = function() end } }
                end,
            },
            require = function(target)
                return assert(modules[target], tostring(target))
            end,
        },
    })()
end
local function player(opts)
    local character = roblox.Instance.new("Model")
    local h = roblox.Instance.new("Humanoid")
    h.Health = opts.dead and 0 or 100
    h.Parent = character
    if opts.celebrating then
        character:SetAttribute("SpeedMul_Celebration", 0)
    end
    local attrs = { Mutated = opts.mutated }
    return {
        Character = character,
        GetAttribute = function(_, k)
            return attrs[k]
        end,
    }
end

local svc = service()
local p = player({})
check("sprint is allowed", svc:SetStance(p, "Sprint", 0) and p.Character:GetAttribute("Stance") == "Sprint")
check("a slide is allowed", svc:SetStance(p, "Slide", 1) and p.Character:GetAttribute("Stance") == "Slide")
local ok, why = svc:SetStance(p, "Slide", 1.5)
check("a second slide inside the cooldown is refused", not ok and why == "cooldown", why)
check("a refused slide leaves the stance alone", p.Character:GetAttribute("Stance") == "Slide")
check("a cooldown after the last slide started, another is allowed", svc:SetStance(p, "Slide", 1 + s.SlideCooldown))
check("walking (nil) is always allowed", svc:SetStance(p, nil, 5) and p.Character:GetAttribute("Stance") == nil)
ok, why = svc:SetStance(player({ mutated = true }), "Crouch", 0)
check("a mutated Titan cannot crouch", not ok and why == "mutated", why)
ok, why = svc:SetStance(player({ celebrating = true }), "Slide", 0)
check("no sliding during a celebration", not ok and why == "celebrating", why)
ok, why = svc:SetStance(player({ dead = true }), "Sprint", 0)
check("the dead do not sprint", not ok and why == "not alive", why)
ok, why = svc:SetStance(player({}), "Fly", 0)
check("an unknown stance is refused", not ok and why == "unknown stance", why)
local flood = player({})
local refused = 0
for i = 1, 40 do
    local okFlood = svc:SetStance(flood, i % 2 == 0 and "Sprint" or nil, 10 + i * 0.001)
    if not okFlood then
        refused += 1
    end
end
check("a flood of stance changes is rate limited", refused == 20, refused)

-- ===== one writer of WalkSpeed =====
local allowed = {
    ["src/shared/Movement.lua"] = true,
    ["src/client/Controllers/MovementController.lua"] = true,
    ["src/server/Services/BotService.lua"] = true, -- a bot's base speed at spawn
}
local writers = {}
local function scan(dir)
    for _, name in fs.readDir(dir) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            scan(path)
        elseif (name:sub(-4) == ".lua" or name:sub(-5) == ".luau") and not allowed[path] then
            local n = 0
            for line in fs.readFile(path):gmatch("[^\n]+") do
                n += 1
                if line:match("%.WalkSpeed%s*=[^=]") and not line:match("^%s*%-%-") then
                    table.insert(writers, path .. ":" .. n)
                end
            end
        end
    end
end
scan("src")
check(
    "only Movement writes WalkSpeed (speed effects go through Movement.setModifier)",
    #writers == 0,
    table.concat(writers, ", ")
)

-- ===== the kit's own speed control is off =====
local kit = roblox.deserializeModel(fs.readFile("assets/WeaponsSystem.rbxm"))[1]
check(
    "the Weapons Kit's sprint and aim-slow are switched off",
    kit.Configuration.SprintEnabled.Value == false and kit.Configuration.SlowZoomWalkEnabled.Value == false
)

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
    process.exit(1)
end
