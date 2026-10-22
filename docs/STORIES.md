# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-36, CF-37 (after its probe), CF-31 (after V49).

## E10 Community transport

### CF-31 One broadcast in the community channel
- Goal: the community transport (CF-28 part 2b) sends one message to the community channel instead of a whisper to each member running the addon, so traffic no longer grows with the number of members.
- Depends on V49: can addons send addon messages in the community channel, and do they arrive at the other members (run 1: the send is accepted, but no copy comes back to the sender)? If V49 says no, this story is dropped and the whispers stay.
- Keeps everything from CF-28: 255-byte parts, MISS and resend, the accept rules (the sender maps to a community member; a record claimed as own must contain the sending character).
- Manual (2 clients in the community, not Battle.net friends): records, level-ups and group asks arrive; `/cf sync debug` shows one channel send instead of a whisper per member.

## E11 Ease of use

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
