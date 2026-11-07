--[[ LaunchProbeRecipes (CF-98): the hidden probe's recipe check for CF-38. Same rules as services/LaunchProbe.lua:
silent, guarded, cheap. CF-105: V60 and V60c are answered (docs/API-FINDINGS.md "Forever launch probe") and gone;
only V60b is left.
- V60b: does a clicked profession link ("trade:") open Blizzard's view of someone else, also while they are offline?
  Only seen when someone clicks such a link: a post-hook on SetItemRef notes the click (never acts). Whose link it
  was is kept as "yours", "a friend online", "a friend offline" or "someone else" (plus "other server", CF-107): no
  GUID, no name.
- CF-109: build 70862 reported "no linked window" for links that did open (Nico: his own, from the Friends tab). The
  check only looked at TRADE_SKILL_SHOW and TRADE_SKILL_DATA_SOURCE_CHANGED, and only after the post-hook: a window
  that opens inside SetItemRef (before the hook) or turns linked later was missed, and the own link may open the
  own, unlinked window. Now the window is looked at right after the click, on each trade skill event
  (TRADE_SKILL_LIST_UPDATE too) and once a second until WAIT; Blizzard's frame (ProfessionsFrame, load on demand, or
  TradeSkillFrame; unverified, looked up by name each time) counts as opened. A click that opened nothing logs
  what was seen ("seen: events …"). ]]
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

-- CF-109: Blizzard's profession frame, by global name, when it exists and is shown (Blizzard_Professions loads on
-- demand, so it is looked up each time; unverified on Forever, VERIFY.md V60b): the name, or nil.
Recipes.FRAMES = { "ProfessionsFrame", "TradeSkillFrame" }
local function shownFrame()
  for _, name in ipairs(Recipes.FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" and type(frame.IsShown) == "function" then
      local ok, shown = pcall(frame.IsShown, frame)
      if ok and shown == true then return name end
    end
  end
  return nil
end

local pending -- { at, who, other, events }: the last clicked profession link, until the window opens or WAIT runs out

local function label(click)
  return click.who .. (click.other and ", other server" or "")
end

-- Is the clicked link's window open? Linked (IsTradeSkillLinked true) answers it; for the own link the own window
-- (a trade skill event since the click, or Blizzard's frame shown) does too. Returns true once answered.
function Recipes.check(click)
  if pending ~= click then return false end
  local isLinked = call("IsTradeSkillLinked")
  local frame = shownFrame()
  local who = label(click)
  if isLinked == true then
    pending = nil
    local ids = call("GetAllRecipeIDs")
    local seen = "link of " .. who .. " opened Blizzard's view (IsTradeSkillLinked true, "
      .. (type(ids) == "table" and #ids or Val(ids)) .. " recipes)"
    if click.who == "a friend offline" then
      result("V60b", "pass", seen)
    else
      info("V60b", seen .. "; a friend's link while they are offline still to see")
    end
    return true
  end
  if click.who == "yours" and (frame or #click.events > 0) then
    pending = nil
    info("V60b", "link of " .. who .. " opened Blizzard's window (" .. (frame or click.events[1])
      .. ", IsTradeSkillLinked " .. Val(isLinked) .. ")")
    return true
  end
  return false
end

function Recipes.clicked(link)
  if not str(link) or link:sub(1, 6) ~= "trade:" then return end
  local guid = link:match("^trade:([^:]+):")
  local click = { at = now(), who = whose(guid), other = ns.Recipes.otherServer(get(UnitGUID, "player"), guid),
                  events = {} }
  pending = click
  note("V60b", "link of " .. label(click) .. " clicked")
  if Recipes.check(click) then return end -- the window may open inside SetItemRef, before this post-hook
  for second = 1, Recipes.WAIT - 1 do
    after(second, function() Recipes.check(click) end)
  end
  after(Recipes.WAIT, function()
    if Recipes.check(click) then return end
    if pending ~= click then return end
    pending = nil
    local frame = shownFrame()
    note("V60b", "seen: events " .. (#click.events > 0 and table.concat(click.events, ", ") or "none")
      .. "; IsTradeSkillLinked " .. Val(call("IsTradeSkillLinked")) .. "; frame " .. (frame or "none shown"))
    local seen = "link of " .. label(click) .. " clicked, no linked window within " .. Recipes.WAIT .. " s"
    if (click.who == "a friend offline" or click.who == "a friend online") and not click.other and not frame then
      result("V60b", "fail", seen)
    else
      info("V60b", seen)
    end
  end)
end

function Recipes.opened(event)
  local click = pending
  if not click or now() - click.at > Recipes.WAIT then return end
  click.events[#click.events + 1] = event
  Recipes.check(click)
end

LaunchProbe.hook("SetItemRef", function(link) Recipes.clicked(link) end)
for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_LIST_UPDATE" }) do
  on(event, function() Recipes.opened(event) end)
end

LaunchProbe.recipes = Recipes
