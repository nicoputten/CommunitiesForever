# Addon v2 design (October 2026)

Design references for the in-game window v2, made with Claude Design on 2026-10-29 (canvas "Doombringers v2", section "Addon in game v2"). They are **reference mockups**, not code: build what they show with the kit, using only what an addon frame can draw (`AG04Kit`). The brief is `BRIEF.md` in this folder.

| File | What it shows |
|---|---|
| `AG01Audit.dc.html` | The window as it was on 29 Oct, with numbered issues. Its four screenshots are **not** in the repo: they showed a real BattleTag and a friend's account name. The full board is kept locally. |
| `AG02Dungeons.dc.html` | The Dungeons tab v2: run list with role pips, the detail with five group rows, "Online now, fits", the action area (organiser before and at the start, a member's answer), Edit or cancel, and the empty state |
| `AG03Tabs.dc.html` | Doomsday (Today with check boxes, stat boxes, the Friends today mini board), Friends (character cards) and Activity (character first, the end of the day) |
| `AG04Kit.dc.html` | What an addon frame can really draw: square corners, 1 px borders, two-colour gradients, atlases with fallbacks, no blur, no shadows, no letter-spacing |

Where a board shows an explanatory line, the rule "player-facing copy only" applies (`docs/STORIES.md`, CF-62): only the lines Nico confirmed stay, and the rest go in a tooltip or nowhere.

**Viewing:** serve this folder (`python -m http.server`) and open a `.dc.html`. `support.js` and `vendor/` are the design tool's runtime. Names on the boards are made up; the realm "Chromaggus" is a public realm name.
