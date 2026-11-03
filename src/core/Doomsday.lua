-- Doomsday: the rules of docs/DOOMSDAY.md (CF-55). Pure Lua, no WoW globals: the addon and the site's
-- TypeScript copy both follow it, checked against tests/fixtures/doomsday-cases.json (the golden cases).
-- Any change here changes DOOMSDAY.md, the golden file and the site's copy in the same release.
local _, ns = ... -- requires ns.Calendar (load core/Calendar.lua first)

local Doomsday = {}

Doomsday.POOL_VERSION = 1
Doomsday.DEFAULT_RESET = 68400   -- 19:00 realm time, seconds after midnight
Doomsday.DAY = 86400
-- The first Doomsday day: the draw runs forward from here, so "never twice in a row" is exact.
-- Day 20761 is the day that starts on Wednesday 2026-11-04 (launch).
Doomsday.EPOCH = 20761

Doomsday.POINTS = { daily = 5, weekly = 15, duelWin = 3, duelLoss = 1 }
Doomsday.SAME_VICTIM_LIMIT = 3   -- the 4th and later kill of one victim name in a day doesn't count

-- ===== Schedule =====

-- pick(n, salt, count) of DOOMSDAY.md "The draw": an index 1..count. Exact in Lua 5.1 doubles and
-- JavaScript numbers (n * 2654435761 stays below 2^53 for any day or week number).
function Doomsday.pick(n, salt, count)
  return ((n * 2654435761 + salt) % 4294967296) % count + 1
end

-- The realm's offset from UTC in seconds, rounded to 15 minutes, from the game clock (GetGameTime) and
-- the server time. nil without the game clock.
function Doomsday.realmOffset(hour, minute, serverTime)
  if type(hour) ~= "number" or type(minute) ~= "number" or type(serverTime) ~= "number" then return nil end
  local diff = (hour * 60 + minute) - math.floor(serverTime / 60) % 1440
  if diff > 720 then diff = diff - 1440 elseif diff <= -720 then diff = diff + 1440 end
  return math.floor(diff / 15 + 0.5) * 15 * 60
end

-- Doomsday day number of a server time: named after the realm date it starts on.
function Doomsday.day(serverTime, offset, reset)
  return math.floor((serverTime + (offset or 0) - (reset or Doomsday.DEFAULT_RESET)) / Doomsday.DAY)
end

-- Week number of a day: a week starts on Sunday at the reset (day 3, Sunday 1970-01-04, starts week 1).
function Doomsday.week(n)
  return math.floor((n + 4) / 7)
end

-- The first day of a week.
function Doomsday.weekStart(week)
  return week * 7 - 4
end

-- Server time at which day n starts.
function Doomsday.dayStart(n, offset, reset)
  return n * Doomsday.DAY + (reset or Doomsday.DEFAULT_RESET) - (offset or 0)
end

-- Seconds until the next reset.
function Doomsday.resetsIn(serverTime, offset, reset)
  return Doomsday.dayStart(Doomsday.day(serverTime, offset, reset) + 1, offset, reset) - serverTime
end

local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = ns.Calendar.MONTHS
local civil = ns.Calendar.date

-- Kept under their names here (CF-59: the math is in core/Calendar.lua).
Doomsday.civil = ns.Calendar.date
Doomsday.dayNumberOf = ns.Calendar.dayNumber

-- "Tue 28 Oct": the day's name (the realm date it starts on).
function Doomsday.label(n)
  local _, month, day = civil(n)
  return string.format("%s %d %s", WEEKDAYS[ns.Calendar.weekday(n) + 1], day, MONTHS[month])
end

-- "3 h 12 m", "12 m", "0 m".
function Doomsday.duration(seconds)
  local minutes = math.max(0, math.floor(seconds / 60))
  if minutes >= 60 then return string.format("%d h %d m", math.floor(minutes / 60), minutes % 60) end
  return string.format("%d m", minutes)
end

-- ===== Catalogue =====

