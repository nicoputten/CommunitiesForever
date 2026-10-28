# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.
E15 Doomsday: CF-52 and CF-53 now, CF-54 at launch, then CF-55, CF-56, CF-57 (see E15).

## E14 Planned runs (continued)

## E15 Doomsday (decided with Nico, 2026-10-28)
Daily and weekly goals, points per track, a streak and a crown, feats and a ladder, in the game, on the site (web E8) and in Discord (bot "Doomsday"). **`docs/DOOMSDAY.md` is the one description of the rules**; read it first. It replaces the three workshop designs (milestones, PvP ladder, dailies and weeklies; their PRs were closed unmerged).

Boards in `docs/design/doomsday-2026-10/`:
- `DD07AddonToday.dc.html`: Today, Week, chat lines, toast
- `DD08AddonBoard.dc.html`: Board, Ladder, Feats
- `AddonKit-doomsday.dc.html`: what WoW supports for Doomsday

The site's and the bot's boards are in their repos. Where a board and `DOOMSDAY.md` disagree, `DOOMSDAY.md` wins: the reset is 19:00 (a setting), goals are computed (not delivered through `Runs.lua`), and the crown gives no points.

None of the new APIs are verified on Forever. Each is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step (V73 to V78), and is checked at launch (from 2026-11-05). A guarded API that is missing leaves its field out (nil). A goal that needs it stays out of the pool, and the site shows no card or feat for it.

Compatibility (rule 8): only new optional fields in `chars.*`, feed entries and RECORD, within `pv` 1. Older clients ignore them, relay what they keep, and a relayed record without them changes nothing (nil = unknown). New stored fields are optional (nil-safe), so no migration unless a field changes meaning. Friends on an older addon show "no Doomsday data yet", never 0 points as if known.

Order:
1. CF-52 and CF-53 (data) now, guarded.
2. CF-54 (probe) at launch.
3. CF-55 (raw kills and the rules core) after CF-52, with its fields filled once CF-54 has answered.
4. CF-56 (goals tracked and shared) after CF-55.
5. CF-57 (the tab) after CF-56.
6. CF-58 (drop "Share my activity") any time, best before CF-56.

The site's WEB-58 needs CF-55's golden file.

### CF-52 PvP, duels and deaths in the record
- Per character (`chars.*.pvp`): lifetime honorable kills, current PvP rank (number and title), and this week's honor, if readable. Candidates: `GetPVPLifetimeStats`, `UnitPVPRank`/`GetPVPRankInfo`, `GetPVPThisWeekStats`. Updated on `PLAYER_PVP_KILLS_CHANGED` and at login.
- Per feed day and character:
  - `kills = { [zone] = n }`: honorable kills by zone (the zone where the kill counter rose)
  - `deaths = { { t, zone, cause } }`, where `t` is the time and `cause` is one of `fall`, `fire` (a campfire or other fire damage), `lava`, `drown`, `fatigue`, `player`, `creature` or `other`. Candidates: `ENVIRONMENTAL_DAMAGE` subevents in the combat log just before `PLAYER_DEAD`, or `C_DeathRecap`. Under the Midnight restrictions the combat log may be unavailable: then `cause` is `other`.
  - `duels = { { t, won, vs } }` where `vs` is the opponent's full character name as the game gives it (never split, rule 4). The winner comes from the `DUEL_WINNER_KNOCKOUT`/`DUEL_WINNER_RETREAT` system message, matched through the game's own format string, never hardcoded English.
- Battleground results are already in `runs` (`kind`, `won`, CF-23). Check that they are filled for Warsong Gulch, Arathi Basin and Alterac Valley once those are open.
- Sizes are capped like the rest of the feed (at most 50 deaths and 50 duels per day and character), and received data is cleaned (SYNC.md).
- `/cf self` shows the PvP line (kills, rank) for the current character.
- Tests: the pure parts (cause from the last environmental damage, duel result from a formatted message, caps, merge of the new fields) with busted. `SYNC.md` and `ARCHITECTURE.md` updated. A fixture for the new fields.

