# EzEmote

## Unreleased

- **Where you are.** `%l` in a custom line becomes your location: the subzone you stand in ("Goldshire"), or the zone when there is none ("Elwynn Forest"). "raises a glass to everyone in %l."

## v1.2.0

- **Resizable palette.** Drag its bottom-right corner to make it bigger: the grid gains columns and rows, so more emotes fit without scrolling. The size is remembered; `/eze reset` puts it back.

## v1.1.0

- **Four wheels.** Each wheel has its own name and key binding, so one key can hold your greetings and another your fighting words. They start as Main (your first eight favorites, so nothing changes for wheels you already use), Mood, Poses and Combat, and the key bindings list them by name.
- **The wheel editor.** `/eze wheels` (or Edit wheels in the options) draws the wheel: click a slot and pick from the palette, right-click to clear, drag one slot onto another to swap. Rename a wheel right there. Wheels no longer follow your favorites.
- **As big as you need.** Each wheel holds 4 to 12 emotes; set it with - and + in the editor. A small wheel stays quick to flick, a big one fits your whole mood set. Shrinking a wheel keeps the hidden emotes for when you grow it again.
- **Every emote in its place.** Slots keep their spot on the wheel, so an emote is always in the same direction, and pointing at an empty slot does nothing instead of grabbing a neighbour.
- Emote tooltips show which wheels hold them ("On wheel: Main 1, Mood 3").
- Right-clicking the icon right after logging in opens the options again, instead of the emote grid.

## v1.0.1

- **No more surprise lines.** Text in a chain always goes out the moment you press, so a line written after a `wait` jumped ahead of the emotes before it without telling you. The editor now warns you while you type, in amber: *Text can't wait: "Realises she needs more..." goes out on the press, with the first step. Move it up to match.*

## v1.0.0

- **Your action bars back.** Every emote in the game sits in one small palette instead of a row of macros. Open it with a key binding or the tiny launcher icon, type a few letters and press Enter, or pick from Favorites, Recent, Greet, Mood, Social, Poses, Silly, Combat or All. It closes as soon as you emote; Shift-click to keep it open.
- **The wheel.** Hold its key and your first eight favorites fan out around the cursor. Point at one and let go. Nothing stays on screen once you release.
- **Your own words.** Save custom `/e` lines ("leans against the wall, arms crossed.") and chains that mix emotes, text and pauses: `/wave`, "looks around the room.", `wait 3`, `/sit`. One press plays it all: text lines go out right away (the game allows addon chat text only from a click or key press) and the emotes keep their timing. `%t` is your target's name. Custom items can be favorites and wheel slots too, and `/eze <name>` runs one from a macro.
- **Know what you'll get.** Green dots mark emotes with an animation, blue ones a voice line, purple ones your chains.
- **Out of your way.** Flat, dark and small. Hide the launcher icon and it's just your key bindings (Options > Keybindings > EzEmote).
- First release for WoW Forever.
