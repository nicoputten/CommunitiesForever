-- RunAlerts: what a planned run brings up in game (CF-48; design docs/design/runs-2026-10/run-start.html).
-- Every RunStart.TICK seconds it checks the runs you organise or answered I'm in or Maybe: at the site's
-- reminder time a chat line; at start time the organiser gets the start panel, everyone else a "Starting now"
-- line with Request invite. CF-63d: banners at the top of the screen 30 and 15 minutes before and at the start
-- (RunBanner, a soft chime), held during combat and battlegrounds (RunStart.release). Chat lines (each kind can be
-- turned off) also say when someone answered your run, a friend is on another character, a Discord ping was
-- queued and runs arrived from a friend. Clickable parts are addon chat links (V47).
local _, ns = ...

local RunAlerts = {}

local addonRef, timer
local last          -- server time of the last check
local held = {}     -- CF-63d: banners that came due during combat or a battleground
local links = {}    -- chat link number -> function
local linkCount = 0
local ANSWER_LINES = { ["in"] = "%s is in for %s (%s).", maybe = "%s is a maybe for %s (%s).",
                       cant = "%s can't make %s (%s)." }
local VIA = { game = "answered in game", discord = "answered on Discord", site = "answered on the website" }

local function settings() return addonRef.db.global.settings end
local function now() return GetServerTime() end

local function lineOn(kind) return ns.Settings.runLine(kind) end

local function say(kind, text)
  if lineOn(kind) then addonRef:Print(text) end
end

-- A clickable part of a chat line that runs fn when clicked.
local function link(text, fn)
  linkCount = linkCount + 1
  links[linkCount] = fn
  return ns.ChatLinks.link("run:" .. linkCount, text)
end

local function dungeonName(run)
  return ns.Dungeons.runName(run) -- CF-63
end

local function clock(at)
  return date and ns.PlannedRuns.clock(at, date) or ""
end

local function who(a)
  if not a then return "someone" end
  local person = a.battleTag and addonRef.db.global.people[a.battleTag]
  if person then return ns.Linker.displayName(a.battleTag, person.displayName) end
  return a.name or (a.battleTag and a.battleTag:match("^([^#]+)")) or "someone"
end

-- What the start panel and the states need: who is online, whose character a GUID is, your group.
function RunAlerts.context()
  local people = addonRef.db.global.people
  local grouped = {}
  for _, guid in ipairs(ns.Instance.groupGuids()) do grouped[guid] = true end
  return {
    online = ns.Sync.online(),
    grouped = grouped,
    keyOf = function(a)
      if not a.guid then return nil end
      for key, person in pairs(people) do
        if type(person) == "table" and person.chars and person.chars[a.guid] then return key end
      end
      return nil
    end,
  }
end

-- Asks the organiser for an invite (C_PartyInfo.RequestInviteFromUnit, V48), or says whom to whisper.
function RunAlerts.requestInvite(run)
  local state, presence = ns.RunStart.organiserState(run, RunAlerts.context())
  local name = presence and presence.name or (run.organiser and run.organiser.name)
  if state ~= "offline" and name and ns.Party.requestInvite(name) then
    addonRef:Print("Asked " .. who(run.organiser) .. " for an invite.")
    return true
  end
  addonRef:Print(state == "offline" and (who(run.organiser) .. " is offline. Whisper someone in the group for an "
    .. "invite.") or ("Whisper " .. tostring(name or who(run.organiser)) .. " for an invite."))
  return false
end

-- Invites one friend (their character online now). Returns true when an invite went out.
function RunAlerts.invite(s)
  local p = s.presence
  if not p then return false end
  return ns.Party.invite(p.name, p.gameAccountID) ~= nil
end

-- Invite everyone ready: one click, one invite per friend (V69).
function RunAlerts.inviteReady(run)
  local count = 0
  for _, s in ipairs(ns.RunStart.readyToInvite(ns.RunStart.states(run, ns.Planner.me(), RunAlerts.context()))) do
    if RunAlerts.invite(s) then count = count + 1 end
  end
  return count
end

-- Queues a Discord ping for a friend who is missing (posted after /reload).
function RunAlerts.ping(run, a)
  ns.Planner.ping(run, a)
  say("ping", string.format("Discord ping for %s queued. It reaches Discord after /reload. %s", who(a),
    link("Reload now", function()
      if not ns.Panels.reload() then addonRef:Print("Type /reload to post it now.") end
    end)))
end

-- An editable whisper to a friend on another character.
function RunAlerts.whisperSwitch(run, s)
  local p = s.presence
  if not p then return false end
  local text = ns.RunStart.switchText(dungeonName(run), p.name, s.answer.name or "the character you signed up with")
  return ns.ContextMenu.whisperText(p.name, text)
end

