# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V2 | Real `BNSendGameData` payload limit | FriendProbe `/fp big N` with receiver logging | open (3500 chunk assumed safe) |
| V3 | Is addon BNet messaging restricted in instances or combat? | ping during combat / in dungeon | open |
| V5 | `CreateScrollBoxListLinearView` available? (`ScrollUtil` verified) | `/dump CreateScrollBoxListLinearView ~= nil` | open |
| V6 | `TooltipDataProcessor.AddTooltipPostCall` + `Enum.TooltipDataType.Unit` available? (`TooltipDataProcessor` verified) | `/dump TooltipDataProcessor.AddTooltipPostCall ~= nil, Enum.TooltipDataType.Unit` | open |
| V7 | First Aid's `skillLine` ID (verified: First Aid is in `GetProfessions()` slot 3) | `/cf self` on that character, read the `[id]` after First Aid | open |
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V9 | Character names with last names: any API returning them differently (e.g. hyphenated)? | watch during development | open |
| V13 | `C_EventUtils.IsEventValid` exists? | `/dump C_EventUtils and C_EventUtils.IsEventValid("PLAYER_LEVEL_UP")` (expect true) | open |
| V14 | `C_Timer.NewTimer` exists? (the gear step works either way; without it there is no debounce) | `/dump C_Timer.NewTimer ~= nil` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-03 Self snapshot
Use `/cf self` to check the record. It prints a fixed, sorted summary: `version`, then per character `updated Ns ago (timestamp)` and the professions.
(`/dump` prints table keys in hash order. That order changes whenever a character is re-stored, so `updatedAt` moves around between dumps.)

| Step | Expected | Status |
|---|---|---|
| `/cf self`, gain a profession skill point, `/cf self` again | Second output: that profession's rank is higher, `version` is higher, the character shows `updated` a few seconds ago. | open (retest with `/cf self`) |
| Log out to the character screen, log in on a different character (alt), `/cf self` | Header says `2 character(s)`; both the alt and the first character are listed, each with its own level/professions. Log back on the first character: still 2, nothing lost. | open |
