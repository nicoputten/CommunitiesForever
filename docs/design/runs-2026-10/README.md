# Planned runs design (October 2026)

Design references for planned runs and the new group asks, made with Claude Design from the prompt in the Discord repo (`docs/DESIGN-PROMPT-PLANNED-RUNS.md`). They are **reference mockups**, not code. They are copies of the revamp boards (`../revamp-2026-10/`) with runs added; the revamp boards stay as they were. Where they overlap, these are the newer design. Stories: E14 in `docs/STORIES.md` (CF-45 to CF-48).

| File | What it shows |
|---|---|
| `runs-flow.html` | How a run travels between game, uploader, website and Discord: where a /reload is needed and the delays |
| `dungeons-runs.html` | Dungeons tab with the Runs segment instead of calendar events, "Runs updated at … · /reload for newer", a run's slots, Ask now and Plan a run |
| `run-dialogs.html` | Ask now (with "Also post on Discord"), the reload prompt, Plan a run, sign up in game, the labels used everywhere |
| `run-start.html` | Reminder toast, Starting now toast, the start-time panel for the organiser and for everyone else, chat lines |
| `widget-kit-runs.html` | The widget kit with the "Runs in game" building blocks (Runs.lua, reload prompt, invites, times) |

**Viewing:** run `python -m http.server` in this folder and open `http://localhost:8000/dungeons-runs.html`. `support.js` and `vendor/` are the design tool's runtime.

**Names are made up.**
