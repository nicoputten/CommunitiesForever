# PvP ladder: rules

Decided with Nico, 2026-10-28. This file is the one description of the ladder's points and goals. The addon (CF-55, CF-56), the site (web WEB-58, WEB-59) and the bot (BOT-15) follow it. The addon computes the ladder in `src/core/Ladder.lua`, and the site has its own TypeScript copy. `tests/fixtures/ladder-cases.json` (golden cases: kills and duels in, points, goal progress and draws out) is copied into the web repo and tested in both, so the two copies can't drift apart. A rule change updates this file, the golden file and both copies in the same release.

**Name:** the ladder's points are **DoomPoints PvP**. The dailies and weeklies (a separate workshop and stories) give **DoomPoints PvE**. The two are shown side by side ("DoomPoints · PvE 34 · PvP 1,210", this week and all time), never summed and never ranked together. PvP goals (kills, duels, battleground wins) live only here, and the dailies pool has none.

Product rule: recommend, never restrict. Goals are suggestions with points, never conditions to play.

## Data
The rules use only what the addon can observe (CF-54 checks which of it Forever gives):
- **kills** from the feed's `pvpKills` (CF-55): time, zone, victim name, victim level (`-1` = skull), victim class and race tokens, victim PvP rank, own level at the kill, `solo` (not in a group), `bg` (inside a battleground).
- **deaths** with their time (CF-52 plus `t` from CF-55), **duels** (CF-52), **battleground results** in `runs` (CF-23), and lifetime honorable kills and rank (CF-52 `chars.*.pvp`).

Any victim field may be unknown (nil). A rule that needs an unknown field gives its fallback, and a goal that needs it can't be drawn (see Goals).

## Days and weeks
- A day is the realm day of the feed (CF-22).
- A week starts on the game's weekly reset day: **Wednesday** in Europe (region 3), **Tuesday** everywhere else. The addon reads the region from `GetCurrentRegion()` (guarded; Wednesday when unknown). The site has one setting for its group.
- Week number: `week = floor((day + 3 - resetWeekday) / 7)`, where `resetWeekday` is 1 for Tuesday and 2 for Wednesday (Monday = 0; day 0, 1970-01-01, was a Thursday).

## DoomPoints PvP per kill (world kills)
A kill with `bg = true` never counts here: it goes to the battleground block.

A kill is **counted** unless:
- the victim's full name is a character of the selected community (never split, rule 4), or
- it is the 4th or later kill of the same victim name by the same character on that day.

Points for a counted kill, from `diff = victim level - own level`:

| Victim | Points |
|---|---|
| level unknown | 1 |
| skull (`-1`) | 3 |
| `diff <= -4` (4 or more below) | 0 |
| `-3 <= diff <= 2` | 1 |
| `diff >= 3` (3 or more above) | 2 |

**Solo:** +1 when `solo` is true and the kill was worth more than 0. Without the own level, the kill counts as "level unknown".

## Goals
Each goal has a **draw**, which comes from the day or week number, so every friend sees the same goal without the site. Goals count per character, and only counted world kills count toward them, unless a goal says otherwise.

Draw: `pick(n, salt, count) = ((n * 2654435761 + salt) % 4294967296) % count + 1`, with `n` the realm day or week number. This is exact in Lua 5.1 doubles and in JavaScript numbers. Lists are drawn in the order written here.

A goal that needs a field the probe found unreadable on Forever is left out of its pool (a flag per goal in both copies). If a pool is then empty, that goal slot stays empty.

### Daily
| Goal | Draw | Points |
|---|---|---|
| **Hunt** | an enemy race and class combination, `pick(day, 1, 20)` from the enemy faction's list | +5 for each kill of that exact combination; +1 for a kill matching only the race or only the class; at most 3 hunt kills a day |
| **Class hunt** | per own class: `pick(day, 100 + classID, 20)` from the enemy list. If it equals the Hunt, the next one in the list | +2 for each kill of that combination, at most 3 a day |
| **Daily** | one from the daily pool, `pick(day, 2, #pool)` | +5 when done |
| **Duel** | none: duel a friend | per pair of friends, the first duel of the day: win +3, loss +1 |

The enemy faction is the other faction of the character's own one. There is no setting.

**Daily pool**
1. **Front line:** 5 kills in the zone of the day. The zone is `pick(day, 4, #band)` from the character's level band (below). Characters below level 20 get Lone wolf instead.
2. **Punch up:** 2 kills on victims 3 or more levels above you (skull counts).
3. **Lone wolf:** 3 solo kills.
4. **Untouchable:** 5 kills without dying in between.
5. **Variety:** kills of 3 different classes.
6. **Ranked bounty:** 1 kill of a victim with a PvP rank of 1 or higher.

**A duel counts** when the opponent's full name is a character of the community, and the pair has dueled each other on that realm day. Both clients record the same duel, so a pair's duel counts once. When the two records disagree about the winner, the duel counts for neither.

### Weekly
| Goal | Draw | Points |
|---|---|---|
| **Streak** (fixed) | none | +15: a counted kill on 5 of the 7 days of the week |
| **Class weekly** | per own class: an enemy class, `pick(week, 200 + classID, #enemy classes)` | +20: 10 kills of that class |
| **Weekly bounty** | one from the bounty pool, `pick(week, 3, #pool)` | +30 when done |

**Bounty pool**
1. 25 kills in the zone of the week: `pick(week, 5, #band)` from the character's band.
2. At least one kill of every enemy class.
3. At least one kill of every enemy race.
4. 5 kills on victims with a PvP rank of 1 or higher.
5. 50 counted kills.
6. A spree of 10: 10 kills without dying in between.
7. The Hunt done (3 hunt kills) on 3 days.
8. Duels with 3 different friends.

### Battleground block
- Battleground kills (`bg = true`) score with the same bands and the same counting rules.
- Daily **Battleground win:** +5 for a won battleground (`runs`, `kind = "pvp"`, `won = true`), once a day.
- The block ranks by these battleground points (not DoomPoints PvP) and shows wins, losses and kills per battleground. It never adds to the world ladder.

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

## Views
- **Week:** friends ranked by the week's DoomPoints PvP (kill points plus goal points), the sum of their characters, which can be expanded to the split per character. Ties: more counted kills first.
- **Lifetime:** friends ranked by the game's lifetime honorable kills (`chars.*.pvp`, summed), with each character's PvP rank. The site also shows all-time DoomPoints PvP, because it keeps every day; the addon only keeps 7 days.
- **Duels:**
  - wins and losses this week
  - a head-to-head grid between friends
  - on the site and in the bot only: an Elo rating over all duels between friends. Start 1000, K = 32, in time order; a disputed duel doesn't count.
- **Battlegrounds:** the block above.
- **PvP Virgin:** a character whose lifetime honorable kills are 0, or, when that counter is unknown, a character with no kill ever recorded. A friend is a PvP Virgin when all their characters are.

## Later (needs the combat log, CF-54)
If the killer's name turns out readable: a **Wanted poster** (the enemy who killed us most this week; killing them is +10) and a **revenge kill** (killing your killer within 10 minutes: +2). Each gets its own story.
