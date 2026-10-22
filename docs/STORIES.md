# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-32, CF-33, CF-34, CF-35, CF-36, CF-37 (after its probe), CF-31 (after V49).

## E10 Community transport

### CF-31 One broadcast in the community channel
- Goal: the community transport (CF-28 part 2b) sends one message to the community channel instead of a whisper to each member running the addon, so traffic no longer grows with the number of members.
- Depends on V49: can addons send addon messages in the community channel, and do they arrive at the other members (run 1: the send is accepted, but no copy comes back to the sender)? If V49 says no, this story is dropped and the whispers stay.
- Keeps everything from CF-28: 255-byte parts, MISS and resend, the accept rules (the sender maps to a community member; a record claimed as own must contain the sending character).
- Manual (2 clients in the community, not Battle.net friends): records, level-ups and group asks arrive; `/cf sync debug` shows one channel send instead of a whisper per member.

## E11 Ease of use

### CF-32 Keybinding and Esc closes the window
- Goal: open and close the window without typing `/cf`.
- A keybinding "Toggle CommunitiesForever" under its own header in Blizzard's keybinding menu (`Bindings.xml`), unbound by default.
- Decided: hard rule 5 in CLAUDE.md gets `BINDING_HEADER_*` / `BINDING_NAME_*` next to `SLASH_*` (Bindings.xml needs them as globals).
- Esc closes the window (and the setup wizard) through the frame's own key handler: no named global frame for `UISpecialFrames`. Esc still opens the game menu when no CommunitiesForever window is open, and still works for other frames and the chat input.
- Manual: bind a key, it toggles the window; Esc closes it; Esc with the window closed opens the game menu; typing in the chat input is not affected.

### CF-33 Minimap button tooltip: who is online
- Goal: see at a glance who is online without opening the window.
- Hovering the minimap button lists the people online now: display name, then their character with class color and level (e.g. `Bright  Vel Stormcaller 24`), Battle.net friends and community peers alike (`Sync.online()`), sorted by name. Nobody online: "Nobody online right now." At most 15 lines, then "+N more".
- Below: "Left-click: open window", "Right-click: settings" (as today).
- Unit tests (pure core): the lines from the online list (sorting, class/level missing, the cap).
- Manual: with a friend online, the tooltip shows them on the right character; after they log out they disappear.

### CF-34 "Uses the addon" mark
- Goal: explain why some people show no professions, talents or quests: they don't run the addon.
- In the Friends tab tree, people running the addon (a record received from them, own or relayed) get a small icon after their name; people known only from the community list get none. The icon's tooltip: "Runs CommunitiesForever" / on the person card a line "Does not run CommunitiesForever: only what the community list shows (class, level, zone)."
- Unit tests (pure core): which people count as running the addon (own record, relayed record, none).
- Manual: a friend with the addon has the mark; a community member without it has none and the explaining line.

### CF-35 Newer version notice
- Goal: during the betas, everyone notices when an update is out.
- Each HELLO carries the sender's addon version (new field; older clients ignore it). When someone runs a newer **release** version than yours, one chat line per session: "A newer version of CommunitiesForever is available (v0.3.1). Update with the CurseForge app or WowUp."
- Decided: only release versions are compared (`v1.2.3`, `v1.2.3-betaN`, `-alphaN`; `v0.3.0-beta1` < `v0.3.0-beta2` < `v0.3.0` < `v0.3.1`). Dev builds (`0.1.N` from `build.ps1`, `@project-version@`) never trigger the line and never get it. A version more than one major ahead or unparsable is ignored.
- `docs/SYNC.md` documents the field.
- Unit tests (pure core): version parsing and order, dev builds ignored, once per session.
- Manual: two clients on different release builds: the older one gets the line once; `/reload` shows it once more at most.

### CF-36 Smart filter in the Friends tab
- Goal: find "who has Tailoring 150?" or "which mages are 20-30?" without clicking through everyone (instead of a separate profession overview: same data).
- A search box above the tree with a grey placeholder while empty and unfocused: `e.g. tailoring 150, mage 20-30` (AceGUI has no placeholder: an own grey text on the edit box, hidden while it has text or focus).
- Decided: each word must match something of a character: name, owner's display name, class, role (tank/healer/dps), profession or zone. A number right after a profession is a minimum rank (`tailoring 150`); `20-30` is a level range; a single number is an exact level. Case-insensitive, also on part of a word (`tail`).
- The tree shows only people with at least one matching character, those characters only, expanded; the count shows ("3 of 12"). Empty box: everything as today. The text stays while the window is open, cleared on close.
- Unit tests (pure core): parsing (words, profession + rank, ranges) and matching per field; no match.
- Manual: `tailoring 150`, `mage 20-30`, `healer`, a zone name, a partial name; clearing the box shows everyone.

### CF-37 Right-click menu on a character
- Goal: whisper, invite or copy a character's name without typing a first-and-last name.
- Right-click a character (in the tree and on the person card) opens a Blizzard-style context menu: **Whisper** (opens the chat input with `/w <name> `), **Invite to group** (as CF-27's invite: by name, else Battle.net), **Copy name** (a small box with the name selected, so Ctrl+C copies it; WoW has no clipboard API). Your own characters: only Copy name.
- Decided: Blizzard's menu (`MenuUtil`), probed first (new FriendProbe check, V-question in VERIFY.md): does `MenuUtil.CreateContextMenu` exist and work from an AceGUI tree row, and which call opens a whisper (`ChatFrameUtil.SendTell` / `ChatFrame_SendTell`). If the menu does not work, a small own popup with the same three buttons.
- Manual: each menu item on a friend's character; Invite on an offline character is disabled.
