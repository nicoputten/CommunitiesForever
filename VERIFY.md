# In-game verification

Claude Code cannot run WoW. Every unverified API and every story's manual test lives here. Nico runs them and records results.
This file holds only open items. Answered API questions move to `docs/API-FINDINGS.md`; passed story steps are removed.

## Open API questions
The FriendProbe launch checklist (CF-60) answers most of them: unzip `FriendProbe.zip` (`tools\build-probe.ps1`) into `Interface\AddOns` and play as usual. Until 2026-11-18 it checks and logs by itself, silently; `/fp` opens the checklist (six play sessions, automatic ticks, Yes / No for the rest, the test buttons below, Copy report). Send `WTF\Account\<account>\SavedVariables\FriendProbe.lua` when done. Every open item below is a checklist item (`tests/spec/ProbeChecklist_spec.lua`).

| # | Question | How to test | Status |
|---|---|---|---|
| V8 | Is `clubId` identical across clients? (design does not depend on it) | the FriendProbe run (at login) on a friend's client: compare the `club` lines under V8 COMMUNITIES. Your own two characters both show 23125681 for Doombringers (2026-10-18); a friend's account is still to check. | open |
| V35b | Which events tell how a battleground ended? (CF-23; the dungeon part is verified, see API-FINDINGS) | `/cf activity debug` (on until `/reload` or logout; the FriendProbe run (at login) also logs the same events), then queue and finish a battleground (stay until the end). Send the FriendProbe log and the `[activity]` lines. Check: `instance:` inside shows `<name>, pvp`; `PVP_MATCH_COMPLETE` passes the winner (0 Horde / 1 Alliance); `battleground ended:` says `won true` when your side won. Last line: `left ...: recorded`. | open |
| V48 | Which way can an addon get a friend into your party from a click? (CF-27; inviting by name works, see API-FINDINGS) | Same FriendProbe Test: links and invites with a friend online in Forever, you not in a group: click `[invite by name]` (does the friend get an invite? the name has a space), leave the group; `[invite via Battle.net]`, leave; then let the friend run FriendProbe's Test: links and invites and click `[ask them for an invite]` on you (do you get a "wants to join" popup?). Send both logs: the `C_PartyInfo...` / `BNInviteFriend` lines and the `INVITE EVENT` lines (blocked actions show as `ADDON_ACTION_BLOCKED`). | open |
| V51 | Do addon whispers reach a character of the other faction? (CF-28) | Both characters need FriendProbe: `/fp whisper <the other character's name>`; the other log should show `addon message <- ... V51:whisper`. | open |
| V52 | How stale does community presence get after a logout? (CF-28: online status for non-friends; CF-15 bug) | A few minutes after a member logged out, the FriendProbe run (at login): under V52 COMMUNITY PRESENCE, does that member still show `Online`? | open |
| V53 | Is the "No player named X is currently playing" line hidden after an addon whisper to someone who just went offline? (CF-28) | With a community member running this build: let them log out, then (within a minute, before the community list updates) `/cf sync`. Expected no "No player named ..." line in chat (`ChatFrameUtil.AddMessageEventFilter` / `ChatFrame_AddMessageEventFilter` and `ERR_CHAT_PLAYER_NOT_FOUND_S` are unverified). If the line shows, send it. | open |
| V59 | Does a friend **receive** the hidden sync channel's HELLO, and which `CHAT_MSG_ADDON` arguments name the channel? (CF-31; sending works on Retail 12.1.5: API-FINDINGS) | Two players in the community who are **not** Battle.net friends, both with CommunitiesForever. Log in A and B, then `/cf sync debug` on both (it lasts until the next /reload or login, CF-64). On A `/cf sync`: `[sync] to the community channel: HELLO …`. On B: a `[sync]` line receiving that HELLO from A, and within seconds A's characters show with their data in `/cf` (not only the community's class and level). Then `/cf sync debug` again on both to stop the lines. If B shows nothing: B's `/dump GetChannelList()` (is a `cf…` channel in it?). | open |
| V64 | Do the ambient effects work (CF-43)? `texture:CreateAnimationGroup` (on the streak, not the frame: see API-FINDINGS "Retail dry runs") with a `Translation` animation (`SetOffset`, `SetDuration`, `SetStartDelay`, `SetLooping("REPEAT")`), `SetClipsChildren` and `Texture:SetBlendMode("ADD")`. | See the CF-43 steps: a soft light streak slides across the window title every few seconds and across LEVEL UP chips, clipped to them; the title bar and the chips themselves never move and no dark block shows; between passes nothing shows, no white strip behind the title's shield (CF-62: an `Alpha` animation holds it visible only while it moves); off with Ambient effects. If nothing moves, send any Lua error. | open |

| V69 | Can one click invite several friends in a row (`C_PartyInfo.InviteUnit` per name), the first invite making a party? (CF-48: Invite everyone ready) | With at least two friends online in Forever and you not in a group: FriendProbe's Test: invite all, click `Invite all N`. Do all friends get an invite (also the second, while the first hasn't accepted yet)? Let them accept, wait 10 s (`V69 after 10 s: in group N`), `/reload` and send the log (the `V69 C_PartyInfo.InviteUnit` lines and `INVITE EVENT` lines). | open |
| V70 | Do `C_ChatInfo.InChatMessagingLockdown()` and `IsEncounterInProgress()` exist, and are they true during a boss fight? (CF-46: runs are never sent during encounters, keystones or PvP matches) | Inside a dungeon, during a boss fight: `/run print(C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown(), IsEncounterInProgress and IsEncounterInProgress())`, and once more outside the fight. Expected `true true` in the fight, `false false` outside (`nil` means the function is missing: then only battlegrounds count). | open |


