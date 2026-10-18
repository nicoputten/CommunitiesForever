# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp clubs` on two clients | open |
| V30 | Is the left-to-right tree order the classic one for other classes too? (CF-18; verified for Warrior) | On a non-Warrior character with talents: `/cf self` shows `talents: <tree> N / <tree> N / <tree> N`. Check that the points sit under the right tree names (e.g. a Holy Paladin has its points under Holy). | open |
| V35 | Which events tell what you did in dungeons and battlegrounds? (CF-23 is built on the Mainline signatures; this checks them) | `/cf activity debug` (stays on after `/reload`; `/fp feed` logs the same events), then in a group with a community member: enter a dungeon, kill a boss, leave after 10 min; queue and finish a battleground. Send the `[activity]` lines. Check: `instance:` inside shows `<name>, party` (raid, pvp); `ENCOUNTER_END` passes `encounterID, name, difficulty, groupSize, 1` on a kill (`BOSS_KILL` too?); `group:` counts the other players and the community companion; at the battleground end `PVP_MATCH_COMPLETE` passes the winner (0 Horde / 1 Alliance) and `battleground ended:` says `won true` when your side won. Last line: `left ...: recorded`. | open |
| V40 | Does `SELECTED_CHAT_FRAME` point at the chat tab you are looking at? (CF-25: that tab does not flash) | Select a tab other than General, `/dump SELECTED_CHAT_FRAME:GetName()`. Expected the name of the selected tab (e.g. `ChatFrame3`). Without it every tab with the community chat flashes, the selected one too. | open |


## Manual test steps per story

### CF-26 Onboarding wizard
| Step | Expected | Status |
|---|---|---|
| Log in after updating (you have no `onboarded` setting yet) | About 5 s after login the setup window opens at Step 1 of 6 with the welcome text. All steps fit in the window, the buttons stay in the same place on every step. | open |
| Next through the steps | Community: your community is selected. Your name: your current display name. Community chat: a purple sample line, the big Create button (or "This character has a ... chat tab"), three switches matching `/cf settings`. Notifications: four switches matching `/cf settings`. | open |
| Change a switch in the wizard, then open `/cf settings` | The same value there. | open |
| Change the display name, Next | `/cf self` shows the new name. | open |
| Click Finish (or Skip, or X); `/reload` | The wizard does not open again. `/cf setup` opens it. | open |
| Log in on an alt in the community without a Community tab | After ~5 s only the small prompt "Create a Community tab on this character too?". Not now: it asks again after the next login. Don't ask again: never on this alt. Create: the tab appears. | open |
| Log in on a character that is not in the community | No prompt. | open |

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


### CF-25 Community chat that stands out
Needs someone else writing in the community (a friend, or one of your alts on a second client).

| Step | Expected | Status |
|---|---|---|
| Log in | Community chat lines are purple in every chat window (also after `/reload` and on alts). | open |
| `/cf settings` → Community chat → color picker, then "Default purple" | The chat color changes right away; "Default purple" brings it back. | open |
| Select another chat tab (e.g. Combat Log); someone writes in the community | The tab(s) that show the community chat flash; the selected tab does not. No flash for your own messages. | open |
| Tick "Play a sound on new messages"; someone writes | A whisper sound plays. Untick "Flash the chat tab": no flash and no sound. | open |
| Click "Create a Community tab" | A new chat tab named after the community appears with only community messages; a chat line confirms it. Clicking again says this character already has one. | open |
| Untick "Keep community messages in General too" | General no longer shows community messages; the Community tab still does. Tick it again: General shows them again. | open |
| Log in on an alt | The color is applied; the alt has no Community tab yet and the button creates one there. | open |
