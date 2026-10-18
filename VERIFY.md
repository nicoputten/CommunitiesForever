# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V30 | Is the left-to-right tree order the classic one for other classes too? (CF-18; verified for Warrior) | On a non-Warrior character with talents: `/cf self` shows `talents: <tree> N / <tree> N / <tree> N`. Check that the points sit under the right tree names (e.g. a Holy Paladin has its points under Holy). | open |
| V35 | Which events tell what you did, for the activity feed? | `/fp feed` (stays on after `/reload`), then play normally: enter and leave a dungeon, kill a boss, join a group, queue and play a battleground, turn in a quest, level up, gain a profession point, die once. `/fp feed off` afterwards and send the `FEED` lines: `ENCOUNTER_END`/`BOSS_KILL` args per boss, `instance ... type` (party/raid/pvp) from `GetInstanceInfo`, the group members with GUIDs, and the battleground status and winner. | open |


## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-17 Alts outside the community (round 3)
Round 2 passed. One fix left:

| Step | Expected | Status |
|---|---|---|

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
| Share more than 5 quests (or `/cf debugon`) | 5 quest lines, then a `Show all N` link; clicking it lists every quest, `Show fewer` folds it back. | open |
| Abandon or turn in the shared quest | Within ~10 s it disappears from the card (the card says `No shared quests.` when none are left). | open |
| Turn in or abandon your last quest | Your stored quests become empty (`/dump` step above shows `{}`) and the quest disappears for the friend. | open |
| `/reload` right after login with quests in the log | The stored quests never become empty for a moment (`/cf self` version does not change without a quest change). | open |
| Open a friend's person card (or Debug Friend's) | `Shared quests (N)` over all their characters: per quest the title, then `Them <their characters>   You <yours>`. Not on your own person card. | open |
| Open your own character card | No Shared quests section. | open |
| Log in on an alt with other quests | Quests shared with that alt appear too; the main's quests stay as of its last login. | open |
| Without a friend: `/cf debugon`, open `/cf` | A `Debug Friend` with `Debug Character` appears in the tree with the dungeon icon; its card shows up to 6 of your current character's quests plus `Debug: Into the Deeps` under Blackfathom Deeps, and `Show all 7`. `Debug Alt` (Warrior, offline) shares 2 of them plus the dungeon quest. `/cf debugoff` or `/reload` removes it; nothing is saved or synced. | open |

### CF-22 Activity feed
Copy the build into AddOns. The other steps passed (levels, quests per zone, profession ranks, day change, sync to a friend, share off).

| Step | Expected | Status |
|---|---|---|
| `/cf` | Text tabs `Friends` (gold, active) and `Activity` (grey) above the window content; no tab frame, only the tree's own box. Hovering a tab highlights it. Hovering a tree row shows no tooltip box. | open |
| `/cf debugon`, click **Activity** | One box. Today: `Debug Friend on Debug Character and 1 more character`, below it `27 to 30 · Engineering reached Expert · learned Mining   Show all (2)` with `Show all (2)` in blue and the row highlighting on hover. Clicking it lists every part on its own line (`27 to 30`, `Engineering reached Expert`, `learned Mining`, `questing in Ashenvale, Stonetalon Mountains +1 zone (10)`), then `on Debug Alt` with `questing in Durotar (2)` below it, then `Show less`. Yesterday: `Debug Friend on Debug Alt`, `reached 20 · questing in Barrens (4)`. The `Friends` tab lines up with the text inside the box. | open |
