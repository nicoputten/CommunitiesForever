# Doomsday: rules

Decided with Nico, 2026-10-28. This file is the one description of Doomsday: daily and weekly goals, points, the streak, the crown, feats and the ladder. The addon (E15), the site (web E8) and the bot (bot "Doomsday") all follow it. Boards: web `design/boards/doomsday-*`, the bot's `design/boards/bot-doomsday-*` and this repo's `docs/design/doomsday-2026-10/`. Where a board and this file disagree, this file wins. The boards differ from it on three points:
- The reset is 19:00, not 09:00.
- The goal list is computed, not delivered through `Runs.lua`.
- The first-to-finish crown gives no points (version B).

It merges what the three workshops of 2026-10-28 designed apart: milestones, the PvP ladder, and dailies and weeklies. `docs/LADDER.md` and `docs/DAILIES.md` were never merged; this file replaces them.

Product rule: **recommend, never restrict.** Goals are suggestions with points, never conditions to play. Gold is never shown as an amount. No pronouns in texts ("Somebody pay a visit."). Names: friends by display name, characters by full name, never BattleTags or Discord IDs.

## Two tracks
- **PvE:** quests, levels, dungeons, professions, playing together.
- **PvP:** kills, duels, the Hunt.

The two are always shown side by side ("PvE 85 · PvP 240"), **never added together**, and each has its own ranking. A friend who never does PvP is never ranked against gankers: a friend who never fought, on any character, is a **PvP Virgin** and is not ranked on the PvP ladder. An honorable kill, a duel or a finished battleground (won or lost, `runs` with `kind = "pvp"`, CF-23) on any character ends it; PvP points from goals without a fight (emotes, the PvP flag) count on the PvP track but don't end it (Nico, 2026-11-03, CF-78). A PvP Virgin with such points shows as Conscientious Objector with the points. The ladder's input is `foughtEver` (the older name `killedEver` is read when it is missing).

## Per friend
Everything counts per friend (BattleTag): any of your characters counts, and progress adds up across characters (6 quests on one, 4 on another = 10). "Another friend" means a character of a different BattleTag, as the `with` lists of runs already use; your own alts don't count as a friend.

