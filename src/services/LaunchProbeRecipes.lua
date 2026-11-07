--[[ LaunchProbeRecipes (CF-98): the hidden probe's recipe check for CF-38. Same rules as services/LaunchProbe.lua:
silent, guarded, cheap. CF-105: V60 and V60c are answered (docs/API-FINDINGS.md "Forever launch probe") and gone;
only V60b is left.
- V60b: does a clicked profession link ("trade:") open Blizzard's view of someone else, also while they are offline?
  Only seen when someone clicks such a link: a post-hook on SetItemRef notes the click (never acts), and a
  TRADE_SKILL_SHOW with IsTradeSkillLinked within 5 s answers it. Whose link it was is kept as "yours", "a friend
  online", "a friend offline" or "someone else": no GUID, no name. ]]
local _, ns = ...

local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, str, get = u.Val, u.str, u.get
local result, note, info, after, now = u.result, u.note, u.info, u.after, u.now
local on = LaunchProbe.on

local Recipes = {}

Recipes.WAIT = 5     -- seconds a clicked profession link has to open the window

local function T() return C_TradeSkillUI end

-- The first return of C_TradeSkillUI[name](...) when readable.
local function call(name, ...)
  local api = T()
  return get(api and api[name], ...)
end

-- ===== V60b: a clicked profession link =====

-- Whose a link's character is, as a word: the GUID is looked up, never stored.
local function whose(guid)
  if not str(guid) then return "someone else" end
  local global = ns.db and ns.db.global or {}
  local own = type(global.self) == "table" and type(global.self.chars) == "table" and global.self.chars
  if guid == get(UnitGUID, "player") or (own and own[guid]) then return "yours" end
  local tracker = ns.PresenceTracker
  local ok, online = pcall(function() return tracker and tracker.characters() or {} end)
  if ok and type(online) == "table" and online[guid] then return "a friend online" end
  local sync = ns.Sync
  ok, online = pcall(function() return sync and sync.online() or {} end)
  if ok and type(online) == "table" then
    for _, peer in pairs(online) do
      if type(peer) == "table" and peer.guid == guid then return "a friend online" end
    end
  end
  -- A character of a person in the addon's data, not online now: a friend offline.
  for _, person in pairs(type(global.people) == "table" and global.people or {}) do
    if type(person) == "table" and type(person.chars) == "table" and person.chars[guid] then
      return "a friend offline"
    end
  end
  return "someone else"
end

local pending -- { at, who }: the last clicked profession link, until the window opens or WAIT runs out

function Recipes.clicked(link)
  if not str(link) or link:sub(1, 6) ~= "trade:" then return end
  local click = { at = now(), who = whose(link:match("^trade:([^:]+):")) }
  pending = click
  note("V60b", "link of " .. click.who .. " clicked")
  after(Recipes.WAIT, function()
    if pending ~= click then return end
    pending = nil
    local seen = "link of " .. click.who .. " clicked, no linked window within " .. Recipes.WAIT .. " s"
    if click.who == "a friend offline" or click.who == "a friend online" then
      result("V60b", "fail", seen)
    else
      info("V60b", seen)
    end
  end)
end

function Recipes.opened()
  if not pending or now() - pending.at > Recipes.WAIT then return end
  local isLinked = call("IsTradeSkillLinked")
  if isLinked ~= true then return end -- the own window, or not yet the linked one
  local who = pending.who
  pending = nil
  local ids = call("GetAllRecipeIDs")
  local seen = "link of " .. who .. " opened Blizzard's view (IsTradeSkillLinked true, "
    .. (type(ids) == "table" and #ids or Val(ids)) .. " recipes)"
  if who == "a friend offline" then
    result("V60b", "pass", seen)
  else
    info("V60b", seen .. "; a friend's link while they are offline still to see")
  end
end

LaunchProbe.hook("SetItemRef", function(link) Recipes.clicked(link) end)
on("TRADE_SKILL_SHOW", Recipes.opened)
on("TRADE_SKILL_DATA_SOURCE_CHANGED", Recipes.opened)

LaunchProbe.recipes = Recipes