--[[ Every goal, in pool order (DOOMSDAY.md). slot: daily, weekly, skirmish or bounty. category: the draw's
category (the 15 of the PvE dailies, docs/DOOMSDAY-CATALOGUE.md). since: the pool version it joined (nil: waits
for data). points: the catalogue's size (1, 3 or 5; CF-69 scores it from a later pool version). can: the
situation check (Doomsday.canDo); fallback: replacements in order. The PvE dailies follow the catalogue (CF-70).
Ids are never reused or renamed; a retired goal stays here with retired = true. ]]
local GOALS = {
  -- quests
  { id = "d.quests10", slot = "daily", category = "quests", since = 1, points = 3, text = "Finish 10 quests" },
  { id = "d.quests20", slot = "daily", category = "quests", since = 1, points = 5, text = "Finish 20 quests" },
  { id = "d.zone5", slot = "daily", category = "quests", since = 1, points = 3, text = "Finish 5 quests in one zone" },
  { id = "d.zones3", slot = "daily", category = "quests", since = 1, points = 3, text = "Hand in quests in 3 zones" },
  { id = "d.shared3", slot = "daily", category = "quests", since = 1, points = 3, text = "Share 3 quests with a friend",
    can = "friendQuestLog", fallback = { "d.quests10" } },
  { id = "d.questUp", slot = "daily", category = "quests", points = 3,
    text = "Finish a quest above the character's level", can = "below60", fallback = { "d.quests10" } },
  { id = "d.groupQuest", slot = "daily", category = "quests", points = 3, text = "Finish a group quest" },
  { id = "d.classQuest", slot = "daily", category = "quests", points = 3, text = "Finish a class quest" },
  { id = "d.questBurst", slot = "daily", category = "quests", points = 3, text = "Hand in 3 quests within 10 minutes" },
  { id = "d.accept5", slot = "daily", category = "quests", points = 3, text = "Take on 5 new quests" },

  -- levels
  { id = "d.level", slot = "daily", category = "levels", since = 1, points = 3, text = "Gain a level",
    can = "below60", fallback = { "d.quests20" } },
  { id = "d.altLevel", slot = "daily", category = "levels", since = 1, points = 3, text = "Gain a level on an alt",
    can = "altBelow60", fallback = { "d.quests10" } },
  { id = "d.ilvl", slot = "daily", category = "levels", since = 1, points = 3, text = "Raise an item level",
    can = "ilvlReadable", fallback = { "d.quests10" } },
  { id = "d.cleanLevel", slot = "daily", category = "levels", points = 3, text = "Gain a level without dying",
    can = "below60", fallback = { "d.quests20" } },
  { id = "d.levels2", slot = "daily", category = "levels", points = 5, text = "Gain 2 levels",
    can = "below60", fallback = { "d.quests20" } },
  { id = "d.dingDungeon", slot = "daily", category = "levels", points = 3, text = "Gain a level inside a dungeon",
    can = "below60Dungeon", fallback = { "d.level" } },
  { id = "d.dingFriend", slot = "daily", category = "levels", points = 3,
    text = "Gain a level in a group with a friend", can = "below60", fallback = { "d.groupFriend" } },
  { id = "d.lowbie", slot = "daily", category = "levels", points = 3, text = "Gain a level on a character below 20",
    can = "below20", fallback = { "d.altLevel" } },

  -- dungeons
  { id = "d.dungeon", slot = "daily", category = "dungeons", since = 1, points = 5, text = "Run a dungeon",
    can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.dungeonFriend", slot = "daily", category = "dungeons", since = 1, points = 5,
    text = "Run a dungeon with a friend", can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.bosses3", slot = "daily", category = "dungeons", since = 1, points = 5, text = "Defeat 3 dungeon bosses",
    can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.dungeonQuest", slot = "daily", category = "dungeons", points = 3, text = "Hand in a dungeon quest",
    can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.cleanRun", slot = "daily", category = "dungeons", points = 5, text = "Run a dungeon without dying",
    can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.speedRun", slot = "daily", category = "dungeons", points = 5,
    text = "Defeat 3 bosses of one dungeon within 45 minutes", can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.newDungeon", slot = "daily", category = "dungeons", points = 5, text = "Run a dungeon new to the character",
    can = "dungeonInRange", fallback = { "d.quests10" } },
  { id = "d.dungeons2", slot = "daily", category = "dungeons", points = 5, text = "Run 2 dungeons",
    can = "dungeonInRange", fallback = { "d.quests10" } },

  -- crafts
  { id = "d.skill5", slot = "daily", category = "crafts", since = 1, points = 3,
    text = "Earn 5 profession skill points", can = "hasProfession", fallback = { "d.quests10" } },
  { id = "d.secondary", slot = "daily", category = "crafts", since = 1, points = 3,
    text = "Raise Cooking, First Aid or Fishing" },
  { id = "d.craft5", slot = "daily", category = "crafts", points = 3, text = "Craft 5 items",
    can = "anyProfession", fallback = { "d.secondary" } },
  { id = "d.gather10", slot = "daily", category = "crafts", points = 3, text = "Gather 10 herbs, ore or leather",
    can = "hasGathering", fallback = { "d.skill5" } },
  { id = "d.newRecipe", slot = "daily", category = "crafts", points = 3, text = "Learn a new recipe",
    can = "anyProfession", fallback = { "d.secondary" } },
  { id = "d.craftGreen", slot = "daily", category = "crafts", points = 3, text = "Craft something uncommon or better",
    can = "hasCraftingProfession", fallback = { "d.craft5" } },

  -- cooking
  { id = "d.cook5", slot = "daily", category = "cooking", points = 3, text = "Cook 5 meals",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.cook15", slot = "daily", category = "cooking", points = 5, text = "Cook 15 dishes",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.cookSkill5", slot = "daily", category = "cooking", points = 3, text = "Raise Cooking by 5 points",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.cookKinds3", slot = "daily", category = "cooking", points = 3, text = "Cook 3 different dishes",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.campfire", slot = "daily", category = "cooking", points = 1, text = "Light a campfire",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.campfireBuff", slot = "daily", category = "cooking", points = 3,
    text = "Sit at a campfire fed with 3 or more items" },
  { id = "d.eatOwn", slot = "daily", category = "cooking", points = 3, text = "Eat a dish cooked that day",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.cookRecipe", slot = "daily", category = "cooking", points = 3, text = "Learn a cooking recipe",
    can = "hasCooking", fallback = { "d.secondary" } },
  { id = "d.feedFriend", slot = "daily", category = "cooking", points = 3,
    text = "Give a friend a dish cooked by an own character", can = "hasCooking", fallback = { "d.trade" } },

  -- fishing
  { id = "d.fish20", slot = "daily", category = "fishing", points = 3, text = "Catch 20 fish",
    can = "hasFishing", fallback = { "d.secondary" } },
  { id = "d.fishZones", slot = "daily", category = "fishing", points = 3, text = "Fish in 2 zones",
    can = "hasFishing", fallback = { "d.secondary" } },
  { id = "d.fish50", slot = "daily", category = "fishing", points = 5, text = "Catch 50 fish",
    can = "hasFishing", fallback = { "d.secondary" } },
  { id = "d.fishSkill5", slot = "daily", category = "fishing", points = 3, text = "Raise Fishing by 5 points",
    can = "hasFishing", fallback = { "d.secondary" } },
  { id = "d.fishKinds3", slot = "daily", category = "fishing", points = 3, text = "Catch 3 kinds of fish",
    can = "hasFishing", fallback = { "d.secondary" } },
  { id = "d.fishFriend", slot = "daily", category = "fishing", points = 3, text = "Fish in a group with a friend",
    can = "hasFishing", fallback = { "d.groupFriend" } },
  { id = "d.fishNight", slot = "daily", category = "fishing", points = 3, text = "Fish at night",
    can = "hasFishing", fallback = { "d.secondary" } },

  -- firstaid
  { id = "d.bandage3", slot = "daily", category = "firstaid", points = 3, text = "Make 3 bandages",
    can = "hasFirstAid", fallback = { "d.secondary" } },
  { id = "d.bandageUp", slot = "daily", category = "firstaid", points = 3, text = "Use a bandage",
    can = "hasFirstAid", fallback = { "d.secondary" } },
  { id = "d.bandage10", slot = "daily", category = "firstaid", points = 3, text = "Make 10 bandages",
    can = "hasFirstAid", fallback = { "d.secondary" } },
  { id = "d.bandageUse3", slot = "daily", category = "firstaid", points = 3, text = "Use 3 bandages",
    can = "hasFirstAid", fallback = { "d.secondary" } },
  { id = "d.bandageFriend", slot = "daily", category = "firstaid", points = 3, text = "Bandage a friend",
    can = "hasFirstAid", fallback = { "d.groupFriend" } },
  { id = "d.aidSkill5", slot = "daily", category = "firstaid", points = 3, text = "Raise First Aid by 5 points",
    can = "hasFirstAid", fallback = { "d.secondary" } },
  { id = "d.bandageKinds2", slot = "daily", category = "firstaid", points = 3, text = "Make 2 kinds of bandages",
    can = "hasFirstAid", fallback = { "d.secondary" } },

  -- play
  { id = "d.chars2", slot = "daily", category = "play", since = 1, points = 1, text = "Play 2 characters",
    can = "chars2", fallback = { "d.quests10" } },
  { id = "d.chars3", slot = "daily", category = "play", points = 3, text = "Play 3 characters",
    can = "chars3", fallback = { "d.chars2" } },
  { id = "d.switchUp", slot = "daily", category = "play", points = 3,
    text = "Play a character not played the day before", can = "chars2", fallback = { "d.quests10" } },
  { id = "d.dustOff", slot = "daily", category = "play", points = 3, text = "Play a character after a week away",
    can = "idle7", fallback = { "d.chars2" } },
  { id = "d.earlyBird", slot = "daily", category = "play", points = 3, text = "Early bird: play before 09:00" },
  { id = "d.nightOwl", slot = "daily", category = "play", points = 3, text = "Night owl: play after 23:00" },
  { id = "d.session1h", slot = "daily", category = "play", points = 5, text = "Play a 1-hour session" },
  { id = "d.deathless", slot = "daily", category = "play", points = 5, text = "Play an hour without dying" },
  { id = "d.jump100", slot = "daily", category = "play", points = 1, text = "Jump 100 times" },

  -- social
  { id = "d.groupFriend", slot = "daily", category = "social", points = 3, text = "Group up with a friend" },
  { id = "d.trade", slot = "daily", category = "social", points = 3, text = "Trade with a friend" },
  { id = "d.questTogether", slot = "daily", category = "social", points = 3,
    text = "Hand in a quest in a group with a friend" },
  { id = "d.chatHello", slot = "daily", category = "social", points = 1, text = "Say something in the community chat" },
  { id = "d.sameZone", slot = "daily", category = "social", points = 3, text = "Be in the same zone as a friend",
    can = "friends1", fallback = { "d.chars2" } },
  { id = "d.online3", slot = "daily", category = "social", points = 3, text = "Be online with 3 friends at once",
    can = "friends3", fallback = { "d.groupFriend" } },
  { id = "d.carry", slot = "daily", category = "social", points = 3, text = "Group with a friend 5+ levels lower" },
  { id = "d.whisper", slot = "daily", category = "social", points = 1, text = "Whisper a friend" },
  { id = "d.wave", slot = "daily", category = "social", points = 1, text = "Wave at a friend" },
  { id = "d.groupPic", slot = "daily", category = "social", points = 1,
    text = "Take a screenshot in a group with a friend" },

  -- exploration
  { id = "d.discover1", slot = "daily", category = "exploration", points = 3, text = "Discover a new place" },
  { id = "d.discover3", slot = "daily", category = "exploration", points = 3, text = "Discover 3 new places" },
  { id = "d.roam4", slot = "daily", category = "exploration", points = 3, text = "Visit 4 zones" },
  { id = "d.newZone", slot = "daily", category = "exploration", points = 3,
    text = "Set foot in a zone new to the character" },
  { id = "d.places10", slot = "daily", category = "exploration", points = 3, text = "Visit 10 places within zones" },
  { id = "d.swim", slot = "daily", category = "exploration", points = 3, text = "Swim for 2 minutes" },
  { id = "d.nostalgia", slot = "daily", category = "exploration", points = 3,
    text = "Visit a zone far below the character's level", can = "level30", fallback = { "d.roam4" } },
  { id = "d.daredevil", slot = "daily", category = "exploration", points = 3,
    text = "Visit a zone above the character's level", can = "below60", fallback = { "d.roam4" } },

  -- travel
  { id = "d.flight", slot = "daily", category = "travel", points = 1, text = "Take a flight" },
  { id = "d.newFlight", slot = "daily", category = "travel", points = 3, text = "Learn a new flight path" },
  { id = "d.hearth", slot = "daily", category = "travel", points = 1, text = "Use the hearthstone" },
  { id = "d.bind", slot = "daily", category = "travel", points = 1, text = "Make a new inn home" },
  { id = "d.ride", slot = "daily", category = "travel", points = 3, text = "Ride a mount for 15 minutes",
    can = "riding", fallback = { "d.roam4" } },
  { id = "d.crossSea", slot = "daily", category = "travel", points = 3, text = "Cross the sea" },
  { id = "d.summoned", slot = "daily", category = "travel", points = 3, text = "Get summoned by a friend" },

  -- combat
  { id = "d.kills30", slot = "daily", category = "combat", points = 3, text = "Defeat 30 enemies",
    can = "below60", fallback = { "d.bosses3" } },
  { id = "d.elite", slot = "daily", category = "combat", points = 3, text = "Defeat an elite",
    can = "below60", fallback = { "d.bosses3" } },
  { id = "d.rareMob", slot = "daily", category = "combat", points = 5, text = "Defeat a rare enemy",
    can = "below60", fallback = { "d.bosses3" } },
  { id = "d.bigFoe", slot = "daily", category = "combat", points = 3, text = "Defeat an enemy 3+ levels higher",
    can = "below60", fallback = { "d.bosses3" } },
  { id = "d.streak20", slot = "daily", category = "combat", points = 5, text = "Defeat 20 enemies without dying",
    can = "below60", fallback = { "d.bosses3" } },
  { id = "d.weaponSkill", slot = "daily", category = "combat", points = 3, text = "Raise a weapon skill 5 times" },
  { id = "d.duoHunt", slot = "daily", category = "combat", points = 3,
    text = "Defeat 15 enemies in a group with a friend", can = "below60", fallback = { "d.dungeonFriend" } },

  -- loot
  { id = "d.rare", slot = "daily", category = "loot", points = 3, text = "Loot a rare item" },
  { id = "d.green5", slot = "daily", category = "loot", points = 3, text = "Loot 5 uncommon items" },
  { id = "d.reward", slot = "daily", category = "loot", points = 3, text = "Earn an uncommon quest reward" },
  { id = "d.coins10", slot = "daily", category = "loot", points = 3, text = "Loot coins from 10 enemies" },
  { id = "d.equipNew", slot = "daily", category = "loot", points = 3, text = "Wear a new find" },
  { id = "d.treasure", slot = "daily", category = "loot", points = 3, text = "Open a treasure chest" },

  -- economy
  { id = "d.vendorSale", slot = "daily", category = "economy", points = 1, text = "Sell to a merchant" },
  { id = "d.vendorBuy", slot = "daily", category = "economy", points = 1, text = "Buy from a merchant" },
  { id = "d.auctionPost", slot = "daily", category = "economy", points = 3, text = "Put an item up for auction" },
  { id = "d.auctionBuy", slot = "daily", category = "economy", points = 3, text = "Buy at the auction house" },
  { id = "d.mailFriend", slot = "daily", category = "economy", points = 1, text = "Send mail to a friend" },
  { id = "d.mailbox", slot = "daily", category = "economy", points = 1, text = "Empty the mailbox" },
  { id = "d.profit", slot = "daily", category = "economy", points = 3, text = "End a session in profit" },

  -- care
  { id = "d.repair", slot = "daily", category = "care", points = 1, text = "Repair gear" },
  { id = "d.trainer", slot = "daily", category = "care", points = 3, text = "Learn a spell at a trainer",
    can = "below60", fallback = { "d.repair" } },
  { id = "d.wellFed", slot = "daily", category = "care", points = 1, text = "Get Well Fed" },
  { id = "d.buffFriend", slot = "daily", category = "care", points = 3, text = "Buff a friend",
    can = "canBuff", fallback = { "d.groupFriend" } },
  { id = "d.restock", slot = "daily", category = "care", points = 1, text = "Restock food or drink" },
  { id = "d.bank", slot = "daily", category = "care", points = 1, text = "Visit the bank" },
  { id = "d.tidyBags", slot = "daily", category = "care", points = 1, text = "Clear the junk from the bags" },
  { id = "d.potion", slot = "daily", category = "care", points = 1, text = "Drink a potion" },
  { id = "d.scrolls10", slot = "daily", category = "care", points = 3, text = "Read 10 scrolls on the own character" },

  { id = "w.days3", slot = "weekly", since = 1, text = "Play on 3 days" },
  { id = "w.days5", slot = "weekly", since = 1, text = "Play on 5 days" },
  { id = "w.chars3", slot = "weekly", since = 1, text = "Play 3 different characters",
    can = "chars3", fallback = { "w.days3" } },
  { id = "w.levels3", slot = "weekly", since = 1, text = "Gain 3 levels",
    can = "below60", fallback = { "w.quests50" } },
  { id = "w.altLevels2", slot = "weekly", since = 1, text = "Gain 2 levels on an alt",
    can = "altBelow60", fallback = { "w.quests50" } },
  { id = "w.quests50", slot = "weekly", since = 1, text = "Finish 50 quests" },
  { id = "w.zones5", slot = "weekly", since = 1, text = "Hand in quests in 5 zones" },
  { id = "w.dungeons3", slot = "weekly", since = 1, text = "Run 3 dungeons",
    can = "dungeonInRange", fallback = { "w.quests50" } },
  { id = "w.dungeonsDiff3", slot = "weekly", since = 1, text = "Run 3 different dungeons",
    can = "dungeonInRange", fallback = { "w.quests50" } },
  { id = "w.dungeonFriends2", slot = "weekly", since = 1, text = "Run a dungeon with 2 friends",
    can = "dungeonInRange", fallback = { "w.quests50" } },
  { id = "w.fullClear", slot = "weekly", since = 1, text = "Clear every boss of a dungeon",
    can = "dungeonInRange", fallback = { "w.quests50" } },
  { id = "w.skill25", slot = "weekly", since = 1, text = "Earn 25 profession skill points",
    can = "hasProfession", fallback = { "w.quests50" } },
  { id = "w.cap", slot = "weekly", since = 1, text = "Reach a profession cap",
    can = "professionBelow300", fallback = { "w.skill25", "w.quests50" } },
  { id = "w.newProf", slot = "weekly", since = 1, text = "Learn a new profession" },
  { id = "w.ilvl3", slot = "weekly", since = 1, text = "Raise an item level by 3",
    can = "ilvlReadable", fallback = { "w.quests50" } },
  { id = "w.friends3", slot = "weekly", text = "Group with 3 different friends" },
  { id = "w.rare5", slot = "weekly", text = "Loot 5 rare items" },
  { id = "w.session2h", slot = "weekly", text = "Play a 2-hour session" },
  { id = "w.discover5", slot = "weekly", text = "Discover 5 new places" },
  { id = "w.craftTrade", slot = "weekly", text = "Craft something and trade it",
    can = "hasCraftingProfession", fallback = { "w.quests50" } },

  { id = "p.frontLine", slot = "skirmish", since = 1, text = "Front line: 5 kills in the zone of the day",
    can = "level20", fallback = { "p.loneWolf" } },
  { id = "p.punchUp", slot = "skirmish", text = "Punch up: 2 kills on players 3+ levels above you" },
  { id = "p.loneWolf", slot = "skirmish", since = 1, text = "Lone wolf: 3 solo kills" },
  { id = "p.untouchable", slot = "skirmish", since = 1, text = "Untouchable: 5 kills without dying" },
  { id = "p.variety", slot = "skirmish", text = "Variety: kills of 3 different classes" },
  { id = "p.ranked", slot = "skirmish", text = "Ranked bounty: kill a ranked player" },
  { id = "p.flex", slot = "skirmish", category = "emote", points = 1, text = "Flex at a player of the other faction" },
  { id = "p.boo", slot = "skirmish", category = "emote", points = 1, text = "Boo a player of the other faction" },
  { id = "p.punchUp5", slot = "skirmish", category = "kill", points = 5,
    text = "Kill an enemy player 5+ levels higher" },
  { id = "p.punchDown5", slot = "skirmish", category = "kill", points = 3,
    text = "Kill an enemy player 5+ levels lower" },

  { id = "b.zone25", slot = "bounty", since = 1, text = "25 kills in the zone of the week" },
  { id = "b.allClasses", slot = "bounty", text = "A kill of every enemy class" },
  { id = "b.allRaces", slot = "bounty", text = "A kill of every enemy race" },
  { id = "b.ranked5", slot = "bounty", text = "5 kills on ranked players" },
  { id = "b.kills50", slot = "bounty", since = 1, text = "50 counted kills" },
  { id = "b.spree10", slot = "bounty", since = 1, text = "A spree of 10" },
  { id = "b.hunt3", slot = "bounty", text = "The Hunt done on 3 days" },
  { id = "b.duels3", slot = "bounty", since = 1, text = "Duels with 3 different friends" },
  { id = "b.days5", slot = "bounty", since = 1, text = "Kills on 5 days" },
}

