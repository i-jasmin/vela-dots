-- Keybinds you change -- the plumbing between Settings, Keybinds and binds.lua.
--
-- binds.lua is vela's defaults, and an update of the dots replaces it. What you
-- change in Settings, Keybinds goes to ~/.config/vela/keybinds.json instead,
-- which no update touches (it is in .gitignore), and binds.lua reads it every
-- time Hyprland loads the config:
--
--     {
--       "changed": { "shell.launcher": "SUPER + A", "windows.pin": false },
--       "custom":  [ { "name": "VS Code", "keys": "SUPER + C", "command": "code" } ]
--     }
--
--   changed   a vela bind's id and the keys it is on now, or false for off.
--             For a family (super + 1 ... 9) it is the modifiers alone.
--   custom    binds of your own: a name for the cheatsheet, the keys, and a
--             command to run.
--
-- A default you have not changed is not in the file, so it follows binds.lua
-- when an update changes it. The file is Settings' to write, but it is plain
-- JSON and fine to edit by hand; `hyprctl reload` then applies it.
--
-- Settings has to know every bind, its id and its default, and hyprctl only
-- knows what is bound now. So each load also writes that list, the manifest,
-- to $XDG_RUNTIME_DIR/vela-keybinds.json.

local K = {}

local config = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")
local runtime = os.getenv("XDG_RUNTIME_DIR")

K.user_file = config .. "/vela/keybinds.json"
K.manifest_file = runtime and (runtime .. "/vela-keybinds.json") or nil

-- ---------------------------------------------------------------- JSON --
-- Lua has no JSON library and Hyprland ships none, so a small one: enough for
-- the file above, which Settings writes and a person may have edited.

