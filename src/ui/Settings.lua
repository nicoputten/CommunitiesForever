-- Settings: the options (one source of truth: every control in the settings window and the setup reads and
-- writes through these get/set functions, CF-26). CF-43: drawn by the addon's own settings window
-- (ui/SettingsWindow.lua), no longer by AceConfigDialog; Options › AddOns has a page that opens it. The table
-- keeps AceConfig's shape (type, name, desc, get, set, values) so it stays easy to read; `help` is the short
-- line under a switch.
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
        type = "color", order = 1, name = "Chat color",
        get = function() local c = ns.Chat.color(s()) return c.r, c.g, c.b end,
        set = function(_, r, g, b) ns.CommunityChat.setColor({ r = r, g = g, b = b }) end,
      },
      resetColor = {
        type = "execute", order = 2, name = "Reset",
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
        type = "execute", order = 5, width = "double", name = "Create a community chat tab",
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

-- The option with this key: top level or in the Community chat group (the settings window and the setup).
function Settings.option(key)
  local args = Settings.options().args
  return args[key] or args.chat.args[key]
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
        name = "When friends log in", -- CF-43: the design's words
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
      -- CF-44: the announcement at the top of the screen.
      levelUpToast = {
        type = "toggle",
        order = 5.1,
        width = "full",
        name = "Level-up announcement",
        help = "A note at the top of the screen when a friend levels up",
        get = function() return ns.db.global.settings.levelUpToast ~= false end,
        set = function(_, value) ns.db.global.settings.levelUpToast = value end,
      },
      shareActivity = {
        type = "toggle",
        order = 5.5,
        width = "full",
        name = "Share my activity",
        desc = "Friends see what you did in their Activity tab (levels, quests, professions). "
          .. "Off: only you see your activity.",
        help = "Levels, zones and dungeons you ran",
        get = function() return ns.FeedTracker.shared() end,
        set = function(_, value) ns.FeedTracker.setShared(value) end,
      },
      groupAsks = {
        type = "toggle",
        order = 5.6,
        width = "full",
        name = "Receive group asks",
        desc = "A chat line with a sound when a friend asks who's up for a dungeon you have a character for "
          .. "(with Join, Later and No to click).",
        help = "A chat line when a friend looks for a group",
        get = function() return ns.db.global.settings.groupAsks ~= false end,
        set = function(_, value) ns.db.global.settings.groupAsks = value end,
      },
      minimap = {
        type = "toggle",
        order = 3,
        width = "full",
        name = "Minimap button",
        get = function() return ns.Minimap.isShown() end,
        set = function(_, value) ns.Minimap.setShown(value) end,
      },
      -- CF-43: open the window a few seconds after logging in (not while the addon is passive).
      openOnLogin = {
        type = "toggle",
        order = 3.1,
        width = "full",
        name = "Open on login",
        get = function() return ns.db.global.settings.openOnLogin == true end,
        set = function(_, value) ns.db.global.settings.openOnLogin = value end,
      },
      -- CF-43: the title shimmer and the LEVEL UP shine.
      ambientEffects = {
        type = "toggle",
        order = 3.2,
        width = "full",
        name = "Ambient effects",
        help = "Title shimmer and level-up glow",
        get = function() return ns.db.global.settings.ambientEffects ~= false end,
        set = function(_, value)
          ns.db.global.settings.ambientEffects = value
          ns.MainFrame.refreshAmbient()
        end,
      },
    },
  }
  options.args.roles = Settings.rolesGroup()
  options.args.chat = Settings.chatGroup()
  return options
end

-- CF-43: the page under Options › AddOns: a line and a button that opens the settings window.
function Settings.register()
  local page = CreateFrame("Frame")
  local text = ns.Theme.text(page, "body", "text")
  text:SetPoint("TOPLEFT", 16, -16)
  text:SetText(ADDON_NAME .. " has its own settings window (also /cf settings).")
  local open = ns.Kit.button(page, "Open settings", function() Settings.open() end, "primary")
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
  Settings.page = page
  Settings.registered = ns.Panels.registerOptions(page, ADDON_NAME)
end

function Settings.open()
  ns.SettingsWindow.open()
end

ns.Settings = Settings
return Settings
