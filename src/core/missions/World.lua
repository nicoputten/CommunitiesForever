-- Missions: combat, travel, economy and social (CF-76).
-- Pure Lua, no WoW globals. A mission module (CF-70): it registers its own observation kinds
-- (Goals.registerKind, facts under its own key) and its goals' progress (Doomsday.registerProgress).
-- Facts of a day or week under facts.world = { kills, elites, rares, bigFoes, duo (counts), streak = { [guid] =
-- kills since the last death }, bestStreak, flights, newFlights, hearth, bank, trainer, weaponUps, groupPic,
-- whispers, mailFriend, buys, repairs, sales, summons, auctions (counts; the last two from CF-104), auctionBuys (count,
-- CF-121), swim = { [guid] =
-- seconds }, ride = { [guid] = seconds }, places = { [zone|subzone] = true } }.
-- Built only for the missions whose launch check passed (docs/API-FINDINGS.md "Forever launch probe": V90, V93,
-- V94, V95, V98, V99, V100, V102, V103, V107, V108 whisper, V111, V115). CF-104 (pool version 4): d.summoned (V114)
-- and d.auctionPost (V101, Nico's pick). CF-121: d.auctionBuy (V101: AUCTION_HOUSE_PURCHASE_COMPLETED, build 70888;
-- siteOnly). Waiting: d.bind (V96), d.mailbox (V100 inbox),
-- d.restock (V99 item link), d.wave (V108 emote).
-- d.bandageUp and d.coins10 are CF-75's (Items).
local _, ns = ... -- requires ns.Goals and ns.Doomsday (loaded before it)

local World = {}

