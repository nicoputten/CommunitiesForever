# Doomsday: catalogue of PvE dailies (draft)

Draft for Nico's review, 2026-11-03. Nothing here is in the pool yet: no code, no `POOL_VERSION` bump, and
`docs/DOOMSDAY.md` is unchanged. After the OK, the next steps are stories for the trackers, the site's copy of the
pool and a pool version bump. The probe checks (V90 to V119) are in the FriendProbe launch checklist. Weeklies come
later and are not part of this draft.

Decisions this draft follows (Nico, 2026-11-03):
- At least 100 PvE dailies, **mostly new kinds of activity**, with only a few size variants.
- **General missions only:** no zone, dungeon or place names; anyone can do them anywhere, given their level and
  characters.
- **Everything drafted, gated by the probe:** a mission that needs an unverified Forever API is in the catalogue and
  joins the pool only in the release after its API is verified (`DOOMSDAY.md` "Pool version").
- New stored data is fine under rule 8: new feed and record fields are optional, nil means unknown.
- **Level 60 is ignored for now:** it takes a while before anyone reaches it. The "all characters at 60" swaps stay
  as written; whether combat needs a kill source at 60 is decided later.
- **Cooking, Fishing and First Aid get many missions of their own** (Nico's ideas: catch 20 fish, cook 15 dishes,
  make and use bandages), plus the campfire and its special buff, potions, scrolls and jumping. The probe finds out
  how the campfire and its buff work (V119).
- **Flex, boo and kills 5 levels above or below** are PvP: they go to the Skirmish pool, not the PvE dailies.

The rules of `DOOMSDAY.md` still hold: per friend, any character counts and progress adds up across characters;
"a friend" means a community character of another BattleTag (never an own alt); the draw takes 3 dailies from 3
different categories; a missing situation field never swaps; recommend, never restrict; no pronouns in texts; gold
never shown as an amount.

## Summary

**121 PvE dailies in 15 categories, plus 4 Skirmish goals** (numbers 1 to 125). The 20 existing dailies are all kept
with their ids; 4 of them move to a new category (below).

| Category | Dailies | Works now | Existing tracker | New, verified API | Needs probe |
|---|---|---|---|---|---|
| quests | 10 | 6 | | 4 | |
| levels | 9 | 5 | 1 | 2 | 1 |
| dungeons | 9 | 6 | 1 | 1 | 1 |
| crafts | 6 | 2 | | 1 | 3 |
| cooking | 9 | 1 | 1 | | 7 |
| fishing | 7 | 1 | 5 | | 1 |
| firstaid | 7 | 1 | | | 6 |
| play | 9 | 4 | 4 | | 1 |
| social | 10 | | 2 | 5 | 3 |
| exploration | 8 | | 2 | 4 | 2 |
| travel | 7 | | | 1 | 6 |
| combat | 7 | | | | 7 |
| loot | 6 | | 1 | 2 | 3 |
| economy | 7 | | 1 | | 6 |
| care | 10 | | | | 10 |
| **PvE total** | **121** | **26** | **18** | **20** | **57** |
| skirmish (PvP) | 4 | | 2 | | 2 |

**Data** (the column "Data" in the tables):
- **"works now"** (26): the addon records the facts already. 14 of them are pool version 1; the other 12 need only
  the goal (catalogue entry, progress function, golden cases) and can join the next pool version.
- **"existing tracker, waits for its launch check"** (18): CF-52, CF-53, CF-55b and CF-56 trackers that are built but
  still unverified on Forever. They join once their `VERIFY.md` item or story steps pass (named in the row).
- **"new tracker, verified API"** (20): needs new recording code, but every event and API it reads is in
  `docs/API-FINDINGS.md`. No probe needed; can join the next pool version.
- **"needs probe V…"** (57): reads an API that is not verified on Forever. Each names its `VERIFY.md` item (V90 to
  V119), which the FriendProbe launch checklist checks.

So **46 of 121 work without a probe** (works now + new tracker), **64 once the existing trackers' launch checks pass**.

### Categories
The 5 existing categories (quests, levels, dungeons, crafts, play) become 15. New: **cooking**, **fishing**,
**firstaid**, **social**, **exploration**, **travel**, **combat**, **loot**, **economy**, **care** (upkeep of a
character: repair, train, rest, eat, potions, scrolls).
- Moved: `d.groupFriend` and `d.trade` from play to social; `d.rare` from play to loot; `d.fish20` and `d.fishZones`
  to fishing; `d.cook5` to cooking; `d.bandage3` and `d.bandageUp` to firstaid. Of these, only `d.groupFriend`,
  `d.trade`, `d.rare` and `d.fish20` are existing ids, and none of them is in a released pool (no `since`), so moving them changes no draw that has happened and no
  stored data. `d.secondary` stays in crafts: it covers all three.
- With 15 categories, each still has enough goals for the "not twice running" rule. A category with many goals is
  drawn as often as a small one (one category per slot), so cooking, fishing and First Aid together come up about
  1 day in 2.
- **Early pool:** combat, travel, economy, care, cooking and firstaid are mostly "needs probe". Until their checks
  pass they hold few or no goals, so the draw sees fewer categories. 8 categories have at least 2 goals that work
  without a probe, so the 3-category draw always works.

