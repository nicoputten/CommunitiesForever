# For the web repo: the Doomsday mission catalogue on the site

**This story belongs to the web repo (`nicoputten/CommunitiesForever-Web`).** It is written here, next to the addon's
E18 stories (`docs/STORIES.md`), so both sides are agreed in one review. Copy it into the web repo's `docs/STORIES.md`
with the next free WEB number there (WEB-80 and WEB-81 if they are free), and delete this file once it is copied.

The approved list is `docs/DOOMSDAY-CATALOGUE.md` in this repo: 118 PvE dailies in 15 categories and 4 Skirmish goals,
numbered 1 to 125, each with id, label, points (1, 3 or 5) and category. The rules stay in `docs/DOOMSDAY.md`; the
golden cases in `tests/fixtures/doomsday-cases.json` pin both copies.

## WEB-80 The site's copy of the pool: catalogue, labels, points (pairs with CF-69, CF-70, CF-77)
- The TypeScript pool gets every catalogue mission with its id, slot, category (15 categories), text, short label and
  points. Missions without `since` are in the catalogue but never drawn, as today.
- Points per goal (CF-69): a day's and a week's points come from its `done` ids and the pool version recorded with
  them (`goals.pool`): days of pool version 1 keep 5 per daily and 15 per weekly; from pool version 2 each goal's
  points. An unknown id scores the old flat value. Crown, crossing out and the streak are unchanged (they count goals).
- Pool version 2 (CF-77) ships in the same release as the addon's: the draw with 15 categories, the new `since`
  values, `POOL_VERSION = 2`, and the weekly draw by category (3 different categories, as the dailies; weeks of pool
  version 1 keep the draw without categories).
- Golden cases: the new keys `pointsPerGoal` and the pool-2 `draws` are copied byte-identical from the addon's
  `doomsday-cases.json` and pass unchanged; the existing cases keep passing.
- Every place that shows points (the /dailies page, the roster, the ladder, Discord recaps through the bot's data)
  shows the per-goal totals. Points per track stay side by side, never added together.
- Labels and texts come from the pool, never typed twice.
- **PvP Virgin (CF-78, Nico 2026-11-03):** a friend stays a PvP Virgin until a real fight: an honorable kill, a duel
  or a finished battleground. PvP points from goals without a fight (emotes, the PvP flag) count on the PvP track but
  don't end it. The ladder, the roster and the bot's data use the same rule; golden `ladder` cases pin it.

## WEB-81 The Mission pool page for 118+ missions (pairs with WEB-78, WEB-79)
The page was built for 37 missions (14 PvE dailies). With 125 in the catalogue it needs:
- **Group and filter:** the pool table grouped by slot, then by category (15 for the dailies), each group folded
  open or shut with its count ("Cooking · 9"); filters for slot, category and state (in the pool / waiting for data /
  off); a search box on title, label and id.
- **Waiting missions shown:** a catalogue mission not yet in the pool (no `since` in the site's pool version) is listed
  greyed with "waiting for data" and the VERIFY number from the catalogue when known; it can't be scheduled or set to
  Often, and How often is disabled with that reason as its tooltip.
- **Points column** with each mission's points (1, 3, 5), and the day tiles show the day's PvE total.
- **Pick…** in the day editor: a searchable list with the category filter, only missions that can go in that slot
  (in the pool, category not taken that day); the refusal line stays for anything else.
- **Phone:** the groups start folded with their counts; "Show all N" works per group; the table never scrolls
  sideways.
- **Counts header:** "Daily PvE · 118" and so on per slot, and how many are in the pool now.
- Screenshot baselines (desktop and phone) for the grouped table, a folded group, the filters, and Pick… with search.
