-- HuntPrey: the Hunt alerts when you spot today's quarry (CF-114, CF-122; board HB01). When you target or mouse over an
-- enemy player of the current character's Hunt (race and class):
-- - the target frame gets the prey mark (ui/HuntMark.lua) while they are your target: red while the Hunt is open,
--   grey when it is already bagged today, also in battlegrounds; their nameplate gets a red crosshair
--   (ui/HuntPlate.lua, HB02; fully guarded, the launch probe's V146 line tells whether it could attach);
-- - a small toast (ui/HuntToast.lua) for 3 s, once per enemy per 10 minutes and at most once a minute, its sound only
--   at the first sighting of the day; "Already bagged today · no points" without sound; none in a battleground. HB02:
--   next to Blizzard's target frame, or at the spot the player moved it to (/cf hunt move; settings.huntToastSpots,
--   per character GUID, missing = automatic);
-- - their unit tooltip says "Your prey: The Hunt" while the Hunt is open (ui/Tooltip.lua asks tooltipLine).
-- CF-122: the "Prey in sight … keep them targeted" chat line is gone; the one chat line comes after your kill
-- (Celebrate). Forever's honor message doesn't name the victim (V73), so the kill takes it from your target (CF-110,
-- CF-117): the alerts make players keep their prey targeted. Hints only, nothing is blocked. The rules are
-- HuntAlerts.mark and HuntAlerts.toast (core); unit values come from PvpInfo.enemy (every value through
-- ns.Safe.call, a secret one is nil before any comparison, CF-108). Off with the "Hunt alerts" switch
-- (settings.huntAlerts) and without a community this character is in (Doomsday is quiet then, CF-85).
local _, ns = ...

local HuntPrey = {}

local addonRef
local memory = nil -- HuntAlerts.newMemory(): toasts shown (in memory only)

local function settings() return addonRef.db.global.settings end

-- HB02: the toast's spot the player moved it to, for the current character, or nil (automatic placement).
local function savedSpot()
  local spots = settings().huntToastSpots
  local guid = ns.SelfInfo.guid()
  local spot = type(spots) == "table" and ns.Safe.text(guid) and spots[guid] or nil
  if type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number" then return spot end
  return nil
end

local function saveSpot(spot)
  local guid = ns.SelfInfo.guid()
  if not ns.Safe.text(guid) then return end
  local s = settings()
  s.huntToastSpots = type(s.huntToastSpots) == "table" and s.huntToastSpots or {}
  s.huntToastSpots[guid] = spot and { x = spot.x, y = spot.y } or nil
end

-- /cf hunt move and Settings > Move (HB02 D): the box to drag, with Reset and Done.
function HuntPrey.move()
  if not addonRef then return end
  ns.HuntToast.startMoving({ saved = savedSpot(), onSave = saveSpot, onReset = function() saveSpot(nil) end })
end

-- The current character's Hunt and whether it is done today, or nil.
local function currentHunt()
  local guid = ns.SelfInfo.guid()
  if not ns.Safe.text(guid) then return nil end
  local char = (addonRef.db.global.self.chars or {})[guid]
  local faction = char and char.faction
  if faction ~= "Horde" and faction ~= "Alliance" then return nil end
  return ns.DoomsdayTracker.huntFor(faction)
end

local function on() return addonRef ~= nil and ns.Celebrate.huntAlertsOn() and not ns.Celebrate.quiet() end

local function instanceType()
  local info = ns.Instance.info()
  return info and info.type
end

-- The unit's facts for the rules (PvpInfo.enemy), or nil when it is no enemy player.
local function facts(unit)
  local name, fields = ns.PvpInfo.enemy(unit)
  if not name then return nil end
  return { enemy = true, player = true, race = fields.race, class = fields.class, raceId = fields.raceId,
           classId = fields.classId }
end

