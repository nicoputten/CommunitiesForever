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
| V19 | `BNET_CLIENT_WOW` equals `"WoW"`, and the BNet events exist? | `/dump BNET_CLIENT_WOW, C_EventUtils.IsEventValid("BN_FRIEND_INFO_CHANGED"), C_EventUtils.IsEventValid("BN_FRIEND_ACCOUNT_ONLINE"), C_EventUtils.IsEventValid("BN_FRIEND_ACCOUNT_OFFLINE"), C_EventUtils.IsEventValid("BN_CONNECTED")` (expect `"WoW"` and 4× true) | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-07 Battle.net presence
Needs a Battle.net friend (e.g. Sjaakovich). The friend does not need the addon.
`/cf friends` prints your Battle.net friend count, who is online in Forever (character, class, level, game account, GUID), and the stored presence links (GUID -> BattleTag, last seen).

| Step | Expected | Status |
|---|---|---|
| Friend is logged in to Forever. `/cf friends` | They are listed as online in Forever with their current character; a presence link for that character exists. | open |
| Friend logs out to the character screen or quits. Wait ~3 s, `/cf friends` | They are no longer listed as online. Their presence link is still listed. | open |
| Friend logs in on a different character. Wait ~3 s, `/cf friends` | Listed with the new character; presence links now show both characters under their BattleTag. | open |
| Friend is only in the Battle.net app or another WoW version (Retail/Classic), not Forever. `/cf friends` | Not listed as online in Forever (still counted as a Battle.net friend). | open |
| `/reload`, `/cf friends` | Presence links survive the reload. | open |