### New trackers
Grouped by what they watch; each is a small adapter (raw values) plus a core fact in `Goals.newFacts` (all new facts
optional, nil = unknown; they stay local like CF-56's facts, only `done` travels).

| Tracker | Goals | Events and APIs | Probe |
|---|---|---|---|
| Quest details at turn-in | `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.dungeonQuest`, `d.questBurst`, `d.accept5`, `d.questTogether` | `QUEST_TURNED_IN` (questID, already used by CF-22), `QUEST_ACCEPTED`, `C_QuestLog.GetInfo` `level` and `suggestedGroup` kept in the stored quest log next to `area` and `dungeon` (V23, V31); turn-in times | none |
| Level context | `d.dingDungeon`, `d.dingFriend`, `d.lowbie` | `PLAYER_LEVEL_UP` with `GetInstanceInfo` type (V35) and the group's friends (CF-53 groups) | none |
| Skill points per profession | `d.cookSkill5`, `d.fishSkill5`, `d.aidSkill5` | the professions per character the addon stores (skill lines 185, 356, 129), as `d.skill5` counts all | none |
| XP bar | `d.xpQuarter` | `PLAYER_XP_UPDATE`, `UnitXP`, `UnitXPMax` | V91 |
| Dungeon history | `d.newDungeon` | feed `runs`; new stored per-character set of dungeon names | none |
| Raid bosses | `d.raidBoss` | `ENCOUNTER_END` in a raid (CF-23 records raids; only the dungeon part is verified) | V92 |
| Crafting details | `d.craft5`, `d.cook5`, `d.cook15`, `d.cookKinds3`, `d.bandage3`, `d.bandage10`, `d.bandageKinds2`, `d.craftGreen`, `d.feedFriend` | `LOOT_ITEM_CREATED_SELF` (CF-56's crafted tracker, V83), counted per item ID; item class and quality | V105 |
| Gathering, chests, fishing loot | `d.gather10`, `d.treasure`, `d.fishKinds3` | `LOOT_OPENED`, `GetLootSourceInfo`, `GetLootSlotLink`, item class of looted items | V106 |
| Recipes | `d.newRecipe`, `d.cookRecipe` | a new-recipe event or system message | V104 |
| Fishing context | `d.fish50`, `d.fishZones`, `d.fishFriend`, `d.fishNight` | CF-56's fishing tracker plus the zone, the group and the realm clock | (V84) |
| Item use | `d.potion`, `d.scrolls10`, `d.eatOwn`, `d.bandageUse3`, `d.bandageFriend` | `UNIT_SPELLCAST_SUCCEEDED` for the player matched to the bag item whose `C_Item.GetItemSpell` is that spell; its item class | V95, V116 |
| Cast targets | `d.scrolls10`, `d.bandageFriend` | `UNIT_SPELLCAST_SENT` (target name) | V117 |
| Jumps | `d.jump100` | a `hooksecurefunc` on `JumpOrAscendStart` | V118 |
| Campfire | `d.campfire`, `d.campfireBuff` | the campfire spell cast; the campfire buff on the player and how it shows the items fed (stacks or points) | V95, V119 |
| Presence and zones of friends | `d.sameZone`, `d.online3` | `C_Club.GetMemberInfo` `zone` and presence, `CLUB_MEMBER_PRESENCE_UPDATED`, `CLUB_MEMBER_UPDATED` (V17, V18) | none |
| Party levels | `d.carry` | `GROUP_ROSTER_UPDATE`, party GUIDs (V35), friends' character levels | none |
| Community chat | `d.chatHello` | `CHAT_MSG_COMMUNITIES_CHANNEL`, own message by sender GUID (V38) | none |
| Whispers and emotes | `d.whisper`, `d.wave`, `p.flex`, `p.boo` | whisper-inform events, a `DoEmote` hook with the target's GUID and faction | V108 |
| Screenshots | `d.groupPic` | `SCREENSHOT_SUCCEEDED` | V111 |
| Zones visited | `d.roam4`, `d.newZone`, `d.crossSea`, `d.nostalgia`, `d.daredevil` | `ZONE_CHANGED_NEW_AREA`, `GetRealZoneText`, `GetInstanceInfo` continent (V35); zone level ranges from Group Finder zone activities (V46); new stored per-character zone set | none |
| Places within zones | `d.places10` | `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `GetSubZoneText` | V115 |
| Movement state | `d.swim`, `d.ride` | `IsSwimming`, `IsMounted`, polled every few seconds | V98 |
| Flights | `d.flight`, `d.newFlight` | `UnitOnTaxi`, `PLAYER_CONTROL_LOST`, the new-flight-path message | V94 |
| Own spell casts | `d.hearth`, `d.bandageUp` | `UNIT_SPELLCAST_SUCCEEDED` for the player with a readable spell ID | V95 |
| Home inn | `d.bind` | `PLAYER_BINDING_CHANGED`, `GetBindLocation` | V96 |
| Summons | `d.summoned` | `CONFIRM_SUMMON`, `C_SummonInfo.GetSummonConfirmSummoner` | V114 |
| Kills from XP messages | `d.kills30`, `d.elite`, `d.rareMob`, `d.bigFoe`, `d.streak20`, `d.duoHunt` | `CHAT_MSG_COMBAT_XP_GAIN` (the combat log is blocked); the victim's classification and level from the target, mouseover or nameplate seen before the kill (as the Hunt does for players) | V90, V93 |
| Player kills by level | `p.punchUp5`, `p.punchDown5` | CF-55b's `pvpKills` with the victim's level | (V73, V74) |
| Weapon skills | `d.weaponSkill` | `CHAT_MSG_SKILL` with `SKILL_RANK_UP` (no skill-line API on Forever) | V107 |
| Loot quality and coins | `d.green5`, `d.reward`, `d.coins10` | `CHAT_MSG_LOOT` (CF-53's parser, V83) counting uncommon items and quest rewards; `CHAT_MSG_MONEY` | V109 (coins) |
| Gear worn | `d.equipNew` | `PLAYER_EQUIPMENT_CHANGED`, `GetInventoryItemID` | V113 |
| Merchant | `d.vendorSale`, `d.vendorBuy`, `d.repair`, `d.restock` | `MERCHANT_SHOW` and `MERCHANT_CLOSED` around CF-53's `PLAYER_MONEY` tracker; repair and buy hooks | V99 |
| Auction house | `d.auctionPost`, `d.auctionBuy` | auction events or system messages | V101 |
| Mail | `d.mailFriend`, `d.mailbox` | `SendMail` hook (recipient), `MAIL_SEND_SUCCESS`, inbox take hooks | V100 |
| Bank | `d.bank` | `BANKFRAME_OPENED` | V102 |
| Trainer | `d.trainer` | `TRAINER_SHOW`, the learned-spell message | V103 |
| Resting | `d.inn` | `IsResting` at `PLAYER_LOGOUT` | V97 |
| Auras | `d.wellFed`, `d.buffFriend` | `UNIT_AURA`, `C_UnitAuras.GetAuraDataByIndex` (spell ID, source) out of combat | V110 |
| Bags | `d.tidyBags` | `BAG_UPDATE`, `C_Container.GetContainerItemInfo` quality | V112 |

### New swap situation fields
All optional, a missing field never swaps: `below20` (characters below 20), `hasCooking`, `hasFirstAid`,
`hasGathering` (Herbalism, Mining or Skinning), `riding` (a character with riding, CF-53), `friends` (other friends in
the community), `canBuff` (a character of a class with a buff it can cast on others). The existing `below60`,
`highest`, `hasProfession`, `hasFishing`, `hasCraftingProfession` and `dungeonInRange` cover the rest.

### Probe checks
In `VERIFY.md` (V90 to V119) and in the FriendProbe launch checklist, which ticks most of them by itself while
playing. "Retail" means a Retail 12.1.5 dry run can answer it (Nico's rule: checked on Retail counts as done),
"Forever" that only Forever can.

| Check | Question | Where |
|---|---|---|
| V90 | Does `CHAT_MSG_COMBAT_XP_GAIN` arrive with readable text matching `COMBATLOG_XPGAIN_FIRSTPERSON` (and its group variants) once per kill, also in a group? | Retail (low character), Forever |
| V91 | Do `PLAYER_XP_UPDATE`, `UnitXP("player")` and `UnitXPMax("player")` work? | Retail |
| V92 | Does `ENCOUNTER_END` (or `BOSS_KILL`) fire with `success` for raid bosses? (V35's raid part) | Forever |
| V93 | Do `UnitClassification`, `UnitLevel` and `UnitName` read for hostile creatures by target, mouseover and nameplate? | Retail |
| V94 | Do `UnitOnTaxi` and `PLAYER_CONTROL_LOST` tell a flight, and does `ERR_NEWTAXIPATH` arrive (`UI_INFO_MESSAGE` or `CHAT_MSG_SYSTEM`) when a flight path is learned? | Retail, Forever |
| V95 | Does `UNIT_SPELLCAST_SUCCEEDED` for `"player"` give a readable spell ID (Hearthstone 8690, a bandage, the campfire)? | Retail |
| V96 | Do `PLAYER_BINDING_CHANGED` and `GetBindLocation()` work when setting the hearthstone? | Retail |
| V97 | Does `IsResting()` read true in an inn and at `PLAYER_LOGOUT`? | Retail |
| V98 | Do `IsMounted()` and `IsSwimming()` read as expected? | Retail |
| V99 | Merchant: `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `CanMerchantRepair`, `GetRepairAllCost`, hooks on `RepairAllItems` and `BuyMerchantItem` with `GetMerchantItemLink`? | Retail |
| V100 | Mail: `MAIL_SHOW`, a `SendMail` hook with the recipient (a full name with a space), `MAIL_SEND_SUCCESS`, `GetInboxHeaderInfo` and hooks on taking items or money? | Retail, Forever (recipient name) |
| V101 | Which auction house UI does Forever have, and which events or system messages tell a posted auction and a bought one? | Forever |
| V102 | Does `BANKFRAME_OPENED` fire? | Retail |
| V103 | `TRAINER_SHOW`, and which event or message tells a spell learned at a trainer? | Retail |
| V104 | Which event or message tells a recipe learned (`NEW_RECIPE_LEARNED`, `ERR_LEARN_RECIPE_S`)? | Forever |
| V105 | `C_Item.GetItemInfoInstant` class and subclass for a crafted food and bandage, and `C_Item.GetItemQualityByID` for a just-created item? | Forever |
| V106 | `GetLootSourceInfo(slot)` on `LOOT_OPENED`: is the source GUID readable (GameObject or Creature)? `GetLootSlotLink` item IDs (also of fishing loot)? Item class 7 subclasses for herbs, ore and leather? | Forever |
| V107 | Does `CHAT_MSG_SKILL` arrive with `SKILL_RANK_UP` text on a weapon skill-up? | Forever (Retail has no weapon skills) |
| V108 | Are whisper-inform targets readable (`CHAT_MSG_WHISPER_INFORM`, `CHAT_MSG_BN_WHISPER_INFORM`), and does a `DoEmote` hook see the token, `UnitGUID("target")` and the target's faction? | Retail, Forever (an enemy player for flex and boo) |
| V109 | Does `CHAT_MSG_MONEY` arrive with `YOU_LOOT_MONEY` / `LOOT_MONEY_SPLIT` text? | Retail |
| V110 | Are `C_UnitAuras.GetAuraDataByIndex` `spellId` and `sourceUnit` readable out of combat, for the player and party members? | Retail |
| V111 | Does `SCREENSHOT_SUCCEEDED` fire? | Retail |
| V112 | Does `C_Container.GetContainerItemInfo` give `quality` for bag items? | Retail |
| V113 | Do `PLAYER_EQUIPMENT_CHANGED` (slot) and `GetInventoryItemID` give the equipped item? | Retail |
| V114 | Do `CONFIRM_SUMMON` and `C_SummonInfo.GetSummonConfirmSummoner()` name the summoner? | Forever (needs a warlock friend) |
| V115 | Do `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS` and `GetSubZoneText()` work? | Retail |
| V116 | Does a used potion, scroll, food or bandage show as `UNIT_SPELLCAST_SUCCEEDED` with a spell ID that `C_Item.GetItemSpell` gives for that bag item? | Retail |
| V117 | Does `UNIT_SPELLCAST_SENT` give the cast's target name (a scroll or bandage on yourself or a friend)? | Retail |
| V118 | Can an addon `hooksecurefunc("JumpOrAscendStart", ...)` without taint or a blocked action, and does it run once per jump? | Retail |
| V119 | The campfire: its spell ID when lit, and its special buff (name, spell ID, stacks or points) as items are added. | Forever |

### Hard to track honestly, and open questions
1. **Kill details from the target cache** (`d.elite`, `d.rareMob`, `d.bigFoe`): like the Hunt, the victim's
   classification and level are only known when it was targeted or moused over before the kill. AoE and pulls seen
   only in passing are missed. `d.rareMob` depends on rare spawns: some days nobody meets one.
2. **Friends' schedules** (`d.groupFriend`, `d.questTogether`, `d.dingFriend`, `d.sameZone`, `d.online3`,
   `d.carry`, `d.duoHunt`, `d.mailFriend`, `d.wave`, `d.groupPic`, `d.buffFriend`, `d.summoned`, `d.fishFriend`,
   `d.bandageFriend`, `d.feedFriend`): only doable when a friend plays at the same time. As with `d.groupFriend`
   today there is no fallback, because it can't be known in advance. Keep them, or give them a fallback when no
   friend was online the day before?
3. **Very easy goals:** `d.chatHello`, `d.wave`, `d.whisper`, `d.hearth`, `d.bank`, `d.mailbox`, `d.potion` take
   seconds. They score the same 5 points as a dungeon. Keep them (variety, a nudge to be social), or cut some?
4. **Done at logout:** `d.inn` is done at the logout, which also stamps the crown's time. Fine, or drop it?
5. **History starts at install:** `d.newZone` and `d.newDungeon` need a per-character set of zones and dungeons. A
   new character has an empty set anyway; for an existing one the set can be seeded from the stored feed and quest
   log, but the first days will still count some old places as new.
6. **Zone level ranges** (`d.nostalgia`, `d.daredevil`): from Group Finder's "Quests & Zones" activities (V46),
   matched to the zone name the feed stores. Forever's new zones must be in that list; zones without a match never
   count.
7. **Treasure chests** (`d.treasure`): a chest and a herb or ore node are both game objects. Telling them apart by
   what is looted (no herb, ore or fish) is a guess; V106 decides.
8. **`d.profit` is easy** with any vendor sale. It never shows an amount.
9. **Crafting checks** for cooking and bandages use the created item's class (V105), not the profession window, so
   a food made by another source (a conjured item) could count. Mage-conjured food is "created" too: exclude
   conjured items by item class if V105 shows they differ.
10. **Auction house** (V101): Forever may have the Mainline auction house or a Classic-style one; the tracker waits
    for the answer.
11. **The campfire** (`d.campfire`, `d.campfireBuff`): the done-when texts are placeholders until V119 shows the
    spell and the buff. If the buff doesn't show how many items were added, `d.campfireBuff` becomes "sit at a
    campfire with its special buff".
12. **`d.jump100`** depends on hooking `JumpOrAscendStart` (V118). If that taints or is blocked, it is dropped.
13. **`p.punchDown5`** rewards killing much lower players. It scores no kill points (`diff <= -4` is 0), only the
    Skirmish goal's 5. Keep it as Nico asked, or make it 3+ lower?
14. Ideas left out, ready if more are wanted: earn reputation with 2 factions (`CHAT_MSG_COMBAT_FACTION_CHANGE`),
    be resurrected by a friend (`RESURRECT_REQUEST`), open a lockbox, a full party of friends in a dungeon (a
    weekly), visit a capital city (would need a list of city names), drink an elixir.

## The catalogue

Columns: **#** (the mission's number for review, across the whole list; numbers stay stable, a mission dropped in
review keeps its number as a gap, and new missions get the next numbers) · **Id** (existing ids are marked ★) ·
**Title** (player copy) · **Label** (at most 10 characters, `Doomsday.SHORT_LABELS`) · **Category** · **Done when**
(exactly) · **Data** ("works now", "existing tracker, waits for its launch check", "new tracker, verified API" or
"needs probe V…", as in the summary) · **Can't do when → fallback**.

