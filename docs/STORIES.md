# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-46, CF-47, CF-48 once the web and uploader stories they need are in (web E7, uploader UP-12). CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).

## E14 Planned runs

Decided with Nico, 2026-10-27. Two kinds of group: **Ask now** lives in the game (CF-27) and is answered within minutes; a **planned run** is owned by the website, posted and answered in Discord, and ends in an invite in the game at start time. The game never talks to the internet: it learns about runs at login or `/reload` from `Data\Runs.lua` (written by the uploader, UP-12) or from a friend's addon over sync, and what the player does reaches the site after the game saves (`/reload` or logout) and the uploader uploads (web WEB-43). The in-game calendar is out of the flow. Times are UTC in data and shown in the player's local time. Boards: `docs/design/runs-2026-10/` (`runs-flow.html` shows the whole flow). Web stories: E7 in the web repo; bot: BOT-04.

### CF-46 Dungeons tab with runs
- Board `dungeons-runs.html`. A **Runs** segment next to the dungeons in range (with the count in the tab title), each run with dungeon, local time, organiser, "3 in · 1 maybe", your answer, and what you could fill ("Grom Ashfeller fits tank"). "Runs updated at 17:34 · /reload for newer" from `CF_RUNS.updatedAt`, never pretending to be live.
- A run's detail: the five slots from the roles the addon knows (CF-18), who answered where ("answered on Discord"), who is close in level, the reminder line, Invite all from start time (CF-48), "Edit or cancel on the website" with the link to copy.
- Dungeons in range show their planned runs ("1 run"). The calendar parts of CF-24 (event matching, Planner's `OpenEvent` queue, Open calendar) are removed.
- Runs are shared over sync to friends' addons (a new message type within `pv`; rule 8: older clients ignore it), the newer `updatedAt` wins, never sent during encounters, keystones or PvP matches.
- Tests: the runs list from a sample `CF_RUNS`, slot filling, newer wins over sync, an old client ignoring the new message.

### CF-47 Ask now, plan a run, sign up
- Board `run-dialogs.html`. **Ask now** (CF-27's ask in the new dialog): dungeon, you go as, who gets whispered and who not (and why), note, **Also post on Discord** (needs a `/reload`; "posted about 15 s later"). **Plan a run**: dungeon, lead as, day (today and the next 6 days), time on the PC clock ("friends see their own time"), note. **Sign up in game** to a run: I'm in / Maybe / Can't, Pick my character (fits / too high / too low), sent to the organiser's addon over sync at once when both are online.
- What has to reach the site (plans, answers, asks to post, pings from CF-48) goes into a `pending` table in SavedVariables, each item with an id (so a file uploaded twice changes nothing on the site), marked "reaches Discord after /reload" until a later `Runs.lua` or sync shows it arrived. Store migration step for the new table (rule 8).
- **The reload prompt** after Ask now or Plan run: "Reload now to post on Discord" / "Later" (later: at the next reload or logout; an ask older than 10 minutes by then is not posted).
- The labels everywhere: "reaches Discord after /reload", "answered on Discord", "Runs updated at … · /reload for newer".
- Tests: the pending queue (ids, cleared when confirmed), what goes in the saved file (the web's WEB-43 reads it: share a fixture), the expiry of a queued ask.

### CF-48 Reminder, start time and chat lines
- Board `run-start.html`. **Reminder toast** at the site's reminder time (default 30 min, in `CF_RUNS`) for friends who answered I'm in or Maybe and are online with the addon: under the minimap, 20 s, soft chime (off in settings), Open, no answer buttons. **Starting now** toast with Request invite.
- **Start-time panel**, opening by itself at start time (or from the Dungeons tab). Organiser: each friend's state from Battle.net presence and sync (ready, on another character, offline, maybe, can't, answered on Discord, already grouped) with Invite, Whisper (an editable Battle.net whisper), Invite <other character> instead, Ping on Discord (queued, after `/reload`); Invite everyone ready, Ping everyone missing. Everyone else: the organiser's state and Request invite (sends the organiser a request in game; when the organiser is offline, suggests whispering the next person).
- **Chat lines** in the addon's style with clickable links (`|H` links, V47): reminder, someone answered (in game or on Discord), starting now, on another character, ping queued, runs updated. Each type can be turned off in settings.
- Done marking needs nothing new: the run log (CF-23) already records the dungeon, time and community members in the group; the site matches it (WEB-43).
- Tests: the reminder timer from UTC times, the friend states, the invite list (skips grouped friends), chat line settings.
