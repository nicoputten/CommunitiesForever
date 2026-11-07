-- RunsTab: the Runs tab (CF-106, board DL01 and DL03 D/E; design docs/design/dungeons-2026-11/). Runs moved here
-- from the Dungeons tab: the planned runs (from the website through the uploader, or a friend's addon) grouped
-- Today, Tomorrow and Later with your status on each row; a run's detail with its group, its bosses once it has
-- started (the kill log, KillLog), your answer (CF-63) or the organiser's start, Online now, fits and the link to
-- the website. Native frames from the kit, drawn from pools.
local _, ns = ...

local RunsTab = {}
local Theme, Kit = ns.Theme, ns.Kit

local PAD = 20
-- CF-47: waiting for the next save and upload (CF-63: the tooltip of a clock icon)
local PENDING = "Saved. Reaches the website with your next upload." -- CF-63 board CF63Answer
local SOURCE_WORDS = { site = "planned on the website", discord = "planned on Discord", game = "planned in game" }
local DOT = " \194\183 "
local LIST_WIDTH = 290
local RUN_ROW = 50
local GROUP_ROW = 36
local ONLINE_ROW = 30
local BOSS_ROW = 24
local ROLE_LABEL = { tank = "Tank", heal = "Healer", dps = "Damage" }
local ROSTER_TIP = "Online members whose current character fits %s." -- CF-63 board CF63RunDetail
local RUNS_TIP = "Runs from the website. Type /reload after an upload for newer."
local LINK_TIP = "Copy with Ctrl+C. Edit or cancel happens on the website."
local INVITE_TIP = "Invite all invites everyone who is in and online."
local ASK_TIP = "Whispers online friends who fit; can post on Discord too. Waits until combat ends." -- CF-61
-- CF-106 (board DL01): the status on the right of a run row.
local STATUS = {
  ["in"] = { "you\226\128\153re in", "online" }, maybe = { "maybe", "warning" },
  cant = { "can\226\128\153t", "keySep" },
  answer = { "answer", "goldLight" }, nofit = { "no fit", "keySep" }, noBoss = { "no boss yet", "keySep" },
  organiser = { "you organise", "goldLight" },
}
local root, list, detail
local helpers -- from MainFrame: settings(), render(), print(text)
local entries = {} -- row value "run:<id>" -> { run = run }
local rows = {}    -- visible list rows: { value, frame }
local pools
local linkBox -- the run's website link to copy
local ticking -- CF-63: the minute ticker runs
local askForRun, memberMenu, openSlotMenu -- CF-63b, defined with renderRun

-- ===== Helpers =====

local function status()
  local s = helpers.settings()
  s.runsTab = s.runsTab or {} -- CF-106: the selected run (a new key; nil in older data)
  return s.runsTab
end

local function now() return GetServerTime() end

local function colored(text, colorName) return Theme.code(colorName) .. tostring(text) .. "|r" end

local function classColored(c, text)
  return Theme.rgbCode(Kit.classColor(c.classFile)) .. tostring(text or c.name) .. "|r"
end

-- "17–24" with the bundled font; the game font has no en dash.
local function range(dungeon)
  return string.format("%d%s%d", dungeon.min, Theme.bundledFonts() and "\226\128\147" or "-", dungeon.max)
end

-- Local times need the game's date (V63, verified on Forever); without it, nothing is shown rather than a wrong time.
local function when(at)
  if not date then return "" end
  return ns.PlannedRuns.whenText(at, now(), date)
end

local function clock(at)
  if not date then return "" end
  return ns.PlannedRuns.clock(at, date)
end

local function dungeonOf(run) return ns.Dungeons.get(run.dungeon) end

local function dungeonName(run) return ns.Dungeons.runName(run) end -- CF-63: never the raw id

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



-- ===== Factories =====

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
  r:SetScript("OnEnter", function(self) -- CF-63: the full name when the row shows a short one
    if not (self.fullName and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.fullName, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(self) if self.fullName and GameTooltip then GameTooltip:Hide() end end)
  r.dot = Theme.fill(r, "gold", "ARTWORK") -- CF-106: before "answer"
  r.dot:SetSize(7, 7)
  r.dot:SetPoint("RIGHT", r.who, "LEFT", -5, 0)
  r.dot:Hide()
  r.clock = Kit.clock(r) -- CF-63: waits for the next upload
  r.clock:SetPoint("LEFT", r.meta, "RIGHT", 6, 0)
  r.clock.tip = PENDING
  r.clock:Hide()
  r:SetScript("OnClick", function(self) RunsTab.select(self.value) end)
  return r
end

-- CF-62: a run's group row (CF-63 board CF63RunDetail: 36 px): role icon, class icon, the full name,
-- "level · friend", then "online" and the status, right-aligned in a 64 px column.
local STATUS_WIDTH = 64
local function groupRow(parent)
  local g = CreateFrame("Frame", nil, parent)
  g:SetHeight(GROUP_ROW)
  g.bg = Theme.fill(g, "white", "BACKGROUND")
  g.bg:SetAllPoints()
  g.edges = Kit.edges(g, "divider")
  g.role = Kit.roleIcon(g, 20)
  g.role:SetPoint("LEFT", 10, 0)
  g.portrait = Kit.portrait(g, 22)
  g.portrait:SetPoint("LEFT", 36, 0)
  g.name = Theme.text(g, "body", "text")
  g.name:SetPoint("LEFT", 66, 0)
  g.info = Theme.text(g, "small", "muted")
  g.info:SetPoint("LEFT", g.name, "RIGHT", 8, 0)
  g.status = Theme.text(g, "small", "muted")
  g.status:SetPoint("RIGHT", -10, 0)
  g.status:SetJustifyH("RIGHT")
  g.online = Theme.text(g, "small", "online")
  g.online:SetPoint("RIGHT", g.status, "LEFT", -8, 0)
  for _, fs in ipairs({ g.name, g.info, g.status, g.online }) do
    if fs.SetWordWrap then fs:SetWordWrap(false) end -- CF-63: cut with "...", never a second line
  end
  g:EnableMouse(true)
  -- CF-63b: the hover tooltip, its first line the name (tipLines), or one text (tip).
  g:SetScript("OnEnter", function(self)
    if not GameTooltip or not (self.tip or self.tipLines) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.tipLines then
      GameTooltip:SetText(self.tipLines[1], nil, nil, nil, nil, true)
      for i = 2, #self.tipLines do GameTooltip:AddLine(self.tipLines[i], Theme.color("textDim")) end
    else
      GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
    end
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self) if (self.tip or self.tipLines) and GameTooltip then GameTooltip:Hide() end end)
  g:SetScript("OnMouseUp", function(self, mouse)
    if self.menu and (mouse == "RightButton" or self.menuOnClick) then self.menu(self) end
  end)
  return g
end

-- CF-63: your own row has gold edges and a gold tint (board CF63RunDetail); the others the divider.
local function rowEdges(g, mine)
  for _, t in ipairs(g.edges) do
    t:SetColorTexture(Theme.color(mine and "gold" or "divider", mine and 0.7 or nil))
  end
end

-- CF-63: a group row's texts never run into each other: the status column is at least 64 px, "online" sits left of
-- it, the name gets what is left after a short info; what doesn't fit is cut ("...").
local function natural(fs)
  local t = fs:GetText()
  if not t or t == "" then return 0 end
  return math.ceil(fs:GetStringWidth() or 0) + 1
end

local function fitGroupRow(g, width)
  for _, fs in ipairs({ g.name, g.info, g.status, g.online }) do fs:SetWidth(0) end
  local statusW = math.max(STATUS_WIDTH, math.min(natural(g.status), math.floor(width * 0.4)))
  g.status:SetWidth(statusW)
  local onlineW = natural(g.online)
  local room = width - 66 - 10 - statusW - 12 - (onlineW > 0 and (onlineW + 8) or 0)
  local infoW = natural(g.info)
  local nameW = math.min(natural(g.name), math.max(80, room - math.min(infoW, 120) - 8))
  nameW = math.max(1, math.min(nameW, room - 9)) -- CF-95: the info's gap and 1 px stay in the row when narrow
  g.name:SetWidth(nameW)
  g.info:SetWidth(math.max(1, math.min(infoW, room - nameW - 8)))
end

-- CF-62: a row of "Online now, fits" (CF-63 board CF63RunDetail: one 30 px line): class icon, name, "level ·
-- friend", Whisper, and Invite from 15 minutes before the start.
local function onlineRow(parent)
  local o = CreateFrame("Frame", nil, parent)
  o:SetHeight(ONLINE_ROW)
  o.line = Theme.fill(o, "divider", "BORDER")
  o.line:SetPoint("BOTTOMLEFT")
  o.line:SetPoint("BOTTOMRIGHT")
  o.line:SetHeight(1)
  o.portrait = Kit.portrait(o, 18)
  o.portrait:SetPoint("LEFT", 0, 0)
  o.name = Theme.text(o, "body", "text")
  o.name:SetPoint("LEFT", 26, 0)
  o.info = Theme.text(o, "small", "muted")
  o.info:SetPoint("LEFT", o.name, "RIGHT", 8, 0)
  o.invite = Kit.button(o, "Invite", nil)
  o.invite:SetPoint("RIGHT", 0, 0)
  if o.invite.SetMotionScriptsWhileDisabled then o.invite:SetMotionScriptsWhileDisabled(true) end
  o.button = Kit.button(o, "", nil)
  o.button:SetPoint("RIGHT", 0, 0)
  if o.button.SetMotionScriptsWhileDisabled then o.button:SetMotionScriptsWhileDisabled(true) end
  for _, fs in ipairs({ o.name, o.info }) do
    if fs.SetWordWrap then fs:SetWordWrap(false) end -- CF-94: cut with "...", never a second line
  end
  return o
end

-- CF-94: the name and "level · friend" of an online row end 8 px before Whisper (and Invite when shown); the name
-- gets what is left after a short info, what doesn't fit is cut ("...").
local function fitOnlineRow(o, width, inviteShown)
  o.name:SetWidth(0)
  o.info:SetWidth(0)
  local buttons = (o.button:GetWidth() or 60) + (inviteShown and ((o.invite:GetWidth() or 60) + 6) or 0)
  local room = width - 26 - buttons - 8
  local infoW = natural(o.info)
  local nameW = math.min(natural(o.name), math.max(60, room - math.min(infoW, 120) - 8))
  nameW = math.max(1, math.min(nameW, room - 9)) -- CF-95: the info's gap and 1 px stay in the row
  o.name:SetWidth(nameW)
  o.info:SetWidth(math.max(1, math.min(infoW, room - nameW - 8)))
end


-- CF-106 (board DL01 A): a boss in the run's Bosses: a check box (green when killed) and the name; tip on hover.
local function bossRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(BOSS_ROW)
  r.box = CreateFrame("Frame", nil, r)
  r.box:SetSize(14, 14)
  r.box:SetPoint("LEFT", 0, 0)
  r.boxFill = r.box:CreateTexture(nil, "BACKGROUND")
  r.boxFill:SetAllPoints()
  r.box.edges = Kit.edges(r.box, "giLine")
  r.check = r.box:CreateTexture(nil, "ARTWORK")
  r.check:SetPoint("TOPLEFT", 1, -1)
  r.check:SetPoint("BOTTOMRIGHT", -1, 1)
  r.check:SetTexture(Theme.TEXTURES.check)
  r.check:SetVertexColor(Theme.color("white"))
  r.name = Theme.text(r, "body", "muted")
  r.name:SetPoint("LEFT", 20, 0)
  r.name:SetJustifyH("LEFT")
  if r.name.SetWordWrap then r.name:SetWordWrap(false) end
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(self) if self.tip and GameTooltip then GameTooltip:Hide() end end)
  return r
