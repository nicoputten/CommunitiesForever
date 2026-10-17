# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V2 | Real `BNSendGameData` payload limit | FriendProbe `/fp big N` with receiver logging | open (3500 chunk assumed safe) |
| V3 | Is addon BNet messaging restricted in instances or combat? | ping during combat / in dungeon | open |
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V9 | Character names with last names: any API returning them differently (e.g. hyphenated)? | watch during development | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-08 Linker
CF-08 is pure logic, fully unit tested. `/cf people` shows its result in game: each person with their community characters and how each character was linked (`via self`, `via presence`, `via record`), then the Unlinked characters.
Records from friends (`via record`) only arrive with sync (CF-11), so for now you will see `self` and `presence` links only.

| Step | Expected | Status |
|---|---|---|
| Your community is selected and a friend (e.g. Sjaakovich) is in it and online. `/cf people` | You `[you]` with your community characters (`via self`); the friend with the character they are on (`via presence`), `online on <character>`. | open |
| A community member who is not your Battle.net friend, or a friend's character they have never logged in on while you were online. `/cf people` | That character is listed under `Unlinked:`. | open |
| Friend logs out. Wait ~3 s, `/cf people` | Friend is still listed (presence link is stored) but `offline`, sorted after online people. | open |
