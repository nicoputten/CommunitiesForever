# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.
CF-54 at launch (from 2026-11-05), CF-55 after CF-52 and CF-54, CF-56 after CF-55 and the ladder designs.

## E14 Planned runs (continued)

## E15 Recap v2: PvP, danger, loot (decided with Nico, 2026-10-28)
New data for new milestones and recap cards on the site and in Discord (web WEB-55 to WEB-57, bot BOT-14). Nico plays only on the PvP ruleset (no Hardcore stories). Gold is never shown as an amount anywhere, only relatively ("bought a mount", "the biggest spender"). The PvP ladder (an addon tab and a site page) and a dungeon catalogue with "first cleared" come later, after designs.

None of the APIs below are verified on Forever. Each one is guarded (rule 3), gets a FriendProbe check and a `VERIFY.md` step, and is verified at launch (from 2026-11-05). A guarded API that is missing leaves its field out (nil), and the site then simply shows no card for it.

Compatibility (rule 8): only new optional fields in `chars.*` and in feed entries, within `pv` 1. Older clients ignore them, relay what they keep, and a relayed record without them changes nothing (nil = unknown). New stored fields are optional (nil-safe), so no migration is needed unless a field changes meaning.

### CF-52 PvP, duels and deaths in the record
- Per character (`chars.*.pvp`): lifetime honorable kills, current PvP rank (number and title), and this week's honor, if readable. Candidates: `GetPVPLifetimeStats`, `UnitPVPRank`/`GetPVPRankInfo`, `GetPVPThisWeekStats`. Updated on `PLAYER_PVP_KILLS_CHANGED` and at login.
- Per feed day and character:
  - `kills = { [zone] = n }`: honorable kills by zone (the zone where the kill counter rose)
  - `deaths = { { zone, cause } }`, where `cause` is one of `fall`, `fire` (a campfire or other fire damage), `lava`, `drown`, `fatigue`, `player`, `creature` or `other`. Candidates: `ENVIRONMENTAL_DAMAGE` subevents in the combat log just before `PLAYER_DEAD`, or `C_DeathRecap`. Under the Midnight restrictions the combat log may be unavailable: then `cause` is `other`.
  - `duels = { { won, vs } }` where `vs` is the opponent's full character name as the game gives it (never split, rule 4). The winner comes from the `DUEL_WINNER_KNOCKOUT`/`DUEL_WINNER_RETREAT` system message, matched through the game's own format string, never hardcoded English.
- Battleground results are already in `runs` (`kind`, `won`, CF-23). Check that they are filled for Warsong Gulch, Arathi Basin and Alterac Valley once those are open.
- Sizes are capped like the rest of the feed (at most 50 deaths and 50 duels per day and character), and received data is cleaned (SYNC.md).
- `/cf self` shows the PvP line (kills, rank) for the current character.
- Tests: the pure parts (cause from the last environmental damage, duel result from a formatted message, caps, merge of the new fields) with busted. `SYNC.md` and `ARCHITECTURE.md` updated. A fixture for the new fields.

### CF-53 Loot, mounts, gold and play sessions in the record
- Per feed day and character:
  - `loot = { rare = n, epic = { itemID, ... } }`: rare (blue) and epic (purple) items received. Candidate: `CHAT_MSG_LOOT` for your own loot, quality from `C_Item.GetItemQualityByID`.
  - `gold = { gained, spent }` in copper: what came in and went out that day, from `PLAYER_MONEY` deltas. Never shown as an amount: the site only compares.
  - `sessions = { { from, to } }`: login to logout times (server time), for night owl, early bird and the longest session.
  - `groups = { [guid] = true }`: community characters you were in a group with that day, for "social butterfly" and "biggest group night".
- Per character: `riding` (the riding skill rank, 0, 75 or 150), from the skill lines (as professions are read). This gives the mount milestones.
- Caps and cleaning as in CF-52. Tests, docs and a fixture as in CF-52.

## E16 PvP ladder (decided with Nico, 2026-10-28)
A weekly and a lifetime ladder, duels and a battleground block, with **DoomPoints PvP** per kill and for daily and weekly goals (next to, never summed with, the DoomPoints PvE of the dailies and weeklies). It shows in the addon (a Ladder tab and a PvP line on the character card), on the site (web WEB-58, WEB-59) and in Discord (`/ladder`, bot BOT-15). The rules are in `docs/LADDER.md`; the addon stores raw kills and derives the points, so the rules can change later. Designs come from Nico (web `docs/DESIGN-PROMPT-RECAP-V2.md`, section 3). Order: CF-54 at launch (from 2026-11-05), then CF-55 (after CF-52), then CF-56 once the designs are in.

Compatibility (rule 8): only new optional fields in feed entries, within `pv` 1. Older clients ignore `pvpKills` and the death `t`, relay what they keep, and a relayed record without them changes nothing. Friends without CF-55 show on the ladder with their lifetime honorable kills and "no ladder data yet" instead of points, never a made-up 0.

