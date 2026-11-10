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
- Ids are never reused or renamed. A retired goal keeps its id in the catalogue, marked retired with the pool version it leaves from (`retired = 2`: `w.ilvl3` stays in pool version 1's draw, replaced by `w.blueGear`).
- A can't-do check added to a goal already in the pool applies from a pool version on (`canFrom`), so older days draw and swap as before: `b.zone25`'s "no character of level 20 or more" from pool version 2 (CF-79).
- PvP goals carry what they need (`needs`: kill, duel, bg, emote or flag, CF-79); only kill, duel and bg goals are a real fight (CF-78, "Two tracks").

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
| `w.groupQuests3` | 3 group Q |
| `w.questUp5` | 5 hard Q |
| `w.duoQuests5` | Duo quests |
| `w.blueGear` | Blue gear |
| `w.levels5` | 5 levels |
| `w.levelDays3` | Level days |
| `w.dungeons5` | 5 dungeons |
| `w.bosses15` | 15 bosses |
| `w.newDungeons2` | New dgn x2 |
| `w.cleanRuns2` | 2 clean |
| `w.gather50` | Gather 50 |
| `w.recipes3` | 3 recipes |
| `w.cook30` | Cook 30 |
| `w.cookKinds5` | 5 dishes |
| `w.fish100` | 100 fish |
| `w.fishZones4` | Fish 4 zns |
| `w.bandages20` | 20 bandage |
| `w.days7` | Every day |
| `w.dayAndNight` | Day+night |
| `w.deathless3h` | Iron 3h |
| `w.friendDays3` | Duo days |
| `w.trades3` | 3 trades |
| `w.chatDays5` | Chatty |
| `w.mentor3` | Mentor |
| `w.newZones3` | 3 new zns |
| `w.roam10` | Roam 10 |
| `w.flightPaths3` | 3 paths |
| `w.kills200` | 200 foes |
| `w.elites10` | 10 elites |
| `w.weapon25` | Weapon +25 |
| `w.potions5` | 5 potions |
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
| `p.kills10` | 10 kills |
| `p.zones3` | 3 zones |
| `p.double` | Double |
| `p.triple` | Triple |
| `p.firstBlood` | 1st blood |
| `p.nightRaid` | Night raid |
| `p.enemyLand` | Enemy land |
| `p.homeGuard` | Home guard |
| `p.contested` | Contested |
| `p.skull` | Skull |
| `p.fairFight` | Fair fight |
| `p.mirror` | Mirror |
| `p.races3` | 3 races |
| `p.healers` | Healers |
| `p.casters3` | Casters |
| `p.melee3` | Fighters |
| `p.nemesis` | Nemesis |
| `p.rankUp` | Outrank |
| `p.huntPair` | Hunt pair |
| `p.streak3` | Streak 3 |
| `p.revenge` | Revenge |
| `p.flagHour` | Flagged 30 |
| `p.comeback` | Comeback |
| `p.noDeath` | Spotless |
| `p.duoKills` | Duo kills |
| `p.trioKills` | Trio kills |
| `p.escort` | Escort |
| `p.avenge` | Avenge |
| `p.pack` | Pack hunt |
| `p.duelWin` | Duel win |
| `p.duelStranger` | Stranger |
| `p.duels3` | 3 duels |
| `p.duelUp` | Duel up |
| `p.duelClass` | Class duel |
| `p.duelWins2` | 2 in a row |
| `p.rematch` | Rematch |
| `p.bgPlay` | BG played |
| `p.bgWin` | BG win |
| `p.bgKills5` | BG kills 5 |
| `p.bgFriend` | BG buddy |
| `p.bgFlag` | Flag cap |
| `p.bgBase` | Base |
| `p.bgTop` | BG top |
| `p.salute` | Salute |
| `p.chicken` | Chicken |
| `p.bowKill` | Bow first |
| `p.flagUp` | Flag up |
| `b.zone25` | Zone 25 |
| `b.allClasses` | Classes |
| `b.allRaces` | Races |
| `b.ranked5` | 5 ranked |
| `b.kills50` | 50 kills |
| `b.spree10` | Spree 10 |
| `b.hunt3` | 3 hunts |
| `b.duels3` | 3 duels |
| `b.days5` | Kill days |
| `b.kills150` | 150 kills |
| `b.zones8` | 8 zones |
| `b.nights3` | Nights x3 |
| `b.enemyLand25` | Invader |
| `b.triples3` | 3 triples |
| `b.firstBlood3` | Blood x3 |
| `b.combos10` | 10 combos |
| `b.punchUp10` | Up x10 |
| `b.skulls3` | 3 skulls |
| `b.fair10` | Fair x10 |
| `b.nemesis` | Nemesis x3 |
| `b.solo20` | Solo 20 |
| `b.untouchable3` | Untouch x3 |
| `b.revenge3` | Revenge x3 |
| `b.flagged3h` | Flagged 3h |
| `b.kd` | K over D |
| `b.duoKills15` | Duo 15 |
| `b.warband` | Warband |
| `b.avenge3` | Avenge x3 |
| `b.huntAll` | All hunt |
| `b.duelWins5` | Duel wins |
| `b.duelAll` | Duel all |
| `b.duelDays4` | Duel days |
| `b.strangers3` | Strangers |
| `b.bgWins3` | 3 BG wins |
| `b.bgEach` | Every BG |
| `b.bgDays3` | BG days |
| `b.bgKills30` | BG kill 30 |
| `b.bgFlags3` | 3 flags |
| `b.bgBases5` | 5 bases |
| `b.bgFriends` | BG trio |
| `b.rankUp` | Rank up |
| `b.skirmish5` | Skirmish 5 |
| `b.taunts5` | Taunts |

## The algorithm, exactly (CF-55)
Fixed with Nico on 2026-10-28 and pinned by `tests/fixtures/doomsday-cases.json` (the addon's `src/core/Doomsday.lua` passes it; the site's copy must too). Where the sections above leave room, this decides. A golden case with `pool` is of that pool version; one without it is of pool version 1.

**Pool version 1** (`Doomsday.POOL_VERSION = 1`):
- PvE dailies and weeklies: the goals with Data **now**.
- Skirmish: `p.frontLine`, `p.loneWolf`, `p.untouchable`. Bounty: `b.zone25`, `b.kills50`, `b.spree10`, `b.duels3`, `b.days5`. These need only the kill's time, zone and `solo`, and deaths.
- **No Hunt**: the slot is empty in pool versions 1 to 3; the Hunt joins with pool version 4 (CF-104). Originally planned for the pool version that follows the CF-54 probe (victim race and class). The same bump adds `p.punchUp`, `p.variety`, `b.allClasses`, `b.allRaces`, `b.hunt3` where their fields are readable (`p.ranked` and `b.ranked5` are retired from pool version 3, CF-99), and the goals marked 52, 53, 56 whose APIs are verified.
- Pool order is the order of the tables in this file. The weeklies, Skirmish and Bounty goals of pool version 1 keep their place; the catalogues' other goals follow them, in catalogue order (CF-79).

**Pool version 2** (`Doomsday.POOL_VERSION = 2`, CF-77, the release after v1.1.0):
- Joins (`since = 2`): the missions whose trackers are built on verified APIs, CF-71 (quests), CF-72 (records) and CF-73 (friends and places), each with its registered progress:
  - 29 PvE dailies: `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.questBurst`, `d.accept5`, `d.levels2`, `d.dingDungeon`, `d.dingFriend`, `d.lowbie`, `d.dungeonQuest`, `d.speedRun`, `d.newDungeon`, `d.dungeons2`, `d.cookSkill5`, `d.fishSkill5`, `d.aidSkill5`, `d.chars3`, `d.switchUp`, `d.dustOff`, `d.questTogether`, `d.chatHello`, `d.sameZone`, `d.online3`, `d.carry`, `d.roam4`, `d.newZone`, `d.nostalgia`, `d.daredevil`, `d.crossSea`.
  - 13 PvE weeklies: `w.groupQuests3`, `w.questUp5`, `w.duoQuests5`, `w.levels5`, `w.levelDays3`, `w.dungeons5`, `w.bosses15`, `w.newDungeons2`, `w.days7`, `w.chatDays5`, `w.mentor3`, `w.newZones3`, `w.roam10`.
  - No Skirmish or Bounty goal: they wait for the launch checks (CF-80, CF-81).
- Leaves: `w.ilvl3` (`retired = 2`, CF-79).
- The pools: 43 dailies in 11 of the 15 categories (none yet in combat, loot, economy and care; one each in cooking, fishing, first aid and travel), 27 weeklies in 7 categories, Skirmish and Bounty as version 1.
- Points: each goal's own size (CF-69, `Doomsday.pointsFor`).
- The weeklies are drawn in different categories (below).
- Missions waiting for launch checks (CF-74 to CF-76, CF-80, CF-81) join in later versions, one bump per release, with golden cases each.

**Pool version 3** (`Doomsday.POOL_VERSION = 3`, CF-99, after the launch probe of 2026-11-06):
- Joins (`since = 3`): the missions of CF-74 to CF-76 whose checks passed, each with its registered progress, and `p.homeGuard` (CF-81):
  - CF-74 (existing trackers, extended): `d.trade`, `d.fish20`, `d.rare`, `d.cleanLevel`, `d.groupFriend`, `d.earlyBird`, `d.fish50`, `d.fishZones`, `d.fishNight`, `d.discover1`, `d.discover3`, `d.nightOwl`, `d.session1h`, `d.deathless`, `d.cleanRun`, `d.profit`, `d.green5`, `d.craft5`; weeklies `w.rare5`, `w.friends3`, `w.session2h`, `w.discover5`, `w.fish100`, `w.fishZones4`, `w.dayAndNight`, `w.deathless3h`, `w.cleanRuns2`, `w.friendDays3`, `w.trades3`. Not yet: `d.reward`, `d.fishFriend`, `d.feedFriend` (they wait for an in-game check, VERIFY.md CF-74).
  - CF-75 (items): `d.gather10`, `d.newRecipe`, `d.craftGreen`, `d.cook5`, `d.cook15`, `d.cookKinds3`, `d.eatOwn`, `d.cookRecipe`, `d.bandage3`, `d.bandage10`, `d.bandageKinds2`, `d.bandageUp`, `d.bandageUse3`, `d.bandageFriend`, `d.coins10`, `d.equipNew`, `d.wellFed`, `d.buffFriend`, `d.tidyBags`, `d.potion`, `d.scrolls10`; weeklies `w.blueGear`, `w.gather50`, `w.recipes3`, `w.cook30`, `w.cookKinds5`, `w.bandages20`, `w.potions5`.
  - CF-76 (world): `d.kills30`, `d.elite`, `d.rareMob`, `d.bigFoe`, `d.streak20`, `d.duoHunt`, `d.weaponSkill`, `d.flight`, `d.newFlight`, `d.hearth`, `d.ride`, `d.swim`, `d.places10`, `d.whisper`, `d.groupPic`, `d.mailFriend`, `d.vendorBuy`, `d.vendorSale`, `d.repair`, `d.trainer`, `d.bank`; weeklies `w.kills200`, `w.elites10`, `w.weapon25`, `w.flightPaths3`.
  - Skirmish: `p.homeGuard`.
- Leaves: `p.ranked`, `p.rankUp`, `b.ranked5`, `b.rankUp` (`retired = 3`): Forever has no readable PvP rank (`UnitPVPRank` missing, V79). They never had a `since`, so the draws of pool versions 1 and 2 are unchanged.
- The pools: 103 dailies in all 15 categories, 49 weeklies in 14 categories, 4 Skirmish goals, Bounty as before (5).
- Draw, swaps and points: as pool version 2.

**Pool version 4** (`Doomsday.POOL_VERSION = 4`, CF-104, Nico's decisions of 2026-11-09):
- Joins (`since = 4`), each with its registered progress:
  - PvE dailies: `d.reward`, `d.fishFriend`, `d.feedFriend` (CF-74, their in-game check passed), `d.summoned` (V114), `d.auctionPost` (V101: posting only; `d.auctionBuy` stays out). "Send mail to a friend" is `d.mailFriend`, already in pool version 3; `d.mailbox` (taking from the inbox) stays out.
  - Skirmish: `p.revenge` (avenge a death: the player who last killed you, within the day), `p.flagHour`, `p.flagUp` (the PvP flag, V121).
  - Bounty: `b.flagged3h` (V121).
  - **The Hunt** (Nico, 2026-11-09): `Doomsday.HUNT_SINCE = 4`, so pool version 4 draws it (salt 1, "The Hunt (daily)" below) and a day's set holds 5 ids (`hunt` the fifth). Its victim's race and class come from CF-110's pick at the kill (your target, mouseover or a nameplate). Pool versions 1 to 3 draw no Hunt. The golden `draws.hunts` cases with `pool: 4` pin it; the older cases without `pool` pin the same rule as if drawn from version 1 (`huntSince` in the file says from which version it is drawn).
- Leaves: `p.homeGuard` (`retired = 4`): an own zone's PvP type reads only in the capitals (V123), so it counted only there. Pool versions 1 to 3 draw as before (pool version 3 keeps it).
- The pools: 108 dailies, 49 weeklies, 6 Skirmish goals (`p.frontLine`, `p.loneWolf`, `p.untouchable`, `p.revenge`, `p.flagHour`, `p.flagUp`), 6 Bounty goals (version 3's and `b.flagged3h`).
- Draw, swaps and points: as pool version 2. The flag time, the killers and the revenges are local facts of the day and week (`battle.flagged`, `flagRun`, `flagBest`, `killers`, `revenge`; `world.summons`, `world.auctions`); nothing new is sent.
- An addon on pool version 3 keeps drawing and recording pool version 3 (`pool = 3` on its days and weeks) and scores a friend's version-4 day by its `pool` (every id is already in its catalogue); the release notes ask friends to update.

**Pool version 5** (`Doomsday.POOL_VERSION = 5`, CF-116, Nico's decision of 2026-11-10):
- **The Hunt draws Forever's combinations** (`Doomsday.FOREVER_COMBOS_SINCE = 5`): 23 per enemy faction instead of Vanilla's 20 (Lists, "From pool version 5"), from Forever's game files (build 1.60.1.70862), without the Skyborne races until their race tokens are known (launch probe V142). Pool versions 1 to 4 draw from the 20 exactly as before. The golden `draws.hunts` cases with `pool: 5` pin it.
- `b.allClasses` counts the enemy classes of the week's pool version: 9 per faction from version 5 (Dwarf Shaman, Undead Paladin), 8 before. The races stay.
- No other mission changes: the pools, the draw of the missions, the swaps and the points are version 4's.
- Nothing new is stored or sent. An addon on pool version 4 keeps drawing version 4 (its Hunt from the 20) and scores a friend's version-5 day by its `pool`: `hunt` is worth 5 in every version. The combination is never sent: each addon stores its own day's combination with the day's facts when it draws the day, so a day drawn before the update keeps its version-4 Hunt, and the Hunt's progress compares that stored race and class with the kill, never the list.

**Which version a day uses.** There is no switch date: a client draws with the pool version it has (`Doomsday.POOL_VERSION`) and records it with the day's and week's entry when it first draws them (CF-69, `pool`). A day or week drawn before the update keeps its set and its version; the first day and week drawn after it use the new version. A friend on an older addon keeps drawing its own version (1, 2 or 3), so on the release day friends on different versions see different sets (the release notes ask everyone to update). Each version's draw runs its own chain from the epoch, so the older versions' draws stay as they were. Points follow the entry's `pool`, and every id of a newer pool is already in the older addon's catalogue (CF-70, CF-79), so an addon on version 2 scores a friend's version-3 day the same way.

**Salts:** Hunt 1, Skirmish 2, Bounty 3, zone of the day 4, zone of the week 5, the 3 PvE dailies 11, 12, 13, the 3 PvE weeklies 21, 22, 23.

**The draw, never twice in a row.** It runs forward from the **epoch**, day `20761` (the Doomsday day that starts on Wednesday 2026-11-04, launch), and week `2966` (the week holding it). Each day excludes the previous day's draw (before swaps); the epoch day and any day before it exclude nothing. Weeks the same.
- **PvE dailies:** for slot 1, 2, 3: the candidates are the pool's goals, in pool order, whose category isn't taken yet and that weren't in the previous day's dailies; slot k takes `candidates[pick(n, 10 + k, #candidates)]`. If no candidate is left, the previous day's goals are allowed again (categories still differ).
- **Skirmish, Bounty:** `available = pool without the previous draw` (the whole pool when that leaves nothing); `available[pick(n, salt, #available)]`.
- **PvE weeklies, pool version 1:** as the dailies without categories: slot k takes `candidates[pick(week, 20 + k, #candidates)]` from the pool minus the goals already chosen and minus last week's (if that leaves none, last week's are allowed again).
- **PvE weeklies, from pool version 2** (CF-77): exactly as the dailies, with the week: the candidates are the pool's weeklies, in pool order, whose category isn't taken yet and that weren't in last week's; slot k takes `candidates[pick(week, 20 + k, #candidates)]`. If no candidate is left, last week's are allowed again (categories still differ).
- **The Hunt** (once in the pool): per hunting faction, the combinations of the pool version (20 in versions 1 to 4, 23 from version 5; see Lists) in list order minus the previous day's combination (none on the epoch), `available[pick(n, 1, #available)]`.
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
| `d.feedFriend` | cooking | Give a friend a dish cooked by an own character | 3 | a completed trade giving a friend's community character a food item one of the own characters created | CF-74 (pool 4, CF-104) | no character with Cooking → `d.trade` |
| `d.fish20` | fishing | Catch 20 fish | 3 | 20 items from fishing loot | 56 | no character with Fishing → `d.secondary` |
| `d.fishZones` | fishing | Fish in 2 zones | 3 | fishing loot in 2 different zones | CF-74 | no character with Fishing → `d.secondary` |
| `d.fish50` | fishing | Catch 50 fish | 5 | 50 items from fishing loot | CF-74 | no character with Fishing → `d.secondary` |
| `d.fishSkill5` | fishing | Raise Fishing by 5 points | 3 | 5 Fishing skill points over all characters (skill line 356) | CF-72 | no character with Fishing → `d.secondary` |
| `d.fishKinds3` | fishing | Catch 3 kinds of fish | 3 | fishing loot of 3 different item IDs | CF-75, V106 (item | no character with Fishing → `d.secondary` |
| `d.fishFriend` | fishing | Fish in a group with a friend | 3 | fishing loot while grouped with a friend's community character in the same zone | CF-74 (pool 4, CF-104) | no character with Fishing → `d.groupFriend` |
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
| `d.summoned` | travel | Get summoned by a friend | 3 | a summon accepted whose summoner is a friend's community character: the summoner from `CONFIRM_SUMMON` with `C_SummonInfo.GetSummonConfirmSummoner()`, the accept from the summon popup (`C_SummonInfo.ConfirmSummon`) | CF-104 (pool 4), V114 | |
| `d.kills30` | combat | Defeat 30 enemies | 3 | 30 kill XP messages | CF-76, V90 | all characters at 60 → `d.bosses3` |
| `d.elite` | combat | Defeat an elite | 3 | a kill XP message naming a creature last seen as elite or rare elite | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.rareMob` | combat | Defeat a rare enemy | 5 | a kill XP message naming a creature last seen as rare or rare elite | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.bigFoe` | combat | Defeat an enemy 3+ levels higher | 3 | a kill XP message naming a creature last seen 3 or more levels above the character, or as a skull | CF-76, V90, V93 | all characters at 60 → `d.bosses3` |
| `d.streak20` | combat | Defeat 20 enemies without dying | 5 | 20 kill XP messages on one character with no death in between | CF-76, V90 (+ 52) | all characters at 60 → `d.bosses3` |
| `d.weaponSkill` | combat | Raise a weapon skill 5 times | 3 | 5 weapon or defense skill-up messages | CF-76, V107 | |
| `d.duoHunt` | combat | Defeat 15 enemies in a group with a friend | 3 | 15 kill XP messages while grouped with a friend's community character | CF-76, V90 | all characters at 60 → `d.dungeonFriend` |
| `d.rare` | loot | Loot a rare item | 3 | a rare (blue) or better item looted | 53 | |
| `d.green5` | loot | Loot 5 uncommon items | 3 | 5 uncommon (green) or better items looted or received | CF-74 | |
| `d.reward` | loot | Earn an uncommon quest reward | 3 | a quest reward of uncommon (green) or better quality | CF-74 (pool 4, CF-104) | |
| `d.coins10` | loot | Loot coins from 10 enemies | 3 | 10 money loot messages | CF-75, V109 | |
| `d.equipNew` | loot | Wear a new find | 3 | an item equipped that the character looted or received that day | CF-75, V113 | |
| `d.treasure` | loot | Open a treasure chest | 3 | loot from a game object that isn't a herb, ore or fishing node | CF-75, V106 | |
| `d.vendorSale` | economy | Sell to a merchant | 1 | money gained while a merchant window is open | CF-76, V99 | |
| `d.vendorBuy` | economy | Buy from a merchant | 1 | an item bought from a merchant (not a repair) | CF-76, V99 | |
| `d.auctionPost` | economy | Put an item up for auction | 3 | an auction posted (`AUCTION_HOUSE_AUCTION_CREATED` or the game's "auction created" message; one per auction) | CF-104 (pool 4), V101 | |
| `d.auctionBuy` | economy | Buy at the auction house | 3 | an auction bought or won | CF-76, V101 | |
| `d.mailFriend` | economy | Send mail to a friend | 1 | mail sent to a friend's community character | CF-76, V100 | |
| `d.mailbox` | economy | Empty the mailbox | 1 | an item or money taken from the mailbox | CF-76, V100 | |
| `d.profit` | economy | End a session in profit | 3 | a session that ends with more money than it started with | CF-74 | |
| `d.repair` | care | Repair gear | 1 | a repair paid at a merchant | CF-76, V99 | |
| `d.trainer` | care | Learn a spell at a trainer | 3 | a spell or rank learned from a class trainer | CF-76, V103 | all characters at 60 → `d.repair` |
| `d.wellFed` | care | Get Well Fed | 1 | the "Well Fed" aura on a character | CF-75, V110 | |
| `d.buffFriend` | care | Buff a friend | 3 | an aura cast by the own character on a friend's community character | CF-75, V110 | no character that can buff others → `d.groupFriend` |
| `d.restock` | care | Restock food or drink | 1 | food or drink bought from a merchant | CF-75, V99, V105 | |
| `d.bank` | care | Visit the bank | 1 | the bank window opened | CF-76, V102 | |
| `d.tidyBags` | care | Clear the junk from the bags | 1 | a character that had poor (grey) items in its bags has none left | CF-75, V112 | |
| `d.potion` | care | Drink a potion | 1 | a potion used (item class consumable, potion) | CF-75, V116 | |
| `d.scrolls10` | care | Read 10 scrolls on the own character | 3 | 10 scrolls used (item class consumable, scroll) with the own character as the target | CF-75, V116, V117 | |

### PvE weeklies

| Id | Category | Goal | Points | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|
| `w.days3` | play | Play on 3 days | 5 | 3 Doomsday days with a login | now |  |
| `w.days5` | play | Play on 5 days | 10 | 5 Doomsday days with a login | now |  |
| `w.chars3` | play | Play 3 different characters | 5 | 3 characters logged in this week | now | fewer than 3 characters → `w.days3` |
| `w.levels3` | levels | Gain 3 levels | 10 | 3 levels over all characters | now | all characters at 60 → `w.quests50` |
| `w.altLevels2` | levels | Gain 2 levels on an alt | 10 | 2 levels on one character that isn't your highest | now | only one character below 60 → `w.quests50` |
| `w.quests50` | quests | Finish 50 quests | 10 | 50 quests handed in | now |  |
| `w.zones5` | quests | Hand in quests in 5 zones | 5 | quests in 5 zones | now |  |
| `w.dungeons3` | dungeons | Run 3 dungeons | 10 | 3 finished party runs | now | no character in range of a dungeon → `w.quests50` |
| `w.dungeonsDiff3` | dungeons | Run 3 different dungeons | 10 | party runs in 3 different instances | now | as `w.dungeons3` |
| `w.dungeonFriends2` | dungeons | Run a dungeon with 2 friends | 10 | a party run with community characters of 2 other friends | now | as `w.dungeons3` |
| `w.fullClear` | dungeons | Clear every boss of a dungeon | 10 | one party run that killed every boss of that dungeon (the addon's boss count per dungeon, `Goals.BOSSES`, from the game's DungeonEncounter table; dungeons with wings or optional bosses get a count after launch and can't be cleared until then) | now | as `w.dungeons3` |
| `w.skill25` | crafts | Earn 25 profession skill points | 10 | 25 points over all professions this week | now | no profession → `w.quests50` |
| `w.cap` | crafts | Reach a profession cap | 10 | a profession reaches 75/75, 150/150, 225/225 or 300/300 (as the site's milestone) | now | no profession below 300 → `w.skill25`, then `w.quests50` |
| `w.newProf` | crafts | Learn a new profession | 5 | a character learns a profession it didn't have | now |  |
| `w.ilvl3` | levels | Raise an item level by 3 | 15 (pool 1 only) | one character's item level 3 above its first login this week; **retired from pool version 2** (replaced by `w.blueGear`) | now | item level unreadable → `w.quests50` |
| `w.friends3` | social | Group with 3 different friends | 10 | in a group with community characters of 3 other friends | existing tracker, waits for its launch check: CF-53 groups |  |
| `w.rare5` | loot | Loot 5 rare items | 10 | 5 rare (blue) or better items | existing tracker, waits for its launch check: V83 |  |
| `w.session2h` | play | Play a 2-hour session | 5 | one login lasting 2 hours | existing tracker, waits for its launch check: CF-53 sessions |  |
| `w.discover5` | exploration | Discover 5 new places | 5 | 5 of the game's "discovered" messages (exploration) | existing tracker, waits for its launch check: V86 |  |
| `w.craftTrade` | crafts | Craft something and trade it | 10 | an item one of your characters created this week, given to another friend's community character in a trade | existing tracker, waits for its launch check: V85 | no crafting profession → `w.quests50` |
| `w.groupQuests3` | quests | Finish 3 group quests | 10 | 3 quests handed in that the quest log marked as group quests | new tracker, verified API: CF-71 |  |
| `w.questUp5` | quests | Finish 5 quests above the character's level | 10 | 5 quests handed in whose level is higher than the character's | new tracker, verified API: CF-71 | all characters at 60 → `w.quests50` |
| `w.duoQuests5` | quests | Hand in 5 quests in a group with a friend | 10 | 5 quests handed in while grouped with a friend's community character | new tracker, verified API: CF-71 |  |
| `w.blueGear` | levels | Put on a blue item new to the character | 10 | a rare (blue) or better item put on that the character never wore before (`PLAYER_EQUIPMENT_CHANGED`, `GetInventoryItemID`, the item's quality); replaces `w.ilvl3`, retired from pool version 2 | needs probe V113, V83 | highest character below 15 → `w.levels3` |
| `w.levels5` | levels | Gain 5 levels | 15 | 5 levels over all characters | works now | all characters at 60 → `w.quests50` |
| `w.levelDays3` | levels | Gain a level on 3 days | 10 | a level gained on 3 Doomsday days of the week | works now | all characters at 60 → `w.quests50` |
| `w.dungeons5` | dungeons | Run 5 dungeons | 15 | 5 finished party runs | works now | as `w.dungeons3` |
| `w.bosses15` | dungeons | Defeat 15 dungeon bosses | 15 | 15 bosses across the week's party runs | works now | as `w.dungeons3` |
| `w.newDungeons2` | dungeons | Run 2 dungeons new to the character | 10 | party runs with at least 1 boss in 2 dungeons the character had no earlier run of | new tracker, verified API: CF-72 | as `w.dungeons3` |
| `w.cleanRuns2` | dungeons | Run 2 dungeons without dying | 10 | two party runs, each with at least 1 boss and no death of that character in it | existing tracker, waits for its launch check: CF-52 deaths | as `w.dungeons3` |
| `w.gather50` | crafts | Gather 50 herbs, ore or leather | 10 | 50 items of the herb, metal and stone or leather classes looted from a gathering node or a skinned body | needs probe V106 | no character with Herbalism, Mining or Skinning → `w.skill25` |
| `w.recipes3` | crafts | Learn 3 new recipes | 10 | 3 recipes learned | needs probe V104 | no profession at all → `w.newProf` |
| `w.cook30` | cooking | Cook 30 dishes | 10 | 30 food or drink items created | needs probe V105 | no character with Cooking → `w.skill25` |
| `w.cookKinds5` | cooking | Cook 5 different dishes | 10 | food or drink items of 5 different item IDs created | needs probe V105 | no character with Cooking → `w.skill25` |
| `w.fish100` | fishing | Catch 100 fish | 15 | 100 items from fishing loot | existing tracker, waits for its launch check: V84 | no character with Fishing → `w.skill25` |
| `w.fishZones4` | fishing | Fish in 4 zones | 10 | fishing loot in 4 different zones | existing tracker, waits for its launch check: V84 | no character with Fishing → `w.skill25` |
| `w.bandages20` | firstaid | Make 20 bandages | 10 | 20 bandages created | needs probe V105 | no character with First Aid → `w.skill25` |
| `w.days7` | play | Play on all 7 days | 15 | all 7 Doomsday days of the week with a login | works now |  |
| `w.dayAndNight` | play | Play before 09:00 and after 23:00 | 10 | a login before 09:00 local time and a login between 23:00 and 03:00 local time, in the same week | existing tracker, waits for its launch check: CF-53 sessions |  |
| `w.deathless3h` | play | Play 3 hours without dying | 15 | 3 hours of session time on one character with no death in between | existing tracker, waits for its launch check: CF-52 deaths, CF-53 sessions |  |
| `w.friendDays3` | social | Group with a friend on 3 days | 10 | in a group with a friend's community character on 3 Doomsday days | existing tracker, waits for its launch check: CF-53 groups |  |
| `w.trades3` | social | Trade with 3 different friends | 10 | completed trades with community characters of 3 other friends | existing tracker, waits for its launch check: V85 | fewer than 3 other friends in the community → `w.friends3` |
| `w.chatDays5` | social | Chat in the community on 5 days | 5 | an own message in the selected community's channel on 5 Doomsday days | new tracker, verified API: CF-73 (V38) |  |
| `w.mentor3` | social | Group with a lower friend on 3 days | 10 | grouped with a friend's community character 5 or more levels below the own character, on 3 Doomsday days | new tracker, verified API: CF-73 |  |
| `w.newZones3` | exploration | Set foot in 3 zones new to the character | 10 | zones entered that the character had never been in, 3 in total | new tracker, verified API: CF-73 |  |
| `w.roam10` | exploration | Visit 10 zones | 10 | 10 different zones entered | new tracker, verified API: CF-73 |  |
| `w.flightPaths3` | travel | Learn 3 flight paths | 10 | 3 new flight paths learned | needs probe V94 |  |
| `w.kills200` | combat | Defeat 200 enemies | 15 | 200 kill XP messages | needs probe V90 | all characters at 60 → `w.dungeons3` |
| `w.elites10` | combat | Defeat 10 elites | 10 | kill XP messages naming creatures last seen as elite or rare elite, 10 in total | needs probe V90, V93 | all characters at 60 → `w.dungeons3` |
| `w.weapon25` | combat | Raise weapon skills 25 times | 10 | 25 weapon or defense skill-up messages | needs probe V107 |  |
| `w.potions5` | care | Drink 5 potions | 5 | 5 potions used | needs probe V116 |  |

"Another friend's community character" means a character of a different BattleTag, as the `with` lists of runs already use. Your own alts don't count.

## PvP goals

### The Hunt (daily)
- The day's enemy race and class combination: `pick(n, 1, #list)` from the list of the friend's enemy faction for the day's pool version (see Lists: 20 in pool versions 1 to 4, 23 from version 5, CF-116).
- A Horde character hunts Alliance combinations and vice versa: the character's own faction decides, with no setting. A friend with characters on both factions sees both Hunts, and either one counts.
- **Done** with one counted kill of that exact combination.
- A kill counts only when the victim's race **and** class are known. Midnight hides combat-log details from addons, so they come from the target, mouseover or nameplate cache seen just before the kill (CF-55); a kill on a player never seen counts for points, not for the Hunt.
- Tip (CF-114): target your prey, or turn on enemy nameplates, so the kill knows who it was. The addon marks an enemy
  player of the open Hunt's combination in their tooltip ("Your prey: The Hunt") and once in chat ("Prey in sight").
- If the launch probe (CF-54) shows race and class are rarely known, the Hunt becomes a second Skirmish (a pool-version bump).

### Skirmish pool (daily)
`pick(n, 2, #pool)`:

| Id | Category | Needs | Goal | Points | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| `p.frontLine` | worldKills | kill | Front line: 5 kills in the zone of the day | 3 | 5 counted kills in that zone. The zone is `pick(n, 4, #band)` from the band of the friend's highest character that played that day (see Lists) | now | no character of level 20 or more → `p.loneWolf` |
| `p.punchUp` | targets | kill | Punch up: 2 kills on players 3+ levels above | 3 | 2 counted kills with `diff >= 3` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.loneWolf` | worldKills | kill | Lone wolf: 3 solo kills | 3 | 3 counted kills with `solo` | now |  |
| `p.untouchable` | streaks | kill | Untouchable: 5 kills without dying | 5 | 5 counted kills on one character with no death in between | now |  |
| `p.variety` | targets | kill | Variety: kills of 3 different classes | 3 | 3 different victim classes | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.ranked` | targets | kill | Ranked bounty: kill a ranked player | 5 | 1 counted kill of a victim with PvP rank 1 or higher | retired from pool version 3: no rank reads on Forever (`UnitPVPRank` missing, V79; Nico, 2026-11-06) |  |
| `p.flex` | taunts | emote | Flex at a player of the other faction | 1 | the `/flex` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| `p.boo` | taunts | emote | Boo a player of the other faction | 1 | the `/boo` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| `p.punchUp5` | targets | kill | Kill an enemy player 5+ levels higher | 5 | a counted kill with `diff >= 5` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.punchDown5` | targets | kill | Kill an enemy player 5+ levels lower | 3 | a counted kill with `diff <= -5` (it scores 0 kill points; only the goal counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.kills10` | worldKills | kill | Score 10 kills | 3 | 10 counted world kills | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.zones3` | worldKills | kill | Kills in 3 zones | 3 | counted kills in 3 different zones | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.double` | worldKills | kill | Double: 2 kills within 10 seconds | 5 | 2 counted kills by one character within 10 seconds | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.triple` | worldKills | kill | Triple: 3 kills within 2 minutes | 5 | 3 counted kills by one character within 2 minutes | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.firstBlood` | worldKills | kill | First blood: the first kill among friends | 5 | the day's first counted world kill of all friends (by the kill's time in the synced records) | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.nightRaid` | worldKills | kill | Night raid: a kill after 23:00 realm time | 3 | a counted kill between 23:00 and 05:00 realm time (`GetGameTime`) | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| `p.enemyLand` | worldKills | kill | Kill in the enemy's territory | 3 | a counted kill in a zone of the enemy faction (`C_PvP.GetZonePVPInfo` "hostile") | needs probe V123 (new) | no character of level 20 or more → `p.loneWolf` |
| `p.homeGuard` | worldKills | kill | Defend home: a kill in friendly territory | 3 | a counted kill in a zone of the own faction: its PvP type (`C_PvP.GetZonePVPInfo`) read "friendly" while the own character was there that day (on entering it or at a kill); a zone without a type (one starting zone, V123) doesn't count | CF-81 (CF-99), V123 "friendly" verified; retired from pool 4 (CF-104: the type reads only in the capitals) | no character of level 20 or more → `p.loneWolf` |
| `p.contested` | worldKills | kill | Kills in contested land | 3 | 3 counted kills in contested zones ("contested") | needs probe V123 (new) | no character of level 20 or more → `p.loneWolf` |
| `p.skull` | targets | kill | Slay a skull | 5 | a counted kill of a victim shown as a skull (`lvl = -1`) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.fairFight` | targets | kill | Fair fight: a kill at the same level | 3 | a counted kill with `diff = 0` | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.mirror` | targets | kill | Mirror match: kill an enemy of the same class | 3 | a counted kill of a victim of the killer's own class | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.races3` | targets | kill | Kills of 3 different races | 3 | 3 different victim races | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.healers` | targets | kill | Silence the healers: 2 healer-class kills | 3 | 2 counted kills of priests, druids, paladins or shamans | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.casters3` | targets | kill | Kill 3 casters | 3 | 3 counted kills of mages, warlocks or priests | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.melee3` | targets | kill | Kill 3 fighters | 3 | 3 counted kills of warriors, rogues or paladins | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.nemesis` | targets | kill | Nemesis: kill the same player twice | 3 | 2 counted kills of the same victim name | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.rankUp` | targets | kill | Kill a player of higher rank | 5 | a counted kill of a victim whose PvP rank is above the killer's | retired from pool version 3: no rank reads on Forever (`UnitPVPRank` missing, V79; Nico, 2026-11-06) |  |
| `p.huntPair` | targets | kill | Kills of 2 Hunt combinations | 3 | counted kills of 2 different race and class combinations of the enemy list (not only today's Hunt) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `p.streak3` | streaks | kill | Three in a row without dying | 3 | 3 counted kills on one character with no death in between | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| `p.revenge` | streaks | kill | Revenge: kill the player who killed you | 5 | a kill, outside a battleground, of the enemy player who last killed that character that day; once per death. By GUID: the killer is the death recap's last damage source when it is a player (`C_DeathRecap.GetRecapEvents`), the victim the one CF-110 picks at the kill (your target, mouseover or a nameplate) | CF-104 (pool 4), V120 |  |
| `p.flagHour` | streaks | flag | Stay flagged for 30 minutes without dying | 3 | 30 minutes flagged for PvP on one character in one run: a death or the flag dropping starts it over (`UnitIsPVP("player")`, read on `PLAYER_FLAGS_CHANGED` and each minute) | CF-104 (pool 4), V121 |  |
| `p.comeback` | streaks | kill | Comeback: a kill within 5 minutes of a death | 3 | a counted kill within 5 minutes after the same character died to a player | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| `p.noDeath` | streaks | kill | Score 3 kills and never die that day | 5 | 3 counted kills on a day with no death to a player on any character up to that moment | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| `p.duoKills` | teamwork | kill | Kills with a friend | 3 | 3 counted kills while grouped with a friend's community character | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| `p.trioKills` | teamwork | kill | Kills with 2 friends | 5 | a counted kill while grouped with community characters of 2 other friends | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| `p.escort` | teamwork | kill | Escort: a kill grouped with a lower friend | 3 | a counted kill while grouped with a friend's community character 5 or more levels below the killer | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| `p.avenge` | teamwork | kill | Avenge a friend | 5 | a counted kill of the player who killed a friend in the same group, within 10 minutes | needs probe V120 (new) | no other friend in the community → `p.loneWolf` |
| `p.pack` | teamwork | kill | Pack hunt: a kill in a full party | 3 | a counted kill while in a party of 5 (`GetNumGroupMembers`, not a raid) | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups |  |
| `p.duelWin` | duels | duel | Win a duel | 1 | a duel won (any opponent) | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `p.duelStranger` | duels | duel | Beat a stranger in a duel | 3 | a duel won against a player who is not a community character | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `p.duels3` | duels | duel | Fight 3 duels | 3 | 3 duels finished, won or lost | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `p.duelUp` | duels | duel | Win a duel against a higher level | 5 | a duel won against a friend's community character of a higher level | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `p.loneWolf` |
| `p.duelClass` | duels | duel | Duel a friend of another class | 1 | a duel with a friend's community character of another class than the own | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `p.loneWolf` |
| `p.duelWins2` | duels | duel | Win 2 duels in a row | 3 | 2 duels won one after the other by one character, no loss between | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `p.rematch` | duels | duel | Rematch: beat the one who beat you | 3 | a duel won against an opponent who won the previous duel between the two that day | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `p.bgPlay` | battlegrounds | bg | Play a battleground to the end | 3 | a battleground run finished (won or lost, `PVP_MATCH_COMPLETE`) | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| `p.bgWin` | battlegrounds | bg | Win a battleground | 5 | a battleground run won | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| `p.bgKills5` | battlegrounds | bg | 5 kills in a battleground | 3 | 5 battleground kills in one run | existing tracker, waits for its launch check: V35b, V73 (battleground kills) | no character of level 10 or more → `p.loneWolf` |
| `p.bgFriend` | battlegrounds | bg | A battleground with a friend | 3 | a battleground run finished with a friend's community character in it | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| `p.bgFlag` | battlegrounds | bg | Capture a flag | 5 | a flag capture by the character (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |
| `p.bgBase` | battlegrounds | bg | Assault or defend a base | 3 | a base or tower assaulted or defended by the character (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |
| `p.bgTop` | battlegrounds | bg | Top killer of the team in a battleground | 5 | the most honorable kills of the own team in a finished battleground run (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |
| `p.salute` | taunts | emote | Salute a worthy enemy | 1 | the `/salute` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| `p.chicken` | taunts | emote | Call an enemy a chicken | 1 | the `/chicken` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| `p.bowKill` | taunts | kill | Bow, then win | 3 | the `/bow` emote at an enemy-faction player, then a counted kill of that player within 2 minutes | needs probe V108, V74, V73 |  |
| `p.flagUp` | taunts | flag | Flag up for PvP | 1 | a character flagged for PvP for 10 minutes that day, in total | CF-104 (pool 4), V121 |  |

### The Duel slot (daily)
- Your first duel with each friend that day: a win +3, a loss +1.
- It counts when the opponent's full name is another friend's community character.
- Both clients record the same duel, so a pair's duel counts once. When the two records disagree about the winner, the duel counts for neither.
- The Duel slot is not a goal for crossing out or the streak: it never counts toward them.
- It does count in "N of M done": M is exactly the goals on the grid (the 3 PvE dailies, the Hunt and the Skirmish, and the Duel slot), and the Duel slot is done after its first duel (live test 2026-10-29).

### Weekly bounty pool
`pick(week, 3, #pool)`:

| Id | Category | Needs | Goal | Points | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| `b.zone25` | worldKills | kill | 25 kills in the zone of the week | 10 | `pick(week, 5, #band)` from the band of the friend's highest character | now | no character of level 20 or more → `b.kills50` (from pool version 2) |
| `b.allClasses` | targets | kill | A kill of every enemy class | 15 | each class of the enemy list at least once | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.allRaces` | targets | kill | A kill of every enemy race | 10 | each race at least once | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.ranked5` | targets | kill | 5 kills on ranked players | 15 | victims with PvP rank 1 or higher | retired from pool version 3: no rank reads on Forever (`UnitPVPRank` missing, V79; Nico, 2026-11-06) |  |
| `b.kills50` | worldKills | kill | 50 counted kills | 10 | 50 counted world kills | now |  |
| `b.spree10` | streaks | kill | A spree of 10 | 15 | 10 kills on one character without dying | now |  |
| `b.hunt3` | targets | kill | The Hunt done on 3 days | 10 | the Hunt done on 3 days | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.duels3` | duels | duel | Duels with 3 different friends | 5 | duels with community characters of 3 other friends | now |  |
| `b.days5` | worldKills | kill | Kills on 5 days | 10 | a counted kill on 5 of the 7 days | now |  |
| `b.kills150` | worldKills | kill | 150 counted kills | 15 | 150 counted world kills | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| `b.zones8` | worldKills | kill | Kills in 8 zones | 10 | counted kills in 8 different zones | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| `b.nights3` | worldKills | kill | Night raids on 3 nights | 10 | a counted kill between 23:00 and 05:00 realm time on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| `b.enemyLand25` | worldKills | kill | 25 kills in the enemy's territory | 10 | counted kills in zones of the enemy faction, 25 in total | needs probe V123 (new) | no character of level 20 or more → `b.kills50` |
| `b.triples3` | worldKills | kill | 3 triples | 15 | 3 times 3 counted kills by one character within 2 minutes | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| `b.firstBlood3` | worldKills | kill | First blood on 3 days | 10 | the day's first counted kill of all friends, on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| `b.combos10` | targets | kill | 10 different Hunt combinations | 15 | counted kills of 10 different race and class combinations of the enemy list | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.punchUp10` | targets | kill | 10 kills on players 3+ levels above | 10 | 10 counted kills with `diff >= 3` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.skulls3` | targets | kill | Slay 3 skulls | 15 | 3 counted kills of skull victims | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.fair10` | targets | kill | 10 fair fights | 10 | 10 counted kills with `-2 <= diff <= 2` | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.nemesis` | targets | kill | Nemesis: the same player 3 times | 5 | counted kills of the same victim name on 3 different days | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| `b.solo20` | streaks | kill | 20 solo kills | 10 | 20 counted kills with `solo` | existing tracker, waits for its launch check: V73, V76 (CF-55b kills, `solo`) |  |
| `b.untouchable3` | streaks | kill | Untouchable on 3 days | 10 | 5 counted kills without dying on one character, on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| `b.revenge3` | streaks | kill | Revenge 3 times | 10 | 3 counted kills of the player who killed that character, each within 30 minutes | needs probe V120 (new) |  |
| `b.flagged3h` | streaks | flag | 3 hours flagged for PvP | 5 | 3 hours flagged for PvP in total, all characters of the week together | CF-104 (pool 4), V121 |  |
| `b.kd` | streaks | kill | More kills than deaths | 10 | at least 10 counted kills and fewer deaths to players than kills, over the week | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| `b.duoKills15` | teamwork | kill | 15 kills with friends | 10 | 15 counted kills while grouped with a friend's community character | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `b.kills50` |
| `b.warband` | teamwork | kill | A warband of 3 friends | 10 | 5 counted kills while grouped with community characters of 2 other friends | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `b.kills50` |
| `b.avenge3` | teamwork | kill | Avenge friends 3 times | 15 | counted kills of players who killed a friend in the same group within 10 minutes, 3 in total | needs probe V120 (new) | no other friend in the community → `b.kills50` |
| `b.huntAll` | teamwork | kill | Every friend does the Hunt | 10 | the Hunt done by every friend who played PvP that week (counted for each of them when the last one finishes) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) | no other friend in the community → `b.kills50` |
| `b.duelWins5` | duels | duel | Win 5 duels | 10 | 5 duels won (any opponent) | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `b.duelAll` | duels | duel | Duel every friend | 15 | a duel with a community character of every other friend who played that week (at least 2) | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `b.kills50` |
| `b.duelDays4` | duels | duel | Duel on 4 days | 5 | a duel on 4 days of the week | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `b.strangers3` | duels | duel | Beat 3 strangers in duels | 10 | duels won against 3 different players who are not community characters | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| `b.bgWins3` | battlegrounds | bg | Win 3 battlegrounds | 10 | 3 battleground runs won | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| `b.bgEach` | battlegrounds | bg | Play every battleground | 15 | a finished run in every battleground open to the character | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| `b.bgDays3` | battlegrounds | bg | Battlegrounds on 3 days | 10 | a finished battleground run on 3 days | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| `b.bgKills30` | battlegrounds | bg | 30 battleground kills | 10 | 30 battleground kills | existing tracker, waits for its launch check: V35b, V73 (battleground kills) | no character of level 10 or more → `b.kills50` |
| `b.bgFlags3` | battlegrounds | bg | Capture 3 flags | 15 | 3 flag captures | needs probe V122 (new) | no character of level 10 or more → `b.kills50` |
| `b.bgBases5` | battlegrounds | bg | Take or hold 5 bases | 10 | 5 bases or towers assaulted or defended | needs probe V122 (new) | no character of level 10 or more → `b.kills50` |
| `b.bgFriends` | battlegrounds | bg | Win a battleground with 2 friends | 15 | a battleground run won with community characters of 2 other friends in it | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| `b.rankUp` | honor | kill | Rise a PvP rank | 15 | a character's PvP rank higher than at the start of the week | retired from pool version 3: no rank reads on Forever (`UnitPVPRank` missing, V79; Nico, 2026-11-06) |  |
| `b.skirmish5` | honor | kill | The Skirmish done on 5 days | 10 | the day's Skirmish done on 5 days of the week | works now: the Skirmish `done` per day |  |
| `b.taunts5` | taunts | emote | Taunt 5 enemies | 5 | `/flex`, `/boo`, `/chicken` or `/rude` at 5 different enemy-faction players | needs probe V108, V74 |  |

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
| 0 | none | Conscientious Objector while a PvP Virgin (shown, never posted); otherwise "No rank yet · N kills" (never shown on Forever, see below) |
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

On Forever the own PvP rank isn't readable (`UnitPVPRank` missing, V79; Nico, 2026-11-06): `pvp.rank` stays empty, so no rank title shows, rank 0's rule included, and the rank goals are retired from pool version 3 (CF-99). The titles stay for when a rank reads.

## Lists
Enemy combinations, pool versions 1 to 4 (race token as `UnitRace` gives it, class token):
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

From pool version 5 (CF-116, Forever's combinations, 23 each, without the Skyborne races):
- **Alliance** (for Horde characters):
  - Human: Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock
  - Dwarf: Warrior, Paladin, Hunter, Rogue, Priest, Shaman
  - NightElf: Warrior, Hunter, Rogue, Priest, Druid
  - Gnome: Warrior, Rogue, Priest, Mage, Warlock
- **Horde** (for Alliance characters):
  - Orc: Warrior, Hunter, Rogue, Shaman, Mage, Warlock
  - Scourge: Warrior, Paladin, Rogue, Priest, Mage, Warlock
  - Tauren: Warrior, Hunter, Shaman, Druid
  - Troll: Warrior, Hunter, Rogue, Priest, Shaman, Mage, Warlock

Enemy classes (`b.allClasses`), pool versions 1 to 4:
- Alliance: Warrior, Paladin, Hunter, Rogue, Priest, Mage, Warlock, Druid
- Horde: Warrior, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid

From pool version 5: all nine for both (Warrior, Paladin, Hunter, Rogue, Priest, Shaman, Mage, Warlock, Druid).

Zone bands (the zone names as the feed stores them):
- **20–29:** Hillsbrad Foothills, Ashenvale, Stonetalon Mountains
- **30–44:** Stranglethorn Vale, Arathi Highlands, Desolace, Dustwallow Marsh, Alterac Mountains
- **45–54:** Tanaris, Feralas, The Hinterlands, Searing Gorge, Un'Goro Crater, Azshara
- **55–60:** Burning Steppes, Felwood, Winterspring, Eastern Plaguelands, Western Plaguelands, Silithus
