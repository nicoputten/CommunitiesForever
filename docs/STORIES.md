# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-48 once the web and uploader stories they need are in (web E7, uploader UP-12). CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).

## E14 Planned runs

Decided with Nico, 2026-10-27. Two kinds of group: **Ask now** lives in the game (CF-27) and is answered within minutes; a **planned run** is owned by the website, posted and answered in Discord, and ends in an invite in the game at start time. The game never talks to the internet: it learns about runs at login or `/reload` from `Data\Runs.lua` (written by the uploader, UP-12) or from a friend's addon over sync, and what the player does reaches the site after the game saves (`/reload` or logout) and the uploader uploads (web WEB-43). The in-game calendar is out of the flow. Times are UTC in data and shown in the player's local time. Boards: `docs/design/runs-2026-10/` (`runs-flow.html` shows the whole flow). Web stories: E7 in the web repo; bot: BOT-04.

### CF-48 Reminder, start time and chat lines
- Board `run-start.html`. **Reminder toast** at the site's reminder time (default 30 min, in `CF_RUNS`) for friends who answered I'm in or Maybe and are online with the addon: under the minimap, 20 s, soft chime (off in settings), Open, no answer buttons. **Starting now** toast with Request invite.
- **Start-time panel**, opening by itself at start time (or from the Dungeons tab). Organiser: each friend's state from Battle.net presence and sync (ready, on another character, offline, maybe, can't, answered on Discord, already grouped) with Invite, Whisper (an editable Battle.net whisper), Invite <other character> instead, Ping on Discord (queued, after `/reload`); Invite everyone ready, Ping everyone missing. Everyone else: the organiser's state and Request invite (sends the organiser a request in game; when the organiser is offline, suggests whispering the next person).
- **Chat lines** in the addon's style with clickable links (`|H` links, V47): reminder, someone answered (in game or on Discord), starting now, on another character, ping queued, runs updated. Each type can be turned off in settings.
- Done marking needs nothing new: the run log (CF-23) already records the dungeon, time and community members in the group; the site matches it (WEB-43).
- Tests: the reminder timer from UTC times, the friend states, the invite list (skips grouped friends), chat line settings.
