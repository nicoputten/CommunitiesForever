-- MainFrame: the main window. CF-39: the revamp's window shell (src/ui/kit) with tabs, title and footer.
-- Each tab is native kit frames in its own file: FriendsTab (CF-40), ActivityTab (CF-41), DungeonsTab
-- (CF-42); only the active one is shown. Renders Format models of the view model. Refreshes on change
-- messages while shown; no polling.
local ADDON_NAME, ns = ...

local MainFrame = {}

local REFRESH_DEBOUNCE = 0.2
local TABS = { { value = "friends", text = "Friends" }, { value = "activity", text = "Activity" }, -- CF-22
               { value = "dungeons", text = "Dungeons" } } -- CF-24: a badge counts planned runs
local FOOTER_HINT = "/cf to open \194\183 drag the title to move"

local GROUP_ASK_NOTE = "Group asks wait until combat ends" -- CF-42

local addonRef, events, frame, refreshDebounced
local tabs -- CF-39: the kit's tab row
local activeTab = "friends" -- CF-22: "friends", "activity" or "dungeons" (CF-24)
local view -- last view model, used by the selection callback
local showAllQuests = {} -- CF-19: tree path -> true when "Show all" is on (until /reload)
local updateFooter -- CF-41, defined below
-- CF-36: the smart filter of the Friends tab. Its text lasts while the window is open; savedGroups keeps the
-- list's unfolded groups from before filtering (filtering unfolds everything) to put back when cleared.
local filterText, savedGroups = "", nil
local FILTER_HINT = "e.g. tailoring 150, mage 20-30"

local function settings()
  return addonRef.db.global.settings
end

local function colorName(name, classFile, classID)
  classFile = ns.Classes.info(classFile, classID)
  if not classFile then return tostring(name) end
  return ns.Theme.rgbCode(ns.Kit.classColor(classFile)) .. tostring(name) .. "|r"
end

MainFrame.colorName = colorName -- CF-33: also used by the minimap tooltip

function MainFrame.render()
  if not frame then return end
  view = ns.ViewModel.build(addonRef)
  MainFrame.updateTabs()

  local empty = ns.Format.emptyState(view, {
    passive = ns.CommunitySelection.passive(),
    selected = ns.CommunitySelection.selected() ~= nil,
    active = ns.CommunitySelection.active() ~= nil,
    communityName = ns.CommunitySelection.name(),
    characterName = view.selfName,
  })
  updateFooter(empty)
  if activeTab == "activity" then
    ns.ActivityTab.render(view, empty)
    return
  end
  if activeTab == "dungeons" then
    ns.DungeonsTab.render(view, empty)
    return
  end
  ns.FriendsTab.render(view, empty)
end

-- CF-37: what a menu item does.
local function onMenuItem(item)
  if item.action == "whisper" then
    if not ns.ContextMenu.whisper(item.name) then addonRef:Print("Cannot open a whisper here.") end
  elseif item.action == "invite" then
    local online = item.battleTag and ns.Sync.online()[item.battleTag]
    if not ns.Party.invite(item.name, online and online.gameAccountID) then
      addonRef:Print("Could not invite " .. tostring(item.name) .. ".")
    end
  end
end

-- CF-37: right-clicking `target` opens the menu for a tree path (a string, or a function returning it when
-- the frame is reused for other rows). Hooked once per frame; OnMouseUp also sees right-clicks on frames
-- that only take left clicks. HookScript is verified on tree rows (V57).
function MainFrame.rightClickMenu(target, path)
  if not target or not target.HookScript then return end
  target.cfMenuPath = path
  if target.cfMenuHooked then return end
  target.cfMenuHooked = true
  target:HookScript("OnMouseUp", function(self, mouse)
    if mouse ~= "RightButton" or not view then return end
    local p = self.cfMenuPath
    if type(p) == "function" then p = p() end
    local model = ns.Format.contextMenu(view, p)
    if model then ns.ContextMenu.open(self, model, onMenuItem) end
  end)
end

