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
`accountInfo.battleTag` = `"Sjaakovich#2232"`.

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
| `AceConfigDialog:AddToBlizOptions` | Shows the options in Esc → Options → AddOns (V16) |
| `/dump` (DevTools) | Prints table keys in hash order; order differs after a table is rebuilt. Use `/cf self` to compare the own record. |

## Not available / not useful
- LanMiaoApi (CurseForge) reports none of the above as present in `APIDocumentation`; it only confirms runtime existence. Not a source of signatures or secret flags for these APIs.
