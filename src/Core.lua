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
end

local function SelectedClubName()
  local clubId = ns.CommunitySelection.selected()
  for _, club in ipairs(ns.CommunitySelection.list()) do
    if club.clubId == clubId then return club.name end
  end
  return clubId
end

function addon:OnSlashCommand(input)
  local command = self:GetArgs(input, 1)
  command = command and command:lower()

  if command == "version" then
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
    for _, line in ipairs(ns.Describe.members(ns.MemberTracker.members(), SelectedClubName())) do
      self:Print(line)
    end
  elseif command == "settings" then
    ns.Settings.open()
  else
    self:Print("Commands:")
    self:Print("  /cf version - show the addon version")
    self:Print("  /cf self - show your stored characters")
    self:Print("  /cf members - show members of the selected community")
    self:Print("  /cf settings - open the settings")
  end
end
