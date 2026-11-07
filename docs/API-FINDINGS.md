# Verified API findings (Forever beta)

Source: FriendProbe run on Forever beta, build `1.60.1 70450 (Oct 15 2026)`, TOC 16001. Two clients, both BNet friends, same PvP ruleset, both Horde. All values readable out of combat (no secret values encountered).

## Client
| API | Result |
|---|---|
| `GetBuildInfo()` | `1.60.1  70450  Oct 15 2026  16001` |
| `WOW_PROJECT_ID` | `18` |
| `UnitName("player")` | `"Ves Doombringer"` (first + last name, one string) on some characters; on others first and last name are split: `"Marks", "Man"` (last name in the realm slot) (V9). Use `GetUnitName("player", true)` for the full name. |
| `GetUnitName("player", true)` | `"Marks Man"`: full name, also where `UnitName` splits it (V9) |
| `UnitFullName("player")` | `"Ves Doombringer"` (realm return nil for own realm) |
| `GetRealmName()` / `GetNormalizedRealmName()` | `"Classic Beta PvP"` / `"ClassicBetaPvP"` |
| `UnitGUID("player")` | `"Player-4619-01627852"` |
| `UnitClassBase("player")` | `"PALADIN"` |
| `BNGetInfo()` | 2nd return is the account's BattleTag (`"Name#1234"`); 1st (presenceID) is nil |
| `GetNumSkillLines`, `GetSkillLineInfo` | do NOT exist |

## Professions
`GetProfessions()` returns 5 slots with nil holes (prof1, prof2, archaeology, fishing, cooking). Loop `k = 1, 5`, not `ipairs`.
`GetProfessionInfo(index)` example: `Mining, 136248, 64, 150, 2, 54, 186, 0, -1, 0, "Mining"`
= name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, **skillLine (186)**, skillModifier, specIndex, specOffset, skillLineName.
Cooking appeared in slot 5 (`2/75`, skillLine 185). First Aid: unknown (no character with it tested).

## Battle.net presence
`C_BattleNet.GetFriendAccountInfo(i)` + `C_BattleNet.GetFriendNumGameAccounts(i)` + `C_BattleNet.GetFriendGameAccountInfo(i, j)` work. Example game account:
`clientProgram="WoW", wowProjectID=18, isOnline=true, characterName="Garraka Doombringer", realmName="ClassicBetaPvP", realmDisplayName="Classic Beta PvP", className="Mage" (LOCALIZED), characterLevel=11, factionName="Horde", playerGuid="Player-4619-01789956", gameAccountID=5`
`accountInfo.battleTag` = `"Solvar#2032"`.

## Messaging
- `C_ChatInfo.RegisterAddonMessagePrefix` works.
- `BNSendGameData(gameAccountID, prefix, text)`: works both directions. Received via `BN_CHAT_MSG_ADDON(prefix, text, channel="WHISPER", senderGameAccountID)`. `C_BattleNet.GetGameAccountInfoByID(senderID)` resolves the sender.
- Payloads of 4000, 4090, 4200 bytes sent without Lua error. **Receipt not verified.** Treat the limit as unknown; chunk at 3500.
- `C_ChatInfo.SendAddonMessage(prefix, text, "WHISPER", "Garraka Doombringer")` returns `0` (success) and arrives. Full name with space works as target. (Not used in V1.)

## Communities (C_Club)
- `C_Club.GetSubscribedClubs()`, `GetClubMembers(clubId)`, `GetMemberInfo(clubId, memberId)`, `FocusMembers(clubId)` exist and work.
- Test club: `clubId=23125681, clubType=1 (Character), crossFaction=false, memberCount=2`.
- Member fields returned: `classID, clubType, faction, guid, isSelf, level, memberId, name, presence, race, role, zone`.
  **No BattleTag, no bnetAccountId.**
- Membership is **per character**: alts of a member are NOT members unless invited themselves.
- Data loads async: fire `FocusMembers`, then re-read after `CLUB_MEMBERS_UPDATED`.
- `C_Club.GetSubscribedClubs()` returns an empty table on a character in no community and no guild (Forever,
  2026-11-05).

### Creating a community (Forever, 2026-11-05)
No community can be created on Forever at launch (CF-83 picks the guild instead):
- `C_Club.ValidateText` returns `3` (TooShort) for every name and short name, for both the Character and the
  BattleNet club type; the Create button in Blizzard's dialog stays grey.
- `C_Club.CreateClub(...)` is protected: `/run C_Club.CreateClub(...)` gives "blocked from an action only available
  to the Blizzard UI".
- `CommunitiesCreateDialog` is a forbidden frame: touching it from `/run` gives "Attempt to access forbidden object
  from code tainted by an AddOn".

### Guild invites (Forever, 2026-11-05, V126)
FriendProbe on Forever, build 9 of the addon (develop 5598ec0), with a friend's alt (CF-87):
- `C_GuildInfo.Invite(name)` / `GuildInvite(name)` are **forbidden for addon code, also inside a button click**:
  both "Invite target, no click" and "Invite target with this click" give `ADDON_ACTION_FORBIDDEN` and Blizzard's
  dialog "<Addon> has been blocked from an action only available to the Blizzard UI. You can disable this addon and
  reload the UI." No invite is sent. The addon's automatic invite (CF-84) showed the same dialog for
  CommunitiesForever, and the popup's plain Invite button sent nothing.
- Typing `/ginvite <alt name>` in chat by hand works: the invite arrives. The alt's name was "First Last" (with the
  space), on another realm id of the same mega-realm.
- **V134 (build 10):** a `SecureActionButtonTemplate` button with `type` = `macro` and `macrotext` =
  `/ginvite <name>` made by an addon does not run it: the game says "Macro script disabled".