The same list is kept as JSON for the review page (`{ n, id, existing, slot, category, title, short, doneWhen,
status, data, cantDo }`), outside the repo.

"A character" is any of the friend's characters; counts add up across characters unless the text says "one
character". "That day" is the Doomsday day.

### quests (10)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 1 | ★ `d.quests10` | Finish 10 quests | 10 quests | quests | 10 quests handed in that day | works now (pool 1) |  |
| 2 | ★ `d.quests20` | Finish 20 quests | 20 quests | quests | 20 quests handed in that day | works now (pool 1) |  |
| 3 | ★ `d.zone5` | Finish 5 quests in one zone | 5 in zone | quests | 5 quests handed in in one zone | works now (pool 1) |  |
| 4 | ★ `d.zones3` | Hand in quests in 3 zones | 3 zones | quests | quests handed in in 3 zones | works now (pool 1) |  |
| 5 | ★ `d.shared3` | Share 3 quests with a friend | 3 shared | quests | at some moment, the own quest log and one friend's synced log share 3 quests | works now (pool 1) | no friend's quest log known → `d.quests10` |
| 6 | `d.questUp` | Finish a quest above the character's level | Hard quest | quests | a quest handed in whose level (from the quest log) is higher than the character's level at the hand-in | new tracker, verified API: quest level kept in the stored log | all characters at 60 → `d.quests10` |
| 7 | `d.groupQuest` | Finish a group quest | Group Q | quests | a quest handed in that the quest log marked as a group quest (`suggestedGroup` > 0) | new tracker, verified API: `suggestedGroup` kept in the stored log |  |
| 8 | `d.classQuest` | Finish a class quest | Class Q | quests | a quest handed in whose quest log header is the character's class name | works now: stored log `area` |  |
| 9 | `d.questBurst` | Hand in 3 quests within 10 minutes | Quick 3 | quests | 3 quests handed in by one character within 10 minutes | new tracker, verified API: turn-in times |  |
| 10 | `d.accept5` | Take on 5 new quests | Take 5 | quests | 5 different quests accepted that day (by quest ID; abandoning and taking one again counts once) | new tracker, verified API: `QUEST_ACCEPTED` |  |

