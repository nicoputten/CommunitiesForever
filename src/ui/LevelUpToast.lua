-- LevelUpToast: the level-up announcement at the top of the screen (CF-44; design activity.html, above the
-- window). A pill with the character's portrait, "<person>'s <character> reached level N" and the LEVEL UP
-- chip; shown for Kit.TOAST_SECONDS, then the next one. Level-ups come from Notify (the same rules as the
-- CF-16 chat line); several close together wait in a queue of at most MAX_WAITING.
local _, ns = ...

local LevelUpToast = {}

LevelUpToast.MAX_WAITING = 5

local toast
local waiting = {}
local shown = {} -- for the specs: the texts shown, in order

local function hex(r, g, b)
  local function byte(v) return math.floor((v or 0) * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x", byte(r), byte(g), byte(b))
end

-- "<person>'s <character> reached level N": the person in gold, the character in class colour.
function LevelUpToast.text(item)
  local Theme, Kit = ns.Theme, ns.Kit
  return string.format("%s%s|r's %s%s|r reached level %s", hex(Theme.color("goldLight")), tostring(item.displayName),
    hex(Kit.classColor(item.classFile)), tostring(item.name), tostring(item.level))
end

local showNext

local function create()
  toast = ns.Kit.toast(UIParent, { chip = "LEVEL UP" })
  toast:ClearAllPoints()
  toast:SetPoint("TOP", UIParent, "TOP", 0, -34)
  toast.onDone = function() showNext() end
end

function showNext()
  local item = ns.Queue.pop(waiting)
  if not item then return end
  local text = LevelUpToast.text(item)
  shown[#shown + 1] = text
  toast:Announce(text, item.classFile)
end

-- item = { displayName, name, classFile, level }. Shows it now, or after the ones already waiting.
function LevelUpToast.announce(item)
  if not toast then create() end
  ns.Queue.push(waiting, item, LevelUpToast.MAX_WAITING)
  if not toast:IsShown() then showNext() end
end

-- For the specs: the toast frame (nil before the first one), how many wait, the texts shown so far.
function LevelUpToast.frame() return toast end
function LevelUpToast.waiting() return #waiting end
function LevelUpToast.shown() return shown end

function LevelUpToast.reset()
  toast, waiting, shown = nil, {}, {}
end

ns.LevelUpToast = LevelUpToast
return LevelUpToast
