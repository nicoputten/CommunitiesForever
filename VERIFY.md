# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
The FriendProbe launch checklist (CF-60) answers most of them: unzip `FriendProbe.zip` (`tools\build-probe.ps1`) into `Interface\AddOns` and play as usual. Until 2026-11-18 it checks and logs by itself, silently; `/fp` opens the checklist (six play sessions, automatic ticks, Yes / No for the rest, the test buttons below, Copy report). Send `WTF\Account\<account>\SavedVariables\FriendProbe.lua` when done. Every open item below is a checklist item (`tests/spec/ProbeChecklist_spec.lua`).

| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | the FriendProbe run (at login) on a friend's client: compare the `club` lines under V8 COMMUNITIES. Your own two characters both show 23125681 for Doombringers (2026-10-18); a friend's account is still to check. | open |
| V35b | Which events tell how a battleground ended? (CF-23; the dungeon part is verified, see API-FINDINGS) | `/cf activity debug` (stays on after `/reload`; the FriendProbe run (at login) also logs the same events), then queue and finish a battleground (stay until the end). Send the FriendProbe log and the `[activity]` lines. Check: `instance:` inside shows `<name>, pvp`; `PVP_MATCH_COMPLETE` passes the winner (0 Horde / 1 Alliance); `battleground ended:` says `won true` when your side won. Last line: `left ...: recorded`. | open |
| V47 | Do clicks on an addon chat link reach the addon? (CF-27: the `[Join]` `[Later]` `[No]` links) | Copy the new `tools/FriendProbe`, FriendProbe's Test: links and invites, click `[click me: link test]` in chat. Expected a line `V47 link clicked via EventRegistry test 0` (or `via SetItemRef hook`). | open |
| V48 | Which way can an addon get a friend into your party from a click? (CF-27; inviting by name works, see API-FINDINGS) | Same FriendProbe Test: links and invites with a friend online in Forever, you not in a group: click `[invite by name]` (does the friend get an invite? the name has a space), leave the group; `[invite via Battle.net]`, leave; then let the friend run FriendProbe's Test: links and invites and click `[ask them for an invite]` on you (do you get a "wants to join" popup?). Send both logs: the `C_PartyInfo...` / `BNInviteFriend` lines and the `INVITE EVENT` lines (blocked actions show as `ADDON_ACTION_BLOCKED`). | open |
| V51 | Do addon whispers reach a character of the other faction? (CF-28) | Both characters need FriendProbe: `/fp whisper <the other character's name>`; the other log should show `addon message <- ... V51:whisper`. | open |
| V52 | How stale does community presence get after a logout? (CF-28: online status for non-friends; CF-15 bug) | A few minutes after a member logged out, the FriendProbe run (at login): under V52 COMMUNITY PRESENCE, does that member still show `Online`? | open |
| V53 | Is the "No player named X is currently playing" line hidden after an addon whisper to someone who just went offline? (CF-28) | With a community member running this build: let them log out, then (within a minute, before the community list updates) `/cf sync`. Expected no "No player named ..." line in chat (`ChatFrameUtil.AddMessageEventFilter` / `ChatFrame_AddMessageEventFilter` and `ERR_CHAT_PLAYER_NOT_FOUND_S` are unverified). If the line shows, send it. | open |
| V59 | Does the hidden sync channel work (CF-31)? `JoinTemporaryChannel` (or `JoinChannelByName`), addon messages with `SendAddonMessage(prefix, text, "CHANNEL", index)`, and which `CHAT_MSG_ADDON` arguments name the channel. | See the CF-31 steps: `/cf sync debug` shows `to the community channel: HELLO ...` when it sends there. If HELLOs keep going as whispers to members on this build, send the `[sync]` lines and the output of `/dump GetChannelList()` (is a `cf...` channel in it?). Nothing breaks when it fails: the addon keeps whispering. | open |
| V64 | Do the ambient effects work (CF-43)? `texture:CreateAnimationGroup` (on the streak, not the frame: see API-FINDINGS "Retail dry runs") with a `Translation` animation (`SetOffset`, `SetDuration`, `SetStartDelay`, `SetLooping("REPEAT")`), `SetClipsChildren` and `Texture:SetBlendMode("ADD")`. | See the CF-43 steps: a soft light streak slides across the window title every few seconds and across LEVEL UP chips, clipped to them; the title bar and the chips themselves never move and no dark block shows; between passes nothing shows, no white strip behind the title's shield (CF-62: an `Alpha` animation holds it visible only while it moves); off with Ambient effects. If nothing moves, send any Lua error. | open |

| V69 | Can one click invite several friends in a row (`C_PartyInfo.InviteUnit` per name), the first invite making a party? (CF-48: Invite everyone ready) | With at least two friends online in Forever and you not in a group: FriendProbe's Test: invite all, click `Invite all N`. Do all friends get an invite (also the second, while the first hasn't accepted yet)? Let them accept, wait 10 s (`V69 after 10 s: in group N`), `/reload` and send the log (the `V69 C_PartyInfo.InviteUnit` lines and `INVITE EVENT` lines). | open |
| V70 | Do `C_ChatInfo.InChatMessagingLockdown()` and `IsEncounterInProgress()` exist, and are they true during a boss fight? (CF-46: runs are never sent during encounters, keystones or PvP matches) | Inside a dungeon, during a boss fight: `/run print(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown(), IsEncounterInProgress and IsEncounterInProgress())`, and once more outside the fight. Expected `true true` in the fight, `false false` outside (`nil` means the function is missing: then only battlegrounds count). | open |


