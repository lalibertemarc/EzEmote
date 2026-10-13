-- EzEmote: every emote, your own /e lines and emote chains, one keypress away.
local _, ns = ...

BINDING_HEADER_EZEMOTE = "EzEmote"
BINDING_NAME_EZEMOTE_PALETTE = "Open the emote palette"

-- Binding action of wheel w (Bindings.xml); wheel 1 keeps the name it had before there were several.
function ns.WheelBinding(w)
    return w == 1 and "EZEMOTE_WHEEL" or "EZEMOTE_WHEEL" .. w
end

-- Names the wheel bindings after your wheels, so Options > Keybindings shows "Emote wheel 2: Mood".
function ns.UpdateBindingNames()
    for w = 1, ns.WHEEL_COUNT do
        local wheel = EzEmoteDB and EzEmoteDB.wheels and EzEmoteDB.wheels[w] or ns.DEFAULT_WHEELS[w]
        _G["BINDING_NAME_" .. ns.WheelBinding(w)] = format("Emote wheel %d: %s", w, wheel.name)
    end
end
ns.UpdateBindingNames()

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffb84dEzEmote|r: " .. msg)
end

local issecret = issecretvalue or function() return false end

---------------------------------------------------------------------------
-- API compat (C_ChatInfo first, old globals as fallback)
---------------------------------------------------------------------------
local function PerformEmote(token, target)
    if C_ChatInfo and C_ChatInfo.PerformEmote then
        C_ChatInfo.PerformEmote(token, target)
    else
        DoEmote(token, target)
    end
end

local function SendEmoteText(text)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(text, "EMOTE")
    else
        SendChatMessage(text, "EMOTE")
    end
end

-- Encounters and similar lock addon chat and emotes; sending then would be blocked.
local function ChatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function TargetName()
    local name = UnitExists("target") and UnitName("target")
    if name and not issecret(name) then return name end
end

-- The subzone you stand in ("Goldshire"), or the zone when there is none ("Elwynn Forest").
local function Location()
    local sub = GetSubZoneText()
    if sub and sub ~= "" then return sub end
    local zone = GetZoneText()
    if zone and zone ~= "" then return zone end
end

---------------------------------------------------------------------------
-- Emote catalog, read from the client's own emote strings
---------------------------------------------------------------------------
ns.emotes = {}   -- token -> { token, label, anim, voice }
ns.sorted = {}   -- the same entries, sorted by label
local byCmd = {} -- slash command or alias, lowercase without "/" -> entry

local function Command(s)
    return (s:gsub("^/", ""):lower())
end

-- Faction emotes only work for your own faction.
local OTHER_FACTION = { Alliance = "FORTHEHORDE", Horde = "FORTHEALLIANCE" }

