# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).
2. E18, the mission catalogue: CF-69 and CF-70, then CF-71 to CF-73, then CF-77 (pool version 2, with the site). CF-74 to CF-76 as their launch checks pass.

## E15 Doomsday (decided with Nico, 2026-10-28)
Daily and weekly goals, points per track, a streak and a crown, feats and a ladder, in the game, on the site (web E8) and in Discord (bot "Doomsday"). **`docs/DOOMSDAY.md` is the one description of the rules**; read it first. It replaces the three workshop designs (milestones, PvP ladder, dailies and weeklies; their PRs were closed unmerged).

Boards in `docs/design/doomsday-2026-10/`:
- `DD07AddonToday.dc.html`: Today, Week, chat lines, toast
- `DD08AddonBoard.dc.html`: Board, Ladder, Feats
- `AddonKit-doomsday.dc.html`: what WoW supports for Doomsday

The site's and the bot's boards are in their repos. Where a board and `DOOMSDAY.md` disagree, `DOOMSDAY.md` wins: the reset is 19:00 (a setting), goals are computed (not delivered through `Runs.lua`), and the crown gives no points.

None of the new APIs are verified on Forever. Each is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step (V73 to V86), and is checked at launch (from 2026-11-05). A guarded API that is missing leaves its field out (nil). A goal that needs it stays out of the pool, and the site shows no card or feat for it.

Compatibility (rule 8): only new optional fields in `chars.*`, feed entries and RECORD, within `pv` 1. Older clients ignore them, relay what they keep, and a relayed record without them changes nothing (nil = unknown). New stored fields are optional (nil-safe), so no migration unless a field changes meaning. Friends on an older addon show "no Doomsday data yet", never 0 points as if known.

Status (2026-10-29): CF-52, CF-53, CF-55 (a and b), CF-56, CF-57 (a and b) and CF-58 are done (`docs/STORIES-COMPLETED.md`). Open: CF-54, the probe run at launch, which decides the victim fields, the Hunt and the next pool version (`DOOMSDAY.md` "The algorithm, exactly"). The unverified APIs are V73 to V86 in `VERIFY.md`.

