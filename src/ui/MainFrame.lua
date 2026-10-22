-- MainFrame: the main window. AceGUI Frame with a TreeGroup: people (expandable to their
-- characters) on the left, a detail card on the right. Renders Format models of the view model.
-- Refreshes on change messages while shown; no polling.
local ADDON_NAME, ns = ...

local MainFrame = {}

local REFRESH_DEBOUNCE = 0.2
local TREE_WIDTH = 210
local ONLINE_ICON = "Interface\\COMMON\\Indicator-Green"
local OFFLINE_ICON = "Interface\\COMMON\\Indicator-Gray"
-- CF-34: the minimap button's icon, small, after people who run the addon.
local ADDON_MARK = "|TInterface\\Icons\\INV_Misc_GroupNeedMore:12:12|t"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local MIN_BAR_WIDTH = 120
local DOT_SIZE = 14
local GREY = "|cffa0a0a0"
local ONLINE_DOT = string.format("|T%s:%d:%d|t ", ONLINE_ICON, DOT_SIZE, DOT_SIZE)

local DUNGEON_ATLAS = "worldquest-icon-dungeon" -- picked in-game with /fp icons (CF-19, V32)
local GOLD = "|cffffd100"
local TABS = { { value = "friends", text = "Friends" }, { value = "activity", text = "Activity" }, -- CF-22
               { value = "dungeons", text = "Dungeons", width = 140 } } -- CF-24: room for "Dungeons (1)"
local TAB_WIDTH = 90
local TAB_INDENT = 12 -- px, lines the tabs up with the text inside the content box

local addonRef, events, frame, content, tree, refreshDebounced
local tabLinks = {} -- CF-22: tab value -> its text link
local activeTab = "friends" -- CF-22: "friends", "activity" or "dungeons" (CF-24)
local expandedFeed = {}     -- CF-22: Activity lines shown in full (day:battleTag -> true), until /reload
local renderActivity -- CF-22, defined below
local view -- last view model, used by the selection callback
local showAllQuests = {} -- CF-19: tree path -> true when "Show all" is on (until /reload)

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

MainFrame.colorName = colorName -- CF-33: also used by the minimap tooltip

-- Dungeon entrance icon for shared dungeon quests, or a text badge when the atlas is missing.
local dungeonIconText
local function dungeonIcon()
  if not dungeonIconText then
    local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(DUNGEON_ATLAS)
    dungeonIconText = hasAtlas and string.format("|A:%s:%d:%d|a", DUNGEON_ATLAS, DOT_SIZE, DOT_SIZE)
      or (GOLD .. "[D]|r")
  end
  return dungeonIconText
end

