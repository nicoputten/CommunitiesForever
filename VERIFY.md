# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V1 | Does `GetAverageItemLevel()` exist in Forever and return equipped ilvl? | `/dump GetAverageItemLevel()` | it shows [1]=1.5625,[2]=1.5625,[3]1.5625 |
| V2 | Real `BNSendGameData` payload limit | FriendProbe `/fp big N` with receiver logging | open (3500 chunk assumed safe) |
| V3 | Is addon BNet messaging restricted in instances or combat? | ping during combat / in dungeon | open |
| V4 | Do Ace3, LibDBIcon load cleanly under TOC 16001? | load addon, check errors | verified: no errors (CF-01) |
| V5 | `ScrollBox` / `ScrollUtil` / `CreateScrollBoxListLinearView` available? | `/dump ScrollUtil ~= nil` |returned true |
| V6 | `TooltipDataProcessor.AddTooltipPostCall` + `Enum.TooltipDataType.Unit` available? | `/dump TooltipDataProcessor ~= nil` | returned true |
| V7 | Is First Aid a profession in Forever, and in which `GetProfessions()` slot? | char with First Aid, `/fp info` | its in |
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V9 | Character names with last names: any API returning them differently (e.g. hyphenated)? | watch during development | open |
| V10 | `C_AddOns.GetAddOnMetadata(name, "Version")` exists and returns the TOC version? | `/dump C_AddOns.GetAddOnMetadata("CommunitiesForever", "Version")` | verified: `/cf version` prints the build version (CF-01) |
| V11 | `UnitRace("player")` 3rd return is raceID; `UnitLevel`, `UnitFactionGroup` return level and `"Horde"`/`"Alliance"`? | `/dump UnitRace("player")`, `/dump UnitLevel("player"), UnitFactionGroup("player")` | open |
| V12 | Do `PLAYER_LEVEL_UP` (arg 1 = new level), `SKILL_LINES_CHANGED` (on profession skill-up and learning), `PLAYER_EQUIPMENT_CHANGED` fire in Forever? | covered by the CF-03 steps below | open |
| V13 | `C_EventUtils.IsEventValid` exists? | `/dump C_EventUtils and C_EventUtils.IsEventValid("PLAYER_LEVEL_UP")` (expect true) | open |
| V14 | `C_Timer.NewTimer` exists and returns a timer with `:Cancel()`? | `/dump C_Timer.NewTimer ~= nil` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-01 Scaffold and tooling
| Step | Expected | Status |
|---|---|---|
| Run `powershell -ExecutionPolicy Bypass -File tools\build.ps1`, then copy `dist\CommunitiesForever` into the Forever client's `Interface\AddOns\`. | Build prints `Built CommunitiesForever 0.1.N`. | shows correct |
| Log in, open the AddOns list on the character screen. | CommunitiesForever is listed and enabled, not "out of date". | shows correct |
| In game, with Lua errors shown (`/console scriptErrors 1`), `/reload`. | No Lua errors from CommunitiesForever or its libs (also covers V4). | no errors |
| `/cf version` | Prints `CommunitiesForever: Version 0.1.N` matching the build (covers V10). | tes |
| `/cf` and `/cf foo` | Print the command list. | yes |
| `/reload`, then `/dump CommunitiesForeverDB.global.schemaVersion` | `1`. | 1 |

### CF-03 Self snapshot
Tip: `/dump CommunitiesForever.db.global.self` shows the live record (SavedVariables on disk only update on logout or `/reload`).

| Step | Expected | Status |
|---|---|---|
| Install a fresh build, log in, `/dump CommunitiesForever.db.global.self` | `battleTag` is your BattleTag; `version` is a server timestamp; `chars[<your GUID>]` has name, classFile, raceID, level, faction, realm, ilvl (whole number), professions keyed by skillLine ID (e.g. `[186]` Mining) with name/rank/max, and updatedAt. | open |
| Note `version`, `/reload`, dump again | `version` and `updatedAt` unchanged (no change, no bump). | open |
| Gain a profession skill point (or learn a profession) | Within a second the profession's rank or entry updates and `version` increases. | open |
| Swap a weapon or armor piece with a different item level | About 2 s later `ilvl` updates and `version` increases. Swapping several items quickly bumps once. | open |
| Level up | `level` shows the new level right after the ding, `version` increases. | open |
| Log in on an alt, dump | Alt added under its own GUID; first character still present. | open |
| Character with First Aid (V7) | First Aid appears under its skillLine ID. Note the ID here. | open |