### levels (9)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 11 | ★ `d.level` | Gain a level | Level | levels | a character gains a level | works now (pool 1) | all characters at 60 → `d.quests20` |
| 12 | ★ `d.altLevel` | Gain a level on an alt | Alt level | levels | a level on any character but the highest | works now (pool 1) | only one character below 60 → `d.quests10` |
| 13 | ★ `d.ilvl` | Raise an item level | Item level | levels | a character's item level is higher than at its first login that day | works now (pool 1) | item level unreadable → `d.quests10` |
| 14 | ★ `d.cleanLevel` | Gain a level without dying | Clean lvl | levels | a level on a character with no death between that level and the previous one | existing tracker, waits for its launch check: 52 (CF-52 deaths) | all characters at 60 → `d.quests20` |
| 15 | `d.levels2` | Gain 2 levels | 2 levels | levels | 2 levels over all characters | works now | all characters at 60 → `d.quests20` |
| 16 | `d.xpQuarter` | Fill a quarter of the XP bar | XP 25% | levels | XP gained that day adds up to a quarter of the bar: the sum over gains of (gain ÷ `UnitXPMax` at the gain) ≥ 0.25 | needs probe V91 | all characters at 60 → `d.quests20` |
| 17 | `d.dingDungeon` | Gain a level inside a dungeon | Deep ding | levels | a level gained while the instance type is `party` | new tracker, verified API: `GetInstanceInfo` at the level-up | all characters at 60 or no character in range of a dungeon → `d.level` |
| 18 | `d.dingFriend` | Gain a level in a group with a friend | Duo ding | levels | a level gained while grouped with a friend's community character | new tracker, verified API: group at the level-up (CF-53 groups) | all characters at 60 → `d.groupFriend` |
| 19 | `d.lowbie` | Gain a level on a character below 20 | Lowbie | levels | a level on a character that was below 20 before it | works now | no character below 20 → `d.altLevel` |

