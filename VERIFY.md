# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V30 | Is the left-to-right tree order the classic one for other classes too? (CF-18; verified for Warrior) | On a non-Warrior character with talents: `/cf self` shows `talents: <tree> N / <tree> N / <tree> N`. Check that the points sit under the right tree names (e.g. a Holy Paladin has its points under Holy). | open |
| V31 | Does `C_QuestLog.GetQuestTagInfo(questID)` return `tagID` 81 (Dungeon) / 62 (Raid) for dungeon and raid quests? (CF-19; a fallback list of dungeon names covers quests under a dungeon header) | With a dungeon quest in the log (e.g. a Blackfathom Deeps quest), `/dump C_QuestLog.GetQuestTagInfo(<questID>)` (questID from `/fp quests`). Expected a table with `tagID = 81`. Also try a normal quest (expected nil). | open |
| V32 | Does the `Dungeon` atlas exist and look like the dungeon entrance map icon? (CF-19) | `/dump C_Texture.GetAtlasInfo("Dungeon")` returns a table; `/run print("|A:Dungeon:14:14|a")` shows the icon in chat. If it is missing, the addon shows a gold `[D]` instead. | open |


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

### CF-15 Login notifications
Needs a friend linked to you in the community (they do not need the addon).

| Step | Expected | Status |
|---|---|---|
| Friend logs in to Forever while you are online | Chat: `CommunitiesForever: Sjaak is online on Garraka Doombringer (Mage 11)`. | works |
| Friend switches to another character | Chat line again with the new character (if more than 30 s since the last one). | works |
| Friend logs out and back in within 30 s | No second line. | works |
| You log in while the friend is already online | No line for them. | works |
| `/cf settings` → untick "Login notifications", friend logs in again | No line. | works |

Found a bug  that a friend logged off  and it shows that the account is offline but character is still online? even after 5min
### CF-16 Level-up announcements
Needs a friend running this build, linked to you in the community.

| Step | Expected | Status |
|---|---|---|
| Friend levels up while you are both online | Within ~10 s: `Sjaak's <character> reached level N` in your chat. | open |
| A friend's level-up older than 15 minutes (e.g. arriving through relay later) | No line. | open |
| `/cf settings` → untick "Announce friends' level-ups", friend levels up | No line. | open |

### CF-19 Shared quests
Needs a friend running this build, linked to you in the community.

| Step | Expected | Status |
|---|---|---|
| Log in, `/dump CommunitiesForeverDB.global.self.chars[UnitGUID("player")].quests` | Your quest log keyed by questID, each with `title`, `area` (the log header) and `dungeon`. Dungeon quests (e.g. Blackfathom Deeps) have `dungeon = true`. | open |
| You and the friend both accept the same quest (on any characters) | Within ~10 s the friend's character card shows `Shared quests (N)` with the quest under its area and your character's name class-colored. | open |
| Make progress on that quest (kill/loot something) | No new sync: `/cf self` shows the same version as before. | open |
| Share a dungeon quest | The dungeon area is listed first with the dungeon icon and `Dungeon`; the friend's character in the tree gets the dungeon icon after its level. | open |
| Share more than 5 quests | 5 quest lines, then `+N more`. | open |
| Abandon or turn in the shared quest | Within ~10 s it disappears from the card (the card says `No shared quests.` when none are left). | open |
| Open your own character card | No Shared quests section. | open |
| Log in on an alt with other quests | Quests shared with that alt appear too; the main's quests stay as of its last login. | open |