-- Progress bar from two inline textures (filled green, rest dark grey), width in pixels.
local function bar(fraction, width)
  local filled = math.floor(width * fraction + 0.5)
  local parts = {}
  if filled > 0 then
    parts[#parts + 1] = string.format("|T%s:8:%d:0:0:8:8:0:8:0:8:99:153:34|t", BAR_TEXTURE, filled)
  end
  if filled < width then
    parts[#parts + 1] = string.format("|T%s:8:%d:0:0:8:8:0:8:0:8:60:60:60|t", BAR_TEXTURE, width - filled)
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

-- Section title: left-aligned gold text, no divider lines.
local function heading(parent, text)
  label(parent, text, GameFontNormalLarge)
end

-- CF-24: the widget helpers the Dungeons tab (ui/DungeonsTab.lua) builds with.
local function uiHelpers()
  return { createWidget = createWidget, label = label, spacer = spacer, heading = heading,
           colorName = colorName, dungeonIcon = dungeonIcon, settings = settings, GREY = GREY, GOLD = GOLD,
           print = function(text) addonRef:Print(text) end }
end

-- Borderless row of columns (SimpleGroup has no frame, unlike InlineGroup).
local function columns(parent)
  local row = createWidget("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")
  parent:AddChild(row)
  return row
end

local function column(row, relativeWidth)
  local col = createWidget("SimpleGroup")
  col:SetRelativeWidth(relativeWidth)
  col:SetLayout("List")
  -- AceGUI's Flow layout centers a widget vertically on its row unless alignoffset says
  -- otherwise; 0 aligns all columns at the top (Talents next to Professions, not below).
  col.alignoffset = 0
  row:AddChild(col)
  return col
end

-- Clickable character list (person and Unlinked details).
local function characterList(parent, groupValue, characters)
  for _, c in ipairs(characters) do
    local text = string.format("%s  %sLvl %s%s  -  %s%s|r", colorName(c.name, c.classFile, c.classID), GREY,
      tostring(c.level or "?"), c.role and ("  -  " .. (ns.Format.ROLE_NAMES[c.role] or c.role)) or "",
      c.seen == "Now" and "Online" or ((c.own and "Played " or "Seen ") .. c.seen),
      c.outside and "  -  not in community" or "")
    local entry = label(parent, text, GameFontHighlight, "InteractiveLabel")
    entry:SetCallback("OnClick", function()
      tree:SelectByPath(groupValue, c.guid)
    end)
  end
end

local function charNames(chars)
  local names = {}
  for _, c in ipairs(chars) do names[#names + 1] = colorName(c.name, c.classFile, c.classID) end
  return table.concat(names, ", ")
end

--[[ CF-19: shared quests grouped by area, dungeon areas first. shared: Format.sharedQuests (character card,
one line per quest with your characters) or Format.personSharedQuests (person card, quests carry
theirChars: a second line with theirs and yours). "Show all N" / "Show fewer" toggles the list per path. ]]
local function sharedQuestsSection(parent, shared, path)
  if not shared then return end
  spacer(parent)
  heading(parent, string.format("Shared quests (%d)", shared.total))
  if shared.total == 0 then
    label(parent, GREY .. "No shared quests.|r", GameFontHighlight)
  end
  for _, area in ipairs(shared.areas) do
    label(parent, GOLD .. tostring(area.area) .. "|r" ..
      (area.dungeon and ("  " .. dungeonIcon() .. " " .. GREY .. "Dungeon|r") or ""), GameFontNormal)
    for _, quest in ipairs(area.quests) do
      if quest.theirChars then
        label(parent, "   " .. tostring(quest.title), GameFontHighlight)
        label(parent, string.format("      %sThem|r %s   %sYou|r %s", GREY, charNames(quest.theirChars), GREY,
          charNames(quest.ownChars)), GameFontHighlightSmall)
      else
        label(parent, string.format("   %s  %s-|r  %s", tostring(quest.title), GREY, charNames(quest.ownChars)),
          GameFontHighlight)
      end
    end
  end
  if shared.expandable and path then
    local toggle = label(parent, shared.showAll and "Show fewer" or string.format("Show all %d", shared.total),
      GameFontNormal, "InteractiveLabel")
    toggle:SetCallback("OnClick", function()
      showAllQuests[path] = not showAllQuests[path] or nil
      MainFrame.render()
    end)
  end
end

local renderDetail = {}

function renderDetail.message(parent, detail)
  label(parent, detail.text, GameFontHighlight)
end

function renderDetail.person(parent, detail, groupValue, path)
  label(parent, detail.title, GameFontNormalHuge)
  if detail.battleTag then
    label(parent, GREY .. detail.battleTag .. "|r", GameFontHighlightSmall)
  end
  if detail.source then
    label(parent, GREY .. detail.source .. "|r", GameFontHighlightSmall)
  end
  if detail.addon then
    label(parent, GREY .. (detail.addon == ns.Format.USES_ADDON and (ADDON_MARK .. " ") or "") .. detail.addon .. "|r",
      GameFontHighlightSmall)
  end
  spacer(parent)
  local status = detail.status
  if detail.current and detail.online then
    status = "Online on " .. colorName(detail.current.name, detail.current.classFile, detail.current.classID) ..
      ((detail.current.visible == false or detail.current.outside) and (GREY .. " (not in community)|r") or "")
  end
  label(parent, string.format("|T%s:%d:%d|t %s", detail.online and ONLINE_ICON or OFFLINE_ICON, DOT_SIZE, DOT_SIZE,
    status),
    GameFontHighlightLarge)
  spacer(parent)

  heading(parent, "Characters")
  characterList(parent, groupValue, detail.characters)
  sharedQuestsSection(parent, detail.sharedQuests, path)
end

function renderDetail.unlinked(parent, detail, groupValue)
  label(parent, "Unlinked", GameFontNormalHuge)
  label(parent, GREY .. "Community members not linked to one of your Battle.net friends.|r", GameFontHighlightSmall)
  spacer(parent)
  characterList(parent, groupValue, detail.characters)
end

function renderDetail.character(parent, detail, _, path)
  label(parent, colorName(detail.name, detail.classFile, detail.classID), GameFontNormalHuge)
  local _, className = classInfo(detail.classFile, detail.classID)
  local subtitle = {}
  if className then subtitle[#subtitle + 1] = className end
  subtitle[#subtitle + 1] = detail.owner
  subtitle[#subtitle + 1] = detail.status
  if detail.outside then subtitle[#subtitle + 1] = "Not in community" end
  label(parent, GREY .. table.concat(subtitle, "  -  ") .. "|r", GameFontHighlight)
  spacer(parent)

  -- Stats as plain text (caption over value), no borders.
  local stats = columns(parent)
  for _, stat in ipairs(detail.stats) do
    local box = column(stats, 0.33)
    label(box, GREY .. stat.label .. "|r", GameFontHighlightSmall)
    label(box, stat.value, GameFontHighlightLarge)
  end
  spacer(parent)

  -- Professions and talents side by side.
  local sections = columns(parent)
  local professions = column(sections, 0.5)
  heading(professions, "Professions")
  if #detail.professions == 0 then
    label(professions, GREY .. "No professions known.|r", GameFontHighlight)
  end
  -- Bars fill the column: half the detail pane minus padding (measured at render time).
  local paneWidth = tree.content and tree.content:GetWidth() or 0
  local barWidth = math.max(MIN_BAR_WIDTH, math.floor(paneWidth / 2) - 40)
  for index, group in ipairs(detail.professions) do
    if index > 1 then spacer(professions) end
    label(professions, GREY .. group.title .. "|r", GameFontHighlightSmall)
    for _, p in ipairs(group.list) do
      label(professions, string.format("%s  %s%s / %s|r\n%s", tostring(p.name), GREY, tostring(p.rank),
        tostring(p.max), bar(p.fraction, barWidth)), GameFontHighlight)
    end
  end
  local talents = column(sections, 0.5)
  heading(talents, "Talents")
  local summary = detail.talents
  if not summary then
    label(talents, GREY .. "No talent data yet. It appears after this character logs in with the addon.|r",
      GameFontHighlight)
  else
    if summary.role then
      label(talents, string.format("Role: %s  %s(%s)|r", summary.role, GREY,
        summary.roleSource == "player" and "set by player" or "from talents"), GameFontHighlight)
    end
    -- Classic notation: "Arms 17 / 0 / 0" (main tree in gold), tree names in order below.
    local build = summary.mainName and string.format("|cffffd100%s|r  %s", summary.mainName, summary.numbers)
      or summary.numbers
    label(talents, build, GameFontHighlightLarge)
    label(talents, GREY .. summary.treeNames .. "|r", GameFontHighlightSmall)
  end

  sharedQuestsSection(parent, detail.sharedQuests, path)
end

-- CF-21: on a character outside the community, step-by-step instructions to join with the shared
-- invite link. Addons may not join themselves (V26); the link opens Blizzard's join window (V27).
local function joinBlock(parent)
  local invite = ns.Invites.current()
  if not invite then return end
  local community = ns.CommunitySelection.name() or "the community"
  local posted = ns.Invites.linkPosted()
  local done = "|cff40c040"

  spacer(parent)
  heading(parent, string.format("How to join %s with %s", community, tostring(view.selfName or "this character")))
  label(parent, string.format("%s1. Click \"Post invite link in chat\" below.|r", posted and done or ""),
    GameFontHighlight)
  label(parent, string.format("2. In your chat window, click the gold [Join %s] link.%s", community,
    posted and "  <- do this now" or ""), GameFontHighlight)
  label(parent, "3. In Blizzard's window that opens, click Join.", GameFontHighlight)
  label(parent, GREY .. "This window then shows the community. If Blizzard says the link is invalid, ask "
    .. tostring(invite.setByName) .. " for a new one.|r", GameFontHighlightSmall)
  spacer(parent)

  local button = createWidget("Button")
  button:SetText(posted and "Post the link again" or "Post invite link in chat")
  button:SetWidth(240)
  button:SetCallback("OnClick", function() ns.Invites.postLink() end)
  parent:AddChild(button)
end

-- extra(scroll): optional, adds widgets after the detail (e.g. the Join button).
local function showDetail(path, messageText, extra)
  tree:ReleaseChildren()
  local scroll = createWidget("ScrollFrame")
  scroll:SetLayout("List")
  tree:AddChild(scroll)
  scroll:PauseLayout() -- lay out once after adding everything

  local detail
  if messageText then
    detail = { kind = "message", text = messageText }
  else
    detail = ns.Format.detail(view, path, GetServerTime(), path and showAllQuests[path])
  end
  renderDetail[detail.kind](scroll, detail, path and (ns.Format.splitPath(path)), path)

  if extra then extra(scroll) end

  local hint = not messageText and ns.Format.friendsHint(view)
  if hint then
    spacer(scroll)
    label(scroll, GREY .. hint .. "|r", GameFontHighlightSmall)
  end

  scroll:ResumeLayout()
  scroll:DoLayout()
end

-- AceGUI tree from Format nodes. New people start expanded; after that AceGUI remembers.
-- How many name characters fit in a tree row: tree width minus indent, dot and level,
-- at roughly 7 px per character of GameFontHighlight.
local function nameCharsForTree()
  local width = settings().tree.treewidth or TREE_WIDTH
  return math.max(8, math.floor((width - 70) / 7))
end

local function aceTree(nodes)
  local maxNameChars = nameCharsForTree()
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
        -- Green dot on the character a person is playing; spaces keep the names aligned.
        -- Long names are shortened so the level stays visible.
        -- CF-19: dungeon entrance icon when this friend's character shares a dungeon quest with you.
        text = string.format("%s%s  %s%s|r%s", c.online and ONLINE_DOT or "      ",
          colorName(ns.Format.truncate(c.name, maxNameChars), c.classFile, c.classID), GREY,
          tostring(c.level or "?"), c.sharedDungeon and (" " .. dungeonIcon()) or ""),
      }
    end
    result[#result + 1] = {
      value = node.value,
      -- Character count; CF-34: the addon's icon after people running it (not on your own row).
      text = string.format("%s%s  %s%d|r", node.text,
        (node.usesAddon and not node.isSelf) and (" " .. ADDON_MARK) or "", GREY, node.count or #node.children),
      icon = not node.unlinked and (node.online and ONLINE_ICON or OFFLINE_ICON) or nil,
      children = children,
    }
  end
  return result
end

function MainFrame.render()
  if not frame then return end
  view = ns.ViewModel.build(addonRef)
  MainFrame.updateTabs()

  local empty = ns.Format.emptyState(view, {
    passive = ns.CommunitySelection.passive(),
    selected = ns.CommunitySelection.selected() ~= nil,
    active = ns.CommunitySelection.active() ~= nil,
    communityName = ns.CommunitySelection.name(),
    characterName = view.selfName,
  })
  if activeTab == "activity" then
    renderActivity(empty)
    return
  end
  if activeTab == "dungeons" then
    ns.DungeonsTab.render(view, empty)
    return
  end
  if empty then
    tree:SetTree({})
    local notMember = ns.CommunitySelection.selected() and not ns.CommunitySelection.active()
    showDetail(nil, empty, notMember and joinBlock or nil)
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

-- CF-22: the Activity tab, in one box (no nested frames). Per person and day two rows: who and on
-- which character, then what they did; "Show all (N)" in link blue opens the remaining parts and the
-- other characters ("Show less" folds them back).
local LINK = "|cff6aa7ff"
local DOT = " \194\183 "
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

-- CF-23: community members by GUID, so companions without a linked person show by name.
local function feedMembers()
  local members = {}
  for _, row in ipairs(view.unlinked or {}) do
    if row.guid and row.name then members[row.guid] = row.name end
  end
  return members
end

function renderActivity(messageText)
  content:ReleaseChildren()
  local box = createWidget("InlineGroup")
  box:SetLayout("Fill")
  content:AddChild(box)
  local scroll = createWidget("ScrollFrame")
  scroll:SetLayout("List")
  box:AddChild(scroll)
  scroll:PauseLayout()

  local days = messageText and {} or ns.Feed.days(view.people, ns.FeedTracker.today(), feedMembers())
  if messageText then
    label(scroll, messageText, GameFontHighlight)
  elseif #days == 0 then
    label(scroll, GREY .. "No activity yet. Levels, quests, professions, dungeons and battlegrounds of you and"
      .. " your friends show up here.|r", GameFontHighlight)
  end
  for dayIndex, day in ipairs(days) do
    if dayIndex > 1 then spacer(scroll) end
    heading(scroll, day.label)
    for _, line in ipairs(day.lines) do
      local key = day.day .. ":" .. tostring(line.key or line.battleTag or "self")
      local expanded = expandedFeed[key]
      local who
      if line.shared then
        -- CF-23: runs done together, one line for everyone in them.
        who = string.format("%s%s|r %stogether|r", GOLD, tostring(line.title), GREY)
      else
        who = string.format("%s%s|r %son|r %s", GOLD, tostring(line.displayName), GREY,
          colorName(line.char.name, line.char.classFile))
      end
      if line.extraChars > 0 then
        who = who .. string.format(" %sand %d more %s|r", GREY, line.extraChars,
          line.extraChars == 1 and "character" or "characters")
      end
      label(scroll, who, GameFontHighlight)

      local function toggle(text)
        local row = label(scroll, text, GameFontHighlight, "InteractiveLabel")
        if row.SetHighlight then row:SetHighlight(HIGHLIGHT) end
        row:SetCallback("OnClick", function()
          expandedFeed[key] = not expanded or nil
          MainFrame.render()
        end)
      end
      local expandable = line.more > 0 or line.extraChars > 0
      if expanded then
        -- Expanded: one part per line, the other characters below, then "Show less".
        for _, part in ipairs(line.parts) do label(scroll, "   " .. part, GameFontHighlight) end
        for _, other in ipairs(line.others) do
          label(scroll, string.format("   %son|r %s", GREY, colorName(other.char.name, other.char.classFile)),
            GameFontHighlight)
          for _, part in ipairs(other.parts) do label(scroll, "      " .. part, GameFontHighlight) end
        end
        toggle("   " .. LINK .. "Show less|r")
      elseif expandable then
        local hidden = line.more
        for _, other in ipairs(line.others) do hidden = hidden + #other.parts end
        toggle(string.format("   %s   %sShow all (%d)|r", table.concat(line.shown, DOT), LINK, hidden))
      else
        label(scroll, "   " .. table.concat(line.shown, DOT), GameFontHighlight)
      end
    end
  end
  if not messageText and not ns.FeedTracker.shared() then
    spacer(scroll)
    label(scroll, GREY .. "You don't share your activity: friends don't see your lines (/cf settings).|r",
      GameFontHighlightSmall)
  end

  scroll:ResumeLayout()
  scroll:DoLayout()
end

local function createTree()
  tree = createWidget("TreeGroup")
  -- No hover tooltip on rows: it repeated the row text on top of the detail card.
  if tree.EnableButtonTooltips then tree:EnableButtonTooltips(false) end
  -- TreeGroup gives child rows GameFontHighlightSmall as the button's normal and highlight
  -- font. The Button reapplies those on hover and click, so set them on the button (not on
  -- its text) and every state keeps the regular size. AceGUI sets them again in RefreshTree
  -- (SetTree, expand, scroll), hence once per refresh. AceGUI reuses released widgets: wrap once.
  if not tree.cfRefreshTree then
    tree.cfRefreshTree = tree.RefreshTree
    tree.RefreshTree = function(widget, ...)
      widget.cfRefreshTree(widget, ...)
      for _, button in ipairs(widget.buttons or {}) do
        if button.level and button.level > 1 then
          button:SetNormalFontObject(GameFontHighlight)
          button:SetHighlightFontObject(GameFontHighlight)
        end
      end
    end
  end
  tree:SetStatusTable(settings().tree) -- AceGUI saves expanded groups, selection and tree width here
  tree:SetTreeWidth(TREE_WIDTH, true)
  tree:SetLayout("Fill")
  tree:SetCallback("OnGroupSelected", function(_, _, path)
    showDetail(path)
  end)
  -- Dragging the tree border changes how much of a name fits: rebuild the rows.
  tree:SetCallback("OnTreeResize", function()
    if view then MainFrame.render() end
  end)
  content:AddChild(tree)
end

local escapeReady -- CF-32: Esc handler set up (not possible in combat: retried on the next show)

local function create()
  frame = createWidget("Frame")
  frame:SetTitle(ADDON_NAME)
  frame:SetStatusTable(settings().window) -- AceGUI saves position and size here
  frame:SetLayout("Flow") -- tab bar row, then the content filling the rest
  frame:SetCallback("OnClose", function() end) -- keep the widget for reuse: closing only hides it
  -- No status bar: hide its background and text (the Close button is separate and stays).
  if frame.statustext and frame.statustext:GetParent() then
    frame.statustext:GetParent():Hide()
  end

  -- CF-22: tabs as plain text (active one gold, others grey), no tab frame, so the content keeps a
  -- single box. Switching releases the content and builds the other one.
  local tabBar = createWidget("SimpleGroup")
  tabBar:SetFullWidth(true)
  tabBar:SetLayout("Flow")
  frame:AddChild(tabBar)
  -- Indent the tabs to the text inside the content box below.
  local indent = createWidget("Label")
  indent:SetText("")
  indent:SetWidth(TAB_INDENT)
  tabBar:AddChild(indent)
  for _, tab in ipairs(TABS) do
    local link = createWidget("InteractiveLabel")
    link:SetFontObject(GameFontNormalLarge)
    link:SetWidth(tab.width or TAB_WIDTH)
    if link.SetHighlight then link:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight") end
    link:SetCallback("OnClick", function() MainFrame.selectTab(tab.value) end)
    tabBar:AddChild(link)
    tabLinks[tab.value] = link
  end

  content = createWidget("SimpleGroup")
  content:SetFullWidth(true)
  content:SetFullHeight(true)
  content:SetLayout("Fill")
  frame:AddChild(content)
  MainFrame.selectTab(activeTab)
end

-- Tab texts: the active one gold. CF-24: "Dungeons (N)" with N runs planned in the next days.
function MainFrame.updateTabs()
  if not frame then return end
  local planned = #ns.Planner.planned()
  for _, tab in ipairs(TABS) do
    local text = tab.text
    if tab.value == "dungeons" and planned > 0 then text = string.format("%s (%d)", text, planned) end
    tabLinks[tab.value]:SetText((tab.value == activeTab and GOLD or GREY) .. text .. "|r")
  end
end

-- Shows a tab ("friends", "activity" or "dungeons").
function MainFrame.selectTab(value)
  if not frame then return end
  activeTab = value
  MainFrame.updateTabs()
  content:ReleaseChildren()
  if value == "friends" then createTree() end
  if value == "dungeons" then ns.DungeonsTab.create(content, uiHelpers()) end
  if view then MainFrame.render() end
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
  if not escapeReady then escapeReady = ns.Keys.closeOnEscape(frame.frame, function() frame:Hide() end) end
  MainFrame.render()
end

-- Messages that change what the window shows.
local function refreshMessages()
  return {
    ns.SelfTracker.UPDATED,
    ns.MemberTracker.UPDATED,
    ns.PresenceTracker.UPDATED,
    ns.CommunitySelection.CHANGED,
    ns.CommunitySelection.PASSIVE_CHANGED,
    ns.Sync.PEOPLE_UPDATED,
    ns.Invites.CHANGED,
    ns.FeedTracker.CHANGED,
    ns.Planner.UPDATED, -- CF-24: calendar events and sign-ups for the Dungeons tab
    ns.GroupAsks.CHANGED, -- CF-27: your ask and its answers
    ns.Sync.PEERS_CHANGED, -- CF-28: community members coming online or leaving
  }
end

function MainFrame.start(addon)
  addonRef = addon
  frame, content, tree, view = nil, nil, nil, nil
  escapeReady = false
  tabLinks = {}
  activeTab, expandedFeed = "friends", {}
  ns.DungeonsTab.reset()
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
