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
end

function Minimap.isShown()
  return not addonRef.db.global.settings.minimap.hide
end

function Minimap.setShown(shown)
  addonRef.db.global.settings.minimap.hide = not shown or nil
  local icon = LibStub("LibDBIcon-1.0")
  if shown then icon:Show(ADDON_NAME) else icon:Hide(ADDON_NAME) end
end

ns.Minimap = Minimap
return Minimap
