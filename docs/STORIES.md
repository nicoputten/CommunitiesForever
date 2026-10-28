# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.
E15 Doomsday: CF-52 and CF-53 now, CF-54 at launch, then CF-55, CF-56, CF-57 (see E15).

## E14 Planned runs (continued)

## E15 Doomsday (decided with Nico, 2026-10-28)
Daily and weekly goals, points per track, a streak and a crown, feats and a ladder, in the game, on the site (web E8) and in Discord (bot "Doomsday"). **`docs/DOOMSDAY.md` is the one description of the rules**; read it first. It replaces the three workshop designs (milestones, PvP ladder, dailies and weeklies; their PRs were closed unmerged).

Boards in `docs/design/doomsday-2026-10/`:
- `DD07AddonToday.dc.html`: Today, Week, chat lines, toast
- `DD08AddonBoard.dc.html`: Board, Ladder, Feats
- `AddonKit-doomsday.dc.html`: what WoW supports for Doomsday

The site's and the bot's boards are in their repos. Where a board and `DOOMSDAY.md` disagree, `DOOMSDAY.md` wins: the reset is 19:00 (a setting), goals are computed (not delivered through `Runs.lua`), and the crown gives no points.

None of the new APIs are verified on Forever. Each is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step (V73 to V78), and is checked at launch (from 2026-11-05). A guarded API that is missing leaves its field out (nil). A goal that needs it stays out of the pool, and the site shows no card or feat for it.

Compatibility (rule 8): only new optional fields in `chars.*`, feed entries and RECORD, within `pv` 1. Older clients ignore them, relay what they keep, and a relayed record without them changes nothing (nil = unknown). New stored fields are optional (nil-safe), so no migration unless a field changes meaning. Friends on an older addon show "no Doomsday data yet", never 0 points as if known.

Order:
1. CF-52 and CF-53 (data) now, guarded.
2. CF-54 (probe) at launch.
3. CF-55 (raw kills and the rules core) after CF-52, with its fields filled once CF-54 has answered.
4. CF-56 (goals tracked and shared) after CF-55.
5. CF-57 (the tab) after CF-56.
6. CF-58 (drop "Share my activity") any time, best before CF-56.

The site's WEB-58 needs CF-55's golden file.

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

### CF-57 Doomsday tab, chat lines and the toast
After CF-56. Split in two (Nico, 2026-10-29): **CF-57a** the tab with Today and Week, the chat lines, the toast, the setting and the card's PvP line (PR #102); **CF-57b** Board, Ladder and Feats (with sprees). Feats: the addon remembers locally when it first saw each one (`self.feats[guid][key] = time`), newest first from then on; feats a character already had show under "Earlier" (Nico).
Decided in CF-57a: swap lines come when the day turns while you play or with the first goal done that day, never at login; chat lines only on a character in the selected community. As the boards `DD07AddonToday` and `DD08AddonBoard` show, built with the kit (pools, `Kit.scrollArea`, `Kit.toast`), as the other tabs.
- A tab **Doomsday** after Dungeons, with:
  - **Today:** your 3 PvE dailies, the Hunt and the Skirmish, with progress ("7/10") or a check with its time, the time to the reset, the swap mark with the original in its tooltip, and the Duel slot (who you dueled, who's still open). Plus today's points (PvE and PvP), a kill summary ("9 kills: 4 near level, 2 solo, 1 above"), the streak, and who has the crown.
  - **Week:** the 3 PvE weeklies and the Weekly bounty with progress (for the bounty, what's still needed: "Paladin, Priest, Hunter"), this week's points per track and per character, the streak.
  - **Board:** every friend's goals today, from synced `goals`. A finished goal is checked and struck through with its time, and a friend is crossed out when all 3 PvE dailies are done. The crown, streaks, today's and this week's points.
  - **Ladder:** this week only, PvE and PvP side by side, each with its own ranking. Rows expand to characters. PvP Virgin is shown, not ranked. "All-time totals on the site."
  - **Feats:** your characters' feats as far as the addon can derive them, newest first.
  - The "everything done" state ("Doomsday done. Go touch grass.") and "Synced with Mira 3 min ago".
- Chat lines in the addon's chat style, as on the board:
  - a daily done
  - the Hunt done
  - a kill worth bonus points
  - someone else took the crown
  - a goal swapped for you
  
  A setting **Doomsday in chat** (on by default).
- A **toast** "First to finish today!" when you take the crown: a gold glow, fading in over 400 ms and sliding 12 px, that just appears when "Ambient effects" is off.
- The character card gets a PvP line: lifetime honorable kills, rank with our title ("Stone Guard, a.k.a. Mailbox Menace"), this week's PvP points, or **PvP Virgin**.
- Friends without Doomsday data show "no Doomsday data yet", never 0.
- **Feats and sprees** (moved here from CF-55, Nico 2026-10-28): the feats the addon can derive from the records it holds (the site's thresholds, web WEB-56, without "First in the group") and spree badges (5 and 10 kills without dying) in the feed, both in `src/core/Doomsday.lua`.
- Tests: the pure parts (rows, sorting, crossing out, the crown, reset times, chat texts, feats, sprees) with busted. Manual steps in `VERIFY.md`.