end

local function button(parent) return Kit.button(parent, "", nil) end
local function primary(parent) return Kit.button(parent, "", nil, "primary") end

-- ===== Drawing =====

-- A text that wraps (pooled texts are reused, so each placement says how it breaks).
local function placeText(pool, parent, x, y, width, text, color, justify)
  local holder = Kit.placeText(pool, parent, x, y, width, text, color, justify)
  if holder.text.SetWordWrap then holder.text:SetWordWrap(true) end
  return holder
end

-- CF-95: one line, cut with "..." where it doesn't fit (the same rule as fitGroupRow and fitOnlineRow).
local function line(pool, parent, x, y, width, text, color, justify)
  local holder = Kit.placeText(pool, parent, x, y, math.max(1, width), text, color, justify)
  if holder.text.SetWordWrap then holder.text:SetWordWrap(false) end
  return holder
end

-- A section title and a note after it, both on one line within width (Kit.section in single lines, CF-95).
local function section(parent, x, y, width, text, note, noteColor)
  local h = line(pools.section, parent, x, y, width, text, "goldLight")
  if note then
    local w = math.min(width, h.text.GetStringWidth and h.text:GetStringWidth() or 100)
    line(pools.small, parent, x + w + 10, y + 3, width - w - 10, note, noteColor or "muted")
  end
  return y + Kit.SECTION_HEIGHT
