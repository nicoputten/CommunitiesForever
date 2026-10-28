-- Pvp: PvP, duel and death data of the own characters (CF-52). Pure Lua, no WoW globals.
-- Per character `chars.*.pvp`; per feed day the events go through Feed.add ("kills", "death", "duel").
local _, ns = ...

local Pvp = {}

-- Our title per PvP rank number, the same for both factions (docs/DOOMSDAY.md "PvP rank titles").
Pvp.TITLES = {
  [0] = "Conscientious Objector",
  "Fresh Meat", "Accidental Flagger", "Lowbie Botherer", "Corpse Camper", "Spirit Healer's Pen Pal",
  "Mailbox Menace", "Flag Hugger", "Honor Goblin", "Queue Dweller", "Crossroads Landlord",
  "Hillsbrad Housing Crisis", "Last Seen Questing at Launch", "Sleep Is for the Dishonorable", "Grass: Untouched",
}

-- A death's cause, as the feed stores it.
Pvp.CAUSES = { fall = true, fire = true, lava = true, drown = true, fatigue = true, player = true,
               creature = true, other = true }

-- How long before the death a damage event or a mirror timer still explains it (seconds).
Pvp.CAUSE_WINDOW = 10
-- At most this many kills from one counter change (a jump after a missed event is not a kill burst).
Pvp.MAX_KILLS_PER_CHANGE = 10
Pvp.MAX_RANK = 14

-- Combat log ENVIRONMENTAL_DAMAGE types (upper case) and death recap names (any case) -> cause.
local ENVIRONMENT = { FALLING = "fall", FIRE = "fire", LAVA = "lava", DROWNING = "drown", FATIGUE = "fatigue",
                      SLIME = "other" }
-- Mirror timers (MIRROR_TIMER_START) -> cause.
local TIMERS = { BREATH = "drown", EXHAUSTION = "fatigue" }

-- COMBATLOG_OBJECT_CONTROL_PLAYER (0x100): a player or something a player controls (a pet). Tested
-- without the bit library, which the pure core does not have.
local function controlledByPlayer(flags)
  return type(flags) == "number" and math.floor(flags / 0x100) % 2 == 1
end

--[[ The last damage taken, as Pvp.deathCause reads it, from one combat log or death recap event:
  subevent "ENVIRONMENTAL_DAMAGE" with environment (type), or any other damage subevent with the source's
  flags (combat log) or GUID (death recap). Returns { kind = <cause>, at } or nil for other events. ]]
function Pvp.damage(subevent, environment, sourceFlags, sourceGuid, at)
  if type(subevent) ~= "string" then return nil end
  if subevent == "ENVIRONMENTAL_DAMAGE" then
    local cause = type(environment) == "string" and ENVIRONMENT[environment:upper()] or "other"
    return { kind = cause, at = at }
  end
  if not subevent:match("_DAMAGE$") and subevent ~= "SWING_DAMAGE" then return nil end
  if controlledByPlayer(sourceFlags) then return { kind = "player", at = at } end
  if sourceFlags == nil and type(sourceGuid) == "string" then
    return { kind = sourceGuid:match("^Player%-") and "player" or "creature", at = at }
  end
  return { kind = "creature", at = at }
end

--[[ The cause of a death at `now`: the last damage taken within CAUSE_WINDOW (combat log or death recap,
see Pvp.damage); else a breath or exhaustion timer that ran until the death or stopped within the window
(timers = { [name] = { startedAt, stoppedAt } }); else "other". ]]
function Pvp.deathCause(lastDamage, timers, now)
  if type(lastDamage) == "table" and Pvp.CAUSES[lastDamage.kind] and type(lastDamage.at) == "number"
      and now - lastDamage.at <= Pvp.CAUSE_WINDOW then
    return lastDamage.kind
  end
  for name, cause in pairs(TIMERS) do
    local timer = type(timers) == "table" and timers[name]
    if type(timer) == "table" and (timer.stoppedAt == nil or now - timer.stoppedAt <= Pvp.CAUSE_WINDOW) then
      return cause
    end
  end
  return "other"
end

