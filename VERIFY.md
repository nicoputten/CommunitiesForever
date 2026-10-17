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
| V15 | Do the club events exist? | `/dump C_EventUtils.IsEventValid("INITIAL_CLUBS_LOADED"), C_EventUtils.IsEventValid("CLUB_ADDED"), C_EventUtils.IsEventValid("CLUB_REMOVED"), C_EventUtils.IsEventValid("CLUB_UPDATED")` (expect 4× true) | open |
| V16 | Does `AceConfigDialog:AddToBlizOptions` show up in the Forever settings panel? | CF-05 step 2 | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-05 Community selection
For the "gone" steps, use a throwaway test community so you don't leave the real one. Create one: Communities window → `+` → Create a WoW Community.

| Step | Expected | Status |
|---|---|---|
| `/cf settings` | Settings window opens with a "Community" dropdown listing your character communities by name. Your guild is not listed. | open |
| Esc → Options → AddOns tab (V16) | A "CommunitiesForever" entry shows the same Community dropdown. | open |
| Select your real community, `/reload`, `/cf settings` | The same community is still selected. | open |
| Log out completely and back in, 2–3 times | No "community is no longer available" message, selection kept (checks the login timing guard). | open |
| Select the test community, then leave it (Communities window → right-click it → Leave Community) | Chat shows once: `Your community is no longer available. Select one with /cf settings.` `/cf settings` shows nothing selected. | open |
| `/reload` | No message again; still nothing selected. | open |
| Select the real community again | Selected; no message. | open |