### dungeons (9)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 20 | ★ `d.dungeon` | Run a dungeon | Dungeon | dungeons | a finished party run (feed `runs`) | works now (pool 1) | no character in range of a dungeon → `d.quests10` |
| 21 | ★ `d.dungeonFriend` | Run a dungeon with a friend | Group run | dungeons | a party run with at least one friend's community character (`with`) | works now (pool 1) | as `d.dungeon` |
| 22 | ★ `d.bosses3` | Defeat 3 dungeon bosses | 3 bosses | dungeons | 3 bosses across that day's party runs | works now (pool 1) | as `d.dungeon` |
| 23 | `d.dungeonQuest` | Hand in a dungeon quest | Dungeon Q | dungeons | a quest handed in that the stored quest log marks as a dungeon quest (`dungeon`, V31) | works now: stored log `dungeon` | as `d.dungeon` |
| 24 | `d.cleanRun` | Run a dungeon without dying | Clean run | dungeons | a party run with at least 1 boss and no death of that character between its start and its last boss | existing tracker, waits for its launch check: 52 (deaths) | as `d.dungeon` |
| 25 | `d.speedRun` | Defeat 3 bosses of one dungeon within 45 minutes | Speed run | dungeons | a party run with 3 or more bosses whose first entry to last boss took 45 minutes or less | works now: run `startedAt`, `lastAt` | as `d.dungeon` |
| 26 | `d.newDungeon` | Run a dungeon new to the character | Fresh run | dungeons | a party run with at least 1 boss in a dungeon that character has no earlier run of | new tracker, verified API: per-character dungeon set (new stored data) | as `d.dungeon` |
| 27 | `d.raidBoss` | Defeat a raid boss | Raid boss | dungeons | a boss killed in a raid run (feed `runs`, instance `raid`) | needs probe V92 | no character at 60 → `d.bosses3` |
| 28 | `d.dungeons2` | Run 2 dungeons | 2 dungeons | dungeons | 2 finished party runs | works now | as `d.dungeon` |

### crafts (6)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 29 | ★ `d.skill5` | Earn 5 profession skill points | Skills | crafts | 5 points over all professions since the first login that day | works now (pool 1) | no profession on any character → `d.quests10` |
| 30 | ★ `d.secondary` | Raise Cooking, First Aid or Fishing | Secondary | crafts | 1 point in one of them, or learning one | works now (pool 1) |  |
| 32 | `d.craft5` | Craft 5 items | Craft 5 | crafts | 5 items created (`LOOT_ITEM_CREATED_SELF`, a stack counts its count) | new tracker, verified API: CF-56's crafted tracker, counted (V83) | no profession at all → `d.secondary` |
| 35 | `d.gather10` | Gather 10 herbs, ore or leather | Gather 10 | crafts | 10 items of the herb, metal and stone or leather classes looted from a gathering node or a skinned body | needs probe V106 | no character with Herbalism, Mining or Skinning → `d.skill5` |
| 36 | `d.newRecipe` | Learn a new recipe | Recipe | crafts | a recipe, pattern, plan, schematic or formula learned | needs probe V104 | no profession at all → `d.secondary` |
| 37 | `d.craftGreen` | Craft something uncommon or better | Fine craft | crafts | an item of uncommon (green) or better quality created | needs probe V105 | no crafting profession → `d.craft5` |

