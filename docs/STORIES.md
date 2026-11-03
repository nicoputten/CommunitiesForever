# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).
2. E18, the mission catalogue: CF-70 first, then in parallel lanes (see E18 "Building in parallel"), CF-77 last.

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
`docs/DOOMSDAY-CATALOGUE.md` is the approved list of dailies: 118 PvE dailies in 15 categories and 4 Skirmish goals,
numbered 1 to 125 (#16, #27 and #94 removed), each with its id, label, points (1, 3 or 5), "done when", data source
and fallback. The weekly catalogue (`docs/DOOMSDAY-WEEKLY-CATALOGUE.md`, #177: 50 weeklies) and the
PvP catalogue (`docs/DOOMSDAY-PVP-CATALOGUE.md`, #178: 57 Skirmish and 43 Bounty goals) were approved by Nico on
2026-11-03; CF-79 puts them in code, and the tracker lanes cover their missions too. Read the catalogue first;
where a story and a catalogue disagree on a mission, the catalogue wins. The site's side is in
`docs/WEB-STORIES-DOOMSDAY-CATALOGUE.md` (for the web repo).

Compatibility (rule 8), for all of E18:
- Stored data: only new optional local facts (`self.doomsday`, as CF-56) and two new per-character sets (zones and
  dungeons seen, CF-72 and CF-73), nil = unknown. No migration: nothing changes meaning.
- Messages: nothing new is sent. Goals travel as today (`goals.days[n].done` ids, `goals.pool`). An older client keeps
  ids it doesn't know (`Goals.clean`), and shows them by id until it updates.
- The draw depends on `POOL_VERSION`: a friend on an older addon draws the older pool. That is the existing rule
  (`goals.pool` is recorded); the release notes ask friends to update on release day.

### Building in parallel
Nico wants several workers on E18 at once. The stories are cut so that, after CF-70, workers on different lanes never
edit the same file. Each story lists the files it touches and what it waits for.

| Lane | Stories, in order | Files only this lane edits |
|---|---|---|
| Start (one worker) | CF-70 | sets up everything the other lanes share (below) |
| Rules | CF-69, then CF-78, then CF-79 (after the reviews) | `src/core/Doomsday.lua`, `src/core/DoomsdayView.lua`, `src/core/Pvp.lua`, `src/ui/DoomsdayTab.lua`, `src/ui/CelebrationBanner.lua`, `docs/DOOMSDAY.md`, `tests/fixtures/doomsday-cases.json` and their specs |
| Quests | CF-71 | `src/core/missions/Quests.lua`, `src/adapters/missions/QuestEvents.lua`, `src/core/Quests.lua`, `src/adapters/SelfInfo.lua` (the quest log fields), `tests/spec/MissionsQuests_spec.lua`, `tests/fixtures/missions/quests.json` |
| Records | CF-72 | `src/core/missions/Records.lua`, `src/adapters/missions/RecordEvents.lua`, `tests/spec/MissionsRecords_spec.lua`, `tests/fixtures/missions/records.json` |
| Friends and places | CF-73 | `src/core/missions/Places.lua`, `src/adapters/missions/PlaceEvents.lua`, `tests/spec/MissionsPlaces_spec.lua`, `tests/fixtures/missions/places.json` |
| Launch checks | CF-74, CF-75, CF-76 (after the launch run, each in its own module files, `missions/Extended`, `missions/Items`, `missions/World`) | as the lanes above, with their own module, adapter, spec and fixture |
| PvP fights | CF-80 (after the launch run) | `src/core/missions/Fights.lua`, `src/adapters/missions/FightEvents.lua`, `tests/spec/MissionsFights_spec.lua`, `tests/fixtures/missions/fights.json` |
| PvP extras | CF-81 (after the launch run) | `src/core/missions/Battle.lua`, `src/adapters/missions/BattleEvents.lua`, `tests/spec/MissionsBattle_spec.lua`, `tests/fixtures/missions/battle.json` |
| End (one worker) | CF-77 | `src/core/Doomsday.lua` (`POOL_VERSION`, `since`, the draw), `tests/fixtures/doomsday-cases.json`, `docs/DOOMSDAY.md` |

Shared by everyone, append only: `VERIFY.md` (each story adds its own section under "Manual test steps per story")
and `CHANGELOG.md` (each story adds its line under "Unreleased"). A merge conflict there is resolved by keeping both.
`CommunitiesForever.toc` is edited only by CF-70 (it lists every module file up front), so the lanes don't touch it.

**Weeklies:** each tracker lane also registers the progress of the weeklies that read its data (the weekly
catalogue's "Data" column: `w.groupQuests3` in CF-71, `w.levels5` in CF-72, `w.roam10` in CF-73, and so on). A
progress function registered before CF-79 lists the weekly is harmless, so the lanes don't wait for CF-79.

Dependencies: CF-70 before everything. CF-69 → CF-78 → CF-79 in the rules lane. CF-71, CF-72, CF-73 need only CF-70
and run side by side, and alongside the rules lane. CF-74 to CF-76 need CF-70 and their launch checks
(`docs/API-FINDINGS.md`); CF-80 and CF-81 the same. CF-77 needs CF-69 and the tracker stories it puts in the pool,
and the site's WEB-80.

### CF-70 The catalogue in code, and the mission modules (first, one worker)
Touches: `src/core/Doomsday.lua`, `src/core/Goals.lua`, `src/services/DoomsdayTracker.lua`, `CommunitiesForever.toc`,
`docs/DOOMSDAY.md` (the goal tables and short labels), `tests/fixtures/doomsday-cases.json` (`pools`), the stub files
below, and their specs. Waits for: nothing.
- `Doomsday.GOALS` gets every daily catalogue mission in catalogue order within its slot, with `id`, `slot`,
  `category` (the 15 categories), `text` (the catalogue's title), `points` (the catalogue's; used by CF-69), `can` and
  `fallback`. New goals have no `since` (they wait for data), so pool version 1's draw doesn't change.
- Moved categories: `d.groupFriend` and `d.trade` to social, `d.rare` to loot, `d.fish20` to fishing (none of them
  in pool version 1).
- `Doomsday.SHORT_LABELS` gets every label (at most 10 characters; a spec checks length and uniqueness per slot).
- The situation (`Goals.situation`) gets the new optional fields: `below20`, `hasCooking`, `hasFirstAid`,
  `hasGathering`, `riding`, `friends`, `canBuff`. A missing field never swaps.
- **Mission modules**, so the tracker lanes never edit a shared file:
  - `Goals.registerKind(kind, fn)`: a module adds its own observation kinds to `Goals.observe` (facts stay in the
    day's and week's facts table under the module's own key, e.g. `facts.quests2`).
  - `Doomsday.registerProgress(id, fn)`: a module adds the progress function of its missions; `Doomsday.progress`
    looks there after its own table.
  - `DoomsdayTracker` forwards every module's internal message (`CF_MISSION_EVENT`, reason = the kind) to
    `Goals.observe`, with today's and this week's facts.
  - Stub files, listed in the TOC now, each a module that registers nothing yet: `src/core/missions/Quests.lua`,
    `Records.lua`, `Places.lua`, `Extended.lua`, `Items.lua`, `World.lua`, `Fights.lua`, `Battle.lua`, and
    `src/adapters/missions/QuestEvents.lua`, `RecordEvents.lua`, `PlaceEvents.lua`, `ExtendedEvents.lua`,
    `ItemEvents.lua`, `WorldEvents.lua`, `FightEvents.lua`, `BattleEvents.lua`; empty fixture
    files `tests/fixtures/missions/*.json` (addon-only progress cases: the site never computes progress).
- `docs/DOOMSDAY.md`: the dailies and Skirmish tables list the new goals with "Data" (the story that tracks them).
- Golden cases: `pools` lists the catalogue; the draws of pool version 1 are unchanged.

### CF-69 Points per mission (rule change; rules lane)
Touches: `src/core/Doomsday.lua` (points, ladder), `src/core/DoomsdayView.lua`, `src/ui/DoomsdayTab.lua`,
`src/ui/CelebrationBanner.lua`, `docs/DOOMSDAY.md` "Points", `tests/fixtures/doomsday-cases.json` (`pointsPerGoal`),
their specs. Waits for: CF-70.
- Nico, 2026-11-03: every goal scores by size: dailies and Skirmish 1, 3 or 5; weeklies and Bounty 5, 10 or 15. A
  day's total varies with the draw.
- `docs/DOOMSDAY.md` "Points": the flat "5 per daily, 15 per weekly" becomes "each goal's points, from the pool"; a
  day keeps the points of the pool version it was drawn in.
- `Doomsday.pointsFor(id, pool)`: pool version 1 keeps 5 (dailies, Skirmish) and 15 (weeklies, Bounty); from pool
  version 2 the goal's `points`. Nil-safe: an unknown id scores the old flat value.
- Points of a day or week come from its `done` ids and the pool version recorded with it (`goals.pool`), on both
  sides. The crown, crossing out and the streak don't change: they count goals, not points.
- The sizes of the pool-1 Skirmish and Bounty goals and of the weeklies come from the weekly and PvP catalogues once
  Nico approved them (#177, #178); until then they keep 5 and 15.
- Golden cases: `pointsPerGoal` (a day of pool 1, a day of pool 2 with 1, 3 and 5 point goals, an unknown id), copied
  unchanged by the site (WEB-80).
- The Week, Board and Ladder show the new totals; the day-complete banner shows the day's points.
- Manual (VERIFY.md): a day with a 1-point goal shows "+1" on its banner and in the week's total.

### CF-78 Only a real fight ends PvP Virgin (rule change; rules lane)
Touches: `src/core/Pvp.lua` (`Pvp.virgin`), `src/core/DoomsdayView.lua` and `src/core/Doomsday.lua` (the ladder's
`killedEver`), `docs/DOOMSDAY.md` "Two tracks", `tests/fixtures/doomsday-cases.json` (`ladder`), their specs. Waits
for: CF-69 (same files).
- Nico, 2026-11-03 (#178): **a PvP Virgin stays one until a real fight: an honorable kill, a duel, or a finished
  battleground.** PvP points from goals that need no fight (emotes, the PvP flag) count on the PvP track but don't end
  PvP Virgin status.
- `DOOMSDAY.md`: "any PvP point or any kill ends it" becomes "an honorable kill, a duel or a finished battleground on
  any character ends it; PvP points from goals without a fight don't".
- `Pvp.virgin` and the ladder's `killedEver` (renamed `foughtEver`, the old name read as a fallback) also count a
  finished battleground run (`runs`, `kind = "pvp"`, CF-23).
- Golden `ladder` cases: a friend with only taunt points stays unranked; a friend with one battleground is ranked.
- Manual: a friend who only flexed shows as Conscientious Objector with the points; after a duel, ranked.

### CF-71 Quest details (verified APIs; quests lane)
Touches: `src/core/missions/Quests.lua`, `src/adapters/missions/QuestEvents.lua`, `src/core/Quests.lua` and
`src/adapters/SelfInfo.lua` (the quest log's new fields), `tests/spec/MissionsQuests_spec.lua`,
`tests/fixtures/missions/quests.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70.
Missions: `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.dungeonQuest`, `d.questBurst`, `d.accept5`,
`d.questTogether` (catalogue #6 to #10, #23, #49).
- The stored quest log keeps `level` and `suggestedGroup` from `C_QuestLog.GetInfo` next to `area` and `dungeon` (V23,
  V31); optional fields, nil on records of older versions.
- At `QUEST_TURNED_IN` (questID, as CF-22) the module looks the quest up in the stored log of that character and
  observes `{ kind = "questDone", level, charLevel, group, area, dungeon, grouped }` with the time.
- `QUEST_ACCEPTED`: distinct quest IDs accepted per Doomsday day.
- `grouped`: a friend's community character in the group at that moment (CF-53's groups).
- Progress functions registered per mission; progress cases in its fixture file; manual steps in VERIFY.md.

### CF-72 Levels, play and dungeons on recorded data (verified APIs; records lane)
Touches: `src/core/missions/Records.lua`, `src/adapters/missions/RecordEvents.lua`,
`tests/spec/MissionsRecords_spec.lua`, `tests/fixtures/missions/records.json`, VERIFY.md, CHANGELOG.md. Waits for:
CF-70.
Missions: `d.levels2`, `d.lowbie`, `d.dingDungeon`, `d.dingFriend`, `d.dungeons2`, `d.speedRun`, `d.newDungeon`,
`d.chars3`, `d.switchUp`, `d.dustOff`, `d.cookSkill5`, `d.fishSkill5`, `d.aidSkill5`.
- Level-ups observe the instance type (`GetInstanceInfo`, V35) and whether a friend's community character is grouped.
- Party runs: duration from `startedAt` and `lastAt`; a per-character set of dungeon names (local, in
  `self.doomsday.dungeonsSeen[guid]`, seeded from the stored feed's runs) for `d.newDungeon`.
- Skill points per skill line (185 Cooking, 356 Fishing, 129 First Aid) from the professions the addon stores.
- `d.switchUp` and `d.dustOff` from the days' facts and `lastPlayed`.
- Progress cases in its fixture file; manual steps in VERIFY.md.

### CF-73 Friends and places (verified APIs; friends and places lane)
Touches: `src/core/missions/Places.lua`, `src/adapters/missions/PlaceEvents.lua`, `tests/spec/MissionsPlaces_spec.lua`,
`tests/fixtures/missions/places.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70.
Missions: `d.sameZone`, `d.online3`, `d.carry`, `d.chatHello`, `d.roam4`, `d.newZone`, `d.crossSea`, `d.nostalgia`,
`d.daredevil`.
- Friends: `C_Club.GetMemberInfo` zone and presence (V17, V18) for "same zone" and "online at once"; party members'
  levels for `d.carry`; own messages in the selected community's channel by sender GUID (V38).
- Places: `ZONE_CHANGED_NEW_AREA` with `GetRealZoneText` and the continent from `GetInstanceInfo` (V35); a
  per-character zone set (local, `self.doomsday.zonesSeen[guid]`, seeded from the feed's quest zones); zone level
  ranges from Group Finder's "Quests & Zones" activities (V46), matched to the zone name. A zone without a match never
  counts.
- Progress cases in its fixture file; manual steps in VERIFY.md.

### CF-74 Existing trackers, extended (after their launch checks)
Touches: `src/core/missions/Extended.lua`, `src/adapters/missions/ExtendedEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. It reads the CF-52, CF-53, CF-55b and CF-56 facts and doesn't edit their trackers. Waits for: CF-70 and
the launch checks below.
Missions: `d.fish50`, `d.fishZones`, `d.fishFriend`, `d.fishNight`, `d.nightOwl`, `d.session1h`, `d.deathless`,
`d.cleanRun`, `d.profit`, `d.green5`, `d.reward`, `d.craft5`, `d.feedFriend`, `d.discover1`, `d.discover3`,
`p.punchUp5`, `p.punchDown5`, and the existing `d.cleanLevel`, `d.groupFriend`, `d.trade`, `d.rare`, `d.earlyBird`.
- Each mission joins the pool only once its check passed at launch: V84 (fishing), V85 (trades), V83 (loot), V86
  (discoveries), V73 and V74 (kills), and the CF-52 and CF-53 story steps (deaths, sessions, gold, groups).

### CF-75 Probe-gated: items, crafting, cooking, First Aid, care
Touches: `src/core/missions/Items.lua`, `src/adapters/missions/ItemEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. Waits for: CF-70 and the V checks named below.
Missions: the cooking, firstaid and care missions and `d.gather10`, `d.newRecipe`, `d.craftGreen`, `d.coins10`,
`d.equipNew` (and the weekly `w.blueGear`), `d.treasure`, `d.jump100` (catalogue "needs probe" rows with V95, V104
to V106, V110, V112, V113, V116 to V119).
- Built per mission once its V passed (`docs/API-FINDINGS.md`); a mission whose V failed is marked retired in the
  catalogue and stays out.
- The campfire missions take their spell ID, buff and item count from V119; their "done when" is rewritten from the
  finding before they are built.

### CF-76 Probe-gated: combat, travel, economy, social
Touches: `src/core/missions/World.lua`, `src/adapters/missions/WorldEvents.lua`, its spec and fixture, VERIFY.md,
CHANGELOG.md. Waits for: CF-70 and the V checks named below.
Missions: the combat, travel and economy missions and `d.whisper`, `d.wave`, `d.groupPic`, `d.places10`, `d.swim`,
`p.flex`, `p.boo` (catalogue "needs probe" rows with V90, V93, V94, V96, V98 to V103, V107 to V109, V111, V114, V115).
- As CF-75: built per mission once its V passed; failed ones retired.
- Kills from the XP message (V90) match the creature last seen by target, mouseover or nameplate (V93), as the Hunt
  does for players.

### CF-79 The weekly and PvP catalogues in code (rules lane)
Touches: `src/core/Doomsday.lua` (the weekly, Skirmish and Bounty entries and labels), `docs/DOOMSDAY.md`,
`tests/fixtures/doomsday-cases.json` (`pools`). Waits for: CF-78 (same files). Both catalogues are approved (#177,
#178).
- As CF-70 for the weeklies and the PvP goals: every approved mission with category, points, `can` and fallback, no
  `since`. The existing pool-1 Skirmish and Bounty goals get the PvP catalogue's sizes (from pool version 2).
- `needs` per PvP goal (kill, duel, bg, emote, flag), so CF-78's rule can tell fight goals from the rest.
- Weekly #8 is the new `w.blueGear` (a blue or better item new to the character; its tracker is CF-75's V113 gear
  tracker). `w.ilvl3` keeps its id and meaning and is marked retired from pool version 2 (`retired = 2`): it stays in
  pool version 1's draw, golden cases unchanged.
- Their trackers are the lanes' (weeklies) and CF-80 and CF-81 (PvP).

### CF-80 PvP fights: kills, deaths, duels, battlegrounds (PvP fights lane)
Touches: `src/core/missions/Fights.lua`, `src/adapters/missions/FightEvents.lua`, `tests/spec/MissionsFights_spec.lua`,
`tests/fixtures/missions/fights.json`, VERIFY.md, CHANGELOG.md. It reads the CF-55b kills (`pvpKills`), the CF-52
deaths and duels, the CF-23 battleground runs, CF-53's groups and the own rank, and doesn't edit their trackers. Waits
for: CF-70 and the launch checks V73, V74, V76, V79, V35b.
Missions: the PvP catalogue's goals with "existing tracker" data (world kills, targets, streaks, teamwork, duels and
the battleground runs; `b.skirmish5` from the Skirmish `done`).
- Kills are counted as `DOOMSDAY.md` "Kill points" counts them; battleground kills only for the battleground goals.
- First blood compares the own kill's time with the friends' kills known at that moment; a later sync doesn't undo it.
- Each goal joins the pool only once its check passed.

### CF-81 PvP extras: taunts, the flag, battleground scores, zones, the killer (PvP extras lane)
Touches: `src/core/missions/Battle.lua`, `src/adapters/missions/BattleEvents.lua`, `tests/spec/MissionsBattle_spec.lua`,
`tests/fixtures/missions/battle.json`, VERIFY.md, CHANGELOG.md. Waits for: CF-70 and the launch checks V108, V120,
V121, V122, V123 (FriendProbe, merged in #179).
Missions: the PvP catalogue's "needs probe" goals (taunts, the flag, battleground objectives and the top killer,
enemy and home territory, revenge and avenge).
- The killer's name (V120) is kept with the own death as a new optional local fact (nil = unknown), never sent.
- Built per goal once its V passed; a goal whose V failed is retired in the catalogue.

### CF-77 Pool version 2 (end, one worker)
Touches: `src/core/Doomsday.lua` (`POOL_VERSION`, `since`, the draw), `tests/fixtures/doomsday-cases.json` (`draws`),
`docs/DOOMSDAY.md` "The algorithm, exactly", VERIFY.md, CHANGELOG.md. Waits for: CF-69, CF-78, the tracker stories
whose missions join, and WEB-80 on the site (same release).
- `Doomsday.POOL_VERSION = 2`; `since = 2` on the missions CF-71 to CF-73 built and on those of CF-74 whose checks
  passed by then; the points of CF-69 count from this version.
- The 15 categories in the draw; golden `draws` cases for days and weeks of pool version 2 from its first day (the
  release day), and the existing pool-1 cases unchanged.
- **The weekly draw takes 3 different categories**, as the dailies do (Nico, 2026-11-03, #177): every weekly gets a
  category, and from pool version 2 slot k takes `candidates[pick(week, 20 + k, #candidates)]` from the pool's
  weeklies whose category isn't taken yet and that weren't in last week's; if none is left, last week's are allowed
  again (categories still differ). Weeks of pool version 1 keep the draw without categories. Golden `draws` cases for
  weeks of both pool versions.
- The site ships its copy of pool version 2 in the same release (WEB-80); the release notes ask friends to update.
- Later bumps (3, 4, ...) add the missions of CF-74 to CF-76, CF-80 and CF-81 (and the weeklies and PvP goals of
  CF-79) as their checks pass, one bump per release,
  with golden cases each.
- Manual (VERIFY.md): on the release day, two friends on the new version see the same 3 dailies; a friend on the old
  version sees pool version 1's.
