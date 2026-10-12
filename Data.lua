-- EzEmote static data: categories, defaults and the few animated emotes Blizzard's lists leave out.
local _, ns = ...

ns.ICON = "Interface\\Icons\\Spell_Shadow_SoothingKiss"

-- Wheels (each with its own key binding), slots per wheel, and emotes kept in the Recent tab.
ns.WHEEL_COUNT = 4
ns.MIN_SLOTS, ns.MAX_SLOTS, ns.DEFAULT_SLOTS = 4, 12, 8
ns.MAX_RECENT = 15

-- Palette tabs, top to bottom. Lists name emotes by their slash command (aliases work too);
-- any your client doesn't have are skipped, and "All" always shows every emote.
ns.CATEGORIES = {
    { key = "fav",    label = "Favorites" },
    { key = "recent", label = "Recent" },
    { key = "greet",  label = "Greet", list = {
        "wave", "hello", "bye", "bow", "curtsey", "greet", "hail", "welcome", "salute", "kneel",
        "nod", "introduce", "thank", "yw", "beckon", "farewell",
    } },
    { key = "mood",   label = "Mood", list = {
        "smile", "grin", "laugh", "giggle", "chuckle", "happy", "blush", "shy", "sigh", "sad",
        "cry", "frown", "sulk", "pout", "angry", "bored", "confused", "surprised", "gasp", "scared",
        "cower", "nervous", "think", "ponder", "smirk", "wink", "facepalm", "eyebrow", "tired",
    } },
    { key = "social", label = "Social", list = {
        "applaud", "cheer", "clap", "congratulate", "hug", "kiss", "flirt", "comfort", "pat", "tickle",
        "poke", "agree", "disagree", "point", "shrug", "sorry", "apologize", "plead", "beg", "cuddle",
        "love", "praise", "bravo", "highfive", "shake", "whisper", "listen", "talk",
    } },
    { key = "pose",   label = "Poses", list = {
        "sit", "stand", "sleep", "kneel", "lean", "eat", "drink", "read", "crossarms", "talk",
        "talkq", "talkex", "pray", "look", "stare", "lay", "rest", "fidget", "stretch", "sweat",
    } },
    { key = "silly",  label = "Silly", list = {
        "dance", "chicken", "flex", "roar", "rude", "train", "joke", "silly", "moo", "meow",
        "quack", "boop", "rasp", "whistle", "bonk", "drool", "burp", "fart", "flap", "puzzle",
        "shimmy", "golfclap", "lavish",
    } },
    { key = "combat", label = "Combat", list = {
        "charge", "helpme", "incoming", "flee", "attackmytarget", "oom", "follow", "wait", "healme", "openfire",
        "threaten", "glare", "growl", "victory", "ready", "taunt", "warn", "battlecry",
    } },
    { key = "all",    label = "All" },
    { key = "custom", label = "Custom" },
}

-- Starting favorites.
ns.DEFAULT_FAVORITES = { "wave", "bow", "laugh", "cheer", "dance", "salute", "kneel", "thank" }

-- Starting wheels, slots clockwise from the top. A wheel without a list starts with your first favorites.
ns.DEFAULT_WHEELS = {
    { name = "Main" },
    { name = "Mood", list = { "smile", "laugh", "cry", "sigh", "angry", "blush", "shrug", "confused" } },
    { name = "Poses", list = { "sit", "stand", "kneel", "sleep", "lean", "eat", "drink", "read" } },
    { name = "Combat", list = { "charge", "helpme", "incoming", "flee", "attackmytarget", "oom", "follow", "healme" } },
}

-- Starting custom items: one line is a custom /e, several make a chain.
ns.DEFAULT_CUSTOM = {
    { name = "lean on wall", lines = { "leans against the wall, arms crossed." } },
    { name = "arrive", lines = { "/wave", "looks around the room.", "/sit" } },
}

-- Chain lines starting with these commands are sent as emote text.
ns.TEXT_COMMANDS = { e = true, em = true, me = true, emote = true }

-- Animated emotes missing from Blizzard's EmoteList (its emote menu only lists some of them).
ns.EXTRA_ANIM = { "CHEER", "CLAP", "NOD", "NO", "HELLO", "BYE", "TALKQ", "TALKEX" }

-- Marker colors in the palette: animation, voice line, chain (several steps).
ns.COLORS = {
    anim  = { 0.40, 0.85, 0.50 },
    voice = { 0.35, 0.65, 1.00 },
    chain = { 0.72, 0.52, 1.00 },
    fav   = { 1.00, 0.82, 0.00 },
}