| V73 | What does `CHAT_MSG_COMBAT_HONOR_GAIN` pass on Forever: the victim's name and rank? Does `PLAYER_PVP_KILLS_CHANGED` fire, and what do `GetPVPSessionStats` and `GetPVPLifetimeStats` return? (CF-54, CF-55: raw kills for Doomsday) | Copy the new `tools/FriendProbe`, the FriendProbe run, then get a few honorable kills in the world: at least one solo and one in a group, and one in a battleground. `/reload` and send the log: the `V73 honor` lines (all arguments) and `V73 counters` lines. | open |
| V74 | Forever only (Retail 12.1.5 answered the rest: level, class and race are readable by mouseover, API-FINDINGS): do target and nameplates of **enemy players** give the same (`UnitLevel` with `-1` for a skull, `UnitClass`, `UnitRace`, `UnitGUID`), is their **PvP rank** readable (`UnitPVPRank` or what exists), and does `NAME_PLATE_UNIT_ADDED` fire for enemy players? (CF-55: victim level, class, race and rank) | The FriendProbe run on Forever: target and mouse over enemy players, with enemy nameplates on, including one that shows a skull. The log shows a `V74 unit` line per player seen; any `secret` or `missing` answers the question. | open |
| V75 | Can an addon register `COMBAT_LOG_EVENT_UNFILTERED` on Forever, and does it show `PARTY_KILL` with the victim's GUID (`GetPlayerInfoByGUID`) and who killed you? (CF-54: Wanted poster, revenge kill) | Only from the button (on Retail 12.1.5 registering it is blocked with Blizzard's popup, see API-FINDINGS "Retail dry runs"; this item is about Forever): `/fp`, Test the combat log. A popup "only available to the Blizzard UI" means blocked: answer No in the checklist and don't disable the addon. Without a popup the log has `V75 combat log: registered`; then get a kill and die to a player once: `V75 PARTY_KILL` and `V75 killed by` lines. | open |
| V76 | Are `IsInGroup()` and the `GetInstanceInfo()` type right at the moment of a kill (`solo`, `bg`)? (CF-55) | The FriendProbe run: each `V73 honor` line is followed by `group true/false, instance <type>`. Check that it matches (grouped or not, `pvp` only in the battleground). | open |
| V79 | Forever only (Retail 12.1.5 answered the rest: `GetPVPLifetimeStats` and `GetStatistic(60)` work, API-FINDINGS): does the Vanilla rank API exist on Forever, `UnitPVPRank` with `GetPVPRankInfo(rankID, "player")` and `GetPVPThisWeekStats`, and does `PLAYER_PVP_KILLS_CHANGED` fire on an honorable kill? (CF-52) | On Forever: `/run print(UnitPVPRank and UnitPVPRank("player"))`, `/run print(GetPVPRankInfo and GetPVPRankInfo(UnitPVPRank("player"), "player"))`, `/run print(GetPVPThisWeekStats and GetPVPThisWeekStats())`. Expected numbers (a rank name and number for a ranked character; `nil` means missing: send which). Then get an honorable kill: the FriendProbe log shows `V73 PLAYER_PVP_KILLS_CHANGED`. | open |
| V84 | Do `LOOT_OPENED`, `IsFishingLoot()` and `GetNumLootItems()` work for fishing? (CF-56: `d.fish20`) | Fish once: `/run print(IsFishingLoot, GetNumLootItems)` shows two functions; after a catch, `/cf doomsday` with `/dump CommunitiesForeverDB.global.self.doomsday` after `/reload` shows `fish` up by the items looted. | open |
| V87 | Battle.net "Appear offline": does a friend's `BNSendGameData` still reach us while they appear offline, do `C_BattleNet.GetGameAccountInfoByID(senderID)` (playerGuid, wowProjectID) and `C_BattleNet.GetAccountInfoByGUID(guid)` (battleTag) still tell who it is, can we send back to that game account, and what happens while we ourselves appear offline? (bug fix: hidden friends were Unlinked and never synced) | Two friends, both with CommunitiesForever and FriendProbe. A sets Battle.net to Appear offline and logs in after B. On B: the FriendProbe log line `V87 from hidden game account …` with `playerGuid yes` and `battleTag yes` (the V87 row turns OK). On B, `/cf friends` does not list A, but `/cf` Friends shows A's characters under A (offline, not Unlinked), and A's record arrived (A's levels and professions on the cards). On A: B's record arrived too (B's data on the cards), so sending back to A's game account works. No "A is online" chat line on B. Then swap: B appears offline, A online; same checks. | open |
| V88 | Which of the game's sounds play for the celebration banners (CF-67)? `PlaySound(SOUNDKIT.<key>, "SFX")` with, per weight, the first key that exists: small `IG_QUEST_LIST_COMPLETE`; medium `UI_EPICLOOT_TOAST`, then `IG_QUEST_LIST_COMPLETE`; big `UI_LEGENDARY_LOOT_TOAST`, then the medium ones. | `/run for _, k in ipairs({"IG_QUEST_LIST_COMPLETE","UI_EPICLOOT_TOAST","UI_LEGENDARY_LOOT_TOAST"}) do print(k, SOUNDKIT[k]) end`: three numbers expected (`nil` means missing: send which). Then `/cf settings`, Celebrations, Preview: a sound plays (the medium one). If a sound is missing, too loud or wrong for the moment, say which. | open |
| V89 | Does the celebration banner draw and move as on the boards (CF-67)? `GetPhysicalScreenSize()` (the 85 % below 1600 px), `Texture:SetGradient("VERTICAL", CreateColor(...), CreateColor(...))` on the plaque, a `Rotation` animation (`SetDegrees`) on a big feat's rays, an inline texture (`\|T...\|t`) for the streak's flame, and the friends' lines anchored to `ChatFrame1`. | `/run print(GetPhysicalScreenSize())` shows your screen's pixels. `/cf settings`, Celebrations, Preview: a dark plaque with angled ends and a gold top edge fading to bronze, a round medallion with the Doomsday emblem, "DAY COMPLETE", the day's name, "PvE 15 · PvP 10 · <flame> 6 days"; it rises in with the medallion (Ambient effects on). Compare with `docs/design/celebrations-2026-11/CB02Day.dc.html`. A flat plaque without the fade means `SetGradient` is missing; a still medallion means `Scale` is. | open |
| V85 | Do `TRADE_SHOW` with `UnitGUID("NPC")`, `TRADE_PLAYER_ITEM_CHANGED` with `GetTradePlayerItemLink(slot)` and `UI_INFO_MESSAGE` with `ERR_TRADE_COMPLETE` tell a completed trade, its partner and what you gave? (CF-56: `d.trade`, `w.craftTrade`) | Trade an item you crafted to a friend's community character; after `/reload` this week's facts have `trades = 1` and `craftTrade = 1`. A cancelled trade adds nothing. | open |
| V90 | Does `CHAT_MSG_COMBAT_XP_GAIN` arrive with readable text matching `COMBATLOG_XPGAIN_FIRSTPERSON` (and its group variants) once per kill, also in a group? (Doomsday catalogue: combat goals) | FriendProbe (`Missions.lua`): kill an enemy that gives XP, alone and in a group. The checklist ticks V90 with "<name> dies, <n> XP"; the log has `V90 XP message` and `V90 kill` lines (with "seen as <classification> level <n>" when V93 saw it first). | open |
| V93 | Do `UnitClassification`, `UnitLevel` and `UnitName` read for hostile creatures by target, mouseover and nameplate? (`d.elite`, `d.rareMob`, `d.bigFoe`) | FriendProbe: target and mouse over enemy creatures, one of them elite. V93 ticks with "<name>: <classification>, level <n>"; `V93 creature` lines in the log. | open |
| V94 | Do `UnitOnTaxi` and `PLAYER_CONTROL_LOST` tell a flight, and does `ERR_NEWTAXIPATH` arrive when a flight path is learned? (`d.flight`, `d.newFlight`) | FriendProbe: take a flight (V94 ticks with "UnitOnTaxi true"); talk to a flight master whose path you don't know (`V94 new flight path message` in the log). | open |
| V95 | Does `UNIT_SPELLCAST_SUCCEEDED` for `"player"` give a readable spell ID (Hearthstone 8690, a bandage, the campfire)? (`d.hearth`, `d.bandageUp`, `d.campfire`) | FriendProbe: cast any spell, e.g. the Hearthstone. V95 ticks with "spell <id> <name>"; every new spell is a `V95 cast` line. | open |
| V96 | Do `PLAYER_BINDING_CHANGED` and `GetBindLocation()` work when setting the hearthstone? (`d.bind`) | FriendProbe: make an inn your home. V96 ticks with "GetBindLocation <place>". | open |
| V98 | Do `IsMounted()` and `IsSwimming()` read true while mounted and swimming? (`d.ride`, `d.swim`) | FriendProbe (polls every 5 s): ride a mount, swim. V98 ticks when both were seen. | open |
| V99 | Merchant: `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `CanMerchantRepair`, `GetRepairAllCost`, hooks on `RepairAllItems` and `BuyMerchantItem` with `GetMerchantItemLink`? (`d.vendorSale`, `d.vendorBuy`, `d.repair`, `d.restock`) | FriendProbe: at a merchant, buy something (or repair), sell something, close the window. V99 ticks with "buy hook ran" or "repair hook ran"; `V99` lines show the item and its class. | open |
| V100 | Mail: does a `SendMail` hook see the recipient (a full name with a space), does `MAIL_SEND_SUCCESS` fire, and do the inbox take hooks with `GetInboxHeaderInfo` give the sender? (`d.mailFriend`, `d.mailbox`) | FriendProbe: send a mail to a friend's or your alt's full name (V100 ticks with "sent to <name>"); take an item from the mailbox (`V100 TakeInboxItem ... sender` in the log). | open |
| V101 | Which auction house does Forever have (`C_AuctionHouse`), and which events or messages tell a posted and a bought auction? (`d.auctionPost`, `d.auctionBuy`) | FriendProbe: post an auction (V101 ticks with the event or `ERR_AUCTION_STARTED`), buy one; send the `V101` lines. | open |
| V102 | Does `BANKFRAME_OPENED` fire? (`d.bank`) | FriendProbe: talk to a banker. V102 ticks. | open |
| V103 | Which event or message tells a spell learned at a class trainer (`LEARNED_SPELL_IN_SKILL_LINE`, `LEARNED_SPELL_IN_TAB`, `ERR_LEARN_SPELL_S`)? (`d.trainer`) | FriendProbe: learn a spell or rank at your trainer. V103 ticks with the event or message that came. | open |
| V104 | Which event or message tells a recipe learned (`NEW_RECIPE_LEARNED`, `ERR_LEARN_RECIPE_S`)? (`d.newRecipe`, `d.cookRecipe`) | FriendProbe: learn a recipe (a cooking recipe from a vendor). V104 ticks with which one came. | open |
| V105 | `C_Item.GetItemInfoInstant` class and subclass, and `C_Item.GetItemQualityByID`, for a just-created item? (cooking and bandage goals, `d.craftGreen`) | FriendProbe: cook something and make a bandage. V105 ticks with "created <id>: class <c>/<s> (...), quality <q>"; send the `V105` lines (food is expected as 0/5, bandages 0/7). | open |
| V106 | On `LOOT_OPENED`, is `GetLootSourceInfo(slot)`'s GUID readable (GameObject or Creature), and does `GetLootSlotLink` give item IDs, also for fishing loot? (`d.gather10`, `d.treasure`, `d.fishKinds3`) | FriendProbe: loot an enemy, a herb or ore node, a chest, and fish once. V106 ticks with "loot source Creature" (or GameObject); `V106 loot slot` lines show item, class and source. | open |
| V107 | Does `CHAT_MSG_SKILL` arrive with `SKILL_RANK_UP` text on a weapon skill-up? (`d.weaponSkill`) | FriendProbe: fight with a weapon whose skill isn't maxed. V107 ticks with the message. | open |
| V108 | Are whisper-inform targets readable (`CHAT_MSG_WHISPER_INFORM`), and does a `DoEmote` hook see the token, `UnitGUID("target")` and the target's faction? (`d.whisper`, `d.wave`, `p.flex`, `p.boo`) | FriendProbe: whisper someone, then target a player and `/wave` (V108 ticks with both). In world PvP: `/flex` and `/boo` at an enemy-faction player; the `V108 DoEmote` lines say "enemy faction true". | open |
| V109 | Does `CHAT_MSG_MONEY` arrive with text matching `YOU_LOOT_MONEY` or `LOOT_MONEY_SPLIT`? (`d.coins10`) | FriendProbe: loot coins, alone and in a group. V109 ticks with which one matched. | open |
| V110 | Are `C_UnitAuras.GetAuraDataByIndex` `spellId` and `sourceUnit` readable out of combat, for the player and party members? (`d.wellFed`, `d.buffFriend`) | FriendProbe: in a group out of combat, buff a party member. V110 ticks with "own buff on party<n>"; `V110 aura` lines list the auras (eat food: "Well Fed" should show). | open |
| V111 | Does `SCREENSHOT_SUCCEEDED` fire? (`d.groupPic`) | FriendProbe: press Print Screen. V111 ticks. | open |
| V112 | Does `C_Container.GetContainerItemInfo` give `quality` for bag items? (`d.tidyBags`) | FriendProbe: at login it reads the bags. V112 ticks with "<n> bag items with a readable quality". | open |
| V113 | Do `PLAYER_EQUIPMENT_CHANGED` (slot) and `GetInventoryItemID` give the item put on? (`d.equipNew`) | FriendProbe: put on or swap a piece of gear. V113 ticks with "slot <n>: item <id>". | open |
| V114 | Do `CONFIRM_SUMMON` and `C_SummonInfo.GetSummonConfirmSummoner()` name the summoner? (`d.summoned`) | FriendProbe: let a warlock friend summon you. V114 ticks with "summoner <name>". | open |
| V115 | Do `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS` and `GetSubZoneText()` give the place within a zone? (`d.places10`) | FriendProbe: walk from one place in a zone to another. V115 ticks with "GetSubZoneText <place>". | open |
| V116 | Does a used potion, scroll, food or bandage show as `UNIT_SPELLCAST_SUCCEEDED` with the spell ID that `C_Item.GetItemSpell` gives for that bag item? (`d.potion`, `d.scrolls10`, `d.eatOwn`, `d.bandageUse3`) | FriendProbe: drink a potion, read a scroll, eat food, use a bandage. V116 ticks with "item <id> (<name>) cast spell <id>: class <c>/<s>"; send the `V116` lines (potions expected 0/1, scrolls 0/4). | open |
| V117 | Does `UNIT_SPELLCAST_SENT` give the cast's target name? (`d.scrolls10` on yourself, `d.bandageFriend`) | FriendProbe: read a scroll on yourself, bandage a friend. V117 ticks with "target <name>". | open |
| V118 | Can an addon `hooksecurefunc("JumpOrAscendStart", ...)` without a blocked action, and does it run once per jump? (`d.jump100`) | FriendProbe: jump 3 times. V118 ticks; jump 10 more and check `V118 jumps 10` in the log. A popup "blocked from an action" means it fails: answer No. | open |
| V119 | The campfire: its spell ID when lit, and its special buff (name, spell ID, stacks or points) as items are added. (`d.campfire`, `d.campfireBuff`) | FriendProbe: light a campfire (Basic Campfire), then add 1, 2 and 3 items. The log has `V119 campfire lit` and `V119 aura near the campfire` lines with stacks and points each time the buff changes. Mark Yes if the buff shows how many items were added, No if not; send the lines. | open |
| V120 | Does `C_DeathRecap.GetRecapEvents()` give the name and GUID of the player who killed you? Without the combat log it is the only source. (PvP catalogue: `p.revenge`, `p.avenge`, `b.revenge3`, `b.avenge3`) | FriendProbe: die to an enemy player. V120 ticks with "killed by player <name>"; the `V120 recap` lines list the recap's sources. "last recap source ..." without a player means it didn't name the killer: send the lines. | open |
| V121 | Do `UnitIsPVP("player")` and `PLAYER_FLAGS_CHANGED` tell the PvP flag? (`p.flagUp`, `p.flagHour`, `b.flagged3h`) | FriendProbe: `/pvp` (or walk into a contested zone), wait for the flag, then let it run out. V121 ticks with "UnitIsPVP true"; `V121 UnitIsPVP` lines show each change. | open |
| V122 | Does the battleground score give your row (`GetBattlefieldScore`: honorable kills) and the battleground's own stats (`GetNumBattlefieldStats`, `GetBattlefieldStatData`: flag captures, bases assaulted or defended)? (`p.bgFlag`, `p.bgBase`, `p.bgTop`, `b.bgFlags3`, `b.bgBases5`) | FriendProbe: play a battleground and open its scoreboard once. V122 ticks with "own honorable kills <n>; <n> battleground stats: ..."; send the `V122` lines from Warsong Gulch and Arathi Basin. | open |
| V124 | Is a guild a club on Forever: does `C_Club.GetSubscribedClubs()` list it with `clubType = 2` (`Enum.ClubType.Guild`), do `C_Club.GetClubMembers(id)` and `C_Club.GetMemberInfo(id, memberId)` give each guild member's `guid`, `name` and `presence`, and do the `CLUB_MEMBER_*` events (`CLUB_MEMBERS_UPDATED`, `CLUB_MEMBER_ADDED`, `CLUB_MEMBER_REMOVED`, `CLUB_MEMBER_PRESENCE_UPDATED`, `CLUB_MEMBER_UPDATED`) fire for it? (CF-83: the guild as the community) | On a character in a guild: `/dump C_Club.GetSubscribedClubs()`: the guild shows with `clubType = 2`; note its `clubId`. `/dump C_Club.GetClubMembers(<clubId>)`: a list of member ids. `/dump C_Club.GetMemberInfo(<clubId>, <one of those ids>)`: `guid` (`Player-…`), `name`, `presence` (1 online, 0 offline), `level`, `classID`, `role`. Then FriendProbe: `/fp`, Test: guild (V124, V125), and let a guild member log in or out within a minute: V124 ticks with "guild <name> (clubType 2): N members, N with a GUID"; the log has `V124 member` lines and `V124 member events in 60 s: CLUB_MEMBER_PRESENCE_UPDATED …` (`none` means the events don't fire for a guild). Send the `V124` lines. | open |
| V125 | Does `CHAT_MSG_GUILD` carry the sender's GUID as argument 12 (as `CHAT_MSG_COMMUNITIES_CHANNEL`, V38)? (CF-83: guild chat counts for the community chat missions) | After Test: guild (V124, V125), say something in guild chat: V125 ticks with "CHAT_MSG_GUILD argument 12: a GUID"; the log line `V125 CHAT_MSG_GUILD sender guid yes own true`. Or by hand: `/run local f=CreateFrame("Frame") f:RegisterEvent("CHAT_MSG_GUILD") f:SetScript("OnEvent", function(_, _, ...) print(select(12, ...), UnitGUID("player")) end)`, then say something in guild chat: two equal `Player-…` values. | open |
| V123 | Does `C_PvP.GetZonePVPInfo()` (or `GetZonePVPInfo()`) give the zone's PvP type ("friendly", "hostile", "contested", "sanctuary")? (`p.enemyLand`, `p.homeGuard`, `p.contested`, `b.enemyLand25`) | FriendProbe: travel through an own-faction, an enemy and a contested zone. V123 ticks with "<zone>: <type>"; `V123 zone` lines show each zone. | open |
| V127 | Does `GUILD_INVITE_REQUEST` pass the inviter and the guild's name as arguments 1 and 2? (CF-84/CF-87: the alt says "Click Accept to join <guild>." only for the guild it asked for.) For later only: may an addon accept with `AcceptGuild()`? CF-87 no longer calls it (V126 makes a "blocked" dialog likely). | On the alt outside the guild with FriendProbe: `/fp`, Test: guild invites. A member invites the alt (`/ginvite <alt name>`). V127 shows "GUILD_INVITE_REQUEST arg1 <inviter>, arg2 <guild name>". Optional, may show Blizzard's "FriendProbe has been blocked" dialog (click Ignore): before the invite click **Accept the next invite by itself (V127)**; `fail` with "blocked AcceptGuild()" means addons can't accept. Send the `V127` and `V126/V127 EVENT` lines. | open |
| V128 | Does `C_ChatInfo.SendAddonMessage(prefix, text, "GUILD")` reach the other guild members online (`CHAT_MSG_ADDON` with channel `GUILD`), and does it come back to the sender? (CF-84: the guild code is spread on the guild channel) | Two guild members with FriendProbe, both online: one presses Test: guild invites, **Guild addon message (V128)**. The other's V128 ticks with "guild addon message from <name> arrived". The sender's log: `V128 GUILD send len … -> 0` (0 is Success, 10 NotInGuild) and maybe `V128 own guild addon message came back`. Send both `V128` lines. | open |
| V129 | Does a `CHAT_MSG_SYSTEM` filter (`ChatFrameUtil.AddMessageEventFilter` or `ChatFrame_AddMessageEventFilter`) hide "No player named '…' is currently playing." after an addon whisper to a name that is offline? (CF-84: the alt whispers members who may be offline; also CF-28's V53) | Alone: `/fp`, Test: guild invites, **Whisper an offline name (V129)**. Expected no "No player named 'Nobody Atall' is currently playing." line in chat, and V129 ticks with "the filter hid 1 line(s)". `info` "the filter saw no … line" means the game printed nothing or another text: say whether a line showed. Send the `V129` lines. | open |
| V131 | Which name forms do addon whispers and guild invites take on Forever, where names have a space ("First Last")? How does `CHAT_MSG_ADDON` report the sender (with "-Realm"?), how do `C_Club.GetMemberInfo` and `GUILD_INVITE_REQUEST` give names, and does `C_GuildInfo.Invite("First Last-Realm")` work? (CF-84: the alt whispers the name the guild list gives; the member whispers back and invites with the sender's name exactly as reported, never a name built from parts) | `/fp`, Test: guild invites, **Name forms (V131)**: V131 ticks with "whisper to the name arrived true, with -Realm true; sender reported as <exact text>"; the log has `V131 V131:plain sender exactly [<text>]`. Then type `/ginvite First Last-<realm>` by hand for a friend's alt outside the guild (the form the V131 line reported): did the invite arrive? Also send the `V124 member` lines (guild names) and the `V126/V127 EVENT GUILD_INVITE_REQUEST` line (inviter's name). | open |
| V132 | Which texts does the game show when a guild invite is refused, and do they match `ERR_GUILD_PERMISSIONS`, `ERR_GUILD_NOT_ALLIED`, `ERR_ALREADY_IN_GUILD_S`, `ERR_ALREADY_INVITED_TO_GUILD_S`, `ERR_GUILD_PLAYER_NOT_FOUND_S`? Do they come as `CHAT_MSG_SYSTEM` or `UI_ERROR_MESSAGE`? (CF-84: a refused invite tells the alt to ask the next member at once) | `/fp`, Test: guild invites, **Refusal texts (V132)** (logs the six texts). Then type `/ginvite <name>` by hand for a character already in a guild, and, on a character without invite rights, on anyone. The log's `V126/V127 EVENT CHAT_MSG_SYSTEM …` or `… UI_ERROR_MESSAGE …` lines should show the same text as one of the `V132 ERR_…` lines. Send them. | open |
| V133 | Does `ChatFrame_AddMessageGroup(frame, "GUILD")` exist on Forever and add guild chat to a chat window (or, if not, does `frame:AddMessageGroup("GUILD")`)? (CF-86: the guild chat tab) | `/run print(ChatFrame_AddMessageGroup, ChatFrame1.AddMessageGroup)`: which is a function? Then the CF-86 steps: the new tab shows guild chat. | open |
| V130 | Does `EditBox:SetPassword(true)` show dots instead of the typed letters? (CF-84: the guild code field in `/cf settings`) | `/fp`, Test: guild invites: type in the box at the bottom of the window. Mark Yes when it shows dots (or stars), No when it shows the letters. | open |

## Manual test steps per story
(Added by Claude Code as stories are completed. Format: story ID, steps, expected result, status.)

### CF-91 Quiet chat
Two accounts with this build, A and B, in the community (or guild) picked on both, B a Battle.net friend of A.
`/console scriptErrors 1` on both. Watch A's chat for lines starting with "CommunitiesForever:".
1. A online, B logs in (wait a minute after A's own login). Expected on A: no "B is online on ..." line (the game's
   own Battle.net toast may show). B switches character: again no line.
2. B gains a level. Expected on A: the LEVEL UP announcement at the top of the screen, no "... reached level ..."
   chat line.
3. A finishes a Doomsday daily (or any goal). Expected: the celebration banner, no "Daily done: ..." line. When A
   finishes all three dailies first: the "First to finish today!" toast, no chat line. When B took the crown first:
   nothing in chat on A.
4. `/cf settings`: no "When friends log in", "Announce friends' level-ups", "Doomsday in chat" or "Run chat lines"
   switches; "Level-up announcement" and the Planned runs switches are there, and the window has no empty gap or
   overlap where they were. `/cf setup`, Sharing and notifications step: only Level-up announcement and the minimap
   switch.
5. A planned run that A answered I'm in (from the site), starting within the hour, organised by B. Expected on A:
   the banners at 30 and 15 minutes and at the start, no chat lines; clicking the start banner opens the run, and its
   start panel has Request invite (clicking it says "Asked ... for an invite." in chat). On B (the organiser): the
   start panel opens at the start, no "is starting now" line; "Ping on Discord" there shows "ping queued · after
   /reload" and Reload now in the panel, no chat line.
6. Still in chat: `/cf ask Deadmines` with nobody in range ("Nobody with CommunitiesForever is online ..."), the
   guild invite lines (CF-87 steps), `/cf version`, and `/cf sync debug` lines.

### CF-94 Run detail layout
This build, `/console scriptErrors 1`. Plan a run on the website for a dungeon whose range fits a few guild members who
are online now (the more the better; at least one with a long name), as organiser. Upload, then `/reload` so
`Data\Runs.lua` has it. `/cf`, Dungeons tab, click the run in the list.

| Step | Expected | Status |
|---|---|---|
| Window at its normal size: look at "Online now, fits" | The heading, its ⓘ and the rows span the full width under the divider. Each row: icon, name, "level · owner" (e.g. "15 · Basilisk") whole, Whisper at the right edge; nothing overlaps. "Edit or cancel" with its ⓘ (tooltip "Copy with Ctrl+C. Edit or cancel happens on the website.") and the link box below the last row, the box as wide as the list. | open |
| Drag the window's corner to its smallest width (it stops at 700 px) | The rows narrow with the window: Whisper stays fully visible at the right; a long name or owner is cut with "..." before Whisper, never under it. The link box narrows too and still copies with Ctrl+C. Make it wide again: the texts are whole again. | open |
| Many online (5 or more, or a short window height) | The detail scrolls; "Edit or cancel" is below the last row, nothing overlaps. | open |
| From 15 minutes before the start (Invite shows beside Whisper), at normal and at the smallest width | Name and info end before Invite; Invite and Whisper side by side at the right, neither covering text. | open |
| A run someone else organises | Same layout; the lower part is "On the website" with the link box. Your answer buttons above unchanged. | open |
| Nobody else online fits (e.g. a run for a range nobody online is in) | "Nobody else online fits" under the heading, "Edit or cancel" below it, full width. | open |

### CF-93 Ctrl+C in the guild invite window
Two people with this build, as in CF-87/CF-88: Bo online in the guild with invite rights and the guild code set, Ada's
alt outside any guild. `/console scriptErrors 1` and `/cf sync debug` on Bo (prints `[guild] invite window focus ...`
lines; `/cf sync debug` again to stop). Each step: Ada's alt logs in (or `/reload`s) to send the request.

| Step | Expected | Status |
|---|---|---|
| **The reported case, IM-style chat:** Bo sets Esc › Interface › Social › Chat Style "IM" (Classic style hides the input). Bo presses Enter to open chat, types nothing, presses Esc (or sends a word), stands still. Then the window comes. | The command is highlighted in the box, no mouse cap, no hint. `[guild] invite window focus on arrival: yes (free): ... chat open yes, chat typing no ...` (chat open may be `no`). Ctrl+C lights the first cap and the character window does not open; Ctrl+V into chat pastes `/ginvite <name>`. | open |
| Same, but Bo is **typing in chat** (input open with the cursor in it) when the window comes | The box stays unfocused (grey text, mouse cap, "Click here, then Ctrl+C" right in the box); Bo's typing goes on in chat. Line: `... no (typing in chat) ...`. Bo presses Enter or Esc to leave chat, stands still: within about a second the box takes the focus and selects the command; mouse cap and hint go (`focus on retry: yes`). | open |
| Bo **moving** (hold W) when the window comes, keeps moving for 5 s, then stops | Unfocused with the hint while moving; Bo walks on, no key is eaten. About 0.6 s after stopping the box has the focus with the command selected. Line: `... on arrival: no (moving) ...`, then `... on retry: yes ...`. | open |
| Bo in **combat** when the window comes; combat ends | Unfocused with the hint during combat; once out of combat and standing still the box takes the focus. | open |
| Box unfocused (moving, as above): Bo clicks the window's **title area or the name line** (not the box), then again with the key row | The box takes the focus and the command is selected; Ctrl+C works. Line: `invite window focus on click: yes`. | open |
| Box unfocused while Bo types in chat: Bo **clicks the box** | The box takes the focus with the command selected; the chat input keeps what Bo typed (open it again: the text is still there, or it closed as the game does when it loses focus). Ctrl+C copies. | open |
| Box focused: Bo presses **Shift**, then Alt, then Ctrl+C | The box keeps the focus; Ctrl+C lights the first cap. | open |
| Box focused: Bo presses **W**, then stands still for 5 s | The box lets go (`[guild] invite window: W let go of the focus`); it does not take the focus back by itself; the hint shows again. A click focuses and selects. | open |

### CF-88 The guild invite window (designer's flow)
Two people with this build, as in CF-87: Bo online in the guild with invite rights and the guild code set, Ada's alt
outside any guild. `/console scriptErrors 1` on both. No addon whisper (menu or Whisper button) before the steps,
else `/reload`. The main flow (window, the four keys, sent, Accept) passed in Nico's test of build 12 (2026-11-05);
these are the steps it did not cover.

| Step | Expected | Status |
|---|---|---|
| Again with Bo **moving** (or in combat, or typing in chat) when the window comes | The box is not focused, its text grey and not highlighted, and a mouse cap comes first (outlined). Bo's keys keep working for the game. One click on the box: text highlighted, the mouse cap gold, Ctrl+C outlined. Then the flow as above. (CF-93: it now also takes the focus by itself once Bo is free, see CF-93.) | open |
| Box focused: Bo presses **W** | The box lets go of the focus (the W is lost once, Bo doesn't walk); the text stays. Typing into the box after a click puts the command back. | open |
| Window open: **Esc** (box focused, then again with it unfocused out of combat), and the **X** | The window closes; nothing in chat, nothing sent; the alt asks the next member after 2 minutes. | open |
| Bo without invite rights: Ctrl+C, Enter, Enter, Ctrl+V, Enter | The game's red "You don't have permission to do that."; the window closes at once; Bo's chat: "<alt> (Ada's alt) will ask someone else."; the alt at once: "Asked <next member> for an invite into <guild>." | open |
| Two of Ada's alts ask within seconds (log one in, then another) | One window; the second request replaces the first in place: new name and command, caps reset, a gold edge for a moment. No second window. | open |
| At 3440×1440 (or the largest resolution you have) | The window sits top centre, larger with the UI, not over the action bars, the red error line or the run reminder banner. | open |
| A long name (e.g. a "First Last-Realm" sender) | The window grows wider (up to 520 px at UI scale 1); the name line wraps to at most two lines. | open |

### CF-87 Guild invites by copy and paste
Two people with this build, as in the CF-84 steps: Bo online in the guild with invite rights and the guild code set,
Ada's alt outside any guild. `/console scriptErrors 1` on both. Do not use the addon's whisper menu or Whisper buttons
before these steps (`/reload` if you did): they fill the chat input from addon code (see the PR).

| Step | Expected | Status |
|---|---|---|
| Bo types a letter into the box, then clicks in it | The text stays `/ginvite <alt name>` and is highlighted again each time. | open |
| Kick the alt and invite it again by hand once (`/gremove <alt name>`, `/ginvite <alt name>`, alt declines), log the alt out and in again; Bo presses **Esc** in the window | The window closes; nothing is sent. The X closes it too. | open |
| Bo without invite rights: the window comes, Bo pastes and sends within a minute | The game's "no permission" line; with `/cf sync debug` on Bo: `[guild] invite … refused: rights`; the alt asks the next member at once. | open |
| Bo waits more than 2 minutes before pasting | The alt has already asked the next member (if one is online); Bo's later invite still arrives and still confirms. | open |

### CF-90 Guild members known by their BattleTag
Two accounts with this build, A and B, both in the guild picked as the community, **not** Battle.net friends of each
other. Both online in Forever, with `/console scriptErrors 1`. Replace `<B's BattleTag>` with B's real one (as in
B's `/run print(CommunitiesForeverDB.global.self.battleTag)`).

| Step | Expected | Status |
|---|---|---|
| On A before updating (any older version that synced with B): `/run for k in pairs(CommunitiesForeverDB.global.people) do print(k) end` | B is listed as `aid:<12 hex>`. | open |
| Update A and B to this build, log both in, wait ~15 s (or `/cf sync` on both) | Nothing in chat. | open |
| On A: `/run local p=CommunitiesForeverDB.global.people["<B's BattleTag>"] print(p ~= nil, p and p.aid)` | `true` and B's 12-hex account ID. | open |
| On A: `/run local n=0 for k in pairs(CommunitiesForeverDB.global.people) do if k:sub(1,4)=="aid:" then n=n+1 end end print(n)` | `0` (or only members on an older version). | open |
| On A: `/cf` | B shows once, named by B's display name or the name part of B's BattleTag (not B's first character), with B's character online. | open |
| The same three `/run` lines on B with A's BattleTag | The same: A under A's BattleTag. | open |
| B levels up or changes gear; on A after ~15 s: `/run print(CommunitiesForeverDB.global.people["<B's BattleTag>"].version)` | A newer version; no `aid:` entry for B appears again. | open |
| A third member C on an **older** version, online with A | A keeps C under `aid:`, C keeps A under `aid:`; both still sync (C's level-up reaches A). | open |
| Upload A's SavedVariables to the site | B shows under B's Battle.net account (WEB-86), not as "Unknown player". | open |

### CF-89 Only the group takes part
Two accounts with the addon on this build, both in the guild picked as the community (A and B), plus a Battle.net
friend C who runs the addon (any version) and has **no** character in the guild. All three online in Forever, with
`/console scriptErrors 1`. Before updating A, note what A has stored about C:
`/run local n=0 for g,p in pairs(CommunitiesForeverDB.global.presence) do if p.battleTag=="<C's BattleTag>" then n=n+1 end end print(n, CommunitiesForeverDB.global.people["<C's BattleTag>"] ~= nil)`.

| Step | Expected | Status |
|---|---|---|
| Update A to this build, log in, wait ~10 s, then run the line above again | `0 false`: C's links and record are gone. | open |
| On A: `/run local n=0 for _ in pairs(CommunitiesForeverDB.global.members) do n=n+1 end print(n)` | The guild's member count (as in `/cf members`). | open |
| On A: `/cf sync debug`, then `/cf sync` | Lines `to <B's BattleTag>: HELLO ...` for B; for C only `not to <C>: not in the community`, never `to <C>: HELLO`. `/cf sync debug` again to stop. | open |
| On C: `/reload` (C greets A) | A's chat shows nothing from C; A's window does not list C. | open |
| On A: `/reload`, then the line from the top again | Still `0 false`. | open |
| On C (if C runs this build): the same line with A's BattleTag | `0 false`: C stores nothing about A either. | open |
| B logs in on an alt **outside** the guild | A and B still sync: B's alt shows under B in A's window after B levels or `/cf sync`. | open |
| On A: `/cf ping` | "Ping sent to N game account(s)" counts only friends in the guild (B), not C. | open |
| Upload A's SavedVariables to the site | C is not a site member; B is. | open |

### CF-86 A chat tab for the guild
On a character in the guild, with the guild picked in `/cf settings` and `/console scriptErrors 1`. Answers V133.
Remove an earlier test tab first (right-click its tab, Close Window) if one named after the guild exists.

| Step | Expected | Status |
|---|---|---|
| `/run print(ChatFrame_AddMessageGroup, ChatFrame1.AddMessageGroup)` | At least one prints `function: ...` (V133). | open |
| `/cf setup`, Next to the "Community chat" step | It says "Your community is a guild: give guild chat its own chat tab, so you never miss it."; no colored sample line, no flash, sound or "Keep community messages in General too" switches; the buttons are "Not now" and "Create chat tab". | open |
| Click "Create chat tab" | A new chat tab named after the guild; chat says "Created the <guild> chat tab." The setup moves on to Notifications. | open |
| Let a guild member write in guild chat (or write yourself) | The message shows in the new tab, in Blizzard's guild green, and still in General. No officer chat or achievements in the new tab. The tab does not flash and no sound plays. | open |
| Right-click the new tab, Settings (or Chat tab settings) | Only "Guild" is ticked under the chat types; no channels. | open |
| `/cf setup`, Next to the chat step again | "This character has a <guild> chat tab."; the buttons are Next and Skip setup, no "Create chat tab". | open |
| `/cf settings`, Community chat | Only the "Create a community chat tab" button; no chat color, Reset, flash, sound or General switch. Click the button: chat says "This character already has a <guild> chat tab."; no second tab. | open |
| `/reload` | The tab is still there and still shows guild chat. | open |
| Log in on another character of yours in the guild (that never answered the tab prompt) | After ~5 s: "Create a Community tab on this character too?" with "A tab with only your guild chat."; Create tab makes the guild tab there. | open |
| An alt **not** in the guild: `/cf settings`, Create a community chat tab | Chat says "Select a community first (and log in on a character that is a member)."; no tab. | open |
| Pick a character community in `/cf settings` | The color, Reset, flash, sound and General switches are back; "Create a community chat tab" makes the community tab as before (purple community chat only). | open |

### CF-85 No community: quiet Doomsday, a clean Dungeons tab
On a character in no guild and no character community, with `/console scriptErrors 1`. Clear the account's pick
first: `/run CommunitiesForeverDB.global.settings.clubId = nil`, then `/reload` (pick it again in `/cf settings` on
your main afterwards).

| Step | Expected | Status |
|---|---|---|
| Finish a Doomsday daily (or all three, for the crown) | No celebration banner, no banner sound, no "First to finish today!" popup under the minimap, no Doomsday chat line. `/cf`, Doomsday tab: the goal is ticked with its points. | open |
| `/cf settings`, Preview (next to Celebration banners) | The sample banner still shows (you asked for it). | open |
| `/cf`, Dungeons tab | Left: only the "Dungeons" title, no chips, "No runs planned", "In range for" or "Show all dungeons". Right: "Nothing planned yet" and the explanation "You're not in a community yet. ...", no "Ask now..." or "Copy website link" button and nothing faded behind the text. | open |
| Stand where nameplates or other characters are behind the window, `/cf` | The window's background is solid on every tab: no faint names, nameplates or frames of the game show through it. The level-up and crown toasts are solid too. | open |
| Join a guild (or a character community) with this character | Chat says `Showing community <name>. Change it with /cf settings.`; no banner or popup for the goals already done; the Doomsday tab still shows them done and today's points count. The next goal you finish shows its banner as usual. | open |
| On a character outside the selected community (the account has one picked), `/cf`, Dungeons tab | Right: the "isn't a member" text, then "Ask now..." (and "Copy website link" when the runs file has the site) below it, not on top of it. | open |

### CF-84 Automatic guild invites for alts
Needs V124 (the guild as the community) and the build's `CommunitiesForever_Vault` folder next to `CommunitiesForever`
in `Interface\AddOns` (`tools\build.ps1` copies both). Two people: you (Ada) with a main in the guild and an alt outside
any guild, the other (Bo) online in the guild with invite rights, both on this build with the guild picked in
`/cf settings`. `/console scriptErrors 1`.

| Step | Expected | Status |
|---|---|---|
| Ada's main: `/cf settings` | Under the invite area a **GUILD CODE** field; the line under it says "No guild code yet: alts outside the guild don't ask members for an invite." Pick a character community instead: the field is gone; pick the guild again. | open |
| Type `abc` in GUILD CODE, Enter | Chat: "The guild code needs at least 6 characters."; nothing saved. | open |
| Type a code of your own (6 or more characters), Enter | The field shows dots while typing (V130) and is empty after Enter; chat: "Guild code saved. Members' addons share it with each other in the guild."; the line says "A guild code is set (<date time>). …". The code shows nowhere: not in chat, not in the field. | open |
| `/reload`, then open `WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` and `CommunitiesForever_Vault.lua` (after a logout or `/reload`) | `CommunitiesForever.lua` does not contain the code. `CommunitiesForever_Vault.lua` has it under `guilds["<guild name, lower case>"]` with `at` and a `roster` of the guild's members. | open |
| Bo, within a minute of Ada setting the code (or after Bo's next login): `/cf settings` | Bo's line says "A guild code is set (<same date time>)": the code came over the guild channel (V128). | open |
| Ada logs out the main and logs in the alt outside the guild; Bo stays online | Within ~20 s chat on the alt: "Asked Bo <name> for an invite into <guild>." On Bo's side a small window "Invite <alt> (Ada's alt)?" with `/ginvite <alt name>` to copy into chat (CF-87 steps). After Bo's invite: Blizzard's invite popup on the alt and the chat line "Click Accept to join <guild>." (V127); Accept, and the alt is in the guild. Bo's chat: "Invited <alt> (Ada's alt) into the guild." No "blocked from an action" dialog on either side. | open |
| Same, with the member who was online most recently before now offline | No "No player named ... is currently playing." line on the alt (V129); the next member is asked at once. | open |
| A third guild member (Cy) online too, with this build | Only one of Bo and Cy gets the Invite window (the other sees the claim). | open |
| An alt in another guild, or the guild picked without a code | Nothing is whispered (with `/cf sync debug` on before the login timer, about 15 s: no `[guild] to …: GINVREQ` line); a hand invite from anyone gives no "Click Accept" line. | open |
| A bank alt of Ada's in **another** guild logs in (the account's pick is the guild) | The pick stays: `/cf settings` still shows the guild; no "Showing community" line; `/cf members` says the character is not a member. Nothing is whispered. | open |
| An alt of the **other faction** (or on another ruleset realm) logs in, outside the guild, code known | One chat line: "This character can't join <guild>: the guild is on the other faction. It won't ask for an invite again." (or "… on another realm …"). No whispers. `/reload`: no line, no whispers. | open |
| Bo has **no invite rights** (take them away for the test); Cy has them; Ada's alt logs in | Bo pastes the window's `/ginvite` line into chat and sends it: the game's own "no permission" line; the alt then asks the next member at once (with `/cf sync debug` on Bo: `[guild] invite … refused: rights`), and Cy gets the window; Cy's pasted invite arrives. | open |
| Ada sets a new code on her main while Bo is **offline**; Bo logs in later with the old code | Bo's code is replaced by Ada's (Bo's settings line shows Ada's time); Ada's is not replaced by Bo's old one, whatever the PC clocks say. | open |
| Kick Ada's alt from the guild (or let it leave), then log it in again | No Invite window: members ignore its request ("No member … answered" once a day at most). The removed character is in `CommunitiesForever_Vault.lua` under `removed` on every member's account that saw it (GKICK). | open |
| Bo invites that alt by hand (`/ginvite <alt name>`) | The invite arrives; after the alt joins, its removal is lifted on every member's account (it is back in the guild list). Kick it again, and the next automatic request is ignored again. | open |
| Ada changes the code on her main to a new one; Bo has the old one | Within a few seconds Bo's line shows the new time. Ada's alt (next login) gets in with the new code; a member still holding the old code ignores the request (the next member answers). | open |

### CF-83 The guild as the community
On a character in a guild that is also in a character community (or in a guild only, for the first step), with
`/console scriptErrors 1`. Answers V124 and V125 first: without `clubType = 2` in the club list the guild never shows.

| Step | Expected | Status |
|---|---|---|
| A character in a guild and in no community, nothing picked yet (`/run CommunitiesForeverDB.global.settings.clubId = nil`, `/reload`) | Chat says `Showing community <guild name>. Change it with /cf settings.`; `/cf` shows the guild members, grouped per Battle.net friend. | open |
| `/cf settings`, Community | The list has the guild next to the character communities; the line below says "Character communities and your guild are listed. Battle.net communities are not supported." | open |
| Pick the guild, then the community, then the guild again (no `/reload`) | Each time `/cf` shows that club's members at once; friends' characters, levels, professions and Doomsday points stay. | open |
| With the guild picked: say something in guild chat | The Doomsday goal "Say something in the community chat" ticks (if drawn today); "Chat in the community on 5 days" counts the day. | open |
| With the guild picked, as guild master: `/cf settings` | No "Community invite link" field. An alt outside the guild sees no "How to join" steps and no "Post invite link in chat". | open |
| A friend with the guild picked, both online | Their characters sync as before (`/cf sync debug` shows the HELLO on the hidden `cf…` channel). | open |

### CF-82 The hidden launch probe
On Forever with this build (not FriendProbe), play as usual for a while: target or mouse over enemy players, loot, die
once, open a merchant. The probe's checks are FriendProbe's automatic ones (V35b to V123), so their answers close the
same open questions above.

| Step | Expected | Status |
|---|---|---|
| Play for 10 minutes, including a fight and a loot | Nothing from the probe in chat, no window, sound or popup, no Lua error (`/console scriptErrors 1` first). | open |
| `/cf help` | No `/cf fp` line. | open |
| `/cf fp` | One chat line `Probe (forever): N pass, N fail, N info, N open; running until 18 November.` and a "Launch probe" dialog with one line per check, selected; it scrolls (`UIPanelScrollFrameTemplate`, unverified: without it the text still copies whole with Ctrl+A, Ctrl+C). Esc leaves the field. | open |
| `/reload`, then open `WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` | `["probe"]` under `global` with `["results"]` > `["forever"]`, items with `status`, `detail`, `at`, `build`; no chat text, no player names except the Hunt's victim and the V120 killer. Section well under 30 KB. | open |
| The uploader sends the file; the site's upload page | The upload is accepted as usual (the site ignores `probe`). | open |
| `/run print(CommunitiesForever.Probe.running(CommunitiesForever.Probe.STOP_AT, {}))` | `false`: from 2026-11-18 00:00 UTC the probe registers nothing at login and keeps its results. | open |

### CF-77 Pool version 2
The release day's draw with this build: `/run local D,s=CommunitiesForever.Doomsday,CommunitiesForever.DoomsdayTracker.schedule(); local n=D.day(GetServerTime(),s.offset,s.reset); print(D.POOL_VERSION, table.concat(D.draw(n).dailies," "), table.concat(D.drawWeek(D.week(n)).weeklies," "))` (call it "the draw line" below).

| Step | Expected | Status |
|---|---|---|
| Two friends on this build, on the release day: the draw line on both, and compare the Doomsday tab | Both print `2` and the same 3 dailies and 3 weeklies; the tabs show the same 3 dailies (or their swaps). The 3 weeklies are of 3 different kinds. | open |
| A friend still on v1.1.0, same day: their Doomsday tab | They see pool version 1's dailies (the ones the site shows for version 1), not the new ones. No errors on either side. | open |
| On this build, a day that was already drawn before the update (log in on v1.1.0, log out, update, log in): `/run for n,e in pairs(CommunitiesForeverDB.global.self.goals.days) do print(n,e.pool,table.concat(e.set," ")) end` | That day keeps its set and prints `pool` nil (read as version 1: its goals score 5 each); the next day's entry prints `2`. | open |
| Finish a new daily (e.g. Say something in the community chat, if drawn) | Its banner and the week's total show its size (+1, +3 or +5), not +5 for every goal. | open |

### CF-73 Friends and places for Doomsday missions
The missions aren't in the draw yet (pool version 2, CF-77): check the facts with this command (call it "the places line" below): `/run for n,d in pairs(CommunitiesForeverDB.global.self.doomsday.days) do local p=d.places; if p then local z,nz=0,0; for _ in pairs(p.zones) do z=z+1 end; for _ in pairs(p.newZones) do nz=nz+1 end; print(n,'zones',z,'new',nz,'sea',p.crossSea,'nost',p.nostalgia,'dare',p.daredevil,'same',p.sameZone,'online',p.onlineMax,'carry',p.carry,'chat',p.chat) end end`

| Step | Expected | Status |
|---|---|---|
| First login with this build, then `/run local n=0; for _,s in pairs(CommunitiesForeverDB.global.self.doomsday.zonesSeen) do for z in pairs(s) do n=n+1 end end; print(n)` | A number above 0 on a character that handed in quests before (the zones of the stored feed). | open |
| Ride into 2 other zones; the places line | `zones` went up by 2 (the login zone counts too). A zone this character never quested in before counts in `new`; going back to it doesn't count again. | open |
| Enter a dungeon and leave it | `zones` doesn't count the dungeon (only zones outside instances). | open |
| Take the boat or zeppelin to the other continent | `sea` true. The Deeprun Tram doesn't count. | open |
| Zone level names (V46, zones part, unverified): `/run local l=C_LFGList; for _,a in ipairs(l.GetAvailableActivities(116) or {}) do local i=l.GetActivityInfoTable(a); print(i.fullName,'/',i.shortName,i.minLevelSuggestion,i.maxLevelSuggestion,i.difficultyID,i.maxNumPlayers) end` and compare with `/run print(GetRealZoneText())` in a few zones | The zones are listed with their level range, and the full or short name matches `GetRealZoneText()` exactly (e.g. "Elwynn Forest"). Answered: move it to `docs/API-FINDINGS.md`; if names differ, say how. | open |
| A level 30+ character enters a starting zone (e.g. Elwynn Forest) | `nost` true. | open |
| A character enters a zone whose lowest suggested level is 5 or more above its level | `dare` true. | open |
| Club member zone text (V18): with a friend's community character online in your zone, `/run for _,m in pairs(CommunitiesForever.MemberTracker.members()) do print(m.name,m.zone,m.presence) end` | The friend's `zone` is the same text as your `GetRealZoneText()`. | open |
| With a friend's community character online; the places line | `online` 1 or more; `same` true while both are in the same zone. A friend on the mobile app (presence 2) doesn't count. | open |
| Group with a friend's community character 5 or more levels lower | `carry` 1 or more; with one 4 levels lower, or your own alt, it stays. | open |
| Say something in the selected community's chat | `chat` 1 or more; a friend's message doesn't count, nor one in another community. | open |
| A friend on v1.1.0 | No errors on either side; their Doomsday tab looks as before (nothing new is sent). | open |

### CF-79 The weekly and PvP catalogues in code
The new missions wait for data (no `since`) and their trackers; nothing new is drawn until pool version 2 (CF-77).

| Step | Expected | Status |
|---|---|---|
| On this build, Doomsday › Week on the same week as a friend on the previous build | The same 3 weeklies and the same Bounty on both, and the same swaps (pool version 1 unchanged). | open |
| Doomsday › Today on the same day as that friend | The same Skirmish on both. | open |

### CF-78 Only a real fight ends PvP Virgin
Taunt and flag goals arrive with pool version 2 and later (CF-79, CF-81); until then the steps check the battleground and that nothing else changed.

| Step | Expected | Status |
|---|---|---|
| A friend (or an alt's BattleTag) with no honorable kill and no duel finishes a battleground (won or lost); `/reload`; Doomsday › Ladder | That friend is ranked on the PvP ladder (no longer under "PvP Virgin · not ranked"). | open |
| A friend who never fought | Still under "PvP Virgin · not ranked"; on Today's mini board "PvP Virgin". | open |
| A duel between two friends who never fought, then `/reload` | Both ranked on the PvP ladder. | open |
| Once a taunt goal is in the pool (pool version 2+): a friend who only did that goal | Shows as Conscientious Objector with the PvP points, not ranked; after a duel, ranked. | open |

### CF-71 Quest details for Doomsday missions
The quest missions aren't in the draw yet (pool version 2, CF-77): check the facts with this command (call it "the facts line" below): `/run local f=CommunitiesForeverDB.global.self.doomsday.days; for n,d in pairs(f) do local q=d.quests2; if q then print(n,'up',q.up,'group',q.group,'class',q.class,'dungeon',q.dungeon,'duo',q.together,'burst',q.burst,'accepted',q.acceptedCount) end end`

| Step | Expected | Status |
|---|---|---|
| Log in, `/reload`, then `/run for id,q in pairs(CommunitiesForeverDB.global.self.chars[UnitGUID("player")].quests) do print(id,q.title,q.level,q.suggestedGroup) end` | Each quest has its level; group quests (shown with "Group" in the quest log) have a number, normal quests `nil`. | open |
| Accept 2 new quests, abandon one, accept it again; the facts line | `accepted` went up by 2 (taking a quest again counts once). | open |
| `QUEST_ACCEPTED`'s arguments (unverified: `questID` on Mainline, `questLogIndex, questID` on Classic; CF-71 takes the last number): after accepting a quest, `/run for n,d in pairs(CommunitiesForeverDB.global.self.doomsday.days) do for id in pairs(d.quests2 and d.quests2.accepted or {}) do print(n,id) end end` | The accepted quest's ID is listed (its ID on wowhead), not a small log index (1 to 40). Answered: move it to `docs/API-FINDINGS.md`. | open |
| Hand in a quest whose level is above your character's level; the facts line | `up` 1. A quest at or below your level doesn't count. | open |
| Hand in a group quest (`suggestedGroup` above 0) | `group` 1. | open |
| Hand in a class quest (quest log header is your class name) | `class` 1. | open |
| Hand in a dungeon quest (dungeon header or the Dungeon tag) | `dungeon` 1. | open |
| Hand in 3 quests within 10 minutes on one character | `burst` 3. | open |
| In a group with a friend's community character, hand in a quest | `duo` 1; with only your own alt or a stranger, it stays. | open |
| A friend on v1.1.0 receives your record | No errors; their quest lists (Friends tab, shared quests) look as before. | open |

### CF-69 Points per mission
Pool version 2 (CF-77) is what turns the sizes on; until then the points stay 5 and 15. These steps check that days carry their pool version and nothing changed.

| Step | Expected | Status |
|---|---|---|
| After a reset on this build: `/run for n,e in pairs(CommunitiesForeverDB.global.self.goals.days) do print(n, e.pool) end` | The newest day (the highest number) prints `1`; days recorded before this build print `nil`. | open |
| Finish a PvE daily, then a weekly | Chat line, banner and Today show +5 and +15, as before; the week's total adds them. | open |
| A friend on v1.1.0 or older syncs while you are online | No errors on either side; their points and yours on Board and Ladder are as before. | open |
| After CF-77 (pool version 2): finish a 1-point daily (e.g. Light a campfire) | Its chat line and banner show "+1"; the week's total grows by 1. | open |

### CF-72 Records missions: levels, play, dungeons (tracking only, not in the draw yet)
No new API: `GetInstanceInfo` (V35), the group (V35), `PLAYER_LEVEL_UP`. The missions are not drawn until pool
version 2 (CF-77), so check the facts. "Today's records" below means:
`/run local d=CommunitiesForeverDB.global.self.doomsday.days local n=0 for k in pairs(d) do if k>n then n=k end end for k,v in pairs(d[n].records or {}) do print(k,type(v)=="table" and #v or tostring(v)) end`
(tables print 0: use `/dump CommunitiesForeverDB.global.self.doomsday.days` for their contents).

| Step | Expected | Status |
|---|---|---|
| First login with this build; `/dump CommunitiesForeverDB.global.self.doomsday.dungeonsSeen` | The dungeons of your feed's party runs (last 7 days) per character GUID; `{}` without runs. No Lua error. | open |
| Gain a level on a character below level 20, outside a group; today's records | `lowbie 1`, `dingDungeon 0`, `dingFriend 0`. | open |
| Gain a level inside a dungeon, grouped with a friend's character from the community; today's records | `dingDungeon 1`, `dingFriend 1`. | open |
| In a dungeon new to the character, kill the first boss; `/dump CommunitiesForeverDB.global.self.doomsday.dungeonsSeen` and `/dump CommunitiesForeverDB.global.self.doomsday.days` (newest day, `records.newDungeons`) | The dungeon is in the character's set; `newDungeons` has a key with the GUID and the dungeon. Kill a second boss: nothing new added. | open |
| Kill 3 bosses of one dungeon within 45 minutes of entering; today's records | `speedRun true`. | open |
| Raise Cooking (or Fishing, First Aid) by a few points; `/dump CommunitiesForeverDB.global.self.doomsday.days` (newest day, `records.skillGain`) | `[185]` (Cooking), `[356]` (Fishing) or `[129]` (First Aid) holds the points gained today. | open |
| Log in a character you last played 2 or more Doomsday days ago; today's records | `switchUp true`; `dustOff true` only if its last play was 7 or more days ago. The first login of each character with this build counts as unknown (no credit). | open |
| `/reload` | No change to `switchUp`/`dustOff` (the last login is now), no Lua error. | open |

### CF-68 Doomsday schedule from the site
Needs the site's Mission pool page (web WEB-78) and the uploader. Pick a day at least 2 days ahead (today and tomorrow are locked on the site).

| Step | Expected | Status |
|---|---|---|
| On the site's Mission pool page change that day's dailies and Skirmish; let the uploader write `Data\Runs.lua`; `/reload`; `/run print(CommunitiesForeverDB.global.doomsdaySchedule.v)` | Prints the site's `v` (a server time). | open |
| On that day (after the reset), `/cf doomsday` and Doomsday › Today | The scheduled dailies and Skirmish show, with swaps only where your characters can't do one. The days before and after show the normal draw. | open |
| A friend on this build without the uploader logs in while you are online | Within a minute their `/run print(CommunitiesForeverDB.global.doomsdaySchedule.v)` prints the same `v` (HELLO `ds`, SCHEDREQ, SCHED); on that day their Today shows the same missions. | open |
| Change the same day on the site again before it is locked; uploader; `/reload` | The new `v` replaces the old on you and, within a minute, on the friend. | open |
| A friend on v1.1.0 (or older) | No errors; on that day they show the normal draw (no schedule support). | open |
| `/reload` during a scheduled day after the site changed that day again | Today keeps the set it had: a day that has started never changes. | open |

### Bug hunt: Doomsday refreshes at the reset
| Step | Expected | Status |
|---|---|---|
| `/cf`, Doomsday › Today, leave it open a few minutes | "New goals … in X h Y m" drops by a minute each minute without clicking anything. | open |
| Keep the Doomsday tab open across 19:00 realm time (or the site's reset), standing still | Within a minute of the reset: the header shows the next day ("Today · <day> · 0 of N done"), new goals, "in 23 h 59 m"; a swapped goal gets its chat line. A friend with the addon sees your new day on their Board without you doing anything. | open |

### CF-67 Celebration banners (boards in docs/design/celebrations-2026-11/)
Compare each banner with its board. Your own banners sit centred low on the screen, just above the action bars.

| Step | Expected | Status |
|---|---|---|
| CB01: finish a PvE daily (`/cf doomsday` shows which) | About 3 s later a small plaque (400 × 64) with a green top edge, the gold check box in the medallion, "DAILY GOAL · PVE", the goal, "<day> · N of 5", "+5" on the right; a short game sound (V88). 4 s, then it fades and sinks. Finish the Skirmish: the same with a red edge, "DAILY GOAL · PVP" and the Skirmish's name ("Lone wolf"). | open |
| CB02: finish the third PvE daily | One medium plaque (470 × 80), gold edge, the Doomsday emblem, "DAY COMPLETE", the day's name, "PvE N · PvP N · <flame> N days" (points side by side, never a total). First in the group that day: a gold crown on top of the medallion. No separate daily banner for that last daily. 5 s. The crown toast under the minimap still comes too. | open |
| CB03: finish a weekly; the Bounty | Medium, blue edge, the hourglass, "WEEKLY GOAL", the goal, "Week NN · N of 4", "+15". The Bounty: red edge, crossed swords, "BOUNTY", the goal, "Week NN". | open |
| CB04: a feat (a level 10, 20, … ding, a new PvP rank) | Medium, gold edge, "FEAT UNLOCKED", the feat, the character. A special one (level 60, PvP rank 6+, first epic, a mount, 1,000+ kills) or one nobody in the group had: big (540 × 98), rays turning slowly and a glow behind the medallion, 6 s; "First in the group" as a gold tag after the title. The first epic: violet edge and the robe. | open |
| CB05: several at once (a level that finishes a daily and the day, a feat) | One banner, the heaviest; under it one grey line such as "Day complete · +3 goals · crown". One sound only. | open |
| CB06: a friend (on this build) finishes the day, a weekly or a special feat while you are online | Bottom left, above the chat: one line with their round class portrait, "<friend> <character> · completed the day" (or "finished a weekly", "is now a Stone Guard", "looted <item>", "reached level 60"), a coloured left edge, no sound, 4 s; up to 3 stack upwards; they wait while your own banner shows. Nothing for what they did before you logged in. | open |
| CB07: the place at 1920 × 1080 and at 1280 × 720 (or any width below 1600) | The banner centred, its bottom about 190 px above the screen's bottom, clear of the action bars, the chat and the top of the screen (LEVEL UP pill, run banners, crown toast). Below 1600 px wide it is 85 % of its size. | open |
| CB08: motion; hover, click, right-click | In: rises 16 px and fades in, the medallion with it (no pop). Out: fades and sinks 8 px. Ambient effects off: no movement at all. Hovering pauses it and shows "Click to open Doomsday" ("Click to open Feats" on a feat); a click opens the window on Doomsday › Today (goals, day), Week (weeklies), Feats (feats) or Board (a friend's line); right-click closes it at once. | open |
| CB08: in combat, a boss fight or a battleground | Finish a goal in combat: nothing until 2 s after combat ends, then the banner (folded with anything else). In a battleground: after you leave. | open |
| CB09: `/cf settings` | Under Interface a section "Celebrations": "Celebration banners", "Celebration sounds", "Friends' celebrations", all on, and a Preview button; tooltips on each. Banners off: no banners and no sounds, and "Friends' celebrations" greys out (still visible). Sounds off: banners without sound. Preview: a medium sample banner for 5 s with its sound. | open |
| No doubles | `/reload` right after a banner: it doesn't come again. The first login after updating: no banners for goals or feats you already had. | open |

### CF-66 The minimap button's shield
| Step | Expected | Status |
|---|---|---|
| Log in at 1080 × 720 with the minimap button on | The button shows the gold shield with a cross inside LibDBIcon's round ring, sharp, not stretched; no green square or question mark (that would mean `media\textures\mapicon.tga` is missing). Hover: the tooltip as before; left-click opens the window, right-click the settings. | open |
| Retail (and Forever, if it has one): the addon compartment (the button next to the minimap that lists addons) | CommunitiesForever is listed with the same shield; clicking it opens the window. Hide the minimap button in the settings: it leaves the compartment too; show it again: back. | open |
| Esc > Options > AddOns, or the AddOns list at character select | CommunitiesForever shows the shield as its icon (`## IconTexture`). | open |

### CF-63c Dungeons tab: the list, in range, planning (board CF63List)
| Step | Expected | Status |
|---|---|---|
| `/cf`, Dungeons | Under "Dungeons  Ask now…" the chips All, My runs, Open slots, In range (All on). Compare with `docs/design/cf-63-2026-10/CF63List.dc.html`. | open |
| Click My runs, Open slots, In range | Planned shows only the runs you organise or are in or maybe; runs with a free slot; runs whose dungeon fits the character "In range for" follows. A chip that hides all says "No runs here". | open |
| Close the window and open it again | The chips are back on All. | open |
| "In range for  Ves Doombringer (23) ▾" | Click it: your characters "Name (level)", highest first; pick an alt: the list and its dungeons follow that character until the next login. Hover: "Ranges are typical levels; …". One line per dungeon: "Wailing Caverns   17–24 · 3 fit". | open |
| Tick "Show all dungeons" | "Other dungeons" lists the rest, greyed. Pick one out of range: under the title "Ves Doombringer 23: too low · Valen Duskward 58: fits" (your alt, when one fits). | open |
| A dungeon with nobody else online | "Suggested group ⓘ" (hover: "Friends’ and your characters whose level fits, online or not.") with full-width rows; "Online now, fits" says "Nobody else online fits"; then Quests, Ask now and Plan a run…. | open |
| A character below level 13 with no run you're in | Left: "No dungeon fits yet"; right, centred: "No dungeon fits yet", "First one: Ragefire Chasm at level 13", "Show all dungeons", "Pick another character". | open |

### CF-63b Dungeons tab: answering inline, group rows (boards CF63Answer, CF63Group)
| Step | Expected | Status |
|---|---|---|
| A run someone else organises (website, Discord or game), not answered yet | Under the group: "Your answer  Not answered yet"; I’m in / Maybe / Can’t; a dropdown with your character ("Vesgar Bloodhoof  31  fits"); the roles your class plays ("Healer · open", "Damage · full"); "Note to the organiser" with "0/80". Compare with `docs/design/cf-63-2026-10/CF63Answer.dc.html`. | open |
| Click I’m in | Saved at once (no Save button): "You’re in", I’m in highlighted, a pocket watch next to it (hover: "Saved. Reaches the website with your next upload."); your own group row shows your character and role. A friend organising it and online sees your row change within seconds. | open |
| Open the dropdown | All your characters, each with its fit ("31 · fits", "23 · 3 below", "48 · carry · +12"). Pick another: saved at once, the role toggles follow its class. | open |
| Hover a full role, then click it | Tooltip "Damage is full · you join as reserve."; after the click "You’re on reserve". | open |
| Type a note, press Enter (or click elsewhere) | Saved; the counter shows the length ("14/80"); at most 80 characters fit. After `/reload` and the upload the website and Discord show the note on your answer. | open |
| Click Can’t | "You can’t make it"; the dropdown, roles and note disappear. | open |
| Hover a member's row | Tooltip: the character; "Level 30 · fits · Tank"; "Answered on the website, Mon 21:12" (or Discord, in game); their note in quotes if any; "Online on <character> · <zone>" when online. | open |
| Right-click a member's row | Menu with their name: Whisper (opens a whisper), "Invite · from 20:15" (greyed until 15 minutes before the start, and in combat), Show in Friends (opens the Friends tab on their character). Your own row has no menu. | open |
| An open slot | "Damage · open" with "Ask now for this run" on the right: it opens Ask now with the note "For SM: Graveyard 20:30 · need damage". Click the row: a menu "Damage · open" with "Whisper <the first who fits>" (opens the chat box with "Up for SM: Graveyard at 20:30? We need damage." filled in; you press Enter), Ask now for this run, "Invite · from 20:15". | open |

### CF-63d Run reminder banners (board CF63Banners)
| Step | Expected | Status |
|---|---|---|
| Answer I’m in to a run that starts in 31 minutes (or plan one), wait | At 30 minutes before: a banner top centre, below where LEVEL UP shows: "In 30 minutes", "SM: Graveyard" large, "Healer · Vesgar Bloodhoof · 20:30"; gold lines above and below; it fades in, stays 10 s, fades out. A soft chime. The chat line "… starts in 30 min …" as before. No note under the minimap any more. Compare with `docs/design/cf-63-2026-10/CF63Banners.dc.html`. | open |
| 15 minutes before | "Invites open". As the organiser also "Invite all" (greyed in combat, tooltip "Not in combat"); clicking it invites everyone in and online. | open |
| At the start | "Starting now"; the organiser's start panel opens as before. | open |
| Click a banner | The window opens on that run. | open |
| Be in combat (or a battleground) when one comes due | No banner until combat ends; then only the latest one for that run, and none from before a start that has passed. | open |
| Answer Can’t, or be a reserve | No banners for that run. | open |
| Settings: Run reminders off | No banners (the chat lines follow their own settings). Ambient effects off: the banner appears and disappears without fading. | open |

### CF-65 Retail test of build 4: dialogs in front, Post on Discord, From the website
| Step | Expected | Status |
|---|---|---|
| Open `/cf`, click into the window, then open each dialog: Ask now… (list), Ask now (a dungeon), the reload prompt after an ask, the start panel (a run you organise at its start), Settings (gear), the setup wizard and the Community tab prompt | Every one opens **in front of** the CommunitiesForever window, also after clicking the window again first. Dropdowns (In range for, the answer's character) and right-click menus open in front of both. | open |
| Ask now: the dialog | "Also post on Discord" is there and ticked; its line "For friends who aren't playing; posted after your next /reload." With nobody in range online: "Nobody with the addon is online in range." | open |
| Note "test123", Ask now (ticked), Reload now, uploader running (`--retail` on Retail) within 10 minutes | `WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` has a `pending` item `kind = "ask"`, the dungeon (e.g. `ubrs`) and `note = "test123"` until the site confirms it. On the site the ask shows; on Discord it's posted with "test123" when the site's admin setting "Ask now from the game" is on. More than 10 minutes between the ask and the upload: the site drops it (expired). | open |
| Untick "Also post on Discord", Ask now | Only friends online in range get it; no reload prompt, nothing in `pending`. Nobody in range: "Nobody with CommunitiesForever is online in range of <dungeon>, and it isn't posted on Discord." | open |
| Every way to start an ask, each clicked several times, also right when the minute countdown ticks over and while a friend logs in or out (the tab redraws then): a dungeon's "Ask now"; "Ask now for this run" (on the Group line); click an open slot, then its menu's "Ask now for this run"; the empty state's "Ask now…" (a character with no run and no dungeon); `/cf ask Deadmines` | Every click opens the same Ask dialog, in front of the window: the dungeon (the run's, the one clicked, else one that fits you), "You go as …", the note filled in for a run ("For SM: Graveyard 20:30 · need a healer"), "Also post on Discord" ticked. No click is lost. There is no "Ask now…" above the run list any more. | open |
| Right after an ask, Ask now again | The button is never greyed; the dialog opens, and its Ask now says "You can ask again in 3 min." until the 3 minutes are over. The dungeon you asked for shows "Asked who's up for it · …" above its Ask now. | open |
| Friends tab with friends the website knows who haven't synced | Header "From the website · N"; each row shows their character count. Click one: "From the website" with an ⓘ (hover: "Not synced in game yet: their characters as the website last saw them. …"), then their characters. | open |

### CF-64 Retail test of v0.10.0-beta1: no planning in game, fixes
| Step | Expected | Status |
|---|---|---|
| Update with sync debug on (from an earlier version), log in | No `[sync]` lines in chat. `/cf sync debug` says "Sync debug on until /reload: …" and the lines come; after `/reload` they're gone again without typing anything. | open |
| `/cf`, Dungeons, a dungeon | No "Plan a run…" anywhere (dungeon, list, run). "Ask now" is enabled, also for a dungeon out of range and with nobody online (only greyed for 3 minutes after an ask). | open |
| "In range for" | A dropdown in the input look with a gold arrow drawn as a texture, "Sekaru (11)" and no "▯". Click it: your characters; hover: "Ranges are typical levels; …". | open |
| A run with friends' characters (synced, in the community roster, or answered on the website) | Each group row and suggested-group row shows that character's round class icon. A Discord answer without a character shows no icon and no empty ring. | open |
| A run with open slots | One "Ask now for this run" at the right of the "Group" line (not on each open slot), also at the narrowest window. It opens Ask now with "For <dungeon> <time> · need a tank" (the first open role). A click on an open slot still opens Whisper / Ask now for this run / Invite. | open |
| Ask now with nobody with the addon online in range, "Also post on Discord" ticked | Chat: "Your ask for <dungeon> is on Discord after your next /reload." The dialog said "Nobody with the addon is online in range." | open |
| After Ask now | "Post on Discord?" centred on the CommunitiesForever window: "Reload to post it on Discord" with an ⓘ (hover: the details), "Friends in game got it already.", Reload now / Later. | open |
| Reload now, let the uploader upload | The ask is on Discord within a minute; after the next `/reload` the list footer "Runs from …" shows the new time. If it stays old, check the uploader writes `Data\Runs.lua` into the Forever install's `Interface\AddOns\CommunitiesForever` (not `_retail_`). | open |

### CF-63e Doomsday goal boxes (boards CF63DoomBoard, CF63DoomToday)
| Step | Expected | Status |
|---|---|---|
| `/cf`, Doomsday, Board | Every goal cell is a drawn 15 px box centred in its column: open a dark box with a dim gold edge, done a gold edge with a gold check. No "☐", "✓" or stray "·". Compare with `docs/design/cf-63-2026-10/CF63DoomBoard.dc.html`. If the check is a plain white tick instead of Blizzard's checkmark, the atlas `common-icon-checkmark` is missing: note it. | open |
| A swapped goal (yours or a friend's) | A small blue corner top right of its box. Hover: "Run a dungeon with a friend", "Swapped for you · original: …", "Not done yet · resets Thu 19:00". A friend's done box: "<goal>", "Mira · done Thu 00:14 · resets …". | open |
| Doomsday, Today | The same box before each goal (no more green square); a swapped goal shows the blue corner and the word "swapped"; hovering the box or the title shows the same tooltip. | open |

### CF-63a Dungeons tab: dungeon names, in range on Retail, the run detail (board CF63RunDetail)
| Step | Expected | Status |
|---|---|---|
| Retail 12.1.5 (or Forever), a website run for SM: Graveyard (`smgy`); `/reload` after the upload, `/cf`, Dungeons | The run row says "SM: Graveyard" (hover: "Scarlet Monastery: Graveyard"); never "smgy". | open |
| Open the run | Three header lines: "Scarlet Monastery: Graveyard"; "level 26–36 · Tirisfal Glades"; "Tomorrow 20:30 · in 1 day · planned on the website" (or "in 3 h 10 m", "in 12 min"). Compare with `docs/design/cf-63-2026-10/CF63RunDetail.dc.html` A. | open |
| Same, alone online (no friend on) | "In range for <character> (<level>)" lists the dungeons that fit you; on Retail the Vanilla dungeons, no Retail ones. | open |
| A run for a dungeon the addon doesn't know (if the site has one) | The site's name, else "A dungeon"; never an id. | open |
| The group, window at its normal size (1080 × 720) | Five 36 px rows across the full width: role, round class icon, name, "level · friend", then a green "online" for members online and the status right-aligned ("organiser", "you", "Discord", "maybe", "3 below"). Your own row has a gold edge. "Damage · open" for an open slot, "Healer · nobody fits" when nobody in range plays it. No name runs into its status. | open |
| Below the group | A line, "Your answer" (or the organiser's Start / Invite all), a line, then one row: "Online now, fits ⓘ" with one line per member ("Lia Thornwhisper 29 · Lia", Whisper) on the left; "On the website ⓘ" (or "Edit or cancel" when you organise) with the link box on the right. Hover the ⓘs: "Online members whose current character fits 26–36." and "Copy with Ctrl+C. Edit or cancel happens on the website." Nobody: "Nobody else online fits". | open |
| Make the window as narrow as it goes | A long name is cut with "..." before it reaches "online" or the status; nothing overlaps. | open |
| Keep the window open on a run across a minute boundary | The countdown changes without clicking ("in 13 min" becomes "in 12 min"). From 15 minutes before the start Invite shows next to Whisper; at the start the line says "Starting now · 20:30" (in orange) for 30 minutes. | open |
| Answer a run (I'm in), before `/reload` | A small pocket watch icon after the run row's "N in" and after the run's time line; hover: "Saved. Reaches the website with your next upload." No text line. If only an empty ring shows, `Interface\Icons\INV_Misc_PocketWatch_01` isn't there: note it. | open |
| The bottom of the run list | "Runs from Wed 22:30 ⓘ" (when the runs file was written); hover: "Runs from the website. Type /reload after an upload for newer." | open |

### CF-62d2 Dungeons tab: in range and the empty state (board AG05InRange, D)
| Step | Expected | Status |
|---|---|---|
| `/cf`, Dungeons | "Dungeons" with "Ask now…"; "Planned" over the runs; then "In range for <character> (<level>)" with an ⓘ (hover: "Ranges are typical levels; …"); per dungeon the name, its range, "N fit · X/Y quests" and a gold "1 run" when planned. Without a run you're in, the first dungeon in range opens; with one, that run. | open |
| Pick a dungeon with a planned run | Title "<dungeon>", "level 22–30 · <zone>", and "1 run planned · Fri 20:00 ›" on the right, which opens the run. | open |
| Same dungeon | "Suggested group" as five 38 px rows (role and class icons, full names, "level · friend", "you"/"online"); "Healer · nobody in range"; "Damage · open" with "N online fit"; "Your other characters in range: …". "Online now, fits …" on the right. | open |
| With Questie | "Quests" with "N of M in your log · K done": a check for quests in your log ("Bob has it too"), "!" for ones to pick up ("level 17"), grey with "done" for completed ones. Without Questie: "Quests · needs Questie" and no list. | open |
| Go | "Ask now" (opens the Ask dialog for it; hover: what it does). No "Plan a run…" (CF-64). | open |
| A level 1–12 character, no runs | Centred: "Nothing planned yet", the reason ("… is not in a dungeon's level range yet …" / "… isn't in the community yet …"), "Ask now…" (disabled without a dungeon) and, when the uploader wrote the site's address, "Copy website link" (the link appears selected; Ctrl+C copies it). | open |

### CF-62d1 Dungeons tab: runs (board AG02Dungeons)
New APIs (guarded): the role icon atlases `UI-LFG-RoleIcon-Tank`, `-Healer`, `-DPS` through `C_Texture.GetAtlasInfo` (without them a coloured square), `ChatFrame_SendTell(name)` for Whisper (else `ChatFrameUtil.OpenChat`), `Button:SetMotionScriptsWhileDisabled` (the tooltip on a disabled Invite all).
| Step | Expected | Status |
|---|---|---|
| `/cf`, Dungeons with a few runs | The list is 290 px: "Runs" with "Ask now…" on the right; runs under "Today"/"Tonight", "Tomorrow", "This week", "Later"; each row: short name ("SM: Graveyard") and time ("20:30" or "Fri 20:00"), five role pips (filled in role colour when taken), "2 in · 1 maybe", the organiser ("you organise" in gold). At the bottom: "Runs from the website, <time>. Type /reload after an upload for newer." | open |
| `/dump C_Texture.GetAtlasInfo("UI-LFG-RoleIcon-Tank")` | A table (then the role icons are Blizzard's); `nil` means the coloured squares are used. | open |
| Open your own run before the start | Title: the dungeon's full name and "level 26–36"; under it "Tonight 20:30 · in 3 h 10 m · planned on the website · note: “…”". Five 38 px group rows with role icon, class icon, the full name (never cut at 1080 × 720), "level · friend", and the status (organiser green, answered on Discord blue, maybe orange). An open slot: dimmed role icon, "Damage · open", "N online fit" in blue (hover: who). "Reserve: …" under them. | open |
| Same run, right column | "Online now, fits 26–36" with an ⓘ (hover: "From the community roster: …") and the count; one row per online member in range who isn't in the group, with Whisper (opens the chat box with /w). "Nobody online fits right now." when none. Below: "Edit or cancel", the link box (click selects it), "Click, then Ctrl+C to copy." | open |
| A community member logs in or out | "Online now, fits" changes within a second. | open |
| Your run, 15 minutes before the start | "Starting now · 20:30" in orange; "Invite all · N online" enabled (hover: "Invite all invites everyone who is in and online."; also while disabled before). Before that, disabled "Invite all · opens 20:15" and "Reminder at 20:00". Online now shows Invite (out of combat; in combat disabled with "Not in combat"). | open |
| Someone else's run | "Your answer" with an ⓘ (hover: "Shared with online friends now; …"), I'm in / Maybe / Can't (yours highlighted), "As <character> · <role> · change" (change opens the answer dialog). The answer reaches the organiser's addon within seconds and survives /reload. "On the website" above the link. | open |

### CF-62c Friends tab (board AG03Tabs)
| Step | Expected | Status |
|---|---|---|
| `/cf`, Friends | The list has headers "Online · N", "Offline · N" and, with a site upload that knows friends who haven't synced, "From the website · N" with each friend's name and "from the website". Your own entry reads "You". No BattleTag anywhere. | open |
| Your own card | Title "You", "Online on <character> · <zone>" in green. Each character as a bordered card: class icon, name in class colour with the realm dim after it, "· Level N · <role>", "online" or "played … ago" on the right, a level bar in class colour, the zone, and the professions ("Mining 240 · …") or "no professions yet". | open |
| No friend synced yet | Under your characters a bordered box: "Friends appear here when they are online with the addon at the same time as you, or after the website sync. N friends are known from the website and fill in after your next /reload following an upload." | open |
| Click a "from the website" friend | Their name, "from the website", and their characters as cards with realm, class, level and "seen … ago". | open |

### CF-62c Footer and Activity (board AG03Tabs)
| Step | Expected | Status |
|---|---|---|
| `/cf` right after login, no friend online | Footer on Activity, Dungeons and Doomsday: "Synced with 0 friends · waiting for someone online". Friends: "Synced with 0 friends this session · N of your characters" with your own character count. | open |
| A friend with the addon comes online | Within seconds: "Synced with 1 friend · 22:41" (the time their record arrived, your clock). Records from before this login don't count. | open |
| Activity | Right of the filter chips: "Today: N friends active · N quests · N levels". Rows read "<character> · <friend>" ("you" for yourself). An ⓘ after "Today" (hover: "That's all for today. Friends' activity arrives when …"). Yesterday and older days below. | open |

### CF-62b Doomsday Today v2 (board AG03Tabs)
| Step | Expected | Status |
|---|---|---|
| `/cf`, Doomsday › Today at 1080 × 720 | Header "Today · Wed evening · N of M done" with an ⓘ after it (hover: what "⇄ swapped" means), "New goals Thu 19:00 · in 4 h 28 m" in orange on the right. | open |
| The goal rows | Per row: an 18 px box (green with a check when done), the kind in green (Daily) or red (Skirmish, Hunt, Duel), the title (struck through and grey when done), a blue "⇄ swapped" on a swapped goal (hover: "Instead of: …"), "done"/"not yet" for one-step goals or a short 140 px bar with "1/10", and "+5" at the far right in the track colour. | open |
| The Duel row | "First duel with each friend", "0/N" with the friends online today, and the points earned today ("+4" after a win and a loss, nothing at 0); hover: whom you dueled and "Win +3 · loss +1 · first duel per friend". | open |
| Under the goals | Three bordered boxes: Today (PvE green · PvP red; hover: the kill summary), This week (the same), Streak ("N days" orange, "best N"). | open |
| The right column | "Friends today" with an ⓘ (hover: "Live for friends online with the addon; others after their upload."), "PvE · PvP" on the right; one row per friend with Doomsday data and "You"; a 12 px box per goal (green PvE, red PvP when done, dark when open), "PvP Virgin" instead of the PvP boxes for a virgin, the points, a line through the name of who did all dailies, "crown" after the first. | open |

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
| First login: `/fp`, press Test: celebration sounds (V88) | Three game sounds 2 s apart, each with a chat line "sound 1: IG_QUEST_LIST_COMPLETE" (2: UI_EPICLOOT_TOAST, 3: UI_LEGENDARY_LOOT_TOAST); "(did not play)" or a missing key means send the log. V64, V88 and V89 show "the APIs are there; check it by eye" or which API is missing. | open |
| World PvP: before each kill, target or mouse over the enemy player (enemy nameplates on) | The checklist's "The Hunt" item ticks with the victim's race and class ("Ann Example: NightElf DRUID via target"). An info line "named, but not seen with race and class" means the kill message works but the victim wasn't seen first: try again with a target. No tick after several kills: send the log (`V73 honor` and `V74 unit` lines). | open |
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
| A: Ask now for a dungeon B has no character in range of with "Also post on Discord" ticked | B gets no "asks: … now?" line; after B's `/reload`, B's saved file has a `pending` item `kind = "ask"` with A's item id (as in A's file), A's guid and BattleTag. | open |
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

### CF-47 Ask now, sign up (planning in game removed in CF-64)
Compare with `docs/design/runs-2026-10/run-dialogs.html`. The answer steps need the CF-46 test file (with a run someone else organises) and ideally that friend online with this build.

| Step | Expected | Status |
|---|---|---|
| Dungeons tab, a dungeon in range, "Ask now" | A dialog "Ask now": the dungeon with its range and "now", "You go as <character> <level> · <role>", "WHISPERED NOW · ONLINE AND FIT" with the friends who get it, "Not asked: …" with why (above/below the range, offline), a note field, "Also post on Discord" with its help line, Cancel and Ask now. | open |
| Type a note, keep "Also post on Discord" ticked (CF-65: on by default), Ask now | Friends online get the ask with your note in quotes (CF-27 chat line). Then "Post on Discord?" with "Reload to post it on Discord" and an ⓘ, on the main window. Unticked: no Discord ask and no reload prompt. | open |
| Reload now (V68) | The UI reloads. Without the API: the line "Type /reload to post it now." | open |
| `/reload`, then let the uploader upload (after UP-12 and WEB-43) | `WTF\Account\<account>\SavedVariables\CommunitiesForever.lua` has a `pending` list with your ask and answer. After the site has them and the next Runs.lua lists them under `received`, the "reaches Discord" labels go. | open |
| Ask now, Later, wait 11 minutes, log out | The ask is gone from `pending` in the saved file (not posted). | open |

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
| An entry | A round class portrait, "<character> · <friend>" (CF-62: the character first in class colour, then the friend in grey, "you" for yourself), below it a gold LEVEL UP chip "22 → 24" (no animation yet), "questing in" with zone pills and "+N zones", "· N quests done", runs and profession ranks as text; the time right (V63). | open |
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
| Footer | Left "Synced with N friends this session · M of your characters" (CF-62), nothing on the right. | open |
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
| Log in (or `/reload`) while the friend is already online in Forever, and wait a minute | No "<friend> is online on ..." line; one appears only when they log in or switch later (bug hunt: Battle.net can report friends a few seconds after login). | open |

