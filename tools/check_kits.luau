-- Build gate: every kit in src/shared/Kits/Registry against the kit rules.
-- Run: lune run tools/check_kits.luau     (exit code 1 on any failure)
--
-- Checks what a computer can: text that fits the card, a passive and a tactical, every
-- number tunable and bounded, nothing that touches a weapon, Credits-only prices, one
-- starter at most, the shared tactical key still free, the card passing CatalogItem, and
-- for a kit past Design, that its server handlers and design record exist.
local fs = require("@lune/fs")
local process = require("@lune/process")
local Kits = require("../src/shared/Kits")
local CatalogItem = require("../src/shared/CatalogItem")

local DIR = "src/shared/Kits/Registry"
local HANDLERS = "src/server/KitAbilities"

local files = fs.isDir(DIR) and fs.readDir(DIR) or {}
table.sort(files)

local failures, defs, seen = 0, {}, {}
for _, file in files do
    if file:sub(-4) == ".lua" then
        local name = file:sub(1, -5)
        local ok, def = pcall(require, "../" .. DIR .. "/" .. name)
        local errors = ok and Kits.validate(def) or { "does not load: " .. tostring(def) }
        if ok and type(def) == "table" then
            if def.Id ~= name then
                table.insert(errors, "file name should be " .. tostring(def.Id) .. ".lua")
            end
            if seen[def.Id] then
                table.insert(errors, "duplicate Id")
            end
            seen[def.Id or file] = true
            table.insert(defs, def)
            local record = ("docs/design/kits/%s/KIT_RECORD.md"):format(name:lower())
            if not fs.isFile(record) then
                table.insert(errors, "no design record at " .. record .. " (lune run tools/new_kit.luau makes one)")
            end
            if #errors == 0 then
                for _, problem in CatalogItem.validate(Kits.defaultCard(def)) do
                    table.insert(errors, "card: " .. problem)
                end
                if def.Status ~= "Design" then
                    for _, slot in { "Passive", "Tactical" } do
                        local path = ("%s/%s.lua"):format(HANDLERS, def[slot].Handler)
                        if not fs.isFile(path) then
                            table.insert(
                                errors,
                                ("%s is %s but %s has no handler at %s"):format(name, def.Status, slot, path)
                            )
                        end
                    end
                end
            end
        end
        if #errors == 0 then
            local price = def.Price and def.Price.Credits and (def.Price.Credits .. " Credits") or "price pending"
            print(("OK    %-16s %-8s %-12s %-11s %s"):format(def.Id, def.Status, def.Role, def.Access, price))
        else
            failures += 1
            print("FAIL  " .. file)
            for _, e in errors do
                print("        - " .. e)
            end
        end
    end
end

local registryErrors = Kits.validateAll(defs)
for _, e in registryErrors do
    failures += 1
    print("FAIL  registry: " .. e)
end

print(("\n%d kits checked, %d failed"):format(#defs, failures))
if failures > 0 then
    process.exit(1)
end