end

-- CF-95: the width a run or a dungeon is laid out at: what the detail shows (near the window's 700 px minimum
-- about 408 px), never below 300; 520 until the detail has a size. It was at least 520, so at the minimum the
-- right side (the status column, Ask now for this run, the answer buttons) was cut off.
local MIN_WIDTH = 300
local function detailWidth()
  local shown = detail and detail:GetWidth()
  if shown and shown > 0 then return math.max(MIN_WIDTH, shown - 6 - 2 * PAD) end
  return 560 - 2 * PAD
end


-- CF-65: a redraw takes the pooled frames again without hiding them first (Kit.recycle), and hides only what it
-- didn't use afterwards (sweep). Hiding and showing a button between mouse down and up drops the click.
local answerDrawn, linkPlaced
local function clearDetail()
  for _, name in ipairs({ "name", "section", "small", "tiny", "buttons", "primary", "groupRows", "onlineRows",
                          "infos", "clocks", "dividers", "bosses" }) do
    Kit.recycle(pools[name])
  end
  answerDrawn, linkPlaced = false, false
end

local function sweep()
  for _, p in pairs(pools) do Kit.sweep(p) end
  if not linkPlaced then linkBox:Hide() end
  if not answerDrawn and ns.RunAnswer then ns.RunAnswer.hide() end
end

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
      -- CF-64: Classes.info returns the class file itself (it was read as a table, so no icon showed).
      local file = ns.Classes.info(nil, m.classID)
      out[#out + 1] = { guid = guid, name = m.name, level = m.level, zone = m.zone, friend = friendOf[guid],
                        classFile = file }
    end
  end
  table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
  return out
end

-- CF-64: a character's class file for its icon: the candidate's, else its synced record's, else the community
-- roster's classID; nil when unknown (then no icon, not an empty ring).
local function classFor(guid, c)
  local file = c and (c.classFile or (c.classID and (ns.Classes.info(nil, c.classID))))
  if file or not guid then return file end
  local global = ns.db and ns.db.global
  local own = global and global.self and global.self.chars and global.self.chars[guid]
  if own and (own.classFile or own.classID) then return own.classFile or (ns.Classes.info(nil, own.classID)) end
  for _, person in pairs(global and global.people or {}) do
    local rec = type(person) == "table" and type(person.chars) == "table" and person.chars[guid]
    if type(rec) == "table" and (rec.classFile or rec.classID) then
      return rec.classFile or (ns.Classes.info(nil, rec.classID))
    end
  end
  local m = ns.MemberTracker.members()[guid]
  return m and m.classID and (ns.Classes.info(nil, m.classID)) or nil
end

-- Shows the class icon, or hides it when the class is unknown.
local function setPortrait(portrait, file, online)
  if file then
    portrait:Show()
    portrait:SetClass(file)
    portrait:SetOnline(online)
  else
    portrait:Hide()
  end
end

local function whisper(name)
  if ChatFrame_SendTell then
    pcall(ChatFrame_SendTell, name)
  elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
    pcall(ChatFrameUtil.OpenChat, "/w " .. name .. " ")
  end
end

-- CF-63: fills "Online now, fits" at x, y (width): its heading with an ⓘ, then a row per member, Whisper, and
-- Invite from 15 minutes before the start (open). Returns the new y.
local function onlineList(parent, x, y, width, fits, dungeon, open)
  local heading = line(pools.section, parent, x, y, width, "Online now, fits", "goldLight")
  local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 120
  local info = Kit.take(pools.infos, parent)
  info:SetPoint("TOPLEFT", x + hw + 6, -(y + 3))
  info.tip = dungeon and string.format(ROSTER_TIP, range(dungeon)) or nil
  y = y + 26
  if #fits == 0 then
    line(pools.small, parent, x, y + 4, width, "Nobody else online fits", "muted")
    return y + 26
  end
  local combat = InCombatLockdown and InCombatLockdown()
  for _, f in ipairs(fits) do
    local o = Kit.take(pools.onlineRows, parent)
    o:SetPoint("TOPLEFT", x, -y)
    o:SetWidth(width)
    o.portrait:SetClass(f.classFile)
    o.portrait:SetOnline(true)
    o.name:SetText(f.classFile and classColored(f, f.name) or tostring(f.name))
    o.info:SetText(f.level .. DOT .. tostring(f.friend or "community"))
    o.button:SetLabel("Whisper")
    o.button:SetEnabled(true)
    o.button.tooltip = nil
    o.button:SetScript("OnClick", function() whisper(f.name) end)
    o.button:ClearAllPoints()
    if open then
      o.invite:Show()
      o.invite:SetEnabled(not combat)
      o.invite.tooltip = combat and "Not in combat" or nil
      o.invite:SetScript("OnClick", function()
        if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(f.name) end
      end)
      o.button:SetPoint("RIGHT", o.invite, "LEFT", -6, 0)
    else
      o.invite:Hide()
      o.button:SetPoint("RIGHT", 0, 0)
    end
    fitOnlineRow(o, width, open)
    y = y + ONLINE_ROW
  end
  return y + 4
