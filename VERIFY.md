# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V25 | Do the invite code functions exist? (CF-21) | `/dump C_Club.RedeemTicket ~= nil, C_Club.RequestTicket ~= nil, C_Club.CreateTicket ~= nil, C_Club.GetMemberInfoForSelf ~= nil` | open |
| V27 | Is a community invite link printed by an addon clickable, and does it open Blizzard's join dialog? (CF-21: chat link instead of joining directly) | 1. `/dump GetClubTicketLink ~= nil`. 2. Copy the code from your invite link (the part after the last `/`). 3. On an alt that is NOT in the community, type this one line (replace CODE): `/run local c="CODE" print(GetClubTicketLink and GetClubTicketLink(c,"Forever Friends",1) or ("\124cffffd100\124HclubTicket:"..c.."\124h[Join Forever Friends]\124h\124r"))` 4. A link appears in chat. Click it: does Blizzard's community invite window open, and does its Join button work without a "blocked" warning? | open |
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

### CF-21 Join with a shared invite link
V26 answered: `C_Club.RedeemTicket` is blocked for addons, so the Join button cannot work. Do not click it again. Next: V27 (chat link). The steps below are on hold until V27 is known.

| Step | Expected | Status |
|---|---|---|
| As owner/leader/moderator: `/cf settings` | A "Community invite link" field. As a normal member the field is not shown. | open |
| Create an invite link (Communities window, invite, link) and paste it into the field | Saved; `/cf settings` shows the code. Typing nonsense prints `That doesn't look like a community invite link or code.` | open |
| Log in on an alt that is not in the community, `/cf` (after ~10 s of sync with a friend online, or on the same account right away) | The "isn't a member" message plus a `Join <community>` button. | open |
| Click `Join <community>` | The alt joins; the window switches to the community. If instead you see `Joining didn't work...` or nothing happens, note what chat/errors show (this answers V26). | open |
| Clear the field (empty) | The Join button disappears for others after the next sync. | open |
