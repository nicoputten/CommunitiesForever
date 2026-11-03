# Doomsday: catalogue of PvP missions (draft)

Draft for Nico's review, 2026-11-03: 100 PvP missions, numbered 1 to 100: **57 for the Skirmish** (the daily PvP
slot) and **43 for the Bounty** (the weekly PvP slot). 19 of them are existing ids (★): the Skirmish and Bounty
pools of `docs/DOOMSDAY.md` and the 4 Skirmish goals approved in the daily catalogue (`docs/DOOMSDAY-CATALOGUE.md`
#122 to #125). Nothing here is in the pool yet: no code, no `POOL_VERSION` bump, `DOOMSDAY.md` unchanged.

The rules of `DOOMSDAY.md` hold: PvP points are their own track, shown next to PvE and never added to it; kills are
"counted" by its kill rules; battleground kills are their own block; per friend, any character counts; general
missions only (no zone or place names; "the zone of the day" is the existing drawn zone); recommend, never restrict;
no pronouns.

## Summary

| Slot | Category | Goals | Works now | Existing tracker | Needs probe |
|---|---|---|---|---|---|
| skirmish | world kills | 11 |  | 8 | 3 |
| skirmish | targets | 15 |  | 15 |  |
| skirmish | streaks | 6 |  | 4 | 2 |
| skirmish | teamwork | 5 |  | 4 | 1 |
| skirmish | duels | 7 |  | 7 |  |
| skirmish | battlegrounds | 7 |  | 4 | 3 |
| skirmish | taunts | 6 |  |  | 6 |
| bounty | world kills | 9 |  | 8 | 1 |
| bounty | targets | 9 |  | 9 |  |
| bounty | streaks | 6 |  | 4 | 2 |
| bounty | teamwork | 4 |  | 3 | 1 |
| bounty | duels | 5 |  | 5 |  |
| bounty | battlegrounds | 7 |  | 5 | 2 |
| bounty | honor | 2 | 1 | 1 |  |
| bounty | taunts | 1 |  |  | 1 |
| **Total** | | **100** | **1** | **77** | **22** |

- **Works now** (1): `b.skirmish5`, from the Skirmish `done` the addon records.
- **Existing tracker, waits for its launch check** (77): almost every kill goal reads the raw kills of CF-55b
  (`pvpKills`: victim name, level, class, race, rank, `solo`, zone, time) and so waits for V73, V74 and V76 of the
  launch run; deaths and duels are CF-52's, battlegrounds CF-23's (V35b), the own rank V79.
- **Needs probe** (22): emotes (V108, already in the probe) and four new checks, to be added to the FriendProbe
  launch checklist in a follow-up PR:
  - **V120** the player who killed you: does `C_DeathRecap` (V81 says it exists) give the killer's name? Without the
    combat log it is the only source. Revenge and avenge goals need it.
  - **V121** the PvP flag: `UnitIsPVP("player")` and `PLAYER_FLAGS_CHANGED`.
  - **V122** battleground objectives: `GetBattlefieldScore` (or `C_PvP.GetScoreInfo`) stats such as flag captures and
    bases assaulted or defended, and honorable kills per player.
  - **V123** the zone's PvP type: `C_PvP.GetZonePVPInfo()` ("hostile", "friendly", "contested", "sanctuary").

**What the goals need:** 66 need a kill, 12 a duel, 14 a battleground, 5 only an emote at an enemy
player and 3 only the PvP flag.

## Points
The PvE scales, per slot: **Skirmish 1 / 3 / 5** (as a PvE daily), **Bounty 5 / 10 / 15** (as a PvE weekly, #177).
- 1: an emote, a flag, a duel; 3: a normal Skirmish; 5: a hard or lucky one (a skull, a ranked victim, a flag capture,
  a triple). Bounty 5: a few evenings of light PvP; 10: standard; 15: a full PvP week (150 kills, every class, every
  battleground).
- This also answers the open question of the stories PR (#176) for the pool-1 goals: `p.frontLine` 3, `p.loneWolf` 3,
  `p.untouchable` 5; Bounty `b.zone25` 10, `b.kills50` 10, `b.days5` 10, `b.spree10` 15, `b.duels3` 5, and the goals
  that wait for the Hunt's fields (`p.punchUp` 3, `p.variety` 3, `p.ranked` 5, `b.allClasses` 15, `b.allRaces` 10,
  `b.ranked5` 15, `b.hunt3` 10).

## The PvP Virgin and "never ranked against gankers"
`DOOMSDAY.md`: a friend with no PvP point (duel points included) and no honorable kill on any character, ever, is a
**PvP Virgin** and is not ranked on the PvP ladder; any PvP point or kill ends it. The PvP ladder is a ranking of its
own, so a friend who never does PvP is never ranked against gankers.
- **Kill, duel and battleground goals** need the fight that ends PvP Virgin status anyway: nothing changes. A PvP
  Virgin sees the Skirmish and the Bounty as suggestions (recommend, never restrict) and stays unranked until the
  first kill or PvP point.
- **Emote and flag goals** (`needs` emote or flag: 5 + 3) score PvP points without a fight. Under today's
  rule the first one ends PvP Virgin status: a friend who flexes once would then be ranked among the gankers with a
  single point. See question 1.
- **Gank guard rails:** the counted-kill rules stay (no community characters, no 4th kill of the same name in a day,
  kills 4+ levels below score 0 kill points). Goals that reward fighting up (`p.punchUp5`, `p.skull`, `b.punchUp10`)
  and fair fights (`p.fairFight`, `b.fair10`) outnumber the one that rewards fighting down (`p.punchDown5`, approved).
  `p.nemesis` and `b.nemesis` count the same victim at most twice a day and on 3 different days.
- **Battleground goals** score PvP points from battleground play, while battleground kills score only battleground
  points (`DOOMSDAY.md` "Battleground block"). See question 2.

## Design questions for Nico
1. **Emote and flag goals and PvP Virgin:** should a goal that needs no fight (taunts, the flag) leave PvP Virgin
   status alone (its points count, but the friend stays unranked until a kill, a duel or a battleground), or end it
   as any PvP point does today?
2. **Battleground goals:** keep them in the Skirmish and the Bounty (PvP points for winning or playing a
   battleground), or move them to the battleground block with their own points?
3. **The new probe checks V120 to V123:** add them to the FriendProbe launch checklist now, so the launch run answers
   them? Without V120 the 4 revenge and avenge goals stay out.

## Hard to track honestly
- **The killer's name** (V120): without the combat log only the death recap can tell who killed you; if it doesn't,
  `p.revenge`, `p.avenge`, `b.revenge3` and `b.avenge3` are retired.
- **Victim fields come from the target cache**, as for the Hunt: a victim never targeted or moused over has no level,
  class or race, so it counts for "counted kill" goals but not for level, class or race goals.
- **First blood** (`p.firstBlood`, `b.firstBlood3`): the addon decides when it sees the own kill earlier than every
  friend's kill it knows that day. A friend's earlier kill that syncs later doesn't undo it.
- **`b.huntAll`** waits for every PvP-playing friend's synced Hunt: friends on an older addon or offline all week
  can't be seen, and count as not playing PvP that week.
- **Battleground scores** (V122) are per battleground; a battleground without flags or bases never counts for those.

## The catalogue

Columns: **#** (number for review, 1 to 100, stable) · **Id** (existing ids ★) · **Title** · **Label** (at most
10 characters) · **Points** · **Needs** (kill, duel, bg, emote or flag) · **Done when** (that Doomsday day for a
Skirmish, that week for a Bounty) · **Data** · **Can't do when → fallback**.

"Counted kill" is the counting rule of `DOOMSDAY.md` "Kill points": world kills only, never a community character,
never the 4th or later kill of the same name that day. Battleground kills count only in the "battlegrounds" goals.

## Skirmish (daily)

### Skirmish · world kills (11)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 1 | ★ `p.frontLine` | Front line: 5 kills in the zone of the day | Front line | 3 | kill | 5 counted kills in the zone of the day (band of the highest character that played) | existing tracker, waits for its launch check: V73 (pool 1) | no character of level 20 or more → `p.loneWolf` |
| 2 | ★ `p.loneWolf` | Lone wolf: 3 solo kills | Lone wolf | 3 | kill | 3 counted kills with `solo` | existing tracker, waits for its launch check: V73, V76 (CF-55b kills, `solo`) (pool 1) |  |
| 3 | `p.kills10` | Score 10 kills | 10 kills | 3 | kill | 10 counted world kills | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 4 | `p.zones3` | Kills in 3 zones | 3 zones | 3 | kill | counted kills in 3 different zones | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 5 | `p.double` | Double: 2 kills within 10 seconds | Double | 5 | kill | 2 counted kills by one character within 10 seconds | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 6 | `p.triple` | Triple: 3 kills within 2 minutes | Triple | 5 | kill | 3 counted kills by one character within 2 minutes | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 7 | `p.firstBlood` | First blood: the first kill among friends | 1st blood | 5 | kill | the day's first counted world kill of all friends (by the kill's time in the synced records) | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 8 | `p.nightRaid` | Night raid: a kill after 23:00 realm time | Night raid | 3 | kill | a counted kill between 23:00 and 05:00 realm time (`GetGameTime`) | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `p.loneWolf` |
| 9 | `p.enemyLand` | Kill in the enemy's territory | Enemy land | 3 | kill | a counted kill in a zone of the enemy faction (`C_PvP.GetZonePVPInfo` "hostile") | needs probe V123 (new) | no character of level 20 or more → `p.loneWolf` |
| 10 | `p.homeGuard` | Defend home: a kill in friendly territory | Home guard | 3 | kill | a counted kill in a zone of the own faction ("friendly") | needs probe V123 (new) | no character of level 20 or more → `p.loneWolf` |
| 11 | `p.contested` | Kills in contested land | Contested | 3 | kill | 3 counted kills in contested zones ("contested") | needs probe V123 (new) | no character of level 20 or more → `p.loneWolf` |