## Schedule
- A **Doomsday day** runs from the reset time to the next one. The default reset is **19:00 realm time**, a group setting (Nico, 2026-10-28: "make it a changeable setting"). A day is named after its start: the weekday plus the part of the day of the reset hour, 05–11 "morning", 12–16 "afternoon", 17–22 "evening", 23–04 "night" ("Doomsday · Tue evening", the span "Tue 19:00 → Wed 19:00"). Times after midnight carry their weekday ("done Wed 00:04"); the countdown reads "resets Wed 19:00 · in 6 h 51 m" (Nico, live test 2026-10-29).
- **Realm time** is the game's clock (`GetGameTime`, unverified: V78). The addon gets the realm's offset from UTC as the difference between `GetGameTime()` and `GetServerTime()`, rounded to 15 minutes, so daylight saving follows the realm. The site has the realm's IANA time zone as a setting (default `Europe/Paris` for EU realms).
- **Everyone has the same day** (Nico, 2026-10-28: friends play from the Netherlands, the UK and Thailand). The day boundary is always realm time, never the PC's. Without `GetGameTime` the addon takes the offset the site sends (`offset`, `offsetUntil`, `offsetAfter` below), and without that CET/CEST (the EU summer-time dates). **Clock times shown** ("done Wed 00:04", the reset, the span, the day's name) are stored as server time (UTC) and shown in each player's own time: the addon uses the PC clock, the site the viewer's time zone (Nico, 2026-10-29: "save UTC but display local time"). Only the bot, which posts one message for everyone, uses realm time. "resets in 3 h 12 m" is the same for all.
- **Day number:** `n = floor((serverTime + realmOffset - resetSeconds) / 86400)`, where `resetSeconds` is the reset time in seconds after midnight (19:00 = 68400). Day 0 started on Thursday 1970-01-01.
- **Week:** a Doomsday week starts on **Sunday** at the reset time. `week = floor((n + 4) / 7)`: day 3 (Sunday 1970-01-04) starts week 1. Not tied to the game's weekly reset or its honor week.
- **The setting:** the reset time lives on the site (the Discord page, admin: hours and minutes in realm time). It reaches the addon through `Data\Runs.lua`, written by the uploader, and from there through HELLO (`dd`) to friends without the uploader: the newest `changedAt` wins. Without it, the addon uses 19:00. A change takes effect from the next reset, never in the middle of a day. Agreed with the site (web PR #108), every field optional:
  - `CF_RUNS.doomsday = { reset, changedAt, offset, offsetUntil, offsetAfter, schedule }` (`schedule`: CF-68, "Schedule from the site" below)
  - `reset`: the reset in force, seconds after realm midnight. The site sends a new reset only from the reset it takes effect at, so the addon applies it as given.
  - `changedAt`: when that reset took effect; 0 while it was never changed.
  - `offset`: the realm zone's UTC offset now, in seconds east; `offsetUntil`: the server time of its next change; `offsetAfter`: the offset from then on. Both are left out when the zone has no change within 400 days.
- Screens show the time left: "New goals in 3 h 12 m" for the day, "Week resets Sun 19:00 · in 3 d 5 h" for the week (CF-61).

## Goals
Every Doomsday day each friend gets:
- **3 PvE dailies** from 3 different categories
- **the Hunt:** today's enemy race and class combination
- **a Skirmish:** one goal from the Skirmish pool
- **the Duel slot:** your first duel with each friend that day

Every Doomsday week each friend gets:
- **3 PvE weeklies**
- **1 PvP Weekly bounty**

**Points**

| What | PvE | PvP |
|---|---|---|
| A daily done (the PvE dailies, the Skirmish) | each goal's points, from the pool: 1, 3 or 5 | 1, 3 or 5 |
| The Hunt | | 5 |
| A weekly done (the PvE weeklies, the Weekly bounty) | each goal's points, from the pool: 5, 10 or 15 | 5, 10 or 15 |
| A kill | | see "Kill points" |
| A duel, per pair of friends, the first one of the day | | win 3 · loss 1 |

Each goal counts once per day or week. Feats give no points. A day's total varies with the draw.

**Points per goal (CF-69, Nico 2026-11-03).** Every goal scores by its size, the `points` of its catalogue entry (`Doomsday.pointsFor(id, pool)`):
- **A day keeps the points of the pool version it was drawn in.** Each day and week records it with its set (`goals.days[n].pool`, `goals.weeks[w].pool`, `Doomsday.entryPool`): the entry's `pool`, else the friend's `goals.pool`, else 1. An addon before CF-69 sends no entry `pool`; the addon sends `pool = 1` for its own entries recorded before CF-69, as pool version 1 was the only one then.
- **Pool version 1** scores flat: 5 for a PvE daily, the Skirmish and the Hunt, 15 for a PvE weekly and the Bounty. From **pool version 2** the goal's own points; a goal without a size yet scores flat; the Hunt stays 5.
- An unknown id (a newer pool) counts nothing: its track isn't known.
- Both sides count a friend's points from the `done` ids and the entry's pool version, never from a total. Pinned by the `pointsPerGoal` golden cases.
- The crown, crossing out and the streak count goals, not points: unchanged.

**The draw.** Goals are computed, never chosen and never sent by the site, so every friend sees the same set without the uploader. One function draws them in the addon (`src/core/Doomsday.lua`) and the site (its TypeScript copy):
- It draws from the day or week number, a salt per slot, and `Doomsday.POOL_VERSION`. Base: `pick(n, salt, count) = ((n * 2654435761 + salt) % 4294967296) % count + 1`, which is exact in Lua 5.1 doubles and JavaScript numbers.
- The 3 PvE dailies come from 3 different categories.
- No goal is drawn on two days running, or in two weeks running.
- Lists are drawn in the order written here.

CF-55 fixes the exact algorithm in `tests/fixtures/doomsday-cases.json` (golden cases: draws for fixed days and weeks, goal progress, points). The site copies that file and tests against it unchanged, so the two copies can't drift apart. A rule change updates this file, the golden file and both copies in the same release.

**Swaps.**
- When none of a friend's characters can do a goal (the "Can't do when" column), it is swapped for its fallback, for that friend only. If the fallback is in the set already, or can't be done either, the next goal in pool order that can be done takes its place.
- A swap is fixed for the day once made. It recommends, it doesn't restrict: the original may still be done, but only the swapped goal counts.
- Screens show a small mark, with the original in the tooltip ("Instead of: Raise Cooking, First Aid or Fishing").

**Pool version.** `Doomsday.POOL_VERSION`.
- A goal that waits for data (column "Data": the addon story whose tracker it needs, unverified until launch) joins the pool only in the release after its API is verified. That release bumps the version.
- A goal that needs a field the probe found unreadable stays out. If a pool is then empty, the slot stays empty.
- Ids are never reused or renamed. A retired goal keeps its id in the catalogue, marked retired.

**Who decides "done".** The addon. It sees the events as they happen, with their time, and the Doomsday day doesn't line up with the feed's realm days (midnight to midnight). It records `done = { [id] = time }` per day and week and shares it (CF-56). The facts behind it are counted live per Doomsday day and week and stay on the player's computer (CF-56, Nico 2026-10-28); progress starts on the day the update is installed. A day's set holds at most 5 ids (3 PvE dailies, the Skirmish, the Hunt as `hunt`), a week's 4 (3 PvE weeklies, the Bounty). The site stores it and counts the points from it, never from an addon total. Kill points are the exception: both sides compute them from the raw kills (`pvpKills`, each with its time), with the same golden cases.

## Short labels (CF-61)
Each goal's column title on the addon's Board and the site's and bot's boards: at most 10 characters, the same everywhere (`Doomsday.SHORT_LABELS`). The Hunt is "Hunt". A new goal gets its label in the same change.
| Goal | Short label |
|---|---|
| `d.quests10` | 10 quests |
| `d.quests20` | 20 quests |
| `d.zone5` | 5 in zone |
| `d.zones3` | 3 zones |
| `d.shared3` | 3 shared |
| `d.questUp` | Hard quest |
| `d.groupQuest` | Group Q |
| `d.classQuest` | Class Q |
| `d.questBurst` | Quick 3 |
| `d.accept5` | Take 5 |
| `d.level` | Level |
| `d.altLevel` | Alt level |
| `d.ilvl` | Item level |
| `d.cleanLevel` | Clean lvl |
| `d.levels2` | 2 levels |
| `d.dingDungeon` | Deep ding |
| `d.dingFriend` | Duo ding |
| `d.lowbie` | Lowbie |
| `d.dungeon` | Dungeon |
| `d.dungeonFriend` | Group run |
| `d.bosses3` | 3 bosses |
| `d.dungeonQuest` | Dungeon Q |
| `d.cleanRun` | Clean run |
| `d.speedRun` | Speed run |
| `d.newDungeon` | Fresh run |
| `d.dungeons2` | 2 dungeons |
| `d.skill5` | Skills |
| `d.secondary` | Secondary |
| `d.craft5` | Craft 5 |
| `d.gather10` | Gather 10 |
| `d.newRecipe` | Recipe |
| `d.craftGreen` | Fine craft |
| `d.cook5` | Cook 5 |
| `d.cook15` | Cook 15 |
| `d.cookSkill5` | Cooking +5 |
| `d.cookKinds3` | 3 dishes |
| `d.campfire` | Campfire |
| `d.campfireBuff` | Cozy fire |
| `d.eatOwn` | Home meal |
| `d.cookRecipe` | New dish |
| `d.feedFriend` | Feed pal |
| `d.fish20` | 20 fish |
| `d.fishZones` | Fish spots |
| `d.fish50` | 50 fish |
| `d.fishSkill5` | Fishing +5 |
| `d.fishKinds3` | Fish kinds |
| `d.fishFriend` | Fish buddy |
| `d.fishNight` | Night fish |
| `d.bandage3` | Bandages |
| `d.bandageUp` | Bandage up |
| `d.bandage10` | 10 bandage |
| `d.bandageUse3` | Bandage x3 |
| `d.bandageFriend` | Medic |
| `d.aidSkill5` | Aid +5 |
| `d.bandageKinds2` | 2 bandages |
| `d.chars2` | 2 chars |
| `d.chars3` | Play 3 |
| `d.switchUp` | Switch up |
| `d.dustOff` | Dust off |
| `d.earlyBird` | Early bird |
| `d.nightOwl` | Night owl |
| `d.session1h` | 1h session |
| `d.deathless` | No deaths |
| `d.jump100` | 100 jumps |
| `d.groupFriend` | Group up |
| `d.trade` | Trade |
| `d.questTogether` | Duo quest |
| `d.chatHello` | Chat |
| `d.sameZone` | Neighbours |
| `d.online3` | Full house |
| `d.carry` | Carry |
| `d.whisper` | Whisper |
| `d.wave` | Wave |
| `d.groupPic` | Group pic |
| `d.discover1` | Discover |
| `d.discover3` | Discover 3 |
| `d.roam4` | Roam 4 |
| `d.newZone` | New zone |
| `d.places10` | 10 places |
| `d.swim` | Swim |
| `d.nostalgia` | Nostalgia |
| `d.daredevil` | Daredevil |
| `d.flight` | Fly |
| `d.newFlight` | New flight |
| `d.hearth` | Hearth |
| `d.bind` | New home |
| `d.ride` | Ride |
| `d.crossSea` | Cross sea |
| `d.summoned` | Summoned |
| `d.kills30` | 30 foes |
| `d.elite` | Elite |
| `d.rareMob` | Rare hunt |
| `d.bigFoe` | Big foe |
| `d.streak20` | Streak 20 |
| `d.weaponSkill` | Weapon +5 |
| `d.duoHunt` | Duo hunt |
| `d.rare` | Rare loot |
| `d.green5` | 5 greens |
| `d.reward` | Reward |
| `d.coins10` | 10 purses |
| `d.equipNew` | New gear |
| `d.treasure` | Treasure |
| `d.vendorSale` | Sell |
| `d.vendorBuy` | Shopping |
| `d.auctionPost` | Auction |
| `d.auctionBuy` | Bargain |
| `d.mailFriend` | Mail pal |
| `d.mailbox` | Mailbox |
| `d.profit` | In profit |
| `d.repair` | Repair |
| `d.trainer` | Train |
| `d.wellFed` | Well fed |
| `d.buffFriend` | Buff pal |
| `d.restock` | Restock |
| `d.bank` | Bank |
| `d.tidyBags` | Tidy bags |
| `d.potion` | Potion |
| `d.scrolls10` | 10 scrolls |
| `w.days3` | 3 days |
| `w.days5` | 5 days |
| `w.chars3` | 3 chars |
| `w.levels3` | 3 levels |
| `w.altLevels2` | Alt 2 lvls |
| `w.quests50` | 50 quests |
| `w.zones5` | 5 zones |
| `w.dungeons3` | 3 dungeons |
| `w.dungeonsDiff3` | 3 distinct |
| `w.dungeonFriends2` | Trio run |
| `w.fullClear` | Full clear |
| `w.skill25` | 25 skill |
| `w.cap` | Skill cap |
| `w.newProf` | New prof |
| `w.ilvl3` | Item lvl+3 |
| `w.friends3` | 3 friends |
| `w.rare5` | 5 rares |
| `w.session2h` | 2h session |
| `w.discover5` | Discover 5 |
| `w.craftTrade` | Craft gift |
| `p.frontLine` | Front line |
| `p.punchUp` | Punch up |
| `p.loneWolf` | Lone wolf |
| `p.untouchable` | Untouched |
| `p.variety` | Variety |
| `p.ranked` | Ranked |
| `p.flex` | Flex |
| `p.boo` | Boo |
| `p.punchUp5` | Punch up 5 |
| `p.punchDown5` | Punch down |
| `b.zone25` | Zone 25 |
| `b.allClasses` | Classes |
| `b.allRaces` | Races |
| `b.ranked5` | 5 ranked |
| `b.kills50` | 50 kills |
| `b.spree10` | Spree 10 |
| `b.hunt3` | 3 hunts |
| `b.duels3` | 3 duels |
| `b.days5` | Kill days |

## The algorithm, exactly (CF-55)
Fixed with Nico on 2026-10-28 and pinned by `tests/fixtures/doomsday-cases.json` (the addon's `src/core/Doomsday.lua` passes it; the site's copy must too). Where the sections above leave room, this decides.

**Pool version 1** (`Doomsday.POOL_VERSION = 1`):
- PvE dailies and weeklies: the goals with Data **now**.
- Skirmish: `p.frontLine`, `p.loneWolf`, `p.untouchable`. Bounty: `b.zone25`, `b.kills50`, `b.spree10`, `b.duels3`, `b.days5`. These need only the kill's time, zone and `solo`, and deaths.
- **No Hunt** yet: the slot is empty until the pool version that follows the CF-54 probe (victim race and class). The same bump adds `p.punchUp`, `p.variety`, `p.ranked`, `b.allClasses`, `b.allRaces`, `b.ranked5`, `b.hunt3` where their fields are readable, and the goals marked 52, 53, 56 whose APIs are verified.
- Pool order is the order of the tables in this file.

**Salts:** Hunt 1, Skirmish 2, Bounty 3, zone of the day 4, zone of the week 5, the 3 PvE dailies 11, 12, 13, the 3 PvE weeklies 21, 22, 23.

**The draw, never twice in a row.** It runs forward from the **epoch**, day `20761` (the Doomsday day that starts on Wednesday 2026-11-04, launch), and week `2966` (the week holding it). Each day excludes the previous day's draw (before swaps); the epoch day and any day before it exclude nothing. Weeks the same.
- **PvE dailies:** for slot 1, 2, 3: the candidates are the pool's goals, in pool order, whose category isn't taken yet and that weren't in the previous day's dailies; slot k takes `candidates[pick(n, 10 + k, #candidates)]`. If no candidate is left, the previous day's goals are allowed again (categories still differ).
- **Skirmish, Bounty:** `available = pool without the previous draw` (the whole pool when that leaves nothing); `available[pick(n, salt, #available)]`.
- **PvE weeklies:** as the dailies without categories: slot k takes `candidates[pick(week, 20 + k, #candidates)]` from the pool minus the goals already chosen and minus last week's.
- **The Hunt** (once in the pool): per hunting faction, the 20 combinations in list order minus the previous day's combination (none on the epoch), `available[pick(n, 1, #available)]`.
- **Zone of the day / week:** `band.zones[pick(n, 4, #zones)]` / `pick(week, 5, #zones)`, the band by level (20–29, 30–44, 45–54, 55–60); below 20 there is none.

**Schedule from the site (CF-68, web WEB-78).** The site's owner can change future days and weeks (Mission pool page). The site sends only the changed ones, as `CF_RUNS.doomsday.schedule` (from the uploader's `Data\Runs.lua`, and between addons as `SCHED`, docs/SYNC.md); every other day and week is the normal draw. Pinned by the `scheduleCheck` and `scheduled` cases of `tests/fixtures/doomsday-cases.json`.
- Shape: `{ v, days = { ["<n>"] = { daily = { id, id, id }, skirmish = id } }, weeks = { ["<week>"] = { weekly = { id, id, id }, bounty = id } } }`. `v`: the site's server time of its last change, an integer > 0. Keys are day and week numbers as decimal strings (integer keys are accepted too). The site sends every slot of a changed day or week in full, and `{ v }` alone once nothing is changed any more. No Hunt in this version: a later story adds `hunt = { Horde = "<Race>:<CLASS>", Alliance = ... }` as an optional field when the Hunt goes on.
- **Check** (`Goals.cleanMissionSchedule(raw, day, week)`, with the reader's current day and week): not a table, `v` not an integer > 0, or `days` / `weeks` present but not a table: no schedule. A key that isn't an integer drops that entry. Days are kept from `day - 1` to `day + 16`, weeks from `week - 1` to `week + 3`. An id is a string of 1 to 24 letters, digits and dots. `daily` / `weekly` count only as exactly 3 valid, distinct ids, else the field is dropped; `skirmish` / `bounty` only as a valid id. Any other field is dropped, and so is a day or week left empty. `days` / `weeks` are left out when empty: `{ v }` is a valid schedule. A newer `v` replaces the whole schedule (so `{ v }` clears an older one); a `v` more than 5 minutes ahead of server time is ignored.
- **Use** (`Doomsday.scheduledDraw(n, schedule)` / `scheduledWeek`): a listed `daily` is used when all 3 ids are in the reader's `pool("daily")` of its pool version, else the whole list is the normal draw's dailies (an id of a newer pool, or a catalogue id without `since`). A listed `skirmish` is used when it is in `pool("skirmish")`, else the normal draw's. Weeks the same with `weekly` and `bounty`. No category or "not twice running" check on the reader's side: the site keeps to them.
- The "never twice in a row" chain runs on the normal draw only, so a scheduled day doesn't change the days around it. The Hunt is always the normal draw's.
- Swaps (below) then run on that set, per friend, as on any day (`goalsForDay(n, situation, version, schedule)`).
- **A day or week that has started keeps the set already recorded** in `goals` (addon only); a schedule that arrives later doesn't change it. (The site locks today and tomorrow, and a week 24 h before it starts, so a change reaches everyone in time.)

**Swaps.** Per friend, from a **situation** summed over that friend's characters: `chars`, `below60`, `altBelow60` (characters below 60 other than the highest one), `highest`, `highestToday` (the highest level that played that day), and the booleans `ilvlReadable`, `dungeonInRange`, `hasProfession`, `hasFishing`, `hasCraftingProfession`, `professionBelow300`, `friendQuestLog`. **A missing field never swaps** (unknown counts as "can do").
- The catalogue's goals (CF-70) add: `below20` (characters below 20), `hasCooking`, `hasFirstAid`, `hasGathering` (Herbalism, Mining or Skinning), `riding` (a character with riding, CF-53), `friends` (other friends with a character in the community), `canBuff` (a character of a class with a buff it can cast on others: Druid, Mage, Paladin, Priest, Shaman, Warlock) and `idle7` (characters not played for 7 days or more). `riding`, `canBuff` and `idle7` are left out unless every character tells (a riding skill, a class, a last login). Checks: "no profession at all" counts Cooking, First Aid and Fishing too; `d.nostalgia` reads `highest` (below 30); `d.dingDungeon` needs both a character below 60 and one in range of a dungeon.
- "Only one character below 60" (`d.altLevel`, `w.altLevels2`) is read as `altBelow60 = 0`: no character below 60 besides the highest one.
- `p.frontLine` can't be done when the highest level that played today (else the highest) is below 20; its zone comes from that level.
- The replacement: the fallbacks in order (`w.cap`: `w.skill25`, then `w.quests50`), skipping ones already in the set or that can't be done; then the next goals in pool order after the original, wrapping around, with the same skips. Slots are swapped in set order (dailies, then the Skirmish; weeklies, then the Bounty), so an earlier swap takes its replacement first. If nothing fits, the original stays.

**Kills.** A friend's kills are taken in time order. The "4th or later kill of the same victim name" counts per track (world, battleground) and Doomsday day; a kill without a name never counts as a repeat. A skull is 3 whatever your level; without your level (or the victim's) a kill is "level unknown" (1). Solo adds 1 only to a kill worth more than 0. Battleground kills score the same way on their own track.

