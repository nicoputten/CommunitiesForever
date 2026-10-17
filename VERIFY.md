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
| V20 | Which talent API does Forever have? (for CF-18, can be checked any time) | `/dump GetNumTalentTabs and GetNumTalentTabs(), GetTalentTabInfo and GetTalentTabInfo(1)` and `/dump C_ClassTalents ~= nil, C_Traits ~= nil, GetSpecialization ~= nil`. Also: which event fires after spending a talent point (`CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`)? `/dump C_EventUtils.IsEventValid("CHARACTER_POINTS_CHANGED"), C_EventUtils.IsEventValid("PLAYER_TALENT_UPDATE"), C_EventUtils.IsEventValid("TRAIT_CONFIG_UPDATED")` | open |
| V22 | Does `PLAYER_LOGOUT` fire on logout / character switch early enough to be saved? | CF-12 "last seen" step below | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-12 Main window (retest after feedback)
All first-round steps passed. These cover the fixes from your feedback.

| Step | Expected | Status |
|---|---|---|
| `/cf` | Person headers show only the display name (no BattleTag), `(you)` for you, and `on <character>` with that character class-colored. A blank line between people. No realm on character rows. | open |
| Play character A for a bit, log out to the character screen, log in on character B, `/cf` | Character A shows `Seen just now` / `Seen N min ago` (when you logged out), not hours ago (V22). | open |
| With nothing selected and exactly one character community: `/reload` | Chat: `Showing community <name>. Change it with /cf settings.`; it is selected. | open |
| With nothing selected and two or more communities: join (or create) a new character community | The new community gets selected with the same chat line. | open |
| With a community selected, join another one | Selection does not change. | open |
