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

### CF-11 Sync
Needs a friend (e.g. Sjaakovich) running this build, both in the selected community and online in Forever. In `/cf people`, characters that came from your friend's addon say `via record`.

| Step | Expected | Status |
|---|---|---|
| Both log in. After ~10 s, `/cf people` and `/cf` | Your friend's community characters are listed under them, including alts they are not on right now (`via record`), with class color, level, item level and professions. | open |
| Friend levels up (or gains a profession point, or swaps gear) | Within ~10 s your window shows the new value without `/reload` (5 s debounce + messages). | open |
| Friend logs in on a community alt you have never seen online | The alt is already listed under them (from the record) and now shows online. | open |
| Friend invites one of their alts to the community | Within ~10 s the alt appears under them on your side. | open |
| Friend `/cf sync` | Nothing changes and no errors (you already have their version). | open |
| `/reload` on your side, `/cf people` | Your friend's characters are still there (stored records survive reloads). | open |
| Friend has an alt that is not in the community | It does not appear on your side (only community members are sent). | open |