-- CF-61: each goal's column title on the Board, at most 10 characters; the site uses the same (DOOMSDAY.md).
Doomsday.SHORT_LABELS = {
  ["d.quests10"] = "10 quests", ["d.quests20"] = "20 quests", ["d.zone5"] = "5 in zone", ["d.zones3"] = "3 zones",
  ["d.shared3"] = "3 shared", ["d.questUp"] = "Hard quest", ["d.groupQuest"] = "Group Q", ["d.classQuest"] = "Class Q",
  ["d.questBurst"] = "Quick 3", ["d.accept5"] = "Take 5", ["d.level"] = "Level", ["d.altLevel"] = "Alt level",
  ["d.ilvl"] = "Item level", ["d.cleanLevel"] = "Clean lvl", ["d.levels2"] = "2 levels",
  ["d.dingDungeon"] = "Deep ding", ["d.dingFriend"] = "Duo ding", ["d.lowbie"] = "Lowbie", ["d.dungeon"] = "Dungeon",
  ["d.dungeonFriend"] = "Group run", ["d.bosses3"] = "3 bosses", ["d.dungeonQuest"] = "Dungeon Q",
  ["d.cleanRun"] = "Clean run", ["d.speedRun"] = "Speed run", ["d.newDungeon"] = "Fresh run",
  ["d.dungeons2"] = "2 dungeons", ["d.skill5"] = "Skills", ["d.secondary"] = "Secondary", ["d.craft5"] = "Craft 5",
  ["d.gather10"] = "Gather 10", ["d.newRecipe"] = "Recipe", ["d.craftGreen"] = "Fine craft", ["d.cook5"] = "Cook 5",
  ["d.cook15"] = "Cook 15", ["d.cookSkill5"] = "Cooking +5", ["d.cookKinds3"] = "3 dishes",
  ["d.campfire"] = "Campfire", ["d.campfireBuff"] = "Cozy fire", ["d.eatOwn"] = "Home meal",
  ["d.cookRecipe"] = "New dish", ["d.feedFriend"] = "Feed pal", ["d.fish20"] = "20 fish",
  ["d.fishZones"] = "Fish spots", ["d.fish50"] = "50 fish", ["d.fishSkill5"] = "Fishing +5",
  ["d.fishKinds3"] = "Fish kinds", ["d.fishFriend"] = "Fish buddy", ["d.fishNight"] = "Night fish",
  ["d.bandage3"] = "Bandages", ["d.bandageUp"] = "Bandage up", ["d.bandage10"] = "10 bandage",
  ["d.bandageUse3"] = "Bandage x3", ["d.bandageFriend"] = "Medic", ["d.aidSkill5"] = "Aid +5",
  ["d.bandageKinds2"] = "2 bandages", ["d.chars2"] = "2 chars", ["d.chars3"] = "Play 3", ["d.switchUp"] = "Switch up",
  ["d.dustOff"] = "Dust off", ["d.earlyBird"] = "Early bird", ["d.nightOwl"] = "Night owl",
  ["d.session1h"] = "1h session", ["d.deathless"] = "No deaths", ["d.jump100"] = "100 jumps",
  ["d.groupFriend"] = "Group up", ["d.trade"] = "Trade", ["d.questTogether"] = "Duo quest", ["d.chatHello"] = "Chat",
  ["d.sameZone"] = "Neighbours", ["d.online3"] = "Full house", ["d.carry"] = "Carry", ["d.whisper"] = "Whisper",
  ["d.wave"] = "Wave", ["d.groupPic"] = "Group pic", ["d.discover1"] = "Discover", ["d.discover3"] = "Discover 3",
  ["d.roam4"] = "Roam 4", ["d.newZone"] = "New zone", ["d.places10"] = "10 places", ["d.swim"] = "Swim",
  ["d.nostalgia"] = "Nostalgia", ["d.daredevil"] = "Daredevil", ["d.flight"] = "Fly", ["d.newFlight"] = "New flight",
  ["d.hearth"] = "Hearth", ["d.bind"] = "New home", ["d.ride"] = "Ride", ["d.crossSea"] = "Cross sea",
  ["d.summoned"] = "Summoned", ["d.kills30"] = "30 foes", ["d.elite"] = "Elite", ["d.rareMob"] = "Rare hunt",
  ["d.bigFoe"] = "Big foe", ["d.streak20"] = "Streak 20", ["d.weaponSkill"] = "Weapon +5", ["d.duoHunt"] = "Duo hunt",
  ["d.rare"] = "Rare loot", ["d.green5"] = "5 greens", ["d.reward"] = "Reward", ["d.coins10"] = "10 purses",
  ["d.equipNew"] = "New gear", ["d.treasure"] = "Treasure", ["d.vendorSale"] = "Sell", ["d.vendorBuy"] = "Shopping",
  ["d.auctionPost"] = "Auction", ["d.auctionBuy"] = "Bargain", ["d.mailFriend"] = "Mail pal",
  ["d.mailbox"] = "Mailbox", ["d.profit"] = "In profit", ["d.repair"] = "Repair", ["d.trainer"] = "Train",
  ["d.wellFed"] = "Well fed", ["d.buffFriend"] = "Buff pal", ["d.restock"] = "Restock", ["d.bank"] = "Bank",
  ["d.tidyBags"] = "Tidy bags", ["d.potion"] = "Potion", ["d.scrolls10"] = "10 scrolls", ["w.days3"] = "3 days",
  ["w.days5"] = "5 days", ["w.chars3"] = "3 chars", ["w.levels3"] = "3 levels", ["w.altLevels2"] = "Alt 2 lvls",
  ["w.quests50"] = "50 quests", ["w.zones5"] = "5 zones", ["w.dungeons3"] = "3 dungeons",
  ["w.dungeonsDiff3"] = "3 distinct", ["w.dungeonFriends2"] = "Trio run", ["w.fullClear"] = "Full clear",
  ["w.skill25"] = "25 skill", ["w.cap"] = "Skill cap", ["w.newProf"] = "New prof", ["w.ilvl3"] = "Item lvl+3",
  ["w.friends3"] = "3 friends", ["w.rare5"] = "5 rares", ["w.session2h"] = "2h session",
  ["w.discover5"] = "Discover 5", ["w.craftTrade"] = "Craft gift", ["p.frontLine"] = "Front line",
  ["p.punchUp"] = "Punch up", ["p.loneWolf"] = "Lone wolf", ["p.untouchable"] = "Untouched", ["p.variety"] = "Variety",
  ["p.ranked"] = "Ranked", ["p.flex"] = "Flex", ["p.boo"] = "Boo", ["p.punchUp5"] = "Punch up 5",
  ["p.punchDown5"] = "Punch down", ["b.zone25"] = "Zone 25", ["b.allClasses"] = "Classes", ["b.allRaces"] = "Races",
  ["b.ranked5"] = "5 ranked", ["b.kills50"] = "50 kills", ["b.spree10"] = "Spree 10", ["b.hunt3"] = "3 hunts",
  ["b.duels3"] = "3 duels", ["b.days5"] = "Kill days",
}

