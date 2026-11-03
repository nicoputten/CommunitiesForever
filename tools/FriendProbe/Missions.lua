-- Missions: checks for the Doomsday mission catalogue (docs/DOOMSDAY-CATALOGUE-DRAFT.md, VERIFY.md V90 to V119).
-- Each logs what the game gives and ticks its checklist item once the API answered. Like the rest of the probe:
-- silent (nothing in chat), every call guarded, only while ns.running().
local _, ns = ...

local log, result, S, Val, Vals, Pattern = ns.log, ns.result, ns.S, ns.Val, ns.Vals, ns.Pattern

local function readable(v)
  return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function str(v)
  return type(v) == "string" and readable(v) and v ~= ""
end

local function passed(id)
  local r = ns.results()[id]
  return r and r.status == "pass"
end

-- A result that never overwrites a pass with an info line.
local function info(id, detail)
  if not passed(id) then result(id, "info", detail) end
end

-- Pattern of a game format string, matching at the start only (the XP message has variants with bonus text).
local function Prefix(format)
  if type(format) ~= "string" then return nil end
  local p = Pattern((format:gsub("%.$", "")))
  return p and p:sub(1, -2)
end

local function matches(text, ...)
  if type(text) ~= "string" then return nil end
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    local p = Pattern(_G[key])
    if p and text:match(p) then return key end
  end
end

local function itemId(link)
  return type(link) == "string" and tonumber(link:match("|Hitem:(%d+)")) or nil
end

-- Class and subclass of an item (C_Item.GetItemInfoInstant: id, type, subtype, equipLoc, icon, classID, subclassID).
local function itemClass(id)
  if not (id and C_Item and C_Item.GetItemInfoInstant) then return "missing" end
  local ok, _, itemType, subType, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
  if not ok then return "error" end
  return string.format("class %s/%s (%s, %s)", Val(classID), Val(subclassID), Val(itemType), Val(subType))
end

local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return Vals(C_Spell.GetSpellName, id) end
  return Vals(GetSpellInfo, id)
end