**The Duel slot.** Per pair of friends and Doomsday day, the earliest record of each side. Both records: the winner per both, else disputed (nobody scores). One record: as recorded. Only opponents that are another friend's community character count (not strangers, not your own alts).

**Crown:** the first to cross out by the time of the last of the 3 PvE dailies; equal times go to the lower friend key (BattleTag). **Streak:** today counts once a goal is done; a today without one yet doesn't break the run to yesterday. **Ladder:** PvE ties on goals done, then the name; PvP ties on goals done, then counted kills, then the name; movement = last week's rank minus this week's ("new" when not ranked last week).

## The crown, crossing out, the streak
- **Crossed out:** a friend's name is struck through on the board once all 3 **PvE** dailies are done. The PvP goals don't count for that, so a PvE-only friend can finish.
- **The crown:** the first friend to finish all 3 PvE dailies that day, by the time the addon recorded. **No points** (version B): the race is for fun, the points are about playing. The crown holds until the next reset.
- **Streak:** Doomsday days in a row with at least one goal done, in either track. A day with none ends it. The best ever is kept. No points.

## Celebrations (CF-67, addon only)
The addon celebrates Doomsday moments with a banner and a game sound (decided with Nico, 2026-11-02; the look is on
the boards in `docs/design/celebrations-2026-11/`). No points, nothing sent; the site and the bot don't show them.
- **Your moments:** each daily done (the PvE dailies, the Skirmish, the Hunt), **day complete**, each weekly and the
  Bounty, a feat unlocked.
