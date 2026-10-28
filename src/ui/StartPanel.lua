-- StartPanel: the start-time panel of a planned run (CF-48; board run-start.html). Opens by itself at start
-- time for the organiser, or from the run in the Dungeons tab. The organiser sees each friend's state (from
-- Battle.net presence and sync) with what to do about it: Invite, Whisper and Invite <other character>
-- instead, Ping on Discord; Invite everyone ready and Ping everyone missing. Everyone else sees the
-- organiser's state and Request invite, or whom to whisper when the organiser is offline.
local _, ns = ...

local StartPanel = {}
local Kit = ns.Kit

local WIDTH, HEIGHT = 600, 470
local PAD = 20
local ROW = 46
local DOT = " \194\183 "
local ROLE_WORDS = { tank = "tank", heal = "healer", dps = "damage" }
local ANSWER_WORDS = { ["in"] = "in", maybe = "maybe", cant = "can't" }

local dialog, pools, runId

local function create()
  dialog = Kit.dialog({ title = "Start", width = WIDTH, height = HEIGHT })
  dialog.footer:Hide()
  local content = dialog.content
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", dialog.titleBar, "BOTTOMLEFT")
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  pools = {
    name = Kit.pool(Kit.textHolder("group")), small = Kit.pool(Kit.textHolder("small")),
    tiny = Kit.pool(Kit.textHolder("tiny")),
    buttons = Kit.pool(function(parent) return Kit.button(parent, "", nil) end),
    primary = Kit.pool(function(parent) return Kit.button(parent, "", nil, "primary") end),
  }
end

local function text(pool, x, y, width, value, color)
  return Kit.placeText(pools[pool], dialog.content, x, y, width, value, color)
end

local function button(kind, label, x, y, onClick, enabled)
  local b = Kit.take(pools[kind], dialog.content)
  b:SetLabel(label)
  b:SetEnabled(enabled ~= false)
  b:SetScript("OnClick", onClick)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", dialog.content, "TOPLEFT", x, -y)
  return b
end

local function findRun(id)
  for _, run in ipairs(ns.Planner.upcoming()) do
    if run.id == id then return run end
  end
  return nil
end

local function dungeonName(run)
  local d = ns.Dungeons.get(run.dungeon)
  return d and d.name or tostring(run.dungeon)
end

local function personName(a)
  local person = a.battleTag and ns.db.global.people[a.battleTag]
  if person then return ns.Linker.displayName(a.battleTag, person.displayName) end
  return (a.battleTag and a.battleTag:match("^([^#]+)")) or a.name or "someone"
end

-- The state line of a friend: "ready · online on this character", "online, but on Tok Ironhide (33)".
local function stateText(s)
  if s.state == "ready" then return "ready" .. DOT .. "online on this character", "onlineText" end
  if s.state == "other" then
    return string.format("online, but on %s (%s)", tostring(s.presence.name), tostring(s.presence.level or "?")),
      "goldLight"
  end
  if s.state == "grouped" then return "already grouped", "onlineText" end
  if s.state == "cant" then
    return "can't" .. (s.answer.source == "discord" and (DOT .. "answered on Discord") or ""), "muted"
  end
  return "offline" .. (s.answer.source == "discord" and (DOT .. "answered on Discord") or ""), "muted"
end

local function pinged(run, a)
  for _, item in ipairs(ns.Planner.pending()) do
    if item.kind == "ping" and item.run == run.id and ((a.battleTag and item.battleTag == a.battleTag)
        or (a.guid and item.guid == a.guid)) then
      return true
    end
  end
  return false
end

