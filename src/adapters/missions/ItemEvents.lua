-- ItemEvents: the events of the items missions (CF-75). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/Items.lua.
-- Created and looted items (LootInfo's CHAT_MSG_LOOT, V83, V105) with the open loot's sources (LOOT_OPENED,
-- GetLootSourceInfo, V106); bag items used (UNIT_SPELLCAST_SENT and _SUCCEEDED for the player, C_Item.GetItemSpell,
-- V95, V116, V117); recipes (NEW_RECIPE_LEARNED, V104); coins (CHAT_MSG_MONEY, V109); gear put on
-- (PLAYER_EQUIPMENT_CHANGED, V113); auras out of combat (UNIT_AURA, C_UnitAuras.GetAuraDataByIndex, V110); grey
-- items in the bags (C_Container.GetContainerItemInfo, V112). Item classes and subclasses from
-- C_Item.GetItemInfoInstant. Every call is guarded; the unverified ones are in VERIFY.md (CF-75).
-- Local stored data: self.doomsday.worn (see Items).
local _, ns = ...

local ItemEvents = {}

local readable, call = ns.Safe.value, ns.Safe.call
local BAGS = 4               -- backpack (0) and the four bags
local EQUIP_SLOTS = 19       -- INVSLOT_FIRST_EQUIPPED .. INVSLOT_LAST_EQUIPPED
local LOOT_GRACE = 3         -- seconds after the loot window closed that its sources still count
local USE_WAIT = 2           -- seconds to wait for the bags after a cast before resolving it anyway
local RECIPE_WAIT = 2.5      -- a learned recipe is read after the recipe item's use resolved
local AURA_EVERY = 2         -- seconds between aura scans of one unit
local addonRef, events

local itemInfo = {}          -- itemID -> { class, subclass, spell } (static, cached)
local counts = {}            -- itemID -> count in the bags at the last scan
local spellItems = {}        -- spellID -> { { id, class, subclass } } of the bag items whose use casts it
local pending = {}           -- casts waiting for the bags: { candidates, before, target, guid }
local sent = {}              -- castGUID -> target name (UNIT_SPELLCAST_SENT)
local sentCount = 0
local lootSources, lootUntil -- the open loot's source kinds; how long they still count after it closed
local lastRecipe             -- { subclass, at } of the last recipe item used
local lastJunk, wasFed, buffDay
local auraAt = {}

local function own() return addonRef.db.global.self end

local function doomsday()
  local s = own()
  s.doomsday = s.doomsday or {}
  return s.doomsday
end

local function send(kind, obs)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs)
end

local function now() return GetTime and GetTime() or 0 end

local function members()
  local ok, list = pcall(ns.MemberTracker.members)
  return ok and type(list) == "table" and list or {}
end

-- Whether a GUID is a friend's community character (Records' rule, CF-72).
local function isFriend(guid)
  if type(guid) ~= "string" then return false end
  local g = addonRef.db.global
  return ns.Missions.Records.friendGrouped({ guid }, members(), g.people, g.presence, own().battleTag)
end

-- class, subclass and use spell of an item ID (C_Item.GetItemInfoInstant, C_Item.GetItemSpell).
local function info(id)
  if type(id) ~= "number" then return {} end
  local cached = itemInfo[id]
  if cached and cached.class ~= nil then return cached end
  local entry = {}
  if C_Item and C_Item.GetItemInfoInstant then
    entry.class, entry.subclass = select(6, call(C_Item.GetItemInfoInstant, id))
  end
  if C_Item and C_Item.GetItemSpell then
    local spell = select(2, call(C_Item.GetItemSpell, id))
    entry.spell = type(spell) == "number" and spell or nil
  end
  itemInfo[id] = entry
  return entry
end

local function quality(id)
  if not (C_Item and C_Item.GetItemQualityByID and type(id) == "number") then return nil end
  local q = call(C_Item.GetItemQualityByID, id)
  return type(q) == "number" and q or nil
end

-- ===== Bags =====

local function resolve(cast, after)
  local item = ns.Missions.Items.usedItem(cast.candidates, cast.before, after)
  if not item then return end
  if item.class == ns.Missions.Items.RECIPE then lastRecipe = { subclass = item.subclass, at = now() } end
  send("itemUsed", {
    guid = cast.guid, id = item.id, class = item.class, subclass = item.subclass,
    self = ns.Missions.Items.onSelf(cast.target, cast.ownForms),
    friend = isFriend(cast.targetGuid),
  })
end

local function flush(after)
  local list = pending
  pending = {}
  for _, cast in ipairs(list) do resolve(cast, after) end