- **Day complete** is the moment you are crossed out: all 3 PvE dailies done, the same moment as the crown (the crown
  shows on that banner when you were first). A PvE-only friend gets it too.
- **Big feats:** PvP rank 6 or higher, level 60, the first epic, a mount, an epic mount, 1,000 honorable kills or
  more, and **first in the group**: none of your other characters and no friend's character in the records the addon
  holds has that feat. The rest are medium.
- **Friends' moments:** only a day complete, a weekly done or a big feat, as a quiet line without sound; only when it
  happened after your login and at most 15 minutes ago.
- **Nothing old, nothing twice:** no banner for what happened before the update or login (feats found in the first
  10 s after login count as known), none again after a `/reload`.
- Points on a day-complete banner are shown per track side by side, never added together.

## Kill points (world kills)
A kill inside a battleground (`bg = true`) never counts here: it goes to the battleground block.

A kill is **counted** unless:
- the victim's full name is a character of the selected community (never split, rule 4), or
- it is the 4th or later kill of the same victim name by the same friend on that day.

Points for a counted kill, from `diff = victim level - own level`:

| Victim | Points |
|---|---|
| level unknown | 1 |
| skull (`-1`) | 3 |
| `diff <= -4` (4 or more below) | 0 |
| `-3 <= diff <= 2` | 1 |
| `diff >= 3` (3 or more above) | 2 |

**Solo:** +1 when `solo` is true and the kill was worth more than 0. Without the own level, the kill counts as "level unknown".

Where a victim field was guessed or unknown, the site shows "≈" next to the number.

## PvE goals
Data: **now** = the addon records it today. **52**, **53**, **56** = trackers from CF-52, CF-53 and CF-56 (unverified until launch). **CF-71** to **CF-81** = the E18 story that tracks it (`docs/STORIES.md`), with the `VERIFY.md` checks it waits for; until then it has no `since` and is never drawn.

The PvE dailies are the approved catalogue (`docs/DOOMSDAY-CATALOGUE.md`, CF-70) in its order, with its 15 categories and sizes (Points: 1, 3 or 5; scored from the pool version CF-69 names, until then every daily scores as "Points" above).

### PvE dailies

