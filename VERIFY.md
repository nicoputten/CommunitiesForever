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
| V21 | `C_CreatureInfo.GetClassInfo(classID)` returns `classFile`? (class colors for Unlinked rows) | `/dump C_CreatureInfo.GetClassInfo(8)` (expect classFile "MAGE") | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-12 Main window
| Step | Expected | Status |
|---|---|---|
| `/cf` | Window "CommunitiesForever" opens (same style as `/cf settings`). `/cf` again closes it. `/cf help` prints the command list. | open |
| Minimap button | Button visible. Hover: tooltip with the number of friends online in Forever. Left-click toggles the window, right-click opens settings. | open |
| `/cf settings` → untick "Show minimap button", `/reload` | Button stays hidden. Tick it again: button is back. | open |
| Window content with your community selected | "People" heading; per person a header `- ● Name (BattleTag) - on <character>` (green dot online, grey offline; "- you" for you). Under it two-line character rows: class-colored name, Lvl, iLvl, Online - zone / Seen … ago; second line professions and realm. "Unlinked" heading with community-only rows if any. Status bar: `N people, M unlinked`. | open |
| Click a person header | Their characters collapse (`+`). Click again: expanded (`-`). Collapse one, `/reload`, open: still collapsed. | open |
| Move and resize the window, close, `/reload`, `/cf` | Same position and size. | open |
| With the window open, a friend logs in/out or switches character | Window updates by itself within ~2 s. | open |
| Clear the selection (select your test community and leave it), `/cf` | Window shows "Select a community in settings (/cf settings)." | open |
| A community with only you linked | "No linked friends yet." under People. | open |
| Unlinked rows (V21) | Names are class-colored too. | open |
