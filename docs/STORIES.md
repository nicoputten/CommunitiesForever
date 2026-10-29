# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. Now: CF-62 (addon v2), in PRs a to d; the Dungeons tab (d) waits for its updated board.
2. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).

## CF-62 Addon v2: Dungeons tab and polish (decided with Nico, 2026-10-29)
Nico's brief and boards: `docs/design/addon-v2-2026-10/` (`BRIEF.md`; `AG02Dungeons`, `AG03Tabs`, `AG04Kit`; `AG01Audit`, whose screenshots stay local). Build what the boards show with what a frame can draw (`AG04Kit`); where a board can't be built 1:1, ask Nico first. Nico's answers below override the brief.

**Player-facing copy only.** Every visible string is short copy for a player. Of the boards' explanatory lines:
- Kept as visible text:
  - "Runs from the website, <time>. Type /reload after an upload for newer."
  - "Click, then Ctrl+C to copy."
  - the empty states ("Nothing planned yet…", "Nobody online fits right now.", the Friends empty box)
- Moved into an ⓘ tooltip (a kit icon next to the heading it belongs to):
  - "From the community roster: online members whose current character fits…"
  - "Shared with online friends now; the website gets it with your next upload."
  - "⇄ swapped: … Goals are suggestions; skip any."
  - "Live for friends online with the addon; others after their upload."
  - "That's all for today. Friends' activity arrives when…"
  - "Reminder at 20:00. Invite all invites everyone who is in and online."
- No other new explanations. Each PR lists every new visible string for Nico.

**Nico's answers (2026-10-29):**
- **Dungeons:** the in-range functionality stays: dungeons in range for your character, the suggested group, the dungeon's quests, Plan a run and Ask now per dungeon. Nico asked the design bot for an updated board that combines it with the v2 run detail. CF-62d waits for that board.
- **Duel row:** it shows the PvP points earned today ("+4" after a win and a loss, nothing at 0). The tooltip says "Win +3 · loss +1 · first duel per friend".
- **Doomsday chips:** the Board chip stays (the full per-goal table, CF-61c), next to the new "Friends today" mini board on Today.
- **Website data in `Data\Runs.lua`:** both optional (rule 8: when absent, the group or button just doesn't show). The shape is agreed with the web engine (WEB):
  - the friends the site knows, for "Not synced yet · N" on Friends: display names and characters, never BattleTags
  - the site's address, for "Copy website link"

**CF-62a: small fixes**
- The title shimmer: the streak is invisible between passes. It waited visibly at the left, which was "the white strip behind the shield". The LEVEL UP shine likewise.
- FriendProbe's "Test: file reload" (V67) shows its result on the V67 row and sets a result. The other test buttons are checked for the same gap.
- Closed on Retail (Nico's rule: checked on retail counts as done): V62 (yes), V65 (yes), V66 (yes) and V67 (pass). A changed file is re-read on /reload, and even a newly added file with its TOC line loads on /reload. They are closed in `VERIFY.md`, with the answers in `API-FINDINGS.md`.

**CF-62b: Doomsday tab** (`AG03Tabs`, Today):
- The header has the count of the goals shown (the Duel slot included) and "New goals Thu 19:00 · in 4 h 28 m" on the right.
- Goal rows (40 px):
  - an 18 px check box first
  - the kind in its track colour
  - the title, struck through when done
  - "⇄ swapped" with the original in the tooltip
  - "done"/"not yet" for one-step goals, or a 140 px bar with "1/10" for counts
  - "+5" in the track colour (the Duel row: the points earned today)
- The stat boxes Today, This week and Streak.
- On the right, "Friends today": five boxes per friend (PvE green, PvP red), "PvP Virgin", "PvE · PvP", struck-through names and the crown.

**CF-62c: Friends, Activity, footer, title bar** (`AG03Tabs`):
- Friends:
  - "You" for yourself, and no BattleTag anywhere
  - "Online on <character> · <zone>"
  - character cards (class icon, name with the realm as a dim suffix, level · role, online or "played …", a level bar, zone and professions)
  - "Not synced yet · N" with the friends from the website data
- Activity: the character first, a one-line summary, Yesterday below Today.
- Footer:
  - "Synced with N friends · HH:MM", or "… · waiting for someone online"
  - Friends: "… this session · M of your characters"
- Title bar: only the shield.

**CF-62d: Dungeons tab** (`AG02Dungeons` plus the updated board):
- Runs list with role pips and groups Tonight, Tomorrow, This week and Later.
- Run detail:
  - the dungeon's name as the title, with the note on the subtitle
  - five group rows that never cut a name
  - "Online now, fits" from the community roster, with Whisper, or Invite from 15 minutes before the start
  - Invite all from 15 minutes before the start
  - your answer (I'm in, Maybe, Can't), shared with online friends
  - the edit link
- The empty state.
- The in-range dungeons as the new board shows them.

Done when: the brief's "Done when" (`BRIEF.md`) is met for the tabs in each PR. `busted` and `luacheck` pass. Every newly used API is guarded and has a `VERIFY.md` step (atlases via `C_Texture.GetAtlasInfo` with the coloured-square fallback, `ChatFrame_SendTell`).

Compatibility (rule 8): answers already travel and are stored (CF-47). The new `Data\Runs.lua` fields are optional. Any new stored field is optional, with nil handled.

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
