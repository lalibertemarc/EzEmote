-- EzEmote palette (search, category rail, emote grid, options, custom editor) and the launcher icon.
local _, ns = ...

local PAD, GAP = 8, 6
local SEARCH_H = 22
local RAIL_W, ROW_H = 74, 20
local COLS, ROWS = 3, 10
local CELL_W = 84
local GRID_W, BODY_H = COLS * CELL_W, ROWS * ROW_H
local BODY_TOP = -(PAD + SEARCH_H + GAP)
local GRID_X = PAD + RAIL_W + GAP

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

local function Skin(f, alpha)
    f:SetBackdrop(FLAT)
    f:SetBackdropColor(0.05, 0.05, 0.06, alpha or 0.92)
    f:SetBackdropBorderColor(1, 1, 1, 0.08)
end
ns.Skin = Skin

local function Text(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
end

local function Hover(f, alpha)
    local hl = f:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, alpha or 0.08)
end

-- Flat button with a centered label.
local function TextButton(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 20)
    Skin(b, 0.6)
    Hover(b)
    b.text = Text(b)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    return b
end

-- Text box with grey placeholder text that shows while it's empty; inset leaves room for an icon.
local function SingleLineBox(parent, placeholder, inset)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetHeight(SEARCH_H)
    Skin(e, 0.5)
    e:SetFontObject("GameFontHighlight")
    e:SetTextInsets(inset or 6, 6, 0, 0)
    e:SetAutoFocus(false)
    e.placeholder = Text(e, "GameFontDisableSmall")
    e.placeholder:SetPoint("LEFT", (inset or 6) + 1, 0)
    e.placeholder:SetText(placeholder)
    e:SetScript("OnTextChanged", function(self) self.placeholder:SetShown(self:GetText() == "") end)
    return e
end

-- Lets frame be dragged (by its empty space) and remembers where it was left in EzEmoteDB[field].
local function Movable(frame, field)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        EzEmoteDB[field] = { point, relPoint, x, y }
    end)
end

-- Puts frame where EzEmoteDB[field] says, or at the default anchor.
local function Place(frame, field, ...)
    local p = EzEmoteDB[field]
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint(...)
    end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local palette = CreateFrame("Frame", "EzEmotePalette", UIParent, "BackdropTemplate")
palette:SetSize(GRID_X + GRID_W + PAD, PAD + SEARCH_H + GAP + BODY_H + PAD)
Skin(palette)
palette:SetFrameStrata("DIALOG")
palette:EnableMouse(true)
Movable(palette, "palettePos")
palette:Hide()
tinsert(UISpecialFrames, "EzEmotePalette") -- Esc closes it

local mode = "grid" -- "grid" | "options" | "editor"
local keys, offset = {}, 0 -- keys in the current grid view; first visible row
local Refresh, SetMode, OpenEditor -- defined below

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
local search = SingleLineBox(palette, "Search emotes", 23)
search:SetPoint("TOPLEFT", PAD, -PAD)
search:SetPoint("TOPRIGHT", -(PAD + SEARCH_H + 4), -PAD)

local glass = search:CreateTexture(nil, "OVERLAY")
glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
glass:SetSize(14, 14)
glass:SetPoint("LEFT", 6, -1)
glass:SetVertexColor(0.6, 0.6, 0.6)

local gear = CreateFrame("Button", nil, palette)
gear:SetSize(SEARCH_H, SEARCH_H)
gear:SetPoint("TOPRIGHT", -PAD, -PAD)
gear.tex = gear:CreateTexture(nil, "ARTWORK")
gear.tex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
gear.tex:SetSize(14, 14)
gear.tex:SetPoint("CENTER")
gear.tex:SetAlpha(0.6)
gear:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
gear:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.6) end)
gear:SetScript("OnClick", function() SetMode(mode == "options" and "grid" or "options") end)

local function Query()
    return strtrim(search:GetText()):lower()
end

-- The key that triggered this, with modifiers, as the bindings store it ("ALT-CTRL-SHIFT-X").
local function BindingFor(key)
    local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "")
    return GetBindingAction(mods .. key)
end

