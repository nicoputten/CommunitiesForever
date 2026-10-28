-- LootInfo: own loot messages, item quality and slot, and money (CF-53). Thin wrapper: raw values only,
-- the rules are in core/Loot.lua. Unverified on Forever (VERIFY.md V82, V83): guarded, missing values are nil.
local _, ns = ...

local LootInfo = {}

-- Internal message: (reason, ...). Reasons: "loot" (text), "money".
LootInfo.CHANGED = "CF_LOOT_CHANGED"

local readable = ns.Safe.value

-- The game's loot strings (Loot.parse); nil when missing.
function LootInfo.formats()
  return {
    looted = readable(LOOT_ITEM_SELF), lootedMultiple = readable(LOOT_ITEM_SELF_MULTIPLE),
    pushed = readable(LOOT_ITEM_PUSHED_SELF), pushedMultiple = readable(LOOT_ITEM_PUSHED_SELF_MULTIPLE),
    created = readable(LOOT_ITEM_CREATED_SELF), createdMultiple = readable(LOOT_ITEM_CREATED_SELF_MULTIPLE),
  }
end

-- quality (nil when the item is not cached yet), equip slot (INVTYPE_* or "") of an item ID.
function LootInfo.item(id)
  if not (C_Item and type(id) == "number") then return nil end
  local quality, slot
  if C_Item.GetItemQualityByID then quality = readable(C_Item.GetItemQualityByID(id)) end
  if C_Item.GetItemInfoInstant then slot = readable(select(4, C_Item.GetItemInfoInstant(id))) end
  return quality, slot
end

-- The character's money in copper, or nil.
function LootInfo.money()
  if not GetMoney then return nil end
  local money = readable(GetMoney())
  return type(money) == "number" and money or nil
end

function LootInfo.watch(addon)
  ns.Events.register(addon, "CHAT_MSG_LOOT", function(_, text)
    addon:SendMessage(LootInfo.CHANGED, "loot", text)
  end)
  ns.Events.register(addon, "PLAYER_MONEY", function()
    addon:SendMessage(LootInfo.CHANGED, "money")
  end)
end

ns.LootInfo = LootInfo
return LootInfo
