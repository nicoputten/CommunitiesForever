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

### CF-12 Main window (new layout, draft B)
The first-round list layout passed; the window is now a tree on the left and a detail card on the right.

| Step | Expected | Status |
|---|---|---|
| `/cf` | Left: people with a green/grey dot and their display name (`(you)` for you), each expanded to class-colored characters with level; `Unlinked` at the bottom if any. Right: the first person is selected. Status bar `N people, M unlinked`. | open |
| Click a person | Right: big display name, BattleTag in grey, dot + `Online on <class-colored character>` or `Offline`, a "Characters" list (name, level, Online / Seen … ago). | open |
| Click a character in that list, or in the tree | Right: class-colored name, `Class  -  Owner  -  Online in <zone>` / `Offline`, three boxes Level / Item level / Last seen, "Professions" with `rank / max` and a green bar. | open |
| Collapse a person in the tree, select something, drag the tree border wider, `/reload`, `/cf` | Same person collapsed, same selection, same tree width. A friend who is new to the list starts expanded. | open |
| Readability | Text is clearly larger than before. Tell me what still feels too small or crowded. | open |
| A friend logs in/out while the window is open | Their dot and status update by themselves within ~2 s; your selection stays. | open |
| Play character A, log out, log in on B, `/cf`, select A | Last seen `just now` / `N min ago` (V22). | open |
| Nothing selected, exactly one character community, `/reload` | Chat: `Showing community <name>. Change it with /cf settings.`, window shows it. | open |
| Nothing selected, two or more communities: join or create a new character community | The new one gets selected, same chat line. | open |
| No community selected | Window shows `Select a community in settings (/cf settings).` | open |