| V72 | Does `ChatFrameUtil.OpenChat("/w <name> <text>")` (or `ChatFrame_OpenChat`) open the chat input with the whisper and text filled in? (CF-48: Whisper on the start panel) | On the CF-48 start panel, click Whisper on a friend who is on another character. Expected: the chat input opens as a whisper to that character with "You're on … Switch to …?" filled in, not sent yet. If it opens empty (or not at all), say which. | open |
| V73 | What does `CHAT_MSG_COMBAT_HONOR_GAIN` pass on Forever: the victim's name and rank? Does `PLAYER_PVP_KILLS_CHANGED` fire, and what do `GetPVPSessionStats` and `GetPVPLifetimeStats` return? (CF-54, CF-55: raw kills for Doomsday) | Copy the new `tools/FriendProbe`, the FriendProbe run, then get a few honorable kills in the world: at least one solo and one in a group, and one in a battleground. `/reload` and send the log: the `V73 honor` lines (all arguments) and `V73 counters` lines. | open |
| V74 | Which enemy player fields can an addon read from target, mouseover and nameplates (`UnitLevel` with `-1` for a skull, `UnitClass`, `UnitRace`, the PvP rank, `UnitGUID`), and does `NAME_PLATE_UNIT_ADDED` fire for enemy players? (CF-55: victim level, class, race and rank) | The FriendProbe run: target and mouse over enemy players, with nameplates on, including one that shows a skull. The log shows a `V74 unit` line per player seen. Any `secret` or `missing` in them answers the question. | open |
| V75 | Can an addon register `COMBAT_LOG_EVENT_UNFILTERED` on Forever, and does it show `PARTY_KILL` with the victim's GUID (`GetPlayerInfoByGUID`) and who killed you? (CF-54: Wanted poster, revenge kill) | Only from the button (on Retail 12.1.5 registering it is blocked with Blizzard's popup, see API-FINDINGS "Retail dry runs"; this item is about Forever): `/fp`, Test the combat log. A popup "only available to the Blizzard UI" means blocked: answer No in the checklist and don't disable the addon. Without a popup the log has `V75 combat log: registered`; then get a kill and die to a player once: `V75 PARTY_KILL` and `V75 killed by` lines. | open |
| V76 | Are `IsInGroup()` and the `GetInstanceInfo()` type right at the moment of a kill (`solo`, `bg`)? (CF-55) | The FriendProbe run: each `V73 honor` line is followed by `group true/false, instance <type>`. Check that it matches (grouped or not, `pvp` only in the battleground). | open |
| V79 | Do `GetPVPLifetimeStats`, `UnitPVPRank` with `GetPVPRankInfo(rankID, "player")`, `GetPVPThisWeekStats` and `GetStatistic(60)` (total deaths) exist and give numbers, and does `PLAYER_PVP_KILLS_CHANGED` fire on an honorable kill? (CF-52) | `/run print(GetPVPLifetimeStats and GetPVPLifetimeStats(), UnitPVPRank and UnitPVPRank("player"))`, `/run print(GetPVPRankInfo and GetPVPRankInfo(UnitPVPRank("player"), "player"))`, `/run print(GetPVPThisWeekStats and GetPVPThisWeekStats(), GetStatistic and GetStatistic(60))`. Expected numbers (a rank name and number for a ranked character; `nil` means missing: send which). Then see the CF-52 steps. | open |
| V84 | Do `LOOT_OPENED`, `IsFishingLoot()` and `GetNumLootItems()` work for fishing? (CF-56: `d.fish20`) | Fish once: `/run print(IsFishingLoot, GetNumLootItems)` shows two functions; after a catch, `/cf doomsday` with `/dump CommunitiesForeverDB.global.self.doomsday` after `/reload` shows `fish` up by the items looted. | open |
| V85 | Do `TRADE_SHOW` with `UnitGUID("NPC")`, `TRADE_PLAYER_ITEM_CHANGED` with `GetTradePlayerItemLink(slot)` and `UI_INFO_MESSAGE` with `ERR_TRADE_COMPLETE` tell a completed trade, its partner and what you gave? (CF-56: `d.trade`, `w.craftTrade`) | Trade an item you crafted to a friend's community character; after `/reload` this week's facts have `trades = 1` and `craftTrade = 1`. A cancelled trade adds nothing. | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-61 bug 11: Dungeons tab without a dungeon
| Step | Expected | Status |
|---|---|---|
| Log in on an alt outside the selected community, `/cf`, Dungeons | "<name> isn't in the community yet. Join it from the Friends tab with a friend's invite link." (not the level sentence) | open |
| A character in the community below level 13 | "<name> is not in a dungeon's level range yet. The first one, Ragefire Chasm, starts at level 13." | open |

### CF-61a Retail dry-run fixes: wizard, settings, version, alt join
| Step | Expected | Status |
|---|---|---|
| `/cf setup` | The line under the progress bars reads "Step 1 of 6 · Welcome → Community" and stays inside the window; Next moves it to "Step 2 of 6 · Community → …". The last step shows "Step 6 of 6 · Done". | open |
| `/cf settings` | Every description wraps inside its own column: none runs under the right column or past the window's edge, and the rows below move down to make room. The footer shows the version with one `v` (e.g. `v0.8.0-beta1`). | open |
| A friend sets the community invite link (`/cf settings`, Community invite link). Log in on an alt that isn't in the community | A few seconds after login the window opens by itself on Friends with "How to join …". `/reload`: it doesn't open again on that alt. | open |
| On that alt: Post invite link in chat, click the link, Join in Blizzard's window | Right after joining, "Create a Community tab on this character too?" shows: a compact dialog with one line, "A tab with only your community's chat.", and on the right Not now and Create tab with normal button padding. Not now closes it and it doesn't ask again on that character. | open |

### CF-61b No designer notes; one reset label per view
| Step | Expected | Status |
|---|---|---|
| `/cf`, every tab (Friends, Activity, Dungeons, Doomsday with all five chips) and the settings | No notes about how the addon, the rules or the site work: none of "Suggestions, never rules", "Live for friends online…", "* = swapped goal…", "Any of your characters counts.", "This week only…", "no kills yet · Rank title…", "Runs come from the website…", "/cf to open · drag the title to move", "Group asks wait until combat ends". | open |
| Doomsday › Today and Board | Top right of the view: "New goals in 5 h 58 m" (your time to the reset). Nothing next to the chips. | open |
| Doomsday › Week and Ladder | Top right: "Week resets Sun 19:00 · in 3 d 5 h". | open |
| Board: hover a crossed-out name | "All three PvE dailies done". | open |
| Dungeons: hover Ask now | "Whispers online friends who fit; can post on Discord too. Waits until combat ends." | open |

### CF-61d Feats: earned while watched, "Already had", no early mounts
| Step | Expected | Status |
|---|---|---|
| `/cf`, Doomsday › Feats on a character the addon knew before this version | Under the character, only feats with a date (earned while the addon watched). What it had at the first sight is one dim line "Already had: Level 10, Level 20, …"; hovering it lists each with its detail. The count after the name counts only the earned ones. | open |
| A character below level 40 with riding (Retail dry run) | No "Mount" feat, also not in "Already had". | open |
| Gain a level | "Level N · Reached level N · <date>" appears in the list. | open |

