-- Core: AceAddon init and wiring. The private addon table is the addon object.
local ADDON_NAME, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(ns, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
CommunitiesForever = addon

-- C_AddOns.GetAddOnMetadata is unverified on Forever (VERIFY.md V10).
local function GetVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
  end
  return "unknown"
end

function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("CommunitiesForeverDB", ns.Store.defaults(), true)
  ns.Store.init(self.db.global)
  self:RegisterChatCommand("cf", "OnSlashCommand")
end

function addon:OnSlashCommand(input)
  local command = self:GetArgs(input, 1)
  command = command and command:lower()

  if command == "version" then
    self:Print("Version " .. GetVersion())
  else
    self:Print("Commands:")
    self:Print("  /cf version - show the addon version")
  end
end
