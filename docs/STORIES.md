# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-02 (part 2: tag workflow, needs the API token), 25 (after V39), 26, 23 (after V35), 24.

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
- V37 (verified): coloring the channel, opening a chat tab, flashing a tab and playing a sound work from an addon; `ChatFrame_AddChannel` is gone, so V39 finds how to put the channel into the new tab. V38 (verified): the message text is hidden, but the sender name and GUID are readable.
- **Color, always on** (decided): the community channel is purple in all chat windows (`ChangeChatColor` on the channel, default `#C080FF`, readable on the dark chat background). Applied on every login and when the community selection changes. A color picker in settings changes the shade; there is no off switch.
- **Alert on a new message** (setting, on by default): when someone else writes in the selected community, every chat tab that shows the channel and is not the selected tab flashes (`FCF_StartAlertFlash`). Optional sound (`SOUNDKIT.TELL_MESSAGE`, setting, off by default). No alert for your own messages (sender GUID is one of your characters, V38).
- **Community chat tab** (encouraged, CF-26 offers it): a button "Create a Community tab" opens a chat tab named after the community that shows only that channel. Chat windows are saved per character by the game, so the tab is offered once per character (remembered in `settings.chatTab[guid]`); clicking again when the tab exists says so. Option "Keep community messages in General too" (on by default); off removes the channel from the other windows, so only the Community tab flashes.
- Not in scope: a chat view inside our window, changing sender names or message text (likely blocked by secret values under Midnight).
- Unit tests (pure core): which incoming messages alert (selected community, not you, not the selected tab); color setting default and change; tab offered once per character.
- Manual (2 clients): a friend writes in the community while another chat tab is selected: the tab with the community chat flashes and the message is purple. Create the Community tab: it shows only community messages; with "Keep in General" off, General no longer shows them.

### CF-26 Onboarding wizard
- Goal: new users set things up in a minute and are encouraged to create the Community chat tab (CF-25). Builds on CF-25 (tab and color code).
- A small window with Back, Next and Skip, shown once per account on the first login after installing (`settings.onboarded`), reopened with `/cf setup`. Closing it counts as skipped; nothing is required.
- Steps:
  1. **Welcome**: what the addon does in three lines (who is who in your community, synced between friends with the addon, activity and shared quests).
  2. **Community**: pick the community (dropdown, pre-selected when there is only one). Without a character community: how to join one (invite link from a friend, CF-21).
  3. **Your name**: display name friends see (CF-04), prefilled with the BattleTag name part.
  4. **Community chat**: a preview line in the purple community color, the big highlighted button **Create a Community tab** (recommended), "Keep community messages in General too" (on), "Flash the tab on new messages" (on), "Play a sound" (off).
  5. **Notifications and sharing**: login notices (on), level-ups (on), Share my activity (on), minimap button (on), each with one line on what it does.
  6. **Done**: "Open CommunitiesForever with /cf", and that friends need the addon too to see their professions, talents, quests and activity.
- Every step writes the same settings as `/cf settings` (one source of truth); the wizard only presents them.
- Alts: chat windows are per character, so on a character without the Community tab (`settings.chatTab[guid]`) a small prompt offers only step 4 ("Create a Community tab on this character too?" Create / Not now / Don't ask again for this character).
- New steps added later (`settings.onboardedVersion`) are shown once to existing users, only the new ones.
- Unit tests (pure core): which steps to show (first run, new version, alt without tab, don't ask again); defaults per setting.
- Manual: fresh SavedVariables: the wizard opens on login, Skip closes it, `/cf setup` reopens it; finishing step 4 creates the Community tab; on an alt only the chat prompt appears.
