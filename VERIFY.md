# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V23 | Which quest log API and events does Forever have, and how big is the quest log? (for CF-19, can be checked any time) | `/dump C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries(), GetNumQuestLogEntries and GetNumQuestLogEntries()` and `/dump C_QuestLog.GetInfo and C_QuestLog.GetInfo(1)`. Events: `/dump C_EventUtils.IsEventValid("QUEST_ACCEPTED"), C_EventUtils.IsEventValid("QUEST_TURNED_IN"), C_EventUtils.IsEventValid("QUEST_REMOVED"), C_EventUtils.IsEventValid("QUEST_LOG_UPDATE")`. Log size: `/dump C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()` | open |
| V20 | Which talent API does Forever have? (for CF-18, can be checked any time) | `/dump GetNumTalentTabs and GetNumTalentTabs(), GetTalentTabInfo and GetTalentTabInfo(1)` and `/dump C_ClassTalents ~= nil, C_Traits ~= nil, GetSpecialization ~= nil`. Also: which event fires after spending a talent point (`CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`)? `/dump C_EventUtils.IsEventValid("CHARACTER_POINTS_CHANGED"), C_EventUtils.IsEventValid("PLAYER_TALENT_UPDATE"), C_EventUtils.IsEventValid("TRAIT_CONFIG_UPDATED")` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-17 Alts outside the community (round 3)
Round 2 passed. One fix left:

| Step | Expected | Status |
|---|---|---|
| Log in on Marks Man (the alt that showed only "Marks"), then `/cf self` | Shows `Marks Man`. On your friend's side the name updates within ~10 s. `/cf ping` from that alt says `Ping from Marks Man`. | works |

### CF-20 Relay
Needs three Battle.net accounts on this build (A, B, C): relaying always involves three different BattleTags. A is Battle.net friends with both; B and C do not need to be friends with each other. All have a character in the community. Can wait until a third person is available.

| Step | Expected | Status |
|---|---|---|
| A and B online together for ~10 s, then B logs off. Later C logs on while A is online (B stays offline) | Within ~10 s C sees B's community characters under B (not in Unlinked), and B's card says `Updated <time> via <A's name>`. | open |
| B and C not Battle.net friends at all | Same as above: B is shown under his name through A (trust is the community). | open |
| Later B and C are online together (if they are friends) | The `via` line disappears: B's own record replaced the relayed copy. | open |
| B changes something (level up) while A is online and C is offline; then C logs on while B is offline | C gets B's new level through A. | open |
| `/reload` on C | B's relayed data stays. | open |
