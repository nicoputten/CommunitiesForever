# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. Now: CF-61 (retail dry-run fixes), in four PRs (a to d) plus a FriendProbe PR.
2. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).

## CF-61 Retail dry-run fixes (decided with Nico, 2026-10-29)
Bugs from Nico's dry run on Retail 12.1.5 (`docs/API-FINDINGS.md` "Retail 12.1.5 dry run"), fixed as one story in four PRs. Bug 1 shipped first as its own PR (#119).

**1. Loot quality from new links (PR #119).** Item links that carry the quality (`|cnIQ<n>:`) instead of a colour count blues and purples also before the game has cached the item. The game's own quality still wins once known.

**CF-61a: small fixes**
- 2. Setup wizard: the step line ("Step 1 of 6 · Welcome → Community → … → Done") stays inside the window. It shows the step number with the current and the next step only.
- 3. Settings window: each description wraps to its own column's width, and its row grows with it. Nothing runs under the other column or past the window edge.
- 4. Settings footer: the version shows one `v` ("v0.8.0-beta1", not "vv0.8.0-beta1").
- 5. An alt that isn't in the selected community:
  - On the first login of that character, the window opens once by itself on the join explanation with the invite link. This is remembered per character, like the chat-tab prompt.
  - As soon as it joins (also while playing), the Community chat tab prompt is offered.
- 10. The Community tab prompt: sized to its content, one short line ("A tab with only your community's chat."), and Create tab and Not now as kit buttons on the right.

**CF-61b: no designer notes in the UI; one reset label per view**
- 6. Every tab, dialog, footer and chat line is checked for board notes, legends and design rationale. Each one is removed, or moved into a tooltip where a player needs it. The PR lists every removed or moved string. Examples:
  - "Live for friends online with the addon; others update after their upload."
  - "* = swapped goal (hover for the original). Crossed out: all three PvE dailies done."
  - the footer "Suggestions, never rules · all-time totals on the site"
  - "Any of your characters counts."
  - "This week only. All-time totals, Elo and battleground history live on the site and in Discord."
  - "no kills yet · Rank title: Conscientious Objector until the first kill."
- 8. Reset labels:
  - Today and Board show only "New goals in 5 h 58 m".
  - Week and Ladder show only "Week resets Sun 19:00 · in 3 d 5 h".
  - The generic line in the tab bar goes.

**CF-61c: a cleaner Board** (confirmed with Nico)
- Friend column:
  - the name, struck through when all three PvE dailies are done, with the finish time, and the crown
  - the streak in the name's tooltip; there is no streak column
- One column per goal:
  - each with a short title: `shortLabel` per goal in `Doomsday.GOALS`, at most 10 characters, the same as on the site (agreed with the web engine, listed in `docs/DOOMSDAY.md`)
  - a gold ✓ when done (the time in the tooltip), or an empty box □ (the progress, e.g. "3/10", in the tooltip)
  - a swapped goal gets a small dot with an "Instead of: …" tooltip
- One points column, "PvE 15 · PvP 11" (never added together).

**CF-61d: Feats, and the rule updates**
- 9. Feats tab:
  - Only feats earned while the addon watched the character are listed.
  - Feats it already had when the addon first saw it fold into one line, "Already had: Level 10, Level 20, …", with the details in a tooltip.
  - A mount feat needs level 40 (an epic mount needs 60). Below that it is never recorded, and stored ones are hidden.
- The web engine's `docs/DOOMSDAY.md` rule updates, in chat lines and tabs, once they are in:
  - PvP Virgin: any PvP point ends it, duel points included.
  - Rank title: "No rank yet · N kills".
  - Goal count: the Duel slot counts.
  - Day label by reset: "Wed evening", and times after midnight with the weekday.

**FriendProbe** (Nico's decision: what he checked on Retail needs no recheck on Forever)
- Done from the Retail run:
  - V77, V78, V63, V71, V55, V68, V50b, V83, V86, V82, V54, V61 and V80 (the strings)
  - V81 (`C_DeathRecap` exists)
- These show in the probe as "done (retail 12.1.5)", out of the open list. They are closed in `VERIFY.md`, and their answers move into `API-FINDINGS.md` as answers.
- Still open: V64 (the shimmer fix), V75 (combat log), V79 (Vanilla ranks), and everything that needs a friend, a dungeon, PvP or Forever only.
- The probe zip is rebuilt.

Compatibility (rule 8): no stored data or messages change, except that mount feats below level 40 are hidden when read (they are not deleted).

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
