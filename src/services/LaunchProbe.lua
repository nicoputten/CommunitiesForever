--[[ LaunchProbe (CF-82): FriendProbe's automatic checks, hidden inside the addon, so friends answer them without
installing FriendProbe. Results go to CommunitiesForeverDB.global.probe (core/Probe.lua), which the uploader sends to
the site. Until Probe.STOP_AT (2026-11-18).
- Invisible: nothing in chat, no frame, sound or popup; only post-hooks (hooksecurefunc). Left out: what can show
  something or act (the combat log V75, whispers, invites, links, reloads, the jump hook V118).
- Safe: every handler and hook runs in pcall (an error is noted under "error"); every API is guarded; a secret value
  is recorded as "secret", a missing API as "missing".
- Cheap: one AceEvent object; units throttled per GUID (60 s); a check's costly scan stops once it passed.
- Private: no raw chat text, no event log; player names only for the Hunt's victim and the killer (V120).
This file: the plumbing and the login, PvP, death, loot and trade checks. services/LaunchProbeMissions.lua: the
mission catalogue's checks (V90 to V117) and the PvP catalogue's (V120 to V123). ]]
local _, ns = ...

local Probe = ns.Probe
local LaunchProbe = {}

local handlers = {}  -- event -> { fn }, filled by both files at load
local hooks = {}     -- { name, fn }: post-hooks on Blizzard functions
local logins = {}    -- fns run once at login
local results        -- this client's results (db.global.probe.results[client])
local section        -- db.global.probe
local started = false

-- ===== Reading values safely =====

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

local function S(v)
  local ok, s = pcall(tostring, v)
  return ok and s or "<error>"
end

-- A value as text: "missing" (nil), "secret" or the value.
local function Val(v)
  if v == nil then return "missing" end
  if secret(v) then return "secret" end
  return S(v)
end

