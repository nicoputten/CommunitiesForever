# Revamp design (October 2026)

Design references for the new look of the addon, made with Claude Design. They are **reference mockups**,
not code: the inline styles carry the exact values (colours, sizes, spacing) the in-game kit should copy.
Stories: E13 in `docs/STORIES.md` (CF-39 to CF-44).

| File | What it shows |
|---|---|
| `widget-kit.html` | Can WoW draw this: every design element mapped to the WoW building block (yes / approximately / no), framework advice, in-game sizes, textures to make |
| `friends.html` | Friends tab: searchable list grouped per person, character detail (header, tiles, professions, talents, shared quests), footer |
| `activity.html` | Activity tab: filter chips, feed per day, together lines, and the level-up announcement at the top of the screen |
| `dungeons.html` | Dungeons tab: planned runs and dungeons in range, suggested group as five slots, quests, plan a run |
| `settings-setup.html` | Settings window in groups, and the first-run setup |

**Viewing:** the pages need a local web server (scripts are blocked over `file://`), for example
`python -m http.server` in this folder, then open `http://localhost:8000/friends.html`. `support.js` and
`vendor/` are the design tool's runtime (shared by all five pages), not part of the design.

**Names are made up.** The mockups were drawn with real players and characters; every name, BattleTag and
portrait initial was replaced by an invented gamer tag before they went into the repo (Ashen Pact, Nightfall,
Ironpaw, Thalia Emberfall, Orin Blackwell, ...).

## Decisions (2026-10-27)

- **Own native kit, no AceGUI for the window** (as `widget-kit.html` advises): our own Window, Tabs, ListRow,
  SkillBar, Button, Checkbox, Toast and ClassPortrait on native frames. Ace3 stays for the plumbing (AceAddon,
  AceDB, AceEvent, AceConsole).
- **Fonts bundled:** Marcellus SC, Marcellus and Inter (SIL OFL), with the game font as fallback for
  non-Latin clients. A new dependency under CLAUDE.md rule 7, listed in `docs/ARCHITECTURE.md` "Libraries".
- **Real class icons** in round masks in game, not the initials of the mockups.
- **Activity keeps 7 days** (the mockup's footer says 14). No run durations (not recorded).
- **Setup keeps the optional Community chat step** (CF-30); the mockup's 5 steps did not know it.
- **No probing before launch:** unverified APIs get a VERIFY.md entry and are checked on the live game
  (Nov 2026).

## Where the mockups differ from what the addon does (and what wins)

| Mockup | Addon |
|---|---|
| Esc through `UISpecialFrames` | Our own Esc handler (CF-32): `UISpecialFrames` needs a named global frame (rule 5) |
| Settings: "Receive group asks: popups when a friend looks for a group" | A chat line with a sound, no popup (decided in CF-27) |
| Settings: "Community invite link: paste to join" | Not possible: `C_Club.RedeemTicket` is blocked for addons (V26). Joining stays by clicking the link in chat (CF-21) |
| "Group asks pause during encounters, keystones and PvP matches" | Forever has no keystones; sending waits for the end of combat (outbox, CF-10) |
| Activity "Keeps 14 days", run "1 h 12 min" | 7 days; no durations |
| Setup "Step 1 of 5" | The optional Community chat step stays |
| Main window strata | `DIALOG`, so Blizzard's menus open above it (CF-37) |
