# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-40 to CF-44 (one per screen, any order).

## E13 Revamp (new look)

Design: `docs/design/revamp-2026-10/` (README: decisions and where the mockups differ). Each screen story replaces one tab whole: old and new never mix inside one tab. Nothing stored or sent changes unless a story says so (rule 8). Visual checks happen in game after launch (VERIFY.md).

### CF-40 Friends tab in the new look
- Goal: the Friends tab as in `friends.html`.
- List (left, 270 px): the search box (CF-36, placeholder kept), per person a group header (online dot, name, "(you)", character count, collapsible), character rows (20 px portrait with online dot, name in class colour, level right, the shared-quest icon with a count). Selected row: gold left bar. Long lists scroll (`ScrollBox`). Right-click menu as CF-37.
- Detail (right): header (52 px portrait, name in Marcellus 24 in class colour, "Class · played by <person> · <status>": online in <zone> or offline, last seen in <zone> <ago>), **Whisper** and **Invite** buttons (the CF-37 actions; disabled when offline or for your own characters). Tiles: Level (with a bar to 60), Item level, Role ("from talents" or "set by player"). Professions as skill bars (rank / max, cap shading, ticks at the tier steps; secondary professions muted). Talents per tree with "a / b / c". Quests you share, grouped by area, dungeons first with a Dungeon tag, "Show all N →". A person's card (group header selected): as today, in the new style.
- Footer: "Synced with <person> <ago>" (the newest record received), "N characters from M friends", "/cf to open · drag the title to move".
- Unit tests (pure core): the header status line, the tiles, skill bar fractions and tier ticks, the footer texts.
- Manual: compare with `friends.html`; search, collapse, right-click, Whisper and Invite still work.

### CF-41 Activity tab in the new look
- Goal: the Activity tab as in `activity.html`.
- Filter chips: All, Level-ups, Dungeons, Together (one active; remembered while the window is open).
- Day headers (Today, Yesterday, then the date) in Marcellus SC. Per entry: a 32 px portrait (two overlapping for a together line), "<person> on <character>" or "<person> and <person> together", then a line with a **LEVEL UP** chip "22 → 24" (gold, with a slow shine unless Ambient effects is off), "questing in" with the top zones as pills and "+N zones", "· N quests done", runs ("ran <dungeon>"), profession ranks. The time on the right is the entry's last change that day (`at`, already stored; no run durations: not recorded).
- Footer: "Activity is shared only by friends who turned on Share my activity" and "Keeps 7 days".
- Unit tests (pure core): filtering per chip, the entry lines, "+N zones", the time.
- Manual: compare with `activity.html`; Show all and the together lines still work.

### CF-42 Dungeons tab in the new look
- Goal: the Dungeons tab as in `dungeons.html`.
- List (left): "Planned" (calendar runs within 3 days: name, day and time, who is going), then "In range for <character> (<level>)": per dungeon the level range ("outdoor" for outdoor ones), friends in range, and "x / y quests" (green when you have all). A note: "Ranges are typical levels; the list follows the character you're on."
- Detail: name in Marcellus 26, "levels a–b · <zone>". Suggested group as five slots (tank, healer, three damage): portrait, "<character> <level>", role and person; a missing role stands out ("nobody in range", orange dashed); your slot outlined in gold; open slots "+ open". "Alternatives for you: <your other characters in range>". **Ask who's up for it** (CF-27) with "Sends a chat line to friends with the addon" (not a popup). Quests "x / y in your log" with a check per quest and who else has it. Plan a run: the title ready to copy and **Open calendar** (as CF-24).
- Footer: "Synced with <person> <ago>" and "Group asks wait until combat ends".
- Unit tests (pure core): the slots (missing role, your slot, open), alternatives, quest counts and colour, the planned list.
- Manual: compare with `dungeons.html`; asking, the calendar button and planned runs still work.

### CF-43 Settings and setup in the new look
- Goal: the settings window and the first-run setup as in `settings-setup.html`.
- Settings (own window, 640 × ~500): Display name, Community (dropdown, character communities only), Sharing (Share my activity; Receive group asks: "a chat line when a friend looks for a group"), Notifications (When friends log in, Announce friends' level-ups, Play a sound), Community chat (colour swatch and Reset, Flash the chat tab, Create a community chat tab), Interface (Minimap button, **Open on login**, **Ambient effects**: title shimmer and level-up glow). No "paste an invite link to join" (blocked, V26). Footer "Also under Options › AddOns · v<version>"; registered there with `Settings.RegisterCanvasLayoutCategory` (unverified, VERIFY.md), replacing the AceConfig dialog.
- New settings `openOnLogin` (off) and `ambientEffects` (on): new keys with defaults, no migration (rule 8).
- Setup (600 × 460): progress bars and "Step n of 6", Welcome (three tiles: Friends, Activity, Dungeons), Community, Name, Community chat (optional, as CF-30: Create chat tab in the Next spot, Not now), Sharing and notifications, Done. Skip setup / Next.
- Unit tests: every setting writes the same value as before (one source of truth, CF-26); the new settings' defaults; the steps.
- Manual: compare with `settings-setup.html`; every setting works; the setup on a fresh account.

### CF-44 Level-up announcement
- Goal: a short announcement at the top of the screen when a friend's character levels up (`activity.html`, above the window).
- A pill at the top centre: 28 px portrait, "<person>'s <character> reached level N", the LEVEL UP chip (shine unless Ambient effects is off); fades out after 6 s; several in a row stack or queue. The chat line (CF-16) stays.
- Setting "Level-up announcement" (Notifications); its default is decided when building.
- Unit tests: when it shows (same rules as the CF-16 line: linked people, not older than 15 minutes), the text, the queue.
- Manual: a friend levels up: the pill shows and fades; off in settings: nothing.