### CF-54 FriendProbe: what Forever tells about a kill
Answers V73 to V77 in one run at launch. The results go to `docs/API-FINDINGS.md` and decide which fields CF-55 fills and which goals `docs/LADDER.md` can draw.
- `/fp pvp` switches kill logging on (it stays on after `/reload`; `/fp pvp off` stops it):
  - every `CHAT_MSG_COMBAT_HONOR_GAIN` with all its arguments, and whether the game's format string (`COMBAT_LOG_HONORGAIN` or the one that exists) gives the victim's name and rank
  - `PLAYER_PVP_KILLS_CHANGED` with the counters from `GetPVPSessionStats` and `GetPVPLifetimeStats`
  - for target, mouseover and each nameplate (`NAME_PLATE_UNIT_ADDED`) of an enemy player: `UnitName`, `UnitLevel` (`-1` on a skull), `UnitClass`, `UnitRace`, `UnitPVPRank` or the API that exists, and `UnitGUID`
  - whether `COMBAT_LOG_EVENT_UNFILTERED` can be registered, and if so each `PARTY_KILL` (with `GetPlayerInfoByGUID` on the victim's GUID) and the last damage source before `PLAYER_DEAD` (the killer's name: Wanted poster and revenge kill, `docs/LADDER.md` "Later")
  - `IsInGroup()` and `GetInstanceInfo()` type at each kill
- `/fp start` also logs `GetCurrentRegion()` (V77).
- Every call is guarded; a missing one logs `missing`, a secret value logs `secret`.
- The finding names which victim fields are readable at the moment of the honor message: from the message itself, or only from a target, mouseover or nameplate seen before.
- If the killer's name is readable, open stories for the Wanted poster and the revenge kill.

### CF-55 Raw kills and the ladder core
After CF-52 and CF-54.
- Per feed day and character, `pvpKills = { { t, zone, name, lvl, myLvl, class, race, rank, solo, bg } }`, one entry per honorable kill:
  - `name`: the victim's full name as the game gives it (never split)
  - `lvl`: the victim's level, `-1` for a skull; `myLvl`: your level at the kill
  - `class`, `race`: tokens (`WARLOCK`, `Human`); `rank`: the victim's PvP rank number
  - `solo`: true when not in a group; `bg`: true inside a battleground
  - Each victim field only when CF-54 found it readable. They come from the honor message or from a short-lived cache by full name, filled from target, mouseover and nameplates (at most 200 names, 10 minutes). Otherwise nil.
- At most 100 entries per day and character. CF-52's `kills = { [zone] = n }` keeps counting every kill, also past the cap.
- CF-52's death entries also get `t` (the time), for "without dying" and sprees.
- `src/core/Ladder.lua` (pure, rule 1) implements `docs/LADDER.md`:
  - points per kill
  - the draws, goal progress and goal points per character and day or week
  - the week number from the region
  - the views as data: week, lifetime, duels without Elo, battleground block, PvP Virgin
  - sprees: 5 and 10 kills without dying, as feed badges, not points
- `tests/fixtures/ladder-cases.json`, the golden cases shared with the site. They cover:
  - every band, skull, unknown level, solo, a community victim, the 4th kill of the same victim
  - bg kills going to the battleground block
  - the draws for fixed days and weeks (Tuesday and Wednesday reset)
  - every daily and bounty goal done and not done
  - a duel recorded by both sides, and a disputed one
  - a goal left out because its field is unknown

  `tests/spec/Ladder_spec.lua` reads it with a small JSON reader in the test helpers (no new dependency) and checks `Ladder` against it.
- Caps and cleaning of received `pvpKills` as for other feed fields (`SYNC.md`): numbers checked, strings stripped of `|`, unknown tokens dropped.
- Check the sync size of a week with 100 kills on each of 7 days (a test on `Serialize`); if it is over what CF-28 sends comfortably, lower the cap and note it in `LADDER.md`.
- `ARCHITECTURE.md` and `SYNC.md` updated. A fixture with `pvpKills`, and `Compat_spec` passes on earlier fixtures.

### CF-56 Ladder tab and the PvP line on the character card
After CF-55, once Nico's designs are in (boards from web `docs/DESIGN-PROMPT-RECAP-V2.md`, section 3).
- A **Ladder** tab in the main window, drawn from `Ladder` (CF-55):
  - **Week:** friends by DoomPoints PvP, expandable to their characters, your own row highlighted
  - **Lifetime:** honorable kills and rank
  - **Duels:** this week's wins and losses and the head-to-head grid
  - **Battlegrounds:** the block
- A goals panel for the character you are on:
  - today's Hunt, Class hunt, Daily and Duel, with progress (for example "Human Warlock 1/3")
  - the week's Streak, Class weekly and Weekly bounty
- The character card gets a PvP line: lifetime honorable kills, rank, this week's DoomPoints PvP and place, or **PvP Virgin**. Where the card shows DoomPoints, PvE and PvP stand side by side ("DoomPoints · PvE 34 · PvP 1,210").
- Spree badges in the Activity tab (5 and 10 kills without dying).
- Friends without CF-55 data show their lifetime numbers and "no ladder data yet", never 0 points as if known.
- Manual steps in `VERIFY.md`.
