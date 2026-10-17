# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V1 | Does `GetAverageItemLevel()` exist in Forever and return equipped ilvl? | `/dump GetAverageItemLevel()` | open |
| V2 | Real `BNSendGameData` payload limit | FriendProbe `/fp big N` with receiver logging | open (3500 chunk assumed safe) |
| V3 | Is addon BNet messaging restricted in instances or combat? | ping during combat / in dungeon | open |
| V4 | Do Ace3, LibDBIcon load cleanly under TOC 16001? | load addon, check errors | open |
| V5 | `ScrollBox` / `ScrollUtil` / `CreateScrollBoxListLinearView` available? | `/dump ScrollUtil ~= nil` | open |
| V6 | `TooltipDataProcessor.AddTooltipPostCall` + `Enum.TooltipDataType.Unit` available? | `/dump TooltipDataProcessor ~= nil` | open |
| V7 | Is First Aid a profession in Forever, and in which `GetProfessions()` slot? | char with First Aid, `/fp info` | open |
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V9 | Character names with last names: any API returning them differently (e.g. hyphenated)? | watch during development | open |
| V10 | `C_AddOns.GetAddOnMetadata(name, "Version")` exists and returns the TOC version? | `/dump C_AddOns.GetAddOnMetadata("CommunitiesForever", "Version")` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-01 Scaffold and tooling
| Step | Expected | Status |
|---|---|---|
| Run `powershell -ExecutionPolicy Bypass -File tools\build.ps1`, then copy `dist\CommunitiesForever` into the Forever client's `Interface\AddOns\`. | Build prints `Built CommunitiesForever 0.1.N`. | open |
| Log in, open the AddOns list on the character screen. | CommunitiesForever is listed and enabled, not "out of date". | open |
| In game, with Lua errors shown (`/console scriptErrors 1`), `/reload`. | No Lua errors from CommunitiesForever or its libs (also covers V4). | open |
| `/cf version` | Prints `CommunitiesForever: Version 0.1.N` matching the build (covers V10). | open |
| `/cf` and `/cf foo` | Print the command list. | open |
| `/reload`, then `/dump CommunitiesForeverDB.global.schemaVersion` | `1`. | open |