end

-- CF-63b: "Invite" from 15 minutes before the start, "Invite · from 20:15" before.
local function inviteLabel(run, open)
  if open then return "Invite" end
  return "Invite" .. DOT .. "from " .. clock(run.startsAt - ns.PlannedRuns.INVITE_LEAD)
end

-- CF-63b (board CF63Group E): Ask now for this run: the Ask dialog with "For SM: Graveyard 20:30 · need a healer".
askForRun = function(run, role)
  ns.RunDialogs.ask({ run = run, role = role })
end

-- CF-63b (board CF63Group D): a member's right-click menu: Whisper, Invite, Show in Friends.
memberMenu = function(owner, run, a, c, who, open)
  local combat = InCombatLockdown and InCombatLockdown()
  local path
  if c and c.key and c.guid then
    local group = c.key == "self" and ns.Format.SELF or c.key:find("^member:") and ns.Format.UNLINKED or c.key
    path = ns.Format.path(group, c.guid)
  end
  local items = {
    { label = "Whisper", enabled = who ~= nil, action = "whisper" },
    { label = inviteLabel(run, open), enabled = open and not combat and who ~= nil, action = "invite" },
    { label = "Show in Friends", enabled = path ~= nil, action = "friends" },
  }
  ns.ContextMenu.open(owner, { title = (c and c.name) or a.name or who, items = items }, function(item)
    if item.action == "whisper" then
      ns.ContextMenu.whisper(who)
    elseif item.action == "invite" then
      if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(who) end
    elseif item.action == "friends" then
      ns.MainFrame.selectTab("friends")
      ns.FriendsTab.select(path)
    end
  end)
end

-- CF-63b (board CF63Group E): an open slot's menu: Whisper <the first who fits> with the prefilled text, Ask now for
-- this run, Invite.
openSlotMenu = function(owner, run, role, fits, open)
  local first = fits[1]
  local combat = InCombatLockdown and InCombatLockdown()
  local items = {
    { label = first and ("Whisper " .. first.name) or "Whisper", enabled = first ~= nil, action = "whisper" },
    { label = "Ask now for this run", enabled = dungeonOf(run) ~= nil, action = "ask" },
    { label = inviteLabel(run, open), enabled = first ~= nil and open and not combat, action = "invite" },
  }
  ns.ContextMenu.open(owner, { title = ROLE_LABEL[role] .. DOT .. "open", items = items }, function(item)
    if item.action == "whisper" then
      local text = date and ns.PlannedRuns.whisperText(run, dungeonName(run), role, now(), date) or ""
      ns.ContextMenu.whisperText(first.name, text)
    elseif item.action == "ask" then
      askForRun(run, role)
    elseif item.action == "invite" then
      if not (InCombatLockdown and InCombatLockdown()) then ns.Party.invite(first.name) end
    end
  end)
end

-- A 1 px divider across the detail at y.
local function divider(parent, y, width)
  local d = Kit.take(pools.dividers, parent)
  d:SetPoint("TOPLEFT", PAD, -y)
  d:SetSize(width, 1)
  return y + 1
end

-- ===== CF-106: boss progress =====

