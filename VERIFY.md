# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
One run answers most of them: copy `tools/FriendProbe` into `Interface\AddOns` (replace the old one), `/fp start`, then `/reload` and send `WTF\Account\<account>\SavedVariables\FriendProbe.lua`. `/fp start` clears the log first and switches on the V35 feed logging (stays on; `/fp feed off`).

| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | `/fp start` on a friend's client: compare the `club` lines under V8 COMMUNITIES. Your own two characters both show 23125681 for Doombringers (2026-10-18); a friend's account is still to check. | open |
| V35b | Which events tell how a battleground ended? (CF-23; the dungeon part is verified, see API-FINDINGS) | `/cf activity debug` (stays on after `/reload`; `/fp start` also logs the same events), then queue and finish a battleground (stay until the end). Send the FriendProbe log and the `[activity]` lines. Check: `instance:` inside shows `<name>, pvp`; `PVP_MATCH_COMPLETE` passes the winner (0 Horde / 1 Alliance); `battleground ended:` says `won true` when your side won. Last line: `left ...: recorded`. | open |
| V47 | Do clicks on an addon chat link reach the addon? (CF-27: the `[Join]` `[Later]` `[No]` links) | Copy the new `tools/FriendProbe`, `/fp invite`, click `[click me: link test]` in chat. Expected a line `V47 link clicked via EventRegistry test 0` (or `via SetItemRef hook`). | open |
| V48 | Which way can an addon get a friend into your party from a click? (CF-27) | Same `/fp invite` with a friend online in Forever, you not in a group: click `[invite by name]` (does the friend get an invite? the name has a space), leave the group; `[invite via Battle.net]`, leave; then let the friend run `/fp invite` and click `[ask them for an invite]` on you (do you get a "wants to join" popup?). Send both logs: the `C_PartyInfo...` / `BNInviteFriend` lines and the `INVITE EVENT` lines (blocked actions show as `ADDON_ACTION_BLOCKED`). | open |
| V49 | Can addons send addon messages in the community channel? (CF-28: one broadcast to every member instead of a whisper each) | Run 1: the send is accepted (`0`, channel index 6) but no copy comes back to the sender. Needs **two clients** in the community, both with the new FriendProbe: on one `/fp comm channel`; the other's log should show `addon message <- ... channel CHANNEL`. | open |
| V50b | Do all 30 burst whispers arrive? (CF-28: send rate) | Copy the **current** `tools/FriendProbe` first (the 2026-10-19 run used an old copy that counts only in a delayed summary, and the `/reload` came after 9 s). `/fp start`, wait 15 s, then `/reload`: the log shows `received V50:burst 30 so far` (or a lower count). | open |
| V51 | Do addon whispers reach a character of the other faction? (CF-28) | Both characters need FriendProbe: `/fp comm whisper <the other character's name>`; the other log should show `addon message <- ... V51:whisper`. | open |
| V52 | How stale does community presence get after a logout? (CF-28: online status for non-friends; CF-15 bug) | A few minutes after a member logged out, `/fp start`: under V52 COMMUNITY PRESENCE, does that member still show `Online`? | open |
| V53 | Is the "No player named X is currently playing" line hidden after an addon whisper to someone who just went offline? (CF-28) | With a community member running this build: let them log out, then (within a minute, before the community list updates) `/cf sync`. Expected no "No player named ..." line in chat (`ChatFrameUtil.AddMessageEventFilter` / `ChatFrame_AddMessageEventFilter` and `ERR_CHAT_PLAYER_NOT_FOUND_S` are unverified). If the line shows, send it. | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### Setup: chat tab button in the Next spot
| Step | Expected | Status |
|---|---|---|
| On a character without a Community chat tab: `/cf setup`, Next until "Community chat" | The buttons read Back, Not now, Create chat tab (where Next was). | open |
| Click **Create chat tab** | A Community chat tab appears and the setup is on "Notifications and sharing". Back: the chat step says "This character has a Community chat tab" with Skip and Next. | open |
| Close the new tab, `/cf setup` again to the chat step, click **Not now** | No tab is created; the setup goes on to "Notifications and sharing". | open |

### CF-02 part 2: release on tag
| Step | Expected | Status |
|---|---|---|
| Create an author API token at https://authors.curseforge.com/#/settings/api-tokens and add it: `gh secret set CF_API_TOKEN --repo nicoputten/CommunitiesForever` | `gh secret list` shows `CF_API_TOKEN`. | open |
| Move the `## Unreleased` heading in `CHANGELOG.md` to the version (e.g. `## v0.2.0-beta1`), merge `develop` into `main`, then `git tag v0.2.0-beta1` on `main` and `git push origin v0.2.0-beta1` | The `release` workflow runs on GitHub (Actions tab): lint and tests pass, then the packager uploads. | open |
| The CurseForge project page, Files | A beta file `CommunitiesForever-v0.2.0-beta1.zip` for the Forever game version, with the changelog. Unzipped: only the addon (no tests, tools, docs, VERIFY.md, CLAUDE.md, .github). | open |
| Install it with the CurseForge app (beta channel on), log in | The addon loads (`/cf version` shows `v0.2.0-beta1`). | open |
| A push to `develop` without a tag | No release workflow run. | open |

