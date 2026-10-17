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
| V18 | Does a member presence or zone change fire a member event, so data updates without our input? | CF-06 first step below | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-06 Member tracking
`/cf members` prints the members of the selected community: name, level, classID, raceID, faction, presence (1 = online, 3 = offline), zone, GUID.
`/cf members` only prints what the addon already has; it does not fetch anything. The header `last change Ns ago` shows when member events last changed the data.

| Step | Expected | Status |
|---|---|---|
| Ask a friend who is in the community to log in, log out or walk into another zone (they do NOT need the addon). Don't run anything for ~5 s, then `/cf members` | Their presence or zone shows the new value, and the header says `last change` a few seconds ago (V18: the client sent a member event and we picked it up by ourselves). | open |
| Switch the selection to another character community, `/cf members` | Lists that community's members (may take a few seconds to load the first time). | open |
