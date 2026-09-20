--!strict
-- Roblox API dump lookup. The authoritative local answer for whether a class/member/enum exists,
-- what its tags are, and -- the field that actually bites -- its Security.Read / Security.Write.
--
-- Creator Hub prose does NOT reliably show write security. A property can be documented in full,
-- with examples, and still be unwritable by a game script. Check here before claiming otherwise.
--
--   lune run tools/roblox_api.luau property Lighting LightingStyle
--   lune run tools/roblox_api.luau class Lighting            -- members, one line each
--   lune run tools/roblox_api.luau class Lighting --writable -- only script-writable members
--   lune run tools/roblox_api.luau enum LightingStyle
--   lune run tools/roblox_api.luau search ShadowSoft         -- members across all classes
--   lune run tools/roblox_api.luau refresh                   -- re-download the dump
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local DUMP_PATH = "reference/roblox/API-Dump.json"
local DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"

local function fail(msg: string): never
    print("ERROR: " .. msg)
    return process.exit(1) :: never
end

local function refresh()
    print("Fetching " .. DUMP_URL)
    local res = net.request({ url = DUMP_URL, method = "GET" })
    if not res.ok then
        fail(("download failed: HTTP %d"):format(res.statusCode))
    end
    fs.writeDir("reference/roblox")
    fs.writeFile(DUMP_PATH, res.body)
    print(("Wrote %s (%.1f MB)"):format(DUMP_PATH, #res.body / 1024 / 1024))
end

local function load()
    if not fs.isFile(DUMP_PATH) then
        fail(DUMP_PATH .. " is missing. Run: lune run tools/roblox_api.luau refresh")
    end
    return serde.decode("json", fs.readFile(DUMP_PATH))
end

local function classesByName(dump)
    local out = {}
    for _, c in dump.Classes do
        out[c.Name] = c
    end
    return out
end

-- Security is either a plain string or {Read=, Write=}
local function security(member): (string, string)
    local s = member.Security
    if type(s) == "table" then
        return s.Read or "None", s.Write or "None"
    end
    return s or "None", s or "None"
end

local function tagList(member): string
    local t = member.Tags
    if not t or #t == 0 then
        return "none"
    end
    return table.concat(t, ", ")
end

local function valueType(member): string
    local vt = member.ValueType
    if vt then
        return (vt.Category == "Enum" and "Enum." or "") .. tostring(vt.Name)
    end
    if member.MemberType == "Function" or member.MemberType == "Event" then
        return member.MemberType
    end
    return "?"
end

-- walk the inheritance chain so Lighting finds members it gets from Instance
local function findMember(byName, className: string, memberName: string)
    local cursor = byName[className]
    if not cursor then
        fail(("no such class: %s"):format(className))
    end
    while cursor do
        for _, m in cursor.Members do
            if m.Name == memberName then
                return m, cursor.Name
            end
        end
        cursor = cursor.Superclass and byName[cursor.Superclass] or nil
    end
    return nil, nil
end

local function printProperty(byName, className: string, memberName: string)
    local m, owner = findMember(byName, className, memberName)
    if not m then
        print(("Class: %s"):format(className))
        print(("Member: %s"):format(memberName))
        print("Status: DOES NOT EXIST on this class or any superclass")
        print("")
        print("Do not use it. Check `search` for a similarly named member.")
        return
    end
    local read, write = security(m)
    local tags = tagList(m)
    print(("Class: %s"):format(className))
    print(("Member: %s%s"):format(m.Name, owner ~= className and (" (inherited from " .. owner .. ")") or ""))
    print(("MemberType: %s"):format(m.MemberType))
    print(("Type: %s"):format(valueType(m)))
    print(("ReadSecurity: %s"):format(read))
    print(("WriteSecurity: %s"):format(write))
    print(("Tags: %s"):format(tags))
    print(("ScriptWritable: %s"):format(write == "None" and "YES" or "NO"))
    print(("ScriptReadable: %s"):format(read == "None" and "YES" or "NO"))
    -- Studio's Properties panel is elevated, so read security is what hides a row there
    print(("StudioReadable: %s"):format(read == "None" and "YES" or "NO"))
    if string.find(tags, "Deprecated") then
        print("")
        print("NOTE: tagged Deprecated. The dump does not record what replaced it -- check the")
        print("Creator Hub docs for migration guidance before choosing a replacement.")
    end
    if write ~= "None" then
        print("")
        print(("NOTE: WriteSecurity is %s, so a game script CANNOT set this."):format(write))
        print("Do not wrap the assignment in pcall -- that hides the failure. Set it in Studio,")
        print("or find a scriptable alternative.")
    end
end

local function printClass(byName, className: string, writableOnly: boolean)
    local c = byName[className]
    if not c then
        fail(("no such class: %s"):format(className))
    end
    print(("Class: %s (Superclass: %s)"):format(c.Name, tostring(c.Superclass)))
    print("")
    local shown = 0
    for _, m in c.Members do
        local read, write = security(m)
        if not writableOnly or (write == "None" and m.MemberType == "Property") then
            shown += 1
            local flags = {}
            if write ~= "None" then
                table.insert(flags, "write=" .. write)
            end
            if read ~= "None" then
                table.insert(flags, "read=" .. read)
            end
            local t = m.Tags
            if t and #t > 0 then
                table.insert(flags, table.concat(t, "/"))
            end
            print(
                ("  %-34s %-10s %-22s %s"):format(
                    m.Name,
                    m.MemberType,
                    valueType(m),
                    #flags > 0 and ("[" .. table.concat(flags, " ") .. "]") or ""
                )
            )
        end
    end
    print("")
    print(
        ("%d member(s) listed%s. Own members only -- inherited ones are on the superclass."):format(
            shown,
            writableOnly and " (script-writable properties only)" or ""
        )
    )
end

local function printEnum(dump, enumName: string)
    for _, e in dump.Enums do
        if e.Name == enumName then
            print(("Enum: %s"):format(e.Name))
            for _, item in e.Items do
                print(("  %-28s = %d"):format(item.Name, item.Value))
            end
            return
        end
    end
    fail(("no such enum: %s"):format(enumName))
end

local function search(dump, needle: string)
    local lower = string.lower(needle)
    local hits = 0
    for _, c in dump.Classes do
        for _, m in c.Members do
            if string.find(string.lower(m.Name), lower, 1, true) then
                local read, write = security(m)
                hits += 1
                print(("  %-26s %-30s %-10s read=%-22s write=%s"):format(c.Name, m.Name, m.MemberType, read, write))
                if hits >= 60 then
                    print("  ... truncated at 60 hits; narrow the search")
                    return
                end
            end
        end
    end
    if hits == 0 then
        print(("no member matching %q in any class"):format(needle))
    end
end

local args = process.args
local cmd = args[1]

if cmd == "refresh" then
    refresh()
elseif cmd == "property" and args[2] and args[3] then
    printProperty(classesByName(load()), args[2], args[3])
elseif cmd == "class" and args[2] then
    printClass(classesByName(load()), args[2], args[3] == "--writable")
elseif cmd == "enum" and args[2] then
    printEnum(load(), args[2])
elseif cmd == "search" and args[2] then
    search(load(), args[2])
else
    print("usage:")
    print("  lune run tools/roblox_api.luau property <Class> <Member>")
    print("  lune run tools/roblox_api.luau class <Class> [--writable]")
    print("  lune run tools/roblox_api.luau enum <EnumName>")
    print("  lune run tools/roblox_api.luau search <text>")
    print("  lune run tools/roblox_api.luau refresh")
    process.exit(1)
end
