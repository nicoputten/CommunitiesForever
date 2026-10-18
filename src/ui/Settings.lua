-- Settings: AceConfig options, shown in the Blizzard settings panel and via /cf settings.
local ADDON_NAME, ns = ...

local Settings = {}

Settings.APP_NAME = ADDON_NAME

-- CF-18: "Role" per own character: Auto (guessed from talents) or Tank / Healer / DPS.
function Settings.rolesGroup()
  local group = { type = "group", inline = true, order = 10, name = "Roles of your characters", args = {} }
  local chars = {}
  for guid, char in pairs(ns.db.global.self.chars) do
    chars[#chars + 1] = { guid = guid, char = char }
  end
  table.sort(chars, function(a, b) return tostring(a.char.name) < tostring(b.char.name) end)
  for i, entry in ipairs(chars) do
    local char = entry.char
    local auto = char.autoRole and ns.Talents.ROLE_NAMES[char.autoRole] or "no talents yet"
    group.args["role" .. i] = {
      type = "select",
      order = i,
      name = tostring(char.name),
      values = { auto = "Auto (" .. auto .. ")", tank = "Tank", heal = "Healer", dps = "DPS" },
      sorting = { "auto", "tank", "heal", "dps" },
      get = function() return char.roleOverride or "auto" end,
      set = function(_, value)
        ns.SelfTracker.setRoleOverride(ns, entry.guid, value ~= "auto" and value or nil)
      end,
    }
  end
  if #chars == 0 then
    group.args.none = { type = "description", name = "No characters stored yet." }
  end
  return group
end

-- CF-25: community chat. The color is always applied; the rest are switches and the tab button.
function Settings.chatGroup()
  local s = function() return ns.db.global.settings end
  return {
    type = "group", inline = true, order = 9, name = "Community chat",
    args = {
      info = { type = "description", order = 0, fontSize = "medium",
               name = "Make the community chat easy to spot in your chat windows." },
      color = {
        type = "color", order = 1, name = "Community chat color",
        get = function() local c = ns.Chat.color(s()) return c.r, c.g, c.b end,
        set = function(_, r, g, b) ns.CommunityChat.setColor({ r = r, g = g, b = b }) end,
      },
      resetColor = {
        type = "execute", order = 2, name = "Default purple",
        func = function() ns.CommunityChat.setColor(nil) end,
      },
      alert = {
        type = "toggle", order = 3, width = "full", name = "Flash the chat tab on new messages",
        desc = "When someone else writes in the community, chat tabs that show it flash (not the one you look at).",
        get = function() return s().chatAlert ~= false end,
        set = function(_, value) s().chatAlert = value end,
      },
      sound = {
        type = "toggle", order = 4, width = "full", name = "Play a sound on new messages",
        get = function() return s().chatSound == true end,
        set = function(_, value) s().chatSound = value end,
      },
      createTab = {
        type = "execute", order = 5, width = "double", name = "Create a Community tab",
        desc = "Opens a chat tab that shows only the community chat. Chat tabs are saved per character.",
        func = function() ns.CommunityChat.createTab() end,
      },
      keepGeneral = {
        type = "toggle", order = 6, width = "full", name = "Keep community messages in General too",
        desc = "Off: with a Community tab, the community chat shows only there.",
        get = function() return s().chatKeepGeneral ~= false end,
        set = function(_, value) ns.CommunityChat.setKeepGeneral(value) end,
      },
    },
  }
end

-- Options table. Data comes from services only.
function Settings.options()
  local options = {
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
      displayName = {
        type = "input",
        order = 0,
        width = "double",
        name = "Display name",
        desc = "How your friends see you in their window, tooltips and chat lines. Plain text, up to 24 characters. "
          .. "Leave empty to use the first part of your BattleTag.",
        get = function() return ns.db.global.self.displayName or "" end,
        set = function(_, value) ns.SelfTracker.setDisplayName(ns, value) end,
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
      shareActivity = {
        type = "toggle",
        order = 5.5,
        width = "full",
        name = "Share my activity",
        desc = "Friends see what you did in their Activity tab (levels, quests, professions). "
          .. "Off: only you see your activity.",
        get = function() return ns.FeedTracker.shared() end,
        set = function(_, value) ns.FeedTracker.setShared(value) end,
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
  options.args.roles = Settings.rolesGroup()
  options.args.chat = Settings.chatGroup()
  return options
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