### CF-53 Loot, mounts, gold and play sessions in the record
- Per feed day and character:
  - `loot = { rare = n, epic = { { id, name, slot, level }, ... } }`: rare (blue) and epic (purple) items received. Each epic carries its item id, its name as the loot link shows it, its equip slot as the game's `INVTYPE_*` token (nil for non-equippable items) and the character's level when it was looted, for the site's "first epic" feat. Candidate: `CHAT_MSG_LOOT` for your own loot, quality and equip slot from `C_Item.GetItemQualityByID` / `C_Item.GetItemInfo`.
  - `notable = { [itemID] = n }`: items from a fixed watch list that you looted or created that day, for the profession feats. The watch list is a pure table in `src/core` (changing it needs an addon release); each entry says whether looting, creating or both count:
    - created: Arcanite Reaper, Arcanite Bar (the first Arcanite transmute), Mooncloth, Devilsaur Gauntlets, Devilsaur Leggings
    - looted (including quest rewards): Speckled Tastyfish (joined the Stranglethorn Fishing Extravaganza), Arcanite Fishing Pole and Hook of the Master Angler (the Extravaganza prize, so the winner)

    Item IDs are looked up from an item database when building, never guessed, and checked at launch with FriendProbe (`VERIFY.md`). Created items: candidate the `You create:` loot message (`LOOT_ITEM_CREATED_SELF` format string) on `CHAT_MSG_LOOT`, or `CHAT_MSG_TRADESKILLS`; verify which one fires on Forever.
  - `gold = { gained, spent }` in copper: what came in and went out that day, from `PLAYER_MONEY` deltas. Never shown as an amount: the site only compares.
  - `sessions = { { from, to } }`: login to logout times (server time), for night owl, early bird and the longest session.
  - `groups = { [guid] = true }`: community characters you were in a group with that day, for "social butterfly" and "biggest group night".