### CF-61e Doomsday rule updates: PvP Virgin, rank 0, the Duel slot, day labels in your clock
Times are stored as server times (UTC seconds) and shown in your PC's clock (Nico, 2026-10-29).
| Step | Expected | Status |
|---|---|---|
| `/cf`, Doomsday › Today | "Today · Wed evening · N of 6 done" (the weekday and part of the day the Doomsday day starts on, in your clock; 3 PvE, Hunt if on, Skirmish, Duel). The Duel slot counts as done after your first duel today. | open |
| Finish a goal after midnight (your clock) | Its time reads "Wed 00:04" with the weekday; before midnight just "23:41". The Week view always shows the weekday. | open |
| Take the crown | The toast: "All three dailies done at <time>" and "The crown is yours until Thu 19:00" in your clock. | open |
| A friend with only a duel (no kills) | No "PvP Virgin" on their card, the Ladder ranks them in PvP. Their rank-0 card line reads "No rank yet · 0 kills". | open |
| A character with kills but no rank | "No rank yet · N kills" on the card and under Your PvP; "Conscientious Objector" only for someone without any PvP point. | open |

### CF-58 Drop "Share my activity"
| Step | Expected | Status |
|---|---|---|
| `/cf settings` | Sharing has only "Receive group asks"; no "Share my activity". `/cf setup`: the step is called "Notifications" with three switches and the minimap one. | open |
| A friend on this build, you on a released version with "Share my activity" off | The friend still sees your activity from before (nothing is wiped); new activity of yours doesn't reach them until you update. | open |
| Both on this build | Each sees the other's activity; the Activity tab footer says "Keeps 7 days" on the right and nothing on the left. | open |

### CF-57b Doomsday tab: Board, Ladder and Feats
Compare with `docs/design/doomsday-2026-10/DD08AddonBoard.dc.html`. Best with two friends on this build.

| Step | Expected | Status |
|---|---|---|
| Doomsday › Board | One row per friend: you first, then friends with Doomsday data, then the rest ("no Doomsday data yet"); a column per goal of today with its short label ("10 QUESTS"); a gold ✓ for done or an empty □ (hover: the goal, "Done at 10:42", your own "3/10", or "Not done yet"); a dot after a swapped goal (hover adds "Instead of: …"); a line through the name of a friend who did all 3 PvE dailies with the time they finished, "crown" after the first one (hover the name: "Streak N days" and when they finished); one POINTS column "PvE 15 · PvP 11". "New goals in …" top right; no notes under the board. | open |
| Doomsday › Ladder | PvE and PvP apart, each ranked this week with points and movement against last week ("+2", "new"); clicking a row shows the characters. A friend who never killed anyone: "PvP Virgin · not ranked". Your PvP: rank and title, kills this week and the zone with most, duels won–lost, each battleground won–lost with its points. | open |
| Doomsday › Feats | Your characters with their feats, newest first; what they had before the update says "earlier". The next honorable-kill feat with "412 / 1,000"; a character without kills: no kill line. | open |
| Level up | A new feat "Level N" with today's date. | open |
| Activity tab, a day with 5 (or 10) kills in a row without dying | "a spree of 5" (or 10) on that line. | open |

### CF-57a Doomsday tab: Today, Week, chat lines and the toast
Compare with `docs/design/doomsday-2026-10/DD07AddonToday.dc.html`.

