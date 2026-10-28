-- RunDialogs: Ask now, Plan a run, the answer to a run and the reload prompt (CF-47; design
-- docs/design/runs-2026-10/run-dialogs.html). One kit dialog, redrawn for each; texts and buttons from pools.
-- What has to reach the website goes into the pending list (services/Planner.lua) and needs a /reload: the
-- game saves only then, and the uploader sends the saved file.
local _, ns = ...

local RunDialogs = {}
local Theme, Kit = ns.Theme, ns.Kit

local WIDTH = 460
local PAD = 20
local DOT = " \194\183 "
local ROLE_WORDS = { tank = "tank", heal = "healer", dps = "damage" }
local ROLE_BUTTONS = { tank = "Tank", heal = "Healer", dps = "Damage" }
local TOO_LOW = "6+ levels below: Maybe only"
local ANSWERS = { { value = "in", text = "I'm in" }, { value = "maybe", text = "Maybe" },
                  { value = "cant", text = "Can't" } }
local LATER = "Reaches the site and Discord after /reload. You'll be asked next."
local DISCORD_HELP = "For friends who aren't playing. Needs a /reload to send; posted about 15 s later."
local RELOAD_TEXT = "The game only saves when you reload or log out. Your uploader then sends it; it's on Discord "
  .. "about 15 seconds later. Friends in game already got the whisper."
local LATER_NOTE = "Later: waits for your next reload or logout. If that's more than 10 min away the ask has "
  .. "expired and isn't posted."

local dialog, pools
local noteBox, timeBox, dungeonSelect, leadSelect, discordBox
local state = {} -- what the open dialog shows and edits

local function now() return GetServerTime() end

local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

local function classColored(c, text)
  return Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(text or c.name) .. "|r"
end

