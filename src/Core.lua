-- Core: AceAddon init and wiring. The private addon table is the addon object.
local ADDON_NAME, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(ns, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
CommunitiesForever = addon

-- CF-32: names for Bindings.xml in Blizzard's keybinding menu (rule 5 allows BINDING_* globals).
BINDING_HEADER_COMMUNITIESFOREVER = ADDON_NAME
BINDING_NAME_COMMUNITIESFOREVER_TOGGLE = "Open or close the window"

-- Called by the key binding (Bindings.xml).
function addon:ToggleWindow()
  ns.MainFrame.toggle()
end

local function GetVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
  end
  return "unknown"
end

function addon:OnInitialize()
  self.version = GetVersion() -- CF-35: sent in HELLO, compared with friends' versions
  self.db = LibStub("AceDB-3.0"):New("CommunitiesForeverDB", ns.Store.defaults(), true)
  ns.Store.init(self.db.global)
  ns.Settings.register()
  self:RegisterChatCommand("cf", "OnSlashCommand")
end

function addon:OnEnable()
  ns.SelfInfo.watch(self)
  ns.FeedTracker.start(self) -- before SelfTracker: its first refresh may record feed events
  ns.SelfTracker.start(self)
  ns.PvpTracker.start(self) -- CF-52: after SelfTracker (keeps chars[guid].pvp of the stored character)
  ns.Community.watch(self)
  ns.CommunitySelection.start(self)
  ns.CommunityChat.start(self) -- CF-25: community chat color, alerts, Community tab
  ns.SyncChannel.start(self) -- CF-31: the hidden channel HELLO and BYE are broadcast on
  ns.MemberTracker.start(self)
  ns.ActivityTracker.start(self) -- CF-23: after MemberTracker (companions must be community members)
  ns.PlayTracker.start(self) -- CF-53: after ActivityTracker (instance events) and MemberTracker (groups)
  ns.DoomsdayTracker.start(self) -- CF-56: after the trackers whose feed events count; before Sync (HELLO dd)
  ns.Presence.watch(self)
  ns.PresenceTracker.start(self)
  ns.MainFrame.start(self)
  ns.Minimap.start(self)
  ns.Planner.start(self) -- CF-46: planned runs (Data\Runs.lua, stored, sync); before Sync's first HELLO
  ns.Messenger.start(self)
  ns.Ping.start(self)
  ns.Sync.start(self)
  ns.Invites.start(self)
  ns.Tooltip.start(self)
  ns.Notify.start(self)
  ns.ChatLinks.watch(self) -- CF-27: clickable chat links
  ns.GroupAsks.start(self) -- CF-27: "Who's up for it?"
  ns.RunAlerts.start(self) -- CF-48: run reminders, start time, chat lines
  ns.DoomsdayBoard.start(self) -- CF-57b: Board, Ladder, Feats (feats remembered from the first sight)
  ns.DoomsdayAlerts.start(self) -- CF-57: Doomsday chat lines and the crown toast (after Sync: PEOPLE_UPDATED)
  ns.Setup.start(self) -- CF-26: onboarding wizard on the first login, Community tab prompt on other characters
end

-- Prints why a community command can't run here, or returns true when it can.
local function CommunityAvailable(self)
  if not ns.CommunitySelection.selected() then
    self:Print("No community selected. Select one with /cf settings.")
    return false
  end
  if not ns.CommunitySelection.active() then
    self:Print(string.format("This character is not a member of %s.",
      ns.CommunitySelection.name() or "the selected community"))
    return false
  end
  return true
end

local function printLines(self, lines)
  for _, line in ipairs(lines) do self:Print(line) end
end

-- /cf ask: ask friends who's up for a dungeon (CF-27), or how your ask stands.
local function askCommand(self, _, input)
  local name = input:match("^%s*%S+%s+(.-)%s*$") -- the rest of the line: names have spaces
  local dungeon = name and name ~= "" and ns.Dungeons.dungeonOf(name)
  if dungeon then
    ns.RunDialogs.ask({ dungeon = dungeon }) -- CF-65: the same Ask dialog as every other way in
  elseif name and name ~= "" then
    self:Print("No dungeon called " .. name .. ". Example: /cf ask Deadmines")
  else
    local ask = ns.GroupAsks.current()
    if not ask then
      self:Print("No open ask. /cf ask <dungeon> asks friends who's up for it.")
      return
    end
    local s = ns.GroupAsk.summary(ask)
    self:Print(string.format("%s: joining %s; later %s; no %s; waiting %s.", ask.dungeon.name,
      table.concat(s.join, ", "), table.concat(s.later, ", "), table.concat(s.no, ", "),
      table.concat(s.waiting, ", ")))
  end
end

local function activityCommand(self, argument)
  if argument == "debug" then
    ns.ActivityTracker.setDebug(not ns.ActivityTracker.debugOn())
    self:Print(ns.ActivityTracker.debugOn()
      and "Activity debug on: instance events and run decisions are printed (stays on after /reload)."
      or "Activity debug off.")
    return
  end
  local run = ns.ActivityTracker.current()
  self:Print(run and string.format("In %s (%s) for %d min, %d bosses killed.", tostring(run.name),
    tostring(run.kind), math.floor((GetServerTime() - (run.startedAt or 0)) / 60), run.bossCount or 0)
    or "Not in a dungeon, raid or battleground.")
end

local function debugCommand(self, _, _, command) -- hidden: not in the help
  ns.Debug.set(command == "debugon")
  self:Print(command == "debugon" and "Debug on: fake friend in the window (not saved, not synced)."
    or "Debug off.")
  if ns.MainFrame.isShown() then ns.MainFrame.render() end
end

--[[ The /cf commands, in help order. name: the first word (lower case; "" for /cf alone); help: its lines in
/cf help (none: hidden); run(self, argument, input, command): argument is the second word, input the
whole line. ]]
local COMMANDS = {
  { name = "", help = { "/cf - open or close the window" }, run = function() ns.MainFrame.toggle() end },
  { name = "version", help = { "/cf version - show the addon version" },
    run = function(self) self:Print("Version " .. GetVersion()) end },
  { name = "self", help = { "/cf self - show your stored characters" },
    run = function(self) printLines(self, ns.Describe.selfRecord(self.db.global.self, GetServerTime())) end },
  { name = "members", help = { "/cf members - show members of the selected community" },
    run = function(self)
      if not CommunityAvailable(self) then return end
      printLines(self, ns.Describe.members(ns.MemberTracker.members(), ns.CommunitySelection.name(),
        ns.MemberTracker.changedAt(), GetServerTime()))
    end },
  { name = "friends", help = { "/cf friends - show Battle.net friends in Forever" },
    run = function(self)
      printLines(self, ns.Describe.friends(ns.PresenceTracker.friends(), ns.PresenceTracker.online(),
        self.db.global.presence, GetServerTime()))
    end },
  { name = "people", help = { "/cf people - show who owns which community character" },
    run = function(self)
      if not CommunityAvailable(self) then return end
      printLines(self, ns.Describe.view(ns.ViewModel.build(self), GetServerTime()))
    end },
  { name = "sync", help = { "/cf sync - announce your characters to friends now",
                            "/cf sync debug - print message parts, missing parts and resends (on/off)" },
    run = function(self, argument)
      if argument == "debug" then -- CF-28: trace parts, missing parts and resends
        ns.Messenger.setDebug(not ns.Messenger.debugOn())
        self:Print(ns.Messenger.debugOn() and "Sync debug on until /reload: message parts, missing parts and resends "
          .. "are printed."
          or "Sync debug off.")
        return
      end
      ns.Sync.announce()
      self:Print("Sync: announced your record to friends online in Forever.")
    end },
  { name = "ping", help = { "/cf ping [bytes] - test messages with friends who run the addon; /cf ping stats" },
    run = function(self, argument)
      if argument ~= "stats" then
        ns.Ping.send(tonumber(argument))
        return
      end
      local s = ns.Messenger.stats()
      self:Print(string.format("Messages: %d chunks sent, %d received, %d dropped, %d queued, %d resent, %d missed.",
        s.sent, s.received, s.dropped, s.queued, s.resent, s.missed))
    end },
  { name = "doomsday", help = { "/cf doomsday - today's and this week's Doomsday goals, streak and points" },
    run = function(self)
      printLines(self, ns.Describe.doomsday(ns.DoomsdayTracker.state(), function(t) return date("%H:%M", t) end))
    end },
  { name = "activity", help = { "/cf activity - show the dungeon, raid or battleground run in progress",
                                "/cf activity debug - print instance events for the activity feed (on/off)" },
    run = activityCommand },
  { name = "settings", help = { "/cf settings - open the settings" }, run = function() ns.Settings.open() end },
  { name = "setup", help = { "/cf setup - run the setup again" }, run = function() ns.Setup.open() end },
  { name = "ask", help = { "/cf ask <dungeon> - ask friends who's up for a dungeon now" }, run = askCommand },
  { name = "debugon", run = debugCommand },
  { name = "debugoff", run = debugCommand },
}

local commandsByName = {}
for _, c in ipairs(COMMANDS) do commandsByName[c.name] = c end

local function printHelp(self)
  self:Print("Commands:")
  for _, c in ipairs(COMMANDS) do
    for _, line in ipairs(c.help or {}) do self:Print("  " .. line) end
  end
end

function addon:OnSlashCommand(input)
  local command, argument = self:GetArgs(input, 2)
  command = command and command:lower() or ""
  local entry = commandsByName[command]
  if entry then entry.run(self, argument, input or "", command) else printHelp(self) end
end
