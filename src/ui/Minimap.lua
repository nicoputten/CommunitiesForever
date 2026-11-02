-- Minimap: LibDataBroker launcher + LibDBIcon button. Left-click: window, right-click: settings.
-- CF-66: the icon is the designer's gold shield (media/textures/mapicon.tga); LibDBIcon draws its own ring. On
-- clients with the addon compartment (Retail; LibDBIcon checks) the addon is listed there too while the button shows.
local ADDON_NAME, ns = ...

local Minimap = {}

local function icon() return ns.Theme.TEXTURES.mapIcon end

local addonRef

local GREY = { 0.8, 0.8, 0.8 }

-- CF-33: who is online now, one line each: display name left, their character (class color) and level right.
local function addOnline(tooltip)
  local list = ns.Format.onlineList(ns.ViewModel.build(addonRef))
  if #list.entries == 0 then
    tooltip:AddLine(ns.Format.NOBODY_ONLINE, unpack(GREY))
    return
  end
  for _, e in ipairs(list.entries) do
    local char = e.name and ns.MainFrame.colorName(e.name, e.classFile, e.classID) or ""
    if e.level then char = char .. " " .. tostring(e.level) end
    if tooltip.AddDoubleLine then
      tooltip:AddDoubleLine(e.displayName, char, 1, 1, 1)
    else
      tooltip:AddLine(e.displayName .. "  " .. char, 1, 1, 1)
    end
  end
  if list.more > 0 then tooltip:AddLine(string.format("+%d more", list.more), unpack(GREY)) end
end

function Minimap.start(addon)
  addonRef = addon
  local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
    type = "launcher",
    text = ADDON_NAME,
    icon = icon(),
    OnClick = function(_, button)
      if button == "RightButton" then
        ns.Settings.open()
      else
        ns.MainFrame.toggle()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine(ADDON_NAME)
      addOnline(tooltip)
      tooltip:AddLine(" ")
      tooltip:AddLine("Left-click: open window", unpack(GREY))
      tooltip:AddLine("Right-click: settings", unpack(GREY))
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
  local dbIcon = LibStub("LibDBIcon-1.0")
  local shown = Minimap.isShown() and not ns.CommunitySelection.passive()
  if shown then
    dbIcon:Show(ADDON_NAME)
  else
    dbIcon:Hide(ADDON_NAME)
  end
  -- CF-66: in the addon compartment with the button (LibDBIcon does nothing where there is no compartment).
  if shown and dbIcon.AddButtonToCompartment then
    dbIcon:AddButtonToCompartment(ADDON_NAME)
  elseif not shown and dbIcon.RemoveButtonFromCompartment then
    dbIcon:RemoveButtonFromCompartment(ADDON_NAME)
  end
end

function Minimap.setShown(shown)
  addonRef.db.global.settings.minimap.hide = not shown or nil
  Minimap.apply()
end

ns.Minimap = Minimap
return Minimap
