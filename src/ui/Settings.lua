-- Settings: AceConfig options, shown in the Blizzard settings panel and via /cf settings.
local ADDON_NAME, ns = ...

local Settings = {}

Settings.APP_NAME = ADDON_NAME

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
      inviteLink = {
        type = "input",
        order = 6,
        width = "full",
        name = "Community invite link",
        desc = "Paste an invite link for this community (Communities window, invite, link). On characters "
          .. "that are not in the community, friends see how to join with it. Leave empty to stop sharing it.",
        hidden = function() return not ns.Invites.canSet() end,
        get = function() return ns.Invites.ownText() end,
        set = function(_, value)
          local ok, message = ns.Invites.set(value)
          if not ok then ns:Print(message) end
        end,
      },
      notifications = {
        type = "toggle",
        order = 4,
        width = "full",
        name = "Login notifications",
        desc = "A chat line when a friend in the community comes online in Forever or switches character.",
        get = function() return ns.db.global.settings.notifications ~= false end,
        set = function(_, value) ns.db.global.settings.notifications = value end,
      },
      levelUps = {
        type = "toggle",
        order = 5,
        width = "full",
        name = "Announce friends' level-ups",
        desc = "A chat line when a character of a friend in the community reaches a new level "
          .. "(friends running CommunitiesForever).",
        get = function() return ns.db.global.settings.levelUps ~= false end,
        set = function(_, value) ns.db.global.settings.levelUps = value end,
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
