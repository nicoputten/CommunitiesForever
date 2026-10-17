-- Tooltip: adds "Sjaak · 3 characters" (or "CommunitiesForever member") to unit tooltips (CF-14).
-- TooltipDataProcessor, AddTooltipPostCall and Enum.TooltipDataType.Unit are verified (V6).
local _, ns = ...

local Tooltip = {}

local LINE_COLOR = { r = 0.25, g = 0.78, b = 0.92 }

local addonRef
local lines -- { [guid] = text }, rebuilt lazily after a change

-- Midnight can hand addons "secret" values (e.g. a hovered unit's GUID in some situations); those
-- cannot be used as table keys. issecretvalue is unverified (VERIFY.md V28): without it, pcall guards.
local function usableGuid(guid)
  if type(guid) ~= "string" then return false end
  if issecretvalue and issecretvalue(guid) then return false end
  return true
end

-- The hovered unit's GUID: data.guid (unverified, V28), else the tooltip's unit.
local function hoveredGuid(tooltip, data)
  if data and data.guid then return data.guid end
  if tooltip and tooltip.GetUnit then
    local _, unit = tooltip:GetUnit()
    if unit then return UnitGUID(unit) end
  end
end

local function lineFor(guid)
  if not lines then
    lines = ns.Format.tooltipLines(ns.ViewModel.build(addonRef))
  end
  return lines[guid]
end

local function onUnitTooltip(tooltip, data)
  local ok, text = pcall(function()
    local guid = hoveredGuid(tooltip, data)
    if not usableGuid(guid) then return nil end
    return lineFor(guid)
  end)
  if ok and text then
    tooltip:AddLine(text, LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b)
  end
end

-- Messages after which the lines must be rebuilt.
local function changeMessages()
  return {
    ns.SelfTracker.UPDATED,
    ns.MemberTracker.UPDATED,
    ns.PresenceTracker.UPDATED,
    ns.CommunitySelection.CHANGED,
    ns.Sync.PEOPLE_UPDATED,
  }
end

function Tooltip.start(addon)
  addonRef = addon
  lines = nil
  local events = LibStub("AceEvent-3.0"):Embed({})
  for _, message in ipairs(changeMessages()) do
    events:RegisterMessage(message, function() lines = nil end)
  end

  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
      and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnitTooltip)
  end
end

ns.Tooltip = Tooltip
return Tooltip