local function reminder(run, organiser)
  local mine = ns.PlannedRuns.yourAnswer(run, ns.Planner.me())
  local yours = organiser and "You organise." or (mine and mine.name and ("You're in as " .. mine.name .. ".")
    or "You're in.")
  if mine and mine.answer == "maybe" then yours = "You said maybe." end
  local minutes = math.floor((run.startsAt - now()) / 60 + 0.5)
  say("reminder", string.format("%s starts in %d min (%s). %s %s", dungeonName(run), minutes, clock(run.startsAt),
    yours, link("Open", function() ns.MainFrame.showRun(run.id) end)))
end

local function starting(run, organiser)
  if organiser then
    say("starting", string.format("%s is starting now. %s", dungeonName(run),
      link("Open the start panel", function() ns.StartPanel.open(run.id) end)))
    ns.StartPanel.open(run.id)
    -- Friends on another character, with what to do about it.
    for _, s in ipairs(ns.RunStart.states(run, ns.Planner.me(), RunAlerts.context())) do
      if s.state == "other" then
        say("otherChar", string.format("%s is online on %s, signed up as %s. %s %s", who(s.answer),
          tostring(s.presence.name), tostring(s.answer.name), link("Whisper", function()
            RunAlerts.whisperSwitch(run, s)
          end), link("Invite " .. tostring(s.presence.name), function() RunAlerts.invite(s) end)))
      end
    end
    return
  end
  say("starting", string.format("%s is starting now. Invites go out from %s. %s", dungeonName(run),
    tostring(run.organiser and run.organiser.name or who(run.organiser)),
    link("Request invite", function() RunAlerts.requestInvite(run) end)))
end

-- CF-63d: not now: in combat, during an encounter or in a battleground (the banner waits).
local function busy()
  if InCombatLockdown and InCombatLockdown() then return true end
  return ns.Instance.messagingRestricted()
end

-- CF-63d: a banner for event { kind, run, organiser }: your role, the character you go as, the start.
local function banner(event)
  local run = event.run
  local mine = ns.PlannedRuns.yourAnswer(run, ns.Planner.me())
  local you = ns.SelfInfo.read()
  local char = mine and (mine.name or (mine.guid == you.guid and you.name)) or nil
  ns.RunBanner.show({
    kind = event.kind, runId = run.id, name = ns.PlannedRuns.shortName(dungeonName(run)),
    role = mine and mine.role, char = char, at = run.startsAt,
    onInvite = event.organiser and function() RunAlerts.inviteReady(run) end or nil,
  })
  if settings().runSound ~= false then ns.ChatFrames.playSound() end
end

-- CF-63d: shows the banners held so far, unless still busy.
local function releaseBanners(t)
  if #held == 0 or busy() then return end
  local list = ns.RunStart.release(held, t)
  held = {}
  if settings().runToasts == false then return end
  for _, event in ipairs(list) do banner(event) end
end

-- Checks what became due since the last check.
function RunAlerts.check()
  local t = now()
  local data = ns.Planner.data()
  local upcoming, me = ns.Planner.upcoming(), ns.Planner.me()
  local due = ns.RunStart.due(upcoming, me, last, t, data and data.reminderMinutes)
  for _, event in ipairs(ns.RunStart.banners(upcoming, me, last, t)) do held[#held + 1] = event end
  last = t
  for _, event in ipairs(due) do
    if event.kind == "reminder" then reminder(event.run, event.organiser) else starting(event.run, event.organiser) end
  end
  releaseBanners(t)
end

-- Checks every TICK seconds while there are runs to show; idle without any (a list arriving starts it again).
local function schedule()
  if timer or #ns.Planner.upcoming() == 0 then return end
  timer = C_Timer.NewTimer(ns.RunStart.TICK, function()
    timer = nil
    RunAlerts.check()
    schedule()
  end)
end

function RunAlerts.start(addon)
  addonRef = addon
  last, links, linkCount, held = now(), {}, 0, {}
  if timer then timer:Cancel() end
  timer = nil
  local events = LibStub("AceEvent-3.0"):Embed({})
  events:RegisterMessage(ns.Planner.UPDATED, function() schedule() end)
  events:RegisterMessage(ns.Planner.ANSWERED, function(_, run, a)
    local line = ANSWER_LINES[a.answer]
    if line then
      say("answered", string.format(line, who(a), dungeonName(run), VIA[a.source] or VIA.game))
    end
  end)
  events:RegisterMessage(ns.Planner.RECEIVED, function(_, updatedAt)
    say("updated", string.format("Runs updated at %s. Type /reload for newer.", clock(updatedAt)))
  end)
  events:RegisterMessage(ns.ChatLinks.CLICKED, function(_, path)
    local n = tonumber(path:match("^run:(%d+)$") or "")
    if n and links[n] then links[n]() end
  end)
  schedule()
end

ns.RunAlerts = RunAlerts
return RunAlerts
