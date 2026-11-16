--!strict
-- No file over 5 MB enters git without a written reason.
--
-- Git keeps every version of a binary for ever, so one 13 MB model rebuilt ten times is
-- 130 MB every clone downloads. Generated candidates and superseded exports rebuild from
-- the package source and stay out (assets/models/*/trials/ is ignored). A file that has
-- to be committed, because nothing else can recreate it, is listed with its reason in
-- tools/large_files.json.
--
-- Reads the index, so a file is caught when it is staged, before the commit exists.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local LIMIT = 5 * 1024 * 1024
local ALLOWED = "tools/large_files.json"

local allowed: { [string]: string } = {}
if fs.isFile(ALLOWED) then
    for path, reason in serde.decode("json", fs.readFile(ALLOWED)) do
        if type(reason) == "string" and path:sub(1, 1) ~= "_" then
            allowed[path] = reason
        end
    end
end

-- `git ls-files -s -l` is not a thing; ls-tree has sizes but only for a commit. So list
-- the index with --format, which can print each staged blob's size directly.
local listed = process.exec("git", { "-c", "core.quotePath=false", "ls-files", "--format=%(objectsize) %(path)" })
if not listed.ok then
    print("git ls-files failed: " .. listed.stderr)
    process.exit(1)
end

local failures, checked, seen = 0, 0, {}
for line in listed.stdout:gmatch("[^\r\n]+") do
    local size, path = line:match("^%s*(%d+) (.+)$")
    local bytes = tonumber(size)
    if bytes and path then
        checked += 1
        if bytes > LIMIT then
            seen[path] = true
            if allowed[path] then
                print(("OK    %5.1f MB  %s  (%s)"):format(bytes / 1048576, path, allowed[path]))
            else
                failures += 1
                print(("FAIL  %5.1f MB  %s"):format(bytes / 1048576, path))
            end
        end
    end
end
for path in allowed do
    if not seen[path] then
        failures += 1
        print(("FAIL  %s is listed in %s but is not a tracked file over the limit; remove the line"):format(path, ALLOWED))
    end
end

print("")
print(("%d tracked files checked, %d problems"):format(checked, failures))
if failures > 0 then
    print("Unstage it (git rm --cached <file>) if it can be rebuilt, or add it to " .. ALLOWED .. " with the reason it cannot.")
    process.exit(1)
end
