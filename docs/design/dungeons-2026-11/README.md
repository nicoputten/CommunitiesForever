# Dungeons & loot · in the addon (CF-106) — design reference

Design mockups created in a visual design tool, exported as standalone pages. Treat them as REFERENCE MOCKUPS, not
production code: the markup and inline styles carry the design's precise values — colors, font sizes, spacing, radii,
shadows, layout — which the kit (`src/ui/kit/`) replicates in its own widgets.

## Contents

- `DL01Runs.dc.html` — the Runs tab: its own tab, day groups, row status, the badge, boss progress (A, B).
- `DL02Dungeons.dc.html` — the Dungeons tab: every dungeon grouped Fits you · Higher · Lower, a dungeon with Bosses &
  loot and Quests.
- `DL03States.dc.html` — states A to F: nothing fits, the Usable switch, quest and recipe drops, a long loot list, run
  rows (no boss yet, no fit), no runs.

The site's boards (DL04 dungeon page, DL05 run page) live in the CommunitiesForever-Web repository.

The runtime the pages load (`support.js`, `vendor/react*.js`) is not committed here; copy it from another folder in
`docs/design/` to view them (serve the folder, e.g. `python3 -m http.server`; some browsers block the scripts over
file://).

## Decisions after the boards

- DL02's tooltip names a run tag "Tonight": the tags are **Today**, **Tomorrow** or a weekday (Nico, 2026-11-07).
- "Plan a run…" gives the website's link to copy: runs are planned on the website or with the bot's `/plan` (CF-64).
- The "Can learn" tooltip of a recipe lists who has the profession; the loot file has no required skill, so the skill
  check of the board waits for a later file.
- All names in the boards are made up.
