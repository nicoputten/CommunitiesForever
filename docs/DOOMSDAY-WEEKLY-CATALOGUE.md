# Doomsday: catalogue of PvE weeklies (draft)

Draft for Nico's review, 2026-11-03: 50 PvE weekly missions, numbered 1 to 50. It follows the daily catalogue
(`docs/DOOMSDAY-CATALOGUE.md`) and its decisions: general missions only (no zone, dungeon or place names), mostly new
kinds of activity, points per mission, a data status, can't-do with a fallback, and probe-gated where an API is
unverified. Nothing here is in the pool yet: no code, no `POOL_VERSION` bump, `docs/DOOMSDAY.md` unchanged.

The rules of `DOOMSDAY.md` hold: a Doomsday week runs from the Sunday reset to the next; per friend, any character
counts and progress adds up across characters; "a friend" is a community character of another BattleTag; 3 PvE
weeklies a week, never the same one two weeks running; a missing situation field never swaps; recommend, never
restrict; no pronouns; gold never shown as an amount.

## Summary

**50 weeklies in 14 categories.** The 20 existing weeklies are all kept with their ids (★); 30 are new. The categories
are the daily catalogue's; the weekly draw takes 3 different ones (decision 2).

| Category | Weeklies | Works now | Existing tracker | New, verified API | Needs probe |
|---|---|---|---|---|---|
| quests | 5 | 2 |  | 3 |  |
| levels | 5 | 5 |  |  |  |
| dungeons | 8 | 6 | 1 | 1 |  |
| crafts | 6 | 3 | 1 |  | 2 |
| cooking | 2 |  |  |  | 2 |
| fishing | 2 |  | 2 |  |  |
| firstaid | 1 |  |  |  | 1 |
| play | 7 | 4 | 3 |  |  |
| social | 5 |  | 3 | 2 |  |
| exploration | 3 |  | 1 | 2 |  |
| travel | 1 |  |  |  | 1 |
| combat | 3 |  |  |  | 3 |
| loot | 1 |  | 1 |  |  |
| care | 1 |  |  |  | 1 |
| **Total** | **50** | **20** | **12** | **8** | **10** |

- **Works now** (20): recorded today; 15 of them are pool version 1.
- **Existing tracker, waits for its launch check** (12): CF-52, CF-53 and CF-56 trackers, and V83 to V86.
- **New tracker, verified API** (8): the trackers of CF-71 to CF-73 (E18), which the dailies need anyway.
- **Needs probe** (10): V90 to V119 of the FriendProbe launch checklist; no new probe checks.

So **28 of 50 work without a probe**. Every tracker here is one the daily catalogue already needs: the weeklies add
no new tracker and no new probe check, only counts over a week.

## Points: 5, 10 or 15
Today every weekly scores 15. Proposal: three sizes, **5 / 10 / 15**, the daily scale (1 / 3 / 5) times about 3.
- **Why:** a week of dailies scores about 7 × 9 = 63 PvE points (3 dailies a day at 1 to 5 each). Three weeklies of
  10 add 30, about half a week of dailies: enough to matter, not enough to outweigh playing every day. 15 stays the
  top, so no weekly is worth more than today, as with the dailies.
- **5, light** (8): done along the way in a normal week (3 days, 3 characters, 5 discoveries, a new profession).
- **10, standard** (35): a goal you play towards on a couple of evenings.
- **15, demanding** (7): most of a week's play (every day, 5 levels, 5 dungeons, 100 fish, 200 enemies).
- Points per goal is the rule change of CF-69: the site counts from the `done` ids and the pool version recorded with
  the week.

## Decisions (Nico, 2026-11-03)
1. **Points stay 5 / 10 / 15** as above.
2. **The weekly draw takes 3 different categories**, as the dailies do. It changes the weekly draw and its golden
   cases on both sides, in the same pool version bump (E18, CF-77).
3. **Overlap with a daily is fine:** the same play counts for a daily and a weekly (`w.dungeons5` next to
   `d.dungeons2`), as `w.quests50` and `d.quests20` do today.

## Hard to track honestly
- **Per-day goals** (`w.days7`, `w.levelDays3`, `w.friendDays3`, `w.chatDays5`, `w.mentor3`) count Doomsday days,
  not calendar days: a session across the 19:00 reset counts for both days.
- **`w.dayAndNight`** uses the PC's local time, like `d.earlyBird`: a friend who changes the PC clock can game it.
- **`w.newZones3`** starts from the per-character zone set of CF-73, seeded from the stored feed: the first week can
  count an old zone as new.

## The catalogue

Columns: **#** (number for review, 1 to 50, stable) · **Id** (existing ids ★) · **Title** · **Label** (at most
10 characters) · **Points** · **Category** · **Done when** (that Doomsday week, Sunday reset to Sunday reset) ·
**Data** · **Can't do when → fallback**.

