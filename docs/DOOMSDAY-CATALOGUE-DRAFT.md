# Doomsday: catalogue of PvE dailies (draft)

Draft for Nico's review, 2026-11-03. Nothing here is in the pool yet: no code, no `POOL_VERSION` bump, and
`docs/DOOMSDAY.md` is unchanged. After the OK, the next steps are stories for the trackers, the probe checks, the
site's copy of the pool and a pool version bump. Weeklies come later and are not part of this draft.

Decisions this draft follows (Nico, 2026-11-03):
- At least 100 PvE dailies, **mostly new kinds of activity**, with only a few size variants.
- **General missions only:** no zone, dungeon or place names; anyone can do them anywhere, given their level and
  characters.
- **Everything drafted, gated by the probe:** a mission that needs an unverified Forever API is in the catalogue and
  joins the pool only in the release after its API is verified (`DOOMSDAY.md` "Pool version").
- New stored data is fine under rule 8: new feed and record fields are optional, nil means unknown.

The rules of `DOOMSDAY.md` still hold: per friend, any character counts and progress adds up across characters;
"a friend" means a community character of another BattleTag (never an own alt); the draw takes 3 dailies from 3
different categories; a missing situation field never swaps; recommend, never restrict; no pronouns in texts; gold
never shown as an amount.

## Summary

**100 dailies in 12 categories.** The 20 existing dailies are all kept with their ids; 3 of them move to a new
category (below).

| Category | Dailies | A | B | C | D |
|---|---|---|---|---|---|
| quests | 10 | 6 | | 4 | |
| levels | 9 | 5 | 1 | 2 | 1 |
| dungeons | 9 | 6 | 1 | 1 | 1 |
| crafts | 10 | 2 | 2 | 1 | 5 |
| play | 8 | 4 | 4 | | |
| social | 10 | | 2 | 5 | 3 |
| exploration | 8 | | 2 | 4 | 2 |
| travel | 7 | | | 1 | 6 |
| combat | 7 | | | | 7 |
| loot | 6 | | 1 | 2 | 3 |
| economy | 7 | | 1 | | 6 |
| care | 9 | | | | 9 |
| **Total** | **100** | **23** | **14** | **20** | **43** |

**Data** (the column "Data" in the tables):
- **A, recorded today** (23): the addon records the facts already. 14 of them are pool version 1; the other 9 need
  only the goal (catalogue entry, progress function, golden cases) and can join the next pool version.
- **B, existing tracker, waiting for its check** (14): CF-52, CF-53 and CF-56 trackers that are built but still
  unverified on Forever. They join once their `VERIFY.md` item or story steps pass (V-number or story named).
- **C, new tracker on verified APIs** (20): needs new recording code, but every event and API it reads is in
  `docs/API-FINDINGS.md`. No probe needed; can join the next pool version.
- **D, new tracker, needs a probe check** (43): reads an API that is not verified on Forever. Each names its probe
  check (P1 to P26 below), which the probe story turns into `VERIFY.md` items (V90 and up) and FriendProbe checks.

So **43 of 100 work without a probe** (A + C), **57 with today's data or verified APIs once B's launch checks pass**
(A + B + C).

### New categories
The 5 existing categories (quests, levels, dungeons, crafts, play) become 12. New: **social**, **exploration**,
**travel**, **combat**, **loot**, **economy**, **care** (upkeep of a character: repair, train, rest, eat, restock).
- `d.groupFriend` and `d.trade` move from play to **social**, `d.rare` from play to **loot**. None of the three is in
  a released pool (no `since`), so moving them changes no draw that has happened and no stored data.
- With 12 categories, each still has enough goals for the "not twice running" rule.
- **Early pool:** combat, travel, economy and care are mostly D. Until their probe checks pass they hold few or no
  goals, so the draw sees fewer categories. 8 categories have at least 2 A or C goals, so the 3-category draw always
  works.

