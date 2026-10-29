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

The two are always shown side by side ("PvE 85 · PvP 240"), **never added together**, and each has its own ranking. A friend who never does PvP is never ranked against gankers: a friend with no PvP point (duel points included) and no honorable kill on any character, ever, is a **PvP Virgin** and is not ranked on the PvP ladder. Any PvP point or any kill ends it (Nico, live test 2026-10-29).

## Per friend
Everything counts per friend (BattleTag): any of your characters counts, and progress adds up across characters (6 quests on one, 4 on another = 10). "Another friend" means a character of a different BattleTag, as the `with` lists of runs already use; your own alts don't count as a friend.

## Schedule
- A **Doomsday day** runs from the reset time to the next one. The default reset is **19:00 realm time**, a group setting (Nico, 2026-10-28: "make it a changeable setting"). A day is named after its start: the weekday plus the part of the day of the reset hour, 05–11 "morning", 12–16 "afternoon", 17–22 "evening", 23–04 "night" ("Doomsday · Tue evening", the span "Tue 19:00 → Wed 19:00"). Times after midnight carry their weekday ("done Wed 00:04"); the countdown reads "resets Wed 19:00 · in 6 h 51 m" (Nico, live test 2026-10-29).
- **Realm time** is the game's clock (`GetGameTime`, unverified: V78). The addon gets the realm's offset from UTC as the difference between `GetGameTime()` and `GetServerTime()`, rounded to 15 minutes, so daylight saving follows the realm. The site has the realm's IANA time zone as a setting (default `Europe/Paris` for EU realms).
- **Everyone has the same day** (Nico, 2026-10-28: friends play from the Netherlands, the UK and Thailand). The day boundary is always realm time, never the PC's. Without `GetGameTime` the addon takes the offset the site sends (`offset`, `offsetUntil`, `offsetAfter` below), and without that CET/CEST (the EU summer-time dates). **Clock times shown** ("done Wed 00:04", the reset, the span) are realm time in the addon's chat lines and in the bot; the site shows them in each viewer's own time zone (Nico, 2026-10-29). "resets in 3 h 12 m" is the same for all.
- **Day number:** `n = floor((serverTime + realmOffset - resetSeconds) / 86400)`, where `resetSeconds` is the reset time in seconds after midnight (19:00 = 68400). Day 0 started on Thursday 1970-01-01.
- **Week:** a Doomsday week starts on **Sunday** at the reset time. `week = floor((n + 4) / 7)`: day 3 (Sunday 1970-01-04) starts week 1. Not tied to the game's weekly reset or its honor week.
- **The setting:** the reset time lives on the site (the Discord page, admin: hours and minutes in realm time). It reaches the addon through `Data\Runs.lua`, written by the uploader, and from there through HELLO (`dd`) to friends without the uploader: the newest `changedAt` wins. Without it, the addon uses 19:00. A change takes effect from the next reset, never in the middle of a day. Agreed with the site (web PR #108), every field optional:
  - `CF_RUNS.doomsday = { reset, changedAt, offset, offsetUntil, offsetAfter }`
  - `reset`: the reset in force, seconds after realm midnight. The site sends a new reset only from the reset it takes effect at, so the addon applies it as given.
  - `changedAt`: when that reset took effect; 0 while it was never changed.
  - `offset`: the realm zone's UTC offset now, in seconds east; `offsetUntil`: the server time of its next change; `offsetAfter`: the offset from then on. Both are left out when the zone has no change within 400 days.
- Screens show the time left: "resets in 3 h 12 m".

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
| A daily done (the PvE dailies, the Hunt, the Skirmish) | 5 | 5 |
| A weekly done (the PvE weeklies, the Weekly bounty) | 15 | 15 |
| A kill | | see "Kill points" |
| A duel, per pair of friends, the first one of the day | | win 3 · loss 1 |

Each goal counts once per day or week. Feats give no points.

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

**Swaps.** Per friend, from a **situation** summed over that friend's characters: `chars`, `below60`, `altBelow60` (characters below 60 other than the highest one), `highest`, `highestToday` (the highest level that played that day), and the booleans `ilvlReadable`, `dungeonInRange`, `hasProfession`, `hasFishing`, `hasCraftingProfession`, `professionBelow300`, `friendQuestLog`. **A missing field never swaps** (unknown counts as "can do").
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
Data: **now** = the addon records it today. **52**, **53**, **56** = trackers from CF-52, CF-53 and CF-56 (unverified until launch).

### PvE dailies

| Id | Category | Goal | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.quests10` | quests | Finish 10 quests | 10 quests handed in that day | now | |
| `d.quests20` | quests | Finish 20 quests | 20 quests handed in that day | now | |
| `d.zone5` | quests | Finish 5 quests in one zone | 5 quests in one zone (feed `quests` by zone) | now | |
| `d.zones3` | quests | Hand in quests in 3 zones | quests in 3 zones that day | now | |
| `d.shared3` | quests | Share 3 quests with a friend | at some moment that day, your quest log and one friend's synced log share 3 quests | now | no friend's quest log known → `d.quests10` |
| `d.level` | levels | Gain a level | a character gains a level that day | now | all characters at 60 → `d.quests20` |
| `d.altLevel` | levels | Gain a level on an alt | a level on any character but your highest | now | only one character below 60 → `d.quests10` |
| `d.ilvl` | levels | Raise an item level | a character's item level is higher than at its first login that day | now | item level unreadable → `d.quests10` |
| `d.cleanLevel` | levels | Gain a level without dying | a level on a character with no death between that level and the previous one | 52 | all characters at 60 → `d.quests20` |
| `d.dungeon` | dungeons | Run a dungeon | a finished party run (feed `runs`) | now | no character in range of a dungeon (`Dungeons`) → `d.quests10` |
| `d.dungeonFriend` | dungeons | Run a dungeon with a friend | a party run with at least one community character of another friend (`with`) | now | as `d.dungeon` |
| `d.bosses3` | dungeons | Defeat 3 dungeon bosses | 3 bosses across that day's party runs | now | as `d.dungeon` |
| `d.skill5` | crafts | Earn 5 profession skill points | 5 points over all professions since the first login that day | now | no profession on any character → `d.quests10` |
| `d.secondary` | crafts | Raise Cooking, First Aid or Fishing | 1 point in one of them, or learning one | now | |
| `d.fish20` | crafts | Catch 20 fish | 20 items from fishing loot | 56 | no character with Fishing → `d.secondary` |
| `d.chars2` | play | Play 2 of your characters | 2 characters logged in that day | now | only one character → `d.quests10` |
| `d.groupFriend` | play | Group up with a friend | in a group with another friend's community character | 53 | |
| `d.trade` | play | Trade with a friend | a completed trade with another friend's community character | 56 | |
| `d.rare` | play | Loot a rare item | a rare (blue) or better item looted | 53 | |
| `d.earlyBird` | play | Early bird: play before 09:00 | logged in before 09:00 your local time | 53 | |

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

| Id | Goal | Done when | Can't do when → fallback |
|---|---|---|---|
| `p.frontLine` | Front line: 5 kills in the zone of the day | 5 counted kills in that zone. The zone is `pick(n, 4, #band)` from the band of the friend's highest character that played that day (see Lists) | no character of level 20 or more → `p.loneWolf` |
| `p.punchUp` | Punch up: 2 kills on players 3+ levels above you | 2 counted kills with `diff >= 3` (a skull counts) | |
| `p.loneWolf` | Lone wolf: 3 solo kills | 3 counted kills with `solo` | |
| `p.untouchable` | Untouchable: 5 kills without dying | 5 counted kills on one character with no death in between | |
| `p.variety` | Variety: kills of 3 different classes | 3 different victim classes | |
| `p.ranked` | Ranked bounty: kill a ranked player | 1 counted kill of a victim with PvP rank 1 or higher | |

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
- **Gear:** the first epic, mount and epic mount.
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