Doomsday.GOALS = GOALS
local BY_ID = {}
for i, g in ipairs(GOALS) do
  g.order = i
  g.shortLabel = Doomsday.SHORT_LABELS[g.id]
  BY_ID[g.id] = g
end

-- The Hunt joins with the pool version that verifies victim race and class (CF-54); nil: not yet.
Doomsday.HUNT_SINCE = nil

function Doomsday.goal(id) return BY_ID[id] end

-- The active goals of a slot in pool order, for a pool version (default the current one).
function Doomsday.pool(slot, version)
  version = version or Doomsday.POOL_VERSION
  local list = {}
  for _, g in ipairs(GOALS) do
    if g.slot == slot and g.since and g.since <= version and not g.retired then list[#list + 1] = g.id end
  end
  return list
end

-- ===== Lists =====

-- Enemy race and class combinations, by the hunting character's faction (race token as UnitRace gives it).
local COMBOS = {
  Horde = { -- hunts Alliance
    { "Human", { "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "MAGE", "WARLOCK" } },
    { "Dwarf", { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST" } },
    { "NightElf", { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "DRUID" } },
    { "Gnome", { "WARRIOR", "ROGUE", "MAGE", "WARLOCK" } },
  },
  Alliance = { -- hunts Horde
    { "Orc", { "WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "WARLOCK" } },
    { "Scourge", { "WARRIOR", "ROGUE", "PRIEST", "MAGE", "WARLOCK" } },
    { "Tauren", { "WARRIOR", "HUNTER", "SHAMAN", "DRUID" } },
    { "Troll", { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE" } },
  },
}

-- { { race, class }, ... } a faction hunts, in list order (20 each).
function Doomsday.combos(faction)
  local list = {}
  for _, entry in ipairs(COMBOS[faction] or {}) do
    for _, class in ipairs(entry[2]) do list[#list + 1] = { race = entry[1], class = class } end
  end
  return list
end

Doomsday.ENEMY_CLASSES = {
  Horde = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "MAGE", "WARLOCK", "DRUID" },
  Alliance = { "WARRIOR", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
}
Doomsday.ENEMY_RACES = { Horde = { "Human", "Dwarf", "NightElf", "Gnome" },
                         Alliance = { "Orc", "Scourge", "Tauren", "Troll" } }

-- Zone bands by the level of the friend's highest character (the zone names as the feed stores them).
Doomsday.BANDS = {
  { min = 20, max = 29, zones = { "Hillsbrad Foothills", "Ashenvale", "Stonetalon Mountains" } },
  { min = 30, max = 44, zones = { "Stranglethorn Vale", "Arathi Highlands", "Desolace", "Dustwallow Marsh",
                                  "Alterac Mountains" } },
  { min = 45, max = 54, zones = { "Tanaris", "Feralas", "The Hinterlands", "Searing Gorge", "Un'Goro Crater",
                                  "Azshara" } },
  { min = 55, max = 60, zones = { "Burning Steppes", "Felwood", "Winterspring", "Eastern Plaguelands",
                                  "Western Plaguelands", "Silithus" } },
}

local function band(level)
  for _, b in ipairs(Doomsday.BANDS) do
    if type(level) == "number" and level >= b.min and level <= b.max then return b end
  end
  return nil
end

-- The zone of the day (salt 4) or of the week (salt 5) for a character level, or nil below 20.
function Doomsday.zone(n, salt, level)
  local b = band(level)
  return b and b.zones[Doomsday.pick(n, salt, #b.zones)] or nil
end

-- ===== The draw =====

-- Salts per slot (DOOMSDAY.md: a salt per slot).
local SALT = { hunt = 1, skirmish = 2, bounty = 3, dailies = { 11, 12, 13 }, weeklies = { 21, 22, 23 } }
Doomsday.SALT = SALT

local function without(list, excluded)
  local result = {}
  for _, item in ipairs(list) do
    if not excluded[item] then result[#result + 1] = item end
  end
  return result
end

local function asSet(list)
  local set = {}
  for _, item in ipairs(list or {}) do set[item] = true end
  return set
end

-- One goal from a pool for n and salt, not one of `previous` (unless nothing else is left).
local function drawOne(pool, n, salt, previous)
  if #pool == 0 then return nil end
  local available = without(pool, asSet(previous))
  if #available == 0 then available = pool end
  return available[Doomsday.pick(n, salt, #available)]
end

-- Three PvE dailies of different categories, none of `previous` while enough are left.
local function drawDailies(pool, n, previous)
  local chosen, categories = {}, {}
  local excluded = asSet(previous)
  for slot = 1, 3 do
    local function candidates(skipPrevious)
      local list = {}
      for _, id in ipairs(pool) do
        local g = BY_ID[id]
        if not categories[g.category] and not (skipPrevious and excluded[id]) then list[#list + 1] = id end
      end
      return list
    end
    local list = candidates(true)
    if #list == 0 then list = candidates(false) end
    if #list == 0 then break end
    local id = list[Doomsday.pick(n, SALT.dailies[slot], #list)]
    chosen[#chosen + 1] = id
    categories[BY_ID[id].category] = true
  end
  return chosen
end

-- Three PvE weeklies, none of `previous` while enough are left.
local function drawWeeklies(pool, week, previous)
  local chosen, taken = {}, {}
  local excluded = asSet(previous)
  for slot = 1, 3 do
    local list = {}
    for _, id in ipairs(pool) do
      if not taken[id] and not excluded[id] then list[#list + 1] = id end
    end
    if #list == 0 then
      for _, id in ipairs(pool) do
        if not taken[id] then list[#list + 1] = id end
      end
    end
    if #list == 0 then break end
    local id = list[Doomsday.pick(week, SALT.weeklies[slot], #list)]
    chosen[#chosen + 1] = id
    taken[id] = true
  end
  return chosen
end

local function comboKey(c) return c.race .. ":" .. c.class end

local function drawHunt(faction, n, previous)
  local keys = {}
  for i, c in ipairs(Doomsday.combos(faction)) do keys[i] = comboKey(c) end
  local key = drawOne(keys, n, SALT.hunt, previous and { previous } or nil)
  if not key then return nil end
  local race, class = key:match("^(.-):(.+)$")
  return { race = race, class = class }
end

local dayCache, weekCache = {}, {}

--[[ The day's draw, the same for everyone (before swaps): { dailies = { id, id, id }, skirmish = id,
hunt = { Horde = { race, class }, Alliance = { race, class } } } (hunt nil until Doomsday.HUNT_SINCE).
Days from EPOCH on never repeat the previous day's goals (and Hunt combination): the draw runs forward
from EPOCH, each day excluding the day before. Days before EPOCH exclude nothing. ]]
function Doomsday.draw(n, version)
  version = version or Doomsday.POOL_VERSION
  local huntOn = Doomsday.HUNT_SINCE ~= nil and Doomsday.HUNT_SINCE <= version
  local prefix = version .. (huntOn and "h:" or ":")
  local key = prefix .. n
  if dayCache[key] then return dayCache[key] end
  local dailyPool, skirmishPool = Doomsday.pool("daily", version), Doomsday.pool("skirmish", version)
  local first = n < Doomsday.EPOCH and n or Doomsday.EPOCH
  local previous
  for day = first, n do
    local k = prefix .. day
    local result = dayCache[k]
    if not result then
      local prev = previous or { dailies = {} }
      result = { dailies = drawDailies(dailyPool, day, prev.dailies),
                 skirmish = drawOne(skirmishPool, day, SALT.skirmish, prev.skirmish and { prev.skirmish }) }
      if huntOn then
        local before = prev.hunt or {}
        result.hunt = { Horde = drawHunt("Horde", day, before.Horde and comboKey(before.Horde)),
                        Alliance = drawHunt("Alliance", day, before.Alliance and comboKey(before.Alliance)) }
      end
      dayCache[k] = result
    end
    previous = result
  end
  return dayCache[key]
end

-- The week's draw before swaps: { weeklies = { id, id, id }, bounty = id }. As Doomsday.draw, per week.
function Doomsday.drawWeek(week, version)
  version = version or Doomsday.POOL_VERSION
  local key = version .. ":" .. week
  if weekCache[key] then return weekCache[key] end
  local weeklyPool, bountyPool = Doomsday.pool("weekly", version), Doomsday.pool("bounty", version)
  local epochWeek = Doomsday.week(Doomsday.EPOCH)
  local first = week < epochWeek and week or epochWeek
  local previous
  for w = first, week do
    local k = version .. ":" .. w
    local result = weekCache[k]
    if not result then
      local prev = previous or { weeklies = {} }
      result = { weeklies = drawWeeklies(weeklyPool, w, prev.weeklies),
                 bounty = drawOne(bountyPool, w, SALT.bounty, prev.bounty and { prev.bounty }) }
      weekCache[k] = result
    end
    previous = result
  end
  return weekCache[key]
end

-- The Hunt's combination for one faction of hunter on day n, or nil.
function Doomsday.hunt(n, faction, version)
  local draw = Doomsday.draw(n, version)
  return draw.hunt and draw.hunt[faction] or nil
end

-- ===== The schedule from the site (CF-68) =====

-- A scheduled list (dailies, weeklies) when all its ids are active goals of that slot, else the normal draw's.
local function overlayList(base, scheduled, slot, version)
  if type(scheduled) ~= "table" or #scheduled ~= 3 then return base end
  local active = asSet(Doomsday.pool(slot, version))
  for _, id in ipairs(scheduled) do
    if not active[id] then return base end
  end
  return { scheduled[1], scheduled[2], scheduled[3] }
end

local function overlayOne(base, scheduled, slot, version)
  if scheduled ~= nil and asSet(Doomsday.pool(slot, version))[scheduled] then return scheduled end
  return base
end

--[[ The day's draw with the site's schedule on top (Goals.cleanMissionSchedule's shape; nil: none): a listed
`daily` is used when all 3 ids are in this pool version, a listed `skirmish` when it is; every other slot is the
normal draw's. The normal draw (and its "never twice in a row" chain) is never changed by it. The Hunt is always
the normal draw's (the schedule has no Hunt yet). ]]
function Doomsday.scheduledDraw(n, schedule, version)
  local draw = Doomsday.draw(n, version)
  local e = type(schedule) == "table" and type(schedule.days) == "table" and schedule.days[tostring(n)]
  if type(e) ~= "table" then return draw end
  return { dailies = overlayList(draw.dailies, e.daily, "daily", version),
           skirmish = overlayOne(draw.skirmish, e.skirmish, "skirmish", version), hunt = draw.hunt }
end

-- The week's draw with the site's schedule on top. As Doomsday.scheduledDraw, with `weekly` and `bounty`.
function Doomsday.scheduledWeek(week, schedule, version)
  local draw = Doomsday.drawWeek(week, version)
  local e = type(schedule) == "table" and type(schedule.weeks) == "table" and schedule.weeks[tostring(week)]
  if type(e) ~= "table" then return draw end
  return { weeklies = overlayList(draw.weeklies, e.weekly, "weekly", version),
           bounty = overlayOne(draw.bounty, e.bounty, "bounty", version) }
end

-- ===== Swaps =====

--[[ situation (one friend, over all their characters): { chars, below60, altBelow60, highest, highestToday,
ilvlReadable, dungeonInRange, hasProfession, hasFishing, hasCraftingProfession, professionBelow300,
friendQuestLog, below20, hasCooking, hasFirstAid, hasGathering, riding, friends, canBuff, idle7 }. chars: number
of characters; below60, below20: characters below 60, below 20; altBelow60: characters below 60 other than the
highest one; highest: the highest level; highestToday: the highest level that played that day (nil: none yet);
friends: other friends in the community; idle7: characters not played for 7 days or more; the rest booleans
(riding: a character with riding; canBuff: a character of a class with a buff it can cast on others). A missing
field counts as "can do" (unknown never swaps). ]]
local function atLeast(value, n) return value == nil or value >= n end

local CAN = {
  friendQuestLog = function(s) return s.friendQuestLog ~= false end,
  below60 = function(s) return s.below60 == nil or s.below60 > 0 end,
  below60Dungeon = function(s) return (s.below60 == nil or s.below60 > 0) and s.dungeonInRange ~= false end,
  below20 = function(s) return s.below20 == nil or s.below20 > 0 end,
  -- Any profession, secondary ones included.
  anyProfession = function(s)
    return s.hasProfession ~= false or s.hasCooking ~= false or s.hasFirstAid ~= false or s.hasFishing ~= false
  end,
  hasCooking = function(s) return s.hasCooking ~= false end,
  hasFirstAid = function(s) return s.hasFirstAid ~= false end,
  hasGathering = function(s) return s.hasGathering ~= false end,
  riding = function(s) return s.riding ~= false end,
  canBuff = function(s) return s.canBuff ~= false end,
  friends1 = function(s) return atLeast(s.friends, 1) end,
  friends3 = function(s) return atLeast(s.friends, 3) end,
  idle7 = function(s) return atLeast(s.idle7, 1) end,
  level30 = function(s) return atLeast(s.highest, 30) end,
  altBelow60 = function(s) return s.altBelow60 == nil or s.altBelow60 > 0 end,
  ilvlReadable = function(s) return s.ilvlReadable ~= false end,
  dungeonInRange = function(s) return s.dungeonInRange ~= false end,
  hasProfession = function(s) return s.hasProfession ~= false end,
  hasFishing = function(s) return s.hasFishing ~= false end,
  hasCraftingProfession = function(s) return s.hasCraftingProfession ~= false end,
  professionBelow300 = function(s) return s.professionBelow300 ~= false end,
  chars2 = function(s) return s.chars == nil or s.chars >= 2 end,
  chars3 = function(s) return s.chars == nil or s.chars >= 3 end,
  level20 = function(s)
    local level = s.highestToday or s.highest
    return level == nil or level >= 20
  end,
}

-- Whether a friend in this situation can do a goal.
function Doomsday.canDo(id, situation)
  local g = BY_ID[id]
  if not g or not g.can then return g ~= nil end
  return CAN[g.can](situation or {})
end

-- The replacement for a goal that can't be done: its fallbacks in order, then the next goals in pool order
-- (wrapping), skipping goals in `taken` and goals that can't be done. nil when nothing fits.
local function replacement(id, situation, taken, version)
  local g = BY_ID[id]
  for _, f in ipairs(g.fallback or {}) do
    if not taken[f] and Doomsday.canDo(f, situation) then return f end
  end
  local pool = Doomsday.pool(g.slot, version)
  local start = 0
  for i, p in ipairs(pool) do
    if p == id then start = i end
  end
  for step = 1, #pool do
    local candidate = pool[(start + step - 1) % #pool + 1]
    if not taken[candidate] and candidate ~= id and Doomsday.canDo(candidate, situation) then return candidate end
  end
  return nil
end

local function swapList(list, situation, swapped, version)
  local taken = asSet(list)
  local result = {}
  for i, id in ipairs(list) do
    if Doomsday.canDo(id, situation) then
      result[i] = id
    else
      local new = replacement(id, situation, taken, version)
      if new then
        taken[new] = true
        swapped[new] = id
      end
      result[i] = new or id -- nothing fits: the original stays
    end
  end
  return result
end

--[[ One friend's goals for day n: { set = { id, ... }, swapped = { [newId] = originalId }, zone, hunt }.
set: the 3 PvE dailies, then the Skirmish. zone: the zone of the day (p.frontLine) for that friend's highest
character that played that day (else the highest). hunt: the draw's Hunt (both factions). schedule (CF-68,
optional): the site's schedule, put on the draw before the swaps (Doomsday.scheduledDraw). ]]
function Doomsday.goalsForDay(n, situation, version, schedule)
  situation = situation or {}
  local draw = Doomsday.scheduledDraw(n, schedule, version)
  local swapped = {}
  local list = {}
  for _, id in ipairs(draw.dailies) do list[#list + 1] = id end
  local set = swapList(list, situation, swapped, version)
  if draw.skirmish then
    set[#set + 1] = swapList({ draw.skirmish }, situation, swapped, version)[1]
  end
  return { set = set, swapped = swapped, hunt = draw.hunt,
           zone = Doomsday.zone(n, 4, situation.highestToday or situation.highest) }
end

-- One friend's goals for a week: { set = { weekly, weekly, weekly, bounty }, swapped, zone }. schedule as above.
function Doomsday.goalsForWeek(week, situation, version, schedule)
  situation = situation or {}
  local draw = Doomsday.scheduledWeek(week, schedule, version)
  local swapped = {}
  local set = swapList(draw.weeklies, situation, swapped, version)
  if draw.bounty then set[#set + 1] = swapList({ draw.bounty }, situation, swapped, version)[1] end
  return { set = set, swapped = swapped, zone = Doomsday.zone(week, 5, situation.highest) }
end

-- ===== Kill points =====

--[[ Points of one counted kill: victim level `lvl` (-1 skull, nil unknown) against your level `myLvl`. ]]
function Doomsday.killValue(kill)
  local lvl, my = kill.lvl, kill.myLvl
  local points
  if lvl == -1 then
    points = 3
  elseif type(lvl) ~= "number" or type(my) ~= "number" then
    points = 1
  else
    local diff = lvl - my
    if diff <= -4 then points = 0 elseif diff >= 3 then points = 2 else points = 1 end
  end
  if kill.solo == true and points > 0 then points = points + 1 end
  return points
end

--[[ Scores one friend's kills (pvpKills of all their characters): each kill gets
{ counted, points, track = "pvp"|"bg", day, reason } in a new list, in time order.
schedule = { offset, reset }; community = { [full name] = true } (characters of the selected community).
Not counted: a victim of the community ("community"), the 4th and later kill of the same victim name that
day ("repeat"). Battleground kills (bg) follow the same rules on their own track. ]]
function Doomsday.scoreKills(kills, schedule, community)
  schedule, community = schedule or {}, community or {}
  local sorted = {}
  for i, k in ipairs(kills or {}) do sorted[i] = { kill = k, index = i } end
  table.sort(sorted, function(a, b)
    if (a.kill.t or 0) ~= (b.kill.t or 0) then return (a.kill.t or 0) < (b.kill.t or 0) end
    return a.index < b.index
  end)
  local seen, result = {}, {}
  for _, entry in ipairs(sorted) do
    local k = entry.kill
    local day = Doomsday.day(k.t or 0, schedule.offset, schedule.reset)
    local track = k.bg == true and "bg" or "pvp"
    local scored = { kill = k, day = day, track = track, counted = false, points = 0 }
    if type(k.name) == "string" and community[k.name] then
      scored.reason = "community"
    else
      local key = track .. ":" .. day .. ":" .. tostring(k.name)
      seen[key] = (seen[key] or 0) + 1
      if k.name ~= nil and seen[key] > Doomsday.SAME_VICTIM_LIMIT then
        scored.reason = "repeat"
      else
        scored.counted = true
        scored.points = Doomsday.killValue(k)
      end
    end
    result[#result + 1] = scored
  end
  return result
end

-- ===== Duels =====

--[[ The Duel slot: duels = { { friend, t, won, vs } } from every friend's records (vs: the opponent's full
character name); owner = { [full name] = friend } for the community characters of friends. Per day and pair
of friends the first duel of the day counts once: the earliest record of each side. Both sides agree: the
winner gets 3, the loser 1. They disagree: it counts for neither (disputed). One side only: as recorded.
Returns { points = { [friend] = n }, duels = { { day, a, b, winner, disputed } } } sorted by day, a, b. ]]
function Doomsday.duels(duels, owner, schedule)
  schedule, owner = schedule or {}, owner or {}
  local pairs_ = {}
  for _, d in ipairs(duels or {}) do
    local other = type(d.vs) == "string" and owner[d.vs]
    if other and d.friend and other ~= d.friend and type(d.t) == "number" and type(d.won) == "boolean" then
      local day = Doomsday.day(d.t, schedule.offset, schedule.reset)
      local a, b = d.friend, other
      if b < a then a, b = b, a end
      local key = day .. "\001" .. a .. "\001" .. b
      local p = pairs_[key]
      if not p then
        p = { day = day, a = a, b = b, first = {} }
        pairs_[key] = p
      end
      local mine = p.first[d.friend]
      if not mine or d.t < mine.t then p.first[d.friend] = d end
    end
  end
  local list, points = {}, {}
  for _, p in pairs(pairs_) do
    local ra, rb = p.first[p.a], p.first[p.b]
    -- Each record as "a won": nil when that side has no record.
    local aWonByA = ra and ra.won
    local aWonByB = rb and not rb.won
    local winner, disputed
    if ra and rb and aWonByA ~= aWonByB then
      disputed = true
    else
      local aWon
      if ra then aWon = aWonByA else aWon = aWonByB end
      winner = aWon and p.a or p.b
      local loser = aWon and p.b or p.a
      points[winner] = (points[winner] or 0) + Doomsday.POINTS.duelWin
      points[loser] = (points[loser] or 0) + Doomsday.POINTS.duelLoss
    end
    list[#list + 1] = { day = p.day, a = p.a, b = p.b, winner = winner, disputed = disputed or false }
  end
  table.sort(list, function(x, y)
    if x.day ~= y.day then return x.day < y.day end
    if x.a ~= y.a then return x.a < y.a end
    return x.b < y.b
  end)
  return { points = points, duels = list }
end

-- ===== Goal progress (addon only: the site stores `done` from the addon) =====

local function sum(map)
  local total = 0
  for _, n in pairs(map or {}) do total = total + n end
  return total
end

local function maxOf(map)
  local best = 0
  for _, n in pairs(map or {}) do best = math.max(best, n) end
  return best
end

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function runs(facts, test)
  local n = 0
  for _, r in ipairs(facts.runs or {}) do
    if not test or test(r) then n = n + 1 end
  end
  return n
end

-- Counted kills of the scored list (Doomsday.scoreKills) on the PvP track, optionally filtered.
local function counted(facts, test)
  local n = 0
  for _, s in ipairs(facts.scored or {}) do
    if s.counted and s.track == "pvp" and (not test or test(s.kill)) then n = n + 1 end
  end
  return n
end

local function distinct(facts, field)
  local seen = {}
  for _, s in ipairs(facts.scored or {}) do
    local value = s.kill[field]
    if s.counted and s.track == "pvp" and value ~= nil then seen[value] = true end
  end
  return seen
end

-- The longest run of counted PvP kills on one character with no death of that character in between.
local function spree(facts)
  local events = {}
  for _, s in ipairs(facts.scored or {}) do
    if s.counted and s.track == "pvp" then
      events[#events + 1] = { t = s.kill.t or 0, char = s.kill.char or "", kill = true }
    end
  end
  for _, d in ipairs(facts.deaths or {}) do events[#events + 1] = { t = d.t or 0, char = d.char or "" } end
  table.sort(events, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    return (a.kill and 1 or 0) < (b.kill and 1 or 0) -- a death at the same second ends the run first
  end)
  local current, best = {}, 0
  for _, e in ipairs(events) do
    if e.kill then
      current[e.char] = (current[e.char] or 0) + 1
      best = math.max(best, current[e.char])
    else
      current[e.char] = 0
    end
  end
  return best
end

local function allOf(list, seen)
  local n = 0
  for _, v in ipairs(list or {}) do
    if seen[v] then n = n + 1 end
  end
  return n
end

-- The best count of an enemy list over the friend's factions (either faction's full list counts).
local function enemyProgress(facts, lists, field)
  local seen, best, target = distinct(facts, field), 0, nil
  for _, faction in ipairs(facts.factions or { "Horde" }) do
    local list = lists[faction]
    if list then
      local n = allOf(list, seen)
      if not target or n / #list > best / target then best, target = n, #list end
    end
  end
  return best, target or 8
end

local function bool(value) return value and 1 or 0 end

--[[ Progress of each goal from facts: value, target. facts are summed over the friend's own characters for a
Doomsday day (dailies) or week (weeklies):
  quests = { [zone] = n }, sharedMax, levels, altLevels, altLevelsMax (week: the most on one alt),
  cleanLevels, ilvlGain (the most on one character), runs = { { name, bosses, friends, fullClear } },
  skill, secondary (bool), learned, capReached (bool), chars, days, groupFriends, trades, rare, earlyBird (bool),
  fish, longestSession (seconds), discoveries, craftTrade,
  scored = Doomsday.scoreKills(...), deaths = { { t, char } }, zone (of the day or week), hunts = { { race,
  class } } (the day's Hunt per faction), huntDays, duelFriends, killDays, factions = { "Horde", ... } ]]
local PROGRESS = {
  ["d.quests10"] = function(f) return sum(f.quests), 10 end,
  ["d.quests20"] = function(f) return sum(f.quests), 20 end,
  ["d.zone5"] = function(f) return maxOf(f.quests), 5 end,
  ["d.zones3"] = function(f) return count(f.quests), 3 end,
  ["d.shared3"] = function(f) return f.sharedMax or 0, 3 end,
  ["d.level"] = function(f) return f.levels or 0, 1 end,
  ["d.altLevel"] = function(f) return f.altLevels or 0, 1 end,
  ["d.ilvl"] = function(f) return f.ilvlGain or 0, 1 end,
  ["d.cleanLevel"] = function(f) return f.cleanLevels or 0, 1 end,
  ["d.dungeon"] = function(f) return runs(f), 1 end,
  ["d.dungeonFriend"] = function(f) return runs(f, function(r) return (r.friends or 0) >= 1 end), 1 end,
  ["d.bosses3"] = function(f)
    local n = 0
    for _, r in ipairs(f.runs or {}) do n = n + (r.bosses or 0) end
    return n, 3
  end,
  ["d.skill5"] = function(f) return f.skill or 0, 5 end,
  ["d.secondary"] = function(f) return bool(f.secondary), 1 end,
  ["d.fish20"] = function(f) return f.fish or 0, 20 end,
  ["d.chars2"] = function(f) return f.chars or 0, 2 end,
  ["d.groupFriend"] = function(f) return f.groupFriends or 0, 1 end,
  ["d.trade"] = function(f) return f.trades or 0, 1 end,
  ["d.rare"] = function(f) return f.rare or 0, 1 end,
  ["d.earlyBird"] = function(f) return bool(f.earlyBird), 1 end,

  ["w.days3"] = function(f) return f.days or 0, 3 end,
  ["w.days5"] = function(f) return f.days or 0, 5 end,
  ["w.chars3"] = function(f) return f.chars or 0, 3 end,
  ["w.levels3"] = function(f) return f.levels or 0, 3 end,
  ["w.altLevels2"] = function(f) return f.altLevelsMax or 0, 2 end,
  ["w.quests50"] = function(f) return sum(f.quests), 50 end,
  ["w.zones5"] = function(f) return count(f.quests), 5 end,
  ["w.dungeons3"] = function(f) return runs(f), 3 end,
  ["w.dungeonsDiff3"] = function(f)
    local names = {}
    for _, r in ipairs(f.runs or {}) do names[r.name or ""] = true end
    return count(names), 3
  end,
  ["w.dungeonFriends2"] = function(f)
    local best = 0
    for _, r in ipairs(f.runs or {}) do best = math.max(best, r.friends or 0) end
    return math.min(best, 2), 2
  end,
  ["w.fullClear"] = function(f) return runs(f, function(r) return r.fullClear == true end) > 0 and 1 or 0, 1 end,
  ["w.skill25"] = function(f) return f.skill or 0, 25 end,
  ["w.cap"] = function(f) return bool(f.capReached), 1 end,
  ["w.newProf"] = function(f) return f.learned or 0, 1 end,
  ["w.ilvl3"] = function(f) return f.ilvlGain or 0, 3 end,
  ["w.friends3"] = function(f) return f.groupFriends or 0, 3 end,
  ["w.rare5"] = function(f) return f.rare or 0, 5 end,
  ["w.session2h"] = function(f) return f.longestSession or 0, 7200 end,
  ["w.discover5"] = function(f) return f.discoveries or 0, 5 end,
  ["w.craftTrade"] = function(f) return f.craftTrade or 0, 1 end,

  ["p.frontLine"] = function(f) return counted(f, function(k) return f.zone ~= nil and k.zone == f.zone end), 5 end,
  ["p.punchUp"] = function(f)
    return counted(f, function(k)
      return k.lvl == -1 or (type(k.lvl) == "number" and type(k.myLvl) == "number" and k.lvl - k.myLvl >= 3)
    end), 2
  end,
  ["p.loneWolf"] = function(f) return counted(f, function(k) return k.solo == true end), 3 end,
  ["p.untouchable"] = function(f) return math.min(spree(f), 5), 5 end,
  ["p.variety"] = function(f) return count(distinct(f, "class")), 3 end,
  ["p.ranked"] = function(f) return counted(f, function(k) return type(k.rank) == "number" and k.rank >= 1 end), 1 end,
  hunt = function(f)
    return counted(f, function(k)
      for _, h in ipairs(f.hunts or {}) do
        if k.race == h.race and k.class == h.class then return true end
      end
      return false
    end) > 0 and 1 or 0, 1
  end,

  ["b.zone25"] = function(f) return counted(f, function(k) return f.zone ~= nil and k.zone == f.zone end), 25 end,
  ["b.allClasses"] = function(f) return enemyProgress(f, Doomsday.ENEMY_CLASSES, "class") end,
  ["b.allRaces"] = function(f) return enemyProgress(f, Doomsday.ENEMY_RACES, "race") end,
  ["b.ranked5"] = function(f) return counted(f, function(k) return type(k.rank) == "number" and k.rank >= 1 end), 5 end,
  ["b.kills50"] = function(f) return counted(f), 50 end,
  ["b.spree10"] = function(f) return math.min(spree(f), 10), 10 end,
  ["b.hunt3"] = function(f) return f.huntDays or 0, 3 end,
  ["b.duels3"] = function(f) return f.duelFriends or 0, 3 end,
  ["b.days5"] = function(f)
    local days = {}
    for _, s in ipairs(f.scored or {}) do
      if s.counted and s.track == "pvp" then days[s.day] = true end
    end
    return count(days), 5
  end,
}

-- CF-70: progress functions of the mission modules (src/core/missions/*), looked up after PROGRESS.
local MODULE_PROGRESS = {}

-- A mission module adds the progress function of one of its goals: fn(facts) returns value, target (facts as
-- Goals.progressFacts gives them, with the module's own facts under its own key). A goal of PROGRESS keeps its own.
function Doomsday.registerProgress(id, fn)
  if type(id) == "string" and type(fn) == "function" and not PROGRESS[id] then MODULE_PROGRESS[id] = fn end
end

-- value, target, done of a goal ("hunt" for the Hunt) from facts. nil for an unknown id.
function Doomsday.progress(id, facts)
  local fn = PROGRESS[id] or MODULE_PROGRESS[id]
  if not fn then return nil end
  local value, target = fn(facts or {})
  return value, target, value >= target
end

-- ===== Points, crossing out, the crown, the streak =====

local TRACK = { daily = "pve", weekly = "pve", skirmish = "pvp", bounty = "pvp" }

-- The track and points of a done goal ("hunt" is a PvP daily). nil for an unknown id (a newer pool).
function Doomsday.goalPoints(id)
  if id == "hunt" then return "pvp", Doomsday.POINTS.daily end
  local g = BY_ID[id]
  if not g then return nil end
  local weekly = g.slot == "weekly" or g.slot == "bounty"
  return TRACK[g.slot], weekly and Doomsday.POINTS.weekly or Doomsday.POINTS.daily
end

--[[ A friend's points for a set of done goals: { pve, pvp }. done = { [id] = time } (days and weeks merged
by the caller); killPoints and duelPoints add to PvP. Goals of a newer pool (unknown ids) count nothing. ]]
function Doomsday.points(done, killPoints, duelPoints)
  local total = { pve = 0, pvp = (killPoints or 0) + (duelPoints or 0) }
  for id in pairs(done or {}) do
    local track, points = Doomsday.goalPoints(id)
    if track then total[track] = total[track] + points end
  end
  return total
end

-- Whether a friend is crossed out: every PvE daily of the day's set is done (the PvP goals don't count).
function Doomsday.crossedOut(set, done)
  local dailies = 0
  for _, id in ipairs(set or {}) do
    local g = BY_ID[id]
    if g and g.slot == "daily" then
      dailies = dailies + 1
      if not (done and done[id]) then return false end
    end
  end
  return dailies > 0
end

-- The time a friend crossed out (the last of the PvE dailies), or nil.
function Doomsday.finishedAt(set, done)
  if not Doomsday.crossedOut(set, done) then return nil end
  local last = 0
  for _, id in ipairs(set) do
    local g = BY_ID[id]
    if g and g.slot == "daily" then last = math.max(last, done[id]) end
  end
  return last
end

--[[ The crown of a day: friends = { { friend, set, done } }. The first to cross out, by the time recorded;
on equal times the lower friend key. Returns the friend key, or nil. ]]
function Doomsday.crown(friends)
  local best, bestAt
  for _, f in ipairs(friends or {}) do
    local at = Doomsday.finishedAt(f.set, f.done)
    if at and (not bestAt or at < bestAt or (at == bestAt and f.friend < best)) then best, bestAt = f.friend, at end
  end
  return best
end

--[[ The streak on day `today`: days in a row with at least one goal done (days = { [n] = count of goals
done, the Duel slot not counted }). Today without a goal yet doesn't end it: the streak then runs to
yesterday. best: the longest run in `days`, at least `storedBest`. Returns streak, best. ]]
function Doomsday.streak(days, today, storedBest)
  days = days or {}
  local function has(n) return (days[n] or 0) > 0 end
  local streak = 0
  local n = has(today) and today or today - 1
  while has(n) do
    streak = streak + 1
    n = n - 1
  end
  local best, list = storedBest or 0, {}
  for day in pairs(days) do
    if has(day) then list[#list + 1] = day end
  end
  table.sort(list)
  local run, last = 0, nil
  for _, day in ipairs(list) do
    run = (last == day - 1) and run + 1 or 1
    last = day
    best = math.max(best, run)
  end
  return streak, math.max(best, streak)
end

-- ===== Ladder =====

--[[ The week's ladder, one ranking per track. friends = { { friend, name, pve, pvp, goals, kills, killedEver } }
(goals: goals done this week; kills: counted kills this week; killedEver: any kill on any character ever).
previous (optional): { pve = { [friend] = rank }, pvp = { [friend] = rank } } of last week.
Returns { pve = rows, pvp = rows, virgins = { friend, ... } } with rows { friend, rank, points, move }:
move = positions gained since last week (negative: lost), "new" when not ranked last week.
PvE ties: more goals done, then the name. PvP: friends who never killed anyone (PvP Virgins) aren't ranked;
ties: more goals done, then more counted kills, then the name. ]]
function Doomsday.ladder(friends, previous)
  previous = previous or {}
  local function rank(track, list)
    table.sort(list, function(a, b)
      if a[track] ~= b[track] then return a[track] > b[track] end
      if (a.goals or 0) ~= (b.goals or 0) then return (a.goals or 0) > (b.goals or 0) end
      if track == "pvp" and (a.kills or 0) ~= (b.kills or 0) then return (a.kills or 0) > (b.kills or 0) end
      return tostring(a.name or a.friend) < tostring(b.name or b.friend)
    end)
    local rows = {}
    for i, f in ipairs(list) do
      local before = previous[track] and previous[track][f.friend]
      rows[i] = { friend = f.friend, rank = i, points = f[track], move = before and (before - i) or "new" }
    end
    return rows
  end
  local pve, pvp, virgins = {}, {}, {}
  for _, f in ipairs(friends or {}) do
    local row = { friend = f.friend, name = f.name, pve = f.pve or 0, pvp = f.pvp or 0, goals = f.goals,
                  kills = f.kills }
    pve[#pve + 1] = row
    if f.killedEver then pvp[#pvp + 1] = row else virgins[#virgins + 1] = f.friend end
  end
  table.sort(virgins)
  return { pve = rank("pve", pve), pvp = rank("pvp", pvp), virgins = virgins }
end

ns.Doomsday = Doomsday
return Doomsday
