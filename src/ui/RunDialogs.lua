-- RunDialogs: Ask now and the reload prompt (CF-47; CF-63b: answering is inline, RunAnswer; CF-64: no planning in
-- the game, that happens on the website or with the bot's /plan; design
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
-- CF-64: the reload prompt's detail, in the ⓘ (the dialog itself says only what to do).
local RELOAD_TIP = "The game saves only on a reload or logout; your uploader then posts the ask on Discord, about "
  .. "15 seconds later. Without a reload it waits for your next logout, and after 10 minutes it has expired."

local dialog, pools, infos
local noteBox
local state = {} -- what the open dialog shows and edits

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
  }
  noteBox = Kit.input(content, { width = WIDTH - 2 * PAD, maxLetters = ns.Pending.MAX_NOTE })
  infos = Kit.pool(Kit.info)
end

local function begin(title, height)
  if not dialog then create() end
  for _, p in pairs(pools) do Kit.release(p) end
  Kit.release(infos)
  noteBox:Hide()
  noteBox:ClearAllPoints()
  dialog.titleText:SetText(title)
  dialog:SetHeight(height)
  -- CF-64: on the window when it is open (it opened outside it, on the right).
  local window = ns.MainFrame.window and ns.MainFrame.window()
  if window and window:IsShown() then
    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER", window, "CENTER", 0, 0)
  end
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

-- ===== Reload prompt =====

-- After Ask now: reload now so the game saves and the ask reaches Discord, or later (CF-64: short; the detail in an ⓘ).
function RunDialogs.reloadPrompt()
  begin("Post on Discord?", 150)
  local head = text("name", 18, "Reload to post it on Discord", "goldLight")
  local hw = head.text.GetStringWidth and head.text:GetStringWidth() or 240
  local info = Kit.take(infos, dialog.content)
  info:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", PAD + hw + 8, -21)
  info.tip = RELOAD_TIP
  text("small", 46, "Friends in game got it already.", "textDim")
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

-- note (CF-63b, optional): the note to start with ("For SM: Graveyard 20:30 · need a healer").
function RunDialogs.askNow(dungeon, note)
  state = { dungeon = dungeon, char = currentChar() }
  local recipients = ns.GroupAsk.recipients(dungeon, ns.Sync.online(), ns.db.global.people,
    ns.db.global.self.battleTag)
  begin("Ask now", 380)
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
    text("small", y, "Nobody online in range: it goes to Discord.", "muted") -- CF-64: still asked
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
  noteBox:SetValue(note or "")
  place(noteBox, PAD, y + 22)
  local ok, wait = ns.GroupAsks.canAsk()
  local main = actions("Ask now", function()
    -- CF-64 (Nico): an ask is always possible: to friends in game when any are online, and always to Discord (the
    -- Discord ask first, CF-51, so the whisper carries its id to every friend's file).
    local typed = noteBox:GetText()
    local post = ns.Planner.askOnDiscord(dungeon.id, state.char, typed)
    ns.GroupAsks.ask(dungeon, ns.Pending.note(typed), post)
    dialog:Hide()
    RunDialogs.reloadPrompt()
  end, not ok and string.format("You can ask again in %d min.", math.ceil(wait / 60)) or nil)
  main:SetEnabled(ok == true)
end

-- For the specs.
function RunDialogs.frame() return dialog end
function RunDialogs.texts()
  local out = {}
  for _, name in ipairs({ "name", "body", "small", "tiny", "label" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
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
function RunDialogs.widgets()
  return { note = noteBox }
end
function RunDialogs.tips()
  local out = {}
  for i = 1, infos and infos.used or 0 do out[i] = infos.items[i].tip end
  return out
end

ns.RunDialogs = RunDialogs
return RunDialogs
