-- EzEmote wheels: hold a wheel's key, point toward an emote, release to do it.
local _, ns = ...

local RADIUS = 92 -- vertical; the wheel widens for more slots
local SLOT_W, SLOT_H = 84, 22
local DEADZONE = 22 -- cursor this close to the center selects nothing

local wheel = CreateFrame("Frame", "EzEmoteWheel", UIParent)
wheel:SetFrameStrata("FULLSCREEN_DIALOG")
wheel:SetClampedToScreen(true)
wheel:Hide()

local hub = wheel:CreateTexture(nil, "ARTWORK")
hub:SetSize(6, 6)
hub:SetPoint("CENTER")
hub:SetColorTexture(1, 1, 1, 0.5)

local title = wheel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
title:SetPoint("BOTTOM", hub, "TOP", 0, 8)

local hint = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOP", hub, "BOTTOM", 0, -10)
hint:SetWidth(200)

local slots, keys, angles = {}, {}, {}
local open, size, selected -- open wheel, its slot count, selected slot

local function Highlight(i)
    local r, g, b = unpack(ns.COLORS.fav)
    for j, s in ipairs(slots) do
        local on = j == i
        s:SetBackdropColor(0.05, 0.05, 0.06, on and 0.98 or 0.85)
        s:SetBackdropBorderColor(r, g, b, on and 0.9 or 0)
        if on then s.text:SetTextColor(r, g, b) else s.text:SetTextColor(0.9, 0.9, 0.9) end
    end
    selected = i
end

local function Release()
    local key = selected and keys[selected]
    wheel:Hide()
    open = nil
    if key then ns.Fire(key) end
end

for i = 1, ns.MAX_SLOTS do
    local s = CreateFrame("Button", nil, wheel, "BackdropTemplate")
    s:SetSize(SLOT_W, SLOT_H)
    ns.Skin(s)
    s.text = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.text:SetPoint("LEFT", 4, 0)
    s.text:SetPoint("RIGHT", -4, 0)
    s.text:SetWordWrap(false)
    -- Clicking a slot works too, for anyone who'd rather click than release.
    s:SetScript("OnClick", function() Highlight(i); Release() end)
    slots[i] = s
end

local function AngleGap(a, b)
    local d = math.abs(a - b) % (2 * math.pi)
    return math.min(d, 2 * math.pi - d)
end

wheel:SetScript("OnUpdate", function(self)
    local cx, cy = self:GetCenter()
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local dx, dy = x / scale - cx, y / scale - cy
    -- Each slot owns its direction; pointing at an empty one selects nothing.
    local best
    if dx * dx + dy * dy >= DEADZONE * DEADZONE then
        local a = math.atan2(dy, dx)
        for i = 1, size do
            if not best or AngleGap(a, angles[i]) < AngleGap(a, angles[best]) then best = i end
        end
        if not keys[best] then best = nil end
    end
    if best ~= selected then Highlight(best) end
end)

local function Open(w)
    local data = EzEmoteDB.wheels[w]
    size = data.size
    local pos = ns.WheelLayout(size, SLOT_W, SLOT_H, RADIUS)
    local width = 0
    keys = {}
    for i, s in ipairs(slots) do
        local key = i <= size and data.slots[i]
        if key and ns.Item(key) then keys[i] = key end
        s:SetShown(keys[i] ~= nil)
        if pos[i] then
            s:ClearAllPoints()
            s:SetPoint("CENTER", wheel, "CENTER", pos[i][1], pos[i][2])
            angles[i] = math.atan2(pos[i][2], pos[i][1])
            width = math.max(width, math.abs(pos[i][1]))
        end
        if keys[i] then s.text:SetText(ns.Label(key)) end
    end
    wheel:SetSize(2 * width + SLOT_W, 2 * RADIUS + SLOT_H)
    title:SetText(data.name)
    hint:SetText(next(keys) and "" or "This wheel is empty. Set it up with /eze wheels.")
    Highlight(nil)

    local x, y = GetCursorPosition()
    local scale = wheel:GetEffectiveScale()
    wheel:ClearAllPoints()
    wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    open = w
    wheel:Show()
end

-- Key bindings (Bindings.xml, runOnUp): pressed opens wheel w, released does the selected slot.
function EzEmote_Wheel(keystate, w)
    w = w or 1
    if keystate == "down" then
        Open(w)
    elseif open == w then
        Release()
    end
end
