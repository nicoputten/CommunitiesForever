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
local ROLE_NAMES = { tank = "Tank", heal = "Healer", dps = "DPS" }
local PENDING = "reaches Discord after /reload" -- CF-47: waiting for the next save and upload
local SOURCE_WORDS = { site = "planned on the website", discord = "planned on Discord", game = "planned in game" }
local DOT = " \194\183 "
local ASK_TIP = "Whispers online friends who fit; can post on Discord too. Waits until combat ends." -- CF-61
-- CF-62 (board AG02Dungeons): sizes and the explanations that live in tooltips.
local LIST_WIDTH = 290
local RUN_ROW = 50
local GROUP_ROW = 38
local ONLINE_WIDTH = 250
local ONLINE_ROW = 34
local ROLE_LABEL = { tank = "Tank", heal = "Healer", dps = "Damage" }
local ROSTER_TIP = "From the community roster: online members whose current character fits the level range."
local ANSWER_TIP = "Shared with online friends now; the website gets it with your next upload."
local INVITE_TIP = "Invite all invites everyone who is in and online."
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

-- CF-62: a run row (50 px): the short name and the time; five role pips, "2 in · 1 maybe", the organiser.
local function runRow(parent)
  local r = Kit.listRow(parent)
  r:SetHeight(RUN_ROW)
  r.name = Theme.text(r, "group", "goldLight")
  r.name:SetPoint("TOPLEFT", 12, -8)
  r.right = Theme.text(r, "small", "textDim")
  r.right:SetPoint("TOPRIGHT", -12, -9)
  r.pips = {}
  for i = 1, 5 do
    local p = r:CreateTexture(nil, "ARTWORK")
    p:SetSize(14, 6)
    p:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 17, 12)
    r.pips[i] = p
  end
  r.meta = Theme.text(r, "tiny", "muted")
  r.meta:SetPoint("BOTTOMLEFT", 12 + 5 * 17 + 6, 9)
  r.who = Theme.text(r, "tiny", "muted")
  r.who:SetPoint("BOTTOMRIGHT", -12, 9)
  r:SetScript("OnClick", function(self) DungeonsTab.select(self.value) end)
  return r
end