### New trackers
Grouped by what they watch; each is a small adapter (raw values) plus a core fact in `Goals.newFacts` (all new facts
optional, nil = unknown; they stay local like CF-56's facts, only `done` travels).

| Tracker | Goals | Events and APIs | Probe |
|---|---|---|---|
| Quest details at turn-in | `d.questUp`, `d.groupQuest`, `d.classQuest`, `d.dungeonQuest`, `d.questBurst`, `d.accept5`, `d.questTogether` | `QUEST_TURNED_IN` (questID, already used by CF-22), `QUEST_ACCEPTED`, `C_QuestLog.GetInfo` `level` and `suggestedGroup` kept in the stored quest log next to `area` and `dungeon` (V23, V31); turn-in times | none |
| Level context | `d.dingDungeon`, `d.dingFriend`, `d.lowbie` | `PLAYER_LEVEL_UP` with `GetInstanceInfo` type (V35) and the group's friends (CF-53 groups) | none |
| XP bar | `d.xpQuarter` | `PLAYER_XP_UPDATE`, `UnitXP`, `UnitXPMax` | P2 |
| Dungeon history | `d.newDungeon` | feed `runs`; new stored per-character set of dungeon names | none |
| Raid bosses | `d.raidBoss` | `ENCOUNTER_END` in a raid (CF-23 records raids; only the dungeon part is verified) | P3 |
| Crafting details | `d.craft5`, `d.cook5`, `d.bandage3`, `d.craftGreen` | `LOOT_ITEM_CREATED_SELF` (CF-56's crafted tracker, V83), counted; item class and quality | P16 |
| Gathering and chests | `d.gather10`, `d.treasure` | `LOOT_OPENED`, `GetLootSourceInfo`, item class of looted items | P17 |
| Recipes | `d.newRecipe` | a new-recipe event or system message | P15 |
| Fishing spots | `d.fishZones` | CF-56's fishing tracker plus the zone | (V84) |
| Presence and zones of friends | `d.sameZone`, `d.online3` | `C_Club.GetMemberInfo` `zone` and presence, `CLUB_MEMBER_PRESENCE_UPDATED`, `CLUB_MEMBER_UPDATED` (V17, V18) | none |
| Party levels | `d.carry` | `GROUP_ROSTER_UPDATE`, party GUIDs (V35), friends' character levels | none |
| Community chat | `d.chatHello` | `CHAT_MSG_COMMUNITIES_CHANNEL`, own message by sender GUID (V38) | none |
| Whispers and emotes | `d.whisper`, `d.wave` | whisper-inform events, a `DoEmote` hook with the target's GUID | P19 |
| Screenshots | `d.groupPic` | `SCREENSHOT_SUCCEEDED` | P22 |
| Zones visited | `d.roam4`, `d.newZone`, `d.crossSea`, `d.nostalgia`, `d.daredevil` | `ZONE_CHANGED_NEW_AREA`, `GetRealZoneText`, `GetInstanceInfo` continent (V35); zone level ranges from Group Finder zone activities (V46); new stored per-character zone set | none |
| Places within zones | `d.places10` | `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `GetSubZoneText` | P26 |
| Movement state | `d.swim`, `d.ride` | `IsSwimming`, `IsMounted`, polled every few seconds | P9 |
| Flights | `d.flight`, `d.newFlight` | `UnitOnTaxi`, `PLAYER_CONTROL_LOST`, the new-flight-path message | P5 |
| Own spell casts | `d.hearth`, `d.bandageUp` | `UNIT_SPELLCAST_SUCCEEDED` for the player with a readable spell ID | P6 |
| Home inn | `d.bind` | `PLAYER_BINDING_CHANGED`, `GetBindLocation` | P7 |
| Summons | `d.summoned` | `CONFIRM_SUMMON`, `C_SummonInfo.GetSummonConfirmSummoner` | P25 |
| Kills from XP messages | `d.kills30`, `d.elite`, `d.rareMob`, `d.bigFoe`, `d.streak20`, `d.duoHunt` | `CHAT_MSG_COMBAT_XP_GAIN` (the combat log is blocked); the victim's classification and level from the target, mouseover or nameplate seen before the kill (as the Hunt does for players) | P1, P4 |
| Weapon skills | `d.weaponSkill` | `CHAT_MSG_SKILL` with `SKILL_RANK_UP` (no skill-line API on Forever) | P18 |
| Loot quality and coins | `d.green5`, `d.reward`, `d.coins10` | `CHAT_MSG_LOOT` (CF-53's parser, V83) counting uncommon items and quest rewards; `CHAT_MSG_MONEY` | P20 (coins) |
| Gear worn | `d.equipNew` | `PLAYER_EQUIPMENT_CHANGED`, `GetInventoryItemID` | P24 |
| Merchant | `d.vendorSale`, `d.vendorBuy`, `d.repair`, `d.restock` | `MERCHANT_SHOW` and `MERCHANT_CLOSED` around CF-53's `PLAYER_MONEY` tracker; repair and buy hooks | P10 |
| Auction house | `d.auctionPost`, `d.auctionBuy` | auction events or system messages | P12 |
| Mail | `d.mailFriend`, `d.mailbox` | `SendMail` hook (recipient), `MAIL_SEND_SUCCESS`, inbox take hooks | P11 |
| Bank | `d.bank` | `BANKFRAME_OPENED` | P13 |
| Trainer | `d.trainer` | `TRAINER_SHOW`, the learned-spell message | P14 |
| Resting | `d.inn` | `IsResting` at `PLAYER_LOGOUT` | P8 |
| Auras | `d.wellFed`, `d.buffFriend` | `UNIT_AURA`, `C_UnitAuras.GetAuraDataByIndex` (spell ID, source) out of combat | P21 |
| Bags | `d.tidyBags` | `BAG_UPDATE`, `C_Container.GetContainerItemInfo` quality | P23 |

### New swap situation fields
All optional, a missing field never swaps: `below20` (characters below 20), `hasCooking`, `hasFirstAid`,
`hasGathering` (Herbalism, Mining or Skinning), `riding` (a character with riding, CF-53), `friends` (other friends in
the community), `canBuff` (a character of a class with a buff it can cast on others). The existing `below60`,
`highest`, `hasProfession`, `hasFishing`, `hasCraftingProfession` and `dungeonInRange` cover the rest.

### Probe checks
For the probe story; each becomes a `VERIFY.md` item (V90 and up) with exact steps and a FriendProbe check. "Retail"
means a Retail 12.1.5 dry run can answer it (Nico's rule: checked on Retail counts as done), "Forever" that only
Forever can.

| Check | Question | Where |
|---|---|---|
| P1 | Does `CHAT_MSG_COMBAT_XP_GAIN` arrive with readable text matching `COMBATLOG_XPGAIN_FIRSTPERSON` (and its group variants) once per kill, also in a group? | Retail (low character), Forever |
| P2 | Do `PLAYER_XP_UPDATE`, `UnitXP("player")` and `UnitXPMax("player")` work? | Retail |
| P3 | Does `ENCOUNTER_END` (or `BOSS_KILL`) fire with `success` for raid bosses? (V35's raid part) | Forever |
| P4 | Do `UnitClassification`, `UnitLevel` and `UnitName` read for hostile creatures by target, mouseover and nameplate? | Retail |
| P5 | Do `UnitOnTaxi` and `PLAYER_CONTROL_LOST` tell a flight, and does `ERR_NEWTAXIPATH` arrive (`UI_INFO_MESSAGE` or `CHAT_MSG_SYSTEM`) when a flight path is learned? | Forever (Retail has flight paths too) |
| P6 | Does `UNIT_SPELLCAST_SUCCEEDED` for `"player"` give a readable spell ID (Hearthstone 8690, a bandage)? | Retail |
| P7 | Do `PLAYER_BINDING_CHANGED` and `GetBindLocation()` work when setting the hearthstone? | Retail |
| P8 | Does `IsResting()` read true in an inn and at `PLAYER_LOGOUT`? | Retail |
| P9 | Do `IsMounted()` and `IsSwimming()` read as expected? | Retail |
| P10 | Merchant: `MERCHANT_SHOW`, `MERCHANT_CLOSED`, `CanMerchantRepair`, `GetRepairAllCost`, hooks on `RepairAllItems` and `BuyMerchantItem` with `GetMerchantItemLink`? | Retail |
| P11 | Mail: `MAIL_SHOW`, a `SendMail` hook with the recipient (a full name with a space), `MAIL_SEND_SUCCESS`, `GetInboxHeaderInfo` and hooks on taking items or money? | Retail, Forever (recipient name) |
| P12 | Which auction house UI does Forever have, and which events or system messages tell a posted auction and a bought one? | Forever |
| P13 | Does `BANKFRAME_OPENED` fire? | Retail |
| P14 | `TRAINER_SHOW`, and which event or message tells a spell learned at a trainer? | Retail |
| P15 | Which event or message tells a recipe learned (`NEW_RECIPE_LEARNED`, `ERR_LEARN_RECIPE_S`)? | Forever |
| P16 | `C_Item.GetItemInfoInstant` class and subclass for a crafted food and bandage, and `C_Item.GetItemQualityByID` for a just-created item? | Forever |
| P17 | `GetLootSourceInfo(slot)` on `LOOT_OPENED`: is the source GUID readable (GameObject or Creature)? Item class 7 subclasses for herbs, ore and leather? | Forever |
| P18 | Does `CHAT_MSG_SKILL` arrive with `SKILL_RANK_UP` text on a weapon skill-up? | Forever (Retail has no weapon skills) |
| P19 | Are whisper-inform targets readable (`CHAT_MSG_WHISPER_INFORM`, `CHAT_MSG_BN_WHISPER_INFORM`), and does a `DoEmote` hook see the token and `UnitGUID("target")`? | Retail |
| P20 | Does `CHAT_MSG_MONEY` arrive with `YOU_LOOT_MONEY` / `LOOT_MONEY_SPLIT` text? | Retail |
| P21 | Are `C_UnitAuras.GetAuraDataByIndex` `spellId` and `sourceUnit` readable out of combat, for the player and party members? | Retail |
| P22 | Does `SCREENSHOT_SUCCEEDED` fire? | Retail |
| P23 | Does `C_Container.GetContainerItemInfo` give `quality` for bag items? | Retail |
| P24 | Do `PLAYER_EQUIPMENT_CHANGED` (slot) and `GetInventoryItemID` give the equipped item? | Retail |
| P25 | Do `CONFIRM_SUMMON` and `C_SummonInfo.GetSummonConfirmSummoner()` name the summoner? | Forever (needs a warlock friend) |
| P26 | Do `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS` and `GetSubZoneText()` work? | Retail |

### Hard to track honestly, and open questions
1. **Combat at level 60.** Kills come only from XP messages (P1), and a level 60 character gets none. All 7 combat
   goals are "can't do" when every character is 60 and swap to a dungeon goal. If P1 fails, the combat category
   stays empty. Is that acceptable, or should combat wait for a kill source that works at 60?
2. **Kill details from the target cache** (`d.elite`, `d.rareMob`, `d.bigFoe`): like the Hunt, the victim's
   classification and level are only known when it was targeted or moused over before the kill. AoE and pulls seen
   only in passing are missed. `d.rareMob` depends on rare spawns: some days nobody meets one.
3. **Friends' schedules** (`d.groupFriend`, `d.questTogether`, `d.dingFriend`, `d.sameZone`, `d.online3`,
   `d.carry`, `d.duoHunt`, `d.mailFriend`, `d.wave`, `d.groupPic`, `d.buffFriend`, `d.summoned`): only doable when a
   friend plays at the same time. As with `d.groupFriend` today there is no fallback, because it can't be known in
   advance. Keep them, or give them a fallback when no friend was online the day before?
4. **Very easy goals:** `d.chatHello`, `d.wave`, `d.whisper`, `d.hearth`, `d.bank`, `d.mailbox` take seconds. They
   score the same 5 points as a dungeon. Keep them (variety, a nudge to be social), or cut some?
5. **Done at logout:** `d.inn` is done at the logout, which also stamps the crown's time. Fine, or drop it?
6. **History starts at install:** `d.newZone` and `d.newDungeon` need a per-character set of zones and dungeons. A
   new character has an empty set anyway; for an existing one the set can be seeded from the stored feed and quest
   log, but the first days will still count some old places as new.
7. **Zone level ranges** (`d.nostalgia`, `d.daredevil`): from Group Finder's "Quests & Zones" activities (V46),
   matched to the zone name the feed stores. Forever's new zones must be in that list; zones without a match never
   count.
8. **Treasure chests** (`d.treasure`): a chest and a herb or ore node are both game objects. Telling them apart by
   what is looted (no herb, ore or fish) is a guess; P17 decides.
9. **`d.profit` is easy** with any vendor sale. It never shows an amount.
10. **Crafting checks** for cooking and bandages use the created item's class (P16), not the profession window, so
    a food made by another source (a conjured item) could count. Mage-conjured food is "created" too: exclude
    conjured items by item class if P16 shows they differ.
11. **Auction house** (P12): Forever may have the Mainline auction house or a Classic-style one; the tracker waits
    for the answer.
12. Ideas left out, ready if more are wanted: earn reputation with 2 factions (`CHAT_MSG_COMBAT_FACTION_CHANGE`),
    be resurrected by a friend (`RESURRECT_REQUEST`), open a lockbox, a full party of friends in a dungeon (a
    weekly), visit a capital city (would need a list of city names).

## The catalogue

Columns: **Id** (new ids are new; existing ids are marked ★) · **Title** (player copy) · **Label** (at most 10
characters, `Doomsday.SHORT_LABELS`) · **Done when** (exactly) · **Data** (A, B, C, D as in the summary) · **Can't
do when → fallback**.

"A character" is any of the friend's characters; counts add up across characters unless the text says "one
character". "That day" is the Doomsday day.

### quests (10)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.quests10` | Finish 10 quests | 10 quests | 10 quests handed in that day | A (pool 1) | |
| ★ `d.quests20` | Finish 20 quests | 20 quests | 20 quests handed in that day | A (pool 1) | |
| ★ `d.zone5` | Finish 5 quests in one zone | 5 in zone | 5 quests handed in in one zone | A (pool 1) | |
| ★ `d.zones3` | Hand in quests in 3 zones | 3 zones | quests handed in in 3 zones | A (pool 1) | |
| ★ `d.shared3` | Share 3 quests with a friend | 3 shared | at some moment, the own quest log and one friend's synced log share 3 quests | A (pool 1) | no friend's quest log known → `d.quests10` |
| `d.questUp` | Finish a quest above the character's level | Hard quest | a quest handed in whose level (from the quest log) is higher than the character's level at the hand-in | C: quest level kept in the stored log | all characters at 60 → `d.quests10` |
| `d.groupQuest` | Finish a group quest | Group Q | a quest handed in that the quest log marked as a group quest (`suggestedGroup` > 0) | C: `suggestedGroup` kept in the stored log | |
| `d.classQuest` | Finish a class quest | Class Q | a quest handed in whose quest log header is the character's class name | A: stored log `area` | |
| `d.questBurst` | Hand in 3 quests within 10 minutes | Quick 3 | 3 quests handed in by one character within 10 minutes | C: turn-in times | |
| `d.accept5` | Take on 5 new quests | Take 5 | 5 different quests accepted that day (by quest ID; abandoning and taking one again counts once) | C: `QUEST_ACCEPTED` | |

### levels (9)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.level` | Gain a level | Level | a character gains a level | A (pool 1) | all characters at 60 → `d.quests20` |
| ★ `d.altLevel` | Gain a level on an alt | Alt level | a level on any character but the highest | A (pool 1) | only one character below 60 → `d.quests10` |
| ★ `d.ilvl` | Raise an item level | Item level | a character's item level is higher than at its first login that day | A (pool 1) | item level unreadable → `d.quests10` |
| ★ `d.cleanLevel` | Gain a level without dying | Clean lvl | a level on a character with no death between that level and the previous one | B: 52 (CF-52 deaths) | all characters at 60 → `d.quests20` |
| `d.levels2` | Gain 2 levels | 2 levels | 2 levels over all characters | A | all characters at 60 → `d.quests20` |
| `d.xpQuarter` | Fill a quarter of the XP bar | XP 25% | XP gained that day adds up to a quarter of the bar: the sum over gains of (gain ÷ `UnitXPMax` at the gain) ≥ 0.25 | D: P2 | all characters at 60 → `d.quests20` |
| `d.dingDungeon` | Gain a level inside a dungeon | Deep ding | a level gained while the instance type is `party` | C: `GetInstanceInfo` at the level-up | all characters at 60 or no character in range of a dungeon → `d.level` |
| `d.dingFriend` | Gain a level in a group with a friend | Duo ding | a level gained while grouped with a friend's community character | C: group at the level-up (CF-53 groups) | all characters at 60 → `d.groupFriend` |
| `d.lowbie` | Gain a level on a character below 20 | Lowbie | a level on a character that was below 20 before it | A | no character below 20 → `d.altLevel` |

### dungeons (9)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.dungeon` | Run a dungeon | Dungeon | a finished party run (feed `runs`) | A (pool 1) | no character in range of a dungeon → `d.quests10` |
| ★ `d.dungeonFriend` | Run a dungeon with a friend | Group run | a party run with at least one friend's community character (`with`) | A (pool 1) | as `d.dungeon` |
| ★ `d.bosses3` | Defeat 3 dungeon bosses | 3 bosses | 3 bosses across that day's party runs | A (pool 1) | as `d.dungeon` |
| `d.dungeonQuest` | Hand in a dungeon quest | Dungeon Q | a quest handed in that the stored quest log marks as a dungeon quest (`dungeon`, V31) | A: stored log `dungeon` | as `d.dungeon` |
| `d.cleanRun` | Run a dungeon without dying | Clean run | a party run with at least 1 boss and no death of that character between its start and its last boss | B: 52 (deaths) | as `d.dungeon` |
| `d.speedRun` | Defeat 3 bosses of one dungeon within 45 minutes | Speed run | a party run with 3 or more bosses whose first entry to last boss took 45 minutes or less | A: run `startedAt`, `lastAt` | as `d.dungeon` |
| `d.newDungeon` | Run a dungeon new to the character | Fresh run | a party run with at least 1 boss in a dungeon that character has no earlier run of | C: per-character dungeon set (new stored data) | as `d.dungeon` |
| `d.raidBoss` | Defeat a raid boss | Raid boss | a boss killed in a raid run (feed `runs`, instance `raid`) | D: P3 | no character at 60 → `d.bosses3` |
| `d.dungeons2` | Run 2 dungeons | 2 dungeons | 2 finished party runs | A | as `d.dungeon` |

### crafts (10)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.skill5` | Earn 5 profession skill points | Skills | 5 points over all professions since the first login that day | A (pool 1) | no profession on any character → `d.quests10` |
| ★ `d.secondary` | Raise Cooking, First Aid or Fishing | Secondary | 1 point in one of them, or learning one | A (pool 1) | |
| ★ `d.fish20` | Catch 20 fish | 20 fish | 20 items from fishing loot | B: 56 (V84) | no character with Fishing → `d.secondary` |
| `d.craft5` | Craft 5 items | Craft 5 | 5 items created (`LOOT_ITEM_CREATED_SELF`, a stack counts its count) | C: CF-56's crafted tracker, counted (V83) | no profession at all → `d.secondary` |
| `d.cook5` | Cook 5 meals | Cook 5 | 5 food or drink items created (item class consumable, food and drink) | D: P16 | no character with Cooking → `d.secondary` |
| `d.bandage3` | Make 3 bandages | Bandages | 3 bandages created (item class consumable, bandage) | D: P16 | no character with First Aid → `d.secondary` |
| `d.gather10` | Gather 10 herbs, ore or leather | Gather 10 | 10 items of the herb, metal and stone or leather classes looted from a gathering node or a skinned body | D: P17 | no character with Herbalism, Mining or Skinning → `d.skill5` |
| `d.newRecipe` | Learn a new recipe | Recipe | a recipe, pattern, plan, schematic or formula learned | D: P15 | no profession at all → `d.secondary` |
| `d.craftGreen` | Craft something uncommon or better | Fine craft | an item of uncommon (green) or better quality created | D: P16 | no crafting profession → `d.craft5` |
| `d.fishZones` | Fish in 2 zones | Fish spots | fishing loot in 2 different zones | B: 56 (V84) plus the zone | no character with Fishing → `d.secondary` |

### play (8)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.chars2` | Play 2 characters | 2 chars | 2 characters logged in that day | A (pool 1) | only one character → `d.quests10` |
| `d.chars3` | Play 3 characters | Play 3 | 3 characters logged in that day | A | fewer than 3 characters → `d.chars2` |
| `d.switchUp` | Play a character not played the day before | Switch up | a character logged in that day that wasn't logged in the previous Doomsday day | A: facts per day | only one character → `d.quests10` |
| `d.dustOff` | Play a character after a week away | Dust off | a character logged in whose last login was 7 or more days earlier (`lastPlayed`) | A | no character unplayed for 7 days → `d.chars2` |
| ★ `d.earlyBird` | Early bird: play before 09:00 | Early bird | logged in before 09:00 local time | B: 53 (CF-53 sessions) | |
| `d.nightOwl` | Night owl: play after 23:00 | Night owl | logged in at some moment between 23:00 and 03:00 local time | B: 53 (sessions) | |
| `d.session1h` | Play a 1-hour session | 1h session | one session lasting 60 minutes | B: 53 (sessions) | |
| `d.deathless` | Play an hour without dying | No deaths | 60 minutes of session time on one character with no death in between | B: 52 + 53 | |

### social (10)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.groupFriend` | Group up with a friend | Group up | in a group with a friend's community character | B: 53 (CF-53 groups) | |
| ★ `d.trade` | Trade with a friend | Trade | a completed trade with a friend's community character | B: 56 (V85) | |
| `d.questTogether` | Hand in a quest in a group with a friend | Duo quest | a quest handed in while grouped with a friend's community character | C: group at the hand-in | |
| `d.chatHello` | Say something in the community chat | Chat | an own message in the selected community's channel (by the sender's GUID) | C: V38 | |
| `d.sameZone` | Be in the same zone as a friend | Neighbours | a character in the same zone as a friend's online community character at the same moment | C: club member `zone` (V18) | no other friend in the community → `d.chars2` |
| `d.online3` | Be online with 3 friends at once | Full house | 3 other friends online in Forever at the same moment while a character plays | C: presence (V18, V19) | fewer than 3 other friends in the community → `d.groupFriend` |
| `d.carry` | Group with a friend 5+ levels lower | Carry | grouped with a friend's community character 5 or more levels below the own character | C: party levels | |
| `d.whisper` | Whisper a friend | Whisper | a whisper sent to a friend's community character or Battle.net account | D: P19 | |
| `d.wave` | Wave at a friend | Wave | the `/wave` emote with a friend's community character targeted | D: P19 | |
| `d.groupPic` | Take a screenshot in a group with a friend | Group pic | a screenshot taken while grouped with a friend's community character | D: P22 | |

### exploration (8)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.discover1` | Discover a new place | Discover | one of the game's "Discovered" messages | B: 56 (V86, answered on Retail) | |
| `d.discover3` | Discover 3 new places | Discover 3 | 3 "Discovered" messages | B: 56 (V86) | |
| `d.roam4` | Visit 4 zones | Roam 4 | 4 different zones entered (on any characters) | C: `ZONE_CHANGED_NEW_AREA` | |
| `d.newZone` | Set foot in a zone new to the character | New zone | a zone entered that the character has never been in (per-character zone set, seeded from its feed) | C: new stored data | |
| `d.places10` | Visit 10 places within zones | 10 places | 10 different subzones entered | D: P26 | |
| `d.swim` | Swim for 2 minutes | Swim | 2 minutes swimming in total, on one character | D: P9 | |
| `d.nostalgia` | Visit a zone far below the character's level | Nostalgia | a zone entered whose highest suggested level is 20 or more below the character's | C: zone levels (V46) | highest character below 30 → `d.roam4` |
| `d.daredevil` | Visit a zone above the character's level | Daredevil | a zone entered whose lowest suggested level is 5 or more above the character's | C: zone levels (V46) | all characters at 60 → `d.roam4` |

### travel (7)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.flight` | Take a flight | Fly | a flight on a flight master's route | D: P5 | |
| `d.newFlight` | Learn a new flight path | New flight | a new flight path learned | D: P5 | |
| `d.hearth` | Use the hearthstone | Hearth | the Hearthstone cast finished | D: P6 | |
| `d.bind` | Make a new inn home | New home | the hearthstone set to a place other than the one it was set to | D: P7 | |
| `d.ride` | Ride a mount for 15 minutes | Ride | 15 minutes mounted in total, on one character | D: P9 | no character with riding (CF-53) → `d.roam4` |
| `d.crossSea` | Cross the sea | Cross sea | a character changes continent (`GetInstanceInfo` instance ID 0 and 1 outside instances) | C: V35 | |
| `d.summoned` | Get summoned by a friend | Summoned | a summon accepted whose summoner is a friend's community character | D: P25 | |

### combat (7)
Kills come from the XP message, so they count only kills that give XP (no grey enemies, no level 60).

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.kills30` | Defeat 30 enemies | 30 foes | 30 kill XP messages | D: P1 | all characters at 60 → `d.bosses3` |
| `d.elite` | Defeat an elite | Elite | a kill XP message naming a creature last seen as elite or rare elite | D: P1, P4 | all characters at 60 → `d.bosses3` |
| `d.rareMob` | Defeat a rare enemy | Rare hunt | a kill XP message naming a creature last seen as rare or rare elite | D: P1, P4 | all characters at 60 → `d.bosses3` |
| `d.bigFoe` | Defeat an enemy 3+ levels higher | Big foe | a kill XP message naming a creature last seen 3 or more levels above the character, or as a skull | D: P1, P4 | all characters at 60 → `d.bosses3` |
| `d.streak20` | Defeat 20 enemies without dying | Streak 20 | 20 kill XP messages on one character with no death in between | D: P1 (+ 52) | all characters at 60 → `d.bosses3` |
| `d.weaponSkill` | Raise a weapon skill 5 times | Weapon +5 | 5 weapon or defense skill-up messages | D: P18 | |
| `d.duoHunt` | Defeat 15 enemies in a group with a friend | Duo hunt | 15 kill XP messages while grouped with a friend's community character | D: P1 | all characters at 60 → `d.dungeonFriend` |

### loot (6)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| ★ `d.rare` | Loot a rare item | Rare loot | a rare (blue) or better item looted | B: 53 (V83) | |
| `d.green5` | Loot 5 uncommon items | 5 greens | 5 uncommon (green) or better items looted or received | C: CF-53's loot parser, counted (V83) | |
| `d.reward` | Earn an uncommon quest reward | Reward | a quest reward of uncommon (green) or better quality | C: `LOOT_ITEM_PUSHED_SELF` (V83) | |
| `d.coins10` | Loot coins from 10 enemies | 10 purses | 10 money loot messages | D: P20 | |
| `d.equipNew` | Wear a new find | New gear | an item equipped that the character looted or received that day | D: P24 | |
| `d.treasure` | Open a treasure chest | Treasure | loot from a game object that isn't a herb, ore or fishing node | D: P17 | |

### economy (7)
Gold is never shown as an amount; the goals count actions.

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.vendorSale` | Sell to a merchant | Sell | money gained while a merchant window is open | D: P10 | |
| `d.vendorBuy` | Buy from a merchant | Shopping | an item bought from a merchant (not a repair) | D: P10 | |
| `d.auctionPost` | Put an item up for auction | Auction | an auction posted | D: P12 | |
| `d.auctionBuy` | Buy at the auction house | Bargain | an auction bought or won | D: P12 | |
| `d.mailFriend` | Send mail to a friend | Mail pal | mail sent to a friend's community character | D: P11 | |
| `d.mailbox` | Empty the mailbox | Mailbox | an item or money taken from the mailbox | D: P11 | |
| `d.profit` | End a session in profit | In profit | a session that ends with more money than it started with | B: 53 (gold, sessions) | |

### care (9)

| Id | Title | Label | Done when | Data | Can't do when → fallback |
|---|---|---|---|---|---|
| `d.repair` | Repair gear | Repair | a repair paid at a merchant | D: P10 | |
| `d.trainer` | Learn a spell at a trainer | Train | a spell or rank learned from a class trainer | D: P14 | all characters at 60 → `d.repair` |
| `d.inn` | Log out rested | Tuck in | a logout in a rested area (inn or city) | D: P8 | |
| `d.wellFed` | Get Well Fed | Well fed | the "Well Fed" aura on a character | D: P21 | |
| `d.buffFriend` | Buff a friend | Buff pal | an aura cast by the own character on a friend's community character | D: P21 | no character that can buff others → `d.groupFriend` |
| `d.restock` | Restock food or drink | Restock | food or drink bought from a merchant | D: P10, P16 | |
| `d.bank` | Visit the bank | Bank | the bank window opened | D: P13 | |
| `d.tidyBags` | Clear the junk from the bags | Tidy bags | a character that had poor (grey) items in its bags has none left | D: P23 | |
| `d.bandageUp` | Use a bandage | Bandage up | a First Aid bandage cast finished | D: P6 | no character with First Aid → `d.secondary` |
