# Verified API findings (Forever beta)

Source: FriendProbe run on Forever beta, build `1.60.1 70450 (Oct 15 2026)`, TOC 16001. Two clients, both BNet friends, same PvP ruleset, both Horde. All values readable out of combat (no secret values encountered).

## Client
| API | Result |
|---|---|
| `GetBuildInfo()` | `1.60.1  70450  Oct 15 2026  16001` |
| `WOW_PROJECT_ID` | `18` |
| `UnitName("player")` | `"Ves Doombringer"` (first + last name, one string) |
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
| `ScrollUtil` | Exists (V5). `CreateScrollBoxListLinearView` not checked separately. |
| `TooltipDataProcessor` | Exists (V6). `AddTooltipPostCall` and `Enum.TooltipDataType.Unit` not checked separately. |
| `UnitRace`, `UnitLevel`, `UnitFactionGroup` | Work; snapshot stores raceID (3rd return of `UnitRace`), level and faction (V11, CF-03) |
| First Aid | Is a profession. With First Aid, Fishing and Cooking: `GetProfessions()` slot 3 = First Aid, 4 = Fishing, 5 = Cooking (V7). skillLine ID still open. |
| `SKILL_LINES_CHANGED` | Fires on a profession skill-up (V12, CF-03) |
| `PLAYER_LEVEL_UP` | Fires; the new level is stored right after the ding (V12, CF-03) |
| `PLAYER_EQUIPMENT_CHANGED` | Fires on gear swaps (V12, CF-03) |
| `/dump` (DevTools) | Prints table keys in hash order; order differs after a table is rebuilt. Use `/cf self` to compare the own record. |

## Not available / not useful
- LanMiaoApi (CurseForge) reports none of the above as present in `APIDocumentation`; it only confirms runtime existence. Not a source of signatures or secret flags for these APIs.