- **V135 (build 10):** `/ginvite <name>` put in the chat input by the addon (`ChatFrameUtil.OpenChat`) shows in the
  input, but Enter gives Blizzard's "CommunitiesForever has been blocked from an action only available to the
  Blizzard UI". The edit box opened and filled by addon code is tainted, so the slash command runs tainted.
- **V136, V137 (build 12, CF-88):** the member's invite window works in game (Nico, 2026-11-05): the copy box takes
  the focus with the text highlighted, the key caps light on their events (EditBox `OnKeyDown` with
  `IsControlKeyDown`, `OnEnterPressed`), and a read-only post-hook on the chat inputs
  (`ChatFrame<i>EditBox:HookScript("OnTextChanged", …)`, reading `GetText()`) lights the Ctrl+V cap **without
  blocking the pasted `/ginvite`**. The focus rule's helpers (`GetUnitSpeed`, `ChatEdit_GetActiveWindow` /
  `ChatFrameUtil.GetActiveWindow`, `GetCurrentKeyBoardFocus`), the sound, the mouse atlas and the check texture were
  not checked one by one; they stay guarded.
- So an addon cannot send a guild invite on Forever in any way. Only a `/ginvite` the player types or pastes into
  chat runs. CF-87 shows `/ginvite <name>` in the addon's own edit box to copy.

