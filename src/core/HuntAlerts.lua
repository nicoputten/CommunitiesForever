-- HuntAlerts: the rules of the Hunt alerts (CF-122; board HB01 "Addon · Hunt alerts" on the Doomsday design canvas).
-- Pure Lua, no WoW globals. Spotting today's quarry stays small: a mark on the target frame and a 3 s toast under
-- it, once per enemy per 10 minutes and at most once a minute, its sound only the first time each day. The kill is
-- big: the Celebrations banner "Quarry bagged". Friends' kills are a line in the friend bar. Requires ns.Doomsday
-- and ns.DoomsdayView.
local _, ns = ...

local HuntAlerts = {}

HuntAlerts.TOAST_SECONDS = 3     -- the toast on screen
HuntAlerts.TOAST_EVERY = 600     -- seconds before the same enemy (GUID) gets the toast again
HuntAlerts.TOAST_GAP = 60        -- seconds between any two toasts

local DOT = " \194\183 "

-- Instance types where the Hunt doesn't count and too many enemies are around: no toast, only the mark.
local NO_TOAST = { pvp = true, arena = true }

-- "Night Elf Druid", or nil without a combination.
function HuntAlerts.comboText(hunt)
  if type(hunt) ~= "table" or hunt.race == nil or hunt.class == nil then return nil end
  return ns.DoomsdayView.raceName(hunt.race) .. " " .. ns.DoomsdayView.className(hunt.class)
end

-- The race's initials for the toast's ring: "NE" (Night Elf), "UN" (Undead); "" without a combination.
function HuntAlerts.initials(hunt)
  if type(hunt) ~= "table" or hunt.race == nil then return "" end
  local name = ns.DoomsdayView.raceName(hunt.race)
  local first, second = name:match("^(%a)%a*%s+(%a)")
  if first then return string.upper(first .. second) end
  return string.upper(name:sub(1, 2))
end

-- The class token of the combination (for the class icon): a token as is, an id through Doomsday's ids.
function HuntAlerts.classFile(hunt)
  local class = type(hunt) == "table" and hunt.class or nil
  if type(class) == "number" then return ns.Doomsday.CLASS_TOKENS[class] end
  return class
end

-- "+5 PvP": the Hunt's points.
function HuntAlerts.pointsText() return "+" .. tostring(ns.Doomsday.pointsFor("hunt")) .. " PvP" end

--[[ The mark on the target frame for a unit: "open" (today's quarry, the Hunt still open), "bagged" (already bagged
today: the grey ring) or nil. hunt = { race, class } of the current character (nil: no Hunt today); done: the Hunt is
done today; unit = { enemy, player, race, class, raceId, classId } as the adapter read it (a secret value nil). The
mark shows in battlegrounds too (HB01 note 7). ]]
function HuntAlerts.mark(hunt, done, unit)
  if type(hunt) ~= "table" or type(unit) ~= "table" then return nil end
  if unit.enemy ~= true or unit.player ~= true then return nil end
  if not ns.Doomsday.isPrey(hunt, false, unit, nil) then return nil end
  return done == true and "bagged" or "open"
end

-- A fresh memory of toasts shown: { seen = { [guid] = at }, last = at of the last toast, soundDay = the day the
-- sound last played }. Lives in memory only (never stored or sent).
function HuntAlerts.newMemory() return { seen = {}, last = nil, soundDay = nil } end

