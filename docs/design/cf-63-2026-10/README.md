# CF-63 design (October 2026)

Design references for CF-63, an interactive Dungeons tab, plus the Doomsday goal box. They were made with Claude Design on 2026-10-30 as copies of the addon v2 boards (`../addon-v2-2026-10/`), fixed for CF-63. They are **reference mockups**, not code: build what they show with the kit, using only what an addon frame can draw (`AG04Kit`). Where a board differs from the story text in `docs/STORIES.md`, the board wins.

| File | Board | What it shows |
|---|---|---|
| `CF63RunDetail.dc.html` | AG02Dungeons · run detail, header & layout | The header (the full name; "level 26–36 · <zone>"; the countdown, which becomes "Starting now"), full-width group rows, then Your answer, then one row with "Online now, fits" on the left and "Edit or cancel" or "On the website" on the right |
| `CF63Answer.dc.html` | AG02Dungeons · answering inline | The "Your answer" block in every state: not answered, in, maybe, can't, reserve, waiting for the upload (clock icon), the character dropdown |
| `CF63Group.dc.html` | AG02Dungeons · group rows | A member's hover tooltip, the right-click menu (Whisper, Invite, Show in Friends), an open slot's menu with the prefilled whisper and "Ask now for this run" |
| `CF63List.dc.html` | AG05InRange · list & planning | The filter chips, "In range for <character>" with its dropdown, "Show all dungeons" with Other dungeons, a dungeon with nobody else online, a dungeon out of range planned for an alt, inline planning, and "No dungeon fits yet" |
| `CF63Banners.dc.html` | Run reminder banners (new) | Banners at 30 and 15 minutes before and at the start, plus the organiser's version with Invite all |
| `CF63DoomBoard.dc.html` | Doomsday Board | The drawn 15 px goal box (open, done, swapped) in every cell, with its tooltip |
| `CF63DoomToday.dc.html` | Doomsday Today | The same goal box in the Today list |

Each board lists its visible strings, with tooltip and menu texts listed separately. Nico agreed with three of the designer's choices (2026-10-30):
- Today shows the word "swapped" as well as the blue corner.
- Banners wait during combat and battlegrounds, and a banner that comes due after the run has started is dropped.
- A full role makes you a reserve, and the tooltip says so.

**Viewing:** serve this folder (`python -m http.server`) and open a `.dc.html`. `support.js` and `vendor/` are the design tool's runtime; they are the same for all seven boards. The names on the boards are made up. The site domain is the public website.
