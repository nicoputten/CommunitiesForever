-- Core: AceAddon init and wiring. The private addon table is the addon object.
local ADDON_NAME, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(ns, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
CommunitiesForever = addon

local function GetVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
  end
  return "unknown"
end

function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("CommunitiesForeverDB", ns.Store.defaults(), true)
  ns.Store.init(self.db.global)
  ns.Settings.register()
  self:RegisterChatCommand("cf", "OnSlashCommand")
end

function addon:OnEnable()
  ns.SelfInfo.watch(self)
  ns.SelfTracker.start(self)
  ns.Community.watch(self)
  ns.CommunitySelection.start(self)
  ns.MemberTracker.start(self)
  ns.Presence.watch(self)
  ns.PresenceTracker.start(self)
  ns.MainFrame.start(self)
  ns.Minimap.start(self)
end

local function SelectedCommunityName()
  local clubId = ns.CommunitySelection.selected()
  for _, club in ipairs(ns.CommunitySelection.list()) do
    if club.clubId == clubId then return club.name end
  end
  return clubId
end

function addon:OnSlashCommand(input)
  local command = self:GetArgs(input, 1)
  command = command and command:lower()

  if command == nil then
    ns.MainFrame.toggle()
  elseif command == "version" then
    self:Print("Version " .. GetVersion())
  elseif command == "self" then
    for _, line in ipairs(ns.Describe.selfRecord(self.db.global.self, GetServerTime())) do
      self:Print(line)
    end
  elseif command == "members" then
    if not ns.CommunitySelection.selected() then
      self:Print("No community selected. Select one with /cf settings.")
      return
    end
    local lines = ns.Describe.members(ns.MemberTracker.members(), SelectedCommunityName(),
      ns.MemberTracker.changedAt(), GetServerTime())
    for _, line in ipairs(lines) do
      self:Print(line)
    end
  elseif command == "people" then
    if not ns.CommunitySelection.selected() then
      self:Print("No community selected. Select one with /cf settings.")
      return
    end
    for _, line in ipairs(ns.Describe.view(ns.ViewModel.build(self), GetServerTime())) do
      self:Print(line)
    end
  elseif command == "friends" then
    local lines = ns.Describe.friends(ns.PresenceTracker.friends(), ns.PresenceTracker.online(),
      self.db.global.presence, GetServerTime())
    for _, line in ipairs(lines) do
      self:Print(line)
    end
  elseif command == "settings" then
    ns.Settings.open()
  else
    self:Print("Commands:")
    self:Print("  /cf - open or close the window")
    self:Print("  /cf version - show the addon version")
    self:Print("  /cf self - show your stored characters")
    self:Print("  /cf members - show members of the selected community")
    self:Print("  /cf friends - show Battle.net friends in Forever")
    self:Print("  /cf people - show who owns which community character")
    self:Print("  /cf settings - open the settings")
  end
end
