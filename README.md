# CommunitiesForever

A World of Warcraft addon for a small group of friends playing **World of Warcraft: Forever** (Vanilla content on
the Mainline client, TOC 16001). It shows which characters in a shared in-game community belong to which friend,
with class, level, item level, professions, talents and quests, and keeps it in sync between friends who run the
addon, over Battle.net and the community.

## What it does
- **Friends:** every friend with all their characters, who is online on which one, their professions, talents and
  the quests you share.
- **Activity:** what everyone did in the last 7 days: levels, quests, professions, dungeons and battlegrounds,
  played together or alone.
- **Dungeons:** the dungeons in range of your character, a suggested group from your friends, planned runs from the
  website (through the CommunitiesForever uploader) with reminders and sign-ups, and "Who's up for it?" asks.
- **Doomsday:** daily and weekly goals for the whole group, points for PvE and PvP, a streak, the crown for the
  first to finish, a board, a weekly ladder and feats (rules: `docs/DOOMSDAY.md`).

`/cf` opens the window, `/cf help` lists the commands. Install it from CurseForge or Wago Addons.

## Development
- Read first: `CLAUDE.md` (rules), `docs/ARCHITECTURE.md` (layers, data model, sync), `docs/SYNC.md` (wire
  reference), `docs/API-FINDINGS.md` (what is verified on Forever), `docs/STORIES.md` (open stories) and
  `VERIFY.md` (open in-game checks).
- Toolchain: `tools\setup-lua.ps1` (a project-local Lua 5.1 with busted and luacheck in `.lua\`), then
  `$env:PATH = "$PWD\.lua\bin;$env:PATH"`.
- `tools\fetch-libs.ps1` fetches the libraries of `.pkgmeta` into `Libs\`.
- `busted` runs the tests, `luacheck src tests` the linter, `tools\build.ps1` builds `dist\CommunitiesForever`.
- Releases: a `v*` tag on `main` (see `CLAUDE.md` "Releases" and `CHANGELOG.md`).

## License
MIT, see `LICENSE`.
