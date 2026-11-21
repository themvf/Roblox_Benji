-- Start a kit: writes src/shared/Kits/Registry/<Id>.lua and docs/design/kits/<id>/KIT_RECORD.md.
-- Run: lune run tools/new_kit.luau <Id>          (Id in PascalCase, e.g. Graviton)
--
-- Both files are full of TODO, which check_kits refuses, so a half-written kit cannot pass
-- the build. Refuses to overwrite an existing kit.
local fs = require("@lune/fs")
local process = require("@lune/process")

local id = process.args[1]
if type(id) ~= "string" or not id:match("^%u%w+$") then
    print("usage: lune run tools/new_kit.luau <Id>   (PascalCase letters and digits)")
    process.exit(1)
end

local definition = "src/shared/Kits/Registry/" .. id .. ".lua"
local folder = "docs/design/kits/" .. id:lower()
local record = folder .. "/KIT_RECORD.md"
for _, path in { definition, record } do
    if fs.isFile(path) then
        print("already exists: " .. path)
        process.exit(1)
    end
end

local DEFINITION = [[
-- Design record: RECORD
return {
    Id = "ID",
    Name = "TODO name on the card, capitals",
    Role = "TODO one of Kits.Roles",
    Fantasy = "TODO one sentence a player would say",
    Decision = "TODO the choice this kit adds that no other kit does",
    Status = "Design",
    Access = "Purchasable",
    RotationEligible = true,
    Price = nil, -- pending until the user names a Credit price; never Robux
    Passive = {
        Name = "TODO",
        Text = "TODO what the player sees happen, in one line",
        Handler = "TodoPassive",
        Tuning = {
            -- Name = { Default = 0, Min = 0, Max = 0, Unit = "s" },
        },
    },
    Tactical = {
        Name = "TODO",
        Text = "TODO what the player sees happen, including the downside",
        Handler = "TodoTactical",
        TouchLabel = "TODO",
        Cooldown = { Default = 12, Min = 6, Max = 30, Unit = "s" },
        Tuning = {},
    },
    Cost = "TODO the price of using it: a slow, a window, a tell",
    Counter = "TODO what an enemy does about it",
    Stacking = "TODO two of this kit on one team; what a second use does to the first",
    Look = { Package = nil, Note = "TODO no art yet, or the asset package" },
}
]]

local RECORD = [[
# TODO display name (`ID`)

Definition: [ID.lua](../../../../src/shared/Kits/Registry/ID.lua) · Checklist:
[KIT_MINIMUM_CHECKLIST.md](../KIT_MINIMUM_CHECKLIST.md) · Workflow: the `kit-from-prompt` skill.
Mark each line **Decided**, **Hypothesis**, **Verified** or **Not applicable — reason**.

- Status / gate: Design
- Owner / updated: TODO
- Role and one-sentence fantasy: TODO
- Access type / rotation eligible: Purchasable / TODO
- Fallback starter kit: Titan
- Player decision: TODO
- Passive: TODO
- Tactical / Utility-slot behavior: TODO
- Cost or vulnerable window: TODO
- Enemy counterplay: TODO
- Duplicate/stacking rule: TODO
- Tuning source and valid ranges: the definition file; every number is `Kit_ID_<Ability>_<Key>` in Tuning
- Keyboard / gamepad / touch action: G / DPadRight / TODO touch label (shared kit action)
- Ready / active / cooldown / failure feedback: TODO
- Server handler and validation: TODO handler names; request checks (alive, in match, cooldown, rate)
- Visual reference and asset handoff: TODO
- Team-readability treatment: TODO
- Telemetry events: tactical attempts, accepted, rejected by reason, hits; passive triggers
- Acceptance evidence: none yet
- Known limitations / next concrete action: TODO

## Intake answers

Recorded once, in the user's words where they gave them.

TODO

## Not verified

Nothing has been played. List what Studio, two clients and each device still owe.
]]

local function fill(template)
    return (template:gsub("RECORD", record):gsub("ID", id))
end

fs.writeDir(folder)
fs.writeFile(definition, fill(DEFINITION))
fs.writeFile(record, fill(RECORD))
print("wrote " .. definition)
print("wrote " .. record)
print("next: fill both, then  lune run tools/check_kits.luau")
