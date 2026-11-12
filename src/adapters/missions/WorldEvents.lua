-- WorldEvents: the events of the world missions (CF-76). Thin wrapper: raw values only, sent as the
-- internal message DoomsdayTracker.MISSION_EVENT (kind, obs) for the kinds of src/core/missions/World.lua.
-- Verified on Forever (docs/API-FINDINGS.md "Forever launch probe"): kills from CHAT_MSG_COMBAT_XP_GAIN (V90),
-- creatures by target, mouseover and nameplate (V93), flights (V94), own casts (V95), swimming and mounted (V98),
-- merchant hooks (V99), SendMail and MAIL_SEND_SUCCESS (V100), BANKFRAME_OPENED (V102), the trainer (V103),
-- CHAT_MSG_SKILL (V107), CHAT_MSG_WHISPER_INFORM (V108), SCREENSHOT_SUCCEEDED (V111), subzones (V115), CONFIRM_SUMMON
-- and C_SummonInfo.GetSummonConfirmSummoner (V114).
-- CF-104: a posted auction (AUCTION_HOUSE_AUCTION_CREATED, V101). Unverified and guarded (VERIFY.md CF-104): the
-- accept of a summon (a post-hook on C_SummonInfo.ConfirmSummon), the ERR_AUCTION_STARTED message as a second source.
-- CF-121: a bought auction (AUCTION_HOUSE_PURCHASE_COMPLETED, V101, build 70888), one per event; registered only when
-- the client knows the event (Events.register).
-- Unverified and guarded (VERIFY.md CF-76): the whisper's GUID argument, Battle.net whispers, the hearthstone's
-- spell from its item, money up at a merchant (a sale). Every call stays guarded.
local _, ns = ...

local WorldEvents = {}

local readable, call = ns.Safe.value, ns.Safe.call

WorldEvents.POLL = 5            -- seconds between the swimming and mounted reads (V98)
WorldEvents.MOVE_FLUSH = 60     -- seconds of swimming or riding sent at once
WorldEvents.MAX_CREATURES = 200 -- creatures remembered by name before the list starts over
WorldEvents.HEARTHSTONE_ITEM = 6948
WorldEvents.HEARTH_SPELLS = { [8690] = true } -- the hearthstone's spell; the item's own spell is added at its cast

local addonRef, events, hooked
local creatures, creatureCount = {}, 0 -- name -> { classification, level }
local xpPattern                       -- the kill XP message's pattern, built once
local onTaxi = false
local lastNewPath = 0
local trainerOpen = false
local merchantOpen, merchantMoney = false, nil
local mailTo
local summonFrom -- CF-104: the summon offered by a friend ({ at }), until it is accepted or cancelled
local lastAuction = 0
local moved = { swim = 0, ride = 0 } -- seconds polled, not sent yet

local function global() return addonRef.db.global end
local function own() return global().self end

local function send(kind, obs)
  addonRef:SendMessage(ns.DoomsdayTracker.MISSION_EVENT, kind, obs)
end

local function action(name) send("worldAction", { action = name }) end

local str = ns.Safe.text -- CF-108: the secret check before any comparison

local function level()
  local guid = ns.SelfInfo.guid()
  local char = guid and own().chars and own().chars[guid]
  return type(char) == "table" and char.level or nil
end

local function friendGrouped()
  local g = global()
  return ns.Missions.Quests.friendInGroup(ns.Instance.groupGuids(), g.people, g.presence, own().battleTag)
end

local function owners()
  return ns.Missions.Places.owners(global().people, global().presence, own().battleTag)
end

-- ===== Kills (V90, V93) =====

local function onUnit(unit)
  if not str(unit) or not call(UnitExists, unit) or call(UnitIsPlayer, unit) then return end
  if not call(UnitCanAttack, "player", unit) then return end
  local name = call(UnitName, unit)
  if not str(name) then return end
  if not creatures[name] then
    creatureCount = creatureCount + 1
    if creatureCount > WorldEvents.MAX_CREATURES then creatures, creatureCount = {}, 1 end
  end
  local lvl = call(UnitLevel, unit)
  creatures[name] = { classification = call(UnitClassification, unit), level = type(lvl) == "number" and lvl or nil }
end

-- The XP message has variants with bonus text after it: match the format without its end.
local function pattern()
  if xpPattern == nil then
    local format = readable(COMBATLOG_XPGAIN_FIRSTPERSON)
    local p = type(format) == "string" and ns.GameText.pattern((format:gsub("%.$", ""))) or nil
    xpPattern = p and p:sub(1, -2) or false
  end
  return xpPattern or nil
end