World.BIG_FOE_GAP = 3     -- d.bigFoe: a creature this many levels or more above the character
World.MAX_PLACES = 50     -- subzones kept per day or week (a cap, as Goals' lists)
World.MAX_SECONDS = 600   -- d.swim, d.ride: the most one observation may add (a stuck poll never fills a goal)

-- UnitClassification values (the game's strings; V93 saw only "normal" at launch).
local ELITE = { elite = true, rareelite = true, worldboss = true }
local RARE = { rare = true, rareelite = true }

local function count(map)
  local n = 0
  for _ in pairs(map or {}) do n = n + 1 end
  return n
end

local function text(v) return type(v) == "string" and v ~= "" and v or nil end

local function factsOf(f)
  local w = f.world
  if type(w) ~= "table" then
    w = { kills = 0, elites = 0, rares = 0, bigFoes = 0, duo = 0, streak = {}, bestStreak = 0, flights = 0,
          newFlights = 0, hearth = 0, bank = 0, trainer = 0, weaponUps = 0, groupPic = 0, whispers = 0,
          mailFriend = 0, buys = 0, repairs = 0, sales = 0, swim = {}, ride = {}, places = {} }
    f.world = w
  end
  return w
end

local function add(w, key, n) w[key] = (w[key] or 0) + (n or 1) end

-- ===== Helpers for WorldEvents (the decisions stay here) =====

-- Whether a creature's classification (UnitClassification) is an elite one: elite, rare elite or world boss.
function World.isElite(classification) return ELITE[classification] == true end

-- Whether a creature's classification is a rare one: rare or rare elite.
function World.isRare(classification) return RARE[classification] == true end

--[[ Whether a creature was a big foe for a character of charLevel: BIG_FOE_GAP or more levels above, or a skull
(UnitLevel -1). A missing level is never one. ]]
function World.isBigFoe(level, charLevel)
  if level == -1 then return true end
  return type(level) == "number" and type(charLevel) == "number" and level >= charLevel + World.BIG_FOE_GAP
end

--[[ The victim of a kill XP message. pattern: GameText.pattern of COMBATLOG_XPGAIN_FIRSTPERSON without its end
(the message has variants with bonus text after it: rested, group). Returns the creature's name, or nil. ]]
function World.victim(message, pattern)
  if type(message) ~= "string" or type(pattern) ~= "string" then return nil end
  return text((message:match(pattern)))
end

--[[ The skill of a SKILL_RANK_UP message (args: GameText.parse result, 1 = skill name), when it is a weapon or
defense skill: any skill not among the professions' names (professions = { [name] = true }). ]]
function World.weaponSkill(args, professions)
  local skill = type(args) == "table" and text(args[1])
  if not skill then return nil end
  if type(professions) == "table" and professions[skill] then return nil end
  return skill
end

--[[ The names of the professions of the own characters (chars = { [guid] = { professions = { [line] = { name } } }
}): { [name] = true }, the skills a skill-up message never counts as a weapon skill. ]]
function World.professionNames(chars)
  local names = {}
  for _, char in pairs(type(chars) == "table" and chars or {}) do
    local profs = type(char) == "table" and type(char.professions) == "table" and char.professions or {}
    for _, p in pairs(profs) do
      if type(p) == "table" and text(p.name) then names[p.name] = true end
    end
  end
  return names
end

--[[ Whether a whisper or mail target is a friend's community character. guid: the target's GUID when the event
gives one (byGuid = { [guid] = battleTag }, Places.owners). name: the name as the game or the player wrote it,
compared whole (never split, rule 4) and case-insensitively with each friend's character's name, and with name and
realm joined by "-" (the realm with and without its spaces). people = { [bt] = { chars = { [guid] = { name, realm }
} } }; mine: the own BattleTag, never a friend. ]]
function World.isFriendTarget(name, guid, byGuid, people, mine)
  if type(guid) == "string" and type(byGuid) == "table" and byGuid[guid] and byGuid[guid] ~= mine then return true end
  name = text(name)
  if not name then return false end
  local wanted = name:lower()
  for bt, person in pairs(type(people) == "table" and people or {}) do
    if bt ~= mine and type(person) == "table" and type(person.chars) == "table" then
      for _, char in pairs(person.chars) do
        local own = type(char) == "table" and text(char.name)
        if own then
          if own:lower() == wanted then return true end
          local realm = text(char.realm)
          if realm and ((own .. "-" .. realm):lower() == wanted
              or (own .. "-" .. realm:gsub("%s", "")):lower() == wanted) then
            return true
          end
        end
      end
    end
  end
  return false
end

-- Whether a Battle.net whisper's target (its BattleTag) is a friend who syncs (people), never the own BattleTag.
function World.isFriendTag(battleTag, people, mine)
  return text(battleTag) ~= nil and battleTag ~= mine and type(people) == "table" and type(people[battleTag]) == "table"
end

-- Whether a spell cast is the hearthstone: its spell ID in spells = { [spellID] = true }.
function World.isHearth(spellID, spells)
  return type(spellID) == "number" and type(spells) == "table" and spells[spellID] == true
end

-- ===== Observations =====

--[[ worldKill: a kill XP message (V90). { guid (the character), classification and level (the creature as last
  seen by target, mouseover or nameplate, V93; nil: not seen), charLevel, friend (bool: a friend's community
  character in the group) } ]]
ns.Goals.registerKind("worldKill", function(f, obs)
  local w = factsOf(f)
  add(w, "kills")
  if World.isElite(obs.classification) then add(w, "elites") end
  if World.isRare(obs.classification) then add(w, "rares") end
  if World.isBigFoe(obs.level, obs.charLevel) then add(w, "bigFoes") end
  if obs.friend == true then add(w, "duo") end
  if type(obs.guid) == "string" then
    local n = (w.streak[obs.guid] or 0) + 1
    w.streak[obs.guid] = n
    if n > (w.bestStreak or 0) then w.bestStreak = n end
  end
end)

-- worldDeath: the own character died (PLAYER_DEAD). { guid } Its kill streak starts over.
ns.Goals.registerKind("worldDeath", function(f, obs)
  if type(obs.guid) ~= "string" then return end
  factsOf(f).streak[obs.guid] = 0
end)

--[[ worldMove: time swimming or mounted (V98, polled), added up per character. { guid, swim, ride (seconds) }
  Each at most MAX_SECONDS. ]]
ns.Goals.registerKind("worldMove", function(f, obs)
  if type(obs.guid) ~= "string" then return end
  local w = factsOf(f)
  for _, key in ipairs({ "swim", "ride" }) do
    local s = obs[key]
    if type(s) == "number" and s > 0 then
      w[key][obs.guid] = (w[key][obs.guid] or 0) + math.min(s, World.MAX_SECONDS)
    end
  end
end)

-- worldPlace: a subzone entered (V115). { zone, subzone } A subzone without a name never counts.
ns.Goals.registerKind("worldPlace", function(f, obs)
  local sub = text(obs.subzone)
  if not sub then return end
  local w = factsOf(f)
  local key = (text(obs.zone) or "") .. "|" .. sub
  if w.places[key] or count(w.places) < World.MAX_PLACES then w.places[key] = true end
end)

--[[ worldAction: one of the counted actions. { action } with action one of: "flight" (on a flight master's route,
  V94), "newFlight" (a flight path learned, V94), "hearth" (V95), "bank" (V102), "trainer" (a spell learned at a
  trainer, V103), "weaponUp" (a weapon or defense skill-up, V107), "groupPic" (a screenshot grouped with a friend,
  V111), "whisper" (to a friend, V108), "mailFriend" (V100), "buy", "repair", "sale" (at a merchant, V99),
  "summoned" (a friend's summon accepted, V114), "auctionPost" (an auction posted, V101), "auctionBuy" (an auction
  bought, V101, CF-121). ]]
local ACTIONS = { flight = "flights", newFlight = "newFlights", hearth = "hearth", bank = "bank", trainer = "trainer",
                  weaponUp = "weaponUps", groupPic = "groupPic", whisper = "whispers", mailFriend = "mailFriend",
                  buy = "buys", repair = "repairs", sale = "sales", summoned = "summons", auctionPost = "auctions",
                  auctionBuy = "auctionBuys" }
World.ACTIONS = ACTIONS

ns.Goals.registerKind("worldAction", function(f, obs)
  local key = ACTIONS[obs.action]
  if key then add(factsOf(f), key) end
end)

-- ===== Progress =====

local function wo(f) return type(f.world) == "table" and f.world or {} end
local function n(value) return type(value) == "number" and value or 0 end

-- The most seconds of one character, in whole minutes.
local function minutes(map)
  local best = 0
  for _, s in pairs(type(map) == "table" and map or {}) do
    if type(s) == "number" and s > best then best = s end
  end
  return math.floor(best / 60)
end

local function counter(key, target) return function(f) return n(wo(f)[key]), target end end

local PROGRESS = {
  ["d.kills30"] = counter("kills", 30),
  ["d.elite"] = counter("elites", 1),
  ["d.rareMob"] = counter("rares", 1),
  ["d.bigFoe"] = counter("bigFoes", 1),
  ["d.streak20"] = counter("bestStreak", 20),
  ["d.duoHunt"] = counter("duo", 15),
  ["d.weaponSkill"] = counter("weaponUps", 5),
  ["d.flight"] = counter("flights", 1),
  ["d.newFlight"] = counter("newFlights", 1),
  ["d.hearth"] = counter("hearth", 1),
  ["d.ride"] = function(f) return minutes(wo(f).ride), 15 end,
  ["d.swim"] = function(f) return minutes(wo(f).swim), 2 end,
  ["d.places10"] = function(f) return count(wo(f).places), 10 end,
  ["d.whisper"] = counter("whispers", 1),
  ["d.groupPic"] = counter("groupPic", 1),
  ["d.mailFriend"] = counter("mailFriend", 1),
  ["d.vendorBuy"] = counter("buys", 1),
  ["d.vendorSale"] = counter("sales", 1),
  ["d.repair"] = counter("repairs", 1),
  ["d.trainer"] = counter("trainer", 1),
  ["d.bank"] = counter("bank", 1),
  ["d.summoned"] = counter("summons", 1),
  ["d.auctionPost"] = counter("auctions", 1),
  ["d.auctionBuy"] = counter("auctionBuys", 1), -- CF-121

  ["w.kills200"] = counter("kills", 200),
  ["w.elites10"] = counter("elites", 10),
  ["w.weapon25"] = counter("weaponUps", 25),
  ["w.flightPaths3"] = counter("newFlights", 3),
}

for id, fn in pairs(PROGRESS) do ns.Doomsday.registerProgress(id, fn) end
World.IDS = {}
for id in pairs(PROGRESS) do World.IDS[#World.IDS + 1] = id end
table.sort(World.IDS)

ns.Missions = ns.Missions or {}
ns.Missions.World = World
return World
