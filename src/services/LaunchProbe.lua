--[[ LaunchProbe (CF-82): FriendProbe's automatic checks, hidden inside the addon, so friends answer them without
installing FriendProbe. Results go to CommunitiesForeverDB.global.probe (core/Probe.lua), which the uploader sends to
the site. Until Probe.STOP_AT (2026-11-18).
- Invisible: nothing in chat, no frame, sound or popup; only post-hooks (hooksecurefunc). Left out: what can show
  something or act (the combat log V75, whispers, invites, sending links, reloads, the jump hook V118). A clicked
  link is only watched (a SetItemRef post-hook, V60b).
- Safe: every handler and hook runs in pcall (an error is noted under "error"); every API is guarded; a secret value
  is recorded as "secret", a missing API as "missing".
- Cheap: one AceEvent object; units throttled per GUID (60 s); a check's costly scan stops once it passed.
- Private: no raw chat text, no event log; player names only for the Hunt's victim and the killer (V120).
This file: the plumbing and the login and PvP checks. services/LaunchProbeMissions.lua: the mission catalogue's
checks and the PvP catalogue's (V120 to V123). services/LaunchProbeRecipes.lua: the recipe checks (V60, V60b).
CF-96: the checks answered by the launch results (build 70790, docs/API-FINDINGS.md "Forever launch probe") are gone;
their stored results stay in the saved data as they are. ]]
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

-- ===== Login: values to read once (V82) =====

local RIDING_LINES = { 148, 149, 150, 152, 533, 553, 554, 713, 762 }

LaunchProbe.atLogin(function()
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

-- ===== V35b: battlegrounds (V70, boss fights, answered: CF-101) =====

LaunchProbe.on("PVP_MATCH_COMPLETE", function(winner)
  if type(winner) == "number" and readable(winner) then
    result("V35b", "pass", "PVP_MATCH_COMPLETE winner " .. winner .. ", GetBattlefieldWinner "
      .. Vals(GetBattlefieldWinner))
  else
    info("V35b", "PVP_MATCH_COMPLETE winner " .. Val(winner))
  end
end)

-- ===== V73, the Hunt: enemy players and honorable kills (V76, the group at a kill, answered: CF-101) =====
-- Enemy players are still looked at for the Hunt (their race and class before a kill); V74 itself is answered.

local unitSeen = {} -- guid -> server time of the last look (Probe.THROTTLE)
local seenByName = {} -- the Hunt: name -> { race, class, source, at }

local function Enemy(unit, source)
  if not (get(UnitExists, unit) and get(UnitIsPlayer, unit)) then return end
  if not (get(UnitIsEnemy, "player", unit) or get(UnitCanAttack, "player", unit)) then return end
  local guid = UnitGUID and UnitGUID(unit)
  local key = readable(guid) and guid or (unit .. source)
  if Probe.throttled(unitSeen, key, now()) then return end
  local class = UnitClass and select(2, UnitClass(unit))
  local race = UnitRace and select(2, UnitRace(unit))
  Probe.remember(seenByName, { get(GetUnitName, unit, true), get(UnitName, unit) },
    { race = str(race) and race or nil, class = str(class) and class or nil, source = source }, now())
end

LaunchProbe.on("PLAYER_TARGET_CHANGED", function() Enemy("target", "target") end)
LaunchProbe.on("UPDATE_MOUSEOVER_UNIT", function() Enemy("mouseover", "mouseover") end)
LaunchProbe.on("NAME_PLATE_UNIT_ADDED", function(unit) if str(unit) then Enemy(unit, "nameplate") end end)

-- CF-101: the game's honor message globals ("COMBATLOG_HONOR..."), sorted, as "NAME" or "NAME (matches)": which
-- variant Forever uses. Looked up once, at the first message no format matched.
local honorGlobals
local function HonorGlobals(text)
  if honorGlobals then return honorGlobals end
  local names = {}
  for key, value in pairs(_G) do
    if type(key) == "string" and key:find("^COMBATLOG_HONOR") and type(value) == "string" then
      names[#names + 1] = key .. (ns.GameText.parse(text, value) and " (matches)" or "")
    end
  end
  table.sort(names)
  honorGlobals = #names > 0 and table.concat(names, ", ") or "none"
  return honorGlobals
end

LaunchProbe.on("CHAT_MSG_COMBAT_HONOR_GAIN", function(text)
  local formats = ns.PvpInfo.formats().honors
  local args, format = nil, nil
  if str(text) then args, format = ns.Pvp.honorArgs(text, formats) end
  local victim = args and args[1]
  if victim then
    local name = "?"
    for _, global in ipairs(ns.PvpInfo.HONOR_FORMATS) do
      if _G[global] == format then name = global break end
    end
    result("V73", "pass", "victim from the honor message via " .. name .. " (second argument " .. Val(args[2]) .. ")")
  elseif #formats == 0 then
    result("V73", "fail", "COMBATLOG_HONORGAIN and its variants missing")
  elseif not str(text) then
    result("V73", "fail", "honor message " .. Val(text))
  else
    result("V73", "fail", "no honor format matched: " .. Val(ns.Probe.shape(text, formats)))
    note("V73", "globals: " .. HonorGlobals(text))
  end
  local status, detail = Probe.hunt(seenByName, victim, now())
  if status == "pass" then
    result("Hunt", status, detail)
  elseif status then
    info("Hunt", detail)
  end
  note("V73", "at a kill: lifetime " .. Vals(GetPVPLifetimeStats) .. ", week " .. Vals(GetPVPThisWeekStats))
end)

-- V79's open part: does PLAYER_PVP_KILLS_CHANGED fire on Forever (noted with the kill it belongs to)?
LaunchProbe.on("PLAYER_PVP_KILLS_CHANGED", function()
  note("V73", "PLAYER_PVP_KILLS_CHANGED, week " .. Vals(GetPVPThisWeekStats))
end)

-- ===== V80: duel lines =====

LaunchProbe.on("CHAT_MSG_SYSTEM", function(text)
  if not str(text) or passed("V80") then return end
  local me = get(GetUnitName, "player", true)
  local short = get(UnitName, "player")
  for _, key in ipairs({ "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT" }) do
    local args = ns.GameText.parse(text, _G[key])
    if args and (args[1] == me or args[2] == me or args[1] == short or args[2] == short) then
      result("V80", "pass", key .. " parsed with your name")
    end
  end
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