local function BuildCatalog()
    wipe(ns.emotes)
    wipe(ns.sorted)
    wipe(byCmd)
    local anim, voice = {}, {}
    for _, t in ipairs(EmoteList or {}) do anim[t] = true end
    for _, t in ipairs(ns.EXTRA_ANIM) do anim[t] = true end
    for _, t in ipairs(TextEmoteSpeechList or {}) do voice[t] = true end
    local skip = OTHER_FACTION[UnitFactionGroup("player") or ""]

    -- Indices aren't contiguous, so walk the whole range.
    for i = 1, MAXEMOTEINDEX or 700 do
        local token, cmd = _G["EMOTE" .. i .. "_TOKEN"], _G["EMOTE" .. i .. "_CMD1"]
        if token and cmd and token ~= skip then
            local e = ns.emotes[token]
            if not e then
                e = { token = token, label = Command(cmd), anim = anim[token], voice = voice[token] }
                ns.emotes[token] = e
                ns.sorted[#ns.sorted + 1] = e
            end
            local j = 1
            while _G["EMOTE" .. i .. "_CMD" .. j] do
                local alias = Command(_G["EMOTE" .. i .. "_CMD" .. j])
                byCmd[alias] = byCmd[alias] or e
                j = j + 1
            end
        end
    end
    table.sort(ns.sorted, function(a, b) return a.label < b.label end)
end

-- Emote entry for a slash command, alias or token ("wave", "/wave", "WAVE").
function ns.FindEmote(name)
    return byCmd[Command(name)] or ns.emotes[name:upper()]
end

---------------------------------------------------------------------------
-- Items: "e:TOKEN" is a game emote, "c:ID" one of your custom lines or chains
---------------------------------------------------------------------------
function ns.Custom(id)
    for i, c in ipairs(EzEmoteDB.custom) do
        if tostring(c.id) == tostring(id) then return c, i end
    end
end

-- Kind ("e" or "c") and the emote entry or custom item for a key; nil if it no longer exists.
function ns.Item(key)
    local kind, id = key:match("^(%a):(.+)$")
    if kind == "e" then
        local e = ns.emotes[id]
        if e then return "e", e end
    elseif kind == "c" then
        local c = ns.Custom(id)
        if c then return "c", c end
    end
end

function ns.Label(key)
    local kind, item = ns.Item(key)
    if kind == "e" then return item.label end
    if kind == "c" then return item.name end
end

function ns.FavIndex(key)
    for i, k in ipairs(EzEmoteDB.favorites) do
        if k == key then return i end
    end
end

function ns.ToggleFav(key)
    local i = ns.FavIndex(key)
    if i then
        table.remove(EzEmoteDB.favorites, i)
    else
        table.insert(EzEmoteDB.favorites, key)
    end
end

-- Moves a favorite one place earlier.
function ns.MoveFavUp(key)
    local f, i = EzEmoteDB.favorites, ns.FavIndex(key)
    if i and i > 1 then f[i], f[i - 1] = f[i - 1], f[i] end
end

-- Keys from list that still exist (emotes your client has, custom items you haven't deleted).
function ns.Existing(list)
    local out = {}
    for _, key in ipairs(list) do
        if ns.Item(key) then out[#out + 1] = key end
    end
    return out
end

local function Remove(list, key)
    for i = #list, 1, -1 do
        if list[i] == key then table.remove(list, i) end
    end
end

local function PushRecent(key)
    local r = EzEmoteDB.recent
    Remove(r, key)
    table.insert(r, 1, key)
    for i = #r, ns.MAX_RECENT + 1, -1 do r[i] = nil end
end

---------------------------------------------------------------------------
-- Wheels: EzEmoteDB.wheels[w] = { name, size, slots = { [1..MAX_SLOTS] = key or nil } }.
-- Slots past size are hidden but kept, so growing the wheel again brings them back.
---------------------------------------------------------------------------
-- "Main 3, Mood 1" for the wheel slots holding key; nil if it's on none.
function ns.WheelSpots(key)
    local spots = {}
    for _, wheel in ipairs(EzEmoteDB.wheels) do
        for i = 1, wheel.size do
            if wheel.slots[i] == key then spots[#spots + 1] = wheel.name .. " " .. i end
        end
    end
    return #spots > 0 and table.concat(spots, ", ") or nil
end

function ns.SwapSlots(w, a, b)
    local slots = EzEmoteDB.wheels[w].slots
    slots[a], slots[b] = slots[b], slots[a]
end

function ns.RenameWheel(w, name)
    EzEmoteDB.wheels[w].name = name
    ns.UpdateBindingNames()
end

function ns.ResizeWheel(w, delta)
    local wheel = EzEmoteDB.wheels[w]
    wheel.size = math.max(ns.MIN_SLOTS, math.min(ns.MAX_SLOTS, wheel.size + delta))
end

-- Slot centers of an n-slot wheel, clockwise from the top, on an ellipse ry tall and just wide
-- enough that no two w x h slots touch. Returns { { x, y }, ... }.
function ns.WheelLayout(n, w, h, ry)
    local pos = {}
    local function Fits(rx)
        for i = 1, n do
            local a = math.pi / 2 - (i - 1) * 2 * math.pi / n
            pos[i] = { math.cos(a) * rx, math.sin(a) * ry }
        end
        for i = 1, n do
            for j = i + 1, n do
                if math.abs(pos[i][1] - pos[j][1]) < w + 4 and math.abs(pos[i][2] - pos[j][2]) < h + 4 then
                    return false
                end
            end
        end
        return true
    end
    local rx = ry
    while not Fits(rx) and rx < 400 do rx = rx + 2 end
    return pos
end

---------------------------------------------------------------------------
-- Chains
---------------------------------------------------------------------------
-- One line of a custom item -> step: { wait = s } | { token, target } | { text } | { bad }, or nil if blank.
function ns.ParseLine(line)
    line = strtrim(line)
    if line == "" then return nil end
    local secs = line:lower():match("^wait%s+(%d+%.?%d*)$")
    if secs then return { wait = tonumber(secs) } end
    local cmd, rest = line:match("^/(%S+)%s*(.*)$")
    if not cmd then return { text = line } end
    cmd = cmd:lower()
    if ns.TEXT_COMMANDS[cmd] then return rest ~= "" and { text = rest } or nil end
    local e = byCmd[cmd]
    if e then return { token = e.token, target = rest ~= "" and rest or nil } end
    return { bad = line }
end

-- First text line written after a wait or a timed emote. Text can't be delayed (see RunCustom),
-- so such a line goes out on the press, earlier than written. nil when the order is honest.
function ns.EarlyText(lines)
    local actions, delayed = 0, false
    for _, line in ipairs(lines) do
        local step = ns.ParseLine(line)
        if step and step.wait then
            delayed = true
        elseif step and step.text then
            if delayed then return step.text end
            actions = actions + 1
        elseif step then
            if actions > 0 then delayed = true end
            actions = actions + 1
        end
    end
end

-- The running chain: { steps, timer } with the steps still to come on their timing.
local chain

function ns.StopChain()
    if chain and chain.timer then chain.timer:Cancel() end
    chain = nil
end

local function Perform(step)
    if step.bad then
        Print("Not an emote: " .. step.bad)
    elseif step.token then
        PerformEmote(step.token, step.target)
    else
        -- %t is your target's name, like in macros; %l is where you stand.
        local text = step.text:gsub("%%t", function() return TargetName() or "someone" end)
        SendEmoteText((text:gsub("%%l", function() return Location() or "somewhere" end)))
    end
end

-- Index of the next action from i on, and the seconds of wait lines passed on the way (nil if none).
local function NextAction(steps, i)
    local wait
    while steps[i] and steps[i].wait do
        wait = (wait or 0) + steps[i].wait
        i = i + 1
    end
    return i, wait
end

local RunStep

local function Schedule(i, delay)
    if not chain.steps[i] then
        chain = nil
        return
    end
    if delay and delay > 0 then
        local c = chain
        c.timer = C_Timer.NewTimer(delay, function()
            if chain == c then RunStep(i) end
        end)
    else
        RunStep(i)
    end
end

function RunStep(i)
    chain.timer = nil
    if ChatLocked() then
        Print("The game blocks emotes right now. Chain stopped.")
        return ns.StopChain()
    end
    Perform(chain.steps[i])
    local j, wait = NextAction(chain.steps, i + 1)
    Schedule(j, wait or EzEmoteDB.stepDelay)
end

-- The game only lets addons send chat text from a click or key press, never from a timer, so
-- the first step and every text line go out now; the remaining emotes keep their timing.
local function RunCustom(item)
    ns.StopChain()
    local steps = {}
    for _, line in ipairs(item.lines) do
        steps[#steps + 1] = ns.ParseLine(line)
    end
    local first, lead = NextAction(steps, 1)
    local started = not lead and steps[first] ~= nil
    local timed = {}
    for i, step in ipairs(steps) do
        if step.text or (started and i == first) then
            Perform(step)
        else
            timed[#timed + 1] = step
        end
    end
    chain = { steps = timed }
    local i, wait = NextAction(timed, 1)
    Schedule(i, started and (wait or EzEmoteDB.stepDelay) or wait)
end

---------------------------------------------------------------------------
-- Firing
---------------------------------------------------------------------------
function ns.Fire(key)
    if ChatLocked() then return Print("The game blocks emotes right now.") end
    local kind, item = ns.Item(key)
    if kind == "e" then
        -- With no target name the game aims the emote at your target, as /wave does.
        PerformEmote(item.token)
    elseif kind == "c" then
        RunCustom(item)
    else
        return
    end
    PushRecent(key)
    if ns.OnChanged then ns.OnChanged() end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local DEFAULTS = { stepDelay = 2, focusSearch = true, keepOpen = false, hideIcon = false, tab = "fav" }

local function InitDB()
    EzEmoteDB = EzEmoteDB or {}
    local db = EzEmoteDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    db.recent = db.recent or {}
    if not db.custom then
        db.custom, db.nextId = {}, 1
        for _, c in ipairs(ns.DEFAULT_CUSTOM) do
            db.custom[#db.custom + 1] = { id = db.nextId, name = c.name, lines = { unpack(c.lines) } }
            db.nextId = db.nextId + 1
        end
    end
    db.nextId = db.nextId or #db.custom + 1
    if not db.favorites then
        db.favorites = {}
        for _, cmd in ipairs(ns.DEFAULT_FAVORITES) do
            local e = ns.FindEmote(cmd)
            if e then db.favorites[#db.favorites + 1] = "e:" .. e.token end
        end
    end
    -- Before v1.1 the only wheel showed your first favorites, so wheel 1 starts with them.
    db.wheels = db.wheels or {}
    for w, def in ipairs(ns.DEFAULT_WHEELS) do
        if not db.wheels[w] then
            local slots = {}
            for _, cmd in ipairs(def.list or {}) do
                local e = ns.FindEmote(cmd)
                if e then slots[#slots + 1] = "e:" .. e.token end
            end
            if not def.list then
                for i, key in ipairs(ns.Existing(db.favorites)) do
                    if i <= ns.DEFAULT_SLOTS then slots[i] = key end
                end
            end
            db.wheels[w] = { name = def.name, slots = slots }
        end
        db.wheels[w].size = db.wheels[w].size or ns.DEFAULT_SLOTS
    end
end

-- Saves a custom item; a new one when id is nil.
function ns.SaveCustom(id, name, lines)
    local c = id and ns.Custom(id)
    if not c then
        c = { id = EzEmoteDB.nextId }
        EzEmoteDB.nextId = EzEmoteDB.nextId + 1
        table.insert(EzEmoteDB.custom, c)
    end
    c.name, c.lines = name, lines
end

function ns.DeleteCustom(id)
    local _, i = ns.Custom(id)
    if not i then return end
    table.remove(EzEmoteDB.custom, i)
    local key = "c:" .. id
    Remove(EzEmoteDB.favorites, key)
    Remove(EzEmoteDB.recent, key)
    for _, wheel in ipairs(EzEmoteDB.wheels) do
        for s = 1, ns.MAX_SLOTS do
            if wheel.slots[s] == key then wheel.slots[s] = nil end
        end
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/eze - open or close the palette",
    "/eze <name> - do an emote or one of your custom items (for macros)",
    "/eze wheels - set up your four emote wheels",
    "/eze icon - show or hide the launcher icon",
    "/eze stop - stop a running chain",
    "/eze reset - reset the icon and palette positions",
    "Key bindings: Options > Keybindings > EzEmote",
}

-- Custom item by name (case-insensitive), else game emote by command.
local function FindByName(name)
    local lower = name:lower()
    for _, c in ipairs(EzEmoteDB.custom) do
        if c.name:lower() == lower then return "c:" .. c.id end
    end
    local e = ns.FindEmote(name)
    return e and "e:" .. e.token
end

local COMMANDS = {
    [""]  = function() ns.TogglePalette() end,
    wheels = function() ns.TogglePalette("wheels") end,
    icon  = function()
        EzEmoteDB.hideIcon = not EzEmoteDB.hideIcon
        ns.UpdateIcon()
        Print(EzEmoteDB.hideIcon and "Icon hidden. Use the key binding or /eze." or "Icon shown.")
    end,
    stop  = function() ns.StopChain() end,
    reset = function()
        EzEmoteDB.iconPos, EzEmoteDB.palettePos, EzEmoteDB.paletteSize = nil, nil, nil
        ns.ApplyPositions()
        Print("Positions and palette size reset.")
    end,
    help  = function()
        for _, line in ipairs(HELP) do Print(line) end
    end,
}

SLASH_EZEMOTE1 = "/eze"
SLASH_EZEMOTE2 = "/ezemote"
SlashCmdList.EZEMOTE = function(msg)
    msg = strtrim(msg)
    local fn = COMMANDS[msg:lower()]
    if fn then return fn() end
    local key = FindByName(msg)
    if key then return ns.Fire(key) end
    Print("No emote or custom item called \"" .. msg .. "\".")
    COMMANDS.help()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    BuildCatalog()
    InitDB()
    ns.UpdateBindingNames()
    ns.ApplyPositions()
    ns.UpdateIcon()
end)
