# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
One run answers most of them: copy `tools/FriendProbe` into `Interface\AddOns` (replace the old one), `/fp start`, then `/reload` and send `WTF\Account\<account>\SavedVariables\FriendProbe.lua`. `/fp start` clears the log first and switches on the V35 feed logging (stays on; `/fp feed off`).

| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp start` on two clients: compare the `club` lines under V8 COMMUNITIES. | open |
| V30 | Is the left-to-right tree order the classic one for other classes too? (CF-18; verified for Warrior) | On a non-Warrior character with talents: `/fp start` (V30 TALENTS lists the nodes with points left to right, with their spells) and `/cf self` (`talents: <tree> N / <tree> N / <tree> N`). The points should sit under the right tree names (e.g. a Holy Paladin has its points under Holy). | open |
| V35 | Which events tell what you did in dungeons and battlegrounds? (CF-23 is built on the Mainline signatures; this checks them) | `/cf activity debug` (stays on after `/reload`; `/fp start` also logs the same events), then in a group with a community member: enter a dungeon, kill a boss, leave after 10 min; queue and finish a battleground. Send the `[activity]` lines. Check: `instance:` inside shows `<name>, party` (raid, pvp); `ENCOUNTER_END` passes `encounterID, name, difficulty, groupSize, 1` on a kill (`BOSS_KILL` too?); `group:` counts the other players and the community companion; at the battleground end `PVP_MATCH_COMPLETE` passes the winner (0 Horde / 1 Alliance) and `battleground ended:` says `won true` when your side won. Last line: `left ...: recorded`. | open |
| V41 | Does a closed chat tab keep its name, with `shown` and `docked` off? (CF-26 feedback: Create did nothing after closing the Community tab) | Close the Community tab (right-click the tab, Close Window), then `/fp start`: under V41 CHAT WINDOWS the closed window still has its name, with `shown` false/nil and `docked` nil. Then Create in `/cf setup` (Community chat step) makes the tab again. | open |
| V46 | Which dungeons does the Forever client know, with which level ranges? (CF-24: Forever's new dungeons, e.g. Excavation Site: Wetlands, are missing in the Dungeons tab) | `/fp start`: V46 GROUP FINDER lists the Group Finder categories and every activity with all its fields (name, level range, map). V46 DUNGEON FINDER lists entries beyond the Vanilla list. Expected: Excavation Site: Wetlands with 26 to 33 among the activities. | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-23 Dungeons, raids, battlegrounds and playing together
Needs a friend running this build in the same community. `/cf activity debug` on shows why something is or is not recorded (V35). `/cf debugon` shows sample lines (a raid, battlegrounds and a shared dungeon line) without playing.

| Step | Expected | Status |
|---|---|---|
| `/cf debugon`, Activity tab | "Show all" on Debug Friend's line lists Debug Alt with `raided Molten Core (4 bosses)` and `2 battlegrounds (1 won)` first; a line `<you> and Debug Friend together` with `ran Blackfathom Deeps ×2` (the `×` shows, not a box). `/cf debugoff`. | open |
| Enter a dungeon, `/cf activity` | `In <dungeon> (party) for 0 min, 0 bosses killed.` | open |
| Alone: kill a boss, leave after 10+ min | Your Activity line today starts with `ran <dungeon>`. | open |
| Leave a dungeon before 10 min, or without a boss kill | No line for it (debug: `not recorded, ...`). | open |
| `/reload` inside a dungeon, then kill a boss and leave after 10+ min | Recorded: the run survived the reload. | open |
| With the friend in one group: run a dungeon, kill a boss, leave after 10+ min | Both clients (after ~1 min sync): one line `<you> and <friend> together` with `ran <dungeon>`, and the run is not on your own lines. | open |
| With a community member who does not run the addon and is not your Battle.net friend | `ran <dungeon> with <their character name>` on your line. | open |
| Finish a battleground (stay until the end) | `1 battleground (won)` or `(lost)`, matching the result. Leaving early: no line. | open |

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
| A Battle.net friend logs off (fix for the bug found: account offline but character still online) | Within a few seconds their account and all their characters show offline (no green dot), also when the Communities window still lists them as online. | open |
| The friend switches to another character | Only the character they are on shows online. | open |