local function onXp(_, message)
  if ns.Safe.secret(message) then return end
  local victim = ns.Missions.World.victim(message, pattern())
  local guid = ns.SelfInfo.guid()
  if not victim or not guid then return end
  local seen = creatures[victim] or {}
  send("worldKill", { guid = guid, classification = seen.classification, level = seen.level, charLevel = level(),
                      friend = friendGrouped() })
end

local function onDead()
  local guid = ns.SelfInfo.guid()
  if guid then send("worldDeath", { guid = guid }) end
end

-- ===== Summons and auctions (V114, V101; CF-104) =====

WorldEvents.SUMMON_WINDOW = 180 -- seconds an offered summon can still be accepted (the game's is 2 minutes)

local function onSummonOffered()
  local get = C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner
  local summoner = get and call(get)
  local g = global()
  if str(summoner) and ns.Missions.World.isFriendTarget(summoner, nil, nil, g.people, own().battleTag) then
    summonFrom = { at = GetServerTime() }
  else
    summonFrom = nil
  end
end

local function onSummonAccepted()
  if summonFrom and GetServerTime() - summonFrom.at <= WorldEvents.SUMMON_WINDOW then action("summoned") end
  summonFrom = nil
end

-- The event and the message can both come for one auction: count it once.
local function auctionPosted()
  local now = GetServerTime()
  if now - lastAuction > 3 then action("auctionPost") end
  lastAuction = now
end

local function onAuctionMessage(message)
  local started = readable(ERR_AUCTION_STARTED)
  if type(started) == "string" and message == started then auctionPosted() end
end

-- ===== Flights (V94) =====

local function checkTaxi()
  if call(UnitOnTaxi, "player") == true and not onTaxi then
    onTaxi = true
    action("flight")
  end
end

local function onMessage(message)
  if not str(message) then return end
  local newPath = readable(ERR_NEWTAXIPATH)
  -- The message can come as both events: count it once.
  if type(newPath) == "string" and message == newPath and GetServerTime() - lastNewPath > 5 then
    lastNewPath = GetServerTime()
    action("newFlight")
  end
  onAuctionMessage(message)
end

-- ===== Swimming and riding (V98) =====

local function flushMove(force)
  local guid = ns.SelfInfo.guid()
  if not guid then return end
  if moved.swim + moved.ride == 0 then return end
  if force or moved.swim >= WorldEvents.MOVE_FLUSH or moved.ride >= WorldEvents.MOVE_FLUSH then
    send("worldMove", { guid = guid, swim = moved.swim, ride = moved.ride })
    moved.swim, moved.ride = 0, 0
  end
end

local function poll()
  local swimming = call(IsSwimming) == true
  local riding = call(IsMounted) == true and call(UnitOnTaxi, "player") ~= true
  if swimming then moved.swim = moved.swim + WorldEvents.POLL end
  if riding then moved.ride = moved.ride + WorldEvents.POLL end
  flushMove(not swimming and not riding)
end

-- ===== Casts, skills, places (V95, V107, V115) =====

local function onCast(_, unit, _, spellID)
  if readable(unit) ~= "player" then return end
  spellID = readable(spellID)
  if type(spellID) ~= "number" then return end
  local spells = WorldEvents.HEARTH_SPELLS
  -- Forever has new spell IDs (V95): the hearthstone item's own spell counts too (C_Item.GetItemSpell, V116).
  local _, itemSpell = call(C_Item and C_Item.GetItemSpell, WorldEvents.HEARTHSTONE_ITEM)
  if type(itemSpell) == "number" then spells[itemSpell] = true end
  if ns.Missions.World.isHearth(spellID, spells) then action("hearth") end
end

local function onSkill(_, message)
  if not str(message) then return end
  local args = ns.GameText.parse(message, readable(SKILL_RANK_UP))
  if ns.Missions.World.weaponSkill(args, ns.Missions.World.professionNames(own().chars)) then action("weaponUp") end
end

local function onPlace()
  local sub = call(GetSubZoneText)
  if str(sub) then send("worldPlace", { zone = ns.SelfInfo.zone(), subzone = sub }) end
end

-- ===== Whispers and mail (V108, V100) =====

local function onWhisper(_, _, target, _, _, _, _, _, _, _, _, _, guid)
  local g = global()
  if ns.Missions.World.isFriendTarget(readable(target), readable(guid), owners(), g.people, own().battleTag) then
    action("whisper")
  end
end

local function onBnWhisper(_, _, _, _, _, _, _, _, _, _, _, _, _, bnID)
  bnID = readable(bnID)
  local accountInfo = C_BattleNet and C_BattleNet.GetAccountInfoByID
  if not (accountInfo and type(bnID) == "number") then return end
  local ok, account = pcall(accountInfo, bnID)
  local tag = ok and type(account) == "table" and readable(account.battleTag) or nil
  if ns.Missions.World.isFriendTag(tag, global().people, own().battleTag) then action("whisper") end
end

local function onMailSent()
  local g = global()
  if mailTo and ns.Missions.World.isFriendTarget(mailTo, nil, nil, g.people, own().battleTag) then
    action("mailFriend")
  end
  mailTo = nil
end

-- ===== Merchant (V99) =====

local function onMoney()
  if not merchantOpen then return end
  local money = call(GetMoney)
  if type(money) ~= "number" then return end
  if type(merchantMoney) == "number" and money > merchantMoney then action("sale") end
  merchantMoney = money
end

local function hook(name, fn)
  if hooksecurefunc and type(_G[name]) == "function" then pcall(hooksecurefunc, name, fn) end
end

local function installHooks()
  if hooked then return end
  hooked = true
  hook("BuyMerchantItem", function() if merchantOpen then action("buy") end end)
  hook("RepairAllItems", function() if merchantOpen then action("repair") end end)
  hook("SendMail", function(recipient) mailTo = str(recipient) and recipient or nil end)
  -- CF-104: the summon popup's accept calls C_SummonInfo.ConfirmSummon (unverified hook, VERIFY.md CF-104).
  if hooksecurefunc and C_SummonInfo and type(C_SummonInfo.ConfirmSummon) == "function" then
    pcall(hooksecurefunc, C_SummonInfo, "ConfirmSummon", onSummonAccepted)
  end
end

-- Called once by DoomsdayTracker.start with the addon (for addon:SendMessage).
function WorldEvents.watch(addon)
  addonRef = addon
  -- An own AceEvent object: addon:RegisterEvent would replace other services' handlers.
  events = events or LibStub("AceEvent-3.0"):Embed({})
  local register = function(event, fn) ns.Events.register(events, event, fn) end
  register("PLAYER_TARGET_CHANGED", function() onUnit("target") end)
  register("UPDATE_MOUSEOVER_UNIT", function() onUnit("mouseover") end)
  register("NAME_PLATE_UNIT_ADDED", function(_, unit) onUnit(unit) end)
  register("CHAT_MSG_COMBAT_XP_GAIN", onXp)
  register("PLAYER_DEAD", onDead)
  local taxiLater = ns.Timer.debounce(3, checkTaxi)
  register("PLAYER_CONTROL_LOST", taxiLater)
  register("PLAYER_CONTROL_GAINED", function() onTaxi = false end)
  register("UI_INFO_MESSAGE", function(_, _, message) onMessage(message) end)
  register("CHAT_MSG_SYSTEM", function(_, message) onMessage(message) end)
  register("UNIT_SPELLCAST_SUCCEEDED", onCast)
  register("BANKFRAME_OPENED", function() action("bank") end)
  register("TRAINER_SHOW", function() trainerOpen = true end)
  register("TRAINER_CLOSED", function() trainerOpen = false end)
  register("LEARNED_SPELL_IN_SKILL_LINE", function() if trainerOpen then action("trainer") end end)
  register("CHAT_MSG_SKILL", onSkill)
  register("SCREENSHOT_SUCCEEDED", function() if friendGrouped() then action("groupPic") end end)
  for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
    register(event, onPlace)
  end
  register("CHAT_MSG_WHISPER_INFORM", onWhisper)
  register("CHAT_MSG_BN_WHISPER_INFORM", onBnWhisper)
  register("MAIL_SEND_SUCCESS", onMailSent)
  register("MAIL_FAILED", function() mailTo = nil end)
  register("CONFIRM_SUMMON", onSummonOffered)
  register("CANCEL_SUMMON", function() summonFrom = nil end)
  register("AUCTION_HOUSE_AUCTION_CREATED", auctionPosted)
  register("AUCTION_HOUSE_PURCHASE_COMPLETED", function() action("auctionBuy") end)
  register("MERCHANT_SHOW", function()
    merchantOpen = true
    merchantMoney = call(GetMoney)
  end)
  register("MERCHANT_CLOSED", function() merchantOpen = false end)
  register("PLAYER_MONEY", onMoney)
  events:RegisterMessage(ns.SelfInfo.CHANGED, function(_, reason)
    if reason == "logout" then flushMove(true) end
  end)
  installHooks()
  ns.Timer.every(WorldEvents.POLL, poll)
end

ns.MissionEvents = ns.MissionEvents or {}
ns.MissionEvents.World = WorldEvents
return WorldEvents
