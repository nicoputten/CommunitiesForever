-- HuntPrey: the Hunt's prey hint (CF-114). When you target or mouse over an enemy player of the current character's
-- open Hunt (race and class), their unit tooltip gets "Your prey: The Hunt" (ui/Tooltip.lua asks tooltipLine) and the
-- chat gets "Prey in sight: <race> <class>. Keep them targeted for the kill." at most once per player per
-- Doomsday.PREY_CHAT_EVERY. Forever's honor message doesn't name the victim (V73), so the kill takes it from your
-- target (CF-110): the hint makes players keep their prey targeted. A hint only, it blocks nothing. The rule is
-- Doomsday.isPrey; unit values come from PvpInfo.enemy (every value through ns.Safe.call, a secret one is nil, CF-108).
-- Without a community this character is in, Doomsday is quiet (CF-85): no hint.
local _, ns = ...

local HuntPrey = {}

local addonRef
local said = {} -- { [guid] = when the chat line was last said }

-- The current character's Hunt and whether it is done today, or nil.
local function currentHunt()
  local guid = ns.SelfInfo.guid()
  if not ns.Safe.text(guid) then return nil end
  local char = (addonRef.db.global.self.chars or {})[guid]
  local faction = char and char.faction
  if faction ~= "Horde" and faction ~= "Alliance" then return nil end
  return ns.DoomsdayTracker.huntFor(faction)
end

-- The Hunt when the unit token is its prey right now, else nil.
function HuntPrey.preyAt(unit)
  if not addonRef or type(unit) ~= "string" or ns.Celebrate.quiet() then return nil end
  local hunt, done = currentHunt()
  if not hunt or done then return nil end -- before reading the unit: no Hunt, no reads
  local name, fields = ns.PvpInfo.enemy(unit)
  if not name then return nil end
  local info = ns.Instance.info()
  local facts = { enemy = true, player = true, race = fields.race, class = fields.class }
  if ns.Doomsday.isPrey(hunt, done, facts, info and info.type) then return hunt end
  return nil
end

-- The tooltip line for a unit token, or nil.
function HuntPrey.tooltipLine(unit)
  return HuntPrey.preyAt(unit) and ns.DoomsdayView.PREY_LINE or nil
end

-- A target or mouseover change: the chat line, once per player per few minutes.
local function looked(unit)
  local hunt = HuntPrey.preyAt(unit)
  if not hunt then return end
  local guid = ns.Safe.call(UnitGUID, unit)
  if not ns.Safe.text(guid) then return end
  if ns.Doomsday.preyChatDue(said, guid, GetServerTime()) then addonRef:Print(ns.DoomsdayView.preyChat(hunt)) end
end

function HuntPrey.start(addon)
  addonRef = addon
  said = {}
  -- PvpInfo.CHANGED "unit" comes from PLAYER_TARGET_CHANGED ("target") and UPDATE_MOUSEOVER_UNIT ("mouseover"),
  -- registered by PvpTracker (PvpInfo.watch). Own AceEvent object: the addon's RegisterMessage keeps one handler.
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.PvpInfo.CHANGED, function(_, reason, unit)
    if reason == "unit" and (unit == "target" or unit == "mouseover") then looked(unit) end
  end)
end

ns.HuntPrey = HuntPrey
return HuntPrey