### quests (5)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 1 | ★ `w.quests50` | Finish 50 quests | 50 quests | 10 | quests | 50 quests handed in that week | works now (pool 1) |  |
| 2 | ★ `w.zones5` | Hand in quests in 5 zones | 5 zones | 5 | quests | quests handed in in 5 zones | works now (pool 1) |  |
| 3 | `w.groupQuests3` | Finish 3 group quests | 3 group Q | 10 | quests | 3 quests handed in that the quest log marked as group quests | new tracker, verified API: CF-71 |  |
| 4 | `w.questUp5` | Finish 5 quests above the character's level | 5 hard Q | 10 | quests | 5 quests handed in whose level is higher than the character's | new tracker, verified API: CF-71 | all characters at 60 → `w.quests50` |
| 5 | `w.duoQuests5` | Hand in 5 quests in a group with a friend | Duo quests | 10 | quests | 5 quests handed in while grouped with a friend's community character | new tracker, verified API: CF-71 |  |

### levels (5)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 6 | ★ `w.levels3` | Gain 3 levels | 3 levels | 10 | levels | 3 levels over all characters | works now (pool 1) | all characters at 60 → `w.quests50` |
| 7 | ★ `w.altLevels2` | Gain 2 levels on an alt | Alt 2 lvls | 10 | levels | 2 levels on one character that isn't the highest | works now (pool 1) | only one character below 60 → `w.quests50` |
| 8 | ★ `w.ilvl3` | Raise an item level by 3 | Item lvl+3 | 10 | levels | one character's item level 3 above its first login that week | works now (pool 1) | item level unreadable → `w.quests50` |
| 9 | `w.levels5` | Gain 5 levels | 5 levels | 15 | levels | 5 levels over all characters | works now | all characters at 60 → `w.quests50` |
| 10 | `w.levelDays3` | Gain a level on 3 days | Level days | 10 | levels | a level gained on 3 Doomsday days of the week | works now | all characters at 60 → `w.quests50` |

### dungeons (8)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 11 | ★ `w.dungeons3` | Run 3 dungeons | 3 dungeons | 10 | dungeons | 3 finished party runs | works now (pool 1) | no character in range of a dungeon → `w.quests50` |
| 12 | ★ `w.dungeonsDiff3` | Run 3 different dungeons | 3 distinct | 10 | dungeons | party runs in 3 different instances | works now (pool 1) | as `w.dungeons3` |
| 13 | ★ `w.dungeonFriends2` | Run a dungeon with 2 friends | Trio run | 10 | dungeons | a party run with community characters of 2 other friends | works now (pool 1) | as `w.dungeons3` |
| 14 | ★ `w.fullClear` | Clear every boss of a dungeon | Full clear | 10 | dungeons | one party run that killed every boss of that dungeon (`Goals.BOSSES`) | works now (pool 1) | as `w.dungeons3` |
| 15 | `w.dungeons5` | Run 5 dungeons | 5 dungeons | 15 | dungeons | 5 finished party runs | works now | as `w.dungeons3` |
| 16 | `w.bosses15` | Defeat 15 dungeon bosses | 15 bosses | 15 | dungeons | 15 bosses across the week's party runs | works now | as `w.dungeons3` |
| 17 | `w.newDungeons2` | Run 2 dungeons new to the character | New dgn x2 | 10 | dungeons | party runs with at least 1 boss in 2 dungeons the character had no earlier run of | new tracker, verified API: CF-72 | as `w.dungeons3` |
| 18 | `w.cleanRuns2` | Run 2 dungeons without dying | 2 clean | 10 | dungeons | two party runs, each with at least 1 boss and no death of that character in it | existing tracker, waits for its launch check: CF-52 deaths | as `w.dungeons3` |

### crafts (6)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 19 | ★ `w.skill25` | Earn 25 profession skill points | 25 skill | 10 | crafts | 25 points over all professions that week | works now (pool 1) | no profession → `w.quests50` |
| 20 | ★ `w.cap` | Reach a profession cap | Skill cap | 10 | crafts | a profession reaches 75/75, 150/150, 225/225 or 300/300 | works now (pool 1) | no profession below 300 → `w.skill25`, then `w.quests50` |
| 21 | ★ `w.newProf` | Learn a new profession | New prof | 5 | crafts | a character learns a profession it didn't have | works now (pool 1) |  |
| 22 | ★ `w.craftTrade` | Craft something and trade it | Craft gift | 10 | crafts | an item an own character created that week, given to a friend's community character in a trade | existing tracker, waits for its launch check: V85 | no crafting profession → `w.quests50` |
| 23 | `w.gather50` | Gather 50 herbs, ore or leather | Gather 50 | 10 | crafts | 50 items of the herb, metal and stone or leather classes looted from a gathering node or a skinned body | needs probe V106 | no character with Herbalism, Mining or Skinning → `w.skill25` |
| 24 | `w.recipes3` | Learn 3 new recipes | 3 recipes | 10 | crafts | 3 recipes learned | needs probe V104 | no profession at all → `w.newProf` |