local firstKey -- key of the top result, fired by Enter

search:HookScript("OnTextChanged", function()
    if mode ~= "grid" then SetMode("grid") else Refresh() end
end)
search:SetScript("OnEnterPressed", function()
    if not firstKey then return end
    ns.Fire(firstKey)
    if not EzEmoteDB.keepOpen then palette:Hide() end
end)
search:SetScript("OnEscapePressed", function(self)
    if self:GetText() ~= "" then self:SetText("") else palette:Hide() end
end)
-- The palette key closes it again even while you're typing in the search box.
search:SetScript("OnKeyDown", function(_, key)
    if BindingFor(key) == "EZEMOTE_PALETTE" then palette:Hide() end
end)

---------------------------------------------------------------------------
-- Category rail
---------------------------------------------------------------------------
local rail = CreateFrame("Frame", nil, palette)
rail:SetPoint("TOPLEFT", PAD, BODY_TOP)
rail:SetSize(RAIL_W, BODY_H)

local divider = rail:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.06)
divider:SetWidth(1)
divider:SetPoint("TOPRIGHT", GAP / 2, 0)
divider:SetPoint("BOTTOMRIGHT", GAP / 2, 0)

local tabs = {}
for i, cat in ipairs(ns.CATEGORIES) do
    local b = CreateFrame("Button", nil, rail)
    b:SetSize(RAIL_W, ROW_H)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    Hover(b, 0.05)
    b.text = Text(b)
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetText(cat.label)
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(unpack(ns.COLORS.fav))
    b.bar:SetSize(2, 12)
    b.bar:SetPoint("LEFT")
    b:SetScript("OnClick", function()
        EzEmoteDB.tab = cat.key
        offset = 0
        search:SetText("")
        Refresh()
    end)
    tabs[cat.key] = b
end

---------------------------------------------------------------------------
-- Grid
---------------------------------------------------------------------------
local grid = CreateFrame("Frame", nil, palette)
grid:SetPoint("TOPLEFT", GRID_X, BODY_TOP)
grid:SetSize(GRID_W, BODY_H)
grid:EnableMouseWheel(true)

local empty = Text(grid, "GameFontDisableSmall")
empty:SetPoint("TOPLEFT", 8, -8)
empty:SetPoint("RIGHT", -8, 0)
empty:SetJustifyH("LEFT")

local thumb = grid:CreateTexture(nil, "OVERLAY")
thumb:SetColorTexture(1, 1, 1, 0.25)
thumb:SetWidth(2)

local cells = {}

local function Dot(cell, i)
    local d = cell:CreateTexture(nil, "ARTWORK")
    d:SetSize(4, 4)
    d:SetPoint("RIGHT", -4 - (i - 1) * 6, 0)
    return d
end