-- Sets the filter text and redraws; the search box takes the text on render.
function MainFrame.setFilter(text)
  text = text or ""
  if text == filterText then return end
  local wasFiltering = filterText:match("%S") ~= nil
  filterText = text
  local filtering = filterText:match("%S") ~= nil
  local status = settings().tree
  if filtering and not wasFiltering then
    savedGroups = {}
    for k, v in pairs(status.groups or {}) do savedGroups[k] = v end
  elseif wasFiltering and not filtering and savedGroups then
    status.groups, savedGroups = savedGroups, nil
  end
  if frame and activeTab == "friends" and frame:IsShown() then MainFrame.render() end
end

function MainFrame.filterText()
  return filterText
end

-- CF-21: on a character outside the community, step-by-step instructions to join with the shared invite
-- link. Addons may not join themselves (V26); the link opens Blizzard's join window (V27). nil without a link.
local function joinInfo()
  if not (ns.CommunitySelection.selected() and not ns.CommunitySelection.active()) then return nil end
  local invite = ns.Invites.current()
  if not invite then return nil end
  local community = ns.CommunitySelection.name() or "the community"
  local posted = ns.Invites.linkPosted()
  return {
    title = string.format("How to join %s with %s", community, tostring(view.selfName or "this character")),
    lines = {
      string.format("%s1. Click \"Post invite link in chat\" below.%s", posted and ns.Theme.code("online") or "",
        posted and "|r" or ""),
      string.format("2. In your chat window, click the gold [Join %s] link.%s", community,
        posted and "  <- do this now" or ""),
      "3. In Blizzard's window that opens, click Join.",
      "This window then shows the community. If Blizzard says the link is invalid, ask "
        .. tostring(invite.setByName) .. " for a new one.",
    },
    button = posted and "Post the link again" or "Post invite link in chat",
    onClick = function() ns.Invites.postLink() end,
  }
end

-- CF-40: what the Friends tab needs from here.
local function friendsHelpers()
  return {
    settings = settings, classInfo = ns.Classes.info, rightClickMenu = MainFrame.rightClickMenu, menuItem = onMenuItem,
    filterText = MainFrame.filterText, setFilter = MainFrame.setFilter, render = MainFrame.render,
    showAllQuests = showAllQuests, joinInfo = joinInfo, filterHint = FILTER_HINT,
  }
end

local escapeReady -- CF-32: Esc handler set up (not possible in combat: retried on the next show)

-- CF-39: the window title shows the community; the status text who is online.
local function updateTitle()
  if not frame then return end
  frame.titleText:SetText(ns.CommunitySelection.name() or ADDON_NAME)
  local online = view and #ns.Format.onlineList(view, 1000).entries or 0
  frame.statusText:SetText(online > 0 and string.format("\226\151\143 %d online", online) or "")
end

-- The footer per tab: CF-40 the sync state, CF-41 who shares and how long the feed keeps, CF-42 the sync
-- state and when group asks wait.
function updateFooter(empty)
  if activeTab == "activity" then
    frame.footerText:SetText(ns.ActivityTab.NOTE)
    frame.footerRightText:SetText(string.format("Keeps %d days", ns.Feed.KEEP_DAYS))
    return
  end
  if activeTab == "dungeons" then
    frame.footerText:SetText(empty and "" or ns.Format.syncedText(view, GetServerTime()))
    frame.footerRightText:SetText(GROUP_ASK_NOTE)
    return
  end
  frame.footerText:SetText(activeTab == "friends" and not empty and ns.Format.friendsFooter(view, GetServerTime())
    or "")
  frame.footerRightText:SetText(FOOTER_HINT)
end

