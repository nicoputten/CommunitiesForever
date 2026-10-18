# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-02 (part 2: tag workflow, needs the API token), 25 (after V37), 23 (after V35), 24.

## E0 Foundation

### CF-02 Release pipeline
- Pushing a git tag `v*` runs the BigWigs packager and uploads to CurseForge (Forever flavor) using the `CF_API_TOKEN` secret. CurseForge project ID in the TOC (`## X-Curse-Project-ID`).
- Still open (part 2, once the `CF_API_TOKEN` secret exists): the tag workflow itself.
- Untagged pushes produce no release.
- Done in part 1 (PR #21, merged without the token): project ID 1752013 in the TOC, zip with forward-slash paths, campfire logo in `docs/logo/`, and the released files contain no personal info. Author `Vestras` (TOC and LICENSE), generic examples in `src` comments, hand-written `CHANGELOG.md` (`manual-changelog` in `.pkgmeta`) instead of a changelog built from commit messages. `tests/spec/Release_spec.lua` fails on banned names in the released files. The repo stays private; its history is unchanged.
- Manual: install via the CurseForge app; publishing a new tag delivers an update.
- The package contains only the addon: `.pkgmeta` ignores tests, tools, docs, `VERIFY.md`, `CLAUDE.md` and the CI config. Check: unzip the built package and list its files.

## E7 Activity and planning

### CF-23 Feed: dungeons, raids, battlegrounds and playing together
- Needs V35 (which events tell instance type, boss kills, group members and battleground results).
- **Dungeon run**: inside a dungeon at least 10 minutes and at least 1 boss killed (which boss does not matter, skipping the last one is fine): `ran Deadmines`; twice: `ran Deadmines ×2`.
- **Raid**: the same for raids, with the number of bosses: `raided Molten Core (4 bosses)`.
- **Battleground**: per match that ends: `3 battlegrounds (2 won)`.
- **Playing together** (decided: one combined line): the client stores the group members' GUIDs with each dungeon, raid and battleground. The receiver maps them to people (Linker). When two or more people did the same activity together that day, one shared line replaces it on their own lines: `Vestras and Alice ran Deadmines ×2`, `Vestras, Alice and Bob: 3 battlegrounds (2 won)`. Community members without the addon appear by character name: `Vestras ran Deadmines with Alice Example`.
- These parts come first on a line, before milestone and level.
- Unit tests: 10-minute and boss rule; ×2; shared line from two records; shared line from one record (companion without the addon); companions outside the community left out.
- Manual (2 clients in one group): run a dungeon together, kill one boss, leave after 10 minutes: one shared line for both.

### CF-24 Dungeon planner
- Calendar findings: reading events works (V33); creating one is blocked for addons (V34: `AddEvent` fires `ADDON_ACTION_BLOCKED`).
- A **Dungeons** tab: for each Vanilla dungeon (fixed table in core with level ranges, same names as the CF-19 list) that fits one of your characters: your characters in range, friends' characters in range (online first), and who has a quest for it (CF-19). Dungeons with the most candidates first.
- Selecting a dungeon suggests a group automatically: up to 5 characters in level range, preferring one tank and one healer by role (CF-18), then shared quests, then online.
- Calendar: upcoming community events (`calendarType` community, V33) whose title mentions the dungeon are listed with their time and sign-ups. Since addons cannot create events (V34), "Plan in calendar" opens Blizzard's calendar (unverified call, guarded) and puts a ready-made title (`<dungeon> run`) and the suggested characters in a chat line to copy into the event. Still to verify: how a community event shows in `GetDayEvent` (create one by hand, `/fp calendar`).
- Unit tests: level-range filter; suggestion order (roles, quests, online); title matching for calendar events.
- Manual: open the tab, pick a dungeon, create the event in Blizzard's calendar from the suggestion; it shows on the dungeon page; a friend sees it and signs up.

## E8 Communication

### CF-25 Community chat that stands out
- Goal: messages in the selected community's chat are easy to notice, in Blizzard's own chat (no chat of our own).
- Needs V37 (`/fp chat`): the community channel name and index, whether coloring a channel, opening a chat tab and flashing a tab work from an addon (or are protected under Midnight), and whether message text is readable.
- **Own color** (setting "Community chat color", default a bright orange, color picker): the community channel gets this color in all chat windows (`ChangeChatColor` on the channel, V37). Applied on login and when changed; Blizzard keeps it in its chat settings. "Reset" goes back to Blizzard's color.
- **Alert on a new message** (setting, on by default): when someone else writes in the selected community, the chat tab that shows the channel flashes, even when another tab is open (`FCF_StartAlertFlash`, V37). Optional sound (setting, off by default). Never for your own messages, never in combat if V37 shows that is protected.
- **Community chat tab** (opt-in button in settings, "Create a Community tab"): opens a new chat tab named after the community that shows only that channel. Only on click, never automatic, since it changes the player's chat layout. Clicking again when the tab exists says so instead of making a second one.
- Not in scope: a chat view inside our window, changing sender names or message text (likely blocked by secret values under Midnight).
- Unit tests (pure core): channel name from clubId and streamId; which incoming messages alert (selected community, not you); color setting stored and reset.
- Manual (2 clients): a friend writes in the community chat while you have another chat tab open: the tab with the community chat flashes and the message shows in your color. Create the Community tab: it shows only community messages.
