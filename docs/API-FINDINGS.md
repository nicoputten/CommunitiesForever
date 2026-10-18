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
| `BNGetInfo()` | 2nd return is BattleTag `"Vestras#2858"`; 1st (presenceID) is nil |
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