- Per character: `riding` (the riding skill rank, 0, 75 or 150), from the skill lines (as professions are read). This gives the mount feats.
- Profession feats that need no new data (the site derives them from `professions` and the feed's `ranks`): the first fishing catch, the flavour titles on Cooking, First Aid and Fishing 300, and "Jack of all trades".
- Caps and cleaning as in CF-52. Tests, docs and a fixture as in CF-52.

### CF-54 FriendProbe: what Forever tells about a kill, and realm time
Answers V73 to V78 in one run at launch. The results go to `docs/API-FINDINGS.md` and decide which fields CF-55 fills and which goals `docs/DOOMSDAY.md` can draw.
- `/fp pvp` switches kill logging on (it stays on after `/reload`; `/fp pvp off` stops it):
  - every `CHAT_MSG_COMBAT_HONOR_GAIN` with all its arguments, and whether the game's format string (`COMBAT_LOG_HONORGAIN` or the one that exists) gives the victim's name and rank
  - `PLAYER_PVP_KILLS_CHANGED` with the counters from `GetPVPSessionStats` and `GetPVPLifetimeStats`
  - for target, mouseover and each nameplate (`NAME_PLATE_UNIT_ADDED`) of an enemy player: `UnitName`, `UnitLevel` (`-1` on a skull), `UnitClass`, `UnitRace`, `UnitPVPRank` or the API that exists, and `UnitGUID`
  - whether `COMBAT_LOG_EVENT_UNFILTERED` can be registered, and if so each `PARTY_KILL` (with `GetPlayerInfoByGUID` on the victim's GUID) and the last damage source before `PLAYER_DEAD` (the killer's name)
  - `IsInGroup()` and `GetInstanceInfo()` type at each kill
- `/fp start` also logs `GetCurrentRegion()` (V77), and `GetGameTime()` next to `GetServerTime()` with the offset it gives (V78).
- Every call is guarded; a missing one logs `missing`, a secret value logs `secret`.
- The finding names which victim fields are readable at the moment of the honor message: from the message itself, or only from a target, mouseover or nameplate seen before. It decides whether the Hunt stays (`DOOMSDAY.md`, "The Hunt").
- If the killer's name is readable, propose stories for a Wanted poster (the enemy who killed us most this week, a bounty on them) and a revenge kill (killing your killer within 10 minutes).

### CF-55 Raw kills and the Doomsday core
After CF-52; its victim fields are filled once CF-54 has answered.
- Per feed day and character, `pvpKills = { { t, zone, name, lvl, myLvl, class, race, rank, solo, bg } }`, one entry per honorable kill:
  - `name`: the victim's full name as the game gives it (never split)
  - `lvl`: the victim's level, `-1` for a skull; `myLvl`: your level at the kill
  - `class`, `race`: tokens (`WARLOCK`, `Human`); `rank`: the victim's PvP rank number
  - `solo`: true when not in a group; `bg`: true inside a battleground
  - Each victim field only when CF-54 found it readable. They come from the honor message or from a short-lived cache by full name, filled from target, mouseover and nameplates (at most 200 names, 10 minutes). Otherwise nil.
- At most 100 entries per day and character. CF-52's `kills = { [zone] = n }` keeps counting every kill, also past the cap.
- `src/core/Doomsday.lua` (pure, rule 1) implements `docs/DOOMSDAY.md`:
  - the schedule: realm offset, day number and week number from the reset setting (default 19:00, `Runs.lua` value when known)
  - the draw: the PvE pools, the Hunt, the Skirmish, the Weekly bounty, `POOL_VERSION`, swaps and fallbacks
  - goal progress from facts per Doomsday day and week
  - points per track, kill points, the Duel slot, crossing out, the crown and the streak
  - the week's ladder as data (per track, the split per character, PvP details without Elo, the battleground block, PvP Virgin)
  - the feats the addon can derive from records (the same thresholds as the site, without "First in the group")
  - sprees (5 and 10 kills without dying) as feed badges, not points
- `tests/fixtures/doomsday-cases.json`, the golden cases shared with the site. They cover:
  - every kill band, a skull, an unknown level, solo, a community victim, the 4th kill of the same victim, battleground kills going to the block
  - the schedule at 19:00 and at another reset time, around midnight and the reset, including the week turning on Sunday
  - the draws for fixed days and weeks (3 categories, no repeats in a row), the swaps
  - every goal done and not done, progress adding up over two characters
  - a duel recorded by both sides, and a disputed one
  - the crown, crossing out, the streak over a missed day
  - a goal left out because its field is unknown

  `tests/spec/Doomsday_spec.lua` reads it with a small JSON reader in the test helpers (no new dependency) and checks `Doomsday` against it.
- Caps and cleaning of received `pvpKills` as for other feed fields (`SYNC.md`): numbers checked, strings stripped of `|`, unknown tokens dropped.
- Check the sync size of a week with 100 kills on each of 7 days (a test on `Serialize`). If it is over what CF-28 sends comfortably, lower the cap and note it in `DOOMSDAY.md`.
- `ARCHITECTURE.md` and `SYNC.md` updated. A fixture with `pvpKills`, and `Compat_spec` passes on earlier fixtures.

### CF-56 Goals tracked and shared
After CF-55.
- A service (`src/services/DoomsdayTracker.lua`) keeps the facts per Doomsday day and week, summed over your own characters:
  - quests per zone, levels, runs with bosses and companions
  - profession ranks and learned professions, logins per character, item level
  - kills, deaths and duels from CF-52/CF-55; groups, loot and sessions from CF-53
  - "Since the first login today/this week" values (level, item level, profession ranks per character) are a base taken the first time a character is seen in that day or week.
  
  It marks a goal done with its time as soon as the facts reach the target (`Doomsday` decides).
- New local trackers for the goals marked 56 in `DOOMSDAY.md`, not sent on their own (only "done" is shared), all guarded with `VERIFY.md` steps:
  - **Fishing:** items looted from fishing. Candidates: `LOOT_READY`/`LOOT_OPENED` with `IsFishingLoot()`, `GetNumLootItems`.
  - **Trades:** a completed trade and its partner. Candidates:
    - `TRADE_SHOW` with `UnitGUID("NPC")` for the partner
    - `TRADE_PLAYER_ITEM_CHANGED`/`GetTradePlayerItemLink` for what you give
    - completion from `UI_INFO_MESSAGE` with `ERR_TRADE_COMPLETE`, matched through the game's own string
  - **Crafted items:** from `CHAT_MSG_LOOT`, matched through the game's `LOOT_ITEM_CREATED_SELF` format string.
  - **Discoveries:** from `UI_INFO_MESSAGE` or `CHAT_MSG_SYSTEM`, matched through `ERR_ZONE_EXPLORED`/`ERR_ZONE_EXPLORED_XP`.
  
  Each of these goals joins the pool (a `POOL_VERSION` bump) only once its API is verified.
- Stored: `self.goals = { days = { [n] = { set, swapped = { [id] = originalId }, done = { [id] = at }, at } }, weeks = { [week] = { ... } }, streak = { n, last }, best }`. 14 days and 2 weeks are kept: the addon keeps no all-time totals (Nico: the site and the bot have them). New optional data, so no migration; code reading it handles nil.
- RECORD gets the optional field `goals` (rule 8, within `pv` 1): the last 7 Doomsday days and the current and previous week (`set`, `swapped`, `done`, `at`), `streak`, `best`, `pool` (the pool version) and `reset` (the reset setting the addon used).
  - It is always sent: there is no "Share my activity" (CF-58).
  - A completion bumps the version through the feed's debounce (at most once per 60 s).
- **Receiving:**
  - Per day and per week, the newer `at` wins.
  - Cleaned and capped: ids at most 24 characters, at most 3 per set, 7 days and 2 weeks, numbers ≥ 0.
  - Ids the client doesn't know (a newer pool) are kept, counted, and shown as "a goal from a newer version".
- The reset setting from `Runs.lua` (`CF_RUNS.doomsday`) is passed on in HELLO as the optional `dd = { reset, changedAt }`. The newest `changedAt` wins and is stored (`settings.doomsdayReset`), so friends without the uploader get it too.
- **Compatibility:** older clients ignore `goals` and `dd`, and drop them when relaying. A relayed record without `goals` is nil = unknown, so the stored one stays.
- `/cf doomsday` prints today's and this week's goals with progress, the swaps, the streak and this week's points (`Describe`).
- `docs/SYNC.md` (field table, caps, merge rule) and `docs/ARCHITECTURE.md` (data model) updated. A fixture with `goals` for the next release's capture. `Compat_spec` passes.
- Tests (busted): progress per goal over two characters, the day rolling over at the reset, the week on Sunday, the merge of `goals`, the setting's newest-wins rule.
- **Manual (`VERIFY.md`):**
  - Finish 10 quests on two characters and see the daily done.
  - The day rolls over at 19:00 realm time.
  - Two accounts: A's completion shows on B within a minute.

### CF-57 Doomsday tab, chat lines and the toast
After CF-56. As the boards `DD07AddonToday` and `DD08AddonBoard` show, built with the kit (pools, `Kit.scrollArea`, `Kit.toast`), as the other tabs.
- A tab **Doomsday** after Dungeons, with:
  - **Today:** your 3 PvE dailies, the Hunt and the Skirmish, with progress ("7/10") or a check with its time, the time to the reset, the swap mark with the original in its tooltip, and the Duel slot (who you dueled, who's still open). Plus today's points (PvE and PvP), a kill summary ("9 kills: 4 near level, 2 solo, 1 above"), the streak, and who has the crown.
  - **Week:** the 3 PvE weeklies and the Weekly bounty with progress (for the bounty, what's still needed: "Paladin, Priest, Hunter"), this week's points per track and per character, the streak.
  - **Board:** every friend's goals today, from synced `goals`. A finished goal is checked and struck through with its time, and a friend is crossed out when all 3 PvE dailies are done. The crown, streaks, today's and this week's points.
  - **Ladder:** this week only, PvE and PvP side by side, each with its own ranking. Rows expand to characters. PvP Virgin is shown, not ranked. "All-time totals on the site."
  - **Feats:** your characters' feats as far as the addon can derive them, newest first.
  - The "everything done" state ("Doomsday done. Go touch grass.") and "Synced with Mira 3 min ago".
- Chat lines in the addon's chat style, as on the board:
  - a daily done
  - the Hunt done
  - a kill worth bonus points
  - someone else took the crown
  - a goal swapped for you
  
  A setting **Doomsday in chat** (on by default).
- A **toast** "First to finish today!" when you take the crown: a gold glow, fading in over 400 ms and sliding 12 px, that just appears when "Ambient effects" is off.
- The character card gets a PvP line: lifetime honorable kills, rank with our title ("Stone Guard, a.k.a. Mailbox Menace"), this week's PvP points, or **PvP Virgin**.
- Friends without Doomsday data show "no Doomsday data yet", never 0.
- Tests: the pure parts (rows, sorting, crossing out, the crown, reset times, chat texts) with busted. Manual steps in `VERIFY.md`.

### CF-58 Drop "Share my activity"
Decided with Nico (2026-10-28): there is no sharing toggle. A friend who doesn't want to share uninstalls the addon. This makes the feed, Doomsday's `goals` (CF-56) and their relaying simpler.
- The setting **Share my activity** goes: from Settings (the Sharing group keeps "Receive group asks"), from onboarding step 5, from `Store` defaults and from `FeedTracker`. A stored `settings.shareActivity` is ignored (and may be cleared); no migration needed.
- `Merge.outgoingRecord` always sends `feed` (and, after CF-56, `goals`). The addon never sends `false` for either.
- **Receiving** (rule 8): released clients may still send or relay `feed = false`. It now means "nothing sent": the stored feed of that friend stays, as for a record without `feed`. The same holds for `goals = false`.
- The Activity tab's footer loses "Activity is shared only by friends who turned on Share my activity".
- `docs/SYNC.md` (RECORD fields, merge rule), `docs/ARCHITECTURE.md` (settings, RECORD) and `docs/DOOMSDAY.md` (if it mentions sharing) updated.
- Tests (busted): `outgoingRecord` without the setting; a received `feed = false` keeps the stored feed; `Compat_spec` passes on earlier fixtures.
- The site does the same on its side (web WEB-55): `false` from released clients means nothing sent.