end

-- Reads the bags: item counts, the items each spell comes from, and the grey items.
local function scan()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
  local newCounts, newSpells, junk = {}, {}, 0
  for bag = 0, BAGS do
    for slot = 1, call(C_Container.GetContainerNumSlots, bag) or 0 do
      local item = call(C_Container.GetContainerItemInfo, bag, slot)
      local id = type(item) == "table" and readable(item.itemID)
      if type(id) == "number" then
        local entry = info(id)
        if entry.spell and not newCounts[id] then -- the first stack of this item
          newSpells[entry.spell] = newSpells[entry.spell] or {}
          table.insert(newSpells[entry.spell], { id = id, class = entry.class, subclass = entry.subclass })
        end
        local stack = readable(item.stackCount)
        newCounts[id] = (newCounts[id] or 0) + (type(stack) == "number" and stack or 1)
        if readable(item.quality) == 0 then junk = junk + 1 end
      end
    end
  end
  flush(newCounts)
  counts, spellItems = newCounts, newSpells
  local guid = ns.SelfInfo.guid()
  if guid and junk ~= lastJunk then
    lastJunk = junk
    send("itemBags", { guid = guid, junk = junk })
  end
end

-- ===== Casts =====

-- The names of a unit (Items.nameForms); GetUnitName and UnitName are verified (V9).
local function names(unit)
  local full = GetUnitName and readable(GetUnitName(unit, true))
  local name, second = UnitName(unit)
  return ns.Missions.Items.nameForms(full, readable(name), readable(second))
end

