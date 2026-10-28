# Dailies and weeklies: the pool

The catalogue of daily and weekly goals (CF-57 to CF-60; designed with Nico on 2026-10-28). The code (`src/core/Dailies.lua`) is the source of truth once it exists. Change this file together with it. The site keeps a copy of the ids and titles (web `docs/STORIES.md`, WEB-60).

## Rules

- **Per friend:** any of your characters counts. Progress adds up across characters (6 quests on one, 4 on another = 10).
- **3 dailies** per realm day (the feed's day number), **3 weeklies** per week. A week runs Monday to Sunday in realm days: `week = floor((day + 3) / 7)` (day 0, 1970-01-01, was a Thursday).
- **Picked, not chosen:** a seeded pick from the realm day (or week) number and the pool version. Everyone on the same pool version gets the same base set, without the site. The 3 dailies come from 3 different categories. A goal isn't picked twice in a row: not on two days running, and not in two weeks running.
- **Swap:** when none of your characters can do a goal (the "Can't do when" column), it is swapped for its fallback, for you only. If the fallback is in the set already, or can't be done either, the next goal in pool order that can be done takes its place. A swap is fixed for the day once made. It recommends, it doesn't restrict: you may still do the original, but only the swapped goal counts.
- **DoomPoints PvE:** 1 per daily, 3 per weekly, no bonus. Each goal counts once per day or week. (DoomPoints PvP come from the PvP ladder. The two are shown side by side and never added up.)
- **Streak:** realm days in a row with all 3 dailies done. A day without them ends it. No points.
- **Pool version:** `Dailies.POOL_VERSION`. A goal that waits for data (column "Data") joins the pool only in the release after its API is verified, and that release bumps the version. Ids are never reused or renamed. A retired goal keeps its id in the catalogue, marked retired.

Data: **now** = the addon records it today. **52** / **53** = trackers from CF-52 / CF-53 (unverified until launch). **60** = new trackers from CF-60 (unverified).

## Dailies

| Id | Category | Goal | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.quests10` | quests | Finish 10 quests | 10 quests handed in today | now | |
| `d.quests20` | quests | Finish 20 quests | 20 quests handed in today | now | |
| `d.zone5` | quests | Finish 5 quests in one zone | 5 quests in one zone (feed `quests` by zone) | now | |
| `d.zones3` | quests | Hand in quests in 3 zones | quests in 3 zones today | now | |
| `d.shared3` | quests | Share 3 quests with a friend | at some moment today, your quest log and one friend's synced log share 3 quests | now | no friend's quest log known → `d.quests10` |
| `d.level` | levels | Gain a level | a character gains a level today | now | all characters at 60 → `d.quests20` |
| `d.altLevel` | levels | Gain a level on an alt | a level on any character but your highest | now | only one character below 60 → `d.quests10` |
| `d.ilvl` | levels | Raise an item level | a character's item level is higher than at its first login today | now | item level unreadable → `d.quests10` |
| `d.cleanLevel` | levels | Gain a level without dying | a level on a character with no death between that level and the previous one | 52 | all characters at 60 → `d.quests20` |
| `d.dungeon` | dungeons | Run a dungeon | a finished party run (feed `runs`) | now | no character in range of a dungeon (`Dungeons`) → `d.quests10` |
| `d.dungeonFriend` | dungeons | Run a dungeon with a friend | a party run with at least one community character of another friend (`with`) | now | as `d.dungeon` |
| `d.bosses3` | dungeons | Defeat 3 dungeon bosses | 3 bosses across today's party runs | now | as `d.dungeon` |
| `d.skill5` | crafts | Earn 5 profession skill points | 5 points over all professions since the first login today | now | no profession on any character → `d.quests10` |
| `d.secondary` | crafts | Raise Cooking, First Aid or Fishing | 1 point in one of them, or learning one | now | |
| `d.fish20` | crafts | Catch 20 fish | 20 items from fishing loot | 60 | no character with Fishing → `d.secondary` |
| `d.chars2` | play | Play 2 of your characters | 2 characters logged in today | now | only one character → `d.quests10` |
| `d.groupFriend` | play | Group up with a friend | in a group with another friend's community character | 53 | |
| `d.trade` | play | Trade with a friend | a completed trade with another friend's community character | 60 | |
| `d.rare` | play | Loot a rare item | a rare (blue) or better item looted | 53 | |
| `d.earlyBird` | play | Early bird: play before 09:00 | logged in before 09:00 your local time | 53 | |

## Weeklies

| Id | Goal | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|
| `w.days3` | Play on 3 days | 3 realm days with a login this week | now | |
| `w.days5` | Play on 5 days | 5 realm days with a login | now | |
| `w.chars3` | Play 3 different characters | 3 characters logged in this week | now | fewer than 3 characters → `w.days3` |
| `w.levels3` | Gain 3 levels | 3 levels over all characters | now | all characters at 60 → `w.quests50` |
| `w.altLevels2` | Gain 2 levels on an alt | 2 levels on one character that isn't your highest | now | only one character below 60 → `w.quests50` |
| `w.quests50` | Finish 50 quests | 50 quests handed in | now | |
| `w.zones5` | Hand in quests in 5 zones | quests in 5 zones | now | |
| `w.dungeons3` | Run 3 dungeons | 3 finished party runs | now | no character in range of a dungeon → `w.quests50` |
| `w.dungeonsDiff3` | Run 3 different dungeons | party runs in 3 different instances | now | as `w.dungeons3` |
| `w.dungeonFriends2` | Run a dungeon with 2 friends | a party run with community characters of 2 other friends | now | as `w.dungeons3` |
| `w.fullClear` | Clear every boss of a dungeon | one party run that killed every boss of that dungeon | now | as `w.dungeons3` |
| `w.skill25` | Earn 25 profession skill points | 25 points over all professions this week | now | no profession → `w.quests50` |
| `w.cap` | Reach a profession cap | a profession reaches 75/75, 150/150, 225/225 or 300/300 (as the site's milestone) | now | no profession below 300 → `w.skill25`, then `w.quests50` |
| `w.newProf` | Learn a new profession | a character learns a profession it didn't have | now | |
| `w.ilvl3` | Raise an item level by 3 | one character's item level 3 above its first login this week | now | item level unreadable → `w.quests50` |
| `w.friends3` | Group with 3 different friends | in a group with community characters of 3 other friends | 53 | |
| `w.rare5` | Loot 5 rare items | 5 rare (blue) or better items | 53 | |
| `w.session2h` | Play a 2-hour session | one login lasting 2 hours | 53 | |
| `w.discover5` | Discover 5 new places | 5 of the game's "discovered" messages (exploration) | 60 | |
| `w.craftTrade` | Craft something and trade it | an item one of your characters created this week, given to another friend's community character in a trade | 60 | no crafting profession → `w.quests50` |

"Another friend's community character" means a character of a different BattleTag, as the `with` lists of runs already use. Your own alts don't count.
