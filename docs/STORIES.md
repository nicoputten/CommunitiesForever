# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.

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