local function drawOrganiser(run, ctx)
  local states = ns.RunStart.states(run, ns.Planner.me(), ctx)
  local yes, maybe = ns.PlannedRuns.counts(run)
  local y = 16
  text("name", PAD, y, WIDTH - 2 * PAD, dungeonName(run) .. DOT .. "starting now", "goldLight")
  text("small", PAD, y + 22, WIDTH - 2 * PAD, string.format("you organise%s%d in%s%d maybe", DOT, yes, DOT, maybe),
    "muted")
  y = y + 52
  if #states == 0 then
    text("small", PAD, y, WIDTH - 2 * PAD, "Nobody else answered yet.", "muted")
    y = y + 24
  end
  for _, s in ipairs(states) do
    local a = s.answer
    local first = tostring(a.name or personName(a)) .. DOT .. personName(a) .. DOT
      .. (ROLE_WORDS[a.role] or "damage") .. DOT .. ANSWER_WORDS[a.answer]
    text("small", PAD, y, 300, first, "text")
    local line, color = stateText(s)
    text("tiny", PAD, y + 18, 300, line, color)
    local x = PAD + 310
    if s.state == "ready" then
      button("buttons", "Invite", x, y, function() ns.RunAlerts.invite(s) end)
    elseif s.state == "other" then
      button("buttons", "Whisper " .. personName(a), x, y, function() ns.RunAlerts.whisperSwitch(run, s) end)
      button("buttons", "Invite " .. tostring(s.presence.name) .. " instead", x, y + 30, function()
        ns.RunAlerts.invite(s)
      end)
      y = y + 22
    elseif s.state == "offline" and a.answer ~= "cant" then
      if pinged(run, a) then
        text("tiny", x, y + 6, 200, "ping queued" .. DOT .. "after /reload", "faint")
      else
        button("buttons", "Ping on Discord", x, y, function()
          ns.RunAlerts.ping(run, a)
          StartPanel.refresh()
        end)
      end
    end
    y = y + ROW
  end
  local ready = ns.RunStart.readyToInvite(states)
  local missing = {}
  for _, s in ipairs(ns.RunStart.missing(states)) do
    if not pinged(run, s.answer) then missing[#missing + 1] = s end
  end
  local bottom = HEIGHT - 110
  button("primary", string.format("Invite everyone ready (%d)", #ready), PAD, bottom, function()
    ns.RunAlerts.inviteReady(run)
  end, #ready > 0)
  button("buttons", "Ping everyone missing on Discord", PAD + 200, bottom, function()
    for _, s in ipairs(missing) do ns.RunAlerts.ping(run, s.answer) end
    StartPanel.refresh()
  end, #missing > 0)
  local queued = false
  for _, item in ipairs(ns.Planner.pending()) do
    if item.kind == "ping" then queued = true end
  end
  if queued then
    button("buttons", "Reload now", PAD + 440, bottom, function()
      if not ns.Panels.reload() then ns:Print("Type /reload to post it now.") end
    end)
  end
  local data = ns.Planner.data()
  if data and date then
    text("tiny", PAD, bottom + 40, WIDTH - 2 * PAD, "Runs updated at " .. ns.PlannedRuns.clock(data.updatedAt, date)
      .. DOT .. "pings go out about 15 s after a /reload", "faint")
  end
end

local function drawOther(run, ctx)
  local y = 16
  text("name", PAD, y, WIDTH - 2 * PAD, dungeonName(run) .. DOT .. "now", "goldLight")
  y = y + 30
  local state, presence = ns.RunStart.organiserState(run, ctx)
  local organiser = run.organiser and personName(run.organiser) or "The organiser"
  local where = state == "offline" and "offline"
    or ("on " .. tostring(presence and presence.name or run.organiser.name) .. DOT
      .. (state == "other" and "online on another character" or "online"))
  text("small", PAD, y, WIDTH - 2 * PAD, organiser .. " organises" .. DOT .. where, state == "offline" and "warning"
    or "text")
  y = y + 26
  local mine = ns.PlannedRuns.yourAnswer(run, ns.Planner.me())
  if mine then
    text("small", PAD, y, WIDTH - 2 * PAD, tostring(mine.name or "you") .. DOT .. "you" .. DOT .. "invite pending",
      "textDim")
    y = y + 30
  end
  if state == "offline" then
    local nextOne = ns.RunStart.nextPerson(ns.RunStart.states(run, ns.Planner.me(), ctx))
    if nextOne then
      text("small", PAD, y, WIDTH - 2 * PAD, string.format("%s is offline. Whisper %s for an invite instead.",
        organiser, tostring(nextOne.presence and nextOne.presence.name or nextOne.answer.name)), "text")
      button("buttons", "Whisper " .. personName(nextOne.answer), PAD, y + 24, function()
        ns.ContextMenu.whisper(nextOne.presence and nextOne.presence.name or nextOne.answer.name)
      end)
    else
      text("small", PAD, y, WIDTH - 2 * PAD, organiser .. " is offline, and nobody else in the group is online yet.",
        "muted")
    end
    return
  end
  button("primary", "Request invite", PAD, y, function() ns.RunAlerts.requestInvite(run) end)
  text("tiny", PAD + 130, y + 7, 300, "Sends " .. organiser .. " a request in game", "faint")
end

-- Draws the panel for the run (again).
function StartPanel.refresh()
  if not (dialog and dialog:IsShown() and runId) then return end
  local run = findRun(runId)
  for _, p in pairs(pools) do Kit.release(p) end
  if not run then
    text("small", PAD, 20, WIDTH - 2 * PAD, "This run is no longer planned.", "muted")
    return
  end
  local ctx = ns.RunAlerts.context()
  if ns.PlannedRuns.isOrganiser(run, ns.Planner.me()) then drawOrganiser(run, ctx) else drawOther(run, ctx) end
end

-- Opens the panel for a run (by id).
function StartPanel.open(id)
  if not dialog then create() end
  runId = id
  dialog:Show()
  StartPanel.refresh()
end

function StartPanel.isShown() return dialog ~= nil and dialog:IsShown() end

-- For the specs.
function StartPanel.texts()
  local out = {}
  for _, name in ipairs({ "name", "small", "tiny" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[#out + 1] = p.items[i].text:GetText() end
  end
  return out
end

function StartPanel.buttons()
  local out = {}
  for _, name in ipairs({ "buttons", "primary" }) do
    local p = pools and pools[name]
    for i = 1, p and p.used or 0 do out[p.items[i].label:GetText()] = p.items[i] end
  end
  return out
end

ns.StartPanel = StartPanel
return StartPanel
