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

The site's WEB-58 needs CF-55's golden file.

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
  - It is sent only when "Share my activity" is on, and is `false` when it is off (as `feed`, CF-28).
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
  - Two accounts: A's completion shows on B within a minute, and turning sharing off on A removes it on B.

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
- **Feats and sprees** (moved here from CF-55, Nico 2026-10-28): the feats the addon can derive from the records it holds (the site's thresholds, web WEB-56, without "First in the group") and spree badges (5 and 10 kills without dying) in the feed, both in `src/core/Doomsday.lua`.
- Tests: the pure parts (rows, sorting, crossing out, the crown, reset times, chat texts, feats, sprees) with busted. Manual steps in `VERIFY.md`.
