# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).
2. CF-67 celebration banners (any time).

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

## CF-67 Celebration banners (Nico, 2026-11-02)
More gamification for Doomsday: a banner of its own, with a game sound, when you finish something, and a quiet line
when a friend does something big. Built from the designer's nine boards in `docs/design/celebrations-2026-11/`
(CB01 to CB09); where this story and a board differ, the board wins for the look, this story for the rules.

**Your own moments** (a banner and a Blizzard sound, no sound files of our own):
- each daily goal done (PvE dailies, the Skirmish, the Hunt): small, a green (PvE) or red (PvP) edge, "+5" (CB01)
- **Day complete**: all three PvE dailies done, the moment you are crossed out on the Board (so a PvE-only friend
  can finish, as the crown). Medium, gold edge, the Doomsday emblem, today's points "PvE 15 · PvP 10" side by side
  (never a total) and the streak; with the crown on the medallion when you were first (CB02). The daily that
  finished the day is part of this banner, not a second one.
- each weekly goal (blue edge) and the Bounty (red edge): medium, "+15", "Week 44 · 2 of 4" (CB03)
- a feat unlocked (CB04): **big** for PvP rank 6 or higher, level 60, the first epic, a mount, an epic mount,
  1,000 honorable kills or more, and "First in the group" (none of your characters and no friend's character in the
  records you hold has that feat); medium for the rest. The first epic takes the violet edge.

**Friends' moments** (CB06): a friend's day complete, a weekly done, a special feat. One quiet 34 px line bottom
left above the chat, no sound, 4 s, at most 3 stacked; they wait while your own banner shows. Only friends with a
record (BattleTag keys), never a single daily or a normal feat.

**Rules:**
- **Weight:** small, medium, big: the sound, the size (400 × 64, 470 × 80, 540 × 98 with rays and a glow) and the time
  on screen (4, 5, 6 s).
- **Folding** (CB05): everything that arrives within 3 seconds, or while banners wait, becomes one banner: the
  heaviest wins, ties go to the latest. The rest is one grey line under it in this order: day complete, goals
  ("+3 goals"), weeklies ("+1 weekly"), feats ("+2 feats"), crown. Only the winner's sound plays.
- **Waiting:** in combat, during an encounter and in a battleground or arena banners wait, and show 2 s after it
  ends, folded.
- **No doubles, nothing old:** no banner for what happened before the update or before login; nothing twice after a
  `/reload` (own moments are remembered per day, week and feat; friends' moments by key). Feats found in the first
  10 s after login are taken as known (as the Feats view's "Already had"). A friend's moment shows only when it
  happened after your login and within the last 15 minutes; the first time a friend's character is seen, its feats
  are known.
- **Place and motion** (CB07, CB08): centred, 190 px above the bottom of the screen; below 1600 px screen width at
  85 %. In over 250 ms (rise 16 px and fade, the medallion pops 0.8 → 1.05 → 1), out over 400 ms (fade, sink 8 px);
  big feats turn their rays slowly. Ambient effects off: no movement at all.
- **Mouse:** hover pauses the timer and shows "Click to open Doomsday" (feats: "Click to open Feats"); a click opens
  the window on Doomsday › Today (goals, day complete), Week (weeklies), Feats (feats) or Board (friends); right-click
  dismisses.
- **Settings** (CB09): a section "Celebrations" with "Celebration banners", "Celebration sounds", "Friends'
  celebrations" (all on by default; banners off greys out the friends' switch) and a Preview button (a medium sample
  banner for 5 s with its sound). The existing crown toast and the Doomsday chat lines stay as they are.

**Built:**
- `src/core/Celebrations.lua` (pure): the moments from goals done, feats and friends' records; weights and edges;
  folding; the waiting queue; the friends' rules and their known keys. Busted specs.
- `src/services/Celebrate.lua`: listens to Doomsday and feats, asks the adapters whether you are busy, shows banners.
- `src/ui/CelebrationBanner.lua`: the plaque and the friends' line on kit frames, textures drawn by
  `tools/make-textures.py` from the boards' shapes.
- Sounds: `SOUNDKIT` entries per weight, guarded (V88). Physical screen width and texture rotation guarded (V89).

**Compatibility (rule 8):** three new switches in `settings` (nil = on, no migration) and
`self.doomsday.celebrated` (local, never sent; nil = nothing celebrated yet). An older version ignores both and keeps
them in the file. No message changes.

**Acceptance:**
- Each trigger above makes its banner with the board's texts, colours and size; friends' moments make their line.
- Several at once fold as on CB05 with one sound; nothing shows in combat, an encounter or a battleground until 2 s
  after; nothing repeats after `/reload`; nothing from before login.
- The settings work as on CB09; Preview shows a medium sample; Ambient effects off stops all movement.
- `busted` and `luacheck` pass; VERIFY steps per board (CF-67) and V88, V89.