-- The mark for a unit token ("open", "bagged" or nil) and the Hunt.
local function markAt(unit)
  if not on() or type(unit) ~= "string" then return nil end
  local hunt, done = currentHunt()
  if not hunt then return nil end -- before reading the unit: no Hunt, no reads
  local f = facts(unit)
  return f and ns.HuntAlerts.mark(hunt, done, f), hunt
end

-- The Hunt when the unit token is its prey right now (open Hunt, outside battlegrounds), else nil.
function HuntPrey.preyAt(unit)
  if not on() or type(unit) ~= "string" then return nil end
  local hunt, done = currentHunt()
  if not hunt or done then return nil end
  local f = facts(unit)
  if f and ns.Doomsday.isPrey(hunt, done, f, instanceType()) then return hunt end
  return nil
end

-- The tooltip line for a unit token, or nil.
function HuntPrey.tooltipLine(unit)
  return HuntPrey.preyAt(unit) and ns.DoomsdayView.PREY_LINE or nil
end

-- HB02 E: the crosshair over the target's nameplate, and the probe's V146 line about it.
local function plate(kind)
  local status = ns.HuntPlate.show(kind ~= nil)
  if kind and status and ns.LaunchProbe and ns.LaunchProbe.report then
    ns.LaunchProbe.report("V146", status == "attached" and "pass" or "info", "nameplate crosshair: " .. status)
  end
end

-- The target's mark, again (a new target, the Hunt just done, a setting changed, a nameplate came or went).
function HuntPrey.refreshMark()
  if not addonRef then return end
  local kind = markAt("target")
  ns.HuntMark.show(kind)
  plate(kind)
end

-- A target or mouseover change: the mark and the nameplate crosshair (target only) and the toast.
local function looked(unit)
  local kind, hunt = markAt(unit)
  if unit == "target" then
    ns.HuntMark.show(kind)
    plate(kind)
  end
  if not kind then return end
  local guid = ns.Safe.call(UnitGUID, unit)
  if not ns.Safe.text(guid) then return end
  local due = ns.HuntAlerts.toast(memory, { mark = kind, guid = guid, now = GetServerTime(),
                                            day = ns.DoomsdayTracker.today(), instanceType = instanceType() })
  if not due then return end
  ns.HuntToast.show(ns.HuntAlerts.toastText(due.kind, hunt), {
    initials = ns.HuntAlerts.initials(hunt), classFile = ns.HuntAlerts.classFile(hunt),
    ambient = settings().ambientEffects ~= false, saved = savedSpot() })
  if due.sound and ns.Celebrate.soundsOn() then ns.Sounds.prey() end
end

function HuntPrey.start(addon)
  addonRef = addon
  memory = ns.HuntAlerts.newMemory()
  -- PvpInfo.CHANGED "unit" comes from PLAYER_TARGET_CHANGED ("target") and UPDATE_MOUSEOVER_UNIT ("mouseover"),
  -- registered by PvpTracker (PvpInfo.watch). Own AceEvent object: the addon's RegisterMessage keeps one handler.
  local events = LibStub("AceEvent-3.0"):Embed({})
  -- The target is looked at a moment later (next frame), after Blizzard's target frame updated: whether it shows
  -- tells a unit-frame mod apart (HB02).
  events:RegisterMessage(ns.PvpInfo.CHANGED, function(_, reason, unit)
    if reason ~= "unit" then return end
    if unit == "target" then
      ns.Timer.after(0, function() looked("target") end)
    elseif unit == "mouseover" then
      looked(unit)
    elseif type(unit) == "string" and unit:match("^nameplate%d+$") then
      HuntPrey.refreshMark() -- the target's plate may have just come into view
    end
  end)
  events:RegisterMessage(ns.DoomsdayTracker.CHANGED, function() HuntPrey.refreshMark() end)
  -- A plate leaving the screen is recycled for another unit: the crosshair follows the target's plate or hides.
  ns.Events.register(events, "NAME_PLATE_UNIT_REMOVED", function() HuntPrey.refreshMark() end)
end

-- For the specs.
function HuntPrey.memory() return memory end

ns.HuntPrey = HuntPrey
return HuntPrey