-- CF-62: a 38 px row of a run's group: role icon, class icon, the full name, "level · friend", the status.
local function groupRow(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetHeight(GROUP_ROW)
  g.bg = Theme.fill(g, "white", "BACKGROUND")
  g.bg:SetAllPoints()
  g.edges = Kit.edges(g, "divider")
  g.role = Kit.roleIcon(g, 20)
  g.role:SetPoint("LEFT", 10, 0)
  g.portrait = Kit.portrait(g, 20)
  g.portrait:SetPoint("LEFT", 38, 0)
  g.name = Theme.text(g, "body", "text")
  g.name:SetPoint("LEFT", 66, 0)
  g.info = Theme.text(g, "small", "muted")
  g.info:SetPoint("LEFT", g.name, "RIGHT", 8, 0)
  g.status = Theme.text(g, "small", "muted")
  g.status:SetPoint("RIGHT", -12, 0)
  g:SetScript("OnEnter", function(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self) if self.tip and GameTooltip then GameTooltip:Hide() end end)
  return g
end

-- CF-62: a 34 px row of "Online now, fits": class icon, name, level, "friend · zone", Whisper or Invite.
local function onlineRow(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetHeight(ONLINE_ROW)
  o.portrait = Kit.portrait(o, 20)
  o.portrait:SetPoint("LEFT", 0, 0)
  o.name = Theme.text(o, "small", "text")
  o.name:SetPoint("TOPLEFT", 28, -4)
  o.level = Theme.text(o, "tiny", "muted")
  o.level:SetPoint("LEFT", o.name, "RIGHT", 6, 0)
  o.info = Theme.text(o, "tiny", "muted")
  o.info:SetPoint("BOTTOMLEFT", 28, 4)
  o.button = Kit.button(o, "", nil)
  o.button:SetPoint("RIGHT", 0, 0)
  if o.button.SetMotionScriptsWhileDisabled then o.button:SetMotionScriptsWhileDisabled(true) end
  return o
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
  Kit.release(pools.runRows)
  Kit.release(pools.listTitle)
  Kit.release(pools.listButtons)
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

  -- CF-62: "Runs" with Ask now…; the runs grouped Tonight, Tomorrow, This week, Later; role pips per row.
  placeText(pools.listTitle, parent, 12, y + 6, width - 24, "Runs", "goldLight")
  local ask = Kit.take(pools.listButtons, parent)
  ask:SetLabel("Ask now\226\128\166")
  ask:SetEnabled(true)
  ask:SetPoint("TOPRIGHT", parent, "TOPLEFT", width - 8, -(y + 4))
  ask:SetScript("OnClick", function() DungeonsTab.askNow() end)
  ask.tooltip = ASK_TIP
  y = y + 36
  local lastBucket
  for _, run in ipairs(runs) do
    local bucket = date and ns.PlannedRuns.bucket(run.startsAt, now(), date) or ""
    if bucket ~= lastBucket then
      placeText(pools.listText, parent, 12, y + 8, width - 24, bucket, "faint")
      y = y + 26
      lastBucket = bucket
    end
    local r = Kit.take(pools.runRows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = "run:" .. run.id
    r.name:SetText(ns.PlannedRuns.shortName(dungeonName(run)))
    r.right:SetText(date and ns.PlannedRuns.rowTime(run.startsAt, now(), date) or "")
    local pipSlots = ns.PlannedRuns.slots(run, candidates, dungeonOf(run))
    for k, p in ipairs(r.pips) do
      local slot = pipSlots[k]
      if slot and slot.answer then
        p:SetColorTexture(Theme.color(slot.role or "dps"))
      else
        p:SetColorTexture(Theme.color("track"))
      end
    end
    r.meta:SetText(run.pending and colored(PENDING, "faint") or countsText(run))
    local organiser = organiserText(run, candidates, me)
    r.who:SetText(organiser)
    r.who:SetTextColor(Theme.color(organiser == "you organise" and "goldLight" or "muted"))
    r:SetSelected(r.value == selected)
    rows[#rows + 1] = { value = r.value, frame = r }
    y = y + RUN_ROW
  end
  if #runs == 0 then
    placeText(pools.listText, parent, 12, y + 2, width - 24, "No runs planned", "text")
    placeText(pools.listText, parent, 12, y + 18, width - 24, "Plan one on the website, or ask who is up for "
      .. "something right now.", "muted")
    y = y + 40
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
  -- CF-62: how old the runs are, one muted line at the bottom of the list.
  local data = ns.Planner.data()
  if data and date then
    local at = when(data.updatedAt):gsub("^Today ", "")
    placeText(pools.listText, parent, 12, y + 10, width - 24, string.format("Runs from the website, %s. Type /reload "
      .. "after an upload for newer.", at), "faint")
    y = y + 40
  end
  y = y + 12
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
  b.tooltip = ASK_TIP -- CF-61: was a note next to the button
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
  for _, name in ipairs({ "name", "section", "small", "tiny", "slots", "quests", "buttons", "primary", "groupRows",
                          "onlineRows", "infos", "links" }) do
    Kit.release(pools[name])
  end
  linkBox:Hide()
end

-- CF-62: who is online in the community and fits the run's range, not in its group (MemberTracker, re-drawn on
-- CLUB_MEMBER_PRESENCE_UPDATED and CLUB_MEMBER_UPDATED through MemberTracker.UPDATED).
local function onlineFits(dungeon, excluded, candidates)
  local friendOf = {}
  for _, c in ipairs(candidates) do
    if c.guid then friendOf[c.guid] = c.own and "you" or c.displayName end
  end
  local out = {}
  if not dungeon then return out end
  local myGuid = ns.SelfInfo.read().guid
  for guid, m in pairs(ns.MemberTracker.members()) do
    local online = m.presence and m.presence ~= 0 and m.presence ~= 3 -- Offline (0) and Away-offline (3) aside
    if online and guid ~= myGuid and not excluded[guid] and type(m.level) == "number"
        and m.level >= dungeon.min and m.level <= dungeon.max then
      local info = ns.Classes and ns.Classes.info and ns.Classes.info(nil, m.classID)
      out[#out + 1] = { guid = guid, name = m.name, level = m.level, zone = m.zone, friend = friendOf[guid],
                        classFile = info and info.file }
    end
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return out
end

local function whisper(name)
  if ChatFrame_SendTell then
    pcall(ChatFrame_SendTell, name)
  elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
    pcall(ChatFrameUtil.OpenChat, "/w " .. name .. " ")
  end
end

-- One run (CF-46; CF-62 board AG02Dungeons A to C).
local function renderRun(run, me, candidates)
  local parent = detail.child
  local width = math.max(560, (detail:GetWidth() or 0) - 6) - 2 * PAD
  local leftWidth = width - ONLINE_WIDTH - 24
  local rightX = PAD + leftWidth + 24
  local y = PAD - 4
  local dungeon = dungeonOf(run)
  local open = ns.PlannedRuns.inviteOpen(run, now())
  -- Title: the dungeon (never the typed note), then its range.
  local title = placeText(pools.name, parent, PAD, y, width, dungeonName(run), "heading")
  local tw = title.text.GetStringWidth and title.text:GetStringWidth() or 200
  if dungeon then placeText(pools.small, parent, PAD + tw + 12, y + 10, 160, "level " .. range(dungeon), "muted") end
  y = y + 34
  local sub = {}
  local lead
  if open then
    lead = colored("Starting now" .. DOT .. clock(run.startsAt), "warning")
  else
    lead = when(run.startsAt) .. DOT .. ns.PlannedRuns.untilText(run.startsAt, now())
  end
  if SOURCE_WORDS[run.source] then sub[#sub + 1] = SOURCE_WORDS[run.source] end
  if run.state == "full" then sub[#sub + 1] = "full" end
  if run.note then sub[#sub + 1] = "note: \226\128\156" .. run.note .. "\226\128\157" end
  placeText(pools.small, parent, PAD, y, width, lead .. (#sub > 0 and (DOT .. table.concat(sub, DOT)) or ""),
    "textDim")
  y = y + 26
  local mineNow = ns.PlannedRuns.yourAnswer(run, me)
  if run.pending or (mineNow and mineNow.pending) then
    placeText(pools.tiny, parent, PAD, y, leftWidth, PENDING, "faint")
    y = y + 18
  end

  -- Group: five full-width rows.
  local slotList = ns.PlannedRuns.slots(run, candidates, dungeon)
  local openCount, inGroup = 0, {}
  for _, slot in ipairs(slotList) do
    if not slot.answer then openCount = openCount + 1 end
    if slot.answer and slot.answer.guid then inGroup[slot.answer.guid] = true end
  end
  for _, a in ipairs(run.answers or {}) do
    if a.guid then inGroup[a.guid] = true end
  end
  local fits = onlineFits(dungeon, inGroup, candidates)
  local yes, maybe = ns.PlannedRuns.counts(run)
  local counts = yes .. " in" .. (maybe > 0 and (DOT .. maybe .. " maybe") or "") ..
    (openCount > 0 and (DOT .. openCount .. " open") or "")
  local top = y
  y = section(parent, PAD, y, leftWidth, "Group", counts)
  local organiser = run.organiser
  local ctx = open and ns.RunAlerts.context() or nil
  local states = {}
  if ctx then
    for _, st in ipairs(ns.RunStart.states(run, ns.Planner.me(), ctx)) do
      states[st.answer] = st
    end
  end
  local fitNames = {}
  for i, f in ipairs(fits) do
    if i > 8 then break end
    fitNames[#fitNames + 1] = f.name .. " " .. f.level
  end
  for _, slot in ipairs(slotList) do
    local g = Kit.take(pools.groupRows, parent)
    g:SetPoint("TOPLEFT", PAD, -y)
    g:SetWidth(leftWidth)
    g.tip = nil
    local a, c = slot.answer, slot.char
    if a then
      g.bg:SetColorTexture(Theme.color("white", 0.03))
      g.role:SetRole(a.role or (c and c.role) or slot.role)
      g.portrait:Show()
      g.portrait:SetClass(c and c.classFile or nil)
      g.portrait:SetOnline(c and c.online)
      local name = (c and c.name) or a.name or tagName(a.battleTag) or "?"
      g.name:SetText(c and classColored(c, name) or name)
      local level = c and c.level
      g.info:SetText((level and (level .. DOT) or "") .. tostring(personName(a, candidates, me) or ""))
      local state, color
      local st = states[a]
      if organiser and ((a.guid and a.guid == organiser.guid) or (a.battleTag and a.battleTag == organiser.battleTag))
      then
        state, color = "organiser", "onlineText"
      elseif open and st and (st.state == "ready" or st.state == "other" or st.state == "grouped") then
        local zone = st.presence and st.presence.zone
        state, color = (slot.maybe and "maybe" .. DOT or "") .. "online" .. (zone and (DOT .. zone) or ""),
          slot.maybe and "warning" or "onlineText"
      elseif open and st and st.state == "offline" then
        state, color = (slot.maybe and "maybe" .. DOT or "") .. "offline", slot.maybe and "warning" or "muted"
      elseif slot.maybe then
        state, color = "maybe", "warning"
      elseif a.source == "discord" then
        state, color = "answered on Discord", "swap"
      end
      -- CF-49: how the level fits when it isn't "fits": a carry in the warning colour, others muted.
      local fit = not state and ns.PlannedRuns.fitOf(a, c, dungeon)
      if fit and fit.label ~= "fits" then state, color = fit.label, fit.kind == "carry" and "warning" or "muted" end
      g.status:SetText(state or "")
      g.status:SetTextColor(Theme.color(color or "muted"))
    else
      g.bg:SetColorTexture(Theme.color("white", 0))
      g.role:SetRole(slot.role, true)
      g.portrait:Hide()
      g.name:SetText(colored(ROLE_LABEL[slot.role] .. DOT .. (slot.missing and "nobody in range" or "open"),
        slot.missing and "warning" or "faint"))
      g.info:SetText("")
      if #fits > 0 and not slot.missing then
        g.status:SetText(#fits .. " online fit")
        g.status:SetTextColor(Theme.color("swap"))
        g.tip = table.concat(fitNames, "\n")
      else
        g.status:SetText("")
      end
    end
    y = y + GROUP_ROW + 4
  end
  local reserves = {}
  for _, a in ipairs(ns.PlannedRuns.reserves(run)) do
    local who = a.name or tagName(a.battleTag) or "?"
    local parts = {}
    if a.role then parts[#parts + 1] = ROLE_LABEL[a.role] end
    local friend = personName(a, candidates, me)
    if friend and friend ~= who then parts[#parts + 1] = friend end
    reserves[#reserves + 1] = who .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "")
  end
  if #reserves > 0 then
    placeText(pools.small, parent, PAD, y + 2, leftWidth, "Reserve: " .. table.concat(reserves, ", "), "muted")
    y = y + 22
  end

  -- The action area, below a divider.
  y = y + 10
  local isOrganiser = ns.PlannedRuns.isOrganiser(run, me)
  local data = ns.Planner.data()
  if isOrganiser then
    y = section(parent, PAD, y, leftWidth, open and "Start" or ("At " .. clock(run.startsAt)))
    local ready = {}
    if ctx then ready = ns.RunStart.readyToInvite(ns.RunStart.states(run, ns.Planner.me(), ctx)) end
    local b = Kit.take(pools.primary, parent)
    b:SetLabel(open and ("Invite all" .. DOT .. #ready .. " online")
      or ("Invite all" .. DOT .. "opens " .. clock(run.startsAt - ns.PlannedRuns.INVITE_LEAD)))
    b:SetEnabled(open and #ready > 0)
    b:SetHeight(32)
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b.tooltip = INVITE_TIP -- also while disabled
    b:SetScript("OnClick", function() ns.RunAlerts.inviteReady(run) end)
    b:SetPoint("TOPLEFT", PAD, -y)
    local bx = PAD + (b:GetWidth() or 180) + 10
    if open and ctx then
      for _, st in ipairs(ns.RunStart.states(run, ns.Planner.me(), ctx)) do
        if st.state == "other" then
          local w = Kit.take(pools.buttons, parent)
          w:SetLabel("Whisper " .. tostring(personName(st.answer, candidates, me)))
          w:SetEnabled(true)
          w:SetScript("OnClick", function() ns.RunAlerts.whisperSwitch(run, st) end)
          w:SetPoint("TOPLEFT", bx, -(y + 3))
          break
        end
      end
    end
    y = y + 40
    if not open and data and data.reminderMinutes and date then
      placeText(pools.small, parent, PAD, y, leftWidth,
        "Reminder at " .. clock(run.startsAt - data.reminderMinutes * 60), "textDim")
      y = y + 20
    elseif open and ctx then
      local offline = {}
      for _, st in ipairs(ns.RunStart.missing(ns.RunStart.states(run, ns.Planner.me(), ctx))) do
        local who = st.answer.name or personName(st.answer, candidates, me) or "?"
        offline[#offline + 1] = who .. (st.answer.answer == "maybe" and " (maybe)" or "")
      end
      if #offline > 0 then
        placeText(pools.small, parent, PAD, y, leftWidth, table.concat(offline, ", ") ..
          (#offline == 1 and " is offline." or " are offline."), "textDim")
        y = y + 20
      end
    end
  elseif not run.pending then
    -- Your answer: three toggles, then the character and role you go as ("change" opens the answer dialog).
    local heading = placeText(pools.section, parent, PAD, y, leftWidth, "Your answer", "goldLight")
    local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 90
    local info = Kit.take(pools.infos, parent)
    info:SetPoint("TOPLEFT", PAD + hw + 8, -(y + 3))
    info.tip = ANSWER_TIP
    y = y + 26
    local x = PAD
    local current = mineNow and mineNow.answer
    local me0 = ns.SelfInfo.read()
    local char = { guid = me0.guid, name = me0.name, level = me0.level, classFile = me0.classFile,
                   role = (mineNow and mineNow.role) or ns.SelfInfo.role and ns.SelfInfo.role() or "dps" }
    for _, def in ipairs({ { "in", "I'm in" }, { "maybe", "Maybe" }, { "cant", "Can't" } }) do
      local b = Kit.take(def[1] == current and pools.primary or pools.buttons, parent)
      b:SetLabel(def[2])
      b:SetEnabled(true)
      b:SetScript("OnClick", function()
        ns.Planner.answer(run, def[1], def[1] ~= "cant" and char or nil)
        helpers.render()
      end)
      b:SetPoint("TOPLEFT", x, -y)
      x = x + (b:GetWidth() or 80) + 8
    end
    y = y + 36
    local asWho = mineNow and mineNow.name or char.name
    placeText(pools.small, parent, PAD, y, leftWidth, "As " .. tostring(asWho) .. DOT ..
      (ROLE_LABEL[(mineNow and mineNow.role) or char.role] or "Damage") .. DOT, "textDim")
    local change = Kit.take(pools.links, parent)
    change:SetPoint("TOPLEFT", PAD + 220, -(y - 2))
    change.text:SetText("change")
    change:SetScript("OnClick", function() ns.RunDialogs.answer(run) end)
    y = y + 22
  end

  -- Right column: Online now, fits, then Edit or cancel.
  local ry = top
  if dungeon then
    local heading = placeText(pools.section, parent, rightX, ry, ONLINE_WIDTH,
      "Online now, fits " .. range(dungeon), "goldLight")
    local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 180
    local info = Kit.take(pools.infos, parent)
    info:SetPoint("TOPLEFT", rightX + hw + 8, -(ry + 3))
    info.tip = ROSTER_TIP
    placeText(pools.small, parent, rightX, ry + 2, ONLINE_WIDTH, tostring(#fits), "faint", "RIGHT")
    ry = ry + 28
    if #fits == 0 then
      placeText(pools.small, parent, rightX, ry, ONLINE_WIDTH, "Nobody online fits right now.", "muted")
      ry = ry + 22
    end
    local combat = InCombatLockdown and InCombatLockdown()
    for _, f in ipairs(fits) do
      local o = Kit.take(pools.onlineRows, parent)
      o:SetPoint("TOPLEFT", rightX, -ry)
      o:SetWidth(ONLINE_WIDTH)
      o.portrait:SetClass(f.classFile)
      o.portrait:SetOnline(true)
      o.name:SetText(f.classFile and classColored(f, f.name) or tostring(f.name))
      o.level:SetText(tostring(f.level))
      o.info:SetText(table.concat({ f.friend or "community", f.zone }, DOT))
      if open then
        o.button:SetLabel("Invite")
        o.button:SetEnabled(not combat)
        o.button.tooltip = combat and "Not in combat" or nil
        o.button:SetScript("OnClick", function()
          if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(f.name) end
        end)
      else
        o.button:SetLabel("Whisper")
        o.button:SetEnabled(true)
        o.button.tooltip = nil
        o.button:SetScript("OnClick", function() whisper(f.name) end)
      end
      ry = ry + ONLINE_ROW
    end
    ry = ry + 12
  end
  ry = section(parent, rightX, ry, ONLINE_WIDTH, isOrganiser and "Edit or cancel" or "On the website")
  if run.url then
    linkBox:ClearAllPoints()
    linkBox:SetParent(parent)
    linkBox:SetPoint("TOPLEFT", rightX, -ry)
    linkBox:SetWidth(228)
    linkBox:SetText(run.url)
    linkBox:Show()
    ry = ry + 34
    placeText(pools.tiny, parent, rightX, ry, ONLINE_WIDTH, "Click, then Ctrl+C to copy.", "faint")
    ry = ry + 20
  end
  parent:SetHeight(math.max(y, ry) + PAD)
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
  column:SetWidth(LIST_WIDTH) -- CF-62
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
    -- CF-62
    runRows = Kit.pool(runRow), listTitle = Kit.pool(Kit.textHolder("section")), listButtons = Kit.pool(button),
    groupRows = Kit.pool(groupRow), onlineRows = Kit.pool(onlineRow), infos = Kit.pool(Kit.info),
    links = Kit.pool(function(p)
      local b = CreateFrame("Button", nil, p)
      b:SetSize(60, 18)
      b.text = Theme.text(b, "small", "goldLight")
      b.text:SetPoint("LEFT")
      return b
    end),
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
    renderDetail(nil, me, ns.Dungeons.emptyText(me.name, me.level, ns.CommunitySelection.active() ~= nil), runs,
      candidates)
    return
  end
  local entry = entries[st.selected]
  if entry.run then
    renderRun(entry.run, me, candidates)
  else
    renderDetail(entry, me, nil, runs, candidates)
  end
end

-- CF-62: "Ask now…" on the list: the selected run's dungeon, else the selected or first dungeon in range.
function DungeonsTab.askNow()
  local selected = entries[status().selected]
  local dungeon = selected and (selected.run and dungeonOf(selected.run) or selected.dungeon)
  if not dungeon then
    for _, e in pairs(entries) do
      if e.dungeon and e.fits then dungeon = e.dungeon break end
    end
  end
  if dungeon then ns.RunDialogs.askNow(dungeon) end
end

function DungeonsTab.reset()
  root, entries, rows = nil, {}, {}
end

-- For the specs: the list rows, the card's texts (in pool order), its buttons by label, the link box.
function DungeonsTab.rows() return rows end
function DungeonsTab.linkBox() return linkBox end

function DungeonsTab.texts()
  local out = {}
  for _, name in ipairs({ "listTitle", "listText", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "rows", "runRows", "slots", "groupRows", "onlineRows", "quests" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "name", "right", "meta", "info", "status", "mark", "who", "level" }) do
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
  for _, name in ipairs({ "buttons", "primary", "listButtons" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  for i = 1, pools and pools.links.used or 0 do out[pools.links.items[i].text:GetText()] = pools.links.items[i] end
  for i = 1, pools and pools.onlineRows.used or 0 do
    local b = pools.onlineRows.items[i].button
    out[b.label:GetText() .. ":" .. i] = b
  end
  return out
end

function DungeonsTab.questRows()
  local out = {}
  for i = 1, pools and pools.quests.used or 0 do out[i] = pools.quests.items[i] end
  return out
end

function DungeonsTab.groupRows()
  local out = {}
  for i = 1, pools and pools.groupRows.used or 0 do out[i] = pools.groupRows.items[i] end
  return out
end

function DungeonsTab.tips()
  local out = {}
  for i = 1, pools and pools.infos.used or 0 do out[#out + 1] = pools.infos.items[i].tip end
  for _, name in ipairs({ "primary", "groupRows" }) do
    for i = 1, pools and pools[name].used or 0 do
      local t = pools[name].items[i].tooltip or pools[name].items[i].tip
      if t then out[#out + 1] = t end
    end
  end
  return out
end

function DungeonsTab.slots()
  local out = {}
  for i = 1, pools and pools.slots.used or 0 do out[i] = pools.slots.items[i] end
  return out
end

ns.DungeonsTab = DungeonsTab
return DungeonsTab
