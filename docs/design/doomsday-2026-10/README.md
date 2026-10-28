# Doomsday design (October 2026)

Design references for Doomsday in the addon, made with Claude Design on 2026-10-28 from the prompt in the web repo (`docs/DESIGN-PROMPT-DOOMSDAY.md`). They are **reference mockups**, not code: the inline styles carry the exact values (colours, sizes, spacing) the in-game kit should copy. Stories: E15 in `docs/STORIES.md` (CF-52 to CF-57). Rules: `docs/DOOMSDAY.md`.

| File | What it shows |
|---|---|
| `DD07AddonToday.dc.html` | The Doomsday tab: Today (5 goals, the Duel slot, today's points, kill summary, streak, crown), Week (weeklies, bounty, points per character), the "everything done" state, the chat lines and the "First to finish today!" toast (CF-57) |
| `DD08AddonBoard.dc.html` | The Doomsday tab: Board (every friend's goals today, struck through), Ladder (this week, PvE and PvP side by side) and Feats (CF-57) |
| `AddonKit-doomsday.dc.html` | A copy of the revamp's `widget-kit.html` with a "Doomsday in game" table: which goal or feat the addon can detect and how (yes / approximately), for CF-52 to CF-56 |

**Where `docs/DOOMSDAY.md` wins over the boards** (decided with Nico, 2026-10-28):
- **Reset time:** the boards say 09:00. The reset is **19:00 realm time**, a group setting on the site.
- **Goal list:** the kit board says it arrives through `Runs.lua` or sync. It is **computed** by `src/core/Doomsday.lua` from the day number; only the reset setting travels through `Runs.lua`.
- **First to finish:** the crown gives **no points** (version B). The toast stays as drawn.
- **API names:** the kit board names APIs (`DUEL_FINISHED`, `UPDATE_BATTLEFIELD_SCORE`, `TRADE_SKILL` events, …) as candidates only. What is verified is in `docs/API-FINDINGS.md`; anything else is guarded and checked first (CLAUDE.md rule 3, `VERIFY.md` V73 to V78).

**Viewing:** the pages need a local web server (scripts are blocked over `file://`), for example `python -m http.server` in this folder, then open `http://localhost:8000/DD07AddonToday.dc.html`. `support.js` and `vendor/` are the design tool's runtime, not part of the design.

**Names are made up** (Ada, Mira, Bob, Tok, Jorrit, …); there are no BattleTags or Discord IDs on the boards.
