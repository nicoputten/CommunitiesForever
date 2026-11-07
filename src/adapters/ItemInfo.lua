-- ItemInfo: what the game knows of an item by its ID, for the Dungeons tab's loot rows (CF-106). Thin wrapper, raw
-- values only. Item info loads asynchronously (V83): a name is nil until the item is cached, so the tab asks the
-- game to load it and redraws on GET_ITEM_INFO_RECEIVED. C_Item.GetItemInfoInstant and GetItemQualityByID are
-- verified (V105); C_Item.GetItemInfo, C_Item.RequestLoadItemDataByID, GetItemIconByID, GET_ITEM_INFO_RECEIVED,
-- GameTooltip:SetItemByID and C_QuestLog.GetTitleForQuestID are not (VERIFY.md CF-106): all guarded.
local _, ns = ...

local ItemInfo = {}

local readable = ns.Safe.value
local requested = {}

--[[ { name, link, quality, icon, equipLoc } of an item ID; each nil while unknown. Asks the game to load an item it
hasn't cached yet (once per session). ]]
function ItemInfo.get(id)
  local out = {}
  if type(id) ~= "number" then return out end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo then
    local ok, name, link, quality, _, _, _, _, _, equipLoc, icon = pcall(getInfo, id)
    if ok then
      out.name, out.link, out.quality = readable(name), readable(link), readable(quality)
      out.equipLoc, out.icon = readable(equipLoc), readable(icon)
    end
  end
  if C_Item and C_Item.GetItemInfoInstant then
    local ok, _, _, _, equipLoc, icon = pcall(C_Item.GetItemInfoInstant, id)
    if ok then
      out.equipLoc = out.equipLoc or readable(equipLoc)
      out.icon = out.icon or readable(icon)
    end
  end
  if out.quality == nil and C_Item and C_Item.GetItemQualityByID then
    local ok, quality = pcall(C_Item.GetItemQualityByID, id)
    if ok then out.quality = readable(quality) end
  end
  if out.icon == nil and C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, id)
    if ok then out.icon = readable(icon) end
  end
  if out.equipLoc == "" then out.equipLoc = nil end
  if out.name == nil and not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
    requested[id] = true
    pcall(C_Item.RequestLoadItemDataByID, id)
  end
  return out
end

-- Calls handler() when the game has loaded an item it was asked for (GET_ITEM_INFO_RECEIVED, guarded).
function ItemInfo.watch(target, handler)
  return ns.Events.register(target, "GET_ITEM_INFO_RECEIVED", function() handler() end)
end

-- The game's own item tooltip on owner: SetItemByID, else SetHyperlink with "item:<id>". False without either.
function ItemInfo.tooltip(owner, id)
  if not (GameTooltip and GameTooltip.SetOwner) then return false end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local ok = false
  if GameTooltip.SetItemByID then
    ok = pcall(GameTooltip.SetItemByID, GameTooltip, id)
  elseif GameTooltip.SetHyperlink then
    ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(id))
  end
  if ok then GameTooltip:Show() end
  return ok
end

-- A quest's title by its ID (C_QuestLog.GetTitleForQuestID, guarded), or nil.
function ItemInfo.questTitle(id)
  if not (C_QuestLog and C_QuestLog.GetTitleForQuestID and type(id) == "number") then return nil end
  local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
  return ok and readable(title) or nil
end

-- True while Shift is held (the chat link click).
function ItemInfo.shift()
  return IsShiftKeyDown ~= nil and IsShiftKeyDown() == true
end

ns.ItemInfo = ItemInfo
return ItemInfo
