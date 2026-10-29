# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. CF-60 (launch checklist in FriendProbe) now: it ships before launch (Nov 4).
3. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).

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

## E16 Release preparation

### CF-60 Launch checklist
Agreed with Nico (2026-10-29). Ships before launch (Nov 4) as the FriendProbe zip. **CommunitiesForever does not change** (Nico: only the probe goes quiet).

**FriendProbe becomes the launch checklist** (its own addon, `tools/FriendProbe`, not part of CommunitiesForever):
- Shared as a zip: `tools\build-probe.ps1` builds `dist\FriendProbe.zip`. Friends unzip it into `Interface\AddOns`, play as usual and send Nico `WTF\Account\<account>\SavedVariables\FriendProbe.lua`.
- **Automatic for two weeks:** from the first login until 2026-11-18 it logs by itself, then stops. No command needed.
- **Silent:** no chat output during play, ever. Everything goes to its SavedVariables (`FriendProbeDB`): ticks, values seen, errors, capped (at most 2,000 log lines, oldest dropped).
- **`/fp` opens the checklist window:** the open `VERIFY.md` API questions (V8 to V86) and the per-story manual steps, grouped into six play sessions:
  1. First login alone: V78, V77, V61, V62, V64, V65, V66, V63, V71, V67, V68, V54, V55, and the Doomsday tab.
  2. With a friend: V59, V50b, V52, V53, V48, V69, V47, V72, V85, V80, V8, and the Board.
  3. Questing: V83, V86, dailies, feats.
  4. A dungeon: V70, the run log (V35 events), boss counts.
  5. World PvP: V73, V74, V75, V76, V79, V81.
  6. Later in the week: V84, V82, V35b, V51.
- **Automatic checkmarks** where the probe can judge it itself (API present, event fired, value sane, string parsed): green, or red with what went wrong. Others get Yes / No buttons. Items that need two people say "needs a friend"; each friend's file adds their results.
- **Test buttons** for the checks that need a click (reload, chat link, invite-all), as the old `/fp invite`, `/fp reload`, `/fp inviteall` did.
- **A "Copy report" button** shows the results as text to copy, as a fallback.
- **One table, kept in step with VERIFY.md:** `tools/FriendProbe/Checklist.lua` is pure data (id, session, title, how it's checked: an automatic check's name or "manual", "needs a friend"). A busted spec reads `VERIFY.md` and fails when an open V-item has no entry, or an entry has no open V-item.

Definition of done as usual; `busted` and `luacheck` pass; `VERIFY.md` gets the FriendProbe run steps.
