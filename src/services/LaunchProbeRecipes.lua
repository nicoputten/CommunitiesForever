--[[ LaunchProbeRecipes (CF-98): the hidden probe's recipe checks for CF-38, ported from FriendProbe's `/fp recipes`
(PR #63, never merged). Same rules as services/LaunchProbe.lua: silent, guarded, cheap.
- V60: what the profession API gives while your own profession window is open (C_TradeSkillUI): which functions
  exist, the profession's IDs, how many recipes and how many learned, and where the item a recipe makes comes from.
  Only counts and IDs (recipe, item, profession), no recipe or player names. The scan stops once it passed.
- V60b: does a clicked profession link ("trade:") open Blizzard's view of someone else, also while they are offline?
  Only seen when someone clicks such a link: a post-hook on SetItemRef notes the click (never acts), and a
  TRADE_SKILL_SHOW with IsTradeSkillLinked within 5 s answers it. Whose link it was is kept as "yours", "a friend
  online", "a friend offline" or "someone else": no GUID, no name. ]]
local _, ns = ...

local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, readable, str, get = u.Val, u.readable, u.str, u.get
local result, note, info, passed, after, now = u.result, u.note, u.info, u.passed, u.after, u.now
local on = LaunchProbe.on

local Recipes = {}

-- The C_TradeSkillUI functions CF-38 might use (V60 lists the missing ones).
Recipes.FUNCTIONS = { "GetAllRecipeIDs", "GetRecipeInfo", "GetRecipeItemLink", "GetRecipeOutputItemData",
                      "GetRecipeSchematic", "GetBaseProfessionInfo", "GetChildProfessionInfo",
                      "GetTradeSkillListLink", "IsTradeSkillLinked", "OpenTradeSkill" }
Recipes.EVERY = 10   -- seconds between two scans of the open window (TRADE_SKILL_LIST_UPDATE fires in bursts)
Recipes.WAIT = 5     -- seconds a clicked profession link has to open the window
Recipes.SAMPLES = 2  -- learned recipes noted with their item IDs

local function T() return C_TradeSkillUI end

-- The first return of C_TradeSkillUI[name](...) when readable.
local function call(name, ...)
  local api = T()
  return get(api and api[name], ...)
end

local function linked()
  return call("IsTradeSkillLinked") == true
end

-- An item ID from a value: a number, or the first "item:<id>" in a link.
local function itemId(v)
  if type(v) == "number" and readable(v) then return v end
  if str(v) then return tonumber(v:match("item:(%d+)")) end
  return nil
end

-- The item a recipe makes, by each way the API might give it: { output = id, link = id, schematic = id }.
local function items(recipeID)
  local output = call("GetRecipeOutputItemData", recipeID)
  local schematic = call("GetRecipeSchematic", recipeID, false)
  return {
    output = type(output) == "table" and itemId(output.itemID) or nil,
    link = itemId(call("GetRecipeItemLink", recipeID)),
    schematic = type(schematic) == "table" and itemId(schematic.outputItemID) or nil,
  }
end

local function professionId(profession)
  if type(profession) ~= "table" then return Val(profession) end
  return Val(profession.professionID)
end

-- ===== V60: reading the own profession window =====

local scannedAt
function Recipes.scan(event)
  if passed("V60") or linked() then return end -- someone else's recipes are V60b's
  if scannedAt and now() - scannedAt < Recipes.EVERY then return end
  scannedAt = now()
  local api = T()
  if type(api) ~= "table" then
    result("V60", "fail", "C_TradeSkillUI missing")
    return
  end
  local missing = {}
  for _, name in ipairs(Recipes.FUNCTIONS) do
    if type(api[name]) ~= "function" then missing[#missing + 1] = name end
  end
  if #missing > 0 then note("V60", "missing: " .. table.concat(missing, ", ")) end
  local profession = "base " .. professionId(call("GetBaseProfessionInfo")) .. ", child "
    .. professionId(call("GetChildProfessionInfo"))
  local ids = call("GetAllRecipeIDs")
  if type(ids) ~= "table" then
    result("V60", "fail", event .. ": GetAllRecipeIDs " .. Val(ids) .. "; " .. profession)
    return
  end
  local learned, samples, found = 0, {}, {}
  for _, id in ipairs(ids) do
    local recipe = call("GetRecipeInfo", id)
    if type(recipe) == "table" and recipe.learned == true then
      learned = learned + 1
      if #samples < Recipes.SAMPLES then
        local made = items(id)
        for way, item in pairs(made) do found[way] = found[way] or item ~= nil end
        samples[#samples + 1] = string.format("recipe %s: output %s, link %s, schematic %s", Val(id),
          Val(made.output), Val(made.link), Val(made.schematic))
      end
    end
  end
  for _, line in ipairs(samples) do note("V60", line) end
  local ways = {}
  for _, way in ipairs({ "output", "link", "schematic" }) do
    if found[way] then ways[#ways + 1] = way end
  end
  local listLink = call("GetTradeSkillListLink")
  local detail = string.format("%s; %d recipes, %d learned; item from %s; list link %s", profession, #ids, learned,
    #ways > 0 and table.concat(ways, "/") or "none", str(listLink) and listLink:find("trade:", 1, true) and "yes"
      or Val(listLink))
  if learned > 0 and #ways > 0 then
    result("V60", "pass", detail)
  elseif #ids > 0 and learned > 0 then
    result("V60", "fail", detail)
  else
    info("V60", event .. ": " .. detail) -- the list may still load (TRADE_SKILL_LIST_UPDATE scans again)
  end
end

on("TRADE_SKILL_SHOW", function() Recipes.scan("TRADE_SKILL_SHOW") end)
on("TRADE_SKILL_LIST_UPDATE", function() Recipes.scan("TRADE_SKILL_LIST_UPDATE") end)
on("TRADE_SKILL_DATA_SOURCE_CHANGED", function() Recipes.scan("TRADE_SKILL_DATA_SOURCE_CHANGED") end)

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
