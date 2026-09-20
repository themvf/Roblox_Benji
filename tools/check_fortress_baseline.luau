local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Config = require("../src/shared/Config")
local Preview = require("../src/shared/WeaponPreview")

local function phaseCheck(values)
    Config.SetOverrideSource({
        GetAttribute = function(_, key)
            return values[key]
        end,
    })
    local rules = Config.GetConvergence()
    local sum = 0
    for _, duration in rules.PhaseSeconds do
        assert(duration >= 1 and duration < math.huge, "invalid phase duration")
        sum += duration
    end
    assert(math.abs(sum - rules.HardCapSeconds) < 0.001, "phases do not fill match")
    return rules
end

local defaults = phaseCheck({})
assert(defaults.PhaseSeconds[3] == 360, "final phase must use remaining time")
phaseCheck({ Convergence_HardCapSeconds = 10, Convergence_Phase1Seconds = 900, Convergence_Phase2Seconds = 500 })
phaseCheck({ Convergence_HardCapSeconds = 0, Convergence_Phase1Seconds = 0 / 0, Convergence_Phase2Seconds = math.huge })
Config.SetOverrideSource(nil)
local project = serde.decode("json", fs.readFile("default.project.json"))
assert(
    project.tree.ReplicatedStorage.Tuning["$attributes"].Convergence_BotsPerTeam == Config.Convergence.BotsPerTeam,
    "Rojo and Config bot defaults disagree"
)

-- Every corner of the projected bounds must fit, even at the nearest depth plane.
for _, dimensions in { { 10, 1, 2 }, { 1, 12, 1 }, { 4, 4, 4 } } do
    for _, aspect in { 0.5, 1, 2.2, 3 } do
        local w, h, depth = table.unpack(dimensions)
        local distance = Preview.distance(w, h, depth, aspect, 35)
        local visibleHalfHeight = (distance - depth) * math.tan(math.rad(35 / 2))
        assert(h <= visibleHalfHeight and w <= visibleHalfHeight * aspect, "preview crops visible geometry")
        assert(distance > depth, "camera intersects preview")
    end
end
print("PASS: phase boundaries, invalid overrides, effective bot preset, wide/tall weapon framing")
