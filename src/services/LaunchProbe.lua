--[[ LaunchProbe (CF-82): FriendProbe's automatic checks, hidden inside the addon, so friends answer them without
installing FriendProbe. Results go to CommunitiesForeverDB.global.probe (core/Probe.lua), which the uploader sends to
the site. Until Probe.STOP_AT (2026-11-18).
- Invisible: nothing in chat, no frame, sound or popup; only post-hooks (hooksecurefunc). Left out: what can show
  something or act (the combat log V75, whispers, invites, sending links, reloads, the jump hook V118). A clicked
  link is only watched (a SetItemRef post-hook, V60b).
- Safe: every handler and hook runs in pcall (an error is noted under "error"); every API is guarded; a secret value
  is recorded as "secret", a missing API as "missing".
- Cheap: one AceEvent object; units throttled per GUID (60 s); a check's costly scan stops once it passed.
- Private: no raw chat text, no event log; player names only for the Hunt's victim (the killer's, V120, until
  CF-113 answered it). V142 records a race's token, ID and name, never the player's.
This file: the plumbing, the login and PvP checks and V142 (races beyond Vanilla's eight, CF-116).
services/LaunchProbeMissions.lua: the mission catalogue's checks and the PvP catalogue's (V122, V123; V120
answered, CF-113). services/LaunchProbeRecipes.lua: the recipe check (V60b; V60 and V60c answered, CF-105).
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

-- ===== The Hunt: the victim picked at a counted kill (CF-110) =====
-- V73 (the honor message names no victim) and V80 (the duel lines) are answered and gone (CF-116); V76, the group
-- at a kill, CF-101.

LaunchProbe.on("PLAYER_PVP_KILLS_CHANGED", function()
  local pick = ns.PvpTracker and ns.PvpTracker.victimNow and ns.PvpTracker.victimNow()
  local status, detail = Probe.huntPick(pick)
  if status == "pass" then result("Hunt", status, detail) else info("Hunt", detail) end
  note("Hunt", "UnitIsDead " .. (UnitIsDead and "exists" or "missing") .. ", target dead "
    .. Val(get(UnitIsDead, "target")))
end)

-- ===== V142: races beyond Vanilla's eight, the Skyborne (CF-116) =====
-- Any player, enemy or friendly, seen as target, mouseover or nameplate: UnitRace's three returns when the race isn't
-- one of the eight. No player names: only the race's token, ID and name.

local unitSeen = {} -- guid -> server time of the last look (Probe.THROTTLE)
local racesSeen = {} -- line -> true, this session
local raceKeys = {} -- "<token> <id>" of each race seen, in order: the result's detail

local function Player(unit, source)
  if not (get(UnitExists, unit) and get(UnitIsPlayer, unit)) then return end
  local guid = UnitGUID and UnitGUID(unit)
  local key = readable(guid) and guid or (unit .. source)
  if Probe.throttled(unitSeen, key, now()) then return end
  if type(UnitRace) ~= "function" then return end
  local ok, name, token, id = pcall(UnitRace, unit)
  if not ok then return end
  local enemy = get(UnitIsEnemy, "player", unit) or get(UnitCanAttack, "player", unit)
  token = str(token) and token or nil
  id = (type(id) == "number" and readable(id)) and id or nil
  local line = Probe.newRace(str(name) and name or nil, token, id, enemy and "enemy" or "friendly", source)
  if not line or racesSeen[line] then return end
  racesSeen[line] = true
  note("V142", line)
  local race = tostring(token or "?") .. " " .. tostring(id or "?")
  for _, k in ipairs(raceKeys) do
    if k == race then return end
  end
  raceKeys[#raceKeys + 1] = race
  result("V142", "pass", "UnitRace token and id: " .. table.concat(raceKeys, ", "))
end

LaunchProbe.on("PLAYER_TARGET_CHANGED", function() Player("target", "target") end)
LaunchProbe.on("UPDATE_MOUSEOVER_UNIT", function() Player("mouseover", "mouseover") end)
LaunchProbe.on("NAME_PLATE_UNIT_ADDED", function(unit) if str(unit) then Player(unit, "nameplate") end end)

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
