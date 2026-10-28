-- GoalEvents: fishing loot, trades and discoveries for Doomsday goals that wait for data (CF-56). Thin
-- wrapper: raw values only. All unverified on Forever (VERIFY.md V84 to V86): every call guarded.
local _, ns = ...

local GoalEvents = {}

-- Internal message: (reason, ...). Reasons: "fish" (count), "trade" (partner GUID, { itemID, ... } given),
-- "discovered" (text).
GoalEvents.CHANGED = "CF_GOAL_EVENT"

local function readable(value)
  if issecretvalue and issecretvalue(value) then return nil end
  return value
end

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return readable(a), readable(b)
end

-- The game's discovery strings (ERR_ZONE_EXPLORED "Discovered: %s", ERR_ZONE_EXPLORED_XP).
function GoalEvents.formats()
  return { readable(ERR_ZONE_EXPLORED), readable(ERR_ZONE_EXPLORED_XP) }
end

-- The trade in progress: partner GUID and the item IDs you put in (TRADE_SHOW, TRADE_PLAYER_ITEM_CHANGED).
local partner, given = nil, {}

local function readGiven()
  given = {}
  for slot = 1, 6 do
    local link = call(GetTradePlayerItemLink, slot)
    local id = type(link) == "string" and tonumber(link:match("|Hitem:(%d+)"))
    if id then given[#given + 1] = id end
  end
end

function GoalEvents.watch(addon)
  local events = LibStub("AceEvent-3.0"):Embed({})
  ns.Events.register(events, "LOOT_OPENED", function()
    if call(IsFishingLoot) then
      local count = call(GetNumLootItems)
      if type(count) == "number" and count > 0 then addon:SendMessage(GoalEvents.CHANGED, "fish", count) end
    end
  end)
  ns.Events.register(events, "TRADE_SHOW", function()
    partner, given = call(UnitGUID, "NPC"), {}
  end)
  ns.Events.register(events, "TRADE_PLAYER_ITEM_CHANGED", readGiven)
  ns.Events.register(events, "UI_INFO_MESSAGE", function(_, _, text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    if ERR_TRADE_COMPLETE and text == ERR_TRADE_COMPLETE then
      if partner then addon:SendMessage(GoalEvents.CHANGED, "trade", partner, given) end
      partner, given = nil, {}
    else
      addon:SendMessage(GoalEvents.CHANGED, "discovered", text)
    end
  end)
  ns.Events.register(events, "CHAT_MSG_SYSTEM", function(_, text)
    if type(text) == "string" then addon:SendMessage(GoalEvents.CHANGED, "discovered", text) end
  end)
end

ns.GoalEvents = GoalEvents
return GoalEvents
