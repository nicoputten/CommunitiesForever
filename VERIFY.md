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
| V17 | Do the member events exist? | `/dump C_EventUtils.IsEventValid("CLUB_MEMBERS_UPDATED"), C_EventUtils.IsEventValid("CLUB_MEMBER_ADDED"), C_EventUtils.IsEventValid("CLUB_MEMBER_REMOVED"), C_EventUtils.IsEventValid("CLUB_MEMBER_PRESENCE_UPDATED"), C_EventUtils.IsEventValid("CLUB_MEMBER_UPDATED")` (expect 5× true) | open |
| V18 | Does a member level-up or zone change update `C_Club.GetMemberInfo` and fire a member event? | CF-06 step 4 | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-06 Member tracking
`/cf members` prints the members of the selected community: name, level, classID, raceID, faction, presence (1 = online, 3 = offline), zone, GUID.
For invite/kick, use the throwaway test community (select it in `/cf settings` first) or an alt of yours.

| Step | Expected | Status |
|---|---|---|
| Select your community, `/cf members` | All members listed, sorted by name, each with a GUID. Matches the Communities window. | open |
| Invite a character (an alt or a friend's) to the selected community, wait ~3 s, `/cf members` | The new member is listed. | open |
| Kick (or have the alt leave) that character, wait ~3 s, `/cf members` | The member is gone. | open |
| A friend in the community logs in/out, levels up or changes zone; wait ~3 s, `/cf members` | presence, level or zone updated (V18). | open |
| Switch the selection to another character community, `/cf members` | Lists that community's members (may take a few seconds to load the first time). | open |