### cooking (2)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 25 | `w.cook30` | Cook 30 dishes | Cook 30 | 10 | cooking | 30 food or drink items created | needs probe V105 | no character with Cooking → `w.skill25` |
| 26 | `w.cookKinds5` | Cook 5 different dishes | 5 dishes | 10 | cooking | food or drink items of 5 different item IDs created | needs probe V105 | no character with Cooking → `w.skill25` |

### fishing (2)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 27 | `w.fish100` | Catch 100 fish | 100 fish | 15 | fishing | 100 items from fishing loot | existing tracker, waits for its launch check: V84 | no character with Fishing → `w.skill25` |
| 28 | `w.fishZones4` | Fish in 4 zones | Fish 4 zns | 10 | fishing | fishing loot in 4 different zones | existing tracker, waits for its launch check: V84 | no character with Fishing → `w.skill25` |

### firstaid (1)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 29 | `w.bandages20` | Make 20 bandages | 20 bandage | 10 | firstaid | 20 bandages created | needs probe V105 | no character with First Aid → `w.skill25` |

### play (7)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 30 | ★ `w.days3` | Play on 3 days | 3 days | 5 | play | 3 Doomsday days with a login | works now (pool 1) |  |
| 31 | ★ `w.days5` | Play on 5 days | 5 days | 10 | play | 5 Doomsday days with a login | works now (pool 1) |  |
| 32 | ★ `w.chars3` | Play 3 different characters | 3 chars | 5 | play | 3 characters logged in that week | works now (pool 1) | fewer than 3 characters → `w.days3` |
| 33 | ★ `w.session2h` | Play a 2-hour session | 2h session | 5 | play | one login lasting 2 hours | existing tracker, waits for its launch check: CF-53 sessions |  |
| 34 | `w.days7` | Play on all 7 days | Every day | 15 | play | all 7 Doomsday days of the week with a login | works now |  |
| 35 | `w.dayAndNight` | Play before 09:00 and after 23:00 | Day+night | 10 | play | a login before 09:00 local time and a login between 23:00 and 03:00 local time, in the same week | existing tracker, waits for its launch check: CF-53 sessions |  |
| 36 | `w.deathless3h` | Play 3 hours without dying | Iron 3h | 15 | play | 3 hours of session time on one character with no death in between | existing tracker, waits for its launch check: CF-52 deaths, CF-53 sessions |  |

### social (5)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 37 | ★ `w.friends3` | Group with 3 different friends | 3 friends | 10 | social | in a group with community characters of 3 other friends | existing tracker, waits for its launch check: CF-53 groups |  |
| 38 | `w.friendDays3` | Group with a friend on 3 days | Duo days | 10 | social | in a group with a friend's community character on 3 Doomsday days | existing tracker, waits for its launch check: CF-53 groups |  |
| 39 | `w.trades3` | Trade with 3 different friends | 3 trades | 10 | social | completed trades with community characters of 3 other friends | existing tracker, waits for its launch check: V85 | fewer than 3 other friends in the community → `w.friends3` |
| 40 | `w.chatDays5` | Chat in the community on 5 days | Chatty | 5 | social | an own message in the selected community's channel on 5 Doomsday days | new tracker, verified API: CF-73 (V38) |  |
| 41 | `w.mentor3` | Group with a lower friend on 3 days | Mentor | 10 | social | grouped with a friend's community character 5 or more levels below the own character, on 3 Doomsday days | new tracker, verified API: CF-73 |  |

### exploration (3)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 42 | ★ `w.discover5` | Discover 5 new places | Discover 5 | 5 | exploration | 5 of the game's "Discovered" messages | existing tracker, waits for its launch check: V86 |  |
| 43 | `w.newZones3` | Set foot in 3 zones new to the character | 3 new zns | 10 | exploration | zones entered that the character had never been in, 3 in total | new tracker, verified API: CF-73 |  |
| 44 | `w.roam10` | Visit 10 zones | Roam 10 | 10 | exploration | 10 different zones entered | new tracker, verified API: CF-73 |  |

### travel (1)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 45 | `w.flightPaths3` | Learn 3 flight paths | 3 paths | 10 | travel | 3 new flight paths learned | needs probe V94 |  |

### combat (3)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 46 | `w.kills200` | Defeat 200 enemies | 200 foes | 15 | combat | 200 kill XP messages | needs probe V90 | all characters at 60 → `w.dungeons3` |
| 47 | `w.elites10` | Defeat 10 elites | 10 elites | 10 | combat | kill XP messages naming creatures last seen as elite or rare elite, 10 in total | needs probe V90, V93 | all characters at 60 → `w.dungeons3` |
| 48 | `w.weapon25` | Raise weapon skills 25 times | Weapon +25 | 10 | combat | 25 weapon or defense skill-up messages | needs probe V107 |  |

### loot (1)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 49 | ★ `w.rare5` | Loot 5 rare items | 5 rares | 10 | loot | 5 rare (blue) or better items looted | existing tracker, waits for its launch check: V83 |  |

### care (1)

| # | Id | Title | Label | Points | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 50 | `w.potions5` | Drink 5 potions | 5 potions | 5 | care | 5 potions used | needs probe V116 |  |
