std = "lua51"
max_line_length = false
self = false

globals = {
    "EzEmoteDB",
    "SLASH_EZEMOTE1",
    "SLASH_EZEMOTE2",
    "SlashCmdList",
    "BINDING_HEADER_EZEMOTE",
    "BINDING_NAME_EZEMOTE_PALETTE",
    "BINDING_NAME_EZEMOTE_WHEEL",
    "EzEmote_TogglePalette",
    "EzEmote_Wheel",
}

read_globals = {
    -- Lua / WoW utility
    "format", "strtrim", "wipe", "tinsert",
    -- Frames & UI
    "CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip", "DEFAULT_CHAT_FRAME", "ChatFrame1",
    -- Emote data (Blizzard_ChatFrameBase)
    "EmoteList", "TextEmoteSpeechList", "MAXEMOTEINDEX",
    -- Namespaced APIs
    "C_ChatInfo", "C_Timer", "issecretvalue",
    -- Global APIs
    "DoEmote", "SendChatMessage", "UnitExists", "UnitName", "UnitFactionGroup", "GetCursorPosition",
    "GetBindingAction", "IsAltKeyDown", "IsControlKeyDown", "IsShiftKeyDown",
}
