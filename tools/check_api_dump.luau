--!strict
-- Build gate: the local Roblox API dump must exist and be recent.
--
-- This is a gate rather than a line of prose in CLAUDE.md on purpose. "Refresh it if it is stale"
-- only runs when someone remembers; a gate runs every time. The dump is the authoritative source
-- for member existence and Security.Read / Security.Write, and a stale one is quietly wrong in
-- exactly the way that is hardest to notice.
local fs = require("@lune/fs")
local process = require("@lune/process")

local DUMP_PATH = "reference/roblox/API-Dump.json"
local MAX_AGE_DAYS = 7
local REFRESH_CMD = "lune run tools/roblox_api.luau refresh"

local function die(lines: { string }): never
    for _, l in lines do
        print(l)
    end
    return process.exit(1) :: never
end

if not fs.isFile(DUMP_PATH) then
    die({
        "ERROR: Roblox API dump is missing.",
        "",
        ("Expected: %s"):format(DUMP_PATH),
        "",
        "Run:",
        "  " .. REFRESH_CMD,
    })
end

local meta = fs.metadata(DUMP_PATH)
local modified = meta.modifiedAt
if not modified then
    die({ "ERROR: could not read the modification time of " .. DUMP_PATH })
end

local ageSeconds = os.time() - math.floor(modified.unixTimestamp)
local ageDays = ageSeconds / 86400

if ageDays > MAX_AGE_DAYS then
    die({
        "ERROR: Roblox API dump is stale.",
        "",
        ("API-Dump.json age: %d days"):format(math.floor(ageDays)),
        ("Maximum allowed:   %d days"):format(MAX_AGE_DAYS),
        "",
        "Roblox ships engine changes continuously. A stale dump will report old security",
        "levels and miss members that now exist.",
        "",
        "Run:",
        "  " .. REFRESH_CMD,
    })
end

print(("API dump OK: %.1f days old (max %d)"):format(ageDays, MAX_AGE_DAYS))