-- The GUID of a unit around the player with that name.
local function guidOfName(name)
  if type(name) ~= "string" or name == "" then return nil end
  local units = { "target", "focus", "mouseover" }
  for i = 1, 4 do units[#units + 1] = "party" .. i end
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
  end
  for _, unit in ipairs(units) do
    if UnitExists == nil or UnitExists(unit) then
      if ns.Missions.Items.sameName(name, names(unit)) then
        local guid = readable(UnitGUID(unit))
        if type(guid) == "string" then return guid end
      end
    end
  end
  return nil
end

local function onSent(_, unit, target, castGUID)
  if unit ~= "player" or readable(castGUID) == nil then return end
  if sentCount > 20 then sent, sentCount = {}, 0 end
  sent[castGUID] = readable(target) or ""
  sentCount = sentCount + 1
end

local function onSucceeded(_, unit, castGUID, spellID)
  if unit ~= "player" then return end
  spellID = readable(spellID)
  local candidates = type(spellID) == "number" and spellItems[spellID]
  if not candidates then return end
  local target = readable(castGUID) and sent[castGUID] or nil
  local before = {}
  for id, n in pairs(counts) do before[id] = n end
  pending[#pending + 1] = { candidates = candidates, before = before, target = target, ownForms = names("player"),
                            targetGuid = guidOfName(target), guid = ns.SelfInfo.guid() }
  C_Timer.NewTimer(USE_WAIT, function()
    if #pending > 0 then scan() end
  end)
end

-- ===== Loot, coins, recipes =====

local function onLootOpened()
  lootSources, lootUntil = {}, nil
  for slot = 1, call(GetNumLootItems) or 0 do
    local guid = call(GetLootSourceInfo, slot)
    local kind = type(guid) == "string" and guid:match("^(%a+)")
    if kind then lootSources[kind] = true end
  end
end

local function onLootClosed()
  lootUntil = now() + LOOT_GRACE
end

local function onLoot(text)
  local item = ns.Loot.parse(text, ns.LootInfo.formats())
  local guid = item and ns.SelfInfo.guid()
  if not guid then return end
  local entry = info(item.id)
  if item.source == "created" then
    send("itemCreated", { guid = guid, id = item.id, count = item.count, class = entry.class,
                          subclass = entry.subclass, quality = quality(item.id) })
    return
  end
  local sources = (lootSources and (lootUntil == nil or now() <= lootUntil)) and lootSources or {}
  send("itemLooted", { guid = guid, id = item.id, count = item.count, class = entry.class, subclass = entry.subclass,
                       node = sources.GameObject == true, creature = sources.Creature == true })
end

local function onMoney(_, text)
  local formats = { readable(YOU_LOOT_MONEY), readable(LOOT_MONEY_SPLIT) }
  if ns.Missions.Items.coinMessage(readable(text), formats) then
    local guid = ns.SelfInfo.guid()
    if guid then send("itemCoins", { guid = guid }) end
  end
end

-- The recipe's profession and the item it makes: C_TradeSkillUI, unverified on Forever (VERIFY.md CF-75).
local function onRecipe(recipeID)
  local guid = ns.SelfInfo.guid()
  recipeID = readable(recipeID)
  if not guid or recipeID == nil then return end
  local obs = { guid = guid, id = recipeID }
  local ui = C_TradeSkillUI
  if ui and ui.GetTradeSkillLineForRecipe then
    local line, _, parent = call(ui.GetTradeSkillLineForRecipe, recipeID)
    obs.skillLine, obs.parentSkillLine = line, parent
  end
  if ui and ui.GetRecipeSchematic then
    local schematic = call(ui.GetRecipeSchematic, recipeID, false)
    local output = type(schematic) == "table" and readable(schematic.outputItemID)
    if type(output) == "number" then
      local entry = info(output)
      obs.outputClass, obs.outputSubclass = entry.class, entry.subclass
    end
  end
  if lastRecipe and now() - lastRecipe.at <= 10 then obs.recipeSubclass = lastRecipe.subclass end
  send("itemRecipe", obs)
end

-- ===== Gear =====

local function equipped()
  local list = {}
  for slot = 1, EQUIP_SLOTS do
    local id = call(GetInventoryItemID, "player", slot)
    if type(id) == "number" then list[#list + 1] = id end
  end
  return list
end

local function worn()
  local d = doomsday()
  d.worn = d.worn or {}
  return d.worn
end

local function onEquip(_, slot)
  local guid = ns.SelfInfo.guid()
  local id = guid and call(GetInventoryItemID, "player", readable(slot))
  if type(id) ~= "number" then return end
  local new = ns.Missions.Items.markWorn(worn(), guid, id, equipped())
  send("itemEquip", { guid = guid, id = id, quality = quality(id), new = new })
end

-- ===== Auras =====

local function scanAuras(unit)
  local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not byIndex or (InCombatLockdown and InCombatLockdown()) then return end
  if auraAt[unit] and now() - auraAt[unit] < AURA_EVERY then return end
  auraAt[unit] = now()
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  local fed, mine = false, false
  for i = 1, 40 do
    local aura = call(byIndex, unit, i, "HELPFUL")
    if type(aura) ~= "table" then break end
    if unit == "player" and ns.Missions.Items.isWellFed(readable(aura.name)) then fed = true end
    if unit ~= "player" and readable(aura.sourceUnit) == "player" then mine = true end
  end
  if unit == "player" then
    if fed and not wasFed then send("itemAura", { guid = guid, wellFed = true }) end
    wasFed = fed
  elseif mine then
    local today = ns.DoomsdayTracker.today()
    if buffDay ~= today and isFriend(readable(UnitGUID(unit))) then
      buffDay = today
      send("itemAura", { guid = guid, friend = true })
    end
  end
end

local function onAura(_, unit)
  if unit == "player" or (type(unit) == "string" and (unit:match("^party%d$") or unit:match("^raid%d+$"))) then
    scanAuras(unit)
  end
end

local function afterCombat()
  auraAt = {}
  scanAuras("player")
  for _, unit in ipairs({ "party1", "party2", "party3", "party4" }) do scanAuras(unit) end
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function ItemEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterMessage would replace other services' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  local register = function(event, fn) ns.Events.register(events, event, fn) end
  events:RegisterMessage(ns.LootInfo.CHANGED, function(_, reason, text)
    if reason == "loot" then onLoot(text) end
  end)
  register("LOOT_OPENED", onLootOpened)
  register("LOOT_CLOSED", onLootClosed)
  register("BAG_UPDATE_DELAYED", scan)
  register("UNIT_SPELLCAST_SENT", onSent)
  register("UNIT_SPELLCAST_SUCCEEDED", onSucceeded)
  register("CHAT_MSG_MONEY", onMoney)
  register("NEW_RECIPE_LEARNED", function(_, recipeID)
    C_Timer.NewTimer(RECIPE_WAIT, function() onRecipe(recipeID) end)
  end)
  register("PLAYER_EQUIPMENT_CHANGED", onEquip)
  register("UNIT_AURA", onAura)
  register("PLAYER_REGEN_ENABLED", afterCombat)
  -- What the character wears now is not new to it (the first start with CF-75, or its first login since).
  C_Timer.NewTimer(5, function()
    local guid = ns.SelfInfo.guid()
    if guid then ns.Missions.Items.markWorn(worn(), guid, nil, equipped()) end
    scan()
    scanAuras("player")
  end)
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.Items = ItemEvents
return ItemEvents
