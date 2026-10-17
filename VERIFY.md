# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V9 | Character names with last names: any API returning them differently (e.g. hyphenated)? | watch during development | open |
| V23 | Which quest log API and events does Forever have, and how big is the quest log? (for CF-19, can be checked any time) | `/dump C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries(), GetNumQuestLogEntries and GetNumQuestLogEntries()` and `/dump C_QuestLog.GetInfo and C_QuestLog.GetInfo(1)`. Events: `/dump C_EventUtils.IsEventValid("QUEST_ACCEPTED"), C_EventUtils.IsEventValid("QUEST_TURNED_IN"), C_EventUtils.IsEventValid("QUEST_REMOVED"), C_EventUtils.IsEventValid("QUEST_LOG_UPDATE")`. Log size: `/dump C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()` | open |
| V20 | Which talent API does Forever have? (for CF-18, can be checked any time) | `/dump GetNumTalentTabs and GetNumTalentTabs(), GetTalentTabInfo and GetTalentTabInfo(1)` and `/dump C_ClassTalents ~= nil, C_Traits ~= nil, GetSpecialization ~= nil`. Also: which event fires after spending a talent point (`CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`)? `/dump C_EventUtils.IsEventValid("CHARACTER_POINTS_CHANGED"), C_EventUtils.IsEventValid("PLAYER_TALENT_UPDATE"), C_EventUtils.IsEventValid("TRAIT_CONFIG_UPDATED")` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

None open. CF-01, CF-03, CF-05 to CF-08, CF-10 and CF-12 passed; CF-09 is unit tested only.