local function create()
  frame = ns.Kit.window({
    title = ns.CommunitySelection.name() or ADDON_NAME,
    subtitle = ADDON_NAME,
    status = settings().window, -- same keys as before (rule 8); reset once to the design size
    -- Closing only hides it. CF-36: the filter starts empty next time; CF-41: the chips at All.
    onClose = function()
      MainFrame.setFilter("")
      ns.ActivityTab.reset()
    end,
    onSettings = function() ns.Settings.open() end,
    onResize = function()
      if refreshDebounced then refreshDebounced() end -- CF-40: the tab follows the new size
    end,
  })
  tabs = ns.Kit.tabs(frame.tabBar, TABS, function(value) MainFrame.selectTab(value) end)

  ns.FriendsTab.create(frame.content, friendsHelpers()) -- CF-40
  ns.ActivityTab.create(frame.content, { settings = settings, render = MainFrame.render }) -- CF-41
  ns.DungeonsTab.create(frame.content, { settings = settings, render = MainFrame.render, -- CF-42
                                         print = function(text) addonRef:Print(text) end })
  MainFrame.selectTab(activeTab)
end

-- The active tab in pale gold with an underline. CF-24: the Dungeons badge counts runs planned in the next
-- days.
function MainFrame.updateTabs()
  if not frame then return end
  tabs.select(activeTab)
  tabs.setBadge("dungeons", #ns.Planner.planned())
  updateTitle()
end

-- Shows a tab ("friends", "activity" or "dungeons").
function MainFrame.selectTab(value)
  if not frame then return end
  activeTab = value
  MainFrame.updateTabs()
  if value == "friends" then ns.FriendsTab.show() else ns.FriendsTab.hide() end
  if value == "activity" then ns.ActivityTab.show() else ns.ActivityTab.hide() end
  if value == "dungeons" then ns.DungeonsTab.show() else ns.DungeonsTab.hide() end
  if view then MainFrame.render() end
end

-- CF-39: the kit window and its tabs (nil before the first open), for the specs and later stories.
function MainFrame.window() return frame end
function MainFrame.tabs() return tabs end

-- CF-43: Ambient effects changed: the title shimmer and the LEVEL UP shine follow.
function MainFrame.refreshAmbient()
  if frame and frame.shimmer then frame.shimmer:Refresh() end
  if MainFrame.isShown() then MainFrame.render() end
end

function MainFrame.isShown()
  return frame ~= nil and frame:IsShown()
end

function MainFrame.toggle()
  if MainFrame.isShown() then
    frame:Hide()
    return
  end
  if not frame then
    create()
  else
    frame:Show()
  end
  if not escapeReady then escapeReady = ns.Keys.closeOnEscape(frame, function() frame:Hide() end) end
  MainFrame.render()
end

-- Messages that change what the window shows.
local function refreshMessages()
  return {
    ns.SelfTracker.UPDATED,
    ns.MemberTracker.UPDATED,
    ns.PresenceTracker.UPDATED,
    ns.CommunitySelection.CHANGED,
    ns.CommunitySelection.PASSIVE_CHANGED,
    ns.Sync.PEOPLE_UPDATED,
    ns.Invites.CHANGED,
    ns.FeedTracker.CHANGED,
    ns.Planner.UPDATED, -- CF-24: calendar events and sign-ups for the Dungeons tab
    ns.GroupAsks.CHANGED, -- CF-27: your ask and its answers
    ns.Sync.PEERS_CHANGED, -- CF-28: community members coming online or leaving
  }
end

function MainFrame.start(addon)
  addonRef = addon
  frame, view = nil, nil
  filterText, savedGroups = "", nil
  escapeReady = false
  tabs = nil
  activeTab = "friends"
  ns.DungeonsTab.reset()
  ns.Kit.ambient = function() return settings().ambientEffects ~= false end -- CF-43
  refreshDebounced = ns.Timer.debounce(REFRESH_DEBOUNCE, function()
    if MainFrame.isShown() then MainFrame.render() end
  end)
  -- Own AceEvent object: AceEvent keeps one handler per object and message,
  -- and services already listen to some of these on the addon object.
  events = LibStub("AceEvent-3.0"):Embed({})
  for _, message in ipairs(refreshMessages()) do
    events:RegisterMessage(message, function() refreshDebounced() end)
  end
end

ns.MainFrame = MainFrame
return MainFrame