local function ShowCellTooltip(cell)
    local key = cell.key
    if not key then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    if key == "new" then
        GameTooltip:AddLine("New custom emote")
        GameTooltip:AddLine("Your own /e text, or a chain of emotes and lines.", 0.7, 0.7, 0.7, true)
        return GameTooltip:Show()
    end
    local kind, item = ns.Item(key)
    if kind == "e" then
        GameTooltip:AddLine("/" .. item.label)
        if item.anim then GameTooltip:AddLine("Animation", unpack(ns.COLORS.anim)) end
        if item.voice then GameTooltip:AddLine("Voice", unpack(ns.COLORS.voice)) end
    else
        GameTooltip:AddLine(item.name)
        for i, line in ipairs(item.lines) do
            if i > 6 then GameTooltip:AddLine("...", 0.6, 0.6, 0.6) break end
            GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
        end
    end
    local fav = ns.FavIndex(key)
    if fav and fav <= ns.WHEEL_SLOTS then GameTooltip:AddLine("Wheel slot " .. fav, unpack(ns.COLORS.fav)) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: emote   Shift-click: keep open", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(fav and "Right-click: remove from favorites" or "Right-click: add to favorites", 0.6, 0.6, 0.6)
    if kind == "c" then GameTooltip:AddLine("Ctrl-click: edit", 0.6, 0.6, 0.6) end
    if fav and EzEmoteDB.tab == "fav" and Query() == "" then
        GameTooltip:AddLine("Alt-click: move earlier", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function OnCellClick(cell, button)
    local key = cell.key
    if key == "new" then return OpenEditor() end
    if button == "RightButton" then
        ns.ToggleFav(key)
    elseif IsControlKeyDown() and key:sub(1, 1) == "c" then
        return OpenEditor(key:sub(3))
    elseif IsAltKeyDown() and EzEmoteDB.tab == "fav" and Query() == "" then
        ns.MoveFavUp(key)
    else
        ns.Fire(key)
        if not (EzEmoteDB.keepOpen or IsShiftKeyDown()) then return palette:Hide() end
    end
    Refresh()
end

for i = 1, COLS * ROWS do
    local c = CreateFrame("Button", nil, grid)
    c:SetSize(CELL_W - 2, ROW_H - 2)
    c:SetPoint("TOPLEFT", ((i - 1) % COLS) * CELL_W, -math.floor((i - 1) / COLS) * ROW_H)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Hover(c)
    c.text = Text(c)
    c.text:SetPoint("LEFT", 6, 0)
    c.text:SetPoint("RIGHT", -16, 0)
    c.text:SetJustifyH("LEFT")
    c.text:SetWordWrap(false)
    c.dots = { Dot(c, 1), Dot(c, 2) }
    c:SetScript("OnClick", OnCellClick)
    c:SetScript("OnEnter", ShowCellTooltip)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[i] = c
end

local function EmoteKeys(entries)
    local out = {}
    for _, e in ipairs(entries) do out[#out + 1] = "e:" .. e.token end
    return out
end

local function CategoryKeys(list)
    local out, seen = {}, {}
    for _, cmd in ipairs(list) do
        local e = ns.FindEmote(cmd)
        if e and not seen[e] then
            seen[e] = true
            out[#out + 1] = "e:" .. e.token
        end
    end
    return out
end

-- Custom items and emotes whose name contains q: exact match first, then names starting with it.
local function SearchKeys(q)
    local hits = {}
    local function Try(key, label)
        local lower = label:lower()
        local at = lower:find(q, 1, true)
        if at then
            hits[#hits + 1] = { key = key, label = lower, rank = (lower == q and 1) or (at == 1 and 2) or 3 }
        end
    end
    for _, c in ipairs(EzEmoteDB.custom) do Try("c:" .. c.id, c.name) end
    for _, e in ipairs(ns.sorted) do Try("e:" .. e.token, e.label) end
    table.sort(hits, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.label < b.label
    end)
    local out = {}
    for i, h in ipairs(hits) do out[i] = h.key end
    return out
end

local EMPTY = {
    fav = "Right-click any emote to add it to your favorites. The first eight fill the wheel.",
    recent = "Emotes you use show up here.",
    search = "No emote matches.",
}

local function ViewKeys()
    local q, tab = Query(), EzEmoteDB.tab
    if q ~= "" then return SearchKeys(q), EMPTY.search end
    if tab == "fav" then return ns.Existing(EzEmoteDB.favorites), EMPTY.fav end
    if tab == "recent" then return ns.Existing(EzEmoteDB.recent), EMPTY.recent end
    if tab == "all" then return EmoteKeys(ns.sorted) end
    if tab == "custom" then
        local out = {}
        for _, c in ipairs(EzEmoteDB.custom) do out[#out + 1] = "c:" .. c.id end
        out[#out + 1] = "new"
        return out
    end
    for _, cat in ipairs(ns.CATEGORIES) do
        if cat.key == tab then return CategoryKeys(cat.list or {}) end
    end
    return {}
end

local function MaxOffset()
    return math.max(0, math.ceil(#keys / COLS) - ROWS)
end

local function DrawCell(c, key)
    c.key = key
    c:SetShown(key ~= nil)
    if not key then return end
    for _, d in ipairs(c.dots) do d:Hide() end
    if key == "new" then
        c.text:SetText("+ New")
        c.text:SetTextColor(0.6, 0.6, 0.6)
        return
    end
    local kind, item = ns.Item(key)
    local marks = {}
    if kind == "e" then
        if item.anim then marks[#marks + 1] = ns.COLORS.anim end
        if item.voice then marks[#marks + 1] = ns.COLORS.voice end
    elseif #item.lines > 1 then
        marks[1] = ns.COLORS.chain
    end
    for i, color in ipairs(marks) do
        c.dots[i]:SetColorTexture(unpack(color))
        c.dots[i]:Show()
    end
    c.text:SetText(ns.Label(key))
    if ns.FavIndex(key) then
        c.text:SetTextColor(unpack(ns.COLORS.fav))
    else
        c.text:SetTextColor(0.9, 0.9, 0.9)
    end
end

function Refresh()
    if not palette:IsShown() or mode ~= "grid" then return end
    local emptyText
    keys, emptyText = ViewKeys()
    firstKey = keys[1] ~= "new" and keys[1] or nil
    offset = math.min(offset, MaxOffset())
    for i, c in ipairs(cells) do DrawCell(c, keys[offset * COLS + i]) end
    empty:SetText(emptyText or "")
    empty:SetShown(#keys == 0)

    local searching = Query() ~= ""
    for key, b in pairs(tabs) do
        local on = key == EzEmoteDB.tab and not searching
        b.bar:SetShown(on)
        if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.55, 0.55, 0.55) end
    end

    local rows = math.ceil(#keys / COLS)
    thumb:SetShown(rows > ROWS)
    if rows > ROWS then
        thumb:SetHeight(BODY_H * ROWS / rows)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", grid, "TOPRIGHT", PAD / 2 + 1, -BODY_H * offset / rows)
    end
    for _, c in ipairs(cells) do
        if c:IsMouseOver() and c:IsShown() then ShowCellTooltip(c) end
    end
end
ns.OnChanged = Refresh

grid:SetScript("OnMouseWheel", function(_, delta)
    offset = math.max(0, math.min(MaxOffset(), offset - delta * 2))
    Refresh()
end)

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
local options = CreateFrame("Frame", nil, palette)
options:SetPoint("TOPLEFT", PAD + 4, BODY_TOP - 4)
options:SetPoint("BOTTOMRIGHT", -PAD, PAD)
options:Hide()

local checks = {}

local function Check(label, get, set)
    local b = CreateFrame("Button", nil, options)
    b:SetSize(GRID_W, 20)
    b:SetPoint("TOPLEFT", 0, -#checks * 22)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetSize(12, 12)
    b.box:SetPoint("LEFT")
    Skin(b.box, 0.5)
    b.fill = b.box:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT", 3, -3)
    b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    b.fill:SetColorTexture(unpack(ns.COLORS.fav))
    b.text = Text(b)
    b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.text:SetText(label)
    b.Update = function() b.fill:SetShown(get()) end
    b:SetScript("OnClick", function()
        set(not get())
        b.Update()
    end)
    checks[#checks + 1] = b
end

Check("Show the launcher icon",
    function() return not EzEmoteDB.hideIcon end,
    function(v) EzEmoteDB.hideIcon = not v; ns.UpdateIcon() end)
Check("Keep the palette open after an emote",
    function() return EzEmoteDB.keepOpen end,
    function(v) EzEmoteDB.keepOpen = v end)
Check("Type to search as soon as it opens",
    function() return EzEmoteDB.focusSearch end,
    function(v) EzEmoteDB.focusSearch = v end)

local delayLabel = Text(options)
delayLabel:SetPoint("TOPLEFT", 0, -#checks * 22 - 6)

local function UpdateDelay()
    delayLabel:SetText(format("Pause between chain steps: %.1f s", EzEmoteDB.stepDelay))
end

local function Stepper(label, delta, x)
    local b = TextButton(options, label, 20)
    b:SetPoint("LEFT", delayLabel, "RIGHT", x, 0)
    b:SetScript("OnClick", function()
        EzEmoteDB.stepDelay = math.max(0.5, math.min(10, EzEmoteDB.stepDelay + delta))
        UpdateDelay()
    end)
end
Stepper("-", -0.5, 10)
Stepper("+", 0.5, 34)

local notes = Text(options, "GameFontDisableSmall")
notes:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -16)
notes:SetWidth(GRID_W + RAIL_W - 8)
notes:SetJustifyH("LEFT")
notes:SetSpacing(3)
notes:SetText("Key bindings: Options > Keybindings > EzEmote.\n"
    .. "The wheel shows your first eight favorites. Alt-click a favorite to move it earlier.\n"
    .. "Markers: green = animation, blue = voice, purple = chain.\n"
    .. "/eze <name> does an emote or custom item, handy in macros.")

local back = TextButton(options, "Back", 60)
back:SetPoint("BOTTOMRIGHT")
back:SetScript("OnClick", function() SetMode("grid") end)

---------------------------------------------------------------------------
-- Custom item editor
---------------------------------------------------------------------------
local editor = CreateFrame("Frame", nil, palette)
editor:SetPoint("TOPLEFT", PAD, BODY_TOP)
editor:SetPoint("BOTTOMRIGHT", -PAD, PAD)
editor:Hide()

local editingId -- id of the custom item being edited, nil for a new one

local nameBox = SingleLineBox(editor, "Name, e.g. arrive")
nameBox:SetPoint("TOPLEFT", 0, 0)
nameBox:SetPoint("TOPRIGHT", 0, 0)
nameBox:SetMaxLetters(40)

local stepsFrame = CreateFrame("Frame", nil, editor, "BackdropTemplate")
stepsFrame:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -GAP)
stepsFrame:SetPoint("TOPRIGHT", nameBox, "BOTTOMRIGHT", 0, -GAP)
stepsFrame:SetHeight(104)
stepsFrame:SetClipsChildren(true)
Skin(stepsFrame, 0.5)

local stepsBox = CreateFrame("EditBox", nil, stepsFrame)
stepsBox:SetPoint("TOPLEFT", 6, -5)
stepsBox:SetPoint("TOPRIGHT", -6, -5)
stepsBox:SetHeight(94)
stepsBox:SetMultiLine(true)
stepsBox:SetAutoFocus(false)
stepsBox:SetFontObject("GameFontHighlightSmall")
stepsBox:SetMaxLetters(1000)
stepsFrame:EnableMouse(true)
stepsFrame:SetScript("OnMouseDown", function() stepsBox:SetFocus() end)

local hint = Text(editor, "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", stepsFrame, "BOTTOMLEFT", 0, -GAP)
hint:SetPoint("RIGHT", editor, "RIGHT")
hint:SetJustifyH("LEFT")
hint:SetSpacing(2)

local HINT = "One step per line: an emote (/bow), text for /e (looks around.), or wait 3. "
    .. "%t is your target's name. Text lines go out as soon as you press; emotes keep their timing."

local function ShowHint(err)
    hint:SetText(err or HINT)
    if err then hint:SetTextColor(1, 0.35, 0.35) else hint:SetTextColor(0.5, 0.5, 0.5) end
end

local function Lines()
    local out = {}
    for line in (stepsBox:GetText() .. "\n"):gmatch("(.-)\r?\n") do
        line = strtrim(line)
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

local save = TextButton(editor, "Save", 60)
save:SetPoint("BOTTOMRIGHT")
local cancel = TextButton(editor, "Cancel", 60)
cancel:SetPoint("RIGHT", save, "LEFT", -GAP, 0)
local delete = TextButton(editor, "Delete", 60)
delete:SetPoint("BOTTOMLEFT")

save:SetScript("OnClick", function()
    local name, lines = strtrim(nameBox:GetText()), Lines()
    if name == "" then return ShowHint("Give it a name.") end
    if #lines == 0 then return ShowHint("Add at least one line.") end
    for _, line in ipairs(lines) do
        local step = ns.ParseLine(line)
        if step and step.bad then return ShowHint(step.bad .. " isn't an emote. Use /e for text.") end
    end
    ns.SaveCustom(editingId, name, lines)
    EzEmoteDB.tab = "custom"
    SetMode("grid")
end)
cancel:SetScript("OnClick", function() SetMode("grid") end)
-- Two clicks to delete, so a stray one can't lose a chain.
delete:SetScript("OnClick", function(self)
    if not self.armed then
        self.armed = true
        self.text:SetText("Sure?")
        self.text:SetTextColor(1, 0.35, 0.35)
        return
    end
    ns.DeleteCustom(editingId)
    SetMode("grid")
end)

for _, box in ipairs({ nameBox, stepsBox }) do
    box:SetScript("OnEscapePressed", function() SetMode("grid") end)
end
nameBox:SetScript("OnTabPressed", function() stepsBox:SetFocus() end)
nameBox:SetScript("OnEnterPressed", function() stepsBox:SetFocus() end)
stepsBox:SetScript("OnTabPressed", function() nameBox:SetFocus() end)

-- Opens the editor on custom item id, or on a blank one.
function OpenEditor(id)
    local c = id and ns.Custom(id)
    editingId = c and c.id
    nameBox:SetText(c and c.name or "")
    stepsBox:SetText(c and table.concat(c.lines, "\n") or "")
    delete:SetShown(c ~= nil)
    delete.armed = nil
    delete.text:SetText("Delete")
    delete.text:SetTextColor(1, 1, 1)
    ShowHint()
    SetMode("editor")
    nameBox:SetFocus()
end

---------------------------------------------------------------------------
-- Modes, open/close
---------------------------------------------------------------------------
function SetMode(m)
    mode = m
    rail:SetShown(m == "grid")
    grid:SetShown(m == "grid")
    options:SetShown(m == "options")
    editor:SetShown(m == "editor")
    gear.tex:SetVertexColor(1, 1, 1)
    if m == "options" then
        gear.tex:SetVertexColor(unpack(ns.COLORS.fav))
        for _, b in ipairs(checks) do b.Update() end
        UpdateDelay()
    end
    if m ~= "editor" then
        nameBox:ClearFocus()
        stepsBox:ClearFocus()
    end
    GameTooltip:Hide()
    Refresh()
end

palette:SetScript("OnShow", function()
    offset = 0
    SetMode("grid")
    -- Next frame, so the key that opened the palette isn't typed into the search box.
    if EzEmoteDB.focusSearch then
        C_Timer.After(0, function()
            if palette:IsShown() and mode == "grid" then search:SetFocus() end
        end)
    end
end)
palette:SetScript("OnHide", function()
    search:SetText("")
    search:ClearFocus()
    nameBox:ClearFocus()
    stepsBox:ClearFocus()
    GameTooltip:Hide()
end)

function ns.TogglePalette(startMode)
    if palette:IsShown() and not startMode then return palette:Hide() end
    palette:Show()
    if startMode then SetMode(startMode) end
end

function EzEmote_TogglePalette()
    ns.TogglePalette()
end

---------------------------------------------------------------------------
-- Launcher icon
---------------------------------------------------------------------------
local icon = CreateFrame("Button", "EzEmoteIcon", UIParent, "BackdropTemplate")
icon:SetSize(24, 24)
icon:SetFrameStrata("MEDIUM")
Movable(icon, "iconPos")
icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
icon:SetBackdrop(FLAT)
icon:SetBackdropColor(0, 0, 0, 0.6)
icon:SetBackdropBorderColor(0, 0, 0, 1)
icon:SetAlpha(0.7)
icon.tex = icon:CreateTexture(nil, "ARTWORK")
icon.tex:SetPoint("TOPLEFT", 1, -1)
icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
icon.tex:SetTexture(ns.ICON)
icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

icon:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        ns.TogglePalette(not (palette:IsShown() and mode == "options") and "options" or nil)
    else
        ns.TogglePalette()
    end
end)
icon:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("EzEmote")
    GameTooltip:AddLine("Click: emote palette", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: options", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: move", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
icon:SetScript("OnLeave", function(self)
    self:SetAlpha(0.7)
    GameTooltip:Hide()
end)

function ns.UpdateIcon()
    icon:SetShown(not EzEmoteDB.hideIcon)
end

-- Saved positions, or next to the main chat window.
function ns.ApplyPositions()
    Place(icon, "iconPos", "BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 28)
    Place(palette, "palettePos", "BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 40)
end
