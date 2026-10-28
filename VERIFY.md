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
| V48 | Which way can an addon get a friend into your party from a click? (CF-27; inviting by name works, see API-FINDINGS) | Same `/fp invite` with a friend online in Forever, you not in a group: click `[invite by name]` (does the friend get an invite? the name has a space), leave the group; `[invite via Battle.net]`, leave; then let the friend run `/fp invite` and click `[ask them for an invite]` on you (do you get a "wants to join" popup?). Send both logs: the `C_PartyInfo...` / `BNInviteFriend` lines and the `INVITE EVENT` lines (blocked actions show as `ADDON_ACTION_BLOCKED`). | open |
| V50b | Do all 30 burst whispers arrive? (CF-28: send rate) | Copy the **current** `tools/FriendProbe` first (the 2026-10-19 run used an old copy that counts only in a delayed summary, and the `/reload` came after 9 s). `/fp start`, wait 15 s, then `/reload`: the log shows `received V50:burst 30 so far` (or a lower count). | open |
| V51 | Do addon whispers reach a character of the other faction? (CF-28) | Both characters need FriendProbe: `/fp comm whisper <the other character's name>`; the other log should show `addon message <- ... V51:whisper`. | open |
| V52 | How stale does community presence get after a logout? (CF-28: online status for non-friends; CF-15 bug) | A few minutes after a member logged out, `/fp start`: under V52 COMMUNITY PRESENCE, does that member still show `Online`? | open |
| V53 | Is the "No player named X is currently playing" line hidden after an addon whisper to someone who just went offline? (CF-28) | With a community member running this build: let them log out, then (within a minute, before the community list updates) `/cf sync`. Expected no "No player named ..." line in chat (`ChatFrameUtil.AddMessageEventFilter` / `ChatFrame_AddMessageEventFilter` and `ERR_CHAT_PLAYER_NOT_FOUND_S` are unverified). If the line shows, send it. | open |
| V54 | Do `frame:EnableKeyboard`, `frame:SetPropagateKeyboardInput` and an `OnKeyDown` script work on an addon window outside combat, and does `Bindings.xml` with `header` and `category="ADDONS"` show the binding? (CF-32) | See the CF-32 steps: Esc closes the window without opening the game menu, walking keys still work with the window open, and the binding shows in Esc → Options → Keybindings. If anything errors, send the error text. | open |
| V55 | Does the minimap button tooltip (LibDBIcon's `GameTooltip`) have `AddDoubleLine`? (CF-33; without it the names fall back to one line each) | See the CF-33 steps: names left, characters right-aligned. | open |
| V59 | Does the hidden sync channel work (CF-31)? `JoinTemporaryChannel` (or `JoinChannelByName`), addon messages with `SendAddonMessage(prefix, text, "CHANNEL", index)`, and which `CHAT_MSG_ADDON` arguments name the channel. | See the CF-31 steps: `/cf sync debug` shows `to the community channel: HELLO ...` when it sends there. If HELLOs keep going as whispers to members on this build, send the `[sync]` lines and the output of `/dump GetChannelList()` (is a `cf...` channel in it?). Nothing breaks when it fails: the addon keeps whispering. | open |
| V61 | Do the kit's drawing calls work on Forever (CF-39)? `FontString:SetFont` with the bundled `.ttf` files, `Texture:SetGradient` with `CreateColor`, `CreateMaskTexture` + `AddMaskTexture`, `SetResizeBounds`, `C_ClassColor.GetClassColor`, the round class icons (`UI-Classes-Circles` with `CLASS_ICON_TCOORDS`), and the TGA textures in `media/textures`. | See the CF-39 steps: if text shows in the game's own font, a texture is a green square or missing, or the title bar has no glow, send a screenshot and any Lua error. | open |
| V62 | Do the Friends tab's native calls work (CF-40)? An `EditBox` with `SetTextInsets`, `SetAutoFocus`, `HasFocus`, `ClearFocus` and the focus and text scripts; a `ScrollFrame` with `SetScrollChild`, `SetVerticalScroll`, `EnableMouseWheel` and `OnMouseWheel`; `Texture:SetRotation` for the fold arrow. (Replaces V56: the AceGUI search box is gone.) | See the CF-40 steps: typing in the search box, scrolling a long list and the card with the mouse wheel, the arrow pointing right on a folded person. If anything errors, send the error text. | open |
| V63 | Does `date("%H:%M", t)` give the local clock time of a server timestamp (CF-41: the time on Activity entries)? | See the CF-41 steps: the time right of each entry matches when it happened. Without `date` the time stays empty. | open |
| V64 | Do the ambient effects work (CF-43)? `frame:CreateAnimationGroup` with a `Translation` animation (`SetOffset`, `SetDuration`, `SetStartDelay`, `SetLooping("REPEAT")`), `SetClipsChildren` and `Texture:SetBlendMode("ADD")`. | See the CF-43 steps: a soft light streak slides across the window title every few seconds and across LEVEL UP chips; off with Ambient effects. If nothing moves, send any Lua error. | open |
| V65 | Does `ColorPickerFrame:SetupColorPickerAndShow` (with `swatchFunc`, `cancelFunc`) and `ColorPickerFrame:GetColorRGB` open and report the colour (CF-43: chat colour)? | See the CF-43 steps: clicking the colour square opens Blizzard's colour picker; the community chat changes colour while picking; Cancel puts the old one back. | open |
| V66 | Do `Settings.RegisterCanvasLayoutCategory(frame, name)` and `Settings.RegisterAddOnCategory(category)` add the page under Options › AddOns (CF-43)? | Esc → Options → AddOns: a "CommunitiesForever" entry with the line and an "Open settings" button that opens the settings window. | open |

| V67 | Is a Lua file in the addon folder that changed on disk re-read on `/reload`, and does a file the TOC lists but that was missing at game start load on `/reload` or only after a restart? (CF-45: the uploader rewrites `Data\Runs.lua` while the game runs) | Copy the new `tools/FriendProbe`, start the game, `/fp reloadfile`: `V67 ReloadProbe.lua mark A \| ReloadProbeLate.lua not loaded`. With the game still running, in PowerShell (your game folder in the first line): `$fp = "<game folder>\Interface\AddOns\FriendProbe"`, then `Set-Content "$fp\ReloadProbe.lua" 'FriendProbeReloadMark = "B"'` and `Set-Content "$fp\ReloadProbeLate.lua" 'FriendProbeLateMark = "late"'`. In game `/reload`, `/fp reloadfile`: is the mark `B` (changed file re-read), and is the late file `late` or `not loaded`? Then exit the game, start it again, `/fp reloadfile` once more. Afterwards `Remove-Item "$fp\ReloadProbeLate.lua"`. | open |
| V68 | May an addon call `C_UI.Reload()` or `ReloadUI()` from a button click? (CF-47: "Reload now to post on Discord") | `/fp reload`, click `C_UI.Reload()`: the UI reloads and the log shows `V68 reloaded by C_UI.Reload`. Then `/fp reload` again and click `ReloadUI()`. If nothing reloads, the log shows `did not reload within 2 s` and any `ADDON_ACTION_BLOCKED` line; `/reload` by hand and send the log. | open |
| V69 | Can one click invite several friends in a row (`C_PartyInfo.InviteUnit` per name), the first invite making a party? (CF-48: Invite everyone ready) | With at least two friends online in Forever and you not in a group: `/fp inviteall`, click `Invite all N`. Do all friends get an invite (also the second, while the first hasn't accepted yet)? Let them accept, wait 10 s (`V69 after 10 s: in group N`), `/reload` and send the log (the `V69 C_PartyInfo.InviteUnit` lines and `INVITE EVENT` lines). | open |
| V70 | Do `C_ChatInfo.InChatMessagingLockdown()` and `IsEncounterInProgress()` exist, and are they true during a boss fight? (CF-46: runs are never sent during encounters, keystones or PvP matches) | Inside a dungeon, during a boss fight: `/run print(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown(), IsEncounterInProgress and IsEncounterInProgress())`, and once more outside the fight. Expected `true true` in the fight, `false false` outside (`nil` means the function is missing: then only battlegrounds count). | open |

| V71 | Does `time({ year, month, day, hour, min })` exist and give the UTC seconds of a local date and time? (CF-47: Plan a run turns your PC-clock time into UTC) | `/run print(time({ year = 2026, month = 11, day = 6, hour = 20, min = 30 }), GetServerTime())`: a number close to the server time (differing by the days and hours to that date). `nil` or an error: Plan a run says it can't convert the time. | open |

| V72 | Does `ChatFrameUtil.OpenChat("/w <name> <text>")` (or `ChatFrame_OpenChat`) open the chat input with the whisper and text filled in? (CF-48: Whisper on the start panel) | On the CF-48 start panel, click Whisper on a friend who is on another character. Expected: the chat input opens as a whisper to that character with "You're on … Switch to …?" filled in, not sent yet. If it opens empty (or not at all), say which. | open |
| V79 | Do `GetPVPLifetimeStats`, `UnitPVPRank` with `GetPVPRankInfo(rankID, "player")`, `GetPVPThisWeekStats` and `GetStatistic(60)` (total deaths) exist and give numbers, and does `PLAYER_PVP_KILLS_CHANGED` fire on an honorable kill? (CF-52) | `/run print(GetPVPLifetimeStats and GetPVPLifetimeStats(), UnitPVPRank and UnitPVPRank("player"))`, `/run print(GetPVPRankInfo and GetPVPRankInfo(UnitPVPRank("player"), "player"))`, `/run print(GetPVPThisWeekStats and GetPVPThisWeekStats(), GetStatistic and GetStatistic(60))`. Expected numbers (a rank name and number for a ranked character; `nil` means missing: send which). Then see the CF-52 steps. | open |
| V80 | Do `DUEL_WINNER_KNOCKOUT` and `DUEL_WINNER_RETREAT` match the duel lines in chat (`CHAT_MSG_SYSTEM`), with the winner as the first argument in both? (CF-52) | `/run print(DUEL_WINNER_KNOCKOUT, "/", DUEL_WINNER_RETREAT)`. Expected (enUS) `%1$s has defeated %2$s in a duel / %2$s has fled from %1$s in a duel`. Then the CF-52 duel steps: a win, a loss and fleeing the duel area. | open |
| V81 | Where can the cause of a death come from? (CF-52) Can an addon register `COMBAT_LOG_EVENT_UNFILTERED` (see also V75); do `MIRROR_TIMER_START`/`MIRROR_TIMER_STOP` fire with `BREATH` and `EXHAUSTION`; does `C_DeathRecap.GetRecapEvents()` without an id give the latest death's events (`event`, `environmentalType`, `sourceGUID`, `timestamp`)? | `/run print(C_DeathRecap and C_DeathRecap.GetRecapEvents)`. After a death: `/dump C_DeathRecap.GetRecapEvents()`. Then the CF-52 death steps: the `/cf self` deaths and the saved file's `deaths` causes. If the combat log is blocked, a Lua error may show once at login (send it). | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

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
| Through the steps | Community: the dropdown; Your name: the field (saved on Next); Community chat: Not now and Create chat tab in the Next spot; Sharing and notifications: four switches; Done: Finish. Each switch matches the settings window. | open |
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
| Footer | Left "Synced with <name> <time>", right "Group asks wait until combat ends". | open |
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
| Footer | Left "Activity is shared only by friends who turned on "Share my activity".", right "Keeps 7 days". Friends tab: its own footer again. | open |
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
| Footer | Left "Synced with <name> <time> · N characters from M friends", right "/cf to open · drag the title to move". | open |
| Activity, Dungeons, back to Friends | The other tabs look as before; Friends comes back with the same selection and search text. | open |

### CF-39 Kit and window shell
Compare with `docs/design/revamp-2026-10/friends.html` (the window around the content).

| Step | Expected | Status |
|---|---|---|
| `/cf` (after the update) | The new window, 880 × 600, centred: dark navy panel, thin gold border with small gold diamonds on the corners, a soft shadow. | open |
| Title bar | Shield emblem, the community name in a serif small-caps font, "CommunitiesForever" small and grey, "● N online" in green, a gear and a close button (V61: fonts, glow). | open |
| Tabs | Friends, Activity, Dungeons in the serif font; the active one pale gold with a gold underline; Dungeons with a round gold badge when runs are planned. Clicking switches; the old tab content works as before. | open |
| Footer | "/cf to open · drag the title to move" in small grey text. | open |
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

