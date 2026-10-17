-- luacheck config. Run: luacheck src tests
std = "lua51+wow"
max_line_length = 120
codes = true
self = false -- Ace callbacks and methods often ignore self

exclude_files = { "Libs/", ".lua/", "dist/" }

-- Globals the addon itself owns (CLAUDE.md rule 5).
local addonGlobals = {
  "CommunitiesForever",
  "CommunitiesForeverDB",
  "SlashCmdList",
}

-- WoW API used by adapters, services and UI. Add entries as stories need them;
-- unverified ones must also have an existence guard and a VERIFY.md entry.
stds.wow = {
  globals = addonGlobals,
  read_globals = {
    -- libraries
    "LibStub",
    -- C_ namespaces
    "C_AddOns", "C_BattleNet", "C_ChatInfo", "C_Club", "C_EventUtils", "C_Timer",
    -- client and unit info
    "GetBuildInfo", "GetServerTime", "GetTime", "GetRealmName", "GetNormalizedRealmName",
    "UnitGUID", "UnitName", "UnitLevel", "UnitClassBase", "UnitRace", "UnitFactionGroup",
    "GetProfessions", "GetProfessionInfo", "GetAverageItemLevel",
    "InCombatLockdown",
    -- Battle.net
    "BNGetInfo", "BNGetNumFriends", "BNSendGameData", "BNET_CLIENT_WOW",
    -- UI
    "CreateFrame", "UIParent", "GameTooltip", "TooltipDataProcessor", "C_CreatureInfo",
    "GameFontNormal", "GameFontHighlightSmall", "GameFontDisable",
    "ScrollUtil", "CreateScrollBoxListLinearView", "RAID_CLASS_COLORS",
    -- constants
    "WOW_PROJECT_ID", "Enum",
  },
}

-- Pure core: plain Lua 5.1 only. Any WoW global here is a lint error (CLAUDE.md rule 1).
files["src/core/"] = { std = "lua51" }

files["tests/"] = { std = "lua51+busted" }
-- The mock installs and removes WoW globals by design.
files["tests/mocks/"] = { std = "lua51", allow_defined_top = true, globals = { "_G" } }