local function decode(text)
    local pos = 1

    local function fail(what)
        error(("%s at character %d"):format(what, pos), 0)
    end

    local function skip()
        pos = text:find("[^ \t\r\n]", pos) or (#text + 1)
    end

    local function utf8char(cp)
        if cp < 0x80 then
            return string.char(cp)
        elseif cp < 0x800 then
            return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
        elseif cp < 0x10000 then
            return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
        end
        return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
            0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
    end

    local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

    local value

    local function str()
        pos = pos + 1
        local out = {}
        while true do
            local c = text:sub(pos, pos)
            if c == "" then
                fail("unterminated string")
            elseif c == '"' then
                pos = pos + 1
                return table.concat(out)
            elseif c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                if e == "u" then
                    local cp = tonumber(text:sub(pos + 2, pos + 5), 16) or fail("bad \\u escape")
                    pos = pos + 6
                    if cp >= 0xD800 and cp < 0xDC00 and text:sub(pos, pos + 1) == "\\u" then
                        local low = tonumber(text:sub(pos + 2, pos + 5), 16)
                        if low and low >= 0xDC00 and low < 0xE000 then
                            cp = 0x10000 + (cp - 0xD800) * 0x400 + (low - 0xDC00)
                            pos = pos + 6
                        end
                    end
                    out[#out + 1] = utf8char(cp)
                else
                    out[#out + 1] = escapes[e] or fail("bad escape")
                    pos = pos + 2
                end
            else
                local stop = text:find('["\\]', pos) or (#text + 1)
                out[#out + 1] = text:sub(pos, stop - 1)
                pos = stop
            end
        end
    end

    function value()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            while true do
                skip()
                if text:sub(pos, pos) ~= '"' then fail("expected a key") end
                local key = str()
                skip()
                if text:sub(pos, pos) ~= ":" then fail("expected ':'") end
                pos = pos + 1
                obj[key] = value()
                skip()
                local sep = text:sub(pos, pos)
                pos = pos + 1
                if sep == "}" then return obj end
                if sep ~= "," then fail("expected ',' or '}'") end
            end
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if text:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            while true do
                arr[#arr + 1] = value()
                skip()
                local sep = text:sub(pos, pos)
                pos = pos + 1
                if sep == "]" then return arr end
                if sep ~= "," then fail("expected ',' or ']'") end
            end
        elseif c == '"' then
            return str()
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not num or num == "" then fail("unexpected '" .. c .. "'") end
        pos = pos + #num
        return tonumber(num)
    end

    local result = value()
    skip()
    if pos <= #text then fail("trailing text") end
    return result
end

local function quote(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        if c == "\n" then return "\\n" end
        if c == "\t" then return "\\t" end
        return ("\\u%04x"):format(c:byte())
    end) .. '"'
end

-- Only what the manifest holds: strings, booleans, and arrays of strings.
local function encode(row)
    local parts = {}
    for _, key in ipairs(row.__order) do
        local v = row[key]
        local out
        if type(v) == "string" then
            out = quote(v)
        elseif type(v) == "boolean" then
            out = tostring(v)
        elseif type(v) == "table" then
            local items = {}
            for i, s in ipairs(v) do items[i] = quote(s) end
            out = "[" .. table.concat(items, ",") .. "]"
        end
        if out then parts[#parts + 1] = quote(key) .. ":" .. out end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- -------------------------------------------------------- your changes --

local user = { changed = {}, custom = {} }
local problems = {}

do
    local file = io.open(K.user_file, "r")
    if file then
        local text = file:read("*a") or ""
        file:close()
        local ok, data = pcall(decode, text)
        if not ok then
            problems[#problems + 1] = "keybinds.json is not valid JSON (" .. tostring(data) .. "); using the defaults"
        elseif type(data) == "table" then
            if type(data.changed) == "table" then user.changed = data.changed end
            if type(data.custom) == "table" then user.custom = data.custom end
        end
    end
end

-- What the manifest says, in the order binds.lua declares.
local rows = {}

-- `hl.bind`, but with an answer when Hyprland refuses the keys: a bad
-- combination in keybinds.json must cost that one bind, not the rest of
-- binds.lua after it.
local function try_bind(keys, dispatcher, opts, id)
    local ok, err = pcall(hl.bind, keys, dispatcher, opts)
    if not ok then
        problems[#problems + 1] = ("%s: Hyprland refused \"%s\" (%s)"):format(id, keys, tostring(err))
    end
    return ok
end

-- The options `hl.bind` knows, without the ones only this file does.
local function bind_opts(opts)
    local out = {}
    for k, v in pairs(opts or {}) do
        if k ~= "fixed" then out[k] = v end
    end
    return out
end

-- One of vela's binds, under a stable id.
--
--   K.bind("shell.launcher", "SUPER + SPACE", hl.dsp.exec_cmd(...), { description = "Shell: Launcher" })
--
-- `fixed = "why"` in the options keeps Settings from offering to change it
-- (alt + tab, whose release binds.lua watches for by keycode; the mouse).
function K.bind(id, keys, dispatcher, opts)
    opts = opts or {}
    local chosen = user.changed[id]
    if opts.fixed then chosen = nil end

    local now = keys
    if chosen == false then
        now = ""
    elseif type(chosen) == "string" and chosen ~= "" then
        now = chosen
    end

    rows[#rows + 1] = {
        __order = { "id", "default", "keys", "description", "fixed" },
        id = id,
        default = keys,
        keys = now,
        description = opts.description or "",
        fixed = opts.fixed,
    }

    if now ~= "" and not try_bind(now, dispatcher, bind_opts(opts), id) and now ~= keys then
        try_bind(keys, dispatcher, bind_opts(opts), id)
        rows[#rows].keys = keys
    end
end

-- A row of binds that differ only by their key, edited as one: super + 1 ...
-- super + 9. What Settings changes is the modifiers; `make(key)` gives each
-- key's dispatcher.
--
--   K.family("workspaces.go", "SUPER", { "1", "2", ... }, function(k) return ... end, { description = ... })
function K.family(id, mods, keys, make, opts)
    opts = opts or {}
    local chosen = user.changed[id]
    if opts.fixed then chosen = nil end

    local now = mods
    local off = chosen == false
    if type(chosen) == "string" and chosen ~= "" then
        now = chosen
    end

    rows[#rows + 1] = {
        __order = { "id", "default", "keys", "family", "description", "fixed" },
        id = id,
        default = mods,
        keys = off and "" or now,
        family = keys,
        description = opts.description or "",
        fixed = opts.fixed,
    }

    if off then return end
    local refused = false
    for _, key in ipairs(keys) do
        if not try_bind(now .. " + " .. key, make(key), bind_opts(opts), id) then
            refused = true
        end
    end
    -- Keys Hyprland would not take: back to the defaults, whole, rather
    -- than a family bound half one way and half the other.
    if refused and now ~= mods then
        rows[#rows].keys = mods
        for _, key in ipairs(keys) do
            try_bind(mods .. " + " .. key, make(key), bind_opts(opts), id)
        end
    end
end

-- Your own binds, from keybinds.json, then the manifest out to the shell.
-- Called once, at the end of binds.lua.
function K.finish()
    for i, c in ipairs(user.custom) do
        if type(c) == "table" and type(c.keys) == "string" and c.keys ~= "" and type(c.command) == "string" and c.command ~= "" then
            local name = (type(c.name) == "string" and c.name ~= "") and c.name or c.command
            try_bind(c.keys, hl.dsp.exec_cmd(c.command), { description = "Custom: " .. name }, "custom " .. i)
        end
    end

    if not K.manifest_file then return end
    -- Protected: hyprland.lua requires more after binds.lua, and a manifest
    -- that could not be written must not cost the autostart and the colours.
    -- Settings says so when it finds no list.
    pcall(function()
        local lines = {}
        for i, row in ipairs(rows) do lines[i] = "  " .. encode(row) end
        local problem_list = {}
        for i, p in ipairs(problems) do problem_list[i] = quote(p) end
        local text = '{\n "binds": [\n' .. table.concat(lines, ",\n") .. '\n ],\n "problems": [' ..
            table.concat(problem_list, ",") .. "]\n}\n"

        -- Written whole and moved into place, so the shell, which watches
        -- the file, never reads half of it.
        local tmp = K.manifest_file .. ".tmp"
        local file = io.open(tmp, "w")
        if file then
            file:write(text)
            file:close()
            os.rename(tmp, K.manifest_file)
        end
    end)
end

-- For checking the parser outside Hyprland.
K._decode = decode

return K
