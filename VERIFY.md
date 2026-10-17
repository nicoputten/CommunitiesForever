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

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-12 Main window (round 4: screenshot review)
| Step | Expected | Status |
|---|---|---|
| Character card of a character with many professions, then one with few | "Talents" starts at the same height as "Professions" in both cases. | open |
| Tree | Character names are the regular text size (not small), also after collapsing/expanding and scrolling. Each person shows their character count in grey (`Sjaakovich  3`). Green dots are slightly bigger (14 px). The character you are on has a grey `(you)` after its level. | open |
| Bottom of the window | No status bar text any more; the Close button is still there. | open |
| Character card, offline friend character | Subtitle `Offline - last seen in <zone>` (or `Offline`), without a time; the time is only in the "Last seen" value. | open |
| Character card, one of your own other characters | Subtitle `Offline - last played in <zone>`, value caption "Last played". In your person card the list says `Played N min ago`. | open |
| Section titles | "Characters", "Professions", "Talents" are left-aligned gold text without lines. | open |
| Profession bars | Bars fill most of the Professions column instead of a short fixed width. Resize the window and reselect the character: bars follow the new width. | open |
