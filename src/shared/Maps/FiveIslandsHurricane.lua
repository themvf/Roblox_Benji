-- Five Islands Hurricane: public arena wrapper over the Studio-authored FiveIslands package.
--
-- To add/edit props, buildings, trees, or lights in Studio:
--   1. Edit `FiveIslands — EDITABLE` (assets/environment/source/FiveIslands.rbxm) under Geometry.
--   2. Save to File over assets/environment/source/FiveIslands.rbxm.
--   3. Run `.\tools\save_map.cmd FiveIslands` (or `bash tools/save_map.sh FiveIslands`).
-- Sky, storm lighting, palette, and terrain live in assets/environment/source/FiveIslands.presentation.lua.
local source = require(script.Parent.FiveIslands)

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in value do
        result[key] = copy(child)
    end
    return result
end

local map = copy(source)
map.Name = "FiveIslandsHurricane"
map.DisplayName = "Five Islands Hurricane"
map.Mode = "TDM"
map.BakedMap = source.Name
map.Draft = nil
map.Authored = nil -- generated-file drift checks belong to FiveIslands.lua, not this wrapper

-- Convergence always funnels to the central vault (B) in Phase 3 after both outer islands close together.
map.Finale = nil
local PHASE_SCHEDULE = {
    A = { 1, 2 },
    B = { 1, 2, 3 },
    C = { 1, 2 },
}
for _, objective in map.Objectives do
    if PHASE_SCHEDULE[objective.Id] then
        objective.Phases = PHASE_SCHEDULE[objective.Id]
    end
end

map.SniperOutposts = {
    { Name = "North Overlook", pos = { 0, 41, -246 }, radius = 12 },
    { Name = "South Overlook", pos = { 0, 41, 246 }, radius = 12 },
}

-- Center Vault holds CQC/heavy placeholder pickups; WhiteSnipers spawn at North & South Overlook backside approaches.
map.Pickups = {
    { kind = "weapon", weapon = "Minigun", pos = { 0, 6.5, 0 }, respawn = 60, duration = 35 },
    { kind = "weapon", weapon = "EnergyRifle", pos = { 0, 6.5, -16 }, respawn = 45, duration = 40 },
    { kind = "weapon", weapon = "Wildcat", pos = { 0, 6.5, 16 }, respawn = 45, duration = 40 },
    {
        kind = "weapon",
        weapon = "WhiteSniper",
        pos = { 0, 24.8, -258 },
        respawnTuning = "WhiteSniperRespawnSeconds",
        respawnOnDeath = true,
    },
    {
        kind = "weapon",
        weapon = "WhiteSniper",
        pos = { 0, 24.8, 258 },
        respawnTuning = "WhiteSniperRespawnSeconds",
        respawnOnDeath = true,
    },
    { kind = "speed", pos = { -20, 5.5, 0 } },
    { kind = "speed", pos = { 20, 5.5, 0 } },
}

-- One-way return launch pads from Sniper Overlooks back onto Center outer beach.
map.LaunchPads = {
    { pos = { 0, 24.3, -223 }, target = { 0, 3.2, -50 }, vy = 66, size = 8 },
    { pos = { 0, 24.3, 223 }, target = { 0, 3.2, 50 }, vy = 66, size = 8 },
}

-- Spawn-exclusive drivable vehicles built by VehicleService at match/explore start.
map.VehicleSpawns = {
    Helicopter = {
        seats = 4,
        passengerFire = false,
        respawn = 25,
        abandonedReset = 25,
        pads = {
            { team = "Red", pos = { -352, 4.5, -28 }, yaw = -90 },
            { team = "Blue", pos = { 352, 4.5, -28 }, yaw = 90 },
        },
    },
    -- The patrol RHIB is 30 studs long and 10 wide (assets/models/patrol-rhib). The beach
    -- starts at x = 278 and the dock is 8 wide, so each boat lies alongside the dock with its
    -- stern a stud clear of the sand and its collar just off the dock edge. One seat for now.
    RHIB = {
        seats = 1,
        passengerFire = true,
        respawn = 15,
        abandonedReset = 25,
        docks = {
            { team = "Red", pos = { -262, 0.35, -10 }, yaw = -90 },
            { team = "Red", pos = { -262, 0.35, 10 }, yaw = -90 },
            { team = "Blue", pos = { 262, 0.35, -10 }, yaw = 90 },
            { team = "Blue", pos = { 262, 0.35, 10 }, yaw = 90 },
        },
    },
    WaveRunner = {
        seats = 1,
        passengerFire = false,
        respawn = 10,
        abandonedReset = 25,
        docks = {
            -- Moved out from z = 15 to clear the wider RHIBs beside the dock.
            { team = "Red", pos = { -272, 0.35, -20 }, yaw = -90 },
            { team = "Red", pos = { -272, 0.35, 20 }, yaw = -90 },
            { team = "Blue", pos = { 272, 0.35, -20 }, yaw = 90 },
            { team = "Blue", pos = { 272, 0.35, 20 }, yaw = 90 },
        },
    },
}

return map
