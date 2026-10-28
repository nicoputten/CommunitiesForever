# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.

## E14 Planned runs (continued)

## E17 Dailies and weeklies (decided with Nico, 2026-10-28)
Small personal goals that reset each realm day or week, per friend (any of your characters counts): 3 dailies and 3 weeklies, picked from a pool so every friend gets the same set. They earn **DoomPoints PvE** (1 per daily, 3 per weekly) and a streak. The PvP ladder's goals and **DoomPoints PvP** are separate stories. The two are shown side by side and never added up, and the dailies pool has no PvP goals. The pool, its rules, the swaps and the points are in `docs/DAILIES.md`.

The addon decides what's done and shares it. The site (web WEB-60 to WEB-62) and the bot only read it. Designs: web `docs/DESIGN-PROMPT-DAILIES.md` (the tab can be built on the kit before the designs and adjusted after). Order: CF-57, CF-58, CF-59. CF-60 adds its goals after its APIs are verified at launch. Goals that need CF-52/CF-53 trackers join the pool once those are verified.

### CF-57 Dailies and weeklies: pool, pick and progress
- `src/core/Dailies.lua` (pure, rule 1): the pool from `docs/DAILIES.md` (id, category, title, target, fallback, data source); `Dailies.POOL_VERSION`; `Dailies.week(day)`; `Dailies.pick(day)` and `Dailies.pickWeek(week)` (seeded, deterministic, 3 different categories for dailies, nothing picked twice in a row); `Dailies.swap(set, canDo)` with the fallback chain; `Dailies.progress(goal, facts)` → `current, target, done`; points and the streak.
- Only goals whose data the addon records go into the pool. Goals marked 52, 53 or 60 stay out until their trackers are verified (a release then bumps `POOL_VERSION`).
- Facts per realm day, kept by a service (`src/services/DailiesTracker.lua`), summed over your own characters: quests per zone (from the feed), levels, runs with bosses and companions, profession ranks and learned professions, logins per character, and item level. "Since the first login today/this week" values (level, item level, profession ranks per character) are a base taken the first time a character is seen in that day or week.
- `w.fullClear` needs each dungeon's boss count: a static count per dungeon in the core dungeon data (pure data, no API).
- Stored in `self.goals = { days = { [day] = { set, swapped = { [id] = originalId }, done = { [id] = at }, at } }, weeks = { [week] = { ... } }, streak = { n, last }, best, total }`. `total` = all-time DoomPoints PvE. 14 days and 4 weeks kept. New optional data, so no migration (rule 8); code reading it handles nil.
- `/cf dailies` prints today's and this week's goals with progress, the swaps, the streak and the points (`Describe`).
- Tests (busted): the same pick for the same day, different days differ, no repeats in a row, 3 categories; swap and fallback chain; progress per goal over two characters; points; the streak across a missed day; week boundaries (Sunday → Monday).
- Manual (`VERIFY.md`): finish 10 quests on two characters and see `d.quests10` done; the day rolls over at the realm day's end.

### CF-58 Share dailies with friends
- RECORD gets an optional field `goals` (rule 8, within `pv` 1): the last 7 realm days and the current and previous week from `self.goals` (`set`, `swapped`, `done`, `at`) plus `streak`, `best`, `total` and `pool` (the pool version). Sent only when "Share my activity" is on; `false` when it is off (as `feed`, CF-28).
- A completion bumps the version through the same debounce as the feed (at most once per 60 s).
- Receiving: per day and per week, the newer `at` wins (as the feed). Cleaned and capped: ids are strings of at most 24 characters, at most 3 per set, 7 days and 2 weeks, and numbers ≥ 0. Ids the client doesn't know (a newer pool) are kept, counted, and shown as "a daily from a newer version".
- Compatibility: older clients ignore `goals` and drop it when relaying (`Merge` keeps known fields only). A relayed record without it is nil = unknown, so the stored one stays. Newer clients get it again from the owner or from a relay that has CF-58.
- `docs/SYNC.md` (field table, caps, merge rule) and `docs/ARCHITECTURE.md` (data model) updated. A fixture with `goals` for the next release's capture. `Compat_spec` passes.
- Manual: two accounts. A's completion shows on B within a minute, and turning sharing off on A removes it on B.

### CF-59 Dailies tab and chat line
- A new tab **Dailies** in the main window, after Dungeons and Ladder (CF-56):
  - Today: the 3 dailies with a check mark or progress (7/10) and the time until the realm day resets. A swapped goal shows a small "swapped" mark, with the original in its tooltip.
  - This week: the 3 weeklies, the same way, with the time until Monday.
  - You: the streak (and best), and **DoomPoints · PvE** this week and all time. **PvP** sits next to it once the ladder provides it; until then it isn't shown.
  - Friends (from CF-58): per friend today's and this week's check marks, the streak and this week's PvE points, sorted by points. Friends who don't share, or who run an addon without dailies, show "not shared".
- A chat line when you finish a goal: "Daily done: Finish 10 quests (+1 DoomPoint PvE, 2 of 3 today)". A setting **Dailies in chat** (on by default) in the settings dialog.
- Frames from the kit (pools, `Kit.scrollArea`), as the other tabs. Layout and wording follow the design once it's in.
- Tests: the pure parts (rows and sorting from goals and people, reset times, the chat text) with busted.
- Manual: the tab with your own goals and a friend's; the chat line and its setting.

### CF-60 Data for fishing, trades and discoveries
New local trackers (not sent: the addon only shares what's done) for the goals `d.fish20`, `d.trade`, `w.discover5` and `w.craftTrade`. Every API is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step, and is verified at launch. Each goal joins the pool (and bumps `POOL_VERSION`) only once its API is verified.
- Fishing: items looted from fishing. Candidates: `LOOT_READY`/`LOOT_OPENED` with `IsFishingLoot()`, `GetNumLootItems`.
- Trades: a completed trade and its partner. Candidates: `TRADE_SHOW` with `UnitGUID("NPC")` for the partner, `TRADE_PLAYER_ITEM_CHANGED`/`GetTradePlayerItemLink` for what you give, and completion from `UI_INFO_MESSAGE` with `ERR_TRADE_COMPLETE` (matched through the game's own string, never hardcoded English). The partner counts when their GUID is another friend's community character.
- Crafted items: items your characters created, from `CHAT_MSG_LOOT` matched through the game's `LOOT_ITEM_CREATED_SELF` format string. A traded item that was created this week counts for `w.craftTrade`.
- Discoveries: the game's exploration message. Candidates: `UI_INFO_MESSAGE` or `CHAT_MSG_SYSTEM` matched through `ERR_ZONE_EXPLORED`/`ERR_ZONE_EXPLORED_XP`.
- Tests: matching through format strings, partner and item rules (pure). Manual: each tracker in game, with FriendProbe first.