### CF-28 part 2b: sync with the community, no Battle.net friendship needed
Needs a second account in the community, running this build, that is **not** your Battle.net friend (or remove the friendship for the test). `/cf sync debug` on both shows the traffic.

| Step | Expected | Status |
|---|---|---|
| Both online, `/cf` | Within ~10 s the other account shows as a person (their display name, or their first character's name) with their community characters, professions and talents; alts outside the community too. | open |
| `/cf sync debug` on both | Lines like `to <their character>: HELLO ...`, `RECORD ... in N part(s)` (parts of at most 255 bytes) and `... complete`. | open |
| The other one levels up | The level-up line and the new level arrive as for friends. | open |
| They log out | They show offline within seconds (BYE), also if the community list still says online. No "No player named ..." line (V53). | open |
| They ask "who's up for it?" (CF-27) for a dungeon you fit | You get the chat line with [Join] [Later] [No]; your answer reaches them. | open |
| Later you become Battle.net friends | They show once (no duplicate person): the community copy merges into the friend. | open |

### CF-28 part 2a: reliable delivery
Needs a friend running this build online in Forever. A lost part cannot be forced in game; these steps check that nothing broke and that the trace shows the parts.

| Step | Expected | Status |
|---|---|---|
| `/cf sync debug`, then `/cf ping 20000` | `[sync] to <friend>: PING <id> in 6 part(s)`; on the friend (also `/cf sync debug`): `from <you>: <id> part 1/6` ... `6/6`, then `PING complete`. | open |
| `/cf ping stats` | The counters end with `0 resent, 0 missed` (nothing was lost). | open |
| Normal play with a friend for a while (level, quests, logins) | Their data stays up to date as before. If `missed` / `resent` ever go above 0, send the `[sync]` lines. | open |
| `/cf sync debug` again | `Sync debug off.` | open |

### CF-28 part 1: per-character merge
Unit tested in depth (older copies, levels, deleted characters, activity). In game only a check that nothing broke.

| Step | Expected | Status |
|---|---|---|
| A friend with this build levels up, turns in a quest and trains a profession rank | You see the new level, the level-up line, the quest in Shared quests and the activity line as before. | open |
| `/reload` on both sides | Nothing goes back to older data (level, quests, activity). | open |
| Friend unticks "Share my activity" | Their activity lines disappear for you after the next sync, as before. | open |

### CF-27 Who's up for it?
Needs a friend running this build, online in Forever, with a character in range of a dungeon you also fit (an alt counts). Run V47 and V48 first if you can.

| Step | Expected | Status |
|---|---|---|
| Dungeons tab, a dungeon you fit: **Ask who's up for it** | Chat: `Asked <friend> who's up for <dungeon>.` The button turns into `Asked who's up for it · waiting: <friend>`. Asking again within 3 minutes: `You can ask again in N min.` | open |
| On the friend's client | A sound and a chat line `<you> asks: <dungeon> now? (min-max)`, `You could come on: <their characters in range>`, `[Join] [Later] [No]`. | open |
| Friend clicks **[Later]** (or **[No]**) | Friend: `You answered Later to <you>.` You: `<friend>: later for <dungeon>.`, and the Dungeons tab shows `later: <friend>`. | open |
| Ask again after 3 min; friend clicks **[Join]** | Friend: `Asked <your character> for a party invite.` (you get Blizzard's "wants to join" popup) or `<you> gets a link to invite you.` You: `<friend> joins your <dungeon> run on <their character>: [Invite]`. Clicking [Invite] invites them (see V48). | open |
| A click after 10 minutes | `This ask has expired.` | open |
| `/cf settings` → untick "Receive group asks"; friend asks | No chat line, no sound. | open |
| `/cf ask Deadmines`, then `/cf ask` | Same as the button; `/cf ask` shows joining, later, no and waiting. | open |

### CF-23 Dungeons, raids, battlegrounds and playing together
Needs a friend running this build in the same community. `/cf activity debug` on shows why something is or is not recorded (V35). `/cf debugon` shows sample lines (a raid, battlegrounds and a shared dungeon line) without playing.

| Step | Expected | Status |
|---|---|---|
| `/cf debugon`, Activity tab | "Show all" on Debug Friend's line lists Debug Alt with `raided Molten Core (4 bosses)` and `2 battlegrounds (1 won)` first; a line `<you> and Debug Friend together` with `ran Blackfathom Deeps ×2` (the `×` shows, not a box). `/cf debugoff`. | open |
| Enter a dungeon, `/cf activity` | `In <dungeon> (party) for 0 min, 0 bosses killed.` | open |
| Alone: kill a boss, leave after 10+ min | Your Activity line today starts with `ran <dungeon>`. | open |
| Leave a dungeon before 10 min, or without a boss kill | No line for it (debug: `not recorded, ...`). | open |
| `/reload` inside a dungeon, then kill a boss and leave after 10+ min | Recorded: the run survived the reload. | open |
| In a dungeon, accept a quest there and turn it in right away (or any quest picked up and handed in within seconds) | The Activity line counts it under the dungeon (or the zone you are in), not under `Other`. | open |
| With a community member who does not run the addon and is not your Battle.net friend | `ran <dungeon> with <their character name>` on your line. | open |
| Finish a battleground (stay until the end) | `1 battleground (won)` or `(lost)`, matching the result. Leaving early: no line. | open |

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