--[[ The toast due for a sighting, or nil, and records it in memory. input = { mark ("open" / "bagged" / nil), guid,
now (seconds), day (Doomsday day number), instanceType (GetInstanceInfo; nil: outside) }. Nil without a mark, a
readable GUID or a time, in a battleground or arena, within TOAST_EVERY of the same enemy's toast or TOAST_GAP of
any toast. Returns { kind = mark, sound } where sound is true only for an open Hunt's first toast of the day. ]]
function HuntAlerts.toast(memory, input)
  if type(memory) ~= "table" or type(input) ~= "table" then return nil end
  local kind, guid, now = input.mark, input.guid, input.now
  if kind ~= "open" and kind ~= "bagged" then return nil end
  if type(guid) ~= "string" or guid == "" or type(now) ~= "number" then return nil end
  if input.instanceType ~= nil and NO_TOAST[input.instanceType] then return nil end
  memory.seen = memory.seen or {}
  for k, at in pairs(memory.seen) do
    if now - at >= HuntAlerts.TOAST_EVERY then memory.seen[k] = nil end
  end
  if memory.seen[guid] then return nil end
  if memory.last and now - memory.last < HuntAlerts.TOAST_GAP then return nil end
  memory.seen[guid], memory.last = now, now
  local sound = false
  if kind == "open" and input.day ~= nil and memory.soundDay ~= input.day then
    sound, memory.soundDay = true, input.day
  end
  return { kind = kind, sound = sound }
end

--[[ The toast's texts for a kind and the Hunt: { kicker, title, line, tip }. "Prey in sight", "Night Elf Druid",
"+5 PvP · keep them targeted" (or "Already bagged today · no points"), and the hover text. ]]
function HuntAlerts.toastText(kind, hunt)
  local combo = HuntAlerts.comboText(hunt) or "Today's quarry"
  local points = HuntAlerts.pointsText()
  return {
    kicker = "Prey in sight", title = combo,
    line = kind == "bagged" and ("Already bagged today" .. DOT .. "no points")
      or (points .. DOT .. "keep them targeted"),
    tip = "Today's quarry" .. DOT .. combo .. DOT .. points,
  }
end

-- ===== Placement (board HB02) =====

HuntAlerts.GAP = 8          -- pixels between the target frame and the toast
HuntAlerts.OWN_TOP = 230    -- the toast's own spot: its top this far below the screen's top, centred

--[[ Where the toast goes, in UIParent units from the screen's bottom left: { mode, x, y } (its bottom left corner).
input = { saved = { x, y } (moved by the player, per character), frame = { left, bottom, top } (Blizzard's target
frame when it is in use, nil when a unit-frame mod replaced it), screen = { width, height }, width, height (the
toast's size in the same units) }. Modes: "saved" (always wins), "above" or "below" the target frame (above when its
bottom is in the lower half of the screen, below otherwise; flipped when it would leave the screen; left edges in
line, kept on screen), "own" (upper centre, OWN_TOP from the top). ]]
function HuntAlerts.placement(input)
  input = input or {}
  local screen = input.screen or {}
  local sw, sh = tonumber(screen.width) or 0, tonumber(screen.height) or 0
  local w, h = tonumber(input.width) or 0, tonumber(input.height) or 0
  local saved = input.saved
  if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
    return { mode = "saved", x = saved.x, y = saved.y }
  end
  local f = input.frame
  if type(f) == "table" and type(f.left) == "number" and type(f.bottom) == "number" and type(f.top) == "number" then
    local above = { mode = "above", y = f.top + HuntAlerts.GAP }
    local below = { mode = "below", y = f.bottom - HuntAlerts.GAP - h }
    local first, second = above, below
    if f.bottom >= sh / 2 then first, second = below, above end
    local function fits(p) return p.y >= 0 and p.y + h <= sh end
    local pick = (fits(first) or not fits(second)) and first or second
    pick.x = math.max(0, math.min(f.left, sw - w))
    return pick
  end
  return { mode = "own", x = math.max(0, (sw - w) / 2), y = sh - HuntAlerts.OWN_TOP - h }
end

HuntAlerts.MARK_TIP = "Today's quarry"
HuntAlerts.MARK_TAG = "Prey"

-- Whether my Hunt (done at `mine`) was the first of the group today: no friend's done time is earlier. others = {
-- at } (friends' done.hunt of today; nil and non-numbers ignored).
function HuntAlerts.firstInGroup(mine, others)
  if type(mine) ~= "number" then return false end
  for _, at in pairs(others or {}) do
    if type(at) == "number" and at < mine then return false end
  end
  return true
end

--[[ The kill's banner (Celebrations moment, big, PvP red, crosshair): kill = { hunt = { race, class } (the target
bagged), zone, clock ("21:02", the player's clock) }, first (first of the group today). The key is the Hunt's daily key
("daily:hunt"), so it never shows twice and folds as a goal. ]]
function HuntAlerts.killMoment(kill, first)
  kill = kill or {}
  local parts = {}
  if type(kill.zone) == "string" and kill.zone ~= "" then parts[#parts + 1] = kill.zone end
  if type(kill.clock) == "string" and kill.clock ~= "" then parts[#parts + 1] = kill.clock end
  return {
    key = "daily:hunt", kind = "daily", weight = "big", edge = "pvp", icon = "crosshair", kicker = "Quarry bagged",
    title = HuntAlerts.comboText(kill.hunt) or "The Hunt", line = table.concat(parts, DOT),
    points = HuntAlerts.pointsText(), badge = first and "First in the group" or nil, view = "today",
  }
end

-- The one chat line after your kill: "Quarry bagged: Night Elf Druid (+5 PvP)."
function HuntAlerts.chatLine(hunt)
  return "Quarry bagged: " .. (HuntAlerts.comboText(hunt) or "The Hunt") .. " (" .. HuntAlerts.pointsText() .. ")."
end

-- A friend's line after their name: "bagged the quarry · Night Elf Druid" (without a known combination, the first
-- part alone).
function HuntAlerts.friendText(hunt)
  local combo = HuntAlerts.comboText(hunt)
  return combo and ("bagged the quarry" .. DOT .. combo) or "bagged the quarry"
end

ns.HuntAlerts = HuntAlerts
return HuntAlerts
