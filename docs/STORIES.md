# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order:
1. Now: CF-63 (an interactive Dungeons tab), in PRs a to d. (CF-62 is merged; its story moves to the completed list with CF-63's.)
2. At launch (from 2026-11-05): CF-54 (the FriendProbe run), then CF-38 (recipes; waits for the V60 check, its story is in PR #63).

## CF-63 An interactive Dungeons tab (decided with Nico, 2026-10-30)
From Nico's retail test of a website run (SM: Graveyard) and his answers to five rounds of questions. Same rules as CF-62: player-facing copy only (explanations in ⓘ tooltips), every new visible string listed in the PR, specs for the core logic, `VERIFY.md` steps, rule 8.

**Causes found (retail test):**
- The run showed the raw id "smgy", had no level range, no "online fit" and no "In range" section. One cause: `Dungeons.applyGroupFinder` replaces the dungeon list with what the Group Finder offers, and on Retail that is only retail dungeons (other activity IDs). So `smgy` wasn't in the list. This is not a Midnight restriction. Forever's Group Finder offers the Vanilla dungeons (V46).
- Role and character couldn't be changed: the answer dialog lists your characters by the dungeon's level range, so with no range found, nothing was listed.
- The site sends the addon's own ids (`smgy`, `smlib`, `smarm`, `smcath`, `lbrs`, `dme`, `lfg1981` to `lfg1984` for Forever's new dungeons) plus an optional `dungeonName` (`docs/UPLOADER-API.md`). It accepts a game answer with `guid` and `role` for any site run already.

**CF-63a: fixes**
- A run's dungeon is looked up in the full static list, not only what the Group Finder offers. Without a match the name comes from `dungeonName`, else a readable form of the id; it is never the raw id.
- When the Group Finder offers none of the known dungeons (Retail), the static list is used.
- "In range for <character>" always lists the dungeons that fit your level, even when you're the only one online; offline characters can be suggested.
- Layout: "Edit or cancel" (the link box) moves below the group, so the group rows get the full width. A row's name never runs into its status: names are measured and cut only below the window's normal width; tested with long names at 1080 × 720.
- An answer or plan waiting for the next upload shows a small clock icon with a tooltip, not a text line.

**CF-63b: answering and the group**
- Inline, instant answering in a run, also for website and Discord runs. Every click saves, reaches friends online at once, and reaches the site with the next upload.
  - I'm in / Maybe / Can't.
  - A character dropdown: all your characters, with their level fit ("fits", "carry · +12", "4 below").
  - Role toggles for the roles the class can play, each with its slot ("Healer · open", "Damage · full" means reserve).
  - An optional note to the organiser (up to 80 characters). It needs a web change: an optional `note` on answer items, ignored by older sites.
- Group rows:
  - a hover tooltip with the character, level fit, role, when and where they answered (site, Discord, game) and the character they are online on
  - a right-click menu: Whisper, Invite (from 15 minutes before the start, out of combat), Show in Friends
  - no organiser moves: everyone sets only their own answer, character and role
- An open slot and "Online now, fits":
  - Whisper opens a whisper prefilled "Up for SM: Graveyard at 20:30? We need a Healer." (you send it)
  - "Ask now for this run" sends an Ask for the run's dungeon with the note "For SM: Graveyard 20:30 · need Healer", to friends with the addon and to Discord through the uploader; the site's ask already has a note
  - Invite from 15 minutes before the start

**CF-63c: the list and planning**
- Filter chips: All (the default, reset on close), My runs, Open slots, In range.
- "In range for <character>" has a dropdown to pick any of your characters (back to the one you're on at each login), and a "Show all dungeons" toggle for the rest.
- A dungeon out of range still shows who fits and the suggested group. Plan and Ask preselect your character that fits (an alt); when none fits, your character shows its fit ("carry", "too low").
- Planning inline: chips for the next three evenings at 20:00 your time ("Tonight 20:00" only while it's at least an hour away, "Tomorrow 20:00", "<weekday> 20:00") and "Other time…" (the existing dialog). Your character and role are preselected, with a note field.
- Countdowns ("in 3 h 10 m", "Starting now") update every minute while the window is open.

**CF-63d: run reminder banners**
- Banners like the LEVEL UP toast (top centre, gold border, the dungeon, your role, the time; they fade after 10 s; a click opens the run) for everyone who is in or maybe, and the organiser:
  - 30 minutes before
  - 15 minutes before ("invites open"; the organiser gets Invite all)
  - at the start
- They replace the old reminder (CF-48), so nothing comes twice.

**Web change (for a web worker):** an optional `note` (up to 80 characters, escaped) on game items of kind `answer`, stored with the answer and shown on the site and in Discord. Older sites ignore it.

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

**Approved deviations from the boards (Nico, 2026-10-29):**
- Solid 1 px borders where a board shows dashed ones (the Friends empty box, open group slots): the kit has no dashed line.
- An extra "Offline · N" group in the Friends list, so synced friends who are offline stay listed.
- In a run, "change" opens the existing answer dialog rather than a small menu.
- No "Discord already pinged everyone who answered" line: the addon can't tell whether the ping went out.
- Class icons as the kit's round class portraits (`Kit.portrait`), not the `classicon-*` atlas.

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
