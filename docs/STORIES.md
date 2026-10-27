# Backlog

Open stories only, in build order. Done stories move to `docs/STORIES-COMPLETED.md`.
Each story: criteria are testable. "Manual" items go into VERIFY.md.

Build order: CF-38 (recipes) waits for the V60 check at launch (its story is in PR #63).
CF-49 after the web's WEB-47 (Runs v2 data) is merged.

## E14 Planned runs (continued)

### CF-49 Runs v2 in game: level fit and roles
Nico tested Runs on the live site (2026-10-27) and the site moved to "Runs v2" (web repo WEB-47..50, boards `runs-v2-*`): any character can join, the role is picked apart from the character, and full roles get a reserve list. The game follows so it says the same as the site and Discord.
- `src/core`: `levelFit(level, min, max)` with the same kinds and labels as the web's WEB-47 (fits, `+N over`, `carry · +N` from 10 over, `N below`; 6+ below can only answer Maybe) and `rolesFor(class)` (Warrior tank and damage; Paladin and Druid tank, healer and damage; Priest and Shaman healer and damage; Mage, Warlock, Hunter, Rogue damage). Unit tested at every boundary and for every class.
- The Dungeons tab's runs (CF-46) and "what you could fill" use `levelFit`; slots show each sign-up's role, carries and reserves from `Runs.lua` when present.
- Sign up in game (CF-47): any character with its fit tag, then a role the class can play (default the addon's role for that character); a tooLow character only Maybe.
- Compat (rule 8): `Runs.lua` gets `role`, `fit` and the reserve state per answer as optional fields (from the web's WEB-44 feed, written by the uploader); without them the addon behaves as now. A pending answer gets an optional `role`; an older site ignores it, and the web's WEB-43 reads it when present. No stored data is reshaped, so no migration step; no sync message changes meaning (a role in run sync is a new optional field).
- Tests: the fit labels and role lists, slots from a `Runs.lua` with and without roles, a pending answer with a role.
