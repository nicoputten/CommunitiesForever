-- DungeonsTab: the Dungeons tab in the revamp's look (CF-42; design docs/design/runs-2026-10/dungeons-runs.html;
-- the planner itself is CF-24, planned runs CF-46). Left: the planned runs (from the website through the
-- uploader, or a friend's addon), then the dungeons in range of the character you are on. Right: a run with
-- its five slots, who answered where, who is close in level and the link to edit it on the website; or a
-- dungeon with its suggested group, your alternatives, asking who's up for it (CF-27), the others in range
-- and its quests. Native frames from the kit, drawn from pools.
local _, ns = ...

local DungeonsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20
local ROW = 44
local SLOT_HEIGHT = 100
local SLOT_GAP = 8
local SOON = 12 * 3600 -- runs starting within this many seconds get the warm colour
local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }
local ROLE_WORDS = { tank = "tank", heal = "healer", dps = "damage" }
local ANSWER_WORDS = { ["in"] = "you: I'm in", maybe = "you: maybe", cant = "you: can't" }
local PENDING = "reaches Discord after /reload" -- CF-47: waiting for the next save and upload
local SOURCE_WORDS = { site = "planned on the website", discord = "planned on Discord", game = "planned in game" }
local DOT = " \194\183 "
local NOTE = "Runs come from the website through your uploader, or from a friend's addon. Ranges are typical "
  .. "levels; the list follows the character you're on."
local ASK_NOTE = "Whispers online friends who fit; can post on Discord too"
local PLAN_TEXT = "Pick a day and time; friends see their own time. Reaches the site and Discord after /reload. "
  .. "Runs planned on the website show here after your uploader fetched them and you /reload."

local root, list, detail
local helpers -- from MainFrame: settings(), render(), print(text)
local entries = {} -- row value -> overview entry, or { run = run } for "run:<id>"
local rows = {}    -- visible list rows: { value, frame }
local pools
local linkBox -- the run's website link to copy

-- ===== Helpers =====

local function status()
  local s = helpers.settings()
  s.dungeonTree = s.dungeonTree or {} -- the keys the AceGUI tree used (rule 8): selected
  return s.dungeonTree
end

local function now() return GetServerTime() end

local function colored(text, colorName) return Theme.code(colorName) .. tostring(text) .. "|r" end

local function classColored(c, text)
  return Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(text or c.name) .. "|r"
end

local function plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end

-- "17–24" with the bundled font; the game font has no en dash.
local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

-- Local times need the game's date (V63); without it, nothing is shown rather than a wrong time.
local function when(at)
  if not date then return "" end
  return ns.PlannedRuns.whenText(at, now(), date)
end

local function clock(at)
  if not date then return "" end
  return ns.PlannedRuns.clock(at, date)
end

local function dungeonOf(run) return ns.Dungeons.get(run.dungeon) end

local function dungeonName(run)
  local d = dungeonOf(run)
  return d and d.name or run.dungeon
end

-- The BattleTag's name part (before "#"), as display names fall back to (ARCHITECTURE "Data model").
local function tagName(battleTag)
  return type(battleTag) == "string" and battleTag:match("^([^#]+)") or nil
end

-- A person on a run as the addon knows them: "you", their display name, or what the site sent.
local function personName(p, candidates, me)
  if not p then return nil end
  if (p.guid and me.guids[p.guid]) or (p.battleTag and p.battleTag == me.battleTag) then return "you" end
  for _, c in ipairs(candidates) do
    if p.guid and c.guid == p.guid then return c.displayName or c.name end
  end
  return tagName(p.battleTag) or p.name
end

local function organiserText(run, candidates, me)
  if ns.PlannedRuns.isOrganiser(run, me) then return "you organise" end
  return personName(run.organiser, candidates, me) or ""
end

local function countsText(run)
  local yes, maybe = ns.PlannedRuns.counts(run)
  local text = yes .. " in"
  if maybe > 0 then text = text .. DOT .. maybe .. " maybe" end
  return text
end

