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
| V24 | Do `InCombatLockdown`, `GetTime` and `PLAYER_REGEN_ENABLED` exist? (combat queue and send rate) | `/dump InCombatLockdown ~= nil, GetTime(), C_EventUtils.IsEventValid("PLAYER_REGEN_ENABLED")` | open |
| V23 | Which quest log API and events does Forever have, and how big is the quest log? (for CF-19, can be checked any time) | `/dump C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries(), GetNumQuestLogEntries and GetNumQuestLogEntries()` and `/dump C_QuestLog.GetInfo and C_QuestLog.GetInfo(1)`. Events: `/dump C_EventUtils.IsEventValid("QUEST_ACCEPTED"), C_EventUtils.IsEventValid("QUEST_TURNED_IN"), C_EventUtils.IsEventValid("QUEST_REMOVED"), C_EventUtils.IsEventValid("QUEST_LOG_UPDATE")`. Log size: `/dump C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()` | open |
| V20 | Which talent API does Forever have? (for CF-18, can be checked any time) | `/dump GetNumTalentTabs and GetNumTalentTabs(), GetTalentTabInfo and GetTalentTabInfo(1)` and `/dump C_ClassTalents ~= nil, C_Traits ~= nil, GetSpecialization ~= nil`. Also: which event fires after spending a talent point (`CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`)? `/dump C_EventUtils.IsEventValid("CHARACTER_POINTS_CHANGED"), C_EventUtils.IsEventValid("PLAYER_TALENT_UPDATE"), C_EventUtils.IsEventValid("TRAIT_CONFIG_UPDATED")` | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-10 Transport
Needs a friend (e.g. Sjaakovich) running this build too, both online in Forever. `/cf ping` sends a test message; the other side prints it and answers automatically, then you see the answer. `/cf ping stats` shows counters.

| Step | Expected | Status |
|---|---|---|
| You: `/cf ping` | You: `Ping sent to 1 game account(s).` Friend: `Ping from <your character> (<your BattleTag>), 0 bytes padding.` You: `Pong from <their character> (<their BattleTag>) for 0 bytes.` | open |
| You: `/cf ping 20000` (forces ~6 chunks, sent 0.2 s apart) | Same three lines with `20000 bytes`, within ~3 s. Covers the chunk size (V2): if this fails, try `/cf ping 3000` and tell me which sizes work. | open |
| Start a fight, then `/cf ping` while in combat | Nothing is sent until the fight ends; then the ping goes out and the pong arrives. `/cf ping stats` during the fight shows `queued` > 0. (V24, V3 combat part) | open |
| Inside a dungeon instance: `/cf ping` | Ping and pong arrive (V3 instance part). | open |
| Friend disables the addon (or is online without it), you: `/cf ping` | Only `Ping sent to 1 game account(s).`; no pong, no error on either side. | open |