## Verified during development
Recorded by Nico in `VERIFY.md`, 2026-10-17.
| API | Result |
|---|---|
| Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceGUI, AceConfig), LibDBIcon, LibDataBroker, LibSerialize, LibDeflate | Load under TOC 16001 without Lua errors (V4) |
| `C_AddOns.GetAddOnMetadata(addon, "Version")` | Exists, returns the TOC `## Version` (V10) |
| `GetAverageItemLevel()` | Exists, returns 3 numbers, all `1.5625` on the test character (V1). Assumed retail order: overall, equipped, PvP. |
| `ScrollUtil`, `CreateScrollBoxListLinearView` | Exist (V5) |
| `TooltipDataProcessor`, `TooltipDataProcessor.AddTooltipPostCall`, `Enum.TooltipDataType.Unit` | Exist (V6) |
| `C_EventUtils.IsEventValid` | Exists, `IsEventValid("PLAYER_LEVEL_UP")` is true (V13) |
| `C_Timer.NewTimer` | Exists (V14) |
| `UnitRace`, `UnitLevel`, `UnitFactionGroup` | Work; snapshot stores raceID (3rd return of `UnitRace`), level and faction (V11, CF-03) |
| First Aid | Is a profession. With First Aid, Fishing and Cooking: `GetProfessions()` slot 3 = First Aid, 4 = Fishing, 5 = Cooking. First Aid skillLine = 129 (V7). Fishing skillLine = 356 (CF-12) |
| `SKILL_LINES_CHANGED` | Fires on a profession skill-up (V12, CF-03) |
| `PLAYER_LEVEL_UP` | Fires; the new level is stored right after the ding (V12, CF-03) |
| `PLAYER_EQUIPMENT_CHANGED` | Fires on gear swaps (V12, CF-03) |
| `INITIAL_CLUBS_LOADED`, `CLUB_ADDED`, `CLUB_REMOVED`, `CLUB_UPDATED` | Valid events per `C_EventUtils.IsEventValid` (V15); leaving a community fires the removal path (CF-05) |
| `CLUB_MEMBERS_UPDATED`, `CLUB_MEMBER_ADDED`, `CLUB_MEMBER_REMOVED`, `CLUB_MEMBER_PRESENCE_UPDATED`, `CLUB_MEMBER_UPDATED` | Valid events (V17). Invite, kick, log in/out and zone changes update `C_Club.GetMemberInfo` and fire member events without polling (V18, CF-06) |
| `BNET_CLIENT_WOW` | `"WoW"` (V19) |
| `BN_FRIEND_INFO_CHANGED`, `BN_FRIEND_ACCOUNT_ONLINE`, `BN_FRIEND_ACCOUNT_OFFLINE`, `BN_CONNECTED` | Valid events (V19). Log out, log in and character switches of a friend update `C_BattleNet` game accounts; Battle.net app and other WoW versions report a different clientProgram or wowProjectID (CF-07) |
| `PLAYER_LOGOUT` | Fires on logout and character switch early enough for the change to be saved (V22, CF-12) |
| Unit tooltip post-call | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ...)` adds lines on hovered players, also in dungeons and combat without errors (V28, CF-14) |
| Talent API | No classic talent tabs: `GetNumTalentTabs` and `GetTalentTabInfo` do not exist. `C_ClassTalents` and `C_Traits` exist; `GetSpecialization` does not. Events `CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED` exist (V20). Tree layout: see V29. |
| Talent layout (V29, Warrior, first probe) | `C_ClassTalents.GetActiveConfigID()` -> config "Warrior" with one tree (1117) holding 52 nodes (about all three Vanilla trees together) and one point pool (`traitCurrencyID` 3820: 22 max, 17 spent). Nodes have `ranksPurchased`, `maxRanks`, `posX`/`posY`, `groupIDs`, `subTreeID` nil. All purchased (Arms) talents share group 11650 and x 1020-2220. `C_SpecializationInfo` and `GetNumSpecializations` exist. |
| Talent layout (V29, all nodes) | The three Vanilla trees sit side by side in the one tree: Warrior Arms at x 1020-2820, Fury 5020-6820, Protection 9080-10880 (big gaps between). Each has its own group ID on all its nodes (11650, 11657, 11670; class specific). Forever has modified talents (e.g. Spearing Strike, Bloodthrill, Gore Drinker). |
| Specializations | One per class: `C_SpecializationInfo.GetSpecialization()` = 1, `GetSpecializationInfo(1)` = 1491 "Warrior" role `DAMAGER`; `GetNumSpecializations()` = 1. No spec per Vanilla tree, so the tree and role have to be derived from talents. `GetSpecializationInfo` (global) does not exist; `GetSpecializationRole` exists. |
| Quest log (V23) | Mainline API: `C_QuestLog.GetNumQuestLogEntries()` returns entries and quests (28, 20); `C_QuestLog.GetInfo(i)` gives `questID`, `title`, `level`, `isHeader`, `isHidden`, `isTask`, `suggestedGroup` (0 for normal quests); headers are areas: zones, dungeons ("Blackfathom Deeps"), "Crafting", the class name. `GetMaxNumQuestsCanAccept()` = 40. Also exist: `GetQuestIDForLogIndex`, `GetTitleForQuestID`, `IsComplete`, `GetQuestObjectives`, `GetLogIndexForQuestID`, `IsOnQuest`. Globals `GetQuestLogTitle`, `GetNumQuestLogEntries` do not exist. Events `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_REMOVED`, `QUEST_LOG_UPDATE`, `QUEST_COMPLETE`, `UNIT_QUEST_LOG_CHANGED` exist. |
| Dungeon icon (V32) | Atlas `worldquest-icon-dungeon` renders as an inline chat icon (`/fp icons`); picked for shared dungeon quests (CF-19). |
| Quest tags (V31) | `C_QuestLog.GetQuestTagInfo(questID)` returns a tag for dungeon quests (`tagName = "Dungeon"`); used with the dungeon header list (CF-19). Quest log headers also name dungeons ("Blackfathom Deeps", "Shadowfang Keep", "Wailing Caverns"); `GetInfo` has a `questClassification` field. Log size seen: 44 entries, 35 quests. |
| Calendar read (V33) | `C_Calendar` exists with `OpenCalendar`, `GetMonthInfo`, `GetNumDayEvents`, `GetDayEvent`, `OpenEvent`, `GetEventInfo`, `CreateCommunitySignUpEvent`, `EventSet*`, `AddEvent`, `EventSignUp`, `GetNumInvites`, `EventGetInvite`. After `OpenCalendar`, `CALENDAR_UPDATE_EVENT_LIST` fires and `GetDayEvent(monthOffset, day, i)` lists events with `title`, `calendarType` (string, e.g. `HOLIDAY`), `eventType`, `clubID`, `startTime`/`endTime` (`year, month, monthDay, weekday, hour, minute`), `invitedBy`, `inviteStatus`. `Enum.CalendarEventType`: Raid 0, Dungeon 1, PvP 2, Meeting 3, Other 4. `Enum.CalendarType`: Player 0, Community 1, Holiday 4. Only holidays were listed (no community event existed yet). |
| Calendar create (V34) | Blocked: `CreateCommunitySignUpEvent` and the `EventSet*` calls run, `CanAddEvent` is true, but `AddEvent` from a button click fires `ADDON_ACTION_BLOCKED` (protected under Midnight). Addons cannot create calendar events. |
| Calendar community event (V42) | A community event made by hand shows in `GetDayEvent` with its `title`, `startTime` and your `inviteStatus` (calendarType not `HOLIDAY`), so the Dungeons tab lists it (CF-24). `ToggleCalendar()` opens Blizzard's calendar from a button click. |
| Calendar sign-ups (V43) | `C_Calendar.OpenEvent(offset, day, index)` fires `CALENDAR_OPEN_EVENT`; then `GetNumInvites()` and `EventGetInvite(i).inviteStatus` give the sign-ups. The Dungeons tab counts them for runs planned within 3 days (CF-24). |
| QuestieDB at runtime (V44) | With Questie installed, `LibQuestieDB.RequireContract(3)` is `true` and `QuestDB.Get(id, "zoneOrSort")` gives the dungeon area ID, so the Dungeons tab lists every dungeon quest (CF-24). QuestieDB's Forever quest data is still identical to its Classic data (4,244 quests, checked 2026-10-18): it knows no Forever-only quests or dungeons yet. |
| `C_QuestLog.IsQuestFlaggedCompleted(questID)` (V45) | Works: `true` for a turned-in quest, `false` otherwise (current character only). |
| Dungeon lists (V46) | Dungeon Journal: `EJ_GetNumTiers()` is 0. Old Dungeon Finder (`GetLFGDungeonInfo`): only the Classic list (67 entries, all expansion 0, minimum levels only). **Group Finder** (`C_LFGList`, verified 2026-10-18): `GetAvailableCategories()` gives 2 (Dungeons), 116 (Quests & Zones), 120 (Custom); `GetAvailableActivities(categoryID)` and `GetActivityInfoTable(activityID)` give `fullName, shortName, minLevelSuggestion, maxLevelSuggestion, maxNumPlayers, mapID, difficultyID, isNormalActivity, isPvpActivity, displayType, filters`. Dungeons have `difficultyID` 1 and `maxNumPlayers` 5 (UBRS 10); zones `difficultyID` 0 and `maxNumPlayers` 0. 29 dungeon activities, including Forever's new ones: Hall of Thanes 13-20 (1984, map 3065), Ruins of Lordaeron 15-22 (1982, map 2999), Excavation Site: Wetlands 26-33 (1981, map 2998), City of Dalaran 28-35 (1983, map 2959). The Stockade was not listed on a Horde character. |
| Closed chat tab (V41) | `GetChatWindowInfo(i)` returns 10 values; a closed tab keeps its name with `shown` false and `docked` nil (window 7 "FP Community"); docked tabs have `docked` 1..n. |
| Talent tree order (V30) | Verified for Warrior and Paladin: the C_Traits tree runs left to right in the classic order. A level 22 Paladin's points (Vindication, Improved Judgement, Conviction, Seal of Command, Benediction, ...) all sit at posX 9080-10280, the right column = Retribution. |
| Addon message size and sends (V50) | `C_ChatInfo.SendAddonMessage` whispers (also to yourself) arrive at once. The limit is **255 bytes**: a 256-byte message reports `0` (Success) and arrives cut to 255, so longer text is truncated silently. 30 sends in a row all return `0` (no `AddonMessageThrottle`, 3). `Enum.SendAddonMessageResult`: Success 0, InvalidPrefix 1, InvalidMessage 2, AddonMessageThrottle 3, InvalidChatType 4, NotInGroup 5, TargetRequired 6, InvalidChannel 7, ChannelThrottle 8, GeneralError 9, NotInGuild 10, AddOnMessageLockdown 11, TargetOffline 12. A `CHANNEL` send to the community channel (index 6) returns `0` but does not come back to the sender (V49 open). |
| Realm date (V36) | `C_DateAndTime.GetCurrentCalendarTime()` returns a table (same `CalendarTime` shape as calendar event times: `year, month, monthDay, weekday, hour, minute`). |
| Community chat (V37) | The community channel is `Community:<clubId>:<streamId>` (`Chat_GetCommunitiesChannelName(clubId, streamId)`; the General stream is `streamId` 1, `streamType` 0); `GetChannelName(name)` gives its index (6 here); `GetChannelList` lists it after the world channels. From a button click: `ChangeChatColor("CHANNEL"..index, r, g, b)` recolors it; `FCF_OpenNewWindow(name)` opens a new chat tab (returns `ChatFrame6`) and `ChatFrame_RemoveAllMessageGroups(frame)` works, but **`ChatFrame_AddChannel` does not exist** (V39: find the replacement); `FCF_StartAlertFlash(ChatFrame1)` flashed General, the window that shows the channel; `PlaySound(SOUNDKIT.TELL_MESSAGE)` plays (3081). `GetChatWindowChannels(i)` lists the channels per window. Blizzard's default color for `ChatTypeInfo.COMMUNITIES_CHANNEL` is r 1, g 0.75, b 0.75 with `flashTab = false`. Nothing was blocked; `issecretvalue` exists. |
| Community messages (V38) | `CHAT_MSG_COMMUNITIES_CHANNEL` arrives with the text as a `\|Kx1\|k` token (not readable), but the sender name (arg 2, "First Last") and GUID (arg 12) are plain. `CLUB_MESSAGE_ADDED` gives `clubId, streamId, messageId`. So your own messages can be skipped by GUID. |
| Chat window channels (V39) | `ChatFrame_AddChannel` is gone; chat windows are mixin frames with `frame:AddChannel(channelName)` (returns the channel index), `frame:RemoveChannel`, `frame:ContainsChannel`, `frame:RemoveAllChannels`. `FCF_OpenNewWindow("FP Community")` + `ChatFrame_RemoveAllMessageGroups(frame)` + `frame:AddChannel("Community:<clubId>:<streamId>")` gives a tab with only the community chat. Also present: `ChatFrame_AddCommunitiesChannel`, `ChatFrameUtil.AddCommunitiesChannel`, `ChatFrameUtil.GetCommunitiesChannelColor`. |
| `SELECTED_CHAT_FRAME` (V40) | Points at the chat tab you are looking at: with the community chat in several tabs, the selected one does not flash (CF-25 verified). |
| Instance info and bosses (V35, dungeon part) | Verified 2026-10-19 with a 5-player Ruins of Lordaeron run. `GetInstanceInfo()` inside: name `Ruins of Lordaeron`, type `party`, difficulty 1 `Normal`, max 5, instanceID 2999 (= the Group Finder `mapID`). On the first `PLAYER_ENTERING_WORLD` inside, difficulty and max are still 0; `ZONE_CHANGED_NEW_AREA` in the same second has them. After leaving, `PLAYER_ENTERING_WORLD` shows type `none` with a stale difficulty 1. Outside instances: continent name, type `none`, instanceID (0 Eastern Kingdoms, 1 Kalimdor). `GetRealZoneText()` can be nil on the first `PLAYER_ENTERING_WORLD` and is set by `ZONE_CHANGED_NEW_AREA`. `ENCOUNTER_START` passes `encounterID, name, difficultyID, groupSize` (`3353, Witherfang, 1, 5`); `ENCOUNTER_END` the same plus `success` (1 on a kill) and a 6th argument, a table. **`BOSS_KILL` did not fire** for any of the 6 dungeon bosses (registered, never logged): `ENCOUNTER_END` carries the kills (the `BOSS_KILL` fallback stays for raids, harmless). `GROUP_ROSTER_UPDATE` fires often, also without a change; `GetNumGroupMembers()` counts you, `party1..4` give name and GUID. Group members' GUIDs can carry another server ID than yours (`Player-4613-...` next to `Player-4619-...`) on the same mega-realm. CF-23 recorded the run on both clients (6 bosses, `with` the friend's GUID) and showed one shared line. Battlegrounds still to be logged (V35b). |
| Right-click menu (V57, CF-37) | `MenuUtil.CreateContextMenu(owner, generator)` opens Blizzard's context menu; `root:CreateTitle` and `root:CreateButton(text, fn)` work and the callbacks arrive. It opens from a plain button and from AceGUI tree rows: hook `OnMouseUp` on `tree.buttons` (AceGUI creates them only when it lays the tree out, so hook after each `RefreshTree`); both person (level 1) and character (level 2) rows report `RightButton`. The menu draws at `FULLSCREEN_DIALOG` (level 605), the same strata as AceGUI windows, and stays **below** them even when raised; a window set to `DIALOG` has the menu above it. `ChatFrameUtil.SendTell(name)` opens the chat input as a whisper (`chatType` WHISPER, `tellTarget` the name). An edit box with the name selected lets Ctrl+C copy it, but it is clumsy (decided: no Copy name). Disabled items: `element:SetEnabled(false)` on a `root:CreateButton` greys it out (V58, CF-37 tested 2026-10-22). |
| Party invite from a click (V48, partial) | `C_PartyInfo.InviteUnit(name)` with a friend's character name (a space in it) invites them, from a right-click menu click (CF-37, 2026-10-22). Still open in V48: `C_PartyInfo.RequestInviteFromUnit` (asking someone to invite you) and `BNInviteFriend`. |
| `C_Club.RedeemTicket` | Protected: calling it from an addon shows "CommunitiesForever has been blocked from an action only available to the Blizzard UI" (V26, CF-21). Addons cannot join a community themselves. |
| `C_CreatureInfo.GetClassInfo(classID)` | Returns `classFile` (V21, class colors on Unlinked rows) |
| `BNSendGameData` payload | 3500-byte chunks arrive; a 20 KB message in ~6 chunks at 0.2 s arrives complete (V2, CF-10). The real per-message limit is still unknown and not needed. |
| Addon BNet messages in instances and combat | Work inside a dungeon. In combat the addon holds its messages (`InCombatLockdown`) and sends them after `PLAYER_REGEN_ENABLED`; verified (V3, V24, CF-10). Sending during combat itself was not tested and is not needed. |
| `InCombatLockdown`, `GetTime`, `PLAYER_REGEN_ENABLED` | Exist and work (V24) |
| Community invite link in chat | A `clubTicket` link printed by an addon is clickable and opens Blizzard's join window; its Join button works (V27, CF-21). `GetClubTicketLink` is used when present, a hand-built `HclubTicket:<code>` link otherwise. |
| `AceConfigDialog:AddToBlizOptions` | Shows the options in Esc → Options → AddOns (V16). No longer used: AceConfig was removed after CF-43. |
| `/dump` (DevTools) | Prints table keys in hash order; order differs after a table is rebuilt. Use `/cf self` to compare the own record. |

## Forever launch probe (build 70790, 2026-11-06, CF-96)
The hidden launch probe (CF-82) of 6 testers on Forever live, build 70790, uploaded through the site (export of
2026-11-06). Later exports (CF-101, CF-105) add results from the patched builds 70840 (seen from 2026-11-07 01:39 UTC)
and 70862 (from 09:24 UTC); a row names its build where it isn't 70790. "N of 6" counts the testers whose probe saw it; a check the others didn't record was not met in their
play, not failed. All answers below are Forever's own, so they close the Retail hints above. The probe no longer runs
these checks (CF-96).
| Item | Seen on build 70790 | What it means |
|---|---|---|
| V55 `GameTooltip:AddDoubleLine` | exists, 6 of 6 | Confirmed on Forever. |
| V63 `date("%H:%M")` | the PC's clock time, 6 of 6 | Confirmed. |
| V71 `time({ year, month, day, hour, min })` | server seconds for the date, 6 of 6 | Confirmed. |
| V77 `GetCurrentRegion()` | `3` (EU), 6 of 6 | Confirmed. |
| V78 `GetGameTime()` | the realm clock, offset +60 min from UTC (CET), 6 of 6 | The realm offset from `GetGameTime` and `GetServerTime` works on Forever (CF-55, CF-56). |
| V79 PvP counters | `GetPVPLifetimeStats()` gives `0, 0` (no kills yet), 6 of 6. `GetStatistic(60)` gives the deaths (`"--"` before the first, then counts up with each death; 5 testers logged it at their deaths). **`UnitPVPRank` is missing on Forever**, 6 of 6. | Lifetime kills and deaths work. The own rank can't be read with `UnitPVPRank` (CF-52's rank stays nil; the rank goals wait). Later export: `PLAYER_PVP_KILLS_CHANGED` fires on a kill and `GetPVPThisWeekStats` is **missing** (V73). Still open: `GetPVPRankInfo` (VERIFY.md V79). |
| V74 enemy players | level, class and race readable by nameplate (`NAME_PLATE_UNIT_ADDED` fires for enemy players), 1 of 6 | The Hunt's and CF-55b's victim fields are readable. Still open: a skull (`UnitLevel` `-1`). The rank is not readable with `UnitPVPRank` (V79). |
| V81 death cause | `C_DeathRecap.GetRecapEvents()` gives events at a death (10, the recap's size), 5 of 6; the mirror timers (`MIRROR_TIMER_START`) were seen before a death by 1 | Death causes from the recap work. |
| V83 loot strings | `LOOT_ITEM_SELF` matched a real loot line with its item ID, 6 of 6 | Loot parsing works on Forever. |
| V84 fishing | `IsFishingLoot()` true and `GetNumLootItems()` on `LOOT_OPENED` while fishing, 3 of 6 | Fishing loot is told apart (`d.fish20` and the fishing goals). |
| V85 trades | `TRADE_SHOW` with a readable `UnitGUID("NPC")`, then `ERR_TRADE_COMPLETE` as `UI_INFO_MESSAGE`, 5 of 6 | A completed trade and its partner work (`d.trade`). Still open: what was given (`TRADE_PLAYER_ITEM_CHANGED`, `GetTradePlayerItemLink`) for `w.craftTrade` (VERIFY.md V85). |
| V86 discoveries | `ERR_ZONE_EXPLORED` matched, 5 of 6; `ERR_ZONE_EXPLORED_XP` 1 of 6 | Discovery parsing works. |
| V87 "Appear offline" friend | **fails**, 4 of 6: a `BN_CHAT_MSG_ADDON` arrives from a game account the friends list doesn't show; `C_BattleNet.GetGameAccountInfoByID(senderID)` answers with a table, but without `playerGuid`, so `C_BattleNet.GetAccountInfoByGUID` gives no BattleTag | A friend who appears offline on Battle.net can't be identified or linked over Battle.net: their data still arrives, but the addon can't tell whose it is and drops it (`Friends.resolveHidden` gets nothing to work with). Over a guild or community they still sync and link by their character (CF-28, CF-90). |
| V90 kills from the XP message | `CHAT_MSG_COMBAT_XP_GAIN` matches `COMBATLOG_XPGAIN_FIRSTPERSON` (also with the rested bonus text), alone and in a group (3 of 6 in a group), and names the creature seen just before, 6 of 6 | Kills count from the XP message. |
| V93 enemy creatures | `UnitName`, `UnitClassification` (`normal`) and `UnitLevel` readable by nameplate and mouseover, 6 of 6 | Creature level and classification work; no elite or rare was seen yet, the value is the game's string. |
| V94 flights | `UnitOnTaxi("player")` true 3 s after `PLAYER_CONTROL_LOST` on a flight, 1 of 6; a message equal to `ERR_NEWTAXIPATH` (as `UI_INFO_MESSAGE` or `CHAT_MSG_SYSTEM`; the probe listened to both) when a flight path was learned, 1 of 6 | `d.flight` and `d.newFlight` work; listen to both events for the new path. |
| V95 own casts | `UNIT_SPELLCAST_SUCCEEDED` for `"player"` with a readable spell ID and name, 6 of 6 | Own casts work (`d.hearth`, `d.bandageUp`). Some Forever spells have new, high IDs (above 1,000,000). |
| V98 movement | `IsMounted()` read true (1 tester) and `IsSwimming()` read true (5 testers), polled every 5 s by `C_Timer.NewTicker`; both read true on the same client for 2 testers (exports of 2026-11-06 evening and 2026-11-07) | Both work. `C_Timer.NewTicker` works on Forever too (it ran the poll). Riding skill: see V82, still open. |
| V99 merchant | `MERCHANT_SHOW` and `MERCHANT_CLOSED` fire, and post-hooks on `BuyMerchantItem` (5 of 6) and `RepairAllItems` (1 of 6) run; `GetMoney` dropped while the window was open | Buys and repairs are seen. Still open: a sale (money up while open), `GetMerchantItemLink`, `CanMerchantRepair`, `GetRepairAllCost` (VERIFY.md V99). |
| V100 mail sent | a `SendMail` post-hook sees the recipient and `MAIL_SEND_SUCCESS` fires, 2 of 6 | `d.mailFriend` works. Still open: the inbox (VERIFY.md V100). |
| V102 bank | `BANKFRAME_OPENED` fires, 1 of 6 | `d.bank` works. |
| V103 trainer | `LEARNED_SPELL_IN_SKILL_LINE` between `TRAINER_SHOW` and `TRAINER_CLOSED`, 6 of 6 | `d.trainer` works with the event. |
| V104 recipes | `NEW_RECIPE_LEARNED` with a recipe ID, 6 of 6 (some IDs above 1,000,000) | `d.newRecipe`, `d.cookRecipe` work with the event. |
| V105 created items | `LOOT_ITEM_CREATED_SELF` with the item, `C_Item.GetItemInfoInstant` class and subclass and `C_Item.GetItemQualityByID` readable, 6 of 6: food and drink `0/5`, trade goods `7/5`, `7/6`, `7/7` | Crafting and cooking checks by item class work. A bandage (expected `0/7`) wasn't made yet. |
| V106 loot source | `GetLootSourceInfo(slot)` gives a readable GUID: `Creature` (5 of 6), `GameObject` (1 of 6) | Loot by source works (`d.gather10`). Still open: item IDs from `GetLootSlotLink` and fishing loot's source (VERIFY.md V106). |
| V107 weapon skill | `CHAT_MSG_SKILL` matches `SKILL_RANK_UP`, 6 of 6 | `d.weaponSkill` works. |
| V108 whisper target | `CHAT_MSG_WHISPER_INFORM` names the target, 4 of 6 | `d.whisper` works. Still open: the emote part (VERIFY.md V108). |
| V109 coins | `CHAT_MSG_MONEY` matches `YOU_LOOT_MONEY` (alone, 3 of 6) and `LOOT_MONEY_SPLIT` (in a group, 3 of 6) | `d.coins10` works. |
| V110 auras | `C_UnitAuras.GetAuraDataByIndex` `spellId` and `sourceUnit` readable out of combat: an own buff on a party member, 3 of 6; the player's own auras, the other 3 | `d.buffFriend` and `d.wellFed` work. |
| V111 screenshot | `SCREENSHOT_SUCCEEDED` fires, 1 of 6 | `d.groupPic` works. |
| V112 bag quality | `C_Container.GetContainerItemInfo` gives `quality`, 6 of 6 | `d.tidyBags` works. |
| V113 gear | `PLAYER_EQUIPMENT_CHANGED` slot and `GetInventoryItemID` give the item put on, 6 of 6 | `d.equipNew` (and `w.blueGear` with the quality) works. |
| V115 places | `ZONE_CHANGED` / `ZONE_CHANGED_INDOORS` with `GetSubZoneText()`, 6 of 6 | `d.places10` works. |
| V116 items used | a used bag item casts the spell `C_Item.GetItemSpell` gives for it (`UNIT_SPELLCAST_SUCCEEDED`), 6 of 6: food and drink `0/5`, consumables `0/8`, a quest item `12/0` | Item use works (`d.eatOwn` and the care goals). Potions (`0/1`) and scrolls (`0/4`) weren't used yet; the classes are Blizzard's. |
| V117 cast targets | `UNIT_SPELLCAST_SENT` gives the target's name, 6 of 6 | `d.bandageFriend`, `d.scrolls10` on yourself work. |
| V120 death recap source | the recap's last event names a `Creature` source with a readable name, 5 of 6 | The recap names the killer for creatures. Still open: a death to a player (VERIFY.md V120). |
| V123 zone PvP type | `C_PvP.GetZonePVPInfo()` (or `GetZonePVPInfo()`) gives `friendly` in the own faction's capital cities (Undercity, Orgrimmar, Thunder Bluff), 5 of 6; **nothing (`nil`) in the own faction's other zones**: Durotar, Tirisfal Glades, Silverpine Forest (2 testers) | Own territory reads only in the capitals, so `p.homeGuard` counts kills inside a capital only. Still open: hostile and contested zones, and the realm type (VERIFY.md V123). |
| V60 professions (exports of 2026-11-06 evening and 2026-11-07) | `V60 pass` with Cooking open: `GetBaseProfessionInfo().professionID` `185`, child `0`; `GetRecipeInfo(id).learned` readable; the item a recipe makes reads all three ways and they agree (`GetRecipeOutputItemData(id).itemID`, `GetRecipeItemLink`, `GetRecipeSchematic(id).outputItemID`: recipe 2963 makes 2996, recipe 1229504 makes 279972); `GetTradeSkillListLink()` gives a `trade:` link; all ten functions exist. **`GetAllRecipeIDs` gives the open profession's list** (build 70840: 132 IDs with Cooking open, 5 learned; the 471 of build 70790 are Forever's Tailoring recipes, WEB-90). On `TRADE_SKILL_SHOW` the list can still be empty (it loads just after; CF-100, then `pass` once loaded). V60b: a clicked link of yours and of someone else (online) opens Blizzard's view (`IsTradeSkillLinked` true; 471 and 262 IDs). | Recipes, learned state and items work (CF-38); a scan adds to the stored set (CF-102). Answered; the probe no longer runs V60 (CF-105). Still open: a friend's link while they are offline, and an old link (V60b, VERIFY.md V60). |
| V60c recipe details (export of 2026-11-07, build 70840, 1 tester) | `C_TradeSkillUI.GetTradeSkillLineForRecipe(id)` answers for every learned recipe: Cooking gave line `2939`, parent `185` for all 5. Of a learned recipe: `relativeDifficulty` (skill-up colour) and `numSkillUps` readable; the reagents read (`GetRecipeSchematic(id, false).reagentSlotSchematics`: 1 slot, 1x an item); `numAvailable` ("can make now") **missing**; `GetRecipeCooldown` **missing**; `GetRecipeSourceText` **missing**. The list link has 4 fields, 35 characters (the short form: read live when clicked) | Each recipe's profession works: CF-38 stores the parent line as `recipeLines` (VERIFY.md V137 answered). The addon can't tell how many a character can make now, a recipe's cooldown or where an unlearned recipe is learned: the site keeps those from its own item data (cmangos). The probe no longer runs V60c (CF-105). |
| V70 messaging lockdown | `C_ChatInfo.InChatMessagingLockdown()` and `IsEncounterInProgress()` exist and read `false` **during a boss fight** in a dungeon (1 tester) | Forever doesn't lock addon messages in Vanilla boss fights (or doesn't count them as encounters); CF-46's guard never blocks there, and sync kept working. |
| V73 honor message | **fails**: the kill message did not match `COMBATLOG_HONORGAIN`, which reads `"%s dies (Honorable Kill: %s). You gain %d Honor."` on Forever (1 tester, 1 kill). `PLAYER_PVP_KILLS_CHANGED` fires, `GetPVPLifetimeStats` counted the kill (`1, 0`), `GetPVPThisWeekStats` is missing | Kills count from the lifetime counter, but without the victim (no name, so no level, class or race). CF-101 tries the variants without a rank, and the probe keeps the message's shape (VERIFY.md V73). |
| V76 group at a kill | `IsInGroup()` and the `GetInstanceInfo()` type readable at a kill (`group true, instance none`), 1 of 6 | The kill's `solo` and `bg` flags work. |
| V121 PvP flag | `UnitIsPVP("player")` reads true after a flag change (`PLAYER_FLAGS_CHANGED`), 1 of 6 | `p.flagUp`, `p.flagHour`, `b.flagged3h` can be built (pool 4). |
| V82 riding | no riding skill seen (no tester has riding yet); `C_TradeSkillUI.GetProfessionInfoBySkillLineID` exists, 6 of 6 | Still open (VERIFY.md V82). |

## Retail dry runs (not Forever)
Answers from the FriendProbe dry run on Retail 12.1.5 (interface 120105, same Mainline API and Midnight restrictions). They never close a Forever item: Forever is checked on its own at launch.
| API | Result |
|---|---|
| `frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` | Blocked for addons (V75 retail: fail). Blizzard shows its popup "... only available to the Blizzard UI. You can disable this addon and reload the UI.", also when the call is inside `pcall`. FriendProbe now only tries it from a button; CommunitiesForever never registers it (CF-61, Nico 2026-10-29: death causes from the death recap and mirror timers). |
| `frame:CreateAnimationGroup()` with a `Translation` (Ambient effects, V64) | Animates the frame itself: the whole title bar slid across as a dark block every few seconds, the streak's bright edge riding along (CF-43 bug). The shine now creates the group on its streak texture (`texture:CreateAnimationGroup()`), so only the streak moves. The texture (white, alpha in the file) with `SetBlendMode("ADD")` was fine. |
| V47 a click on an addon chat link (FriendProbe run 2, build 70575, 29 Oct) | pass: "link click reached the addon via SetItemRef hook". Closed (Nico: checked on Retail counts as done). |
| V74 enemy player fields | Level, class and race are readable by mouseover. Forever: see "Forever launch probe" (nameplates confirmed; a skull still open). |
| V79 PvP counters | `GetPVPLifetimeStats()` works (`0, 0` on a character without kills); `GetStatistic(60)` gives total deaths (`31`). The Vanilla rank API (`UnitPVPRank`, `GetPVPRankInfo`, `GetPVPThisWeekStats`) is missing on Retail, as expected. Forever: `UnitPVPRank` is missing there too, see "Forever launch probe". |
| V72 `ChatFrameUtil.OpenChat("/w <name> <text>")` (Whisper on the start panel) | yes (Nico, by hand): the chat input opens as a whisper with the text filled in, not sent. Closed. |
| V59 the hidden sync channel, sending | `JoinTemporaryChannel` plus `SendAddonMessage(prefix, text, "CHANNEL", index)` sends: `/cf sync debug` printed "[sync] to the community channel: HELLO …". Receiving on another client is still open (V59). |
| A file listed in the TOC that doesn't exist | A "Lua Warning" popup at every login (`<addon>.toc:<line> Error loading ...`). Ship only TOC lines whose files exist. |

## Retail 12.1.5 dry run (2026-10-29)
FriendProbe on Retail 12.1.5, build 70575, one EU character (interface 120105: the same Mainline API and Midnight restrictions as Forever). **Answers for Forever (Nico, 2026-10-29, CF-61):** what he checked on Retail needs no recheck; those VERIFY.md items are closed: V77, V78, V63, V71, V55, V68, V50b, V83, V86, V82, V54, V61, V80 (the strings) and V81 (`C_DeathRecap` exists); from the second run (CF-62) V62, V65, V66 and V67. Still open, so only hints here: V64 (the shimmer fix), V75 (combat log), V79 (Vanilla ranks), and everything that needs a friend, a dungeon, PvP or Forever itself.
| Item | Retail result | What it suggests for Forever |
|---|---|---|
| V77 `GetCurrentRegion()` | `3` (EU) | As expected. |
| V78 `GetGameTime()` | Realm clock 12:31 against UTC 11:31: offset +60 min (CET) | The realm offset from `GetGameTime` and `GetServerTime` works as CF-55 assumes. |
| V63 `date("%H:%M")`, V71 `time({...})` | pass | Local clock and date-to-seconds work. |
| V68 `C_UI.Reload()` from a click | pass: the UI reloaded | A button may reload the UI. |
| V55 `GameTooltip:AddDoubleLine` | exists | Two-column minimap tooltip works. |
| V50b self-whisper burst | 30 of 30 arrived. A 256-byte whisper arrives as 255 bytes | Whispers are capped at 255 bytes, which matches `Protocol.COMMUNITY_CHUNK = 255`. |
| V79 PvP counters | `GetPVPLifetimeStats()` gives `0, 0`; `UnitPVPRank`, `GetPVPThisWeekStats`, `GetPVPRankInfo` missing; `GetStatistic(60)` (total deaths) gives `31` | Retail has no Vanilla rank system, so the missing rank functions say nothing about Forever. Deaths from `GetStatistic(60)` work. |
| V80 `DUEL_WINNER_KNOCKOUT`, `DUEL_WINNER_RETREAT` | exist: `"%1$s has defeated %2$s in a duel"` and `"%2$s has fled from %1$s in a duel"` | Positional arguments: the winner is `%1$s` in both, also when it comes second in the text. `GameText.parse` already handles `%n$s` (GameText spec); no duel was fought, so a real match is not confirmed. |
| V81 `C_DeathRecap.GetRecapEvents` | exists | A cause source when the combat log is not allowed. |
| V82 riding | `IsSpellKnown(33388)` false, `IsSpellKnown(33391)` true; `GetNumSkillLines` missing | Riding from spells works; the skill-line fallback doesn't exist on this API. |
| V83 loot strings and items | `LOOT_ITEM_*` strings as expected; `LOOT_ITEM_PUSHED_SELF` matched a real item. Item links use a new colour prefix `|cnIQ1:` (quality in the prefix, not `|cffRRGGBB`); parsing `|Hitem:` still works. `GetItemInfo` is empty until the item is cached (names arrived on a later login). The watch-list IDs exist: 12784, 12360, 14342, 15063, 15062, 19807, 19970, 19979 | **Item info loads asynchronously:** code must not rely on `GetItemInfo` at loot time. The watch list keys on the item ID from the link, and the slot comes from `C_Item.GetItemInfoInstant`; both are fine. **The quality fallback is at risk:** `Loot.parse` reads the link colour `|cffRRGGBB` when `C_Item.GetItemQualityByID` is nil (not cached). With `|cnIQ<n>:` links that fallback finds nothing, so a rare or epic looted before it is cached would be missed. Check the Forever link format at launch (V83). |
| V86 `ERR_ZONE_EXPLORED`, `ERR_ZONE_EXPLORED_XP` | both matched a discovery | Discovery parsing works. |
| V62 Friends tab native calls (EditBox, ScrollFrame, mouse wheel, fold arrow) | yes (by hand) | Closed (CF-62). |
| V65 `ColorPickerFrame:SetupColorPickerAndShow` with `swatchFunc`, `cancelFunc`, `GetColorRGB` | yes (by hand): picks the chat colour, Cancel restores it | Closed (CF-62). |
| V66 `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory` | yes (by hand): the page is under Esc › Options › AddOns | Closed (CF-62). |
| V67 a changed addon file on `/reload` | pass: a Lua file changed on disk is re-read on `/reload`, and even a newly added file with its TOC line loads on `/reload` (no restart needed) | Closed (CF-62): `Data\Runs.lua` written by the uploader is picked up with `/reload`. |
| V75 combat log | `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` returned without an error, but Blizzard showed "only available to the Blizzard UI", and no events arrived | Likely forbidden for addons, not confirmed. See "Retail dry runs" above. |
| V54 Esc closes the window, key binding | yes (by hand) | |
| V61 the window draws right | no (by hand): the title shimmer drew a dark block (fixed in #117, see "Retail dry runs"); the rest draws | Closed; the shimmer itself stays open as V64. |

## Not available / not useful
- LanMiaoApi (CurseForge) reports none of the above as present in `APIDocumentation`; it only confirms runtime existence. Not a source of signatures or secret flags for these APIs.