-- The second part of a run row: your answer, a character of yours that fits, or the counts.
local function runStatus(run, candidates, me)
  if run.pending then return colored(PENDING, "faint") end -- CF-47: your plan, not on the site yet
  local mine = ns.PlannedRuns.yourAnswer(run, me)
  if mine and not ns.PlannedRuns.isOrganiser(run, me) then
    local text = ANSWER_WORDS[mine.answer]
    if mine.answer ~= "cant" and mine.name then text = text .. " as " .. mine.name end
    text = colored(text, mine.answer == "cant" and "muted" or "goldLight")
    if mine.pending then text = text .. "  " .. colored(PENDING, "faint") end
    return text
  end
  local fit, role = ns.PlannedRuns.youFit(run, candidates, dungeonOf(run), me, ns.SelfInfo.read().guid)
  if fit then return colored(fit.name .. " fits " .. ROLE_WORDS[role], "onlineText") end
  return countsText(run)
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

-- ===== Factories =====

local function listRow(parent)
  local r = Kit.listRow(parent)
  r:SetHeight(ROW)
  r.name = Theme.text(r, "group", "goldLight")
  r.name:SetPoint("TOPLEFT", 12, -7)
  r.right = Theme.text(r, "tiny", "muted")
  r.right:SetPoint("TOPRIGHT", -12, -8)
  r.meta = Theme.text(r, "tiny", "muted")
  r.meta:SetPoint("BOTTOMLEFT", 12, 7)
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- A slot of a group: portrait (or "?" / "+" / an initial), name and level, role and who, a state line.
local function slotFrame(parent)
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(SLOT_HEIGHT)
  local bg = s:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(Theme.color("white", 0.03))
  s.edges = Kit.edges(s, "divider")
  s.portrait = Kit.portrait(s, 26)
  s.portrait:SetPoint("TOP", 0, -9)
  s.mark = Theme.text(s, "body", "faint")
  s.mark:SetPoint("CENTER", s.portrait)
  s.name = Theme.text(s, "small", "text")
  s.name:SetPoint("TOP", s.portrait, "BOTTOM", 0, -5)
  s.info = Theme.text(s, "tiny", "textDim")
  s.info:SetPoint("TOP", s.name, "BOTTOM", 0, -3)
  s.status = Theme.text(s, "tiny", "muted")
  s.status:SetPoint("TOP", s.info, "BOTTOM", 0, -3)
  return s
end

local function questRow(parent)
  local q = CreateFrame("Frame", nil, parent)
  q:SetHeight(24)
  q.check = q:CreateTexture(nil, "ARTWORK")
  q.check:SetSize(12, 12)
  q.check:SetPoint("LEFT", 2, 0)
  q.check:SetTexture(Theme.TEXTURES.check)
  q.check:SetVertexColor(Theme.color("online"))
  q.name = Theme.text(q, "small", "text")
  q.name:SetPoint("LEFT", 22, 0)
  q.name:SetJustifyH("LEFT")
  q.who = Theme.text(q, "tiny", "muted")
  q.who:SetPoint("RIGHT")
  local sep = q:CreateTexture(nil, "BORDER")
  sep:SetPoint("BOTTOMLEFT")
  sep:SetPoint("BOTTOMRIGHT")
  sep:SetHeight(1)
  sep:SetColorTexture(Theme.color("white", 0.05))
  return q
end

local function button(parent) return Kit.button(parent, "", nil) end
local function primary(parent) return Kit.button(parent, "", nil, "primary") end

-- ===== Drawing =====

local placeText = Kit.placeText

local function section(parent, x, y, width, text, note, noteColor)
  return Kit.section(pools.section, pools.small, parent, x, y, width, text, note, noteColor)
end