-- Every return value of fn(...) through Val, or "missing" / "error".
local function Vals(fn, ...)
  if type(fn) ~= "function" then return "missing" end
  local r = { pcall(fn, ...) }
  if not r[1] then return "error" end
  local parts = {}
  for i = 2, table.maxn(r) do parts[#parts + 1] = Val(r[i]) end
  return #parts > 0 and table.concat(parts, ", ") or "(nothing)"
end

-- A readable value: not nil and not secret.
local function readable(v)
  return v ~= nil and not secret(v)
end

-- A readable, non-empty string.
local function str(v)
  return type(v) == "string" and readable(v) and v ~= ""
end

-- The first return value of fn(...) when readable, else nil.
local function get(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and readable(v) then return v end
  return nil
end

-- The key of the first of the game's format strings (by global name) whose pattern matches text.
local function matches(text, ...)
  if not str(text) then return nil end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    local pattern = ns.GameText.pattern(_G[key])
    if pattern and text:match(pattern) then return key end
  end
end

local function now() return GetServerTime() end
local function build() return GetBuildInfo and S((select(2, GetBuildInfo()))) or "?" end

-- ===== Recording =====

local function result(id, status, detail)
  if not results then return end
  if Probe.record(results, id, status, detail, now(), build()) then Probe.trim(section) end
end

local function note(id, line)
  if not results then return end
  Probe.note(results, id, line)
  Probe.trim(section)
end

local function passed(id)
  return results ~= nil and Probe.passed(results, id)
end

-- An info line that never overwrites a pass.
local function info(id, detail)
  if not passed(id) then result(id, "info", detail) end
end

local function running()
  return Probe.running(now(), section)
end

-- ===== Registration (both files) =====

function LaunchProbe.on(event, fn)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
end

function LaunchProbe.hook(name, fn) hooks[#hooks + 1] = { name = name, fn = fn } end
function LaunchProbe.atLogin(fn) logins[#logins + 1] = fn end

-- Runs fn guarded; an error is noted, never shown.
local function guarded(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then pcall(note, "error", label .. ": " .. S(err)) end
end

local function dispatch(event, ...)
  if not running() then return end
  for _, fn in ipairs(handlers[event]) do guarded(event, fn, ...) end
end

-- After `seconds`, fn runs guarded (C_Timer.NewTimer, verified), or not at all without a timer.
local function after(seconds, fn)
  if C_Timer and C_Timer.NewTimer then
    C_Timer.NewTimer(seconds, function()
      if running() then guarded("timer", fn) end
    end)
  end
end

-- For LaunchProbeMissions.lua.
LaunchProbe.util = { S = S, Val = Val, Vals = Vals, readable = readable, str = str, get = get, matches = matches,
                     result = result, note = note, info = info, passed = passed, after = after, now = now }

-- ===== Login: values to read once (V55, V63, V71, V77, V78, V79, V82) =====

local RIDING_LINES = { 148, 149, 150, 152, 533, 553, 554, 713, 762 }

LaunchProbe.atLogin(function()
  local clock = date and date("%H:%M")
  result("V63", type(clock) == "string" and clock:match("^%d%d:%d%d$") and "pass" or "fail", "date: " .. Val(clock))
  local t = time and time({ year = 2026, month = 11, day = 6, hour = 20, min = 30 })
  result("V71", type(t) == "number" and math.abs(t - now()) < 400 * 86400 and "pass" or "fail", "time() " .. Val(t))
  local double = GameTooltip and GameTooltip.AddDoubleLine ~= nil
  result("V55", double and "pass" or "fail", "GameTooltip.AddDoubleLine " .. (double and "exists" or "missing"))

  local region = get(GetCurrentRegion)
  result("V77", type(region) == "number" and "pass" or "fail", "region " .. Val(region))
  local hour, minute
  if GetGameTime then
    local ok, h, m = pcall(GetGameTime)
    if ok and readable(h) and readable(m) then hour, minute = h, m end
  end
  result("V78", Probe.realmClock(hour, minute, now()))

  local lifetime = get(GetPVPLifetimeStats)
  result("V79", type(lifetime) == "number" and "pass" or "fail", "lifetime " .. Vals(GetPVPLifetimeStats)
    .. ", rank " .. Vals(UnitPVPRank, "player") .. ", deaths " .. Vals(GetStatistic, 60))

  local riding = {}
  local byLine = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
  for _, line in ipairs(RIDING_LINES) do
    local prof = get(byLine, line)
    if type(prof) == "table" and type(prof.skillLevel) == "number" and prof.skillLevel > 0 then
      riding[#riding + 1] = "line " .. line
    end
  end
  if get(IsSpellKnown, 33388) or get(IsSpellKnown, 33391) then riding[#riding + 1] = "spell" end
  if #riding > 0 then
    result("V82", "pass", "riding from " .. table.concat(riding, ", "))
  else
    info("V82", "no riding skill seen (GetProfessionInfoBySkillLineID " .. (byLine and "exists" or "missing") .. ")")
  end
end)

-- ===== V35b, V70: battlegrounds and boss fights =====

LaunchProbe.on("PVP_MATCH_COMPLETE", function(winner)
  if type(winner) == "number" and readable(winner) then
    result("V35b", "pass", "PVP_MATCH_COMPLETE winner " .. winner .. ", GetBattlefieldWinner "
      .. Vals(GetBattlefieldWinner))
  else
    info("V35b", "PVP_MATCH_COMPLETE winner " .. Val(winner))
  end
end)

LaunchProbe.on("ENCOUNTER_START", function()
  local locked = get(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
  local busy = get(IsEncounterInProgress)
  if locked == true or busy == true then
    result("V70", "pass", "in a boss fight: lockdown " .. Val(locked) .. ", in progress " .. Val(busy))
  else
    result("V70", "fail", "in a boss fight: lockdown " .. Val(locked) .. ", in progress " .. Val(busy))
  end
end)

-- ===== V74, V73, V76, the Hunt: enemy players and honorable kills =====

local unitSeen = {} -- guid -> server time of the last look (Probe.THROTTLE)
local seenByName = {} -- the Hunt: name -> { race, class, source, at }

local function Enemy(unit, source)
  if not (get(UnitExists, unit) and get(UnitIsPlayer, unit)) then return end
  if not (get(UnitIsEnemy, "player", unit) or get(UnitCanAttack, "player", unit)) then return end
  local guid = UnitGUID and UnitGUID(unit)
  local key = readable(guid) and guid or (unit .. source)
  if Probe.throttled(unitSeen, key, now()) then return end
  local level = UnitLevel and UnitLevel(unit)
  local class = UnitClass and select(2, UnitClass(unit))
  local race = UnitRace and select(2, UnitRace(unit))
  local bad = {}
  if not readable(class) then bad[#bad + 1] = "class " .. Val(class) end
  if not readable(level) then bad[#bad + 1] = "level " .. Val(level) end
  if not readable(race) then bad[#bad + 1] = "race " .. Val(race) end
  if #bad == 0 then
    result("V74", "pass", "level, class and race readable via " .. source)
  else
    result("V74", "fail", table.concat(bad, ", ") .. " via " .. source)
  end
  Probe.remember(seenByName, { get(GetUnitName, unit, true), get(UnitName, unit) },
    { race = str(race) and race or nil, class = str(class) and class or nil, source = source }, now())
end

LaunchProbe.on("PLAYER_TARGET_CHANGED", function() Enemy("target", "target") end)
LaunchProbe.on("UPDATE_MOUSEOVER_UNIT", function() Enemy("mouseover", "mouseover") end)
LaunchProbe.on("NAME_PLATE_UNIT_ADDED", function(unit) if str(unit) then Enemy(unit, "nameplate") end end)

LaunchProbe.on("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  local args = str(text) and ns.GameText.parse(text, COMBATLOG_HONORGAIN)
  local victim, rank = args and args[1], args and args[2]
  if victim then
    result("V73", "pass", "victim and rank from the honor message (rank " .. Val(rank) .. ")")
  elseif not COMBATLOG_HONORGAIN then
    result("V73", "fail", "COMBATLOG_HONORGAIN missing")
  elseif not str(text) then
    result("V73", "fail", "honor message " .. Val(text))
  else
    result("V73", "fail", "honor message did not match COMBATLOG_HONORGAIN")
    note("V73", "format: " .. Val(COMBATLOG_HONORGAIN))
  end
  local status, detail = Probe.hunt(seenByName, victim, now())
  if status == "pass" then
    result("Hunt", status, detail)
  elseif status then
    info("Hunt", detail)
  end
  local grouped = get(IsInGroup)
  local instanceType = GetInstanceInfo and select(2, GetInstanceInfo())
  if type(grouped) == "boolean" and str(instanceType) then
    result("V76", "pass", "group " .. S(grouped) .. ", instance " .. instanceType)
  else
    result("V76", "fail", "IsInGroup " .. Val(grouped) .. ", instance " .. Val(instanceType))
  end
  note("V79", "at a kill: lifetime " .. Vals(GetPVPLifetimeStats) .. ", week " .. Vals(GetPVPThisWeekStats))
end)

-- ===== V80, V86: system messages =====

local function Discovered(text)
  local key = matches(text, "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP")
  if key then result("V86", "pass", key .. " matched") end
end

LaunchProbe.on("CHAT_MSG_SYSTEM", function(text)
  if not str(text) then return end
  if not passed("V80") then
    local me = get(GetUnitName, "player", true)
    local short = get(UnitName, "player")
    for _, key in ipairs({ "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT" }) do
      local args = ns.GameText.parse(text, _G[key])
      if args and (args[1] == me or args[2] == me or args[1] == short or args[2] == short) then
        result("V80", "pass", key .. " parsed with your name")
      end
    end
  end
  if not passed("V86") then Discovered(text) end
end)

-- ===== V81: where a death's cause comes from =====

local mirrorSeen = false
LaunchProbe.on("MIRROR_TIMER_START", function() mirrorSeen = true end)

LaunchProbe.on("PLAYER_DEAD", function()
  local sources = {}
  local recap = C_DeathRecap and C_DeathRecap.GetRecapEvents
  if recap then
    sources[#sources + 1] = "death recap"
    local ok, events = pcall(recap)
    note("V81", "GetRecapEvents: " .. (ok and type(events) == "table" and (#events .. " events") or Val(events)))
  end
  if mirrorSeen then sources[#sources + 1] = "mirror timers" end
  result("V81", #sources > 0 and "pass" or "fail", #sources > 0 and table.concat(sources, ", ") or "no cause source")
  note("V79", "at a death: GetStatistic(60) " .. Vals(GetStatistic, 60))
end)

-- ===== V83, V84, V85: loot, fishing, trades =====

LaunchProbe.on("CHAT_MSG_LOOT", function(text)
  if passed("V83") then return end
  local key = matches(text, "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF")
  if key then result("V83", "pass", key .. " matched, item " .. Val(ns.GameText.item(text))) end
end)

LaunchProbe.on("LOOT_OPENED", function()
  if passed("V84") then return end
  if get(IsFishingLoot) == true then
    result("V84", "pass", "IsFishingLoot true, " .. Vals(GetNumLootItems) .. " items")
  end
end)

local tradePartner
LaunchProbe.on("TRADE_SHOW", function() tradePartner = get(UnitGUID, "NPC") or false end)
LaunchProbe.on("UI_INFO_MESSAGE", function(_, text)
  if not str(text) then return end
  if ERR_TRADE_COMPLETE and text == ERR_TRADE_COMPLETE and tradePartner ~= nil then
    result("V85", tradePartner and "pass" or "fail", "trade complete, partner GUID "
      .. (tradePartner and "readable" or "missing"))
    tradePartner = nil
  elseif not passed("V86") then
    Discovered(text)
  end
end)

-- ===== V87: data from a friend who appears offline =====

-- True when a Battle.net friend's WoW game account with this ID is visible (online in this game).
local function visible(gameAccountID)
  if not (BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts) then return false end
  for i = 1, get(BNGetNumFriends) or 0 do
    for j = 1, get(C_BattleNet.GetFriendNumGameAccounts, i) or 0 do
      local ga = get(C_BattleNet.GetFriendGameAccountInfo, i, j)
      if type(ga) == "table" and ga.gameAccountID == gameAccountID then return true end
    end
  end
  return false
end

local senders = {}
LaunchProbe.on("BN_CHAT_MSG_ADDON", function(_, _, _, senderID)
  if passed("V87") or type(senderID) ~= "number" or secret(senderID) then return end
  if Probe.throttled(senders, senderID, now()) or visible(senderID) then return end
  local game = get(C_BattleNet and C_BattleNet.GetGameAccountInfoByID, senderID)
  local guid = type(game) == "table" and str(game.playerGuid) and game.playerGuid or nil
  local account = guid and get(C_BattleNet.GetAccountInfoByGUID, guid)
  local tag = type(account) == "table" and str(account.battleTag)
  result("V87", guid and tag and "pass" or "fail", string.format("from a hidden game account: "
    .. "GetGameAccountInfoByID %s, playerGuid %s, battleTag %s", type(game) == "table" and "ok" or "nil",
    guid and "yes" or "no", tag and "yes" or "no"))
end)

-- ===== Start =====

-- The client's results, readable for /cf fp.
function LaunchProbe.results() return results end
function LaunchProbe.client() return Probe.client(WOW_PROJECT_ID) end
function LaunchProbe.running() return section ~= nil and running() end

-- At login: until STOP_AT, registers its events (own AceEvent object, not the addon's handlers) and post-hooks
-- and reads the values to read once. After STOP_AT it registers nothing and keeps the results.
function LaunchProbe.start(addon)
  if started then return end
  section = Probe.section(addon.db.global)
  results = Probe.results(addon.db.global, Probe.client(WOW_PROJECT_ID))
  if not running() then return end
  started = true
  local listener = LibStub("AceEvent-3.0"):Embed({})
  for event in pairs(handlers) do
    pcall(ns.Events.register, listener, event, dispatch)
  end
  for _, h in ipairs(hooks) do
    if hooksecurefunc and type(_G[h.name]) == "function" then
      pcall(hooksecurefunc, h.name, function(...)
        if running() then guarded(h.name, h.fn, ...) end
      end)
    end
  end
  for _, fn in ipairs(logins) do guarded("login", fn) end
  Probe.trim(section)
end

ns.LaunchProbe = LaunchProbe
return LaunchProbe