### CF-54 FriendProbe: what Forever tells about a kill, and realm time
Probe written (PR #98): `/fp pvp` and the V77/V78 and V79–V83 lines in `/fp start`. The story stays open until the launch run is in `API-FINDINGS.md` (`VERIFY.md` "CF-54").
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

## E18 The Doomsday mission catalogue (approved by Nico, 2026-11-03)
`docs/DOOMSDAY-CATALOGUE.md` is the approved list: 118 PvE dailies in 15 categories and 4 Skirmish goals, numbered
1 to 125 (#16, #27 and #94 removed), each with its id, label, points (1, 3 or 5), "done when", data source and
fallback. These stories build it in the addon. Read the catalogue first; where a story and the catalogue disagree on a
mission, the catalogue wins. The site's side is in `docs/WEB-STORIES-DOOMSDAY-CATALOGUE.md` (for the web repo).

Build order: CF-69 and CF-70 first (rules and catalogue in code), then CF-71 to CF-73 (no probe needed), CF-77 pool
version 2 with the site in the same release. CF-74 to CF-76 follow mission by mission as their launch checks pass, each
group with its own pool version bump.

Compatibility (rule 8), for all of E18:
- Stored data: only new optional local facts (`self.doomsday`, as CF-56) and two new per-character sets (zones and
  dungeons seen, CF-72 and CF-73), nil = unknown. No migration: nothing changes meaning.
- Messages: nothing new is sent. Goals travel as today (`goals.days[n].done` ids, `goals.pool`). An older client keeps
  ids it doesn't know (`Goals.clean`), and shows them by id until it updates.
- The draw depends on `POOL_VERSION`: a friend on an older addon draws the older pool. That is the existing rule
  (`goals.pool` is recorded); the release notes ask friends to update on release day.

### CF-69 Points per mission (rule change)
Nico, 2026-11-03: every goal scores 1, 3 or 5 points by size, so no daily is worth more than today; a day's total
varies with the draw; the Skirmish and the weeklies get sizes too.
- `docs/DOOMSDAY.md` "Points": the flat "5 per daily, 15 per weekly" becomes "each goal's points, from the pool"; the
  table lists the sizes (1 quick, 3 standard, 5 demanding) and says that a day keeps the points of the pool version it
  was drawn in.
- `Doomsday.GOALS` entries get `points`. Goals of pool version 1 keep 5 (dailies, Skirmish) and 15 (weeklies, Bounty)
  for days and weeks of pool version 1; from pool version 2 each goal's catalogue points count. `Doomsday.pointsFor(id,
  pool)` returns them (nil-safe: an unknown id scores the old flat value).
- Points of a day or week are computed from its `done` ids and the pool version recorded with it (`goals.pool`), on
  both sides. The crown, crossing out and the streak don't change: they count goals, not points.
- Open before building, for Nico: the sizes of the pool-1 Skirmish goals (`p.frontLine`, `p.loneWolf`,
  `p.untouchable`: proposal 3 each) and of the Bounty and the weeklies (proposal: 5, 10 or 15). The catalogue has
  the sizes of every PvE daily and the 4 new Skirmish goals.
- Golden cases: a new `pointsPerGoal` key in `tests/fixtures/doomsday-cases.json` (a day of pool 1, a day of pool 2
  with 1, 3 and 5 point goals, an unknown id), copied unchanged by the site (WEB story).
- The addon's Week, Board and Ladder show the new totals; the day-complete banner shows the day's points.
- Manual (VERIFY.md): a day with a 1-point goal shows "+1" on its banner and in the week's total.

### CF-70 The catalogue in code
- `Doomsday.GOALS` gets every catalogue mission in catalogue order within its slot, with `id`, `slot`, `category`
  (the 15 categories), `text` (the catalogue's title), `points`, `can` and `fallback`. New goals have no `since`
  (they wait for data), so pool version 1's draw doesn't change.
- Moved categories: `d.groupFriend` and `d.trade` to social, `d.rare` to loot, `d.fish20` to fishing (none of them
  in pool version 1).
- `Doomsday.SHORT_LABELS` gets every label (at most 10 characters; a spec checks length and uniqueness per slot).
- The situation (`Goals.situation`) gets the new optional fields: `below20`, `hasCooking`, `hasFirstAid`,
  `hasGathering`, `riding`, `friends`, `canBuff`. A missing field never swaps.
- `docs/DOOMSDAY.md`: the dailies table and the Skirmish table list the new goals with "Data" (the story that tracks
  them), the short labels table gets the new labels.
- Golden cases: `pools` lists the catalogue; the draws of pool version 1 are unchanged (the existing cases pass as
  they are).

### CF-71 Quest details (verified APIs)
Missions: `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.dungeonQuest`, `d.questBurst`, `d.accept5`,
`d.questTogether` (catalogue #6 to #10, #23, #49).
- The stored quest log (`Quests`) keeps `level` and `suggestedGroup` from `C_QuestLog.GetInfo` next to `area` and
  `dungeon` (V23, V31); optional fields, nil on records of older versions.
- At `QUEST_TURNED_IN` (questID, as CF-22) the tracker looks the quest up in the stored log of that character and
  observes `{ kind = "questDone", level, charLevel, group, area, dungeon, grouped }` with the time.
- `QUEST_ACCEPTED`: distinct quest IDs accepted per Doomsday day.
- `grouped`: a friend's community character in the group at that moment (CF-53's groups).
- Progress functions and golden `progress` cases per mission, by its "done when".
- Manual: one step per mission in VERIFY.md (hand in a group quest, a class quest, 3 quests in 10 minutes, ...).

### CF-72 Levels, play and dungeons on recorded data (verified APIs)
Missions: `d.levels2`, `d.lowbie`, `d.dingDungeon`, `d.dingFriend`, `d.dungeons2`, `d.speedRun`, `d.newDungeon`,
`d.chars3`, `d.switchUp`, `d.dustOff`, `d.cookSkill5`, `d.fishSkill5`, `d.aidSkill5`.
- Level-ups observe the instance type (`GetInstanceInfo`, V35) and whether a friend's community character is grouped.
- Party runs: duration from `startedAt` and `lastAt`; a new stored per-character set of dungeon names
  (`chars[guid].dungeonsSeen`, local, seeded from the stored feed's runs) for `d.newDungeon`.
- Skill points per skill line (185 Cooking, 356 Fishing, 129 First Aid) from the professions the addon stores, as
  `d.skill5` counts all.
- `d.switchUp` and `d.dustOff` from the days' facts and `lastPlayed`.
- Golden `progress` cases per mission; manual steps in VERIFY.md.

### CF-73 Friends and places (verified APIs)
Missions: `d.sameZone`, `d.online3`, `d.carry`, `d.chatHello`, `d.roam4`, `d.newZone`, `d.crossSea`, `d.nostalgia`,
`d.daredevil`.
- Friends: `C_Club.GetMemberInfo` zone and presence (V17, V18) for "same zone" and "online at once"; party members'
  levels for `d.carry`; own messages in the selected community's channel by sender GUID (V38).
- Places: `ZONE_CHANGED_NEW_AREA` with `GetRealZoneText` and the continent from `GetInstanceInfo` (V35); a new stored
  per-character zone set (`chars[guid].zonesSeen`, local, seeded from the feed's quest zones); zone level ranges from
  Group Finder's "Quests & Zones" activities (V46), matched to the zone name. A zone without a match never counts.
- Golden `progress` cases; manual steps in VERIFY.md.

### CF-74 Existing trackers, extended (after their launch checks)
Missions: `d.fish50`, `d.fishZones`, `d.fishFriend`, `d.fishNight`, `d.nightOwl`, `d.session1h`, `d.deathless`,
`d.cleanRun`, `d.profit`, `d.green5`, `d.reward`, `d.craft5`, `d.feedFriend`, `d.discover1`, `d.discover3`,
`p.punchUp5`, `p.punchDown5`, and the existing `d.cleanLevel`, `d.groupFriend`, `d.trade`, `d.rare`, `d.earlyBird`.
- Each extends a CF-52, CF-53, CF-55b or CF-56 tracker (zone, group, realm clock, counts per item ID) and joins the pool
  only once its check passed at launch: V84 (fishing), V85 (trades), V83 (loot), V86 (discoveries), V73 and V74
  (kills), and the CF-52 and CF-53 story steps (deaths, sessions, gold, groups).
- Golden `progress` cases; manual steps in VERIFY.md.

### CF-75 Probe-gated: items, crafting, cooking, First Aid, care
Missions: the cooking, firstaid and care missions and `d.gather10`, `d.newRecipe`, `d.craftGreen`, `d.coins10`,
`d.equipNew`, `d.treasure`, `d.jump100` (catalogue "needs probe" rows with V95, V104 to V106, V110, V112, V113, V116 to
V119).
- Built per mission once its V passed (`docs/API-FINDINGS.md`); a mission whose V failed is marked retired in the
  catalogue and stays out.
- The campfire missions (`d.campfire`, `d.campfireBuff`) take their spell ID, buff and item count from V119; their
  "done when" is rewritten from the finding before they are built.
- Every API guarded (rule 3); golden `progress` cases; manual steps in VERIFY.md.

### CF-76 Probe-gated: combat, travel, economy, social
Missions: the combat, travel and economy missions and `d.whisper`, `d.wave`, `d.groupPic`, `d.places10`, `d.swim`,
`p.flex`, `p.boo` (catalogue "needs probe" rows with V90, V93, V94, V96, V98 to V103, V107 to V109, V111, V114, V115).
- As CF-75: built per mission once its V passed; failed ones retired.
- Kills from the XP message (V90) match the creature last seen by target, mouseover or nameplate (V93), as the Hunt
  does for players.

### CF-77 Pool version 2
- `Doomsday.POOL_VERSION = 2`; `since = 2` on the missions CF-71 to CF-73 built and on those of CF-74 whose checks
  passed by then; the points of CF-69 count from this version.
- The 15 categories in the draw; golden `draws` cases for days and weeks of pool version 2 from its first day (the
  release day), and the existing pool-1 cases unchanged.
- The site ships its copy of pool version 2 in the same release (WEB story); the release notes ask friends to update.
- Later bumps (3, 4, ...) add the missions of CF-74 to CF-76 as their checks pass, one bump per release, with golden
  cases each.
- Manual (VERIFY.md): on the release day, two friends on the new version see the same 3 dailies; a friend on the old
  version sees pool version 1's.