local function renderList(runs, overview, me, candidates)
  Kit.release(pools.rows)
  Kit.release(pools.listText)
  rows = {}
  local parent = list.child
  local width = math.max(200, (list:GetWidth() or 0) - 6)
  local y = 4
  local selected = status().selected

  local function label(text)
    placeText(pools.listText, parent, 12, y + 8, width - 24, text:upper(), "faint")
    y = y + 26
  end
  local function row(value, name, right, rightColor, meta, dim)
    local r = Kit.take(pools.rows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = value
    r.name:SetText(name)
    r.name:SetTextColor(Theme.color(dim and "muted" or "goldLight"))
    r.right:SetText(right or "")
    r.right:SetTextColor(Theme.color(rightColor or "muted"))
    r.meta:SetText(meta or "")
    r:SetSelected(value == selected)
    rows[#rows + 1] = { value = value, frame = r }
    y = y + ROW
  end

  -- CF-46: the runs, and how old they are (never pretending to be live).
  label("Runs")
  for _, run in ipairs(runs) do
    local soon = run.startsAt - now() < SOON
    row("run:" .. run.id, dungeonName(run), when(run.startsAt), soon and "soon" or "textDim",
      organiserText(run, candidates, me) .. "    " .. runStatus(run, candidates, me))
  end
  if #runs == 0 then
    placeText(pools.listText, parent, 12, y + 2, width - 24, "No runs planned. Plan one on the website.", "muted")
    y = y + 22
  end
  local data = ns.Planner.data()
  if data then
    local at = when(data.updatedAt):gsub("^Today ", "")
    placeText(pools.listText, parent, 12, y + 4, width - 24, "Runs updated " .. (at ~= "" and ("at " .. at .. DOT)
      or "") .. "/reload for newer", "textDim")
    y = y + 24
  end

  local runsPer = {}
  for _, run in ipairs(runs) do runsPer[run.dungeon] = (runsPer[run.dungeon] or 0) + 1 end
  local inRange = {}
  for _, entry in ipairs(overview) do
    if entry.fits then inRange[#inRange + 1] = entry end
  end
  if #inRange > 0 then
    label(string.format("In range for %s (%s)", tostring(me.name), tostring(me.level or "?")))
    for _, entry in ipairs(inRange) do
      local friends = entry.people - 1
      local meta = friends > 0 and plural(friends, "friend") or "nobody else yet"
      local info = questInfo(entry)
      if info.total > 0 then
        meta = meta .. "    " .. colored(string.format("%d / %d quests", info.have, info.total),
          info.have == info.total and "onlineText" or "goldLight")
      end
      if runsPer[entry.dungeon.id] then meta = meta .. "    " .. colored(plural(runsPer[entry.dungeon.id], "run"),
        "goldLight") end
      row(entry.dungeon.id, entry.dungeon.name, range(entry.dungeon), "muted", meta)
    end
  end
  local note = placeText(pools.listText, parent, 12, y + 10, width - 24, NOTE, "faint")
  note.text:SetTextColor(Theme.color("faint"))
  y = y + 60
  parent:SetHeight(y)
  list:Update()
end

local function edge(s, colorName)
  local c = { Theme.color(colorName) }
  for _, e in ipairs(s.edges) do e:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

-- The five slots of the suggested group.
local function slots(parent, entry, group, y, width)
  local w = math.floor((width - 4 * SLOT_GAP) / 5)
  for i, slot in ipairs(ns.Dungeons.slots(group, entry.selfGuid)) do
    local s = Kit.take(pools.slots, parent)
    s:SetPoint("TOPLEFT", PAD + (i - 1) * (w + SLOT_GAP), -y)
    s:SetWidth(w)
    s:SetAlpha(1)
    s.status:SetText("")
    local c = slot.char
    if c then
      s.portrait:Show()
      s.mark:SetText("")
      s.portrait:SetClass(c.classFile)
      s.portrait:SetOnline(c.online)
      s.name:SetText(classColored(c, ns.Format.truncate(c.name, 14) .. " " .. tostring(c.level)))
      local info = { ROLE_NAMES[c.role] or ROLE_NAMES[slot.role] }
      info[#info + 1] = c.own and "you" or (c.displayName or "member")
      if c.online then info[#info + 1] = "online" end
      s.info:SetText(table.concat(info, DOT))
      s.info:SetTextColor(Theme.color("textDim"))
      edge(s, slot.own and "gold" or "divider")
    else
      s.portrait:Hide()
      s.mark:SetText(slot.missing and "?" or "+")
      s.mark:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      s.name:SetText(ROLE_NAMES[slot.role])
      s.info:SetText(slot.missing and "nobody in range" or "open")
      s.info:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      edge(s, slot.missing and "missing" or "divider")
    end
  end
  return y + SLOT_HEIGHT + 10
end

-- CF-46: the five slots of a run, filled from the answers.
local function runSlots(parent, run, candidates, me, y, width)
  local w = math.floor((width - 4 * SLOT_GAP) / 5)
  local organiser = run.organiser
  for i, slot in ipairs(ns.PlannedRuns.slots(run, candidates, dungeonOf(run))) do
    local s = Kit.take(pools.slots, parent)
    s:SetPoint("TOPLEFT", PAD + (i - 1) * (w + SLOT_GAP), -y)
    s:SetWidth(w)
    s:SetAlpha(slot.maybe and 0.75 or 1)
    local a, c = slot.answer, slot.char
    if a then
      local mine = (a.guid and me.guids[a.guid]) or (a.battleTag and a.battleTag == me.battleTag)
      if c then
        s.portrait:Show()
        s.mark:SetText("")
        s.portrait:SetClass(c.classFile)
        s.portrait:SetOnline(c.online)
        s.name:SetText(classColored(c, ns.Format.truncate(c.name, 14) .. " " .. tostring(c.level)))
      else
        s.portrait:Hide()
        local name = a.name or tagName(a.battleTag) or "?"
        s.mark:SetText(name:match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
        s.mark:SetTextColor(Theme.color("textDim"))
        s.name:SetText(ns.Format.truncate(name, 14))
        s.name:SetTextColor(Theme.color("text"))
      end
      local info = { ROLE_NAMES[a.role or (c and c.role) or "dps"] }
      info[#info + 1] = personName(a, candidates, me)
      s.info:SetText(table.concat(info, DOT))
      s.info:SetTextColor(Theme.color("textDim"))
      local state, stateColor
      if organiser and ((a.guid and a.guid == organiser.guid) or (a.battleTag and a.battleTag == organiser.battleTag))
      then
        state, stateColor = "organiser", "onlineText"
      elseif slot.maybe then
        state, stateColor = "maybe", "goldLight"
      elseif a.source == "discord" then
        state, stateColor = "answered on Discord", "discord"
      elseif c and c.online then
        state, stateColor = "online", "onlineText"
      end
      -- CF-49: how the level fits when it isn't "fits": a carry in the warning colour, others muted.
      local fit = not state and ns.PlannedRuns.fitOf(a, c, dungeonOf(run))
      if fit and fit.label ~= "fits" then
        state, stateColor = fit.label, fit.kind == "carry" and "warning" or "muted"
      end
      s.status:SetText(state or "")
      s.status:SetTextColor(Theme.color(stateColor or "muted"))
      edge(s, mine and "gold" or "divider")
    else
      s.portrait:Hide()
      s.mark:SetText(slot.missing and "?" or "+")
      s.mark:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      s.name:SetText(ROLE_NAMES[slot.role])
      s.name:SetTextColor(Theme.color("text"))
      s.info:SetText(slot.missing and "nobody in range" or "open")
      s.info:SetTextColor(Theme.color(slot.missing and "warning" or "faint"))
      s.status:SetText("")
      edge(s, slot.missing and "missing" or "divider")
    end
  end
  return y + SLOT_HEIGHT + 10
end

-- CF-27: ask friends who's up for it now, or how your ask stands.
local function askBlock(parent, entry, y, width)
  local ask = ns.GroupAsks.current()
  if ask and ask.dungeon.id == entry.dungeon.id then
    local s = ns.GroupAsk.summary(ask)
    local parts = {}
    if #s.join > 0 then parts[#parts + 1] = colored("joining: " .. table.concat(s.join, ", "), "onlineText") end
    if #s.later > 0 then parts[#parts + 1] = "later: " .. table.concat(s.later, ", ") end
    if #s.no > 0 then parts[#parts + 1] = colored("not now: " .. table.concat(s.no, ", "), "muted") end
    if #s.waiting > 0 then parts[#parts + 1] = colored("waiting: " .. table.concat(s.waiting, ", "), "muted") end
    placeText(pools.small, parent, PAD, y + 4, width, "Asked who's up for it" .. DOT .. table.concat(parts, DOT),
      "text")
    return y + 26
  end
  local ok, wait = ns.GroupAsks.canAsk()
  if not ok then
    placeText(pools.small, parent, PAD, y + 4, width, string.format("You can ask again in %d min.",
      math.ceil(wait / 60)), "muted")
    return y + 26
  end
  local b = Kit.take(pools.primary, parent)
  b:SetLabel("Ask now")
  b:SetEnabled(true)
  b:SetScript("OnClick", function() ns.RunDialogs.askNow(entry.dungeon) end) -- CF-47
  b:SetPoint("TOPLEFT", PAD, -y)
  placeText(pools.tiny, parent, PAD + (b:GetWidth() or 140) + 10, y + 7, width, ASK_NOTE, "faint")
  return y + 36
end

local function questColumn(parent, info, x, y, width)
  local hint = "Install QuestieDB (it comes with Questie) to see every quest for this dungeon."
  if #info.quests == 0 then
    y = section(parent, x, y, width, "Quests")
    placeText(pools.small, parent, x, y, width, "No quests known for this dungeon yet.", "muted")
    y = y + 18
    if not info.complete then
      placeText(pools.tiny, parent, x, y, width, hint, "faint")
      y = y + 30
    end
    return y
  end
  y = section(parent, x, y, width, "Quests", string.format("%d / %d in your log", info.have, info.total),
    info.have == info.total and "onlineText" or "goldLight")
  local done = 0
  for _, q in ipairs(info.quests) do
    if q.state == "done" then
      done = done + 1
    else
      local r = Kit.take(pools.quests, parent)
      r:SetPoint("TOPLEFT", x, -y)
      r:SetWidth(width)
      if q.state == "have" then r.check:Show() else r.check:Hide() end
      r.name:SetText(tostring(q.name or ("Quest " .. q.id)))
      r.name:SetTextColor(Theme.color(q.state == "later" and "muted" or "text"))
      r.name:SetWidth(width - 22 - 90)
      local who
      if q.state == "later" then
        who = "from level " .. tostring(q.requiredLevel)
      elseif #q.holders > 0 then
        who = table.concat(q.holders, ", ") .. (q.state == "have" and " too" or " has it")
      elseif type(q.level) == "number" and q.level > 0 then
        who = "level " .. q.level
      end
      r.who:SetText(who or "")
      y = y + 24
    end
  end
  if done > 0 then
    placeText(pools.tiny, parent, x, y + 4, width, plural(done, "quest") .. " already done on this character.", "faint")
    y = y + 20
  end
  if not info.complete then
    placeText(pools.tiny, parent, x, y + 4, width, "Only quests in someone's quest log. " .. hint, "faint")
    y = y + 34
  end
  return y
end

local function planColumn(parent, dungeon, x, y, width)
  y = section(parent, x, y, width, "Plan a run")
  placeText(pools.small, parent, x, y, width, PLAN_TEXT, "textDim")
  y = y + 54
  local b = Kit.take(pools.buttons, parent) -- CF-47
  b:SetLabel("Plan a run")
  b:SetEnabled(true)
  b:SetScript("OnClick", function() ns.RunDialogs.plan(dungeon) end)
  b:SetPoint("TOPLEFT", x, -y)
  return y + 36
end

local function clearDetail()
  for _, name in ipairs({ "name", "section", "small", "tiny", "slots", "quests", "buttons", "primary" }) do
    Kit.release(pools[name])
  end
  linkBox:Hide()
end

-- CF-46: one planned run.
local function renderRun(run, me, candidates)
  local parent = detail.child
  local width = math.max(420, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD - 4
  local dungeon = dungeonOf(run)
  local title = placeText(pools.name, parent, PAD, y, width, dungeonName(run), "heading")
  local tw = title.text.GetStringWidth and title.text:GetStringWidth() or 200
  local soon = run.startsAt - now() < SOON
  local timing = placeText(pools.small, parent, PAD + tw + 12, y + 10, width - tw - 12,
    when(run.startsAt) .. DOT .. ns.PlannedRuns.untilText(run.startsAt, now()), soon and "soon" or "textDim")
  local sub = {}
  if dungeon then sub[#sub + 1] = range(dungeon) end
  sub[#sub + 1] = SOURCE_WORDS[run.source]
  if run.state == "full" then sub[#sub + 1] = "full" end
  if #sub > 0 then
    local ww = timing.text.GetStringWidth and timing.text:GetStringWidth() or 150
    placeText(pools.small, parent, PAD + tw + ww + 24, y + 10, math.max(60, width - tw - ww - 24),
      table.concat(sub, DOT), "muted")
  end
  y = y + 40
  if run.note then
    placeText(pools.small, parent, PAD, y, width, "\226\128\156" .. run.note .. "\226\128\157", "textDim")
    y = y + 26
  end
  local organiser = personName(run.organiser, candidates, me)
  if organiser and organiser ~= "you" then
    placeText(pools.tiny, parent, PAD, y, width, "Organised by " .. organiser .. DOT .. countsText(run), "muted")
    y = y + 20
  end
  -- CF-47: your answer (or plan) until the site has it; answering in game.
  local mineNow = ns.PlannedRuns.yourAnswer(run, me)
  if run.pending or (mineNow and mineNow.pending) then
    placeText(pools.tiny, parent, PAD, y, width, PENDING, "faint")
    y = y + 20
  end
  if not run.pending and not ns.PlannedRuns.isOrganiser(run, me) then
    local b = Kit.take(pools.primary, parent)
    b:SetLabel(mineNow and "Change answer" or "Answer")
    b:SetEnabled(true)
    b:SetScript("OnClick", function() ns.RunDialogs.answer(run) end)
    b:SetPoint("TOPLEFT", PAD, -y)
    y = y + 38
  end

  y = section(parent, PAD, y + 4, width, "Group", countsText(run))
  y = runSlots(parent, run, candidates, me, y, width)
  -- CF-49: reserves wait for a full role; they take no slot.
  local reserves = {}
  for _, a in ipairs(ns.PlannedRuns.reserves(run)) do
    local who = a.name or tagName(a.battleTag) or "?"
    reserves[#reserves + 1] = who .. (a.role and (" (" .. ROLE_NAMES[a.role] .. ")") or "")
  end
  if #reserves > 0 then
    placeText(pools.tiny, parent, PAD, y, width, "Reserve: " .. table.concat(reserves, ", "), "muted")
    y = y + 20
  end
  local close = {}
  for i, entry in ipairs(ns.PlannedRuns.close(run, candidates, dungeon)) do
    if i > 3 then break end
    local c = entry.char
    local whose = c.own and "your alt" or (c.displayName or "member")
    close[#close + 1] = classColored(c, c.name) .. " " .. c.level .. " (" .. whose .. ", " .. entry.fit.label .. ")"
  end
  if #close > 0 then
    placeText(pools.tiny, parent, PAD, y, width, "Close: " .. table.concat(close, ", "), "muted")
    y = y + 20
  end

  local half = math.floor((width - 22) / 2)
  local top = y + 12
  -- Left: at start time. CF-48: from 5 minutes before the start, Invite all opens the start panel; everyone
  -- else can request an invite.
  local started = now() >= run.startsAt - 300
  local left = section(parent, PAD, top, half, "At " .. clock(run.startsAt))
  local isOrganiser = ns.PlannedRuns.isOrganiser(run, me)
  local mine = ns.PlannedRuns.yourAnswer(run, me)
  local lines = {}
  local data = ns.Planner.data()
  if data and data.reminderMinutes and (isOrganiser or (mine and mine.answer ~= "cant")) then
    lines[#lines + 1] = "You'll get a reminder at " .. clock(run.startsAt - data.reminderMinutes * 60) .. "."
  end
  lines[#lines + 1] = isOrganiser and "At start, Invite all invites everyone who's in and online."
    or "At start, the organiser invites everyone who's in."
  placeText(pools.small, parent, PAD, left, half, table.concat(lines, " "), "textDim")
  left = left + 40
  if isOrganiser then
    local b = Kit.take(pools.primary, parent)
    b:SetLabel(started and "Invite all" or ("Invite all" .. DOT .. "from " .. clock(run.startsAt)))
    b:SetEnabled(started)
    b:SetScript("OnClick", function() ns.StartPanel.open(run.id) end)
    b:SetPoint("TOPLEFT", PAD, -left)
    left = left + 36
  elseif started and mine and mine.answer ~= "cant" then
    local b = Kit.take(pools.buttons, parent)
    b:SetLabel("Request invite")
    b:SetEnabled(true)
    b:SetScript("OnClick", function() ns.StartPanel.open(run.id) end)
    b:SetPoint("TOPLEFT", PAD, -left)
    left = left + 36
  end
  -- Right: edit or cancel on the website.
  local x = PAD + half + 22
  local right = section(parent, x, top, half, "Edit or cancel")
  placeText(pools.small, parent, x, right, half, run.url and "On the website. Copy the link:" or "On the website.",
    "textDim")
  right = right + 22
  if run.url then
    linkBox:ClearAllPoints()
    linkBox:SetParent(parent)
    linkBox:SetPoint("TOPLEFT", x, -right)
    linkBox:SetWidth(half)
    linkBox:SetText(run.url)
    linkBox:Show()
    right = right + 36
  end
  parent:SetHeight(math.max(left, right) + PAD)
  detail:Update()
end

local function renderDetail(entry, me, messageText, runs, candidates)
  local parent = detail.child
  local width = math.max(420, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local y = PAD - 4
  if not entry then
    placeText(pools.small, parent, PAD, y, width, messageText or "", "textDim")
    parent:SetHeight(y + 60)
    detail:Update()
    return
  end

  local dungeon = entry.dungeon
  local title = placeText(pools.name, parent, PAD, y, width, dungeon.name, "heading")
  local sub = "levels " .. range(dungeon)
  if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. DOT .. ns.Dungeons.ZONES[dungeon.id] end
  local tw = title.text.GetStringWidth and title.text:GetStringWidth() or 200
  placeText(pools.small, parent, PAD + tw + 12, y + 10, width - tw - 12, sub, "muted")
  y = y + 40

  -- CF-46: the planned runs of this dungeon.
  for _, run in ipairs(runs) do
    if run.dungeon == dungeon.id then
      placeText(pools.small, parent, PAD, y, width, table.concat({ when(run.startsAt),
        organiserText(run, candidates, me), countsText(run) }, DOT), "onlineText")
      y = y + 18
    end
  end
  y = y + 4

  y = section(parent, PAD, y, width, "Suggested group")
  if not entry.fits then
    placeText(pools.small, parent, PAD, y, width, string.format("%s is not in range.", tostring(me.name)), "muted")
    y = y + 20
  end
  local group = ns.Dungeons.suggest(entry)
  y = slots(parent, entry, group, y, width)
  local alternatives, others = ns.Dungeons.outside(entry, group)
  if #alternatives > 0 then
    local names = {}
    for i, c in ipairs(alternatives) do names[i] = classColored(c, c.name .. " " .. c.level) end
    placeText(pools.tiny, parent, PAD, y, width, "Alternatives for you: " .. table.concat(names, ", "), "muted")
    y = y + 20
  end
  if entry.fits then y = askBlock(parent, entry, y + 2, width) end

  if #others > 0 then
    y = section(parent, PAD, y + 8, width, "Also in range")
    for _, c in ipairs(others) do
      local parts = { classColored(c, c.name .. " " .. c.level) }
      if c.role and ROLE_NAMES[c.role] then parts[#parts + 1] = ROLE_NAMES[c.role] end
      parts[#parts + 1] = c.displayName or "community member"
      if c.online then parts[#parts + 1] = "online" end
      placeText(pools.small, parent, PAD, y, width, table.concat(parts, DOT), "textDim")
      y = y + 18
    end
  end

  local half = math.floor((width - 22) / 2)
  local top = y + 12
  local left = questColumn(parent, questInfo(entry), PAD, top, half)
  local right = planColumn(parent, dungeon, PAD + half + 22, top, half)
  parent:SetHeight(math.max(left, right) + PAD)
  detail:Update()
end

-- ===== Public =====

function DungeonsTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  local column = CreateFrame("Frame", nil, root)
  column:SetPoint("TOPLEFT")
  column:SetPoint("BOTTOMLEFT")
  column:SetWidth(Theme.SIZES.listWidth)
  local columnBg = Theme.fill(column, "list", "BACKGROUND")
  columnBg:SetAllPoints()
  local columnLine = Theme.fill(column, "divider", "BORDER")
  columnLine:SetPoint("TOPRIGHT")
  columnLine:SetPoint("BOTTOMRIGHT")
  columnLine:SetWidth(1)
  list = Kit.scrollArea(column)
  list:SetPoint("TOPLEFT", 0, -4)
  list:SetPoint("BOTTOMRIGHT", 0, 4)

  detail = Kit.scrollArea(root)
  detail:SetPoint("TOPLEFT", column, "TOPRIGHT", 0, 0)
  detail:SetPoint("BOTTOMRIGHT")

  -- The run's link to copy: selected when clicked, so Ctrl+C copies it. Typing does not change it.
  linkBox = CreateFrame("EditBox", nil, detail.child)
  linkBox:SetHeight(28)
  linkBox:SetAutoFocus(false)
  linkBox:SetTextInsets(10, 10, 0, 0)
  Theme.font(linkBox, "small")
  linkBox:SetTextColor(Theme.color("text"))
  local boxBg = Theme.fill(linkBox, "input", "BACKGROUND")
  boxBg:SetAllPoints()
  linkBox.edges = Kit.edges(linkBox, "border")
  linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  linkBox:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self.link then self:SetText(self.link) end
  end)
  local setText = linkBox.SetText
  function linkBox:SetText(text)
    self.link = text
    setText(self, text)
  end
  linkBox:Hide()

  pools = {
    rows = Kit.pool(listRow), listText = Kit.pool(Kit.textHolder("tiny")),
    name = Kit.pool(Kit.textHolder("name")), section = Kit.pool(Kit.textHolder("section")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    slots = Kit.pool(slotFrame), quests = Kit.pool(questRow), buttons = Kit.pool(button),
    primary = Kit.pool(primary),
  }
  return root
end

-- Shown: the game's dungeons and level ranges (V46).
function DungeonsTab.show()
  if not root then return end
  root:Show()
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
end

function DungeonsTab.hide() if root then root:Hide() end end

function DungeonsTab.select(value)
  status().selected = value
  helpers.render()
end

-- CF-48: selects a row without drawing (the window draws when it opens on the tab).
function DungeonsTab.selectQuietly(value)
  if helpers then status().selected = value end
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
function DungeonsTab.render(view, messageText)
  if not root then return end
  entries = {}
  clearDetail()
  local me = ns.SelfInfo.read()
  if messageText then
    renderList({}, {}, me, {})
    renderDetail(nil, me, messageText, {}, {})
    return
  end

  local who = ns.Planner.me()
  local runs = ns.Planner.upcoming()
  local candidates = ns.Dungeons.candidates(view)
  local overview = ns.Dungeons.overview(candidates, me.guid)
  local order = {}
  for _, run in ipairs(runs) do
    entries["run:" .. run.id] = { run = run }
    order[#order + 1] = "run:" .. run.id
  end
  for _, entry in ipairs(overview) do
    if entry.fits then
      entries[entry.dungeon.id] = entry
      order[#order + 1] = entry.dungeon.id
    end
  end

  local st = status()
  if not st.selected or not entries[st.selected] then st.selected = order[1] end
  me.guids, me.battleTag = who.guids, who.battleTag
  renderList(runs, overview, me, candidates)
  if not st.selected then
    renderDetail(nil, me, string.format("%s is not in a dungeon's level range yet. The first one, Ragefire "
      .. "Chasm, starts at level 13.", tostring(me.name)), runs, candidates)
    return
  end
  local entry = entries[st.selected]
  if entry.run then
    renderRun(entry.run, me, candidates)
  else
    renderDetail(entry, me, nil, runs, candidates)
  end
end

function DungeonsTab.reset()
  root, entries, rows = nil, {}, {}
end

-- For the specs: the list rows, the card's texts (in pool order), its buttons by label, the link box.
function DungeonsTab.rows() return rows end
function DungeonsTab.linkBox() return linkBox end

function DungeonsTab.texts()
  local out = {}
  for _, name in ipairs({ "listText", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "rows", "slots", "quests" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "name", "right", "meta", "info", "status", "mark", "who" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
    end
  end
  return out
end

function DungeonsTab.buttons()
  local out = {}
  for _, name in ipairs({ "buttons", "primary" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  return out
end

function DungeonsTab.questRows()
  local out = {}
  for i = 1, pools and pools.quests.used or 0 do out[i] = pools.quests.items[i] end
  return out
end

function DungeonsTab.slots()
  local out = {}
  for i = 1, pools and pools.slots.used or 0 do out[i] = pools.slots.items[i] end
  return out
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
