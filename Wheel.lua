-- EzEmote wheel: hold the key, point toward a favorite, release to emote.
local _, ns = ...

local RADIUS = 92
local SLOT_W, SLOT_H = 84, 22
local DEADZONE = 22 -- cursor this close to the center selects nothing

local wheel = CreateFrame("Frame", "EzEmoteWheel", UIParent)
wheel:SetSize(2 * RADIUS + SLOT_W, 2 * RADIUS + SLOT_H)
wheel:SetFrameStrata("FULLSCREEN_DIALOG")
wheel:SetClampedToScreen(true)
wheel:Hide()

local hub = wheel:CreateTexture(nil, "ARTWORK")
hub:SetSize(6, 6)
hub:SetPoint("CENTER")
hub:SetColorTexture(1, 1, 1, 0.5)

local hint = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOP", hub, "BOTTOM", 0, -10)
hint:SetWidth(200)
hint:SetText("No favorites yet. Right-click emotes in the palette to add them.")

local slots, keys, selected = {}, {}, nil

local function Highlight(i)
    for j, s in ipairs(slots) do
        local on = j == i
        s:SetBackdropColor(0.05, 0.05, 0.06, on and 0.98 or 0.85)
        local r, g, b = unpack(ns.COLORS.fav)
        s:SetBackdropBorderColor(r, g, b, on and 0.9 or 0)
        if on then s.text:SetTextColor(unpack(ns.COLORS.fav)) else s.text:SetTextColor(0.9, 0.9, 0.9) end
    end
    selected = i
end

local function Release()
    local key = selected and keys[selected]
    wheel:Hide()
    if key then ns.Fire(key) end
end

for i = 1, ns.WHEEL_SLOTS do
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

-- Spreads n slots clockwise from the top and remembers each slot's angle.
local angles = {}
local function Layout(n)
    for i, s in ipairs(slots) do
        s:SetShown(i <= n)
        if i <= n then
            local a = math.pi / 2 - (i - 1) * 2 * math.pi / n
            angles[i] = a
            s:ClearAllPoints()
            s:SetPoint("CENTER", wheel, "CENTER", math.cos(a) * RADIUS, math.sin(a) * RADIUS)
        end
    end
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
    if #keys == 0 or dx * dx + dy * dy < DEADZONE * DEADZONE then
        if selected then Highlight(nil) end
        return
    end
    local a, best = math.atan2(dy, dx), 1
    for i = 2, #keys do
        if AngleGap(a, angles[i]) < AngleGap(a, angles[best]) then best = i end
    end
    if best ~= selected then Highlight(best) end
end)

local function Open()
    keys = ns.Existing(EzEmoteDB.favorites)
    for i = #keys, ns.WHEEL_SLOTS + 1, -1 do keys[i] = nil end
    Layout(#keys)
    for i = 1, #keys do slots[i].text:SetText(ns.Label(keys[i])) end
    hint:SetShown(#keys == 0)
    Highlight(nil)

    local x, y = GetCursorPosition()
    local scale = wheel:GetEffectiveScale()
    wheel:ClearAllPoints()
    wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    wheel:Show()
end

-- Key binding (Bindings.xml, runOnUp): pressed opens the wheel, released emotes the selected slot.
function EzEmote_Wheel(keystate)
    if keystate == "down" then
        Open()
    elseif wheel:IsShown() then
        Release()
    end
end
