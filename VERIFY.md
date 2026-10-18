# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V30 | Is the left-to-right tree order the classic one for other classes too? (CF-18; verified for Warrior) | On a non-Warrior character with talents: `/cf self` shows `talents: <tree> N / <tree> N / <tree> N`. Check that the points sit under the right tree names (e.g. a Holy Paladin has its points under Holy). | open |
| V35 | Which events tell what you did, for the activity feed? | `/fp feed` (stays on after `/reload`), then play normally: enter and leave a dungeon, kill a boss, join a group, queue and play a battleground, turn in a quest, level up, gain a profession point, die once. `/fp feed off` afterwards and send the `FEED` lines: `ENCOUNTER_END`/`BOSS_KILL` args per boss, `instance ... type` (party/raid/pvp) from `GetInstanceInfo`, the group members with GUIDs, and the battleground status and winner. | open |
| V37 | Which community chat functions work for an addon? (CF-25) | Copy the updated `toolsriendprobe`, `/reload`. 1) `/fp chat`: send the log (which functions exist, the community channel name and index, which chat windows show it). 2) `/fp chat watch`, let a friend write in the community chat (or write yourself from another character): send the `chat` lines (is the text `<secret>`?). 3) `/fp chat color` and click the button: do community messages turn orange? 4) `/fp chat tab` and click: does an `fp community` tab appear with only community messages? (close it afterwards: right click the tab, close window). 5) open another chat tab, `/fp chat flash` and click: does the tab with the community chat flash, and do you hear a whisper sound? note any "blocked" message. | open |


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