| Id | Category | Goal | Points | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|
| `d.quests10` | quests | Finish 10 quests | 3 | 10 quests handed in that day | now | |
| `d.quests20` | quests | Finish 20 quests | 5 | 20 quests handed in that day | now | |
| `d.zone5` | quests | Finish 5 quests in one zone | 3 | 5 quests in one zone (feed `quests` by zone) | now | |
| `d.zones3` | quests | Hand in quests in 3 zones | 3 | quests in 3 zones that day | now | |
| `d.shared3` | quests | Share 3 quests with a friend | 3 | at some moment that day, your quest log and one friend's synced log share 3 quests | now | no friend's quest log known → `d.quests10` |
| `d.questUp` | quests | Finish a quest above the character's level | 3 | a quest handed in whose level (from the quest log) is higher than the character's level at the hand-in | CF-71 | all characters at 60 → `d.quests10` |
| `d.groupQuest` | quests | Finish a group quest | 3 | a quest handed in that the quest log marked as a group quest (`suggestedGroup` > 0) | CF-71 | |
| `d.classQuest` | quests | Finish a class quest | 3 | a quest handed in whose quest log header is the character's class name | CF-71 | |
| `d.questBurst` | quests | Hand in 3 quests within 10 minutes | 3 | 3 quests handed in by one character within 10 minutes | CF-71 | |
| `d.accept5` | quests | Take on 5 new quests | 3 | 5 different quests accepted that day (by quest ID; abandoning and taking one again counts once) | CF-71 | |
| `d.level` | levels | Gain a level | 3 | a character gains a level that day | now | all characters at 60 → `d.quests20` |
| `d.altLevel` | levels | Gain a level on an alt | 3 | a level on any character but your highest | now | only one character below 60 → `d.quests10` |
| `d.ilvl` | levels | Raise an item level | 3 | a character's item level is higher than at its first login that day | now | item level unreadable → `d.quests10` |
| `d.cleanLevel` | levels | Gain a level without dying | 3 | a level on a character with no death between that level and the previous one | 52 | all characters at 60 → `d.quests20` |
| `d.levels2` | levels | Gain 2 levels | 5 | 2 levels over all characters | CF-72 | all characters at 60 → `d.quests20` |
| `d.dingDungeon` | levels | Gain a level inside a dungeon | 3 | a level gained while the instance type is `party` | CF-72 | all characters at 60 or no character in range of a dungeon → `d.level` |
| `d.dingFriend` | levels | Gain a level in a group with a friend | 3 | a level gained while grouped with a friend's community character | CF-72 | all characters at 60 → `d.groupFriend` |
| `d.lowbie` | levels | Gain a level on a character below 20 | 3 | a level on a character that was below 20 before it | CF-72 | no character below 20 → `d.altLevel` |
| `d.dungeon` | dungeons | Run a dungeon | 5 | a finished party run (feed `runs`) | now | no character in range of a dungeon (`Dungeons`) → `d.quests10` |
| `d.dungeonFriend` | dungeons | Run a dungeon with a friend | 5 | a party run with at least one community character of another friend (`with`) | now | as `d.dungeon` |
| `d.bosses3` | dungeons | Defeat 3 dungeon bosses | 5 | 3 bosses across that day's party runs | now | as `d.dungeon` |
| `d.dungeonQuest` | dungeons | Hand in a dungeon quest | 3 | a quest handed in that the stored quest log marks as a dungeon quest (`dungeon`, V31) | CF-71 | as `d.dungeon` |
| `d.cleanRun` | dungeons | Run a dungeon without dying | 5 | a party run with at least 1 boss and no death of that character between its start and its last boss | CF-74 | as `d.dungeon` |
| `d.speedRun` | dungeons | Defeat 3 bosses of one dungeon within 45 minutes | 5 | a party run with 3 or more bosses whose first entry to last boss took 45 minutes or less | CF-72 | as `d.dungeon` |
| `d.newDungeon` | dungeons | Run a dungeon new to the character | 5 | a party run with at least 1 boss in a dungeon that character has no earlier run of | CF-72 | as `d.dungeon` |
| `d.dungeons2` | dungeons | Run 2 dungeons | 5 | 2 finished party runs | CF-72 | as `d.dungeon` |
| `d.skill5` | crafts | Earn 5 profession skill points | 3 | 5 points over all professions since the first login that day | now | no profession on any character → `d.quests10` |
| `d.secondary` | crafts | Raise Cooking, First Aid or Fishing | 3 | 1 point in one of them, or learning one | now | |
| `d.craft5` | crafts | Craft 5 items | 3 | 5 items created (`LOOT_ITEM_CREATED_SELF`, a stack counts its count) | CF-74 | no profession at all → `d.secondary` |
| `d.gather10` | crafts | Gather 10 herbs, ore or leather | 3 | 10 items of the herb, metal and stone or leather classes looted from a gathering node or a skinned body | CF-75, V106 | no character with Herbalism, Mining or Skinning → `d.skill5` |
| `d.newRecipe` | crafts | Learn a new recipe | 3 | a recipe, pattern, plan, schematic or formula learned | CF-75, V104 | no profession at all → `d.secondary` |
| `d.craftGreen` | crafts | Craft something uncommon or better | 3 | an item of uncommon (green) or better quality created | CF-75, V105 | no crafting profession → `d.craft5` |
| `d.cook5` | cooking | Cook 5 meals | 3 | 5 food or drink items created (item class consumable, food and drink) | CF-75, V105 | no character with Cooking → `d.secondary` |
| `d.cook15` | cooking | Cook 15 dishes | 5 | 15 food or drink items created (item class consumable, food and drink) | CF-75, V105 | no character with Cooking → `d.secondary` |
| `d.cookSkill5` | cooking | Raise Cooking by 5 points | 3 | 5 Cooking skill points over all characters (skill line 185) | CF-72 | no character with Cooking → `d.secondary` |
| `d.cookKinds3` | cooking | Cook 3 different dishes | 3 | food or drink items of 3 different item IDs created | CF-75, V105 | no character with Cooking → `d.secondary` |
| `d.campfire` | cooking | Light a campfire | 1 | the campfire spell cast (Basic Campfire; its ID as the probe finds it) | CF-75, V95, V119 | no character with Cooking → `d.secondary` |
| `d.campfireBuff` | cooking | Sit at a campfire fed with 3 or more items | 3 | the campfire's special buff on a character, with 3 or more items in the fire (the buff and how it shows the items: as the probe finds it) | CF-75, V119 | |
| `d.eatOwn` | cooking | Eat a dish cooked that day | 3 | a food item eaten whose item ID one of the own characters created that day | CF-75, V105, V116 | no character with Cooking → `d.secondary` |
| `d.cookRecipe` | cooking | Learn a cooking recipe | 3 | a recipe learned whose spell creates a food or drink item | CF-75, V104 | no character with Cooking → `d.secondary` |
| `d.feedFriend` | cooking | Give a friend a dish cooked by an own character | 3 | a completed trade giving a friend's community character a food item one of the own characters created | CF-74 | no character with Cooking → `d.trade` |
| `d.fish20` | fishing | Catch 20 fish | 3 | 20 items from fishing loot | 56 | no character with Fishing → `d.secondary` |
| `d.fishZones` | fishing | Fish in 2 zones | 3 | fishing loot in 2 different zones | CF-74 | no character with Fishing → `d.secondary` |
| `d.fish50` | fishing | Catch 50 fish | 5 | 50 items from fishing loot | CF-74 | no character with Fishing → `d.secondary` |
| `d.fishSkill5` | fishing | Raise Fishing by 5 points | 3 | 5 Fishing skill points over all characters (skill line 356) | CF-72 | no character with Fishing → `d.secondary` |
| `d.fishKinds3` | fishing | Catch 3 kinds of fish | 3 | fishing loot of 3 different item IDs | CF-75, V106 (item | no character with Fishing → `d.secondary` |
| `d.fishFriend` | fishing | Fish in a group with a friend | 3 | fishing loot while grouped with a friend's community character in the same zone | CF-74 | no character with Fishing → `d.groupFriend` |
| `d.fishNight` | fishing | Fish at night | 3 | fishing loot between 21:00 and 05:00 realm time (`GetGameTime`, the game's own night) | CF-74 | no character with Fishing → `d.secondary` |
| `d.bandage3` | firstaid | Make 3 bandages | 3 | 3 bandages created (item class consumable, bandage) | CF-75, V105 | no character with First Aid → `d.secondary` |
| `d.bandageUp` | firstaid | Use a bandage | 3 | a First Aid bandage cast finished | CF-75, V95 | no character with First Aid → `d.secondary` |
| `d.bandage10` | firstaid | Make 10 bandages | 3 | 10 bandages created (item class consumable, bandage) | CF-75, V105 | no character with First Aid → `d.secondary` |
| `d.bandageUse3` | firstaid | Use 3 bandages | 3 | 3 First Aid bandage casts finished | CF-75, V95, V116 | no character with First Aid → `d.secondary` |
| `d.bandageFriend` | firstaid | Bandage a friend | 3 | a bandage cast finished whose target is a friend's community character | CF-75, V116, V117 | no character with First Aid → `d.groupFriend` |
| `d.aidSkill5` | firstaid | Raise First Aid by 5 points | 3 | 5 First Aid skill points over all characters (skill line 129) | CF-72 | no character with First Aid → `d.secondary` |
| `d.bandageKinds2` | firstaid | Make 2 kinds of bandages | 3 | bandages of 2 different item IDs created | CF-75, V105 | no character with First Aid → `d.secondary` |
| `d.chars2` | play | Play 2 characters | 1 | 2 characters logged in that day | now | only one character → `d.quests10` |
| `d.chars3` | play | Play 3 characters | 3 | 3 characters logged in that day | CF-72 | fewer than 3 characters → `d.chars2` |
| `d.switchUp` | play | Play a character not played the day before | 3 | a character logged in that day that wasn't logged in the previous Doomsday day | CF-72 | only one character → `d.quests10` |
| `d.dustOff` | play | Play a character after a week away | 3 | a character logged in whose last login was 7 or more days earlier (`lastPlayed`) | CF-72 | no character unplayed for 7 days → `d.chars2` |
| `d.earlyBird` | play | Early bird: play before 09:00 | 3 | logged in before 09:00 your local time | 53 | |
| `d.nightOwl` | play | Night owl: play after 23:00 | 3 | logged in at some moment between 23:00 and 03:00 local time | CF-74 | |
| `d.session1h` | play | Play a 1-hour session | 5 | one session lasting 60 minutes | CF-74 | |
| `d.deathless` | play | Play an hour without dying | 5 | 60 minutes of session time on one character with no death in between | CF-74 | |
| `d.jump100` | play | Jump 100 times | 1 | 100 jumps (a hook on the jump key) over all characters | CF-75, V118 | |
| `d.groupFriend` | social | Group up with a friend | 3 | in a group with another friend's community character | 53 | |
| `d.trade` | social | Trade with a friend | 3 | a completed trade with another friend's community character | 56 | |
| `d.questTogether` | social | Hand in a quest in a group with a friend | 3 | a quest handed in while grouped with a friend's community character | CF-71 | |
| `d.chatHello` | social | Say something in the community chat | 1 | an own message in the selected community's channel (by the sender's GUID) | CF-73 | |
| `d.sameZone` | social | Be in the same zone as a friend | 3 | a character in the same zone as a friend's online community character at the same moment | CF-73 | no other friend in the community → `d.chars2` |
| `d.online3` | social | Be online with 3 friends at once | 3 | 3 other friends online in Forever at the same moment while a character plays | CF-73 | fewer than 3 other friends in the community → `d.groupFriend` |
| `d.carry` | social | Group with a friend 5+ levels lower | 3 | grouped with a friend's community character 5 or more levels below the own character | CF-73 | |
| `d.whisper` | social | Whisper a friend | 1 | a whisper sent to a friend's community character or Battle.net account | CF-76, V108 | |
| `d.wave` | social | Wave at a friend | 1 | the `/wave` emote with a friend's community character targeted | CF-76, V108 | |
| `d.groupPic` | social | Take a screenshot in a group with a friend | 1 | a screenshot taken while grouped with a friend's community character | CF-76, V111 | |
| `d.discover1` | exploration | Discover a new place | 3 | one of the game's "Discovered" messages | CF-74 | |
| `d.discover3` | exploration | Discover 3 new places | 3 | 3 "Discovered" messages | CF-74 | |
| `d.roam4` | exploration | Visit 4 zones | 3 | 4 different zones entered (on any characters) | CF-73 | |
| `d.newZone` | exploration | Set foot in a zone new to the character | 3 | a zone entered that the character has never been in (per-character zone set, seeded from its feed) | CF-73 | |
| `d.places10` | exploration | Visit 10 places within zones | 3 | 10 different subzones entered | CF-76, V115 | |
| `d.swim` | exploration | Swim for 2 minutes | 3 | 2 minutes swimming in total, on one character | CF-76, V98 | |
| `d.nostalgia` | exploration | Visit a zone far below the character's level | 3 | a zone entered whose highest suggested level is 20 or more below the character's | CF-73 | highest character below 30 → `d.roam4` |
| `d.daredevil` | exploration | Visit a zone above the character's level | 3 | a zone entered whose lowest suggested level is 5 or more above the character's | CF-73 | all characters at 60 → `d.roam4` |
| `d.flight` | travel | Take a flight | 1 | a flight on a flight master's route | CF-76, V94 | |
| `d.newFlight` | travel | Learn a new flight path | 3 | a new flight path learned | CF-76, V94 | |
| `d.hearth` | travel | Use the hearthstone | 1 | the Hearthstone cast finished | CF-76, V95 | |
| `d.bind` | travel | Make a new inn home | 1 | the hearthstone set to a place other than the one it was set to | CF-76, V96 | |
| `d.ride` | travel | Ride a mount for 15 minutes | 3 | 15 minutes mounted in total, on one character | CF-76, V98 | no character with riding (CF-53) → `d.roam4` |
| `d.crossSea` | travel | Cross the sea | 3 | a character changes continent (`GetInstanceInfo` instance ID 0 and 1 outside instances) | CF-73 | |
| `d.summoned` | travel | Get summoned by a friend | 3 | a summon accepted whose summoner is a friend's community character | CF-76, V114 | |
| `d.kills30` | combat | Defeat 30 enemies | 3 | 30 kill XP messages | CF-76, V90 | all characters at 60 → `d.bosses3` |
| `d.elite` | combat | Defeat an elite | 3 | a kill XP message naming a creature last seen as elite or rare elite | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.rareMob` | combat | Defeat a rare enemy | 5 | a kill XP message naming a creature last seen as rare or rare elite | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.bigFoe` | combat | Defeat an enemy 3+ levels higher | 3 | a kill XP message naming a creature last seen 3 or more levels above the character, or as a skull | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.streak20` | combat | Defeat 20 enemies without dying | 5 | 20 kill XP messages on one character with no death in between | CF-76, V90 (+ 52) | all characters at 60 → `d.bosses3` |
| `d.weaponSkill` | combat | Raise a weapon skill 5 times | 3 | 5 weapon or defense skill-up messages | CF-76, V107 | |
| `d.duoHunt` | combat | Defeat 15 enemies in a group with a friend | 3 | 15 kill XP messages while grouped with a friend's community character | CF-76, V90 | all characters at 60 → `d.dungeonFriend` |
| `d.rare` | loot | Loot a rare item | 3 | a rare (blue) or better item looted | 53 | |
| `d.green5` | loot | Loot 5 uncommon items | 3 | 5 uncommon (green) or better items looted or received | CF-74 | |
| `d.reward` | loot | Earn an uncommon quest reward | 3 | a quest reward of uncommon (green) or better quality | CF-74 | |
| `d.coins10` | loot | Loot coins from 10 enemies | 3 | 10 money loot messages | CF-75, V109 | |
| `d.equipNew` | loot | Wear a new find | 3 | an item equipped that the character looted or received that day | CF-75, V113 | |
| `d.treasure` | loot | Open a treasure chest | 3 | loot from a game object that isn't a herb, ore or fishing node | CF-75, V106 | |
| `d.vendorSale` | economy | Sell to a merchant | 1 | money gained while a merchant window is open | CF-76, V99 | |
| `d.vendorBuy` | economy | Buy from a merchant | 1 | an item bought from a merchant (not a repair) | CF-76, V99 | |
| `d.auctionPost` | economy | Put an item up for auction | 3 | an auction posted | CF-76, V101 | |
| `d.auctionBuy` | economy | Buy at the auction house | 3 | an auction bought or won | CF-76, V101 | |
| `d.mailFriend` | economy | Send mail to a friend | 1 | mail sent to a friend's community character | CF-76, V100 | |
| `d.mailbox` | economy | Empty the mailbox | 1 | an item or money taken from the mailbox | CF-76, V100 | |
| `d.profit` | economy | End a session in profit | 3 | a session that ends with more money than it started with | CF-74 | |
| `d.repair` | care | Repair gear | 1 | a repair paid at a merchant | CF-75, V99 | |
| `d.trainer` | care | Learn a spell at a trainer | 3 | a spell or rank learned from a class trainer | CF-75, V103 | all characters at 60 → `d.repair` |
| `d.wellFed` | care | Get Well Fed | 1 | the "Well Fed" aura on a character | CF-75, V110 | |
| `d.buffFriend` | care | Buff a friend | 3 | an aura cast by the own character on a friend's community character | CF-75, V110 | no character that can buff others → `d.groupFriend` |
| `d.restock` | care | Restock food or drink | 1 | food or drink bought from a merchant | CF-75, V99, V105 | |
| `d.bank` | care | Visit the bank | 1 | the bank window opened | CF-75, V102 | |
| `d.tidyBags` | care | Clear the junk from the bags | 1 | a character that had poor (grey) items in its bags has none left | CF-75, V112 | |
| `d.potion` | care | Drink a potion | 1 | a potion used (item class consumable, potion) | CF-75, V116 | |
| `d.scrolls10` | care | Read 10 scrolls on the own character | 3 | 10 scrolls used (item class consumable, scroll) with the own character as the target | CF-75, V116, V117 | |

### PvE weeklies

| Id | Goal | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|
| `w.days3` | Play on 3 days | 3 Doomsday days with a login | now | |
| `w.days5` | Play on 5 days | 5 Doomsday days with a login | now | |
| `w.chars3` | Play 3 different characters | 3 characters logged in this week | now | fewer than 3 characters → `w.days3` |
| `w.levels3` | Gain 3 levels | 3 levels over all characters | now | all characters at 60 → `w.quests50` |
| `w.altLevels2` | Gain 2 levels on an alt | 2 levels on one character that isn't your highest | now | only one character below 60 → `w.quests50` |
| `w.quests50` | Finish 50 quests | 50 quests handed in | now | |
| `w.zones5` | Hand in quests in 5 zones | quests in 5 zones | now | |
| `w.dungeons3` | Run 3 dungeons | 3 finished party runs | now | no character in range of a dungeon → `w.quests50` |
| `w.dungeonsDiff3` | Run 3 different dungeons | party runs in 3 different instances | now | as `w.dungeons3` |
| `w.dungeonFriends2` | Run a dungeon with 2 friends | a party run with community characters of 2 other friends | now | as `w.dungeons3` |
| `w.fullClear` | Clear every boss of a dungeon | one party run that killed every boss of that dungeon (the addon's boss count per dungeon, `Goals.BOSSES`, from the game's DungeonEncounter table; dungeons with wings or optional bosses get a count after launch and can't be cleared until then) | now | as `w.dungeons3` |
| `w.skill25` | Earn 25 profession skill points | 25 points over all professions this week | now | no profession → `w.quests50` |
| `w.cap` | Reach a profession cap | a profession reaches 75/75, 150/150, 225/225 or 300/300 (as the site's milestone) | now | no profession below 300 → `w.skill25`, then `w.quests50` |
| `w.newProf` | Learn a new profession | a character learns a profession it didn't have | now | |
| `w.ilvl3` | Raise an item level by 3 | one character's item level 3 above its first login this week | now | item level unreadable → `w.quests50` |
| `w.friends3` | Group with 3 different friends | in a group with community characters of 3 other friends | 53 | |
| `w.rare5` | Loot 5 rare items | 5 rare (blue) or better items | 53 | |
| `w.session2h` | Play a 2-hour session | one login lasting 2 hours | 53 | |
| `w.discover5` | Discover 5 new places | 5 of the game's "discovered" messages (exploration) | 56 | |
| `w.craftTrade` | Craft something and trade it | an item one of your characters created this week, given to another friend's community character in a trade | 56 | no crafting profession → `w.quests50` |

"Another friend's community character" means a character of a different BattleTag, as the `with` lists of runs already use. Your own alts don't count.

## PvP goals

### The Hunt (daily)
- The day's enemy race and class combination: `pick(n, 1, 20)` from the list of the friend's enemy faction (see Lists).
- A Horde character hunts Alliance combinations and vice versa: the character's own faction decides, with no setting. A friend with characters on both factions sees both Hunts, and either one counts.
- **Done** with one counted kill of that exact combination.
- A kill counts only when the victim's race **and** class are known. Midnight hides combat-log details from addons, so they come from the target, mouseover or nameplate cache seen just before the kill (CF-55); a kill on a player never seen counts for points, not for the Hunt.
- If the launch probe (CF-54) shows race and class are rarely known, the Hunt becomes a second Skirmish (a pool-version bump).

### Skirmish pool (daily)
`pick(n, 2, #pool)`:

| Id | Goal | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|
| `p.frontLine` | Front line: 5 kills in the zone of the day | 5 counted kills in that zone. The zone is `pick(n, 4, #band)` from the band of the friend's highest character that played that day (see Lists) | now | no character of level 20 or more → `p.loneWolf` |
| `p.punchUp` | Punch up: 2 kills on players 3+ levels above you | 2 counted kills with `diff >= 3` (a skull counts) | CF-54 | |
| `p.loneWolf` | Lone wolf: 3 solo kills | 3 counted kills with `solo` | now | |
| `p.untouchable` | Untouchable: 5 kills without dying | 5 counted kills on one character with no death in between | now | |
| `p.variety` | Variety: kills of 3 different classes | 3 different victim classes | CF-54 | |
| `p.ranked` | Ranked bounty: kill a ranked player | 1 counted kill of a victim with PvP rank 1 or higher | CF-54 | |
| `p.flex` | Flex at a player of the other faction | the `/flex` emote with an enemy-faction player targeted | CF-76, V108 (emote and target), V74 | |
| `p.boo` | Boo a player of the other faction | the `/boo` emote with an enemy-faction player targeted | CF-76, V108 (emote and target), V74 | |
| `p.punchUp5` | Kill an enemy player 5+ levels higher | a counted kill with `diff >= 5` (a skull counts) | CF-74, V73, V74 | |
| `p.punchDown5` | Kill an enemy player 5+ levels lower | a counted kill with `diff <= -5` (it scores 0 kill points; only the goal counts) | CF-74, V73, V74 | |

### The Duel slot (daily)
- Your first duel with each friend that day: a win +3, a loss +1.
- It counts when the opponent's full name is another friend's community character.
- Both clients record the same duel, so a pair's duel counts once. When the two records disagree about the winner, the duel counts for neither.
- The Duel slot is not a goal for crossing out or the streak: it never counts toward them.
- It does count in "N of M done": M is exactly the goals on the grid (the 3 PvE dailies, the Hunt and the Skirmish, and the Duel slot), and the Duel slot is done after its first duel (live test 2026-10-29).

### Weekly bounty pool
`pick(week, 3, #pool)`:

| Id | Goal | Done when |
|---|---|---|
| `b.zone25` | 25 kills in the zone of the week | `pick(week, 5, #band)` from the band of the friend's highest character |
| `b.allClasses` | A kill of every enemy class | each class of the enemy list at least once |
| `b.allRaces` | A kill of every enemy race | each race at least once |
| `b.ranked5` | 5 kills on ranked players | victims with PvP rank 1 or higher |
| `b.kills50` | 50 counted kills | |
| `b.spree10` | A spree of 10 | 10 kills on one character without dying |
| `b.hunt3` | The Hunt done on 3 days | |
| `b.duels3` | Duels with 3 different friends | |
| `b.days5` | Kills on 5 days | a counted kill on 5 of the 7 days |

## Battleground block
- Battleground kills (`bg = true`) score with the same bands and counting rules, as **battleground points**: never PvP points, never in the week's kills.
- The block shows wins, losses and kills per battleground (`runs`, `kind = "pvp"`, `won`, CF-23).
- It is shown apart and ranked on its own.

## Ladder
- **Week:** friends by the week's points, one ranking per track. Each row expands to the split per character, with movement since last week (▲2, ▼1, new). Ties: more goals done first, then more counted kills (PvP).
- **All time:** totals since the start. **Only the site and the bot keep all-time totals**; the addon shows this week only (Nico, 2026-10-28).
- **PvP details:**
  - kills this week (solo, skulls), kills by zone
  - PvP rank with insignia and our title (see Feats)
  - **duels:** wins and losses, a head-to-head grid between friends, and an **Elo** rating (site and bot only: start 1000, K = 32, in time order, disputed duels left out)
  - the **battleground block**

## Feats
One-time achievements per character, posted once in Discord as **"Feat unlocked"**, **no points**. Every milestone the site posts today becomes a feat, and the new ones join them. The full list, texts and card images are in web `docs/STORIES.md` WEB-56. In short:
- **Existing:** levels 10–50, level 60, profession caps, new characters.
- **PvP:**
  - honorable kills (first, 100, 1,000, 5,000, 10,000)
  - a new highest PvP rank with our title
  - duel wins (10, 50, 100)
  - the first win in each battleground
  - 100 deaths
- **Gear:** the first epic, mount and epic mount. A mount counts only from level 40 and an epic mount from level 60 (CF-61: Retail clients report riding at any level).
- **Professions:**
  - the first catch
  - Head Chef, Field Medic and Fish Whisperer
  - Jack of all trades
  - the watch-list items: Arcanite Reaper, the Arcanite transmute, Mooncloth, Devilsaur, and the Fishing Extravaganza joined and won
- **First in the group:** a badge on a feat nobody in the group had before.

The site decides feats; the addon shows the feats it can derive from records it holds (the same kinds, thresholds and titles as the site's `feats.ts`), without "First in the group" and without the group's mount count. It remembers locally when it first saw each feat, so the Feats view lists them newest first; what a character had when the addon first saw it shows as "earlier" (CF-57b).

**PvP rank titles:** the official rank per faction, then "a.k.a." our title, the same for both factions:

| Rank | Horde / Alliance | Our title |
|---|---|---|
| 0 | none | Conscientious Objector while a PvP Virgin (shown, never posted); otherwise "No rank yet · N kills" |
| 1 | Scout / Private | Fresh Meat |
| 2 | Grunt / Corporal | Accidental Flagger |
| 3 | Sergeant / Sergeant | Lowbie Botherer |
| 4 | Senior Sergeant / Master Sergeant | Corpse Camper |
| 5 | First Sergeant / Sergeant Major | Spirit Healer's Pen Pal |
| 6 | Stone Guard / Knight | Mailbox Menace |
| 7 | Blood Guard / Knight-Lieutenant | Flag Hugger |
| 8 | Legionnaire / Knight-Captain | Honor Goblin |
| 9 | Centurion / Knight-Champion | Queue Dweller |
| 10 | Champion / Lieutenant Commander | Crossroads Landlord |
| 11 | Lieutenant General / Commander | Hillsbrad Housing Crisis |
| 12 | General / Marshal | Last Seen Questing at Launch |
| 13 | Warlord / Field Marshal | Sleep Is for the Dishonorable |
| 14 | High Warlord / Grand Marshal | Grass: Untouched |

## Lists
Enemy combinations (race token as `UnitRace` gives it, class token):
- **Alliance** (for Horde characters):
  - Human: Warrior, Paladin, Rogue, Priest, Mage, Warlock
  - Dwarf: Warrior, Paladin, Hunter, Rogue, Priest
  - NightElf: Warrior, Hunter, Rogue, Priest, Druid
  - Gnome: Warrior, Rogue, Mage, Warlock
- **Horde** (for Alliance characters):
  - Orc: Warrior, Hunter, Rogue, Shaman, Warlock
  - Scourge: Warrior, Rogue, Priest, Mage, Warlock
  - Tauren: Warrior, Hunter, Shaman, Druid
  - Troll: Warrior, Hunter, Rogue, Priest, Shaman, Mage

Enemy classes:
- Alliance: Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock, Druid
- Horde: Warrior, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid

Zone bands (the zone names as the feed stores them):
- **20–29:** Hillsbrad Foothills, Ashenvale, Stonetalon Mountains
- **30–44:** Stranglethorn Vale, Arathi Highlands, Desolace, Dustwallow Marsh, Alterac Mountains
- **45–54:** Tanaris, Feralas, The Hinterlands, Searing Gorge, Un'Goro Crater, Azshara
- **55–60:** Burning Steppes, Felwood, Winterspring, Eastern Plaguelands, Western Plaguelands, Silithus
