-- DungeonsTab: the Dungeons tab of the main window (CF-24, layout A). Dungeons that fit your characters
-- on the left, the chosen one on the right: a suggested group, the others in range, calendar events
-- that mention it, and what to copy into a calendar event (addons cannot create one, V34).
-- MainFrame owns the window and passes its widget helpers (ui).
local _, ns = ...

local DungeonsTab = {}

local TREE_WIDTH = 230

local ui, tree, overview, calendarAsked
local entries = {} -- dungeon id -> overview entry

local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }

local function status()
  local s = ui.settings()
  s.dungeonTree = s.dungeonTree or {}
  return s.dungeonTree
end

-- One character line: name (class color), level, role, owner, online, quests.
local function characterLine(c)
  local parts = { tostring(c.level) }
  if c.role and ROLE_NAMES[c.role] then parts[#parts + 1] = ROLE_NAMES[c.role] end
  if c.own then
    parts[#parts + 1] = "you"
  elseif c.displayName then
    parts[#parts + 1] = c.displayName
  else
    parts[#parts + 1] = "community member"
  end
  if c.online then parts[#parts + 1] = "online" end
  if #c.questIDs > 0 then
    parts[#parts + 1] = #c.questIDs == 1 and "1 quest" or (#c.questIDs .. " quests")
  end
  return string.format("%s  %s%s|r", ui.colorName(c.name, c.classFile, c.classID), ui.GREY,
    table.concat(parts, " \194\183 "))
end

-- A copyable field: the text is selected when clicked, so Ctrl+C copies it.
local function copyField(parent, labelText, text)
  local edit = ui.createWidget("EditBox")
  edit:SetLabel(labelText)
  edit:SetText(text)
  edit:SetFullWidth(true)
  edit:DisableButton(true)
  if edit.editbox and edit.editbox.SetScript then
    edit.editbox:SetScript("OnEditFocusGained", function(box) box:HighlightText() end)
  end
  parent:AddChild(edit)
  return edit
end

local function showDungeon(id)
  tree:ReleaseChildren()
  local scroll = ui.createWidget("ScrollFrame")
  scroll:SetLayout("List")
  tree:AddChild(scroll)
  scroll:PauseLayout()

  local entry = entries[id]
  if entry then
    local dungeon = entry.dungeon
    ui.label(scroll, string.format("%s  %slevels %d to %d|r", dungeon.name, ui.GREY, dungeon.min, dungeon.max),
      GameFontNormalLarge)
    ui.spacer(scroll)

    local group = ns.Dungeons.suggest(entry)
    ui.heading(scroll, "Suggested group")
    local inGroup = {}
    for _, c in ipairs(group) do
      inGroup[c.guid] = true
      ui.label(scroll, characterLine(c), GameFontHighlight)
    end
    if #group < ns.Dungeons.GROUP_SIZE then
      ui.label(scroll, ui.GREY .. "Nobody else in range yet.|r", GameFontHighlightSmall)
    end

    local others = {}
    for _, c in ipairs(entry.candidates) do
      if not inGroup[c.guid] then others[#others + 1] = c end
    end
    if #others > 0 then
      ui.spacer(scroll)
      ui.heading(scroll, "Also in range")
      for _, c in ipairs(others) do ui.label(scroll, characterLine(c), GameFontHighlight) end
    end

    ui.spacer(scroll)
    ui.heading(scroll, "Calendar")
    local events = ns.Dungeons.events(ns.Calendar.events(), dungeon, ns.Calendar.now())
    if #events == 0 then
      ui.label(scroll, ui.GREY .. "No upcoming calendar event mentions " .. dungeon.name .. ".|r",
        GameFontHighlight)
    end
    for _, e in ipairs(events) do
      local signUp = ns.Dungeons.signUp(e.inviteStatus)
      ui.label(scroll, string.format("%s  %s%s|r", ns.Dungeons.eventTime(e.startTime), e.title,
        signUp and (ui.GREY .. "  \194\183 " .. signUp) or ""), GameFontHighlight)
    end

    ui.spacer(scroll)
    ui.heading(scroll, "Plan a run")
    ui.label(scroll, ui.GREY .. "Addons can't create calendar events. Open the calendar, create a community "
      .. "event, and copy these into it (click a field, then Ctrl+C).|r", GameFontHighlightSmall)
    copyField(scroll, "Event title", ns.Dungeons.eventTitle(dungeon))
    copyField(scroll, "Group", ns.Dungeons.groupText(group))
    local open = ui.createWidget("Button")
    open:SetText("Open calendar")
    open:SetWidth(160)
    open:SetCallback("OnClick", function()
      if not ns.Calendar.open() then
        ui.print("Open the calendar with the date button next to the minimap.")
      end
    end)
    scroll:AddChild(open)
  end

  scroll:ResumeLayout()
  scroll:DoLayout()
end

-- Builds the tab's tree widget into the window content (on switching to the tab).
function DungeonsTab.create(content, helpers)
  ui = helpers
  tree = ui.createWidget("TreeGroup")
  if tree.EnableButtonTooltips then tree:EnableButtonTooltips(false) end
  tree:SetStatusTable(status())
  tree:SetTreeWidth(TREE_WIDTH, true)
  tree:SetLayout("Fill")
  tree:SetCallback("OnGroupSelected", function(_, _, id) showDungeon(id) end)
  content:AddChild(tree)
  if not calendarAsked then
    calendarAsked = true
    ns.Calendar.request() -- the events arrive with CALENDAR_UPDATE_EVENT_LIST (the window refreshes)
  end
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
function DungeonsTab.render(view, messageText)
  if not tree then return end
  entries = {}
  if messageText then
    tree:SetTree({})
    tree:ReleaseChildren()
    local scroll = ui.createWidget("ScrollFrame")
    scroll:SetLayout("List")
    tree:AddChild(scroll)
    ui.label(scroll, messageText, GameFontHighlight)
    return
  end

  overview = ns.Dungeons.overview(ns.Dungeons.candidates(view), ns.SelfInfo.read().guid)
  local nodes = {}
  for _, entry in ipairs(overview) do
    entries[entry.dungeon.id] = entry
    local text = string.format("%s  %s%d|r", entry.dungeon.name, ui.GREY, entry.people)
    if entry.quests > 0 then text = text .. "  " .. ui.dungeonIcon() .. ui.GOLD .. entry.quests .. "|r" end
    nodes[#nodes + 1] = { value = entry.dungeon.id, text = text }
  end
  tree:SetTree(nodes)

  if #nodes == 0 then
    tree:ReleaseChildren()
    local scroll = ui.createWidget("ScrollFrame")
    scroll:SetLayout("List")
    tree:AddChild(scroll)
    ui.label(scroll, ui.GREY .. "None of your characters is in a dungeon's level range yet. The first one, "
      .. "Ragefire Chasm, starts at level 13.|r", GameFontHighlight)
    return
  end
  local selected = status().selected
  if not selected or not entries[selected] then selected = nodes[1].value end
  tree:SelectByValue(selected)
end

function DungeonsTab.reset()
  tree, overview, calendarAsked, entries = nil, nil, nil, {}
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