-- Lua pattern of a game format string ("%1$s has defeated %2$s in a duel") and, per capture, the number
-- of the argument it holds. Plain "%s" and "%d" count in order. nil when the string has no arguments.
function Pvp.pattern(format)
  if type(format) ~= "string" then return nil end
  local order, plain, pattern = {}, 0, ""
  local i = 1
  while i <= #format do
    local index, kind, after = format:match("^%%(%d)%$([sd])()", i)
    if not index then
      kind, after = format:match("^%%([sd])()", i)
    end
    if not kind and format:sub(i, i + 1) == "%%" then
      pattern = pattern .. "%%"
      i = i + 2
    elseif kind then
      if index then
        index = tonumber(index)
      else
        plain = plain + 1
        index = plain
      end
      order[#order + 1] = index
      pattern = pattern .. (kind == "d" and "(%d+)" or "(.+)")
      i = after
    else
      local char = format:sub(i, i)
      pattern = pattern .. (char:match("%W") and ("%" .. char) or char)
      i = i + 1
    end
  end
  if #order == 0 then return nil end
  return "^" .. pattern .. "$", order
end

-- The arguments of a message formatted with `format`, by argument number, or nil when it does not match.
function Pvp.parse(message, format)
  local pattern, order = Pvp.pattern(format)
  if not pattern or type(message) ~= "string" then return nil end
  local captures = { message:match(pattern) }
  if #captures == 0 then return nil end
  local args = {}
  for i, index in ipairs(order) do args[index] = captures[i] end
  return args
end

--[[ A finished duel of `me` (the own full name) from a system message: { won, vs } or nil.
formats = { knockout = DUEL_WINNER_KNOCKOUT, retreat = DUEL_WINNER_RETREAT }. In both the first argument is
the winner and the second the loser (VERIFY.md V80). Names are compared whole, never split (rule 4). ]]
function Pvp.duel(message, formats, me)
  if type(me) ~= "string" or type(formats) ~= "table" then return nil end
  for _, key in ipairs({ "knockout", "retreat" }) do
    local args = Pvp.parse(message, formats[key])
    if args and args[1] and args[2] and args[1] ~= args[2] then
      if args[1] == me then return { won = true, vs = args[2] } end
      if args[2] == me then return { won = false, vs = args[1] } end
    end
  end
  return nil
end

local function count(value)
  if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return nil end
  return math.floor(value)
end

--[[ The character's PvP data from what the game gives (adapters/PvpInfo.read) and the stored data:
  { hk, rank, rankName, weekKills, weekHonor, deaths, duelsWon, duelsLost }
hk: lifetime honorable kills; rank: PvP rank number (0 none, 1 to 14); rankName: the game's name for it;
weekKills, weekHonor: this week's honorable kills and honor. A value the game does not give keeps the stored
one. deaths, duelsWon, duelsLost are counted by the addon (Pvp.count) or deaths from the game's statistic. ]]
function Pvp.build(info, stored)
  info, stored = info or {}, stored or {}
  local rank, statDeaths = count(info.rank), count(info.deaths)
  local rankName = stored.rankName
  if rank then rankName = rank > 0 and type(info.rankName) == "string" and info.rankName or nil end
  local pvp = {
    hk = count(info.hk) or stored.hk,
    rank = rank and math.min(rank, Pvp.MAX_RANK) or stored.rank,
    rankName = rankName,
    weekKills = count(info.weekKills) or stored.weekKills,
    weekHonor = count(info.weekHonor) or stored.weekHonor,
    deaths = statDeaths and math.max(statDeaths, stored.deaths or 0) or stored.deaths,
    duelsWon = stored.duelsWon,
    duelsLost = stored.duelsLost,
  }
  return next(pvp) and pvp or nil
end

-- New honorable kills between two lifetime counts: 0 when either is unknown or the count went down,
-- at most MAX_KILLS_PER_CHANGE.
function Pvp.newKills(before, after)
  if type(before) ~= "number" or type(after) ~= "number" or after <= before then return 0 end
  return math.min(after - before, Pvp.MAX_KILLS_PER_CHANGE)
end

-- Counts a death or a duel in the lifetime counters (in place). event: { kind = "death" } or
-- { kind = "duel", won }. statDeaths: the game's total deaths when readable; it wins when higher (the addon
-- came later), and a statistic that has not counted this death yet does not undo it.
function Pvp.count(pvp, event, statDeaths)
  if event.kind == "death" then
    pvp.deaths = math.max(count(statDeaths) or 0, (pvp.deaths or 0) + 1)
  elseif event.kind == "duel" then
    if event.won then pvp.duelsWon = (pvp.duelsWon or 0) + 1 else pvp.duelsLost = (pvp.duelsLost or 0) + 1 end
  end
end

-- "Stone Guard a.k.a. Mailbox Menace", "rank 0 a.k.a. Conscientious Objector", or nil without a rank.
function Pvp.rankText(pvp)
  local rank = type(pvp) == "table" and pvp.rank
  if type(rank) ~= "number" or not Pvp.TITLES[rank] then return nil end
  local name = rank > 0 and pvp.rankName or nil
  return string.format("%s a.k.a. %s", name or ("rank " .. rank), Pvp.TITLES[rank])
end

local MAX_NUMBER = 10000000

local function cleanCount(value)
  local n = count(value)
  return n and math.min(n, MAX_NUMBER) or nil
end

-- Copy of a received `chars.*.pvp` with only the expected fields, cleaned, or nil.
function Pvp.clean(pvp)
  if type(pvp) ~= "table" then return nil end
  local rank = cleanCount(pvp.rank)
  local result = {
    hk = cleanCount(pvp.hk),
    rank = rank and rank <= Pvp.MAX_RANK and rank or nil,
    rankName = type(pvp.rankName) == "string" and pvp.rankName:gsub("|", ""):sub(1, 40) or nil,
    weekKills = cleanCount(pvp.weekKills),
    weekHonor = cleanCount(pvp.weekHonor),
    deaths = cleanCount(pvp.deaths),
    duelsWon = cleanCount(pvp.duelsWon),
    duelsLost = cleanCount(pvp.duelsLost),
  }
  return next(result) and result or nil
end

ns.Pvp = Pvp
return Pvp
