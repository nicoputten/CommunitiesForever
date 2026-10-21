-- Minimap: LibDataBroker launcher + LibDBIcon button. Left-click: window, right-click: settings.
local ADDON_NAME, ns = ...

local Minimap = {}

local ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"

local addonRef

local function onlineCount()
  local count = 0
  for _ in pairs(ns.PresenceTracker.online()) do count = count + 1 end
  return count
end

function Minimap.start(addon)
  addonRef = addon
  local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = ADDON_NAME,
    icon = ICON,
    OnClick = function(_, button)
      if button == "RightButton" then
        ns.Settings.open()
      else
        ns.MainFrame.toggle()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine(ADDON_NAME)
      tooltip:AddLine(string.format("%d friend(s) online in Forever", onlineCount()), 1, 1, 1)
      tooltip:AddLine("Left-click: open window", 0.8, 0.8, 0.8)
      tooltip:AddLine("Right-click: settings", 0.8, 0.8, 0.8)
    end,
  })
  LibStub("LibDBIcon-1.0"):Register(ADDON_NAME, launcher, addon.db.global.settings.minimap)
  -- Hidden while passive (no community), whatever the setting says; shown again once one appears.
  -- Own AceEvent object: AceEvent keeps one handler per object and message.
  LibStub("AceEvent-3.0"):Embed({}):RegisterMessage(ns.CommunitySelection.PASSIVE_CHANGED, Minimap.apply)
  Minimap.apply()
end

function Minimap.isShown()
  return not addonRef.db.global.settings.minimap.hide
end

-- Shows or hides the button per the setting and the passive state.
function Minimap.apply()
  local icon = LibStub("LibDBIcon-1.0")
  if Minimap.isShown() and not ns.CommunitySelection.passive() then
    icon:Show(ADDON_NAME)
  else
    icon:Hide(ADDON_NAME)
  end
end

function Minimap.setShown(shown)
  addonRef.db.global.settings.minimap.hide = not shown or nil
  Minimap.apply()
end

ns.Minimap = Minimap
return Minimap