-- Your characters, highest level first: { guid, name, level, classFile, role }.
local function ownChars()
  local list = {}
  for guid, c in pairs(ns.db and ns.db.global.self.chars or {}) do
    if type(c) == "table" and type(c.level) == "number" then
      list[#list + 1] = { guid = guid, name = c.name, level = c.level, classFile = c.classFile, role = c.role or "dps" }
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level > b.level end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

-- The character you are on (from your record when known, for its role).
local function currentChar()
  local me = ns.SelfInfo.read()
  for _, c in ipairs(ownChars()) do
    if c.guid == me.guid then return c end
  end
  return { guid = me.guid, name = me.name, level = me.level, classFile = me.classFile, role = "dps" }
end

local function charText(c)
  return classColored(c, tostring(c.name) .. " " .. tostring(c.level)) .. DOT .. (ROLE_WORDS[c.role] or "damage")
end

-- ===== The dialog =====

local function create()
  dialog = Kit.dialog({ title = "", width = WIDTH, height = 300 })
  dialog.footer:Hide()
  local content = dialog.content
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", dialog.titleBar, "BOTTOMLEFT")
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  pools = {
    name = Kit.pool(Kit.textHolder("group")), body = Kit.pool(Kit.textHolder("body")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    label = Kit.pool(Kit.textHolder("label")),
    buttons = Kit.pool(function(parent) return Kit.button(parent, "", nil) end),
    ghost = Kit.pool(function(parent) return Kit.button(parent, "", nil, "ghost") end),
    primary = Kit.pool(function(parent) return Kit.button(parent, "", nil, "primary") end),
    rows = Kit.pool(function(parent)
      local r = Kit.listRow(parent)
      r.text = Theme.text(r, "small", "text")
      r.text:SetPoint("LEFT", 12, 0)
      r.right = Theme.text(r, "tiny", "muted")
      r.right:SetPoint("RIGHT", -12, 0)
      return r
    end),
  }
  noteBox = Kit.input(content, { width = WIDTH - 2 * PAD, maxLetters = ns.Pending.MAX_NOTE })
  timeBox = Kit.input(content, { width = 80, maxLetters = 5 })
  dungeonSelect = Kit.select(content, function(value) state.dungeon = ns.Dungeons.get(value) end)
  leadSelect = Kit.select(content, function(value)
    for _, c in ipairs(ownChars()) do
      if c.guid == value then state.char = c end
    end
    -- CF-49: the role row follows the character's class.
    state.role = state.char and ns.PlannedRuns.defaultRole(state.char.classFile, state.char.role)
    state.time, state.note = timeBox:GetText(), noteBox:GetText()
    RunDialogs.drawPlan()
  end)
  discordBox = Kit.checkbox(content, "Also post on Discord", DISCORD_HELP, false, function(on) state.discord = on end)
end

local function begin(title, height)
  if not dialog then create() end
  for _, p in pairs(pools) do Kit.release(p) end
  for _, w in ipairs({ noteBox, timeBox, dungeonSelect, leadSelect, discordBox }) do
    w:Hide()
    w:ClearAllPoints()
  end
  dialog.titleText:SetText(title)
  dialog:SetHeight(height)
  dialog:Show()
  return dialog.content
end

local function text(pool, y, value, color, x, width)
  return Kit.placeText(pools[pool], dialog.content, x or PAD, y, width or (WIDTH - 2 * PAD), value, color)
end

local function label(y, value) return text("label", y, value:upper(), "faint") end

local function place(widget, x, y)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", x, -y)
  widget:Show()
end

local function button(kind, labelText, onClick)
  local b = Kit.take(pools[kind], dialog.content)
  b:SetLabel(labelText)
  b:SetEnabled(true)
  b:SetScript("OnClick", onClick)
  return b
end

-- Cancel and the main button at the bottom right; returns the main button.
local function actions(mainLabel, onMain, note)
  local main = button("primary", mainLabel, onMain)
  main:ClearAllPoints()
  main:SetPoint("BOTTOMRIGHT", dialog.content, "BOTTOMRIGHT", -PAD, 16)
  local cancel = button("ghost", "Cancel", function() dialog:Hide() end)
  cancel:ClearAllPoints()
  cancel:SetPoint("RIGHT", main, "LEFT", -8, 0)
  if note then
    local h = Kit.take(pools.tiny, dialog.content)
    h:ClearAllPoints()
    h:SetPoint("BOTTOMLEFT", dialog.content, "BOTTOMLEFT", PAD, 22)
    h.text:SetWidth(WIDTH - 2 * PAD - 200)
    h.text:SetText(note)
    h.text:SetTextColor(Theme.color("faint"))
  end
  return main
end

-- CF-49: a row of the roles the class can play (Tank, Healer, Damage), the picked one highlighted.
local function roleRow(y, classFile, picked, onPick)
  label(y, "Role")
  local x = PAD
  for _, role in ipairs(ns.PlannedRuns.rolesFor(classFile)) do
    local b = button(role == picked and "buttons" or "ghost", ROLE_BUTTONS[role], function() onPick(role) end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", x, -(y + 18))
    x = x + (b:GetWidth() or 60) + 4
  end
  return y + 56
end

-- A copy of the character with the picked role (what goes into the pending item).
local function withRole(c, role)
  if not c then return nil end
  local copy = {}
  for k, v in pairs(c) do copy[k] = v end
  copy.role = role or c.role
  return copy
end

-- ===== Reload prompt =====

-- After Ask now with Discord or Plan a run: reload now so the game saves, or later.
function RunDialogs.reloadPrompt()
  begin("Post on Discord?", 230)
  text("name", 18, "Reload now to post on Discord", "goldLight")
  text("small", 44, RELOAD_TEXT, "textDim")
  text("tiny", 100, LATER_NOTE, "faint")
  local main = button("primary", "Reload now", function()
    dialog:Hide()
    if not ns.Panels.reload() then
      ns:Print("Type /reload to post it now.")
    end
  end)
  main:ClearAllPoints()
  main:SetPoint("BOTTOMRIGHT", dialog.content, "BOTTOMRIGHT", -PAD, 16)
  local later = button("ghost", "Later", function() dialog:Hide() end)
  later:ClearAllPoints()
  later:SetPoint("RIGHT", main, "LEFT", -8, 0)
end

-- ===== Ask now =====

-- Friends online who are not asked, and why: "Ruk Bloodhoof 27 (above 26)", "Bob is offline".
local function notAsked(dungeon, recipients)
  local asked, parts = {}, {}
  for _, r in ipairs(recipients) do asked[r.battleTag] = true end
  local people = ns.db.global.people
  local online = ns.Sync.online()
  for key, presence in pairs(online) do
    if not asked[key] and type(presence.level) == "number" then
      local why = presence.level > dungeon.max and ("above " .. dungeon.max)
        or presence.level < dungeon.min and ("below " .. dungeon.min) or "no addon"
      parts[#parts + 1] = string.format("%s %d (%s)", tostring(presence.name or key), presence.level, why)
    end
  end
  table.sort(parts)
  local offline = {}
  for key, person in pairs(people or {}) do
    if not online[key] and type(person) == "table" and #ns.GroupAsk.charsInRange(person.chars, dungeon.min,
      dungeon.max) > 0 then
      offline[#offline + 1] = ns.Linker.displayName(key, person.displayName) .. " is offline"
    end
  end
  table.sort(offline)
  for i = 1, math.min(3, #offline) do parts[#parts + 1] = offline[i] end
  return parts
end

function RunDialogs.askNow(dungeon)
  state = { dungeon = dungeon, discord = false, char = currentChar() }
  local recipients = ns.GroupAsk.recipients(dungeon, ns.Sync.online(), ns.db.global.people,
    ns.db.global.self.battleTag)
  begin("Ask now", 430)
  local y = 16
  local title = text("name", y, dungeon.name, "goldLight")
  local tw = title.text.GetStringWidth and title.text:GetStringWidth() or 160
  text("small", y + 2, range(dungeon) .. DOT .. "now", "muted", PAD + tw + 10, 160)
  y = y + 30
  text("small", y, "You go as " .. charText(state.char), "text")
  y = y + 28
  label(y, "Whispered now" .. DOT .. "online and fit")
  y = y + 20
  if #recipients == 0 then
    text("small", y, "Nobody with the addon is online with a character in range.", "muted")
    y = y + 20
  end
  for i, r in ipairs(recipients) do
    if i > 4 then break end
    local c = r.chars[1]
    text("small", y, (c and (tostring(c.name) .. " " .. tostring(c.level)) or "?") .. DOT
      .. tostring(r.displayName or r.battleTag) .. DOT .. "online", "text")
    y = y + 20
  end
  local others = notAsked(dungeon, recipients)
  if #others > 0 then
    text("tiny", y + 2, "Not asked: " .. table.concat(others, ", "), "faint")
    y = y + 34
  end
  label(y + 4, "Note (optional)")
  noteBox:SetValue("")
  place(noteBox, PAD, y + 22)
  y = y + 60
  discordBox:SetChecked(false)
  discordBox:SetWidth(WIDTH - 2 * PAD)
  place(discordBox, PAD, y)
  local ok, wait = ns.GroupAsks.canAsk()
  local main = actions("Ask now", function()
    local note = noteBox:GetText()
    if #recipients > 0 then ns.GroupAsks.ask(dungeon, ns.Pending.note(note)) end
    if state.discord then ns.Planner.askOnDiscord(dungeon.id, state.char, note) end
    dialog:Hide()
    if state.discord then RunDialogs.reloadPrompt() end
  end, not ok and string.format("You can ask again in %d min.", math.ceil(wait / 60)) or nil)
  main:SetEnabled(ok == true)
end

-- ===== Plan a run =====

function RunDialogs.plan(dungeon)
  local char = currentChar()
  state = { dungeon = dungeon, char = char, days = date and ns.PlannedRuns.dayChoices(now(), date) or {},
            day = 1, time = "20:00", note = "", role = ns.PlannedRuns.defaultRole(char.classFile, char.role) }
  RunDialogs.drawPlan()
end

-- (Redrawn when a day is picked; what was typed is kept.)
function RunDialogs.drawPlan()
  begin("Plan a run", 496)
  local y = 16
  label(y, "Dungeon")
  local list = {}
  for _, d in ipairs(ns.Dungeons.LIST) do list[#list + 1] = { value = d.id, text = d.name .. DOT .. range(d) } end
  table.sort(list, function(a, b)
    local da, db = ns.Dungeons.get(a.value), ns.Dungeons.get(b.value)
    if da.min ~= db.min then return da.min < db.min end
    return da.name < db.name
  end)
  dungeonSelect:SetChoices("Dungeon", list, state.dungeon and state.dungeon.id)
  dungeonSelect:SetWidth(WIDTH - 2 * PAD)
  place(dungeonSelect, PAD, y + 18)
  y = y + 56
  label(y, "Lead as")
  local chars = {}
  for _, c in ipairs(ownChars()) do
    chars[#chars + 1] = { value = c.guid, text = tostring(c.name) .. " " .. tostring(c.level) .. DOT
      .. (ROLE_WORDS[c.role] or "damage") }
  end
  leadSelect:SetChoices("Lead as", chars, state.char and state.char.guid)
  leadSelect:SetWidth(WIDTH - 2 * PAD)
  place(leadSelect, PAD, y + 18)
  y = y + 56
  y = roleRow(y, state.char and state.char.classFile, state.role, function(role)
    state.role, state.time, state.note = role, timeBox:GetText(), noteBox:GetText()
    RunDialogs.drawPlan()
  end)
  label(y, "Day")
  local x = PAD
  for i, d in ipairs(state.days) do
    local b = button(i == state.day and "buttons" or "ghost", d.label, function()
      state.day, state.time, state.note = i, timeBox:GetText(), noteBox:GetText()
      RunDialogs.drawPlan()
    end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", x, -(y + 18))
    x = x + (b:GetWidth() or 60) + 4
  end
  y = y + 56
  label(y, "Time")
  timeBox:SetValue(state.time)
  place(timeBox, PAD, y + 18)
  text("tiny", y + 26, "your PC clock" .. DOT .. "friends see their own time", "faint", PAD + 92, 300)
  y = y + 56
  label(y, "Note (optional)")
  noteBox:SetValue(state.note)
  place(noteBox, PAD, y + 18)
  local problem = text("tiny", y + 52, "", "warning")
  actions("Plan run", function()
    local h, m = ns.PlannedRuns.parseClock(timeBox:GetText())
    local day = state.days[state.day]
    local startsAt = h and day and ns.Panels.localTime({ year = day.year, month = day.month, day = day.day,
                                                         hour = h, min = m })
    if not h then
      problem.text:SetText("Type the time as 20:30.")
      return
    end
    if not startsAt then
      problem.text:SetText("This game version can't convert the time. Plan the run on the website.")
      return
    end
    if startsAt <= now() then
      problem.text:SetText("That time has passed.")
      return
    end
    if not (state.dungeon and state.char and state.char.guid) then
      problem.text:SetText("Pick a dungeon and a character.")
      return
    end
    ns.Planner.plan(state.dungeon.id, startsAt, withRole(state.char, state.role), noteBox:GetText())
    dialog:Hide()
    RunDialogs.reloadPrompt()
  end, LATER)
end

-- ===== Answer a run =====

-- Your characters for a run with their fit (CF-49 levelFit: "fits", "+3 over", "carry · +12", "4 below"),
-- fits first, then by level.
local function picks(run)
  local dungeon = ns.Dungeons.get(run.dungeon)
  local list = {}
  for _, c in ipairs(ownChars()) do
    local fit = dungeon and ns.PlannedRuns.levelFit(c.level, dungeon.min, dungeon.max)
      or { kind = "fits", label = "fits", canPick = true }
    list[#list + 1] = { char = c, fit = fit }
  end
  table.sort(list, function(a, b)
    if (a.fit.kind == "fits") ~= (b.fit.kind == "fits") then return a.fit.kind == "fits" end
    return a.char.level > b.char.level
  end)
  return list
end

-- CF-49: picks a character: its role (the addon's when the class can play it) and, when it is 6+ levels
-- below, Maybe instead of I'm in.
local function pick(o, role)
  state.char, state.fit = o.char, o.fit
  state.role = role and ns.PlannedRuns.canPlay(o.char.classFile, role) and role
    or ns.PlannedRuns.defaultRole(o.char.classFile, o.char.role)
  if not o.fit.canPick and state.answer == "in" then state.answer = "maybe" end
end

function RunDialogs.answer(run)
  local me = ns.Planner.me()
  local mine = ns.PlannedRuns.yourAnswer(run, me)
  local options = picks(run)
  state = { run = run, answer = mine and mine.answer or "in", char = nil }
  for _, o in ipairs(options) do
    if mine and o.char.guid == mine.guid then pick(o, mine.role) end
  end
  if not state.char and options[1] and options[1].fit.canPick then pick(options[1]) end
  RunDialogs.drawAnswer(options)
end

function RunDialogs.drawAnswer(options)
  local run = state.run
  local showRole = state.answer ~= "cant" and state.char ~= nil
  local note = state.answer ~= "cant" and state.fit and (state.fit.canPick and state.fit.note or
    (not state.fit.canPick and TOO_LOW))
  begin("Answer", 160 + 28 * #options + 80 + (showRole and 56 or 0) + (note and 20 or 0))
  local dungeon = ns.Dungeons.get(run.dungeon)
  local y = 16
  text("name", y, dungeon and dungeon.name or run.dungeon, "goldLight")
  local when = date and ns.PlannedRuns.whenText(run.startsAt, now(), date) or ""
  local theirs = date and run.organiser and ns.PlannedRuns.theirClock(run.startsAt, run.organiser.utcOffset, date)
  local who = run.organiser and (run.organiser.name or run.organiser.battleTag)
  if theirs and who then when = when .. DOT .. theirs .. " for " .. who end
  text("small", y + 22, when, "muted")
  y = y + 50
  local x = PAD
  for _, a in ipairs(ANSWERS) do
    local b = button(a.value == state.answer and "buttons" or "ghost", a.text, function()
      state.answer = a.value
      RunDialogs.drawAnswer(options)
    end)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", x, -y)
    x = x + (b:GetWidth() or 60) + 4
    -- CF-49: a character 6+ levels below can only answer Maybe.
    if a.value == "in" and state.fit and not state.fit.canPick then b:SetEnabled(false) end
  end
  y = y + 40
  if state.answer ~= "cant" then
    label(y, "Pick my character")
    y = y + 20
    for _, o in ipairs(options) do
      local r = Kit.take(pools.rows, dialog.content)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", PAD, -y)
      r:SetPoint("RIGHT", dialog.content, "RIGHT", -PAD, 0)
      r:SetHeight(26)
      r.text:SetText(charText(o.char))
      r.right:SetText(o.fit.label)
      r.right:SetTextColor(Theme.color(o.fit.kind == "fits" and "onlineText"
        or o.fit.kind == "carry" and "warning" or "muted"))
      r:SetSelected(state.char ~= nil and state.char.guid == o.char.guid)
      r:SetScript("OnClick", function()
        pick(o)
        RunDialogs.drawAnswer(options)
      end)
      y = y + 28
    end
    if note then
      text("tiny", y + 2, note, state.fit.canPick and "muted" or "warning")
      y = y + 20
    end
    if showRole then
      y = roleRow(y + 6, state.char.classFile, state.role, function(role)
        state.role = role
        RunDialogs.drawAnswer(options)
      end) - 6
    end
  end
  text("tiny", y + 6, "reaches Discord after /reload", "faint")
  local organiser = run.organiser and (run.organiser.name or run.organiser.battleTag) or "The organiser"
  actions("Save answer", function()
    ns.Planner.answer(run, state.answer, state.answer ~= "cant" and withRole(state.char, state.role) or nil)
    dialog:Hide()
  end, organiser .. "'s addon gets it right away over addon sync when you're both online.")
end

-- For the specs.
function RunDialogs.frame() return dialog end
function RunDialogs.texts()
  local out = {}
  for _, name in ipairs({ "name", "body", "small", "tiny", "label" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for i = 1, pools and pools.rows.used or 0 do
    out[#out + 1] = pools.rows.items[i].text:GetText() .. " | " .. pools.rows.items[i].right:GetText()
  end
  return out
end
function RunDialogs.buttons()
  local out = {}
  for _, name in ipairs({ "buttons", "ghost", "primary" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  return out
end
function RunDialogs.rows()
  local out = {}
  for i = 1, pools and pools.rows.used or 0 do out[i] = pools.rows.items[i] end
  return out
end
function RunDialogs.widgets()
  return { note = noteBox, time = timeBox, dungeon = dungeonSelect, lead = leadSelect, discord = discordBox }
end

ns.RunDialogs = RunDialogs
return RunDialogs
