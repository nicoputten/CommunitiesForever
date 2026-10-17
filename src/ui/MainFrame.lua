-- MainFrame: the main window. AceGUI Frame with a TreeGroup: people (expandable to their
-- characters) on the left, a detail card on the right. Renders Format models of the view model.
-- Refreshes on change messages while shown; no polling.
local ADDON_NAME, ns = ...

local MainFrame = {}

local REFRESH_DEBOUNCE = 0.2
local TREE_WIDTH = 210
local ONLINE_ICON = "Interface\\COMMON\\Indicator-Green"
local OFFLINE_ICON = "Interface\\COMMON\\Indicator-Gray"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BAR_WIDTH = 180
local GREY = "|cffa0a0a0"

local addonRef, events, frame, tree, refreshDebounced
local view -- last view model, used by the selection callback

local function createWidget(widgetType)
  return LibStub("AceGUI-3.0"):Create(widgetType)
end

local function settings()
  return addonRef.db.global.settings
end

-- C_CreatureInfo.GetClassInfo is verified (V21): classFile and className from a classID.
local function classInfo(classFile, classID)
  if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    local info = C_CreatureInfo.GetClassInfo(classID)
    if info then return classFile or info.classFile, info.className end
  end
  return classFile, nil
end

local function colorName(name, classFile, classID)
  classFile = classInfo(classFile, classID)
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not color then
    return tostring(name)
  end
  local function hex(value) return math.floor(value * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x%s|r", hex(color.r), hex(color.g), hex(color.b), tostring(name))
end

-- Progress bar from two inline textures (filled green, rest dark grey).
local function bar(fraction)
  local filled = math.floor(BAR_WIDTH * fraction + 0.5)
  local parts = {}
  if filled > 0 then
    parts[#parts + 1] = string.format("|T%s:8:%d:0:0:8:8:0:8:0:8:99:153:34|t", BAR_TEXTURE, filled)
  end
  if filled < BAR_WIDTH then
    parts[#parts + 1] = string.format("|T%s:8:%d:0:0:8:8:0:8:0:8:60:60:60|t", BAR_TEXTURE, BAR_WIDTH - filled)
  end
  return table.concat(parts)
end

local function label(parent, text, fontObject, widgetType)
  local widget = createWidget(widgetType or "Label")
  widget:SetText(text)
  widget:SetFullWidth(true)
  if fontObject then widget:SetFontObject(fontObject) end
  parent:AddChild(widget)
  return widget
end

local function spacer(parent)
  label(parent, " ")
end

-- Clickable character list (person and Unlinked details).
local function characterList(parent, groupValue, characters)
  for _, c in ipairs(characters) do
    local text = string.format("%s  %sLvl %s  -  %s|r", colorName(c.name, c.classFile, c.classID), GREY,
      tostring(c.level or "?"), c.seen == "Now" and "Online" or ("Seen " .. c.seen))
    local entry = label(parent, text, GameFontHighlight, "InteractiveLabel")
    entry:SetCallback("OnClick", function()
      tree:SelectByPath(groupValue, c.guid)
    end)
  end
end

local renderDetail = {}

function renderDetail.message(parent, detail)
  label(parent, detail.text, GameFontHighlight)
end

function renderDetail.person(parent, detail, groupValue)
  label(parent, detail.title, GameFontNormalHuge)
  if detail.battleTag then
    label(parent, GREY .. detail.battleTag .. "|r", GameFontHighlightSmall)
  end
  spacer(parent)
  local status = detail.status
  if detail.current and detail.online then
    status = "Online on " .. colorName(detail.current.name, detail.current.classFile, detail.current.classID) ..
      (detail.current.visible == false and (GREY .. " (not in community)|r") or "")
  end
  label(parent, string.format("|T%s:12:12|t %s", detail.online and ONLINE_ICON or OFFLINE_ICON, status),
    GameFontHighlightLarge)
  spacer(parent)

  local heading = createWidget("Heading")
  heading:SetText("Characters")
  heading:SetFullWidth(true)
  parent:AddChild(heading)
  characterList(parent, groupValue, detail.characters)
end

function renderDetail.unlinked(parent, detail, groupValue)
  label(parent, "Unlinked", GameFontNormalHuge)
  label(parent, GREY .. "Community members not linked to one of your Battle.net friends.|r", GameFontHighlightSmall)
  spacer(parent)
  characterList(parent, groupValue, detail.characters)
end

function renderDetail.character(parent, detail)
  label(parent, colorName(detail.name, detail.classFile, detail.classID), GameFontNormalHuge)
  local _, className = classInfo(detail.classFile, detail.classID)
  local subtitle = {}
  if className then subtitle[#subtitle + 1] = className end
  subtitle[#subtitle + 1] = detail.owner
  subtitle[#subtitle + 1] = detail.status
  label(parent, GREY .. table.concat(subtitle, "  -  ") .. "|r", GameFontHighlight)
  spacer(parent)

  local stats = createWidget("SimpleGroup")
  stats:SetFullWidth(true)
  stats:SetLayout("Flow")
  for _, stat in ipairs(detail.stats) do
    local box = createWidget("InlineGroup")
    box:SetTitle(stat.label)
    box:SetRelativeWidth(0.33)
    box:SetLayout("List") -- auto height; "Fill" needs a fixed height
    label(box, stat.value, GameFontHighlightLarge)
    stats:AddChild(box)
  end
  parent:AddChild(stats)
  spacer(parent)

  local heading = createWidget("Heading")
  heading:SetText("Professions")
  heading:SetFullWidth(true)
  parent:AddChild(heading)
  if #detail.professions == 0 then
    label(parent, GREY .. "No professions known.|r", GameFontHighlight)
  end
  for _, p in ipairs(detail.professions) do
    label(parent, string.format("%s  %s%s / %s|r\n%s", tostring(p.name), GREY, tostring(p.rank), tostring(p.max),
      bar(p.fraction)), GameFontHighlight)
  end
end

local function showDetail(path, messageText)
  tree:ReleaseChildren()
  local scroll = createWidget("ScrollFrame")
  scroll:SetLayout("List")
  tree:AddChild(scroll)
  scroll:PauseLayout() -- lay out once after adding everything

  local detail
  if messageText then
    detail = { kind = "message", text = messageText }
  else
    detail = ns.Format.detail(view, path, GetServerTime())
  end
  renderDetail[detail.kind](scroll, detail, path and (ns.Format.splitPath(path)))

  local hint = not messageText and ns.Format.friendsHint(view)
  if hint then
    spacer(scroll)
    label(scroll, GREY .. hint .. "|r", GameFontHighlightSmall)
  end

  scroll:ResumeLayout()
  scroll:DoLayout()
end

-- AceGUI tree from Format nodes. New people start expanded; after that AceGUI remembers.
local function aceTree(nodes)
  local status = settings().tree
  status.groups = status.groups or {}
  status.known = status.known or {}

  local result = {}
  for _, node in ipairs(nodes) do
    if not status.known[node.value] then
      status.known[node.value] = true
      status.groups[node.value] = true
    end
    local children = {}
    for _, c in ipairs(node.children) do
      children[#children + 1] = {
        value = c.value,
        text = string.format("%s  %s%s|r", colorName(c.name, c.classFile, c.classID), GREY, tostring(c.level or "?")),
      }
    end
    result[#result + 1] = {
      value = node.value,
      text = node.text,
      icon = not node.unlinked and (node.online and ONLINE_ICON or OFFLINE_ICON) or nil,
      children = children,
    }
  end
  return result
end

function MainFrame.render()
  if not frame then return end
  view = ns.ViewModel.build(addonRef)
  frame:SetStatusText(string.format("%d people, %d unlinked", #view.people, #view.unlinked))

  local empty = ns.Format.emptyState(view, ns.CommunitySelection.selected() ~= nil)
  if empty then
    tree:SetTree({})
    showDetail(nil, empty)
    return
  end

  local nodes = ns.Format.tree(view)
  tree:SetTree(aceTree(nodes))

  -- Keep the selection while it still exists, else select the first person.
  local status = settings().tree
  local selected = status.selected
  if not selected or ns.Format.detail(view, selected, GetServerTime()).kind == "message" then
    selected = nodes[1] and nodes[1].value
  end
  if selected then
    tree:SelectByValue(selected) -- fires OnGroupSelected -> showDetail
  else
    showDetail(nil)
  end
end

local function create()
  frame = createWidget("Frame")
  frame:SetTitle(ADDON_NAME)
  frame:SetStatusTable(settings().window) -- AceGUI saves position and size here
  frame:SetLayout("Fill")
  frame:SetCallback("OnClose", function() end) -- keep the widget for reuse: closing only hides it

  tree = createWidget("TreeGroup")
  tree:SetStatusTable(settings().tree) -- AceGUI saves expanded groups, selection and tree width here
  tree:SetTreeWidth(TREE_WIDTH, true)
  tree:SetLayout("Fill")
  tree:SetCallback("OnGroupSelected", function(_, _, path)
    showDetail(path)
  end)
  frame:AddChild(tree)
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
  frame, tree, view = nil, nil, nil
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
