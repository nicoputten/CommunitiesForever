-- Settings: AceConfig options, shown in the Blizzard settings panel and via /cf settings.
local ADDON_NAME, ns = ...

local Settings = {}

Settings.APP_NAME = ADDON_NAME

-- ns is the addon object (Core.lua), so its saved settings are here.
local function addonSettings()
  return ns.db.global.settings
end

-- Options table. Data comes from services only.
function Settings.options()
  return {
    type = "group",
    name = ADDON_NAME,
    args = {
      community = {
        type = "select",
        order = 1,
        width = "double",
        name = "Community",
        desc = "The character community whose members are shown.",
        values = function()
          local values = {}
          for _, club in ipairs(ns.CommunitySelection.list()) do
            values[club.clubId] = club.name
          end
          return values
        end,
        sorting = function()
          local order = {}
          for _, club in ipairs(ns.CommunitySelection.list()) do
            order[#order + 1] = club.clubId
          end
          return order
        end,
        get = function() return ns.CommunitySelection.selected() end,
        set = function(_, clubId) ns.CommunitySelection.select(clubId) end,
      },
      communityHelp = {
        type = "description",
        order = 2,
        name = "Only character communities are listed. Guilds and Battle.net communities are not supported.",
      },
      shareAlts = {
        type = "toggle",
        order = 4,
        width = "full",
        name = "Share alts outside the community",
        desc = "Friends also see your characters that are not in the selected community. "
          .. "They are only shown under you when at least one of your characters is in the community.",
        get = function() return addonSettings().shareAlts ~= false end,
        set = function(_, value)
          addonSettings().shareAlts = value
          ns.Sync.settingsChanged()
        end,
      },
      minimap = {
        type = "toggle",
        order = 3,
        width = "full",
        name = "Show minimap button",
        get = function() return ns.Minimap.isShown() end,
        set = function(_, value) ns.Minimap.setShown(value) end,
      },
    },
  }
end

function Settings.register()
  LibStub("AceConfig-3.0"):RegisterOptionsTable(Settings.APP_NAME, Settings.options)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(Settings.APP_NAME, ADDON_NAME)
end

function Settings.open()
  LibStub("AceConfigDialog-3.0"):Open(Settings.APP_NAME)
end

ns.Settings = Settings
return Settings