| Step | Expected | Status |
|---|---|---|
| `/cf`, the new tab **Doomsday** after Dungeons | Chips Today and Week, nothing on their right. Today: "Today · <day> · N of 5 done" with "New goals in …" on the right, one row per goal (DAILY, HUNT once it's on, SKIRMISH) with "3/10" and a gold bar, or "✓ 20:14" in your own clock time; the DUEL row with whom you dueled ("won vs Bob") and who's still open; "PvE 10 · PvP 9", the kill summary, the streak, who has the crown. Footer: "Synced with …" only. | open |
| Hover a goal marked "(swapped)" | A tooltip "Instead of: <the original goal>". | open |
| Week | "This week", "Week resets <weekday> <time> · in N d N h", the weeklies and the Bounty (for "every enemy class": "Still needed for the bounty: …"), this week's points, your characters with their level and PvP points, the streak. | open |
| Finish a daily | Chat: "Daily done: <goal> (+5 PvE, N of 3 today)". A weekly: "Weekly done: … (+15 PvE)". | open |
| A kill on a player 3+ levels above you, solo | Chat: "Kill: +2 PvP · 3 levels above you, and solo (+1)". A kill worth 1 point says nothing. | open |
| Finish all 3 PvE dailies first in the group | Under the minimap: "First to finish today!", "All three dailies done at <time>", "The crown is yours until <reset time>. Others have been told, gently." It fades in and slides with Ambient effects on, just appears with them off. | open |
| A friend finished first (after their record syncs) | Chat: "<friend> finished Doomsday first today. You're at N of 5." Once a day. | open |
| The day turns at the reset while you play, with a swapped goal | Chat: "Swapped for you: "<original>" → "<new>"". Not at login. | open |
| Settings → Doomsday in chat off | No Doomsday chat lines; the toast still shows. | open |
| A friend's character card (Friends tab) | Under the tiles: "<rank>, a.k.a. <our title> · N honorable kills · PvP N this week", or "PvP Virgin"; nothing for a friend on an older addon. | open |

### CF-56 Goals tracked and shared
`/cf doomsday` prints today's and this week's goals with progress, swaps, the streak and this week's points.

| Step | Expected | Status |
|---|---|---|
| `/cf doomsday` | "Doomsday <weekday day month>, resets in …", the source (`realm clock`, `the site's time zone` or `CET/CEST`), today's 3 PvE dailies and the Skirmish, this week's 3 weeklies and the Bounty, with progress. | open |
| A day with "Finish 10 quests": 6 quests on one character, 4 on another | After the 10th: "Finish 10 quests: done <time>" in your own clock time. | open |
| A swapped goal (e.g. a character without professions) | "(instead of: …)" after the replacement. | open |
| Wait past 19:00 realm time (or the site's reset) | `/cf doomsday` shows the next day with new goals; Sunday's reset also starts a new week. | open |
| Two accounts: A finishes a goal | Within about a minute B's saved file has `people[<A's BattleTag>].goals.days[<day>].done`. | open |
| A full run of The Deadmines (all 7 bosses) in a week with "Clear every boss of a dungeon" | The weekly is done. Note the boss count `/cf activity` shows for Scarlet Monastery wings, Blackrock Spire, Dire Maul, Stratholme, Scholomance, Blackfathom Deeps and Sunken Temple, for their counts. | open |
| A friend in Thailand (or a PC clock set to another zone) | The same day and goals as everyone; clock times in their own time. | open |

### CF-55b Raw kills in the record
After CF-54's run (V73, V74, V76). One PvP-flagged character with this build; enemy nameplates on. After the steps `/reload` and look at `self.feed[<today>][<guid>].pvpKills`.

| Step | Expected | Status |
|---|---|---|
| Target an enemy player, then get the honorable kill on them, solo | An entry with `name`, `lvl` (or `-1` for a skull), `class`, `race`, `rank` (when ranked), `myLvl`, `solo = true`, the zone and time. | open |
| A kill on a player you never targeted or saw a nameplate of | An entry with `name` (and `rank`) only. | open |
| A kill in a group | No `solo`. | open |
| A kill in a battleground | `bg = true`, the battleground as zone. | open |
| If no honor message comes for a kill (the counter rose) | An entry without `name` about 3 s later. | open |

### CF-54 / CF-60 The FriendProbe launch run (from 2026-11-05)
Answers V73 to V86 and the older open questions in one go. Unzip `FriendProbe.zip` into `Interface\AddOns` (replace the old FriendProbe), and share the zip with friends.

| Step | Expected | Status |
|---|---|---|
| Before launch, a dry run on Retail (same Mainline API and Midnight restrictions): copy the probe into Retail's `Interface\AddOns`, tick "Load out of date AddOns" | It loads without a Lua error and stays silent. `/fp` says "on retail"; the items only Forever can answer (Vanilla honor, ranks, riding, battlegrounds, sync with friends) are greyed "Forever only". Retail results are kept apart (`results.retail`): they never close a VERIFY item by themselves. | open |
| Log in (any character) | Nothing in chat. `/fp` opens the checklist: the items answered on Retail 12.1.5 are ticked in the Done list at the bottom (CF-61). | open |
| Play the six sessions over the week (alone, with a friend, questing, a dungeon, world PvP on a level 20+ character with enemy nameplates on, later in the week) | Items tick by themselves as they happen; mark the others Yes or No in `/fp`. | open |
| Copy report | A window with the results as text, ready to copy. | open |
| After a few days, send `WTF\Account\<account>\SavedVariables\FriendProbe.lua` (and friends theirs) | Claude Code moves the answers to `docs/API-FINDINGS.md`, decides which victim fields CF-55b fills and the next pool version (the Hunt stays or becomes a second Skirmish), fills the boss counts, and proposes the Wanted poster and revenge-kill stories if the killer's name is readable. | open |
| After 2026-11-18 | The probe stops logging by itself. | open |

### CF-53 Loot, gold, play sessions and groups in the record
One character with this build. After the steps `/reload` and look at `self.feed[<today>][<guid>]` in the saved file (`CommunitiesForeverDB`).

| Step | Expected | Status |
|---|---|---|
| Loot a blue item, take a blue quest reward, loot a grey and a green | `loot.rare = 2`; nothing for the grey and green. | open |
| Loot (or win the roll for) a purple item | `loot.epic` has `{ id, name, slot = "INVTYPE_...", level }` with your level at that moment. | open |
| A friend in your group loots a blue | Nothing in your `loot`. | open |
| Tailor: create Mooncloth (or any watch-list item you can) | `notable = { [14342] = 1 }`. Crafting an item off the watch list adds nothing. | open |
| Sell something to a vendor, buy something | `gold.gained` and `gold.spent` in copper match. | open |
| Log in, play 10 minutes, `/reload`, play 10 more, log out | One session in `sessions`: `from` at the login, `to` at the logout (20+ minutes). | open |
| Log in again after 10 minutes away | A second session. | open |
| Group with a friend's community character, then with a stranger | `groups` has the friend's character GUID only. | open |
| Learn riding (level 40) | `self.chars[<guid>].riding = 75`; friends see it after the next sync. | open |

### CF-52 PvP, duels and deaths in the record
One character with this build, flagged for PvP. `/cf self` shows a `PvP:` line under the character. After the steps `/reload` and look at `CommunitiesForeverDB` in the saved file: `self.chars[<guid>].pvp` and `self.feed[<today>][<guid>]`.

| Step | Expected | Status |
|---|---|---|
| Log in, `/cf self` | `PvP: <lifetime honorable kills>, <rank name> a.k.a. <our title>` (or `rank 0 a.k.a. Conscientious Objector`), this week's kills and honor as the honor tab shows them. `?` means the counter was not readable (V79). | open |
| Get two honorable kills in one zone, one in another | The feed entry has `kills = { [zone] = 2, [other zone] = 1 }`; `/cf self` shows the lifetime count 3 higher. | open |
| Duel a friend and win; duel again and lose; duel once more and run out of the duel area | `duels` has three entries `{ t, won, vs }` with `won = true`, `false`, `false` and the friend's full name; `pvp.duelsWon = 1`, `pvp.duelsLost = 2`. A duel between two other players nearby adds nothing. | open |
| Die by falling, by drowning (stay under water), to a monster and to an enemy player | `deaths` has one entry each with `cause` `fall`, `drown`, `creature`, `player`. Without the combat log (V81) `fall` and `creature`/`player` show as `other`, drowning still as `drown`. `pvp.deaths` counts up. | open |
| A friend with this build: after a minute | The friend's saved file has your `chars[<guid>].pvp` and the feed's `kills`, `deaths`, `duels` under `people[<your BattleTag>]`. | open |
| Gain a PvP rank (when the weekly ranking comes) | `/cf self` shows the new rank and title; friends get it within seconds (not after 60 s). | open |
| Warsong Gulch, Arathi Basin and Alterac Valley, once each is open: finish a match | The feed's `runs` has the battleground with `kind = "pvp"` and `won` true or false (CF-23). | open |

### CF-51 Carry friends' asks
Two accounts with this build, Battle.net friends, both in the community: A (asks) and B (carries). The site on WEB-53.

| Step | Expected | Status |
|---|---|---|
| A: Ask now for a dungeon B has no character in range of, tick "Also post on Discord" | B gets no "asks: … now?" line; after B's `/reload`, B's saved file has a `pending` item `kind = "ask"` with A's item id (as in A's file), A's guid and BattleTag. | open |
| B uploads (the uploader app) before A reloads | The ask shows on Discord as A's ask, once; after A's upload too, still one post. B's next runs fetch lists the id under `received` and B's `pending` loses it. | open |
| A: Ask now for a dungeon B fits, posted on Discord; B: [Join] | B's `pending` gets the ask and an `askAnswer` (`answer = "in"`); after B's upload the Discord post lists B as In. | open |
| B waits 11 minutes before `/reload` | The carried ask and the answer are pruned, nothing reaches the site. | open |

### CF-50 Any level may answer I'm in
Use the CF-49 setup: a run 12+ levels above your character (`dungeon = "smarm"` at level 20). `/reload` after each edit.

| Step | Expected | Status |
|---|---|---|
| The run, "Answer", pick the character | "12 below", "This will be tough." in orange under the characters; I'm in stays enabled and selected. | open |
| Save answer | `pending` in the saved file (after `/reload`) has `answer = "in"` with that character. | open |
| The Dungeons tab, a run you don't fit | Your 6+ below alt is not in "Close: …" (only 1–5 below and carries are). | open |

### CF-49 Runs v2: level fit and roles
Use the CF-46 test file. Give one run a dungeon well above your character (e.g. `dungeon = "smarm"` at level 20) and add answers with `role`, `fit` and `reserve`: `{ name = "Cy Example", answer = "in", role = "dps", fit = "carry \194\183 +12" }`, `{ name = "Bo Stone", answer = "maybe", role = "heal", reserve = true }`. `/reload` after each edit.

| Step | Expected | Status |
|---|---|---|
| A run in range, "Answer" | Your characters with "fits", "+N over", "carry · +N" or "N below", fits first. Under them "ROLE" with only the roles the class can play (Warrior Tank and Damage, Mage only Damage), starting on the character's role. A carry shows "Little XP for you here.", 1–5 below "This will be tough." | open |
| Healer, Save answer | `pending` in the saved file (after `/reload`) has the answer with `role = "heal"`. With the organiser online with this build: their slot shows you as Healer. | open |
| The run 12+ levels above you, "Answer", pick the character | ~~"6+ levels below: Maybe only", I'm in greyed out~~ Since CF-50: see CF-50. | open |
| "Plan a run" | A ROLE row under Lead as; another Lead as character changes the roles; the plan's `role` in `pending` is the one picked. | open |
| The run with Cy and Bo in the Dungeons tab | Cy's slot says "carry · +12" in orange; Bo has no slot; "Reserve: Bo Stone (Healer)" under the slots. A character of yours 1–5 below or a carry is in "Close: … (your alt, 4 below)". | open |
| A Runs.lua from before (no role, fit, reserve) | The tab looks as with CF-46. | open |

### CF-48 Reminder, start time and chat lines
Compare with `docs/design/runs-2026-10/run-start.html`. Use the CF-46 test file with runs a few minutes ahead (e.g. `startsAt = $($t + 35 * 60)` with `reminderMinutes = 30`), and a friend with this build online for the invite steps (V69, V48).

| Step | Expected | Status |
|---|---|---|
| A run you're in, at its reminder time | A note under the minimap: "IN 30 MINUTES", the dungeon and time, "You're in as … <organiser> invites at start. N in.", Open and Close; it goes after 20 s. A soft chime. A chat line "… starts in 30 min (20:30). You're in as …. [Open]"; Open shows the run in the Dungeons tab. | open |
| Settings → Planned runs / Run chat lines | Run reminders off: no note. Reminder chime off: no sound. Each chat line kind off: that line is gone. | open |
| A run you organise, at start time | The start panel opens by itself: "<dungeon> · starting now", "you organise · N in · N maybe", each friend with name, role, answer and state (ready · online on this character / online, but on <char> (level) / offline / already grouped / can't · answered on Discord). | open |
| Invite, Invite everyone ready (N) | Each ready "I'm in" friend gets an invite (V69: several in a row); friends already in your group are skipped. | open |
| A friend on another character | A chat line "… is online on <char>, signed up as <char>. [Whisper] [Invite <char>]"; Whisper opens the whisper with the text filled in (V72); Invite <char> instead invites that character. | open |
| Ping on Discord, Ping everyone missing | "ping queued · after /reload" on the row; a chat line "Discord ping for … queued. It reaches Discord after /reload. [Reload now]"; Reload now on the panel. After the upload the site posts the ping (WEB-43). | open |
| A run someone else organises, at start time | A note "STARTING NOW", "Waiting for <organiser>'s invite", Request invite (V48: `RequestInviteFromUnit`); a chat line with [Request invite]. The run card has Request invite from 5 minutes before the start. With the organiser offline, the panel says whom to whisper instead. | open |
| A friend answers your run in game, or on Discord (a newer Runs.lua) | "<friend> is in for <dungeon> (answered in game)." / "(answered on Discord)." Runs from a friend's addon: "Runs updated at <time>. Type /reload for newer." | open |

### CF-47 Ask now, plan a run, sign up
Compare with `docs/design/runs-2026-10/run-dialogs.html`. The answer steps need the CF-46 test file (with a run someone else organises) and ideally that friend online with this build.

| Step | Expected | Status |
|---|---|---|
| Dungeons tab, a dungeon in range, "Ask now" | A dialog "Ask now": the dungeon with its range and "now", "You go as <character> <level> · <role>", "WHISPERED NOW · ONLINE AND FIT" with the friends who get it, "Not asked: …" with why (above/below the range, offline), a note field, "Also post on Discord" with its help line, Cancel and Ask now. | open |
| Type a note, tick Also post on Discord, Ask now | Friends get the ask with your note in quotes (CF-27 chat line). Then "Post on Discord?" with "Reload now to post on Discord", the text about saving, Later and Reload now. | open |
| Reload now (V68) | The UI reloads. Without the API: the line "Type /reload to post it now." | open |
| "Plan a run" on a dungeon | Dungeon and Lead as dropdowns, the days Today and the next six (the picked one highlighted), Time "20:00" with "your PC clock · friends see their own time", a note, Cancel and Plan run. "Reaches the site and Discord after /reload." | open |
| Pick tomorrow, 21:30, Plan run (V71) | The reload prompt; the run shows in the Runs list at once with "reaches Discord after /reload". A time like "soon": "Type the time as 20:30."; today 00:00: "That time has passed." | open |
| A run someone else organises, "Answer" | "Answer": the dungeon, "Thu 21:00 · 20:00 for <organiser>" (their time, when the site sent their offset), I'm in / Maybe / Can't, "PICK MY CHARACTER" with your characters and fits / too high / too low, "reaches Discord after /reload", Save answer. Can't hides the characters. | open |
| Maybe, a character, Save answer | The row says "you: maybe as <character>  reaches Discord after /reload". With the organiser online with this build: their Dungeons tab shows you in the run within seconds (`/cf sync debug`: `RUNANSWER`). | open |
| `/reload`, then let the uploader upload (after UP-12 and WEB-43) | `WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` has a `pending` list with your plan, ask and answer. After the site has them and the next Runs.lua lists them under `received`, the "reaches Discord" labels go. | open |
| Ask now with Discord, Later, wait 11 minutes, log out | The ask is gone from `pending` in the saved file (not posted). | open |

### CF-46 Dungeons tab with runs
Compare with `docs/design/runs-2026-10/dungeons-runs.html`. Until the uploader writes runs (UP-12), make a test file by hand. In PowerShell, with your game folder and a character name of yours in the first two lines (a run in 2 hours and one tomorrow, you organise the first):
`$addon = "<game folder>\Interface\AddOns\CommunitiesForever"`, `$me = "<your character name>"`, `$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`, then
`Set-Content "$addon\Data\Runs.lua" "CF_RUNS = { updatedAt = $t, reminderMinutes = 30, runs = { { id = 'r1', dungeon = 'dm', startsAt = $($t + 7200), source = 'site', note = 'Bring water', url = 'https://example.com/runs/r1', organiser = { name = '$me', battleTag = '<your BattleTag>' }, answers = { { battleTag = '<your BattleTag>', name = '$me', answer = 'in', role = 'dps' }, { name = 'Ada Example', answer = 'maybe', source = 'discord' } } }, { id = 'r2', dungeon = 'wc', startsAt = $($t + 26 * 3600), source = 'discord', organiser = { name = 'Ada Example' }, answers = { { name = 'Ada Example', answer = 'in', role = 'tank' } } } } }"`.
Afterwards put the empty file back: `Set-Content "$addon\Data\Runs.lua" "CF_RUNS = nil"`.

| Step | Expected | Status |
|---|---|---|
| Write the test file, `/reload` (V67), `/cf`, Dungeons tab | The tab badge says 2. Left "RUNS": The Deadmines with "Today <time>" in a warm colour and "you organise    1 in · 1 maybe"; Wailing Caverns "Tomorrow <time>", "Ada Example" and "<character> fits damage" in green (when you are in range). Below them "Runs updated at <time> · /reload for newer", then the dungeons in range; The Deadmines with "1 run". | open |
| Click The Deadmines run | Name large, "Today <time> · in 1 h 59 min", "17–26 · planned on the website", the note in quotes. "Group" with five slots: Tank "nobody in range" (or open), Healer, your character outlined gold with "organiser", Ada Example dimmed with "maybe". "At <time>": "You'll get a reminder at <time − 30 min>. At start, Invite all invites everyone who's in and online." and a greyed "Invite all · from <time>". "Edit or cancel": the link in a box (click, Ctrl+C copies; typing does not change it). | open |
| Click the Wailing Caverns run | "planned on Discord", "Organised by Ada Example · 1 in", Ada Example as tank with "organiser"; no Invite all. | open |
| A friend with this build online, you have the test file, they don't | Within a few seconds their Dungeons tab shows the same runs (`/cf sync debug` shows `RUNS`). After their `/reload` the runs are still there (stored). | open |
| Put the empty file back, `/reload` | The runs stay (stored from before) until a newer list arrives; "No runs planned" only when none are upcoming. | open |
| Inside a battleground with a friend logging in | No `RUNS` while you are in the match (`/cf sync debug`); it goes out within 30 s after you leave. | open |

### CF-45 Runs file and checks
Nothing shows yet: the Dungeons tab reads the runs from CF-46 on. This checks that the empty file ships and loads.

| Step | Expected | Status |
|---|---|---|
| Install the release (CurseForge app or `tools\build.ps1 -AddOnsPath "<game folder>\Interface\AddOns"`) | `Interface\AddOns\CommunitiesForever\Data\Runs.lua` exists and contains `CF_RUNS = nil`. | open |
| Log in, `/reload` | No Lua error; the addon works as before. | open |

### CF-44 Level-up announcement
Needs a friend with the addon who levels up while you are online (or `/cf debugon` is not enough: the debug friend never levels).

| Step | Expected | Status |
|---|---|---|
| A friend's character levels up | At the top centre of the screen a dark pill with a gold border: the character's round portrait, "<friend>'s <character> reached level N" (friend gold, character in class colour), and a gold LEVEL UP chip with a slow shine (V64). It fades out after 6 seconds. The chat line still comes. | open |
| Two level-ups close together | The second pill shows right after the first one is gone. | open |
| Settings → Notifications → Level-up announcement off | The chat line only, no pill. Announce friends' level-ups off and the announcement on: the pill only. | open |
| Ambient effects off | The pill without the shine. | open |

### CF-43 Settings and setup in the new look
Compare with `docs/design/revamp-2026-10/settings-setup.html`.

| Step | Expected | Status |
|---|---|---|
| `/cf settings` (or the gear) | A 640 × 500 window in the new look titled "Settings": Display name and Community (a dropdown) on top, then Sharing, Notifications, Community chat, Interface in two columns, the invite link (only when you may set it), then "Roles of your characters". Footer "Also under Options » AddOns" and "v<version>". Scrolls when it is longer than the window. Esc closes it. | open |
| Each switch | Changes the same thing as before (e.g. When friends log in off: no login line; Minimap button off: the button goes). | open |
| Display name: type, Enter | Saved (friends see it after the next sync). | open |
| Community dropdown | Blizzard's menu with your character communities; picking one switches the window to it. | open |
| Chat colour square | Opens the colour picker (V65); Reset puts the default purple back. | open |
| Create a community chat tab | Makes the tab as before. | open |
| A role dropdown | Auto (from talents), Tank, Healer, DPS; the Dungeons tab uses the role. | open |
| Open on login on, `/reload` | The window opens a few seconds after loading (not when the setup opens, not without a community). | open |
| Ambient effects | On: a slow light streak across the window title and across LEVEL UP chips in Activity (V64). Off: none. | open |
| Esc → Options → AddOns → CommunitiesForever | The line and "Open settings", which opens the window (V66). | open |
| `/cf setup` | A 600 × 460 window: progress bars and "Step 1 of 6 · Welcome → Community → ...", "Who is who in your community", three tiles (Friends, Activity, Dungeons). Skip setup (left of Next) and Back. | open |
| Through the steps | Community: the dropdown; Your name: the field (saved on Next); Community chat: Not now and Create chat tab in the Next spot; Notifications: four switches; Done: Finish. Each switch matches the settings window. | open |
| Another character after the setup | The Community tab prompt in the new look: one gold button; closing is no. | open |

### CF-42 Dungeons tab in the new look
Compare with `docs/design/revamp-2026-10/dungeons.html`. Best on a character in range of a dungeon, with a friend in range too.

| Step | Expected | Status |
|---|---|---|
| `/cf`, Dungeons tab | Left column: "RUNS" (CF-46), then "IN RANGE FOR <character> (<level>)": per dungeon the name in gold, the range "17–24" right, "N friends" and "x / y quests" (green when you have all); the note about typical ranges at the bottom. | open |
| Log on an alt in another level range, open the tab | The list follows that character; your first character shows under "Alternatives for you" where it fits. | open |
| Click a dungeon | Gold bar on the row. Card: the name large, "levels 17–26 · Westfall"; "Suggested group" as five slots: Tank, Healer, three DPS with portrait, "<name> <level>" in class colour, "role · person"; your slot outlined gold; a missing tank or healer in orange "nobody in range"; free slots "+ open". | open |
| Ask who's up for it | The gold button with "Sends a chat line to friends with the addon"; clicking asks (CF-27) and the line turns into "Asked who's up for it · ..." with the answers. | open |
| Also in range | Others in range not in the group, one line each. | open |
| Quests | Left "Quests" with "x / y in your log", a green check on quests in your log, who else has them. | open |
| Footer | Left "Synced with <name> <time>", nothing on the right. Hover Ask now: what it does, and that it waits until combat ends. | open |
| Long card or list, small window | Both scroll with the mouse wheel (V62). | open |

### CF-41 Activity tab in the new look
Compare with `docs/design/revamp-2026-10/activity.html`. Best with a friend who levelled, quested and ran a dungeon with you today.

| Step | Expected | Status |
|---|---|---|
| `/cf`, Activity tab | Chips All, Level-ups, Dungeons, Together on top (All gold). Day headers "Today", "Yesterday", then e.g. "Monday 26 Oct" in the serif small caps, a thin gold line under each. | open |
| An entry | A round class portrait, "<name> on <character>" (name gold, character in class colour), below it a gold LEVEL UP chip "22 → 24" (no animation yet), "questing in" with zone pills and "+N zones", "· N quests done", runs and profession ranks as text; the time right (V63). | open |
| Played together | One entry "<you> and <friend> together" with two overlapping portraits and "ran <dungeon>". | open |
| A friend with activity on two characters | "and 1 more character", "Show all (N)" opens the other character's pieces under "on <character>"; "Show less" folds it. | open |
| Each chip | Level-ups: only entries with a level change (whole entries); Dungeons: entries with a dungeon, raid or battleground; Together: the together entries. No match: "Nothing of this kind in the last 7 days." | open |
| Close and open the window | The chips start at All again. | open |
| Footer | Left empty, right "Keeps 7 days". Friends tab: its own footer again. | open |
| Many entries | The feed scrolls with the mouse wheel (V62). | open |

### CF-40 Friends tab in the new look
Compare with `docs/design/revamp-2026-10/friends.html`. Needs a friend with the addon (for professions, talents and shared quests).

| Step | Expected | Status |
|---|---|---|
| `/cf`, Friends tab | Left a darker column (270 px) with the search box and its grey hint; per person a header (arrow, online dot green or grey, name, the addon icon for friends who run it, character count right); under it the characters: round class portrait with a green dot on the one being played, name in class colour, level right. | open |
| A friend's character that shares quests with you | A small page icon with the number of shared quests before the level. | open |
| Click a person's arrow; `/reload` | The person folds (arrow points right) and stays folded after the reload. Click again: unfolds. | open |
| Click a person's name | Their card: name, BattleTag, the addon line, status, "Characters" (click one to open it, right-click for the menu), "Quests you share" with "them" and "you". The header gets a soft gold highlight. | open |
| Click a friend's character | Gold bar on the row. Card: 52 px portrait, name large in class colour, "Class · played by <name> · online in <zone>" (or "offline, last seen in <zone> <time>"), Whisper and Invite buttons right. | open |
| The tiles | LEVEL with a bar in class colour (full at 60), ITEM LEVEL, ROLE with "from talents" or "set by player". | open |
| Professions and Talents | Professions as gold bars with darker shading up to the current maximum and lines at 75/150/225 (secondary ones grey); "Talents" with "a / b / c" next to it and one bar per tree, the fullest tree in pale gold. | open |
| Quests you share | Grouped by zone, dungeons first with a blue DUNGEON tag; more than five: "Show all N →", then "Show fewer". | open |
| Whisper, Invite on an online friend's character | Opens a whisper to that character / invites them. On an offline character and your own: both buttons dimmed and doing nothing. | open |
| Right-click a person or character in the list (CF-37) | The menu opens above the window, as before. | open |
| Many people, or a small window | The list and the card scroll with the mouse wheel; a thin gold bar on the right shows where you are (V62). | open |
| Footer | Left "Synced with <name> <time> · N characters from M friends", nothing on the right. | open |
| Activity, Dungeons, back to Friends | The other tabs look as before; Friends comes back with the same selection and search text. | open |

### CF-39 Kit and window shell
Compare with `docs/design/revamp-2026-10/friends.html` (the window around the content).

| Step | Expected | Status |
|---|---|---|
| `/cf` (after the update) | The new window, 880 × 600, centred: dark navy panel, thin gold border with small gold diamonds on the corners, a soft shadow. | open |
| Title bar | Shield emblem, the community name in a serif small-caps font, "CommunitiesForever" small and grey, "● N online" in green, a gear and a close button (V61: fonts, glow). | open |
| Tabs | Friends, Activity, Dungeons in the serif font; the active one pale gold with a gold underline; Dungeons with a round gold badge when runs are planned. Clicking switches; the old tab content works as before. | open |
| Footer | No hint text on the right. | open |
| Drag the title, resize from the bottom-right corner, `/reload` | Position and size are kept; it does not get smaller than 700 × 480. | open |
| Gear button | The settings open. Close button and Esc close the window. | open |
| Right-click a character (CF-37) | The menu still opens above the window. | open |

### CF-31 Hidden community channel
Needs two characters in the community on this build, **not** Battle.net friends (or `/cf sync debug` shows the Battle.net traffic too).

| Step | Expected | Status |
|---|---|---|
| Log in on both | No new channel in any chat window, no "Joined Channel" line, no extra chat tab. `/chatlist` may list a channel `cf` + 8 characters: that is it. | open |
| `/cf sync debug` on both, then one levels up (or `/cf sync`) | `to the community channel: HELLO ...` once, and no `to <name>: HELLO` whisper to the other (after the first exchange at login). The other's level updates as before. | open |
| One logs out | `to the community channel: BYE`; the other shows them offline within seconds. | open |
| One character on the previous release (v0.4.0-beta1) | That one is still whispered (`to <name>: HELLO`), and syncing works both ways. | open |

### CF-36 Smart filter in the Friends tab
| Step | Expected | Status |
|---|---|---|
| `/cf`, Friends tab | Inside the tab, above the list: a search box (not touching the window border) with the grey hint "e.g. tailoring 150, mage 20-30" (V62), the count ("N of M") under it on the right. Not on the Activity and Dungeons tabs. Switching tabs and back keeps the text. | open |
| Click in the box | The hint disappears; typing works (keys do not move the character). | open |
| `tailoring 150` (or a profession someone has) | Only people with a character at that rank, only those characters, expanded; "N of M" next to the box. | open |
| `mage 20-30`, `healer`, a zone name, part of a name | Each narrows the list as expected. | open |
| A word nobody matches | "No character matches ..." in the card area. | open |
| Clear the box | Everyone again, with groups expanded or collapsed as before. | open |
| Close the window and open it again | The box is empty. | open |

### CF-35 Newer version notice
Needs two clients on different **release** builds (from CurseForge or WowUp; a `build.ps1` dev build never shows the line).

| Step | Expected | Status |
|---|---|---|
| The one on the older release logs in while the other is online | One chat line: "A newer version of CommunitiesForever is available (v...). Update with the CurseForge app or WowUp." | open |
| Stay online, let the other level up or `/cf sync` | No second line this session; after `/reload` at most once more. | open |
| The one on the newer release | Never gets the line. | open |

### CF-34 "Uses the addon" mark
| Step | Expected | Status |
|---|---|---|
| `/cf`, Friends tab, a friend who runs the addon | A small icon (the minimap button's) after their name in the list; on their card "Runs CommunitiesForever." with the icon. | open |
| A community member or friend without the addon | No icon; their card says "Does not run CommunitiesForever: only what the community list shows (class, level, zone)." | open |
| Your own row and card | No icon, no line. | open |

### CF-33 Minimap button tooltip: who is online
| Step | Expected | Status |
|---|---|---|
| Nobody else online, hover the minimap button | "CommunitiesForever", then "Nobody online right now.", then Left-click / Right-click. | open |
| A friend (or community member with the addon) online, hover | One line per person: display name left, their character in class color with level right (V55), sorted by name. | open |
| The friend switches character or logs out, hover again | The line shows the new character / the person is gone. | open |

### CF-32 Keybinding and Esc closes the window
| Step | Expected | Status |
|---|---|---|
| Esc → Options → Keybindings | A "CommunitiesForever" section (under AddOns, or its own header; note where) with "Open or close the window", unbound. | open |
| Bind a key, press it twice | The window opens, then closes. | open |
| `/cf`, then walk with W/A/S/D and type in chat | Movement and chat work normally while the window is open. | open |
| `/cf`, press Esc | The window closes and the game menu does **not** open. Esc again: the game menu opens. | open |
| `/cf setup`, press Esc | The setup closes (counts as skipped, as with the X). | open |
| In combat: `/cf`, press Esc | No error; the game menu opens and the window stays (Esc on the window is off in combat). After combat, close with `/cf`, open again: Esc closes it. | open |

### Passive without a community
Needs a character on an account where no character ever selected a community (or a fresh WTF: rename
`WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` first, rename it back afterwards), and that
character in no community.

| Step | Expected | Status |
|---|---|---|
| Log in, wait 10 s | No setup wizard, no minimap button, no CommunitiesForever chat lines (also not when a Battle.net friend with the addon logs in). | open |
| `/cf` | The window says "You're not in a community yet." with how to join by invite link or code. | open |
| `/cf sync debug`, wait for a friend with the addon to log in | No `[sync]` lines: nothing is sent or received. | open |
| Join a community (a friend's invite link, or create one in Blizzard's Communities window) | Within seconds: "Showing community ..." in chat, the setup wizard opens, the minimap button appears (unless switched off), and with `/cf sync debug` on, HELLO lines to friends online. | open |
| A character of the same account that is in no community, after another character selected one | Not passive: the window shows how to join the selected community (as before). | open |

### Setup: chat tab button in the Next spot
| Step | Expected | Status |
|---|---|---|
| On a character without a Community chat tab: `/cf setup`, Next until "Community chat" | The buttons read Back, Not now, Create chat tab (where Next was). | open |
| Click **Create chat tab** | A Community chat tab appears and the setup is on "Notifications". Back: the chat step says "This character has a Community chat tab" with Skip and Next. | open |
| Close the new tab, `/cf setup` again to the chat step, click **Not now** | No tab is created; the setup goes on to "Notifications". | open |

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
| (Needs a third account.) You know someone only through a friend's relay (`Updated ... via <friend>` on their card), then they come online in the community (not your Battle.net friend) | Within ~10 s their card no longer says `via`: their own record arrived over the community. | open |

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