### cooking (9)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 33 | `d.cook5` | Cook 5 meals | Cook 5 | cooking | 5 food or drink items created (item class consumable, food and drink) | needs probe V105 | no character with Cooking → `d.secondary` |
| 101 | `d.cook15` | Cook 15 dishes | Cook 15 | cooking | 15 food or drink items created (item class consumable, food and drink) | needs probe V105 | no character with Cooking → `d.secondary` |
| 102 | `d.cookSkill5` | Raise Cooking by 5 points | Cooking +5 | cooking | 5 Cooking skill points over all characters (skill line 185) | works now: professions per character | no character with Cooking → `d.secondary` |
| 103 | `d.cookKinds3` | Cook 3 different dishes | 3 dishes | cooking | food or drink items of 3 different item IDs created | needs probe V105 | no character with Cooking → `d.secondary` |
| 104 | `d.campfire` | Light a campfire | Campfire | cooking | the campfire spell cast (Basic Campfire; its ID as the probe finds it) | needs probe V95, V119 | no character with Cooking → `d.secondary` |
| 105 | `d.campfireBuff` | Sit at a campfire fed with 3 or more items | Cozy fire | cooking | the campfire's special buff on a character, with 3 or more items in the fire (the buff and how it shows the items: as the probe finds it) | needs probe V119 |  |
| 106 | `d.eatOwn` | Eat a dish cooked that day | Home meal | cooking | a food item eaten whose item ID one of the own characters created that day | needs probe V105, V116 | no character with Cooking → `d.secondary` |
| 107 | `d.cookRecipe` | Learn a cooking recipe | New dish | cooking | a recipe learned whose spell creates a food or drink item | needs probe V104 | no character with Cooking → `d.secondary` |
| 108 | `d.feedFriend` | Give a friend a dish cooked by an own character | Feed pal | cooking | a completed trade giving a friend's community character a food item one of the own characters created | existing tracker, waits for its launch check: V85, plus V105 | no character with Cooking → `d.trade` |

### fishing (7)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 31 | ★ `d.fish20` | Catch 20 fish | 20 fish | fishing | 20 items from fishing loot | existing tracker, waits for its launch check: 56 (V84) | no character with Fishing → `d.secondary` |
| 38 | `d.fishZones` | Fish in 2 zones | Fish spots | fishing | fishing loot in 2 different zones | existing tracker, waits for its launch check: 56 (V84) plus the zone | no character with Fishing → `d.secondary` |
| 109 | `d.fish50` | Catch 50 fish | 50 fish | fishing | 50 items from fishing loot | existing tracker, waits for its launch check: V84 | no character with Fishing → `d.secondary` |
| 110 | `d.fishSkill5` | Raise Fishing by 5 points | Fishing +5 | fishing | 5 Fishing skill points over all characters (skill line 356) | works now: professions per character | no character with Fishing → `d.secondary` |
| 111 | `d.fishKinds3` | Catch 3 kinds of fish | Fish kinds | fishing | fishing loot of 3 different item IDs | needs probe V106 (item IDs of fishing loot) | no character with Fishing → `d.secondary` |
| 112 | `d.fishFriend` | Fish in a group with a friend | Fish buddy | fishing | fishing loot while grouped with a friend's community character in the same zone | existing tracker, waits for its launch check: V84, CF-53 groups | no character with Fishing → `d.groupFriend` |
| 113 | `d.fishNight` | Fish at night | Night fish | fishing | fishing loot between 21:00 and 05:00 realm time (`GetGameTime`, the game's own night) | existing tracker, waits for its launch check: V84 | no character with Fishing → `d.secondary` |

### firstaid (7)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 34 | `d.bandage3` | Make 3 bandages | Bandages | firstaid | 3 bandages created (item class consumable, bandage) | needs probe V105 | no character with First Aid → `d.secondary` |
| 100 | `d.bandageUp` | Use a bandage | Bandage up | firstaid | a First Aid bandage cast finished | needs probe V95 | no character with First Aid → `d.secondary` |
| 114 | `d.bandage10` | Make 10 bandages | 10 bandage | firstaid | 10 bandages created (item class consumable, bandage) | needs probe V105 | no character with First Aid → `d.secondary` |
| 115 | `d.bandageUse3` | Use 3 bandages | Bandage x3 | firstaid | 3 First Aid bandage casts finished | needs probe V95, V116 | no character with First Aid → `d.secondary` |
| 116 | `d.bandageFriend` | Bandage a friend | Medic | firstaid | a bandage cast finished whose target is a friend's community character | needs probe V116, V117 | no character with First Aid → `d.groupFriend` |
| 117 | `d.aidSkill5` | Raise First Aid by 5 points | Aid +5 | firstaid | 5 First Aid skill points over all characters (skill line 129) | works now: professions per character | no character with First Aid → `d.secondary` |
| 118 | `d.bandageKinds2` | Make 2 kinds of bandages | 2 bandages | firstaid | bandages of 2 different item IDs created | needs probe V105 | no character with First Aid → `d.secondary` |

### play (9)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 39 | ★ `d.chars2` | Play 2 characters | 2 chars | play | 2 characters logged in that day | works now (pool 1) | only one character → `d.quests10` |
| 40 | `d.chars3` | Play 3 characters | Play 3 | play | 3 characters logged in that day | works now | fewer than 3 characters → `d.chars2` |
| 41 | `d.switchUp` | Play a character not played the day before | Switch up | play | a character logged in that day that wasn't logged in the previous Doomsday day | works now: facts per day | only one character → `d.quests10` |
| 42 | `d.dustOff` | Play a character after a week away | Dust off | play | a character logged in whose last login was 7 or more days earlier (`lastPlayed`) | works now | no character unplayed for 7 days → `d.chars2` |
| 43 | ★ `d.earlyBird` | Early bird: play before 09:00 | Early bird | play | logged in before 09:00 local time | existing tracker, waits for its launch check: 53 (CF-53 sessions) |  |
| 44 | `d.nightOwl` | Night owl: play after 23:00 | Night owl | play | logged in at some moment between 23:00 and 03:00 local time | existing tracker, waits for its launch check: 53 (sessions) |  |
| 45 | `d.session1h` | Play a 1-hour session | 1h session | play | one session lasting 60 minutes | existing tracker, waits for its launch check: 53 (sessions) |  |
| 46 | `d.deathless` | Play an hour without dying | No deaths | play | 60 minutes of session time on one character with no death in between | existing tracker, waits for its launch check: 52 + 53 |  |
| 121 | `d.jump100` | Jump 100 times | 100 jumps | play | 100 jumps (a hook on the jump key) over all characters | needs probe V118 |  |

### social (10)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 47 | ★ `d.groupFriend` | Group up with a friend | Group up | social | in a group with a friend's community character | existing tracker, waits for its launch check: 53 (CF-53 groups) |  |
| 48 | ★ `d.trade` | Trade with a friend | Trade | social | a completed trade with a friend's community character | existing tracker, waits for its launch check: 56 (V85) |  |
| 49 | `d.questTogether` | Hand in a quest in a group with a friend | Duo quest | social | a quest handed in while grouped with a friend's community character | new tracker, verified API: group at the hand-in |  |
| 50 | `d.chatHello` | Say something in the community chat | Chat | social | an own message in the selected community's channel (by the sender's GUID) | new tracker, verified API: V38 |  |
| 51 | `d.sameZone` | Be in the same zone as a friend | Neighbours | social | a character in the same zone as a friend's online community character at the same moment | new tracker, verified API: club member `zone` (V18) | no other friend in the community → `d.chars2` |
| 52 | `d.online3` | Be online with 3 friends at once | Full house | social | 3 other friends online in Forever at the same moment while a character plays | new tracker, verified API: presence (V18, V19) | fewer than 3 other friends in the community → `d.groupFriend` |
| 53 | `d.carry` | Group with a friend 5+ levels lower | Carry | social | grouped with a friend's community character 5 or more levels below the own character | new tracker, verified API: party levels |  |
| 54 | `d.whisper` | Whisper a friend | Whisper | social | a whisper sent to a friend's community character or Battle.net account | needs probe V108 |  |
| 55 | `d.wave` | Wave at a friend | Wave | social | the `/wave` emote with a friend's community character targeted | needs probe V108 |  |
| 56 | `d.groupPic` | Take a screenshot in a group with a friend | Group pic | social | a screenshot taken while grouped with a friend's community character | needs probe V111 |  |

