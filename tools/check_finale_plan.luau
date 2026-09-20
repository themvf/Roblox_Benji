local Plan = require("../src/server/FinalePlan")
local objectives = { { Id = "gate" }, { Id = "yard" }, { Id = "keep" } }
local settings = { EligibleIds = { "gate", "yard", "keep" } }
local cases = 0
for final = 1, 3 do
    for close = 1, 2 do
        local calls = 0
        local plan = assert(Plan.create("pair-" .. final .. close, objectives, settings, function()
            calls += 1
            return calls == 1 and final or close
        end))
        assert(plan.FinalId == objectives[final].Id)
        assert(Plan.visibleFinal(plan, 1) == nil and Plan.visibleFinal(plan, 2) == nil, "secret leaked before reveal")
        for phase = 1, 3 do
            local live = 0
            for _, objective in objectives do
                if Plan.live(plan, objective.Id, phase) then
                    live += 1
                end
            end
            assert(live == 4 - phase, "incorrect active-zone count")
        end
        assert(Plan.live(plan, plan.FinalId, 2) and Plan.live(plan, plan.FinalId, 3))
        assert(
            not Plan.live(plan, plan.FirstClosedId, 2) and not Plan.live(plan, plan.FirstClosedId, 3),
            "closed zone reopened"
        )
        assert(Plan.reveal(plan) and not Plan.reveal(plan), "reveal was not idempotent")
        assert(Plan.visibleFinal(plan, 1) == nil, "phase 1 snapshot leaked final")
        assert(Plan.visibleFinal(plan, 2) == plan.FinalId and Plan.visibleFinal(plan, 3) == plan.FinalId)
        cases += 1
    end
end
local first = assert(Plan.create("repeat", objectives, settings, function()
    return 1
end))
local aborted = assert(Plan.create("repeat", objectives, settings, function()
    return 1
end))
assert(first.FinalId == aborted.FinalId, "unrevealed abort consumed history")
Plan.reveal(first)
local otherMap = assert(Plan.create("other-map", objectives, settings, function()
    return 1
end))
Plan.reveal(otherMap)
local nextMatch = assert(Plan.create("repeat", objectives, settings, function()
    return 1
end))
assert(nextMatch.FinalId ~= first.FinalId, "intervening map reset repeat prevention")
for i = 1, 30 do
    Plan.reveal(nextMatch)
    local nextPlan = assert(Plan.create("repeat", objectives, settings))
    assert(nextPlan.FinalId ~= nextMatch.FinalId)
    nextMatch = nextPlan
end
local restricted = assert(Plan.create("restricted", objectives, { EligibleIds = { "yard", "keep" } }))
assert(restricted.FinalId ~= "gate", "excluded district selected")
for _, bad in
    {
        { EligibleIds = {} },
        { EligibleIds = { "gate" } },
        { EligibleIds = { "gate", "missing" } },
        { EligibleIds = { "gate", "gate" } },
        12,
    }
do
    local plan, message = Plan.create("invalid", objectives, bad)
    assert(plan == nil and message, "bad config did not fail preflight")
end
local duplicate, duplicateError =
    Plan.create("duplicate", { { Id = "gate" }, { Id = "gate" }, { Id = "keep" } }, settings)
assert(not duplicate and duplicateError)
assert(Plan.create("fixed", objectives, nil) == nil, "fixed-phase map opted in accidentally")
assert(objectives[1].Phases == nil and settings.EligibleIds[1] == "gate", "shared map data mutated")
print(
    "PASS: "
        .. cases
        .. " closure combinations, hidden/revealed state, history/aborts, exclusions, invalid configuration, fixed-map compatibility"
)
