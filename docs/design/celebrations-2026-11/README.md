# Celebration banners (November 2026)

Design references for the addon's celebration banners (CF-67 in `docs/STORIES.md`), made with Claude Design on
2026-11-02. They are **reference mockups**, not code: the inline styles carry the exact values (colours, sizes,
spacing) the in-game kit copies. Rules: the story and `docs/DOOMSDAY.md`.

| File | What it shows |
|---|---|
| `CB01Daily.dc.html` | Your daily goal done: the small banner, green edge for PvE, red for PvP |
| `CB02Day.dc.html` | Day complete: gold edge, the Doomsday emblem, today's points per track and the streak; the crown when first |
| `CB03Weekly.dc.html` | A weekly goal (blue edge) and the Bounty (red edge), medium |
| `CB04Feat.dc.html` | Feat unlocked: special (big, rays and a glow), first in the group, epic (violet edge), normal (medium) |
| `CB05Folded.dc.html` | Several at once: the biggest shows, the rest in one grey line under it |
| `CB06Friends.dc.html` | A friend's moment: one quiet line bottom left, no sound |
| `CB07Screen.dc.html` | Where the banners sit at 1920 × 1080 and 1280 × 720, next to the other toasts |
| `CB08Motion.dc.html` | Motion: in 250 ms, 4 to 6 s on screen, out 400 ms; still with Ambient effects off |
| `CB09Settings.dc.html` | The settings section "Celebrations" with three switches and Preview |

**Where the story decides** (the boards leave room):
- **Day complete** is the moment all three PvE dailies are done (crossed out on the Board, the same moment as the
  crown), so PvE-only friends get it too.
- **Folding** waits 3 seconds from the first moment (CB05 "everything that arrives within 3 seconds").
- **Medallion icons** for feats the boards don't draw (levels, professions, mounts, duels) use the boards' own
  glyphs: the Doomsday emblem for PvE feats, crossed swords for PvP feats.

**Viewing:** the pages need a local web server (scripts are blocked over `file://`), for example
`python -m http.server` in this folder, then open `http://localhost:8000/CB01Daily.dc.html`. `support.js` and
`vendor/` are the design tool's runtime, not part of the design.

**Names are made up** (Ves Doombringer, Mira, Bob, Tok, Lia, …); there are no BattleTags or Discord IDs on the
boards.