### exploration (8)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 57 | `d.discover1` | Discover a new place | Discover | exploration | one of the game's "Discovered" messages | existing tracker, waits for its launch check: 56 (V86, answered on Retail) |  |
| 58 | `d.discover3` | Discover 3 new places | Discover 3 | exploration | 3 "Discovered" messages | existing tracker, waits for its launch check: 56 (V86) |  |
| 59 | `d.roam4` | Visit 4 zones | Roam 4 | exploration | 4 different zones entered (on any characters) | new tracker, verified API: `ZONE_CHANGED_NEW_AREA` |  |
| 60 | `d.newZone` | Set foot in a zone new to the character | New zone | exploration | a zone entered that the character has never been in (per-character zone set, seeded from its feed) | new tracker, verified API: new stored data |  |
| 61 | `d.places10` | Visit 10 places within zones | 10 places | exploration | 10 different subzones entered | needs probe V115 |  |
| 62 | `d.swim` | Swim for 2 minutes | Swim | exploration | 2 minutes swimming in total, on one character | needs probe V98 |  |
| 63 | `d.nostalgia` | Visit a zone far below the character's level | Nostalgia | exploration | a zone entered whose highest suggested level is 20 or more below the character's | new tracker, verified API: zone levels (V46) | highest character below 30 → `d.roam4` |
| 64 | `d.daredevil` | Visit a zone above the character's level | Daredevil | exploration | a zone entered whose lowest suggested level is 5 or more above the character's | new tracker, verified API: zone levels (V46) | all characters at 60 → `d.roam4` |

### travel (7)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 65 | `d.flight` | Take a flight | Fly | travel | a flight on a flight master's route | needs probe V94 |  |
| 66 | `d.newFlight` | Learn a new flight path | New flight | travel | a new flight path learned | needs probe V94 |  |
| 67 | `d.hearth` | Use the hearthstone | Hearth | travel | the Hearthstone cast finished | needs probe V95 |  |
| 68 | `d.bind` | Make a new inn home | New home | travel | the hearthstone set to a place other than the one it was set to | needs probe V96 |  |
| 69 | `d.ride` | Ride a mount for 15 minutes | Ride | travel | 15 minutes mounted in total, on one character | needs probe V98 | no character with riding (CF-53) → `d.roam4` |
| 70 | `d.crossSea` | Cross the sea | Cross sea | travel | a character changes continent (`GetInstanceInfo` instance ID 0 and 1 outside instances) | new tracker, verified API: V35 |  |
| 71 | `d.summoned` | Get summoned by a friend | Summoned | travel | a summon accepted whose summoner is a friend's community character | needs probe V114 |  |

### combat (7)

