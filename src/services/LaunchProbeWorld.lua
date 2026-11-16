--[[ LaunchProbeWorld (CF-120): the hidden probe's checks for the questions whose action happened in play but no
probe ever answered. Each tries other ways to read the data (another API, event, hook or moment), side by side, and
notes which way saw what. Same rules as services/LaunchProbe.lua: silent, guarded, cheap, no raw chat text and no
player names (a mail's sender only as "readable"). Every API here is guarded; the unverified ones are in VERIFY.md.
- V8: the clubIds of the subscribed clubs, to compare between friends' exports.
- V79: whether GetPVPRankInfo exists.
- V99: at a merchant, GetMerchantItemLink(1), CanMerchantRepair and GetRepairAllCost (MERCHANT_SHOW and
  MERCHANT_UPDATE).
- V106: fishing loot's source and items (LOOT_READY and LOOT_OPENED; fishing told by IsFishingLoot or by an own
  Fishing cast just before).
- V119: the campfire's spell when lit (UNIT_SPELLCAST_SUCCEEDED) and the helpful auras that appear or change on
  you while it burns (UNIT_AURA, C_UnitAuras.GetAuraDataByIndex).
CF-124: V96 (the hearthstone), V100 (a mail's sender) and V118 (jumps) answered (export of 2026-11-16) and gone. ]]
local _, ns = ...

local LaunchProbe = ns.LaunchProbe
local u = LaunchProbe.util
local Val, Vals, readable, str, get = u.Val, u.Vals, u.readable, u.str, u.get
local result, note, info, passed, now = u.result, u.note, u.info, u.passed, u.now
local on = LaunchProbe.on

-- A readable number, else nil.
local function num(v)
  return type(v) == "number" and readable(v) and v or nil
end

-- The item ID in an item link, else nil.
local function itemId(link)
  return str(link) and link:match("|Hitem:(%d+)") or nil
end

-- ===== V8: the clubIds, to compare between clients =====
LaunchProbe.atLogin(function()
  local list = C_Club and C_Club.GetSubscribedClubs
  if not list then
    info("V8", "C_Club.GetSubscribedClubs missing")
    return
  end
  local parts = {}
  local clubs = get(list)
  for _, c in ipairs(type(clubs) == "table" and clubs or {}) do
    if type(c) == "table" then parts[#parts + 1] = "type " .. Val(c.clubType) .. " id " .. Val(c.clubId) end
  end
  info("V8", #parts > 0 and ("clubs: " .. table.concat(parts, ", ")) or "no club")
end)

-- ===== V79: GetPVPRankInfo =====
LaunchProbe.atLogin(function()
  if type(GetPVPRankInfo) == "function" then
    result("V79", "pass", "GetPVPRankInfo exists, rank 0: " .. Vals(GetPVPRankInfo, 0))
  else
    result("V79", "fail", "GetPVPRankInfo missing")
  end
end)

-- ===== V99: the merchant's item link and the repair cost =====
local function Merchant(event)
  if passed("V99") then return end
  local link = get(GetMerchantItemLink, 1)
  local id = itemId(link)
  local canRepair = get(CanMerchantRepair)
  local detail = event .. ": GetMerchantItemLink(1) " .. (id and ("item " .. id) or Val(link))
    .. ", CanMerchantRepair " .. Val(canRepair) .. ", GetRepairAllCost " .. Vals(GetRepairAllCost)
  if id and canRepair ~= nil then result("V99", "pass", detail) else info("V99", detail) end
end
on("MERCHANT_SHOW", function() Merchant("MERCHANT_SHOW") end)
on("MERCHANT_UPDATE", function() Merchant("MERCHANT_UPDATE") end)

-- ===== V106: fishing loot's source =====
-- Fishing: IsFishingLoot, or an own cast of a Fishing spell (Vanilla's ranks 7620, 7731, 7732, 18248) within
-- FISH_WINDOW seconds.
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }
local FISH_WINDOW = 30
local fishedAt

on("UNIT_SPELLCAST_CHANNEL_START", function(unit, _, spellID)
  if unit == "player" and num(spellID) and FISHING[spellID] then fishedAt = now() end
end)

local function Loot(event)
  if passed("V106") then return end
  local byApi = get(IsFishingLoot) == true
  local byCast = fishedAt ~= nil and now() - fishedAt <= FISH_WINDOW
  if not (byApi or byCast) then return end
  local way = byApi and "IsFishingLoot" or "a Fishing cast"
  local source = get(GetLootSourceInfo, 1)
  local kind = str(source) and source:match("^(%a+)") or Val(source)
  local id = itemId(get(GetLootSlotLink, 1))
  local detail = event .. " (" .. way .. "): source " .. kind .. ", item " .. (id or Val(id))
  if str(source) and id then result("V106", "pass", detail) else info("V106", detail) end
end
on("LOOT_READY", function() Loot("LOOT_READY") end)
on("LOOT_OPENED", function() Loot("LOOT_OPENED") end)

-- ===== V119: the campfire =====
-- Basic Campfire is spell 818 in Vanilla; a spell whose name has "Campfire" counts too (Forever may differ).
local CAMPFIRE = 818
local CAMPFIRE_WINDOW = 600 -- seconds after lighting that auras are watched
local campfireAt, auras

local function SpellName(id)
  local data = C_Spell and C_Spell.GetSpellInfo and get(C_Spell.GetSpellInfo, id)
  if type(data) == "table" and str(data.name) then return data.name end
  local name = get(GetSpellInfo, id)
  return str(name) and name or nil
end

-- The helpful auras on you: { [spellId] = "<name> <id> stacks <n> points <p1>" }.
local function Auras()
  local seen = {}
  local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not byIndex then return seen end
  for i = 1, 40 do
    local a = get(byIndex, "player", i, "HELPFUL")
    if type(a) ~= "table" then break end
    local id = num(a.spellId)
    if id then
      local points = type(a.points) == "table" and a.points[1]
      seen[id] = Val(a.name) .. " " .. id .. " stacks " .. Val(a.applications) .. " points " .. Val(points)
    end
  end
  return seen
end

on("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit ~= "player" or not num(spellID) then return end
  local name = SpellName(spellID)
  if spellID ~= CAMPFIRE and not (name and name:find("Campfire", 1, true)) then return end
  campfireAt, auras = now(), Auras()
  if not passed("V119") then info("V119", "campfire lit: spell " .. spellID .. " " .. Val(name)) end
end)

on("UNIT_AURA", function(unit)
  if unit ~= "player" or not campfireAt or now() - campfireAt > CAMPFIRE_WINDOW then return end
  local current = Auras()
  for id, line in pairs(current) do
    if auras[id] ~= line then
      note("V119", "aura near the campfire: " .. line)
      if not auras[id] then result("V119", "pass", "campfire lit; new aura " .. line) end
    end
  end
  auras = current
end)
