-- DungeonsTab: the Dungeons tab of the main window (CF-24, layout A). Left: runs planned in the calendar
-- for the next days, then the dungeons that fit your characters. Right: the chosen dungeon with its
-- planned runs, a suggested group, the others in range, and the event title to copy into a community
-- event (addons cannot create one, V34). MainFrame owns the window and passes its widget helpers (ui).
local _, ns = ...

local DungeonsTab = {}

local TREE_WIDTH = 250
local GREEN = "|cff40c040"
local DOT = " \194\183 "

local ui, tree
local entries = {} -- tree value -> overview entry

local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }

local function status()
  local s = ui.settings()
  s.dungeonTree = s.dungeonTree or {}
  return s.dungeonTree
end

-- Section title: regular size gold, with a gap before it (the big font made the card too heavy).
local function section(parent, text)
  ui.spacer(parent)
  ui.label(parent, text, GameFontNormal)
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- One character line: name (class color), level, role, owner, online, quests.
local function characterLine(c)
  local parts = { tostring(c.level) }
  if c.role and ROLE_NAMES[c.role] then parts[#parts + 1] = ROLE_NAMES[c.role] end
  if c.own then
    parts[#parts + 1] = "you"
  else
    parts[#parts + 1] = c.displayName or "community member"
  end
  if c.online then parts[#parts + 1] = "online" end
  if #c.questIDs > 0 then parts[#parts + 1] = plural(#c.questIDs, "quest") end
  return string.format("%s  %s%s|r", ui.colorName(c.name, c.classFile, c.classID), ui.GREY,
    table.concat(parts, DOT))
end

-- "3 signed up · +1 tentative", or nil when the sign-ups are not known (V43).
local function signUpText(event)
  local signed, tentative = ns.Planner.signUpsOf(event)
  if not signed then return nil end
  local text = signed .. " signed up"
  if tentative and tentative > 0 then text = text .. DOT .. "+" .. tentative .. " tentative" end
  return text
end

-- Every dungeon's area IDs, to read QuestieDB once for all of them.
local function allAreaIds()
  local ids = {}
  for _, d in ipairs(ns.Dungeons.LIST) do
    for _, id in ipairs(d.areaIds) do ids[#ids + 1] = id end
  end
  return ids
end

-- The dungeon's quests for your character in the suggested group (CF-24 feedback): QuestieDB when it
-- is installed, else what people in range have in their logs. Completed quests are known only for
-- the character you are on.
local function questInfo(entry)
  local own
  for _, c in ipairs(ns.Dungeons.suggest(entry)) do
    if c.own then own = c end
  end
  local me = ns.SelfInfo.read()
  local data = ns.QuestieData.dungeonQuests(allAreaIds())
  local completed
  if data and own and own.guid == me.guid then
    local ids = {}
    for _, areaId in ipairs(entry.dungeon.areaIds) do
      for _, q in ipairs(data[areaId] or {}) do ids[#ids + 1] = q.id end
    end
    completed = ns.QuestieData.completed(ids)
  end
  return ns.Dungeons.quests(entry.dungeon, data, { char = own, candidates = entry.candidates,
    factionMask = data and ns.QuestieData.factionMask(me.faction), completed = completed })
end

local function questLine(q)
  local name = tostring(q.name or ("Quest " .. q.id))
  local details = {}
  if q.state == "have" then
    return GREEN .. name .. "|r" .. ui.GREY .. DOT .. "in your quest log|r"
  end
  if q.state == "later" then
    return ui.GREY .. name .. DOT .. "from level " .. q.requiredLevel .. "|r"
  end
  if type(q.level) == "number" and q.level > 0 then details[#details + 1] = "level " .. q.level end
  if #q.holders > 0 then details[#details + 1] = table.concat(q.holders, ", ") .. " has it" end
  return name .. (#details > 0 and (ui.GREY .. DOT .. table.concat(details, DOT) .. "|r") or "")
end

local function questsSection(parent, info)
  local hint = ui.GREY .. "Install QuestieDB (it comes with Questie) to see every quest for this dungeon.|r"
  if #info.quests == 0 then
    if not info.complete then ui.label(parent, hint, GameFontHighlightSmall) end
    return
  end
  section(parent, string.format("Quests  %s%d/%d|r", ui.GREY, info.have, info.total))
  local done = 0
  for _, q in ipairs(info.quests) do
    if q.state == "done" then done = done + 1 else ui.label(parent, questLine(q), GameFontHighlight) end
  end
  if done > 0 then
    ui.label(parent, ui.GREY .. plural(done, "quest") .. " already done on this character.|r", GameFontHighlightSmall)
  end
  if not info.complete then
    ui.label(parent, ui.GREY .. "Only quests in someone's quest log.|r " .. hint, GameFontHighlightSmall)
  end
end

-- A copyable field: the text is selected when clicked, so Ctrl+C copies it.
local function copyField(parent, text)
  local edit = ui.createWidget("EditBox")
  edit:SetText(text)
  edit:SetFullWidth(true)
  edit:DisableButton(true)
  if edit.editbox and edit.editbox.SetScript then
    edit.editbox:SetScript("OnEditFocusGained", function(box) box:HighlightText() end)
  end
  parent:AddChild(edit)
  return edit
end

local function showDungeon(value)
  tree:ReleaseChildren()
  local scroll = ui.createWidget("ScrollFrame")
  scroll:SetLayout("List")
  tree:AddChild(scroll)
  scroll:PauseLayout()

  local entry = entries[value]
  if entry then
    local dungeon = entry.dungeon
    ui.label(scroll, string.format("%s  %slevels %d to %d|r", dungeon.name, ui.GREY, dungeon.min, dungeon.max),
      GameFontNormalLarge)

    local events = ns.Dungeons.events(ns.Planner.events(), dungeon, ns.Calendar.now())
    if #events > 0 then
      section(scroll, "Planned")
      for _, e in ipairs(events) do
        local parts = { ns.Dungeons.eventTime(e.startTime), e.title }
        parts[#parts + 1] = signUpText(e)
        parts[#parts + 1] = ns.Dungeons.signUp(e.inviteStatus)
        ui.label(scroll, GREEN .. table.concat(parts, DOT) .. "|r", GameFontHighlight)
      end
    end

    section(scroll, "Suggested group")
    if not entry.fits then
      ui.label(scroll, ui.GREY .. "None of your characters is in range.|r", GameFontHighlightSmall)
    end
    local group = ns.Dungeons.suggest(entry)
    local inGroup, ownOthers = {}, {}
    for _, c in ipairs(group) do inGroup[c.guid] = true end
    for _, c in ipairs(entry.candidates) do
      if c.own and not inGroup[c.guid] then ownOthers[#ownOthers + 1] = c end
    end
    for _, c in ipairs(group) do
      ui.label(scroll, characterLine(c), GameFontHighlight)
      if c.own and #ownOthers > 0 then
        -- Your other characters in range, on one line instead of a list of your own alts.
        local alts = {}
        for i, o in ipairs(ownOthers) do alts[i] = string.format("%s %d", o.name, o.level) end
        ui.label(scroll, "      " .. ui.GREY .. "or " .. table.concat(alts, ", ") .. "|r", GameFontHighlightSmall)
      end
    end
    if #group < 2 then
      ui.label(scroll, ui.GREY .. "Nobody else in range yet.|r", GameFontHighlightSmall)
    end

    questsSection(scroll, questInfo(entry))

    local others = {}
    for _, c in ipairs(entry.candidates) do
      if not c.own and not inGroup[c.guid] then others[#others + 1] = c end
    end
    if #others > 0 then
      section(scroll, "Also in range")
      for _, c in ipairs(others) do ui.label(scroll, characterLine(c), GameFontHighlight) end
    end

    section(scroll, "Plan a run")
    ui.label(scroll, ui.GREY .. "Create a community event in the calendar with this title (click, Ctrl+C).|r",
      GameFontHighlightSmall)
    copyField(scroll, ns.Dungeons.eventTitle(dungeon))
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
  tree:SetCallback("OnGroupSelected", function(_, _, value) showDungeon(value) end)
  content:AddChild(tree)
  ns.Planner.request() -- fresh events; the window refreshes when they arrive
end

local function message(text)
  tree:ReleaseChildren()
  local scroll = ui.createWidget("ScrollFrame")
  scroll:SetLayout("List")
  tree:AddChild(scroll)
  ui.label(scroll, text, GameFontHighlight)
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
function DungeonsTab.render(view, messageText)
  if not tree then return end
  entries = {}
  if messageText then
    tree:SetTree({})
    message(messageText)
    return
  end

  local planned = ns.Planner.planned()
  local include = {}
  for _, p in ipairs(planned) do include[p.dungeon.id] = true end
  local overview = ns.Dungeons.overview(ns.Dungeons.candidates(view), ns.SelfInfo.read().guid, include)
  local byId = {}
  for _, entry in ipairs(overview) do byId[entry.dungeon.id] = entry end

  local nodes = {}
  if #planned > 0 then
    nodes[#nodes + 1] = { value = "header:planned", text = ui.GREY .. "Planned|r", disabled = true }
    for i, p in ipairs(planned) do
      local entry = byId[p.dungeon.id]
      local value = "planned:" .. i
      entries[value] = entry
      local name = entry.fits and p.dungeon.name or (ui.GREY .. p.dungeon.name .. "|r")
      nodes[#nodes + 1] = { value = value, text = string.format("%s  %s%s%s|r", name, GREEN,
        ns.Dungeons.shortTime(p.event.startTime), p.signed and (DOT .. p.signed) or "") }
    end
    nodes[#nodes + 1] = { value = "header:range", text = ui.GREY .. "In range|r", disabled = true }
  end
  for _, entry in ipairs(overview) do
    if entry.fits then
      entries[entry.dungeon.id] = entry
      local text = string.format("%s  %s%d|r", entry.dungeon.name, ui.GREY, entry.people)
      local info = questInfo(entry)
      if info.total > 0 then
        -- Dungeon icon and "have/total" quests (CF-24 feedback; the icon came back).
        text = string.format("%s  %s%s%d/%d|r", text, ui.dungeonIcon(), ui.GOLD, info.have, info.total)
      end
      nodes[#nodes + 1] = { value = entry.dungeon.id, text = text }
    end
  end
  tree:SetTree(nodes)

  if not next(entries) then
    message(ui.GREY .. "None of your characters is in a dungeon's level range yet. The first one, "
      .. "Ragefire Chasm, starts at level 13.|r")
    return
  end
  local selected = status().selected
  if not selected or not entries[selected] then
    for _, node in ipairs(nodes) do
      if entries[node.value] then
        selected = node.value
        break
      end
    end
  end
  tree:SelectByValue(selected)
end

function DungeonsTab.reset()
  tree, entries = nil, {}
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