-- The first daily reset after a time (the Doomsday day boundary, DoomsdayTracker's reset setting).
local function resetAfter(at)
  local s = ns.DoomsdayTracker.schedule()
  return ns.Doomsday.dayStart(ns.Doomsday.day(at, s.offset, s.reset) + 1, s.offset, s.reset)
end

-- A run's progress and its dungeon's bosses (DungeonLoot from the loot file; {} for a dungeon it doesn't have).
local function progressOf(run, kills)
  local d = dungeonOf(run)
  local bosses = d and ns.DungeonLoot.bossesFor(ns.LootData, d) or {} -- CF-106: an older "strat" has every wing's
  return ns.RunProgress.progress(run, bosses, kills, now(), resetAfter(run.startsAt)), bosses
end

-- The levels of your characters (for "no fit" and the badge).
local function ownLevels(candidates)
  local levels = {}
  for _, c in ipairs(candidates or {}) do
    if c.own then levels[#levels + 1] = c.level end
  end
  return levels
end

-- Whose kill log a kill came from, for the boss's tooltip: "Grom" (the friend), "your" for your own characters.
local function killerName(guid, candidates)
  for _, c in ipairs(candidates or {}) do
    if c.guid == guid then return c.own and "your" or ((c.displayName or c.name) .. "\226\128\153s") end
  end
  return nil
end

-- CF-106 (board DL01 A): Bosses once the run has started: "3 of 6", a check per killed boss in two columns, "optional"
-- (or "– skipped" on a cleared run) after an optional boss. Hover: "Killed 20:31 (from Grom's log)".
local function bossSection(parent, y, width, progress, bosses, kills, candidates)
  y = section(parent, PAD, y, width, "Bosses", string.format("%d of %d", progress.done, progress.total))
  local colW = math.floor((width - 18) / 2)
  -- CF-106: an older run for a whole instance ("strat", "dme") lists each wing's bosses under the wing's name.
  local wing, i = nil, 0
  for _, b in ipairs(bosses) do
    if b.wing ~= wing then
      if i > 0 then y = y + math.ceil(i / 2) * BOSS_ROW end
      wing, i = b.wing, 0
      local d = wing and ns.Dungeons.get(wing)
      if d then
        line(pools.small, parent, PAD, y + 4, width, d.title or d.name, "textDim")
        y = y + 22
      end
    end
    i = i + 1
    local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
    local r = Kit.take(pools.bosses, parent)
    r:SetPoint("TOPLEFT", PAD + col * (colW + 18), -(y + rowIndex * BOSS_ROW))
    r:SetSize(colW, BOSS_ROW)
    local at = progress.killed[b.id]
    r.check:SetShown(at ~= nil)
    r.boxFill:SetColorTexture(Theme.color(at and "killed" or "white", at and 1 or 0))
    for _, e in ipairs(r.box.edges) do e:SetColorTexture(Theme.color(at and "killed" or "giLine")) end
    local extra = ""
    if b.optional then
      local dash = Theme.bundledFonts() and "\226\128\147" or "-" -- the game font has no en dash
      extra = progress.skipped[b.id] and (" " .. dash .. " skipped") or (at and "" or " optional")
    end
    r.name:SetText(tostring(b.name) .. (extra ~= "" and Theme.code("keySep") .. extra .. "|r" or ""))
    r.name:SetTextColor(Theme.color(at and "text" or "muted"))
    r.name:SetWidth(math.max(1, colW - 22))
    r.tip = nil
    if at then
      local who
      for _, k in ipairs(kills or {}) do
        if k.encounterID == b.id and k.at == at then who = killerName(k.guid, candidates) end
      end
      r.tip = "Killed " .. clock(at) .. (who and (" (from " .. who .. " log)") or "")
    end
  end
  return y + math.ceil(i / 2) * BOSS_ROW + 6
end


-- One run (CF-46; CF-62 board AG02Dungeons A to C; CF-63 board CF63RunDetail): the header, the group at full
-- width, your answer (or the organiser's start), then Online now, fits and below it Edit or cancel /
-- On the website (CF-94).
local function renderRun(run, me, candidates, progress, bosses, kills)
  local parent = detail.child
  local width = detailWidth() -- CF-95
  local y = PAD - 6
  local dungeon = dungeonOf(run)
  local open = ns.PlannedRuns.inviteOpen(run, now())
  -- Header: the full name with Dungeon › on the right (CF-106: opens it in the Dungeons tab); "level 26–36 · <zone>";
  -- the countdown line ("started 20:04" once a boss died).
  local header = line(pools.name, parent, PAD, y, width, dungeonName(run), "heading")
  if dungeon then
    local go = Kit.take(pools.buttons, parent)
    go:SetLabel("Dungeon \226\128\186")
    go:SetEnabled(true)
    go:SetHeight(24)
    go.tooltip = nil
    go:SetScript("OnClick", function() ns.MainFrame.showDungeon(dungeon.id) end)
    go:ClearAllPoints()
    go:SetPoint("TOPRIGHT", parent, "TOPLEFT", PAD + width, -(y + 2))
    header.text:SetWidth(math.max(1, width - (go:GetWidth() or 90) - 8))
  end
  y = y + 34
  if dungeon then
    local sub = "level " .. range(dungeon)
    if ns.Dungeons.ZONES[dungeon.id] then sub = sub .. DOT .. ns.Dungeons.ZONES[dungeon.id] end
    line(pools.small, parent, PAD, y, width, sub, "muted")
    y = y + 18
  end
  local sub = {}
  local countdown = ns.PlannedRuns.countdown(run.startsAt, now())
  local lead
  if progress and progress.firstKill then
    lead = when(run.startsAt) .. DOT .. colored("started " .. clock(progress.firstKill), "online")
  elseif countdown == "Starting now" then
    lead = colored(countdown, "warning") .. DOT .. clock(run.startsAt)
  else
    lead = when(run.startsAt) .. DOT .. countdown
  end
  if SOURCE_WORDS[run.source] then sub[#sub + 1] = SOURCE_WORDS[run.source] end
  if run.state == "full" then sub[#sub + 1] = "full" end
  if run.note then sub[#sub + 1] = "note: \226\128\156" .. run.note .. "\226\128\157" end
  local leadText = line(pools.small, parent, PAD, y, width - 24,
    lead .. (#sub > 0 and (DOT .. table.concat(sub, DOT)) or ""), "textDim")
  local mineNow = ns.PlannedRuns.yourAnswer(run, me)
  if run.pending or (mineNow and mineNow.pending) then
    -- CF-63: a clock after the line, its tooltip says when it reaches the website.
    local lw = leadText.text.GetStringWidth and leadText.text:GetStringWidth() or 200
    local clockIcon = Kit.take(pools.clocks, parent)
    clockIcon:SetPoint("TOPLEFT", PAD + math.min(lw, width - 24) + 8, -(y + 1))
    clockIcon.tip = PENDING
  end
  y = y + 28

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
  -- CF-64: one "Ask now for this run" for the run (was on every open slot), at the right of the header. CF-95:
  -- below the header when "Group" and the counts don't fit beside it.
  local needed = ns.PlannedRuns.neededRole(run, candidates, dungeon)
  local ask
  if needed and dungeon then
    ask = Kit.take(pools.buttons, parent)
    ask:SetLabel("Ask now for this run")
    ask:SetEnabled(true)
    ask:SetHeight(24)
    ask:SetScript("OnClick", function() askForRun(run, needed) end)
    ask:ClearAllPoints()
  end
  local askW = ask and ((ask:GetWidth() or 140) + 8) or 0
  local groupTop = y
  local title = line(pools.section, parent, PAD, y, width, "Group", "goldLight")
  local tw = math.min(width, title.text.GetStringWidth and title.text:GetStringWidth() or 50)
  local note = line(pools.small, parent, PAD + tw + 10, y + 3, width - tw - 10, counts, "muted")
  local beside = ask and tw + 10 + natural(note.text) <= width - askW
  if beside then note.text:SetWidth(math.max(1, width - tw - 10 - askW)) end
  y = y + Kit.SECTION_HEIGHT
  if beside then
    ask:SetPoint("TOPRIGHT", parent, "TOPLEFT", PAD + width, -(groupTop - 2))
  elseif ask then
    ask:SetPoint("TOPLEFT", PAD, -y)
    y = y + 30
  end
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
    g:SetWidth(width)
    g.tip, g.tipLines, g.menu, g.menuOnClick = nil, nil, nil, nil
    g.online:SetText("")
    local a, c = slot.answer, slot.char
    local mine = a and personName(a, candidates, me) == "you"
    rowEdges(g, mine)
    if a then
      g.bg:SetColorTexture(Theme.color(mine and "gold" or "white", mine and 0.07 or 0.03))
      g.role:SetRole(a.role or (c and c.role) or slot.role)
      local file = classFor(a.guid, c)
      setPortrait(g.portrait, file, c and c.online)
      local name = (c and c.name) or a.name or tagName(a.battleTag) or "?"
      g.name:SetText(file and classColored({ classFile = file }, name) or name)
      local level = c and c.level
      g.info:SetText((level and (level .. DOT) or "") .. tostring(personName(a, candidates, me) or ""))
      local st = states[a]
      -- "online": near the start from presence, else what the community roster says of the character.
      local online
      if st then
        online = st.state == "ready" or st.state == "other" or st.state == "grouped"
      else
        online = c and c.online
      end
      if online and not mine then g.online:SetText("online") end
      local state, color
      if organiser and ((a.guid and a.guid == organiser.guid) or (a.battleTag and a.battleTag == organiser.battleTag))
      then
        state, color = "organiser", "online"
      elseif mine then
        state, color = "you", "goldLight"
      elseif slot.maybe then
        state, color = "maybe", "warning"
      elseif open and st and st.state == "offline" then
        state, color = "offline", "muted"
      elseif a.source == "discord" then
        state, color = "Discord", "swap"
      end
      -- CF-49: how the level fits when it isn't "fits": a carry in the warning colour, others muted.
      local fit = not state and ns.PlannedRuns.fitOf(a, c, dungeon)
      if fit and fit.label ~= "fits" then state, color = fit.label, fit.kind == "carry" and "warning" or "muted" end
      g.status:SetText(state or "")
      g.status:SetTextColor(Theme.color(color or "muted"))
      -- CF-63b (board CF63Group C, D): the hover tooltip and the right-click menu.
      local presence = st and st.presence or (online and c and { name = c.name }) or nil
      g.tipLines = ns.PlannedRuns.memberLines(a, c, dungeon, presence, now(), date)
      if not mine then
        local who = (presence and presence.name) or name
        g.menu = function(owner) memberMenu(owner, run, a, c, who, open) end
      end
    else
      g.bg:SetColorTexture(Theme.color("white", 0.015))
      g.role:SetRole(slot.role, true)
      g.portrait:Hide()
      g.name:SetText(colored(ROLE_LABEL[slot.role] .. DOT .. (slot.missing and "nobody fits" or "open"),
        slot.missing and "warning" or "muted"))
      g.info:SetText("")
      g.status:SetText("")
      if not slot.missing then
        -- CF-63b (board CF63Group E): a click opens Whisper / Ask now for this run / Invite.
        g.menu, g.menuOnClick = function(owner) openSlotMenu(owner, run, slot.role, fits, open) end, true
        if #fits > 0 then g.tip = table.concat(fitNames, "\n") end
      end
    end
    fitGroupRow(g, width)
    y = y + GROUP_ROW + 5
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
    line(pools.small, parent, PAD, y + 2, width, "Reserve: " .. table.concat(reserves, ", "), "muted")
    y = y + 22
  end

  -- CF-106: Bosses, once the run has started and the loot file knows the dungeon's bosses.
  if progress and now() >= run.startsAt and #bosses > 0 then
    y = bossSection(parent, y + 8, width, progress, bosses, kills, candidates)
  end

  -- Your answer (or the organiser's start), between two dividers.
  y = divider(parent, y + 6, width) + 12
  local isOrganiser = ns.PlannedRuns.isOrganiser(run, me)
  local data = ns.Planner.data()
  if isOrganiser then
    y = section(parent, PAD, y, width, open and "Start" or ("At " .. clock(run.startsAt)))
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
          if bx + (w:GetWidth() or 120) > PAD + width then -- CF-95: below Invite all when it doesn't fit beside
            w:SetPoint("TOPLEFT", PAD, -(y + 40))
            y = y + 34
          else
            w:SetPoint("TOPLEFT", bx, -(y + 3))
          end
          break
        end
      end
    end
    y = y + 40
    if not open and data and data.reminderMinutes and date then
      line(pools.small, parent, PAD, y, width,
        "Reminder at " .. clock(run.startsAt - data.reminderMinutes * 60), "textDim")
      y = y + 20
    elseif open and ctx then
      local offline = {}
      for _, st in ipairs(ns.RunStart.missing(ns.RunStart.states(run, ns.Planner.me(), ctx))) do
        local who = st.answer.name or personName(st.answer, candidates, me) or "?"
        offline[#offline + 1] = who .. (st.answer.answer == "maybe" and " (maybe)" or "")
      end
      if #offline > 0 then
        line(pools.small, parent, PAD, y, width, table.concat(offline, ", ") ..
          (#offline == 1 and " is offline." or " are offline."), "textDim")
        y = y + 20
      end
    end
  elseif not run.pending then
    -- CF-63b (board CF63Answer): answering inline, every click saves.
    y = y + ns.RunAnswer.render(parent, run, me, candidates, PAD, y, width, function() helpers.render() end)
    answerDrawn = true
  end

  -- CF-94: Online now, fits at full width, then Edit or cancel or On the website below it, also at full width
  -- (beside each other the rows had too little room and Whisper covered their text).
  y = divider(parent, y + 6, width) + 12
  y = onlineList(parent, PAD, y, width, fits, dungeon, open) + 8
  local heading = line(pools.section, parent, PAD, y, width,
    isOrganiser and "Edit or cancel" or "On the website", "goldLight")
  local hw = heading.text.GetStringWidth and heading.text:GetStringWidth() or 120
  local info = Kit.take(pools.infos, parent)
  info:SetPoint("TOPLEFT", PAD + hw + 6, -(y + 3))
  info.tip = LINK_TIP
  y = y + 26
  if run.url then
    linkBox:ClearAllPoints()
    linkBox:SetParent(parent)
    linkBox:SetPoint("TOPLEFT", PAD, -y)
    linkBox:SetWidth(width)
    linkBox:SetText(run.url)
    linkBox:Show()
    linkPlaced = true
    y = y + 34
  end
  parent:SetHeight(y + PAD)
  detail:Update()
end
-- ===== The list =====

-- CF-106 (board DL01): "Runs" with Ask now…, the runs grouped Today, Tomorrow, Later, each row with your status;
-- "No runs planned" and Find a dungeon › without runs; "Runs from 09:51" with an ⓘ at the bottom.
local function renderList(runs, me, candidates, bare)
  for _, name in ipairs({ "runRows", "listText", "listTitle", "listButtons", "listInfos", "listGroups" }) do
    Kit.recycle(pools[name])
  end
  rows = {}
  local parent = list.child
  local width = math.max(200, (list:GetWidth() or 0) - 6)
  local y = 4
  local selected = status().selected
  placeText(pools.listTitle, parent, 14, y + 8, width - 120, "Runs", "goldLight")
  if not bare then
    local ask = Kit.take(pools.listButtons, parent)
    ask:SetLabel("Ask now\226\128\166")
    ask:SetEnabled(true)
    ask.tooltip = ASK_TIP
    ask:SetScript("OnClick", function() ns.RunDialogs.ask({}) end) -- CF-65: a dungeon that fits you
    ask:SetPoint("TOPRIGHT", parent, "TOPLEFT", width - 8, -(y + 6))
  end
  y = y + 40
  if bare then
    parent:SetHeight(y)
    list:Update()
    return
  end
  local levels = ownLevels(candidates)
  local lastGroup
  for _, item in ipairs(runs) do
    local run, progress = item.run, item.progress
    local group = date and ns.RunProgress.dayGroup(run.startsAt, now(), date) or "Today"
    if group ~= lastGroup then
      local g = placeText(pools.listGroups, parent, 14, y + 10, width - 28, group, "gold")
      if g.text.SetWordWrap then g.text:SetWordWrap(false) end
      y = y + 28
      lastGroup = group
    end
    local r = Kit.take(pools.runRows, parent)
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetPoint("RIGHT", parent, "RIGHT")
    r.value = "run:" .. run.id
    local full = dungeonName(run)
    r.name:SetText(ns.PlannedRuns.shortName(full))
    r.fullName = ns.PlannedRuns.shortName(full) ~= full and full or nil
    r.name:SetTextColor(Theme.color(r.value == selected and "goldLight" or "text"))
    r.right:SetText(date and ns.PlannedRuns.rowTime(run.startsAt, now(), date) or "")
    local pipSlots = ns.PlannedRuns.slots(run, candidates, dungeonOf(run))
    local open = 0
    for k, p in ipairs(r.pips) do
      local slot = pipSlots[k]
      if slot and slot.answer then
        p:SetColorTexture(Theme.color(slot.role or "dps"))
      else
        p:SetColorTexture(Theme.color("track"))
        open = open + 1
      end
    end
    local yes = ns.PlannedRuns.counts(run)
    local meta = yes .. " in"
    if progress.state == "going" or progress.state == "cleared" then
      meta = meta .. DOT .. progress.label
    elseif progress.state ~= "noBoss" and open > 0 then
      meta = meta .. DOT .. open .. " open"
    end
    r.meta:SetText(meta)
    r.clock:SetShown(run.pending == true)
    local st = ns.RunProgress.rowStatus(run, { me = me, levels = levels, dungeon = dungeonOf(run),
                                               progress = progress })
    local def = STATUS[st]
    r.who:SetText(def[1])
    r.who:SetTextColor(Theme.color(def[2]))
    r.dot:SetShown(st == "answer") -- the gold square before "answer" (a texture, not a font character)
    r.status = st
    r:SetSelected(r.value == selected)
    rows[#rows + 1] = { value = r.value, frame = r }
    y = y + RUN_ROW
  end
  if #runs == 0 then
    placeText(pools.listText, parent, 14, y + 6, width - 28, "No runs planned", "text")
    local find = Kit.take(pools.listButtons, parent)
    find:SetLabel("Find a dungeon \226\128\186")
    find:SetEnabled(true)
    find.tooltip = nil
    find:SetScript("OnClick", function() ns.MainFrame.showDungeon(nil) end)
    find:SetPoint("TOPLEFT", 14, -(y + 28))
    y = y + 64
  end
  -- CF-62: how old the runs are, one muted line at the bottom of the list.
  local data = ns.Planner.data()
  if data and date then
    local at = when(data.updatedAt):gsub("^Today ", "")
    local footer = placeText(pools.listText, parent, 14, y + 12, width - 40, "Runs from " .. at, "faint")
    local fw = footer.text.GetStringWidth and footer.text:GetStringWidth() or 120
    local info = Kit.take(pools.listInfos, parent)
    info:SetPoint("TOPLEFT", 14 + fw + 6, -(y + 11))
    info.tip = RUNS_TIP -- CF-63 board CF63RunDetail
    y = y + 36
  end
  parent:SetHeight(y + 12)
  list:Update()
end

-- The detail without a run (or the window's empty state): a short line in the middle.
local function renderEmpty(messageText)
  local parent = detail.child
  local width = detailWidth()
  local y = PAD + 60
  if messageText then
    local holder = placeText(pools.small, parent, PAD, y, width, messageText, "textDim", "CENTER")
    y = y + 60 + (holder.text.GetStringHeight and (holder.text:GetStringHeight() or 0) or 0)
  else
    line(pools.small, parent, PAD, y, width, "Plan a run from a dungeon in the Dungeons tab, or on the website.",
      "muted", "CENTER")
    y = y + 40
  end
  parent:SetHeight(y + PAD)
  detail:Update()
end

-- ===== Public =====

function RunsTab.create(parent, h)
  helpers = h
  root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  local column = CreateFrame("Frame", nil, root)
  column:SetPoint("TOPLEFT")
  column:SetPoint("BOTTOMLEFT")
  column:SetWidth(LIST_WIDTH)
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
    listText = Kit.pool(Kit.textHolder("tiny")), listTitle = Kit.pool(Kit.textHolder("section")),
    listGroups = Kit.pool(Kit.textHolder("label")), listButtons = Kit.pool(button), listInfos = Kit.pool(Kit.info),
    runRows = Kit.pool(runRow),
    name = Kit.pool(Kit.textHolder("name")), section = Kit.pool(Kit.textHolder("section")),
    small = Kit.pool(Kit.textHolder("small")), tiny = Kit.pool(Kit.textHolder("tiny")),
    buttons = Kit.pool(button), primary = Kit.pool(primary),
    groupRows = Kit.pool(groupRow), onlineRows = Kit.pool(onlineRow), infos = Kit.pool(Kit.info),
    clocks = Kit.pool(Kit.clock), bosses = Kit.pool(bossRow),
    dividers = Kit.pool(function(p)
      local f = CreateFrame("Frame", nil, p)
      local t = Theme.fill(f, "divider", "BORDER")
      t:SetAllPoints()
      return f
    end),
  }
  return root
end

function RunsTab.show()
  if not root then return end
  root:Show()
  if not ticking then
    ticking = ns.Timer.every(60, function()
      if root and root:IsShown() and helpers then helpers.render() end
    end)
  end
  ns.Dungeons.applyGroupFinder(ns.GroupFinder.dungeons())
end

function RunsTab.hide() if root then root:Hide() end end

function RunsTab.closed() end

function RunsTab.select(value)
  status().selected = value
  helpers.render()
end

-- CF-48: selects a run without drawing (the window draws when it opens on the tab). value: "run:<id>".
function RunsTab.selectQuietly(value)
  if helpers then status().selected = value end
end

--[[ The runs the tab lists, soonest first, each { run, progress, bosses }: not cancelled, before the start, 3 h after
it without a kill, until the daily reset with kills (RunProgress). ]]
function RunsTab.runs(kills)
  local out = {}
  kills = kills or ns.KillLog.all()
  for _, run in ipairs(ns.Planner.upcoming(ns.PlannedRuns.KEEP_PROGRESS)) do
    local progress, bosses = progressOf(run, kills)
    if progress.visible then out[#out + 1] = { run = run, progress = progress, bosses = bosses } end
  end
  return out
end

-- CF-106: the badge on the Runs tab (RunProgress.badge with your characters' levels).
function RunsTab.badge(view)
  return ns.RunProgress.badge(ns.Planner.upcoming(), { me = ns.Planner.me(), now = now(), dungeonOf = dungeonOf,
                                                       levels = ownLevels(ns.Dungeons.candidates(view)) })
end

-- Fills the tab from the view model. messageText: the window's empty state (no community etc.).
local function draw(view, messageText)
  entries = {}
  clearDetail()
  local me = ns.SelfInfo.read()
  if messageText then
    renderList({}, me, {}, true)
    renderEmpty(messageText)
    return
  end
  local who = ns.Planner.me()
  me.guids, me.battleTag = who.guids, who.battleTag
  local kills = ns.KillLog.all()
  local runs = RunsTab.runs(kills)
  local candidates = ns.Dungeons.candidates(view)
  for _, item in ipairs(runs) do entries["run:" .. item.run.id] = item end
  local st = status()
  if not st.selected or not entries[st.selected] then
    -- CF-62: the next run you're in (or organise), else the first.
    local first
    for _, item in ipairs(runs) do
      local mine = ns.PlannedRuns.yourAnswer(item.run, who)
      if not first and (ns.PlannedRuns.isOrganiser(item.run, who) or (mine and mine.answer ~= "cant")) then
        first = "run:" .. item.run.id
      end
    end
    st.selected = first or (runs[1] and ("run:" .. runs[1].run.id)) or nil
  end
  renderList(runs, me, candidates)
  local entry = st.selected and entries[st.selected]
  if entry then
    renderRun(entry.run, me, candidates, entry.progress, entry.bosses, kills)
  else
    renderEmpty(nil)
  end
end

function RunsTab.render(view, messageText)
  if not root then return end
  draw(view, messageText)
  sweep() -- CF-65: hide only what this draw didn't use
end

function RunsTab.reset()
  root, entries, rows = nil, {}, {}
end

-- For the specs: the list rows, the texts (in pool order), the buttons by label, the link box, the boss rows.
function RunsTab.rows() return rows end
function RunsTab.linkBox() return linkBox end
function RunsTab.detailArea() return detail end

function RunsTab.detailTexts()
  local out = {}
  for _, name in ipairs({ "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i] end
  end
  return out
end

function RunsTab.texts()
  local out = {}
  for _, name in ipairs({ "listTitle", "listGroups", "listText", "name", "section", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  for _, name in ipairs({ "runRows", "groupRows", "onlineRows", "bosses" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do
      local item = p.items[i]
      for _, key in ipairs({ "name", "right", "meta", "info", "online", "status", "who" }) do
        local fs = item[key]
        if type(fs) == "table" and fs.GetText and fs:GetText() and fs:GetText() ~= "" then
          out[#out + 1] = fs:GetText()
        end
      end
    end
  end
  for _, t in ipairs(ns.RunAnswer and ns.RunAnswer.texts() or {}) do out[#out + 1] = t end -- CF-63b
  return out
end

function RunsTab.buttons()
  local out = ns.RunAnswer and ns.RunAnswer.buttons() or {} -- CF-63b
  for _, name in ipairs({ "buttons", "primary", "listButtons" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  for i = 1, pools and pools.onlineRows.used or 0 do
    local b = pools.onlineRows.items[i].button
    out[b.label:GetText() .. ":" .. i] = b
  end
  return out
end

local function used(name)
  local out = {}
  for i = 1, pools and pools[name].used or 0 do out[i] = pools[name].items[i] end
  return out
end

function RunsTab.onlineRows() return used("onlineRows") end -- CF-94
function RunsTab.groupRows() return used("groupRows") end
function RunsTab.bossRows() return used("bosses") end -- CF-106

function RunsTab.tips()
  local out = {}
  for _, name in ipairs({ "infos", "listInfos", "clocks" }) do
    for i = 1, pools and pools[name].used or 0 do out[#out + 1] = pools[name].items[i].tip end
  end
  for _, name in ipairs({ "primary", "buttons", "groupRows", "listButtons", "bosses" }) do
    for i = 1, pools and pools[name].used or 0 do
      local t = pools[name].items[i].tooltip or pools[name].items[i].tip
      if t then out[#out + 1] = t end
    end
  end
  for _, t in ipairs(ns.RunAnswer and ns.RunAnswer.tips() or {}) do out[#out + 1] = t end -- CF-63b
  return out
end

ns.RunsTab = RunsTab
return RunsTab