-- ===== V93: creatures seen (for V90's kills) =====
local creatures = {} -- name -> { classification, level, at }

local function Creature(unit, source)
  if not (UnitExists and UnitExists(unit)) or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
  if not (UnitCanAttack and UnitCanAttack("player", unit)) then return end
  local name = UnitName(unit)
  local classification = UnitClassification and UnitClassification(unit)
  local level = UnitLevel and UnitLevel(unit)
  if not str(name) then
    result("V93", "fail", "creature name " .. Val(name) .. " via " .. source)
    return
  end
  local seen = creatures[name]
  creatures[name] = { classification = classification, level = level, at = GetTime() }
  if seen and GetTime() - seen.at < 60 then return end
  log("V93 creature", source, name, "classification", Val(classification), "level", Val(level))
  if readable(classification) and type(level) == "number" then
    result("V93", "pass", string.format("%s: %s, level %s via %s", name, S(classification), S(level), source))
  else
    result("V93", "fail", "classification " .. Val(classification) .. ", level " .. Val(level) .. " via " .. source)
  end
end

-- ===== V90: kills from the XP message =====
local function XpGain(text)
  log("V90 XP message", Val(text), "| group", Vals(IsInGroup))
  local p = Prefix(COMBATLOG_XPGAIN_FIRSTPERSON)
  local victim, xp
  if p and type(text) == "string" then victim, xp = text:match(p) end
  if not victim then
    if p then info("V90", "XP message did not match: " .. S(text):sub(1, 80)) end
    if not p then result("V90", "fail", "COMBATLOG_XPGAIN_FIRSTPERSON missing") end
    return
  end
  local seen = creatures[victim]
  local detail = string.format("%s dies, %s XP%s", victim, S(xp), IsInGroup and IsInGroup() and ", in a group" or "")
  if seen then
    detail = detail .. string.format(", seen as %s level %s", Val(seen.classification), Val(seen.level))
  end
  log("V90 kill", detail)
  result("V90", "pass", detail)
end

-- ===== V94: flights =====
local function ControlLost()
  if not C_Timer then return end
  C_Timer.After(3, function()
    local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
    log("V94 control lost, 3 s later UnitOnTaxi", Val(onTaxi))
    if onTaxi == true then result("V94", "pass", "UnitOnTaxi true after PLAYER_CONTROL_LOST") end
  end)
end

-- ===== V95, V116, V119: own spell casts, items used, the campfire =====
local spellsSeen = {}
local itemSpells = {} -- spellID -> itemID of a bag item whose use casts it
local campfireAt

local function ScanBags()
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return end
  local getSpell = C_Item and C_Item.GetItemSpell
  itemSpells = {}
  local qualities = 0
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local id = C_Container.GetContainerItemID(bag, slot)
      if type(id) == "number" and getSpell then
        local ok, _, spellID = pcall(getSpell, id)
        if ok and type(spellID) == "number" then itemSpells[spellID] = id end
      end
      -- V112: the quality of bag items.
      if C_Container.GetContainerItemInfo then
        local ok, item = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(item) == "table" and type(item.quality) == "number" then qualities = qualities + 1 end
      end
    end
  end
  if qualities > 0 then
    result("V112", "pass", qualities .. " bag items with a readable quality")
  else
    info("V112", "no bag item with a readable quality (GetContainerItemInfo " .. Val(C_Container.GetContainerItemInfo)
      .. ")")
  end
end

local function SpellCast(unit, _, spellID)
  if unit ~= "player" then return end
  if not (type(spellID) == "number" and readable(spellID)) then
    result("V95", "fail", "spell ID " .. Val(spellID))
    return
  end
  local name = spellName(spellID)
  if not spellsSeen[spellID] then
    spellsSeen[spellID] = true
    log("V95 cast", spellID, name)
  end
  result("V95", "pass", "spell " .. spellID .. " " .. name)
  local item = itemSpells[spellID]
  if item then
    local detail = string.format("item %d (%s) cast spell %d: %s", item, Vals(C_Item and C_Item.GetItemNameByID, item),
      spellID, itemClass(item))
    log("V116 item used", detail)
    result("V116", "pass", detail)
  end
  if spellID == 818 or name:lower():find("campfire", 1, true) then
    campfireAt = GetTime()
    log("V119 campfire lit", spellID, name)
    info("V119", "campfire lit: spell " .. spellID .. " " .. name .. "; now add items and look at the log")
  end
end

local function SpellSent(unit, target, _, spellID)
  if unit ~= "player" then return end
  log("V117 cast sent", Val(spellID), "target", Val(target))
  if str(target) then
    result("V117", "pass", "target " .. target .. " for spell " .. Val(spellID))
  else
    info("V117", "no target name (" .. Val(target) .. ") for spell " .. Val(spellID))
  end
end

-- ===== V110, V119: auras =====
local auraSeen = {}   -- unit .. spellId -> applications last logged
local auraAt = {}     -- unit -> GetTime() of the last scan

local function Auras(unit)
  if unit ~= "player" and not (type(unit) == "string" and unit:match("^party%d$")) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if auraAt[unit] and GetTime() - auraAt[unit] < 2 then return end
  auraAt[unit] = GetTime()
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not get then
    result("V110", "fail", "C_UnitAuras.GetAuraDataByIndex missing")
    return
  end
  for i = 1, 40 do
    local ok, aura = pcall(get, unit, i, "HELPFUL")
    if not ok or type(aura) ~= "table" then break end
    local key = unit .. ":" .. Val(aura.spellId)
    local nearFire = campfireAt and GetTime() - campfireAt < 600 and unit == "player"
    if auraSeen[key] ~= Val(aura.applications) then
      auraSeen[key] = Val(aura.applications)
      local line = string.format("%s %s (%s) from %s, stacks %s, points %s", unit, Val(aura.name), Val(aura.spellId),
        Val(aura.sourceUnit), Val(aura.applications), Vals(function() return unpack(aura.points or {}) end))
      log(nearFire and "V119 aura near the campfire" or "V110 aura", line)
      if nearFire then info("V119", "after the campfire: " .. line) end
    end
    if readable(aura.spellId) and readable(aura.sourceUnit) then
      if unit ~= "player" and aura.sourceUnit == "player" then
        result("V110", "pass", "own buff on " .. unit .. ": " .. Val(aura.name))
      else
        info("V110", "player auras readable (spellId, sourceUnit); a buff on a party member still to see")
      end
    end
  end
end

-- ===== V98: mounted and swimming, polled =====
local mounted, swimming = false, false
local function Poll()
  if not ns.running() then return end
  if IsMounted and IsMounted() == true and not mounted then
    mounted = true
    log("V98 IsMounted true")
  end
  if IsSwimming and IsSwimming() == true and not swimming then
    swimming = true
    log("V98 IsSwimming true")
  end
  if mounted and swimming then
    result("V98", "pass", "IsMounted and IsSwimming both read true")
  elseif mounted or swimming then
    info("V98", (mounted and "IsMounted" or "IsSwimming") .. " read true; the other still to see")
  end
end

-- ===== V99, V100, V108, V118: hooks (hooksecurefunc, post-hooks only) =====
local merchantOpen, merchantMoney, merchantAction = false, nil, nil
local mailTo
local whisperTarget, emoteSeen
local jumps = 0

local function hook(name, fn)
  if not (hooksecurefunc and _G[name]) then
    log("hook", name, "missing")
    return false
  end
  local ok, err = pcall(hooksecurefunc, name, function(...)
    if not ns.running() then return end
    local okRun, errRun = pcall(fn, ...)
    if not okRun then log("hook", name, "error", S(errRun)) end
  end)
  if not ok then log("hook", name, "error", S(err)) end
  return ok
end

local function Hooks()
  hook("RepairAllItems", function()
    merchantAction = "repair"
    log("V99 RepairAllItems while merchant open", S(merchantOpen))
  end)
  hook("BuyMerchantItem", function(index, quantity)
    merchantAction = "buy"
    local link = GetMerchantItemLink and GetMerchantItemLink(index)
    log("V99 BuyMerchantItem", Val(index), Val(quantity), Val(link), itemClass(itemId(link)))
  end)
  hook("SendMail", function(recipient)
    mailTo = recipient
    log("V100 SendMail to", Val(recipient))
  end)
  for _, name in ipairs({ "TakeInboxItem", "TakeInboxMoney", "AutoLootMailItem" }) do
    hook(name, function(index)
      local sender = GetInboxHeaderInfo and select(3, GetInboxHeaderInfo(index))
      log("V100 " .. name, Val(index), "sender", Val(sender))
    end)
  end
  hook("DoEmote", function(token)
    local enemy = UnitIsPlayer and UnitIsPlayer("target")
      and UnitFactionGroup("target") ~= UnitFactionGroup("player") and UnitFactionGroup("target") ~= nil
    log("V108 DoEmote", Val(token), "target", Vals(UnitGUID, "target"), "player", Vals(UnitIsPlayer, "target"),
      "faction", Vals(UnitFactionGroup, "target"), "enemy faction", S(enemy))
    emoteSeen = string.format("emote %s on %s", Val(token), enemy and "an enemy-faction player" or "no enemy player")
    if whisperTarget then
      result("V108", "pass", "whisper target " .. whisperTarget .. "; " .. emoteSeen)
    else
      info("V108", emoteSeen .. "; a whisper still to send")
    end
  end)
  local jumpHooked = hook("JumpOrAscendStart", function()
    jumps = jumps + 1
    if jumps % 10 == 0 then log("V118 jumps", jumps) end
    if jumps == 3 then result("V118", "pass", "the hook ran on 3 jumps") end
  end)
  if not jumpHooked then result("V118", "fail", "JumpOrAscendStart or hooksecurefunc missing") end
end

-- ===== Events =====
local EVENTS = { "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_XP_UPDATE", "ENCOUNTER_END", "PLAYER_TARGET_CHANGED",
  "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "PLAYER_CONTROL_LOST", "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM",
  "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT", "PLAYER_BINDING_CHANGED", "PLAYER_UPDATE_RESTING",
  "PLAYER_LOGOUT", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_SEND_SUCCESS", "AUCTION_HOUSE_SHOW",
  "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_PURCHASE_COMPLETED", "BANKFRAME_OPENED",
  "TRAINER_SHOW", "TRAINER_CLOSED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "NEW_RECIPE_LEARNED",
  "CHAT_MSG_LOOT", "LOOT_OPENED", "CHAT_MSG_SKILL", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM",
  "CHAT_MSG_MONEY", "UNIT_AURA", "SCREENSHOT_SUCCEEDED", "PLAYER_EQUIPMENT_CHANGED", "CONFIRM_SUMMON",
  "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "BAG_UPDATE_DELAYED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }

local trainerOpen = false
local subzones = {}

-- System and UI messages: flight paths, auctions, trainers, recipes.
local function Message(text)
  if type(text) ~= "string" or not readable(text) then return end
  if ERR_NEWTAXIPATH and text == ERR_NEWTAXIPATH then
    log("V94 new flight path message")
    info("V94", "new flight path message seen; a flight still to take")
  end
  local key = matches(text, "ERR_AUCTION_STARTED", "ERR_AUCTION_WON_S", "ERR_AUCTION_BID_PLACED")
  if key then
    log("V101 message", key, text)
    if key == "ERR_AUCTION_STARTED" then result("V101", "pass", "posted: " .. key) end
  end
  key = matches(text, "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S")
  if key then
    log("V103 learned", key, text, "trainer open", S(trainerOpen))
    if trainerOpen then result("V103", "pass", key .. " at a trainer: " .. text) end
  end
  key = matches(text, "ERR_LEARN_RECIPE_S")
  if key then
    log("V104 recipe message", text)
    result("V104", "pass", "ERR_LEARN_RECIPE_S: " .. text)
  end
end

local function Loot(text)
  if not matches(text, "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE") then return end
  local id = itemId(text)
  local quality = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
  local detail = string.format("created %s: %s, quality %s", Val(id), itemClass(id), Val(quality))
  log("V105", detail)
  if id and not itemClass(id):find("missing", 1, true) then result("V105", "pass", detail) end
end

local function LootOpened()
  local count = GetNumLootItems and GetNumLootItems()
  local fishing = IsFishingLoot and IsFishingLoot()
  local sources = {}
  for slot = 1, type(count) == "number" and count or 0 do
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
    local id = itemId(link)
    log("V106 loot slot", slot, "item", Val(id), id and itemClass(id) or "", "source", Val(guid), "fishing",
      Val(fishing))
    if str(guid) then sources[#sources + 1] = guid:match("^(%a+)") or guid end
  end
  if #sources > 0 then
    result("V106", "pass", "loot source " .. table.concat(sources, ", ") .. (fishing and " (fishing)" or ""))
  elseif type(count) == "number" and count > 0 then
    info("V106", "no readable loot source (GetLootSourceInfo " .. Val(GetLootSourceInfo) .. ")")
  end
end

local handlers = {
  CHAT_MSG_COMBAT_XP_GAIN = XpGain,
  PLAYER_XP_UPDATE = function()
    local xp, max = UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player")
    log("V91 XP", Val(xp), "of", Val(max))
    if type(xp) == "number" and type(max) == "number" and readable(xp) then
      result("V91", "pass", "UnitXP " .. xp .. " of UnitXPMax " .. max)
    else
      result("V91", "fail", "UnitXP " .. Val(xp) .. ", UnitXPMax " .. Val(max))
    end
  end,
  ENCOUNTER_END = function(encounterID, name, _, _, success)
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "raid" then return end
    log("V92 raid ENCOUNTER_END", Val(encounterID), Val(name), "success", Val(success))
    if success == 1 then result("V92", "pass", "raid boss " .. Val(name) .. " (" .. Val(encounterID) .. ")") end
  end,
  PLAYER_TARGET_CHANGED = function() Creature("target", "target") end,
  UPDATE_MOUSEOVER_UNIT = function() Creature("mouseover", "mouseover") end,
  NAME_PLATE_UNIT_ADDED = function(unit) Creature(unit, "nameplate") end,
  PLAYER_CONTROL_LOST = ControlLost,
  UI_INFO_MESSAGE = function(_, text) Message(text) end,
  CHAT_MSG_SYSTEM = function(text) Message(text) end,
  UNIT_SPELLCAST_SUCCEEDED = SpellCast,
  UNIT_SPELLCAST_SENT = SpellSent,
  PLAYER_BINDING_CHANGED = function()
    local place = GetBindLocation and GetBindLocation()
    log("V96 binding changed:", Val(place))
    result("V96", str(place) and "pass" or "fail", "GetBindLocation " .. Val(place))
  end,
  PLAYER_UPDATE_RESTING = function()
    local resting = IsResting and IsResting()
    log("V97 resting", Val(resting))
    if resting == true then result("V97", "pass", "IsResting true") end
  end,
  PLAYER_LOGOUT = function() log("V97 at logout IsResting", Vals(IsResting)) end,
  MERCHANT_SHOW = function()
    merchantOpen, merchantAction = true, nil
    merchantMoney = GetMoney and GetMoney()
    log("V99 merchant open: CanMerchantRepair", Vals(CanMerchantRepair), "GetRepairAllCost", Vals(GetRepairAllCost))
  end,
  MERCHANT_CLOSED = function()
    if not merchantOpen then return end
    merchantOpen = false
    local money = GetMoney and GetMoney()
    local change = type(money) == "number" and type(merchantMoney) == "number" and money - merchantMoney or nil
    log("V99 merchant closed: money change", Val(change), "action", S(merchantAction))
    if merchantAction then
      result("V99", "pass", merchantAction .. " hook ran; money " .. (change and (change >= 0 and "up" or "down")
        or "unknown"))
    elseif change and change > 0 then
      info("V99", "money up while the merchant was open (a sale); a buy or repair still to see")
    end
  end,
  MAIL_SHOW = function() log("V100 mailbox open, inbox", Vals(GetInboxNumItems)) end,
  MAIL_SEND_SUCCESS = function()
    log("V100 MAIL_SEND_SUCCESS to", Val(mailTo))
    if str(mailTo) then result("V100", "pass", "sent to " .. mailTo) end
  end,
  AUCTION_HOUSE_SHOW = function()
    log("V101 auction house open, C_AuctionHouse", C_AuctionHouse and "exists" or "missing")
  end,
  AUCTION_HOUSE_CLOSED = function() log("V101 auction house closed") end,
  AUCTION_HOUSE_AUCTION_CREATED = function(...)
    log("V101 AUCTION_HOUSE_AUCTION_CREATED", Vals(function(...) return ... end, ...))
    result("V101", "pass", "posted: AUCTION_HOUSE_AUCTION_CREATED")
  end,
  AUCTION_HOUSE_PURCHASE_COMPLETED = function(...)
    log("V101 AUCTION_HOUSE_PURCHASE_COMPLETED", Vals(function(...) return ... end, ...))
  end,
  BANKFRAME_OPENED = function() result("V102", "pass", "BANKFRAME_OPENED fired") end,
  TRAINER_SHOW = function()
    trainerOpen = true
    log("V103 trainer open")
  end,
  TRAINER_CLOSED = function() trainerOpen = false end,
  LEARNED_SPELL_IN_SKILL_LINE = function(...)
    log("V103 LEARNED_SPELL_IN_SKILL_LINE", Vals(function(...) return ... end, ...), "trainer open", S(trainerOpen))
    if trainerOpen then result("V103", "pass", "LEARNED_SPELL_IN_SKILL_LINE at a trainer") end
  end,
  LEARNED_SPELL_IN_TAB = function(...)
    log("V103 LEARNED_SPELL_IN_TAB", Vals(function(...) return ... end, ...), "trainer open", S(trainerOpen))
    if trainerOpen then result("V103", "pass", "LEARNED_SPELL_IN_TAB at a trainer") end
  end,
  NEW_RECIPE_LEARNED = function(recipeID)
    log("V104 NEW_RECIPE_LEARNED", Val(recipeID), spellName(recipeID))
    result("V104", "pass", "NEW_RECIPE_LEARNED " .. Val(recipeID))
  end,
  CHAT_MSG_LOOT = Loot,
  LOOT_OPENED = LootOpened,
  CHAT_MSG_SKILL = function(text)
    log("V107 skill message", Val(text))
    if matches(text, "SKILL_RANK_UP") then result("V107", "pass", "SKILL_RANK_UP: " .. text) end
  end,
  CHAT_MSG_WHISPER_INFORM = function(_, target)
    log("V108 whisper sent to", Val(target))
    if str(target) then
      whisperTarget = target
      if emoteSeen then
        result("V108", "pass", "whisper target " .. target .. "; " .. emoteSeen)
      else
        info("V108", "whisper target " .. target .. " readable; an emote still to do")
      end
    end
  end,
  CHAT_MSG_BN_WHISPER_INFORM = function(_, target, ...)
    log("V108 Battle.net whisper sent, name", Val(target), "other", Vals(function(...) return ... end, ...))
  end,
  CHAT_MSG_MONEY = function(text)
    log("V109 money message", Val(text))
    local key = matches(text, "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT")
    if key then result("V109", "pass", key .. " matched") end
  end,
  UNIT_AURA = Auras,
  SCREENSHOT_SUCCEEDED = function() result("V111", "pass", "SCREENSHOT_SUCCEEDED fired") end,
  PLAYER_EQUIPMENT_CHANGED = function(slot)
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    log("V113 equipment slot", Val(slot), "item", Val(id))
    if type(id) == "number" then result("V113", "pass", "slot " .. S(slot) .. ": item " .. id) end
  end,
  CONFIRM_SUMMON = function()
    local summoner = C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner and
      C_SummonInfo.GetSummonConfirmSummoner()
    log("V114 summon from", Val(summoner), "to", Vals(C_SummonInfo and C_SummonInfo.GetSummonConfirmAreaName))
    result("V114", str(summoner) and "pass" or "fail", "summoner " .. Val(summoner))
  end,
  ZONE_CHANGED = function()
    local sub = GetSubZoneText and GetSubZoneText()
    if str(sub) and not subzones[sub] then
      subzones[sub] = true
      log("V115 subzone", sub, "in", Vals(GetRealZoneText))
      result("V115", "pass", "GetSubZoneText " .. sub)
    end
  end,
  BAG_UPDATE_DELAYED = ScanBags,
  ADDON_ACTION_BLOCKED = function(addon, fn)
    if addon == "FriendProbe" then
      log("blocked", Val(fn))
      if S(fn):find("Jump", 1, true) then result("V118", "fail", "blocked: " .. S(fn)) end
    end
  end,
}
handlers.ZONE_CHANGED_INDOORS = handlers.ZONE_CHANGED
handlers.ADDON_ACTION_FORBIDDEN = handlers.ADDON_ACTION_BLOCKED

local frame = CreateFrame("Frame")
for _, event in ipairs(EVENTS) do
  if not pcall(frame.RegisterEvent, frame, event) then log("missions: unknown event", event) end
end
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
  if not ns.running() then return end
  local ok, err
  if event == "PLAYER_LOGIN" then
    ok, err = pcall(function()
      log("== V90-V119 MISSION CHECKS ==")
      log("V101 C_AuctionHouse", C_AuctionHouse and "exists" or "missing", "| V96 GetBindLocation",
        Vals(GetBindLocation), "| V97 IsResting", Vals(IsResting))
      Hooks()
      ScanBags()
      if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, Poll) end
    end)
  elseif handlers[event] then
    ok, err = pcall(handlers[event], ...)
  else
    ok = true
  end
  if not ok then log("missions handler error", event, S(err)) end
end)
