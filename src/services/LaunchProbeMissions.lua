--[[ LaunchProbeMissions (CF-82): the hidden probe's checks for the Doomsday mission catalogue (V90 to V117, from
FriendProbe's Missions.lua) and the PvP catalogue (V120 to V123). Same rules as services/LaunchProbe.lua: silent,
guarded, cheap, no raw chat text and no player names except the killer's (V120). Left out: the jump hook (V118, a
"blocked" popup is a possible answer) and the campfire (V119, judged by eye). ]]
local _, ns = ...

local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local S, Val, Vals, readable, str, get = u.S, u.Val, u.Vals, u.readable, u.str, u.get
local matches, result, note, info, passed, after, now = u.matches, u.result, u.note, u.info, u.passed, u.after, u.now
local on = LaunchProbe.on

local function itemId(link)
  return str(link) and tonumber(link:match("|Hitem:(%d+)")) or nil
end

-- Class and subclass of an item (C_Item.GetItemInfoInstant: id, type, subtype, equipLoc, icon, classID, subclassID).
local function itemClass(id)
  if not (id and C_Item and C_Item.GetItemInfoInstant) then return "missing" end
  local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
  if not ok then return "error" end
  return "class " .. Val(classID) .. "/" .. Val(subclassID)
end

local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return Vals(C_Spell.GetSpellName, id) end
  return Vals(GetSpellInfo, id)
end

