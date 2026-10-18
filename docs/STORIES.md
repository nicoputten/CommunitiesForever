# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-02 (part 2: tag workflow, needs the API token), 26, 23 (after V35), 24.

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
- Decided in CF-23: built before V35 was run, with guarded fallbacks: a boss kill comes from `ENCOUNTER_END` (success 1) or `BOSS_KILL` (counted once per encounter); the battleground winner from `PVP_MATCH_COMPLETE` or `GetBattlefieldWinner`, your team from `GetBattlefieldArenaFaction` or your faction (Horde 0, Alliance 1). A missing API means a missing line, never an error. `/cf activity debug` prints every instance event and what the tracker concluded, so the first real dungeon answers V35.
- Decided in CF-23: the run in progress is saved (`db.global.runs`), so `/reload` or a disconnect inside keeps it; the time inside counts until leaving (or the logout). A run counts on the day it started. Only companions who are members of the selected community are stored. Several runs with the same people on a day make one shared line per group of people (`Ann and Ben together`: `ran Deadmines ×2`); battlegrounds are counted together regardless of map.

### CF-24 Dungeon planner
- Calendar findings: reading events works (V33); creating one is blocked for addons (V34: `AddEvent` fires `ADDON_ACTION_BLOCKED`).
- A **Dungeons** tab: for each Vanilla dungeon (fixed table in core with level ranges, same names as the CF-19 list) that fits one of your characters: your characters in range, friends' characters in range (online first), and who has a quest for it (CF-19). Dungeons with the most candidates first.
- Selecting a dungeon suggests a group automatically: up to 5 characters in level range, preferring one tank and one healer by role (CF-18), then shared quests, then online.
- Calendar: upcoming community events (`calendarType` community, V33) whose title mentions the dungeon are listed with their time and sign-ups. Since addons cannot create events (V34), "Plan in calendar" opens Blizzard's calendar (unverified call, guarded) and puts a ready-made title (`<dungeon> run`) and the suggested characters in a chat line to copy into the event. Still to verify: how a community event shows in `GetDayEvent` (create one by hand, `/fp calendar`).
- Unit tests: level-range filter; suggestion order (roles, quests, online); title matching for calendar events.
- Manual: open the tab, pick a dungeon, create the event in Blizzard's calendar from the suggestion; it shows on the dungeon page; a friend sees it and signs up.
- Decided in CF-24: layout A (dungeon list on the left like the Friends tab, the chosen dungeon on the right). Candidates are all community members: your characters, linked people's characters (also their alts outside the community), and unlinked members (level and class only; each counts as their own person). Only dungeons with one of your characters in range; raids are left out. Scarlet Monastery is split into its four wings with their own ranges; quests count for a dungeon by their quest log area. The suggestion takes at most one character per person: your best one first, then a tank and a healer from two different people, then shared quests, online, closeness to the middle of the range. Chat lines cannot be copied in WoW, so "Plan a run" shows the event title in a field to copy from (Ctrl+C), plus an Open calendar button.
- Decided in CF-24 round 2 (feedback): the event title is just the dungeon name and events match on the dungeon name only ("The" optional, the longest name wins: a Scarlet Monastery wing beats nothing shorter); no short names, no group field (you cannot invite yourself; inviting is done in the calendar). Runs planned within 3 days are listed on top under Planned (also for dungeons none of your characters fits, in grey) with their time and sign-ups, and the tab reads `Dungeons (N)`. Sign-ups count signed up, accepted and confirmed (tentative apart); they need each event opened (`C_Calendar.OpenEvent`, one at a time, V43), done in the background by the Planner service. Section titles in the normal size; your other characters in range on one line under yours; no Calendar section without events.
- Decided in CF-24 round 3 (feedback): list rows show the dungeon icon with `have/total` quests; the detail has a Quests section (in your log, to pick up with who in range has it, from level N, and how many are already done). have = quests in the log of your character in the suggested group; total = have + quests you can pick up now. No API lists quests you have not picked up, so the full list comes from the optional QuestieDB addon at runtime (decided: no data shipped, QuestieDB has no license); without it, from the quest logs of people in range. Quests of the other faction (`requiredRaces`) and class quests are left out; completed ones only for the character you are on (`IsQuestFlaggedCompleted`, V45).
- Decided in CF-24 round 4 (feedback: Forever's new dungeons were missing): the list comes from the game's Group Finder (`C_LFGList` dungeon activities, V46) at runtime. Known dungeons keep their quest data and take the game's level range; unknown ones (Forever's new dungeons: Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran) are added by name and range, with quests only from quest logs (QuestieDB has no Forever-only data yet). Without the Group Finder the static Vanilla table is used.

## E8 Communication

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
- Decided in CF-26: existing users (no `settings.onboarded` yet) see the full wizard once too, prefilled with their settings. Layout A: a compact window with dots and "Step N of 6" on top, Back / Skip / Next at the bottom (Finish on the last step). It opens 5 s after login. The character the wizard ran on gets no chat prompt; the prompt (feedback round 1) has one big "Yes, create a Community tab" button; closing it means no, and either way the character is not asked again (`settings.chatTabPrompt[guid]`). A closed chat tab keeps its name, so closed windows do not count as a Community tab (V41). The display name is saved when leaving its step, and only when it changed.
