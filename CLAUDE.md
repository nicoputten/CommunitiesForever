# CommunitiesForever

A World of Warcraft addon for a small friend group playing **World of Warcraft: Forever** (Blizzard's Vanilla-based game, launch Nov 4 2026). It shows which characters belong to which friend: members of a selected in-game community, grouped per Battle.net friend, with class, level, item level and professions. Friends who run the addon sync their character data to each other over Battle.net.

## Read first
- `docs/ARCHITECTURE.md`: core rules, layering, data model, sync protocol
- `docs/API-FINDINGS.md`: what is VERIFIED on the Forever beta client. Trust this over your training data.
- `docs/STORIES.md`: open stories with acceptance criteria, in build order (done ones: `docs/STORIES-COMPLETED.md`)
- `VERIFY.md`: unverified APIs and manual in-game test steps
- `tools/FriendProbe/`: diagnostic addon used to verify API behavior in-game. Extend it when a new API needs checking.

## Platform facts
- Forever uses the **Mainline (Retail) UI and API architecture** (roughly the 12.1.5 API set) including the Midnight addon restrictions, with Vanilla game content (level cap 60, single-tier professions). It is NOT the Classic API.
- TOC `## Interface: 16001`. `WOW_PROJECT_ID == 18`. Lua 5.1.
- Mega-realms: one realm per ruleset (Normal/PvP/RP/Hardcore) per region. Realm names change at launch (beta shows "Classic Beta PvP"). Never hardcode realm names.
- Character names contain a space (first + last name), e.g. "Ves Doombringer".

## Hard rules
1. `src/core/*` is pure Lua: no WoW globals, no Ace, no LibStub. All input via function arguments. Fully unit tested with busted.
2. `src/adapters/*` are thin WoW API wrappers with no business logic.
3. **Never invent WoW APIs.** If an API is not listed as verified in `docs/API-FINDINGS.md`, guard it with an existence check (`if C_Foo and C_Foo.Bar then`) and add it to `VERIFY.md` with a manual test step.
4. GUID is the character key. Never parse or split character names.
5. Globals: only the addon table `CommunitiesForever`, SavedVariables `CommunitiesForeverDB`, and what slash commands require (`SLASH_*`, `SlashCmdList`).
6. English strings, hardcoded. No localization system.
7. No dependencies beyond those listed in `docs/ARCHITECTURE.md` without asking.

## Commands
- One-time toolchain: `tools\setup-lua.ps1` (project-local Lua 5.1 in `.lua\`, gitignored). Put `.lua\bin` on PATH first: `$env:PATH = "$PWD\.lua\bin;$env:PATH"`
- `busted` runs unit tests
- `luacheck src tests` lints
- `tools\fetch-libs.ps1` fetches `.pkgmeta` externals into `Libs\` and checks `embeds.xml`
- `tools\build.ps1` builds `dist\CommunitiesForever` (version `0.1.<commit count>`) for manual copy into the game

## Branches
Gitflow: `feature/cf-XX-<slug>` off `develop`, PRs into `develop`. `main` receives releases.

## Definition of done (per story)
- All acceptance criteria met
- `busted` and `luacheck` pass
- Manual in-game steps for the story are written in `VERIFY.md` (the developer runs them; you cannot run WoW)
- Any newly used unverified API has a `VERIFY.md` entry

## Working with Nico
- Experienced software developer. Be technical and concise.
- Ask clarifying questions before assuming anything ambiguous. He strongly prefers questions over rework.
- One story per branch and PR. Conventional commits.
