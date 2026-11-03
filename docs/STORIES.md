# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).
2. CF-68 (the Mission pool schedule), alongside the site's WEB-78: they share the schedule's shape and golden cases.

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

## E16 Mission pool schedule (2026-11-03)
The site's owner can change future Doomsday days and weeks on a Mission pool page (web E10: WEB-78, WEB-79; boards in the web repo, `design/boards/mission-pool*`). The site sends only the changed days and weeks, as a schedule; every other day stays the normal draw (`docs/DOOMSDAY.md` "The algorithm, exactly") on both sides. Today and tomorrow are locked on the site, and a week locks 24 h before it starts, so a change has time to reach everyone.

### CF-68 Doomsday schedule from the site
- **Read it:** `CF_RUNS.doomsday.schedule` from `Data\Runs.lua` (`RunsFile`, read at login or `/reload`): `{ v, days = { ["<n>"] = { daily = { id, id, id }, skirmish = id, hunt = id } }, weeks = { ["<week>"] = { weekly = { id, id, id }, bounty = id } } }`. `v` is the site's server time of its last change. The exact shape is agreed with web WEB-78.
- **Check it** (a pure core function with busted tests): keys are day and week numbers; ids as the goal records allow (at most 24 characters of letters, digits and dots); at most 3 dailies, 3 weeklies, one of each other slot; only days from yesterday to 16 days ahead and weeks from last week to 3 weeks ahead; anything else is dropped. A broken table gives no schedule.
- **Use it:**
  - For a day or week the schedule lists, each listed slot takes the scheduled mission; a slot it leaves out, or whose id this addon doesn't know (a newer pool), takes the normal draw's mission. Swaps apply on top, per friend, as today.
  - Any other day or week is the normal draw. The "never twice in a row" chain stays on the normal draw, so a scheduled day doesn't change the days around it.
  - A day or week that has started keeps the set already recorded in `goals`; a schedule that arrives later doesn't change it.
  - The Hunt slot is used only while the Hunt is on (`HUNT_SINCE`).
- **Keep it:** stored in SavedVariables (`global`), so it lasts without the uploader; days and weeks that are over are dropped. A newer `v` replaces it, from the file or from a friend.
- **Pass it on,** like planned runs (CF-46): HELLO gains `ds` (the schedule's `v`); a HELLO with a newer `ds` gets a `SCHEDREQ`; the answer is `SCHED { v, days, weeks }`. Accepted only when `v` is newer than ours and at most 5 minutes ahead of server time, then checked as above. Over the community and Battle.net as RUNS.
- **Compatibility (rule 8):** new optional fields and new message types within `pv` 1. An older addon ignores `ds`, `SCHED` and `SCHEDREQ` and shows the normal draw. The schedule in SavedVariables is a new optional table: no migration; a version without it starts with none. `docs/SYNC.md` and `docs/DOOMSDAY.md` ("The draw": a new "Schedule" part) describe it.
- **Golden cases:** `tests/fixtures/doomsday-cases.json` gains schedule cases (a day with all slots, one slot, an unknown id, a week, a day already recorded); the site's copy passes them unchanged.
- **Screens:** no change. A scheduled day looks like any other day.
- Done when:
  - busted tests: checking the schedule, using it per slot, the fallbacks, a started day kept, keeping and dropping old days, accepting `SCHED` (newer, older, too far ahead)
  - the golden cases pass in the addon and on the site
  - `busted` and `luacheck` pass; `VERIFY.md` gets the in-game steps (a changed day in Runs.lua shows after `/reload`; a friend without the uploader gets it over `SCHED`; an older addon shows the normal draw)
