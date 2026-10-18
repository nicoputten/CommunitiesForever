# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-02, 22, 23 (after V35), 24 (after V33, V34).

## E0 Foundation

### CF-02 Release pipeline
- Pushing a git tag `v*` runs the BigWigs packager and uploads to CurseForge (Forever flavor) using the `CF_API_TOKEN` secret. CurseForge project ID in the TOC (`## X-Curse-Project-ID`).
- Untagged pushes produce no release.
- Decided (CF-02 part 1): the released files contain no personal info. Author `Vestras` (TOC and LICENSE), generic examples in `src` comments, hand-written `CHANGELOG.md` (`manual-changelog` in `.pkgmeta`) instead of a changelog built from commit messages. `tests/spec/Release_spec.lua` fails on banned names in the released files. The repo stays private; its history is unchanged.
- Manual: install via the CurseForge app; publishing a new tag delivers an update.
- The package contains only the addon: `.pkgmeta` ignores tests, tools, docs, `VERIFY.md`, `CLAUDE.md` and the CI config. Check: unzip the built package and list its files.

## E7 Activity and planning

### CF-22 Activity feed
- Goal: see at a glance what friends did recently, without one active player flooding the feed. One line per person per day, built from events each client records about its own characters and syncs with its record.
- Decided: no play time, no logins without other activity, no gold, no deaths. Only what someone did.
- Events in this story (no new API needed):
  - **Level-up** (`PLAYER_LEVEL_UP`): per character lowest → highest level of the day: `Ves 5 → 8`.
  - **Milestone**: reaching level 10, 20, 40 or 60 replaces the plain range: `Ves reached 40` (for 60: `Ves reached 60!`).
  - **Questing** (`QUEST_TURNED_IN`, at least 1 quest): count per character plus the zones, sorted by most turn-ins. One zone: `questing in Westfall (9)`; two: `questing in Westfall and Redridge (12)`; three or more: `questing in Westfall, Redridge +2 zones (15)`. The zone is the area (log header) of the quest that was turned in.
  - **Profession rank** (`SKILL_LINES_CHANGED`): only when a new rank is trained (the max goes up: 75 Apprentice, 150 Journeyman, 225 Expert, 300 Artisan), and when a profession is learned: `Mining reached Expert`, `learned Alchemy`. Skill point gains are not shown.
- Storage: own record field `feed`, aggregated per realm day (in-game calendar date) per character, so turn-ins do not add one entry each: `feed = { [day] = { [guid] = { levelFrom, levelTo, milestone, quests = { [zone] = count }, ranks = { { name, rank } }, learned = { name } } } }`. Kept 7 days. A feed change bumps the version at most once per 60 s (debounced), so questing does not sync after every turn-in.
- Privacy: setting "Share my activity" (on by default). Off: your own feed still shows in your window, but `outgoingRecord` leaves `feed` out and friends drop what they stored.
- Line per person per day (pure core, unit tested): parts in order of importance: milestone, level, profession, questing (CF-23 adds dungeon, raid, battleground and activities together at the top). At most 3 parts, then `+N`; clicking the line shows all parts. With several characters the most active one is in the sentence, then `+1 character`. Example: `Vestras: Ves 5 → 8, Mining reached Expert, questing in Westfall (9) +1 character`.
- Window: an **Activity** tab next to the current view (the dungeon planner, CF-24, becomes a third tab). Sections `Today`, `Yesterday`, then weekday names, newest first; within a day, the person active most recently first. Your own line is included. Received text is cleaned like all other received text.
- Unit tests: aggregation per day and character; milestone replaces range; zone wording for 1, 2 and 3+ zones; only new ranks; 3-part limit with `+N`; several characters; 7-day trim; debounced version bump; share off leaves `feed` out.
- Manual (2 clients): level up, turn in quests in two zones, train a new profession rank; within ~1 min the friend's Activity tab shows one line for you today. Share off: your line disappears for the friend after the next sync.

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
- Needs V33 (read community calendar events) and V34 (create a community sign-up event from a click).
- A **Dungeons** tab: for each Vanilla dungeon (fixed table in core with level ranges, same names as the CF-19 list) that fits one of your characters: your characters in range, friends' characters in range (online first), and who has a quest for it (CF-19). Dungeons with the most candidates first.
- Selecting a dungeon suggests a group automatically: up to 5 characters in level range, preferring one tank and one healer by role (CF-18), then shared quests, then online.
- Calendar: upcoming community events whose title mentions the dungeon are listed with their sign-ups. "Plan in calendar" creates a community sign-up event (title `<dungeon> run`, time picked by you, the suggested characters in the description) if V34 allows it; otherwise the button opens Blizzard's calendar.
- Unit tests: level-range filter; suggestion order (roles, quests, online); title matching for calendar events.
- Manual: open the tab, pick a dungeon, create an event, a friend sees it in the community calendar and signs up.