### Skirmish · targets (15)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 12 | ★ `p.punchUp` | Punch up: 2 kills on players 3+ levels above | Punch up | 3 | kill | 2 counted kills with `diff >= 3` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 13 | ★ `p.variety` | Variety: kills of 3 different classes | Variety | 3 | kill | 3 different victim classes | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 14 | ★ `p.ranked` | Ranked bounty: kill a ranked player | Ranked | 5 | kill | 1 counted kill of a victim with PvP rank 1 or higher | existing tracker, waits for its launch check: V73, V74, V79 (victim and own rank) |  |
| 15 | ★ `p.punchUp5` | Kill an enemy player 5+ levels higher | Punch up 5 | 5 | kill | a counted kill with `diff >= 5` (a skull counts); approved in the daily catalogue (#124) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 16 | ★ `p.punchDown5` | Kill an enemy player 5+ levels lower | Punch down | 3 | kill | a counted kill with `diff <= -5`; approved in the daily catalogue (#125) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 17 | `p.skull` | Slay a skull | Skull | 5 | kill | a counted kill of a victim shown as a skull (`lvl = -1`) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 18 | `p.fairFight` | Fair fight: a kill at the same level | Fair fight | 3 | kill | a counted kill with `diff = 0` | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 19 | `p.mirror` | Mirror match: kill an enemy of the same class | Mirror | 3 | kill | a counted kill of a victim of the killer's own class | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 20 | `p.races3` | Kills of 3 different races | 3 races | 3 | kill | 3 different victim races | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 21 | `p.healers` | Silence the healers: 2 healer-class kills | Healers | 3 | kill | 2 counted kills of priests, druids, paladins or shamans | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 22 | `p.casters3` | Kill 3 casters | Casters | 3 | kill | 3 counted kills of mages, warlocks or priests | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 23 | `p.melee3` | Kill 3 fighters | Fighters | 3 | kill | 3 counted kills of warriors, rogues or paladins | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 24 | `p.nemesis` | Nemesis: kill the same player twice | Nemesis | 3 | kill | 2 counted kills of the same victim name | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 25 | `p.rankUp` | Kill a player of higher rank | Outrank | 5 | kill | a counted kill of a victim whose PvP rank is above the killer's | existing tracker, waits for its launch check: V73, V74, V79 (victim and own rank) |  |
| 26 | `p.huntPair` | Kills of 2 Hunt combinations | Hunt pair | 3 | kill | counted kills of 2 different race and class combinations of the enemy list (not only today's Hunt) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |

### Skirmish · streaks (6)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 27 | ★ `p.untouchable` | Untouchable: 5 kills without dying | Untouched | 5 | kill | 5 counted kills on one character with no death in between | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths (pool 1) |  |
| 28 | `p.streak3` | Three in a row without dying | Streak 3 | 3 | kill | 3 counted kills on one character with no death in between | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| 29 | `p.revenge` | Revenge: kill the player who killed you | Revenge | 5 | kill | a counted kill of the player who killed that character, within 30 minutes of the death | needs probe V120 (new) |  |
| 30 | `p.flagHour` | Stay flagged for 30 minutes without dying | Flagged 30 | 3 | flag | 30 minutes flagged for PvP on one character with no death | needs probe V121 (new) |  |
| 31 | `p.comeback` | Comeback: a kill within 5 minutes of a death | Comeback | 3 | kill | a counted kill within 5 minutes after the same character died to a player | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| 32 | `p.noDeath` | Score 3 kills and never die that day | Spotless | 5 | kill | 3 counted kills on a day with no death to a player on any character up to that moment | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |

### Skirmish · teamwork (5)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 33 | `p.duoKills` | Kills with a friend | Duo kills | 3 | kill | 3 counted kills while grouped with a friend's community character | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| 34 | `p.trioKills` | Kills with 2 friends | Trio kills | 5 | kill | a counted kill while grouped with community characters of 2 other friends | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| 35 | `p.escort` | Escort: a kill grouped with a lower friend | Escort | 3 | kill | a counted kill while grouped with a friend's community character 5 or more levels below the killer | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `p.loneWolf` |
| 36 | `p.avenge` | Avenge a friend | Avenge | 5 | kill | a counted kill of the player who killed a friend in the same group, within 10 minutes | needs probe V120 (new) | no other friend in the community → `p.loneWolf` |
| 37 | `p.pack` | Pack hunt: a kill in a full party | Pack hunt | 3 | kill | a counted kill while in a party of 5 (`GetNumGroupMembers`, not a raid) | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups |  |

### Skirmish · duels (7)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 38 | `p.duelWin` | Win a duel | Duel win | 1 | duel | a duel won (any opponent) | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 39 | `p.duelStranger` | Beat a stranger in a duel | Stranger | 3 | duel | a duel won against a player who is not a community character | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 40 | `p.duels3` | Fight 3 duels | 3 duels | 3 | duel | 3 duels finished, won or lost | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 41 | `p.duelUp` | Win a duel against a higher level | Duel up | 5 | duel | a duel won against a friend's community character of a higher level | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `p.loneWolf` |
| 42 | `p.duelClass` | Duel a friend of another class | Class duel | 1 | duel | a duel with a friend's community character of another class than the own | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `p.loneWolf` |
| 43 | `p.duelWins2` | Win 2 duels in a row | 2 in a row | 3 | duel | 2 duels won one after the other by one character, no loss between | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 44 | `p.rematch` | Rematch: beat the one who beat you | Rematch | 3 | duel | a duel won against an opponent who won the previous duel between the two that day | existing tracker, waits for its launch check: CF-52 duels (V80) |  |

### Skirmish · battlegrounds (7)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 45 | `p.bgPlay` | Play a battleground to the end | BG played | 3 | bg | a battleground run finished (won or lost, `PVP_MATCH_COMPLETE`) | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| 46 | `p.bgWin` | Win a battleground | BG win | 5 | bg | a battleground run won | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| 47 | `p.bgKills5` | 5 kills in a battleground | BG kills 5 | 3 | bg | 5 battleground kills in one run | existing tracker, waits for its launch check: V35b, V73 (battleground kills) | no character of level 10 or more → `p.loneWolf` |
| 48 | `p.bgFriend` | A battleground with a friend | BG buddy | 3 | bg | a battleground run finished with a friend's community character in it | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `p.loneWolf` |
| 49 | `p.bgFlag` | Capture a flag | Flag cap | 5 | bg | a flag capture by the character (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |
| 50 | `p.bgBase` | Assault or defend a base | Base | 3 | bg | a base or tower assaulted or defended by the character (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |
| 51 | `p.bgTop` | Top killer of the team in a battleground | BG top | 5 | bg | the most honorable kills of the own team in a finished battleground run (the battleground's score) | needs probe V122 (new) | no character of level 10 or more → `p.loneWolf` |

### Skirmish · taunts (6)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 52 | ★ `p.flex` | Flex at a player of the other faction | Flex | 1 | emote | the `/flex` emote with an enemy-faction player targeted; approved in the daily catalogue (#122) | needs probe V108, V74 |  |
| 53 | ★ `p.boo` | Boo a player of the other faction | Boo | 1 | emote | the `/boo` emote with an enemy-faction player targeted; approved in the daily catalogue (#123) | needs probe V108, V74 |  |
| 54 | `p.salute` | Salute a worthy enemy | Salute | 1 | emote | the `/salute` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| 55 | `p.chicken` | Call an enemy a chicken | Chicken | 1 | emote | the `/chicken` emote with an enemy-faction player targeted | needs probe V108, V74 |  |
| 56 | `p.bowKill` | Bow, then win | Bow first | 3 | kill | the `/bow` emote at an enemy-faction player, then a counted kill of that player within 2 minutes | needs probe V108, V74, V73 |  |
| 57 | `p.flagUp` | Flag up for PvP | Flag up | 1 | flag | a character flagged for PvP for 10 minutes | needs probe V121 (new) |  |

## Bounty (weekly)

### Bounty · world kills (9)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 58 | ★ `b.zone25` | 25 kills in the zone of the week | Zone 25 | 10 | kill | counted kills in the zone of the week (band of the highest character) | existing tracker, waits for its launch check: V73 (pool 1) | no character of level 20 or more → `b.kills50` |
| 59 | ★ `b.kills50` | 50 counted kills | 50 kills | 10 | kill | 50 counted world kills | existing tracker, waits for its launch check: V73 (pool 1) |  |
| 60 | ★ `b.days5` | Kills on 5 days | Kill days | 10 | kill | a counted kill on 5 of the 7 days | existing tracker, waits for its launch check: V73 (pool 1) |  |
| 61 | `b.kills150` | 150 counted kills | 150 kills | 15 | kill | 150 counted world kills | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| 62 | `b.zones8` | Kills in 8 zones | 8 zones | 10 | kill | counted kills in 8 different zones | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| 63 | `b.nights3` | Night raids on 3 nights | Nights x3 | 10 | kill | a counted kill between 23:00 and 05:00 realm time on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| 64 | `b.enemyLand25` | 25 kills in the enemy's territory | Invader | 10 | kill | counted kills in zones of the enemy faction, 25 in total | needs probe V123 (new) | no character of level 20 or more → `b.kills50` |
| 65 | `b.triples3` | 3 triples | 3 triples | 15 | kill | 3 times 3 counted kills by one character within 2 minutes | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |
| 66 | `b.firstBlood3` | First blood on 3 days | Blood x3 | 10 | kill | the day's first counted kill of all friends, on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills) | no character of level 20 or more → `b.kills50` |

### Bounty · targets (9)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 67 | ★ `b.allClasses` | A kill of every enemy class | Classes | 15 | kill | each class of the enemy list at least once | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 68 | ★ `b.allRaces` | A kill of every enemy race | Races | 10 | kill | each race at least once | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 69 | ★ `b.ranked5` | 5 kills on ranked players | 5 ranked | 15 | kill | victims with PvP rank 1 or higher | existing tracker, waits for its launch check: V73, V74, V79 (victim and own rank) |  |
| 70 | ★ `b.hunt3` | The Hunt done on 3 days | 3 hunts | 10 | kill | the Hunt done on 3 days | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 71 | `b.combos10` | 10 different Hunt combinations | 10 combos | 15 | kill | counted kills of 10 different race and class combinations of the enemy list | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 72 | `b.punchUp10` | 10 kills on players 3+ levels above | Up x10 | 10 | kill | 10 counted kills with `diff >= 3` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 73 | `b.skulls3` | Slay 3 skulls | 3 skulls | 15 | kill | 3 counted kills of skull victims | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 74 | `b.fair10` | 10 fair fights | Fair x10 | 10 | kill | 10 counted kills with `-2 <= diff <= 2` | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |
| 75 | `b.nemesis` | Nemesis: the same player 3 times | Nemesis x3 | 5 | kill | counted kills of the same victim name on 3 different days | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) |  |

### Bounty · streaks (6)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 76 | ★ `b.spree10` | A spree of 10 | Spree 10 | 15 | kill | 10 kills on one character without dying | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths (pool 1) |  |
| 77 | `b.solo20` | 20 solo kills | Solo 20 | 10 | kill | 20 counted kills with `solo` | existing tracker, waits for its launch check: V73, V76 (CF-55b kills, `solo`) |  |
| 78 | `b.untouchable3` | Untouchable on 3 days | Untouch x3 | 10 | kill | 5 counted kills without dying on one character, on 3 days | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |
| 79 | `b.revenge3` | Revenge 3 times | Revenge x3 | 10 | kill | 3 counted kills of the player who killed that character, each within 30 minutes | needs probe V120 (new) |  |
| 80 | `b.flagged3h` | 3 hours flagged for PvP | Flagged 3h | 5 | flag | 3 hours flagged for PvP in total | needs probe V121 (new) |  |
| 81 | `b.kd` | More kills than deaths | K over D | 10 | kill | at least 10 counted kills and fewer deaths to players than kills, over the week | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-52 deaths |  |

### Bounty · teamwork (4)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 82 | `b.duoKills15` | 15 kills with friends | Duo 15 | 10 | kill | 15 counted kills while grouped with a friend's community character | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `b.kills50` |
| 83 | `b.warband` | A warband of 3 friends | Warband | 10 | kill | 5 counted kills while grouped with community characters of 2 other friends | existing tracker, waits for its launch check: V73 (CF-55b kills), CF-53 groups | no other friend in the community → `b.kills50` |
| 84 | `b.avenge3` | Avenge friends 3 times | Avenge x3 | 15 | kill | counted kills of players who killed a friend in the same group within 10 minutes, 3 in total | needs probe V120 (new) | no other friend in the community → `b.kills50` |
| 85 | `b.huntAll` | Every friend does the Hunt | All hunt | 10 | kill | the Hunt done by every friend who played PvP that week (counted for each of them when the last one finishes) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with the victim) | no other friend in the community → `b.kills50` |

### Bounty · duels (5)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 86 | ★ `b.duels3` | Duels with 3 different friends | 3 duels | 5 | duel | duels with community characters of 3 other friends | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 87 | `b.duelWins5` | Win 5 duels | Duel wins | 10 | duel | 5 duels won (any opponent) | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 88 | `b.duelAll` | Duel every friend | Duel all | 15 | duel | a duel with a community character of every other friend who played that week (at least 2) | existing tracker, waits for its launch check: CF-52 duels (V80) | no other friend in the community → `b.kills50` |
| 89 | `b.duelDays4` | Duel on 4 days | Duel days | 5 | duel | a duel on 4 days of the week | existing tracker, waits for its launch check: CF-52 duels (V80) |  |
| 90 | `b.strangers3` | Beat 3 strangers in duels | Strangers | 10 | duel | duels won against 3 different players who are not community characters | existing tracker, waits for its launch check: CF-52 duels (V80) |  |

### Bounty · battlegrounds (7)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 91 | `b.bgWins3` | Win 3 battlegrounds | 3 BG wins | 10 | bg | 3 battleground runs won | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| 92 | `b.bgEach` | Play every battleground | Every BG | 15 | bg | a finished run in every battleground open to the character | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| 93 | `b.bgDays3` | Battlegrounds on 3 days | BG days | 10 | bg | a finished battleground run on 3 days | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |
| 94 | `b.bgKills30` | 30 battleground kills | BG kill 30 | 10 | bg | 30 battleground kills | existing tracker, waits for its launch check: V35b, V73 (battleground kills) | no character of level 10 or more → `b.kills50` |
| 95 | `b.bgFlags3` | Capture 3 flags | 3 flags | 15 | bg | 3 flag captures | needs probe V122 (new) | no character of level 10 or more → `b.kills50` |
| 96 | `b.bgBases5` | Take or hold 5 bases | 5 bases | 10 | bg | 5 bases or towers assaulted or defended | needs probe V122 (new) | no character of level 10 or more → `b.kills50` |
| 97 | `b.bgFriends` | Win a battleground with 2 friends | BG trio | 15 | bg | a battleground run won with community characters of 2 other friends in it | existing tracker, waits for its launch check: V35b (CF-23 battleground runs) | no character of level 10 or more → `b.kills50` |

### Bounty · honor (2)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 98 | `b.rankUp` | Rise a PvP rank | Rank up | 15 | kill | a character's PvP rank higher than at the start of the week | existing tracker, waits for its launch check: V79 (own rank) |  |
| 99 | `b.skirmish5` | The Skirmish done on 5 days | Skirmish 5 | 10 | kill | the day's Skirmish done on 5 days of the week | works now: the Skirmish `done` per day |  |

### Bounty · taunts (1)

| # | Id | Title | Label | Points | Needs | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|---|
| 100 | `b.taunts5` | Taunt 5 enemies | Taunts | 5 | emote | `/flex`, `/boo`, `/chicken` or `/rude` at 5 different enemy-faction players | needs probe V108, V74 |  |