-- ===== V93: creatures seen (for V90's kills) =====
local creatures = {} -- name -> { classification, level, at }
local creatureCount = 0

local function Creature(unit, source)
  if passed("V93") and passed("V90") then return end
  if not get(UnitExists, unit) or get(UnitIsPlayer, unit) then return end
  if not get(UnitCanAttack, "player", unit) then return end
  local name = UnitName and UnitName(unit)
  if not str(name) then
    result("V93", "fail", "creature name " .. Val(name) .. " via " .. source)
    return
  end
  local classification = UnitClassification and UnitClassification(unit)
  local level = UnitLevel and UnitLevel(unit)
  local seen = creatures[name]
  if not seen then
    creatureCount = creatureCount + 1
    if creatureCount > 200 then creatures, creatureCount = {}, 1 end
  end
  creatures[name] = { classification = classification, level = level, at = now() }
  if seen and now() - seen.at < 60 then return end
  if str(classification) and type(level) == "number" and readable(level) then
    result("V93", "pass", string.format("%s: %s, level %d via %s", name, classification, level, source))
  else
    result("V93", "fail", "classification " .. Val(classification) .. ", level " .. Val(level) .. " via " .. source)
  end
end

on("PLAYER_TARGET_CHANGED", function() Creature("target", "target") end)
on("UPDATE_MOUSEOVER_UNIT", function() Creature("mouseover", "mouseover") end)
on("NAME_PLATE_UNIT_ADDED", function(unit) if str(unit) then Creature(unit, "nameplate") end end)

-- ===== V90: kills from the XP message =====
-- The XP message has variants with bonus text after it: match the format without its end.
local function prefix(format)
  local pattern = ns.GameText.pattern(type(format) == "string" and (format:gsub("%.$", "")) or nil)
  return pattern and pattern:sub(1, -2)
end

on("CHAT_MSG_COMBAT_XP_GAIN", function(text)
  if passed("V90") then return end
  local p = prefix(COMBATLOG_XPGAIN_FIRSTPERSON)
  if not p then
    result("V90", "fail", "COMBATLOG_XPGAIN_FIRSTPERSON missing")
    return
  end
  local victim, xp
  if str(text) then victim, xp = text:match(p) end
  if not victim then
    info("V90", "XP message " .. (str(text) and "did not match" or Val(text)))
    return
  end
  local seen = creatures[victim]
  local detail = string.format("%s dies, %s XP%s", victim, S(xp), get(IsInGroup) and ", in a group" or "")
  if seen then detail = detail .. ", seen as " .. Val(seen.classification) .. " level " .. Val(seen.level) end
  result("V90", "pass", detail)
end)

-- ===== V94: flights =====
on("PLAYER_CONTROL_LOST", function()
  if passed("V94") then return end
  after(3, function()
    if get(UnitOnTaxi, "player") == true then result("V94", "pass", "UnitOnTaxi true after PLAYER_CONTROL_LOST") end
  end)
end)

-- ===== V95, V116, V117: own spell casts, items used, cast targets =====
local itemSpells = {} -- spellID -> itemID of a bag item whose use casts it

on("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" or (passed("V95") and passed("V116")) then return end
  if not (type(spellID) == "number" and readable(spellID)) then
    result("V95", "fail", "spell ID " .. Val(spellID))
    return
  end
  result("V95", "pass", "spell " .. spellID .. " " .. spellName(spellID))
  local item = itemSpells[spellID]
  if item then
    result("V116", "pass", string.format("item %d cast spell %d: %s", item, spellID, itemClass(item)))
  end
end)

on("UNIT_SPELLCAST_SENT", function(unit, target, _, spellID)
  if unit ~= "player" or passed("V117") then return end
  if str(target) then
    result("V117", "pass", "target name readable for spell " .. Val(spellID))
  else
    info("V117", "no target name (" .. Val(target) .. ") for spell " .. Val(spellID))
  end
end)

-- ===== V112, V116: bag items =====
on("BAG_UPDATE_DELAYED", function()
  if passed("V112") and passed("V116") then return end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return end
  local getSpell = C_Item and C_Item.GetItemSpell
  itemSpells = {}
  local qualities = 0
  for bag = 0, 4 do
    for slot = 1, get(C_Container.GetContainerNumSlots, bag) or 0 do
      local id = get(C_Container.GetContainerItemID, bag, slot)
      if type(id) == "number" and getSpell then
        local ok, _, spellID = pcall(getSpell, id)
        if ok and type(spellID) == "number" and readable(spellID) then itemSpells[spellID] = id end
      end
      local item = get(C_Container.GetContainerItemInfo, bag, slot)
      if type(item) == "table" and type(item.quality) == "number" then qualities = qualities + 1 end
    end
  end
  if qualities > 0 then
    result("V112", "pass", qualities .. " bag items with a readable quality")
  else
    info("V112", "no bag item with a readable quality (GetContainerItemInfo "
      .. (C_Container.GetContainerItemInfo and "exists" or "missing") .. ")")
  end
end)

-- ===== V110: buffs on party members (skipped in combat, at most every 2 s per unit) =====
local auraAt = {}
on("UNIT_AURA", function(unit)
  if passed("V110") or not (unit == "player" or (str(unit) and unit:match("^party%d$"))) then return end
  if get(InCombatLockdown) then return end
  if auraAt[unit] and now() - auraAt[unit] < 2 then return end
  auraAt[unit] = now()
  local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not byIndex then
    result("V110", "fail", "C_UnitAuras.GetAuraDataByIndex missing")
    return
  end
  for i = 1, 40 do
    local aura = get(byIndex, unit, i, "HELPFUL")
    if type(aura) ~= "table" then break end
    if readable(aura.spellId) and readable(aura.sourceUnit) then
      if unit ~= "player" and aura.sourceUnit == "player" then
        result("V110", "pass", "own buff on " .. unit .. ": spell " .. Val(aura.spellId))
        return
      end
      info("V110", "player auras readable (spellId, sourceUnit); a buff on a party member still to see")
    end
  end
end)

-- ===== V98: mounted and swimming, polled every 5 s =====
local mounted, swimming = false, false
local ticker
LaunchProbe.atLogin(function()
  if passed("V98") or not (C_Timer and C_Timer.NewTicker) then return end
  ticker = C_Timer.NewTicker(5, function()
    if not LaunchProbe.running() then
      ticker:Cancel()
      return
    end
    mounted = mounted or get(IsMounted) == true
    swimming = swimming or get(IsSwimming) == true
    if mounted and swimming then
      result("V98", "pass", "IsMounted and IsSwimming both read true")
      ticker:Cancel()
    elseif mounted or swimming then
      info("V98", (mounted and "IsMounted" or "IsSwimming") .. " read true; the other still to see")
    end
  end)
end)

-- ===== V99, V100, V108: post-hooks =====
local merchantOpen, merchantMoney, merchantAction = false, nil, nil
local mailTo, whisperSeen, emoteSeen

LaunchProbe.hook("RepairAllItems", function() merchantAction = "repair" end)
LaunchProbe.hook("BuyMerchantItem", function() merchantAction = "buy" end)
LaunchProbe.hook("SendMail", function(recipient) mailTo = recipient end)
LaunchProbe.hook("DoEmote", function(token)
  if passed("V108") then return end
  local theirs = get(UnitFactionGroup, "target")
  local enemy = get(UnitIsPlayer, "target") and theirs ~= nil and theirs ~= get(UnitFactionGroup, "player")
  emoteSeen = "emote " .. Val(token) .. " on " .. (enemy and "an enemy-faction player" or "no enemy player")
  if whisperSeen then
    result("V108", "pass", "whisper target readable; " .. emoteSeen)
  else
    info("V108", emoteSeen .. "; a whisper still to send")
  end
end)

on("MERCHANT_SHOW", function()
  merchantOpen, merchantAction = true, nil
  merchantMoney = get(GetMoney)
end)
on("MERCHANT_CLOSED", function()
  if not merchantOpen then return end
  merchantOpen = false
  local money = get(GetMoney)
  local change = type(money) == "number" and type(merchantMoney) == "number" and money - merchantMoney or nil
  if merchantAction then
    result("V99", "pass", merchantAction .. " hook ran; money " .. (change and (change >= 0 and "up" or "down")
      or "unknown"))
  elseif change and change > 0 then
    info("V99", "money up while the merchant was open (a sale); a buy or repair still to see")
  end
end)

on("MAIL_SEND_SUCCESS", function()
  if str(mailTo) then result("V100", "pass", "recipient readable from the SendMail hook") end
end)

on("CHAT_MSG_WHISPER_INFORM", function(_, target)
  if passed("V108") or not str(target) then return end
  whisperSeen = true
  if emoteSeen then
    result("V108", "pass", "whisper target readable; " .. emoteSeen)
  else
    info("V108", "whisper target readable; an emote still to do")
  end
end)

-- ===== V94, V101, V103, V104: system and UI messages =====
local trainerOpen = false
local function Message(text)
  if not str(text) then return end
  if ERR_NEWTAXIPATH and text == ERR_NEWTAXIPATH then
    info("V94", "new flight path message seen; a flight still to take")
  end
  if matches(text, "ERR_AUCTION_STARTED") then result("V101", "pass", "posted: ERR_AUCTION_STARTED") end
  local key = matches(text, "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S")
  if key and trainerOpen then result("V103", "pass", key .. " at a trainer") end
  if matches(text, "ERR_LEARN_RECIPE_S") then result("V104", "pass", "ERR_LEARN_RECIPE_S matched") end
end
on("UI_INFO_MESSAGE", function(_, text) Message(text) end)
on("CHAT_MSG_SYSTEM", Message)

on("AUCTION_HOUSE_AUCTION_CREATED", function() result("V101", "pass", "posted: AUCTION_HOUSE_AUCTION_CREATED") end)
on("BANKFRAME_OPENED", function() result("V102", "pass", "BANKFRAME_OPENED fired") end)
on("TRAINER_SHOW", function() trainerOpen = true end)
on("TRAINER_CLOSED", function() trainerOpen = false end)
on("LEARNED_SPELL_IN_SKILL_LINE", function()
  if trainerOpen then result("V103", "pass", "LEARNED_SPELL_IN_SKILL_LINE at a trainer") end
end)
on("NEW_RECIPE_LEARNED", function(recipeID) result("V104", "pass", "NEW_RECIPE_LEARNED " .. Val(recipeID)) end)
on("PLAYER_BINDING_CHANGED", function()
  local place = get(GetBindLocation)
  result("V96", str(place) and "pass" or "fail", "GetBindLocation " .. Val(place))
end)

-- ===== V105, V106, V107, V109: loot, skills, coins =====
on("CHAT_MSG_LOOT", function(text)
  if passed("V105") or not matches(text, "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE") then return end
  local id = itemId(text)
  local quality = id and get(C_Item and C_Item.GetItemQualityByID, id)
  local class = itemClass(id)
  if id and class ~= "missing" and class ~= "error" then
    result("V105", "pass", string.format("created %d: %s, quality %s", id, class, Val(quality)))
  end
end)

on("LOOT_OPENED", function()
  if passed("V106") then return end
  local count = get(GetNumLootItems)
  local sources = {}
  for slot = 1, type(count) == "number" and count or 0 do
    local guid = get(GetLootSourceInfo, slot)
    if str(guid) then sources[#sources + 1] = guid:match("^(%a+)") or "?" end
  end
  if #sources > 0 then
    result("V106", "pass", "loot source " .. table.concat(sources, ", ") .. (get(IsFishingLoot) and " (fishing)" or ""))
  elseif type(count) == "number" and count > 0 then
    info("V106", "no readable loot source (GetLootSourceInfo " .. (GetLootSourceInfo and "exists" or "missing") .. ")")
  end
end)

on("CHAT_MSG_SKILL", function(text)
  if matches(text, "SKILL_RANK_UP") then result("V107", "pass", "SKILL_RANK_UP matched") end
end)

on("CHAT_MSG_MONEY", function(text)
  local key = matches(text, "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT")
  if key then result("V109", "pass", key .. " matched") end
end)

-- ===== V111, V113, V114, V115 =====
on("SCREENSHOT_SUCCEEDED", function() result("V111", "pass", "SCREENSHOT_SUCCEEDED fired") end)

on("PLAYER_EQUIPMENT_CHANGED", function(slot)
  if passed("V113") then return end
  local id = get(GetInventoryItemID, "player", slot)
  if type(id) == "number" then result("V113", "pass", "slot " .. Val(slot) .. ": item " .. id) end
end)

on("CONFIRM_SUMMON", function()
  local summoner = get(C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner)
  result("V114", str(summoner) and "pass" or "fail", "summoner " .. (str(summoner) and "readable" or Val(summoner)))
end)

local function SubZone()
  if passed("V115") then return end
  local sub = get(GetSubZoneText)
  if str(sub) then result("V115", "pass", "GetSubZoneText " .. sub) end
end
on("ZONE_CHANGED", SubZone)
on("ZONE_CHANGED_INDOORS", SubZone)

-- ===== V120: who killed you, from the death recap (1 s after the death) =====
local function Killer()
  local recap = C_DeathRecap and C_DeathRecap.GetRecapEvents
  if not recap then
    result("V120", "fail", "C_DeathRecap.GetRecapEvents missing")
    return
  end
  local events = get(recap)
  if type(events) ~= "table" then
    info("V120", "no recap events (" .. Val(events) .. ")")
    return
  end
  local last
  for _, e in ipairs(events) do
    if type(e) == "table" then last = e end
  end
  if not last then return end
  local guid = last.sourceGUID
  note("V120", "last recap source: " .. (str(guid) and (guid:match("^(%a+)") or "?") or Val(guid)) .. ", name "
    .. (str(last.sourceName) and "readable" or Val(last.sourceName)))
  if str(last.sourceName) and str(guid) and guid:match("^Player%-") then
    result("V120", "pass", "killed by player " .. last.sourceName)
  else
    info("V120", "last recap source not a player with a name; a death to a player still to see")
  end
end
on("PLAYER_DEAD", function() after(1, Killer) end)

-- ===== V121: the PvP flag =====
local flagSeen
local function Flag()
  local flagged = UnitIsPVP and UnitIsPVP("player")
  if not readable(flagged) or flagged == flagSeen then
    if flagged == nil then result("V121", "fail", "UnitIsPVP missing") end
    return
  end
  flagSeen = flagged
  if flagged == true then result("V121", "pass", "UnitIsPVP true after a flag change") end
end
on("PLAYER_FLAGS_CHANGED", function(unit) if unit == "player" then Flag() end end)
LaunchProbe.atLogin(Flag)

-- ===== V122: the battleground score (at most once a minute) =====
local scoreAt
on("UPDATE_BATTLEFIELD_SCORE", function()
  if passed("V122") or (scoreAt and now() - scoreAt < 60) then return end
  scoreAt = now()
  local me = get(UnitName, "player")
  local count = get(GetNumBattlefieldScores)
  local stats = {}
  for s = 1, get(GetNumBattlefieldStats) or 0 do stats[#stats + 1] = Vals(GetBattlefieldStatInfo, s) end
  for i = 1, type(count) == "number" and count or 0 do
    local name, _, honorableKills = GetBattlefieldScore(i)
    if str(name) and str(me) and name:find(me, 1, true) == 1 then
      if type(honorableKills) == "number" and readable(honorableKills) then
        result("V122", #stats > 0 and "pass" or "info", "own honorable kills " .. honorableKills .. "; " .. #stats
          .. " battleground stats" .. (#stats > 0 and (": " .. table.concat(stats, " / ")) or ""))
      else
        result("V122", "fail", "own honorable kills " .. Val(honorableKills))
      end
      return
    end
  end
end)

-- ===== V123: the zone's PvP type =====
local function ZonePvp()
  if passed("V123") then return end
  local zonePvp = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  if not zonePvp then
    result("V123", "fail", "GetZonePVPInfo missing")
    return
  end
  local pvpType = get(zonePvp)
  local zone = Val(get(GetRealZoneText))
  if str(pvpType) then
    result("V123", "pass", zone .. ": " .. pvpType)
  else
    info("V123", "no PvP type in " .. zone .. " (" .. Val(pvpType) .. ")")
  end
end
on("ZONE_CHANGED_NEW_AREA", ZonePvp)
LaunchProbe.atLogin(ZonePvp)
