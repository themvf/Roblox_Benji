-- Server-only match plans. Map definitions are never mutated and hidden choices never go to bots.
local FinalePlan = {}
local lastRevealed = {}

function FinalePlan.create(mapId, objectives, settings, randomIndex)
    if not settings then
        return nil
    end
    if #objectives ~= 3 or type(settings) ~= "table" or type(settings.EligibleIds) ~= "table" then
        return nil, "rotating finale requires three objectives and EligibleIds"
    end
    local ids = {}
    for _, objective in objectives do
        if type(objective.Id) ~= "string" or ids[objective.Id] then
            return nil, "objectives require unique stable IDs"
        end
        ids[objective.Id] = true
    end
    local eligible, seen = {}, {}
    for _, id in settings.EligibleIds do
        if not ids[id] or seen[id] then
            return nil, "invalid or duplicate eligible objective ID"
        end
        seen[id] = true
        table.insert(eligible, id)
    end
    if #eligible < 2 then
        return nil, "at least two eligible finales are required"
    end
    local choices = {}
    for _, id in eligible do
        if id ~= lastRevealed[mapId] then
            table.insert(choices, id)
        end
    end
    randomIndex = randomIndex or math.random
    local finalId = choices[randomIndex(#choices)]
    local others = {}
    for _, objective in objectives do
        if objective.Id ~= finalId then
            table.insert(others, objective.Id)
        end
    end
    return { MapId = mapId, FinalId = finalId, FirstClosedId = others[randomIndex(#others)], Revealed = false }
end

function FinalePlan.live(plan, id, phase)
    return phase == 1 or (phase == 2 and id ~= plan.FirstClosedId) or (phase >= 3 and id == plan.FinalId)
end

function FinalePlan.reveal(plan)
    if plan.Revealed then
        return false
    end
    plan.Revealed = true
    lastRevealed[plan.MapId] = plan.FinalId
    return true
end

function FinalePlan.visibleFinal(plan, phase)
    return plan and plan.Revealed and phase >= 2 and plan.FinalId or nil
end

return FinalePlan
