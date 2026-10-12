-- EzEmote: every emote, your own /e lines and emote chains, one keypress away.
local _, ns = ...

BINDING_HEADER_EZEMOTE = "EzEmote"
BINDING_NAME_EZEMOTE_PALETTE = "Open the emote palette"
BINDING_NAME_EZEMOTE_WHEEL = "Emote wheel (hold, release on an emote)"

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

-- Moves a favorite one place earlier (the first eight fill the wheel, in order).
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

local chainTimer

function ns.StopChain()
    if chainTimer then
        chainTimer:Cancel()
        chainTimer = nil
    end
end

local function Perform(step)
    if step.bad then
        Print("Not an emote: " .. step.bad)
    elseif step.token then
        PerformEmote(step.token, step.target)
    else
        -- %t is your target's name, like in macros.
        SendEmoteText((step.text:gsub("%%t", function() return TargetName() or "someone" end)))
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

local function Schedule(steps, i, delay)
    chainTimer = nil
    if not steps[i] then return end
    if delay and delay > 0 then
        chainTimer = C_Timer.NewTimer(delay, function() RunStep(steps, i) end)
    else
        RunStep(steps, i)
    end
end

function RunStep(steps, i)
    chainTimer = nil
    if ChatLocked() then return Print("The game blocks emotes right now. Chain stopped.") end
    Perform(steps[i])
    local j, wait = NextAction(steps, i + 1)
    Schedule(steps, j, wait or EzEmoteDB.stepDelay)
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
        ns.StopChain()
        local steps = {}
        for _, line in ipairs(item.lines) do
            steps[#steps + 1] = ns.ParseLine(line)
        end
        local i, wait = NextAction(steps, 1)
        Schedule(steps, i, wait)
    else
        return
    end
    PushRecent(key)
    if ns.OnFired then ns.OnFired() end
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
    Remove(EzEmoteDB.favorites, "c:" .. id)
    Remove(EzEmoteDB.recent, "c:" .. id)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/eze - open or close the palette",
    "/eze <name> - do an emote or one of your custom items (for macros)",
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
    icon  = function()
        EzEmoteDB.hideIcon = not EzEmoteDB.hideIcon
        ns.UpdateIcon()
        Print(EzEmoteDB.hideIcon and "Icon hidden. Use the key binding or /eze." or "Icon shown.")
    end,
    stop  = function() ns.StopChain() end,
    reset = function()
        EzEmoteDB.iconPos, EzEmoteDB.palettePos = nil, nil
        ns.ApplyPositions()
        Print("Positions reset.")
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
    ns.ApplyPositions()
    ns.UpdateIcon()
end)
