-- MainFrame: the main window (AceGUI Frame + ScrollFrame). Renders Format.rows of the view model.
-- Refreshes on change messages while shown; no polling.
local ADDON_NAME, ns = ...

local MainFrame = {}

local REFRESH_DEBOUNCE = 0.2
local INDENT = "      "
local ONLINE_ICON = "|TInterface\\COMMON\\Indicator-Green:12:12|t"
local OFFLINE_ICON = "|TInterface\\COMMON\\Indicator-Gray:12:12|t"
local DETAIL_COLOR = "|cffa0a0a0"

local addonRef, events, frame, scroll, refreshDebounced

local function createWidget(widgetType)
  return LibStub("AceGUI-3.0"):Create(widgetType)
end

local function settings()
  return addonRef.db.global.settings
end

-- Class color escape for a name. C_CreatureInfo.GetClassInfo is unverified (VERIFY.md V21).
local function colorName(name, classFile, classID)
  if not classFile and classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    local info = C_CreatureInfo.GetClassInfo(classID)
    classFile = info and info.classFile
  end
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not color then
    return tostring(name)
  end
  local function hex(value) return math.floor(value * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x%s|r", hex(color.r), hex(color.g), hex(color.b), tostring(name))
end

local function addLabel(widgetType, text, fontObject)
  local label = createWidget(widgetType)
  label:SetText(text)
  label:SetFullWidth(true)
  if fontObject then label:SetFontObject(fontObject) end
  scroll:AddChild(label)
  return label
end

local function toggleCollapsed(key)
  local collapsed = settings().collapsed
  collapsed[key] = not collapsed[key] or nil
  MainFrame.render()
end

function MainFrame.render()
  if not frame then return end
  scroll:PauseLayout() -- lay out once after adding all rows, not per row
  scroll:ReleaseChildren()

  local view = ns.ViewModel.build(addonRef)
  local rows = ns.Format.rows(view, {
    communitySelected = ns.CommunitySelection.selected() ~= nil,
    collapsed = settings().collapsed,
    now = GetServerTime(),
  })

  for _, row in ipairs(rows) do
    if row.kind == "section" then
      local heading = createWidget("Heading")
      heading:SetText(row.text)
      heading:SetFullWidth(true)
      scroll:AddChild(heading)
    elseif row.kind == "spacer" then
      addLabel("Label", " ")
    elseif row.kind == "person" then
      local text = string.format("%s %s %s", row.expanded and "-" or "+",
        row.online and ONLINE_ICON or OFFLINE_ICON, row.text)
      if row.current then
        text = text .. " - on " .. colorName(row.current.name, row.current.classFile, row.current.classID) ..
          (row.current.outside and " (not in community)" or "")
      end
      local label = addLabel("InteractiveLabel", text, GameFontNormal)
      label:SetCallback("OnClick", function() toggleCollapsed(row.key) end)
    elseif row.kind == "char" then
      local text = INDENT .. colorName(row.name, row.classFile, row.classID) .. "  " .. row.line1
      if row.line2 ~= "" then
        text = text .. "\n" .. INDENT .. DETAIL_COLOR .. row.line2 .. "|r"
      end
      addLabel("Label", text, GameFontHighlightSmall)
    else -- "empty", "note"
      addLabel("Label", row.text, GameFontDisable)
    end
  end

  scroll:ResumeLayout()
  scroll:DoLayout()
  frame:SetStatusText(string.format("%d people, %d unlinked", #view.people, #view.unlinked))
end

local function create()
  frame = createWidget("Frame")
  frame:SetTitle(ADDON_NAME)
  frame:SetStatusTable(settings().window) -- AceGUI saves position and size here
  frame:SetLayout("Fill")
  -- Keep the widget for reuse: closing only hides it.
  frame:SetCallback("OnClose", function() end)

  scroll = createWidget("ScrollFrame")
  scroll:SetLayout("List")
  frame:AddChild(scroll)
end

function MainFrame.isShown()
  return frame ~= nil and frame.frame:IsShown()
end

function MainFrame.toggle()
  if MainFrame.isShown() then
    frame:Hide()
    return
  end
  if not frame then
    create()
  else
    frame:Show()
  end
  MainFrame.render()
end

-- Messages that change what the window shows.
local function refreshMessages()
  return {
    ns.SelfTracker.UPDATED,
    ns.MemberTracker.UPDATED,
    ns.PresenceTracker.UPDATED,
    ns.CommunitySelection.CHANGED,
  }
end

function MainFrame.start(addon)
  addonRef = addon
  frame, scroll = nil, nil
  refreshDebounced = ns.Timer.debounce(REFRESH_DEBOUNCE, function()
    if MainFrame.isShown() then MainFrame.render() end
  end)
  -- Own AceEvent object: AceEvent keeps one handler per object and message,
  -- and services already listen to some of these on the addon object.
  events = LibStub("AceEvent-3.0"):Embed({})
  for _, message in ipairs(refreshMessages()) do
    events:RegisterMessage(message, function() refreshDebounced() end)
  end
end

ns.MainFrame = MainFrame

return MainFrame