Kills come from the XP message, so they count only kills that give XP (no grey enemies, no level 60).

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 72 | `d.kills30` | Defeat 30 enemies | 30 foes | combat | 30 kill XP messages | needs probe V90 | all characters at 60 → `d.bosses3` |
| 73 | `d.elite` | Defeat an elite | Elite | combat | a kill XP message naming a creature last seen as elite or rare elite | needs probe V90, V93 | all characters at 60 → `d.bosses3` |
| 74 | `d.rareMob` | Defeat a rare enemy | Rare hunt | combat | a kill XP message naming a creature last seen as rare or rare elite | needs probe V90, V93 | all characters at 60 → `d.bosses3` |
| 75 | `d.bigFoe` | Defeat an enemy 3+ levels higher | Big foe | combat | a kill XP message naming a creature last seen 3 or more levels above the character, or as a skull | needs probe V90, V93 | all characters at 60 → `d.bosses3` |
| 76 | `d.streak20` | Defeat 20 enemies without dying | Streak 20 | combat | 20 kill XP messages on one character with no death in between | needs probe V90 (+ 52) | all characters at 60 → `d.bosses3` |
| 77 | `d.weaponSkill` | Raise a weapon skill 5 times | Weapon +5 | combat | 5 weapon or defense skill-up messages | needs probe V107 |  |
| 78 | `d.duoHunt` | Defeat 15 enemies in a group with a friend | Duo hunt | combat | 15 kill XP messages while grouped with a friend's community character | needs probe V90 | all characters at 60 → `d.dungeonFriend` |

### loot (6)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 79 | ★ `d.rare` | Loot a rare item | Rare loot | loot | a rare (blue) or better item looted | existing tracker, waits for its launch check: 53 (V83) |  |
| 80 | `d.green5` | Loot 5 uncommon items | 5 greens | loot | 5 uncommon (green) or better items looted or received | new tracker, verified API: CF-53's loot parser, counted (V83) |  |
| 81 | `d.reward` | Earn an uncommon quest reward | Reward | loot | a quest reward of uncommon (green) or better quality | new tracker, verified API: `LOOT_ITEM_PUSHED_SELF` (V83) |  |
| 82 | `d.coins10` | Loot coins from 10 enemies | 10 purses | loot | 10 money loot messages | needs probe V109 |  |
| 83 | `d.equipNew` | Wear a new find | New gear | loot | an item equipped that the character looted or received that day | needs probe V113 |  |
| 84 | `d.treasure` | Open a treasure chest | Treasure | loot | loot from a game object that isn't a herb, ore or fishing node | needs probe V106 |  |

### economy (7)

Gold is never shown as an amount; the goals count actions.

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 85 | `d.vendorSale` | Sell to a merchant | Sell | economy | money gained while a merchant window is open | needs probe V99 |  |
| 86 | `d.vendorBuy` | Buy from a merchant | Shopping | economy | an item bought from a merchant (not a repair) | needs probe V99 |  |
| 87 | `d.auctionPost` | Put an item up for auction | Auction | economy | an auction posted | needs probe V101 |  |
| 88 | `d.auctionBuy` | Buy at the auction house | Bargain | economy | an auction bought or won | needs probe V101 |  |
| 89 | `d.mailFriend` | Send mail to a friend | Mail pal | economy | mail sent to a friend's community character | needs probe V100 |  |
| 90 | `d.mailbox` | Empty the mailbox | Mailbox | economy | an item or money taken from the mailbox | needs probe V100 |  |
| 91 | `d.profit` | End a session in profit | In profit | economy | a session that ends with more money than it started with | existing tracker, waits for its launch check: 53 (gold, sessions) |  |

### care (10)

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 92 | `d.repair` | Repair gear | Repair | care | a repair paid at a merchant | needs probe V99 |  |
| 93 | `d.trainer` | Learn a spell at a trainer | Train | care | a spell or rank learned from a class trainer | needs probe V103 | all characters at 60 → `d.repair` |
| 94 | `d.inn` | Log out rested | Tuck in | care | a logout in a rested area (inn or city) | needs probe V97 |  |
| 95 | `d.wellFed` | Get Well Fed | Well fed | care | the "Well Fed" aura on a character | needs probe V110 |  |
| 96 | `d.buffFriend` | Buff a friend | Buff pal | care | an aura cast by the own character on a friend's community character | needs probe V110 | no character that can buff others → `d.groupFriend` |
| 97 | `d.restock` | Restock food or drink | Restock | care | food or drink bought from a merchant | needs probe V99, V105 |  |
| 98 | `d.bank` | Visit the bank | Bank | care | the bank window opened | needs probe V102 |  |
| 99 | `d.tidyBags` | Clear the junk from the bags | Tidy bags | care | a character that had poor (grey) items in its bags has none left | needs probe V112 |  |
| 119 | `d.potion` | Drink a potion | Potion | care | a potion used (item class consumable, potion) | needs probe V116 |  |
| 120 | `d.scrolls10` | Read 10 scrolls on the own character | 10 scrolls | care | 10 scrolls used (item class consumable, scroll) with the own character as the target | needs probe V116, V117 |  |

### skirmish (4)

PvP: these join the Skirmish pool (the daily PvP slot, `DOOMSDAY.md`), not the PvE dailies.

| # | Id | Title | Label | Category | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|---|---|
| 122 | `p.flex` | Flex at a player of the other faction | Flex | skirmish | the `/flex` emote with an enemy-faction player targeted | needs probe V108 (emote and target), V74 |  |
| 123 | `p.boo` | Boo a player of the other faction | Boo | skirmish | the `/boo` emote with an enemy-faction player targeted | needs probe V108 (emote and target), V74 |  |
| 124 | `p.punchUp5` | Kill an enemy player 5+ levels higher | Punch up 5 | skirmish | a counted kill with `diff >= 5` (a skull counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with levels) |  |
| 125 | `p.punchDown5` | Kill an enemy player 5+ levels lower | Punch down | skirmish | a counted kill with `diff <= -5` (it scores 0 kill points; only the goal counts) | existing tracker, waits for its launch check: V73, V74 (CF-55b kills with levels) |  |
