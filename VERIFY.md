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

### CF-12 Main window (round 3)
Everything else in draft B passed. These cover your last feedback.

| Step | Expected | Status |
|---|---|---|
| Tree | The character each person is playing has a green dot in front of it; other characters have none (names stay aligned). | open |
| Character card | Level / Item level / Last seen are plain text (small grey caption, larger value), no box border. Professions and Talents side by side; Talents says "Not available yet." | open |
| A friend in the community walks into another zone, then logs out. Click them | Person card: `Offline - last seen in <zone> on <character>, N min ago`. Their character card: `Offline - last seen in <zone>, N min ago`. | open |
| Same for someone who logged off before you logged in today (no zone seen yet) | `Offline - last seen on <character>, N h ago` or just `Offline`; no error. | open |
