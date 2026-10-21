-- Setup: the onboarding wizard and the Community tab prompt for other characters (CF-26).
-- Every switch here is the matching /cf settings option (get/set from Settings.options): the wizard
-- only presents the settings. Which steps to show comes from core/Onboarding.lua.
local ADDON_NAME, ns = ...

local Setup = {}

Setup.LOGIN_DELAY = 5 -- seconds after login, so the community list and chat channels are there

local GREY, GOLD = "|cffa0a0a0", "|cffffd100"
local DOT = "\194\183"

local addonRef
local wizard, prompt         -- AceGUI frames, created once and reused
local steps, index = {}, 1
local leaveStep               -- saves what the current step holds (the name field) before moving on

local function createWidget(widgetType)
  return LibStub("AceGUI-3.0"):Create(widgetType)
end

local function settings() return addonRef.db.global.settings end

local function selfGuid() return ns.SelfInfo.read().guid end

-- The /cf settings option with this key (top level or in the Community chat group).
local function option(key)
  local args = ns.Settings.options().args
  return args[key] or args.chat.args[key]
end

local function label(parent, text, font)
  local w = createWidget("Label")
  w:SetText(text)
  w:SetFullWidth(true)
  w:SetFontObject(font or GameFontHighlight)
  parent:AddChild(w)
  return w
end

local function spacer(parent)
  label(parent, " ", GameFontHighlightSmall)
end

-- A checkbox bound to a settings option, with one grey line on what it does.
local function toggle(parent, key, line)
  local opt = option(key)
  local box = createWidget("CheckBox")
  box:SetLabel(opt.name)
  box:SetValue(opt.get() and true or false)
  box:SetFullWidth(true)
  box:SetCallback("OnValueChanged", function(_, _, value) opt.set({}, value) end)
  parent:AddChild(box)
  if line then label(parent, "      " .. GREY .. line .. "|r", GameFontHighlightSmall) end
  return box
end

local function button(parent, text, relativeWidth, onClick)
  local b = createWidget("Button")
  b:SetText(text)
  b:SetRelativeWidth(relativeWidth)
  b:SetCallback("OnClick", onClick)
  parent:AddChild(b)
  return b
end

local function hex(color)
  return string.format("%02x%02x%02x", math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
    math.floor(color.b * 255 + 0.5))
end

-- ===== Steps =====

local render -- defined below

local STEP_BODIES = {}

function STEP_BODIES.welcome(body)
  label(body, "CommunitiesForever shows who is who in your community: which characters belong to which "
    .. "friend, with class, level, item level, professions and talents.")
  spacer(body)
  label(body, "Friends who run the addon too sync their characters with you over Battle.net, also the "
    .. "alts that are not in the community.")
  spacer(body)
  label(body, "You also see what your friends did lately (Activity) and which quests you share.")
end

function STEP_BODIES.community(body)
  local opt = option("community")
  local values, order = opt.values(), opt.sorting()
  if #order == 0 then
    label(body, "This character is not in a character community yet.")
    spacer(body)
    label(body, "To join one, ask a friend in it for the invite link (Communities window, Invite, link). "
      .. "Friends who run CommunitiesForever can share it: on a character that is not a member, the "
      .. "window then shows the link to click.")
    spacer(body)
    label(body, GREY .. "Guilds and Battle.net communities are not supported. You can pick the community "
      .. "later in /cf settings.|r", GameFontHighlightSmall)
    return
  end
  label(body, "Pick the community whose members you want to see. It is the same on all your characters.")
  spacer(body)
  local dropdown = createWidget("Dropdown")
  dropdown:SetLabel("Community")
  dropdown:SetList(values, order)
  dropdown:SetValue(opt.get())
  dropdown:SetFullWidth(true)
  dropdown:SetCallback("OnValueChanged", function(_, _, clubId) opt.set({}, clubId) end)
  body:AddChild(dropdown)
  spacer(body)
  label(body, GREY .. "Only character communities are listed.|r", GameFontHighlightSmall)
end

function STEP_BODIES.name(body)
  local opt = option("displayName")
  local own = addonRef.db.global.self
  label(body, "How your friends see you in their window, tooltips and chat lines.")
  spacer(body)
  local current = ns.Linker.displayName(own.battleTag or "", own.displayName)
  local edit = createWidget("EditBox")
  edit:SetLabel("Display name")
  edit:SetText(current)
  edit:SetMaxLetters(24)
  edit:SetFullWidth(true)
  edit:DisableButton(true)
  body:AddChild(edit)
  spacer(body)
  label(body, GREY .. "Plain text, up to 24 characters. Empty: the first part of your BattleTag.|r",
    GameFontHighlightSmall)
  -- Saved when leaving the step; unchanged text keeps the stored value (no needless sync).
  leaveStep = function()
    local text = edit.GetText and edit:GetText() or edit.text
    if text ~= current then opt.set({}, text) end
  end
end

function STEP_BODIES.chat(body)
  local color = ns.Chat.color(settings())
  label(body, "Community chat in its own color and its own chat tab, so you never miss it.")
  spacer(body)
  label(body, string.format("|cff%s[%s] Alice Example: anyone up for Deadmines?|r", hex(color),
    ns.CommunityChat.tabName()))
  spacer(body)
  if ns.CommunityChat.tab() then
    label(body, GOLD .. "This character has a " .. ns.CommunityChat.tabName() .. " chat tab.|r")
  else
    -- The Create button sits where Next is (see render), so clicking on through the wizard creates it.
    label(body, GOLD .. "Create chat tab|r makes a " .. ns.CommunityChat.tabName()
      .. " tab and goes on; Not now goes on without one.")
  end
  spacer(body)
  toggle(body, "keepGeneral")
  toggle(body, "alert")
  toggle(body, "sound")
  label(body, GREY .. "Chat tabs are saved per character: your other characters ask once.|r",
    GameFontHighlightSmall)
end

function STEP_BODIES.notifications(body)
  toggle(body, "notifications", "A chat line when a friend comes online in Forever or switches character.")
  toggle(body, "levelUps", "A chat line when a friend's character reaches a new level.")
  toggle(body, "shareActivity", "Friends see your levels, quests, professions and dungeons in Activity.")
  toggle(body, "minimap", "Opens the window; you can always use /cf.")
end

function STEP_BODIES.done(body)
  label(body, "All set. Open CommunitiesForever with " .. GOLD .. "/cf|r, change these later with "
    .. GOLD .. "/cf settings|r, and run this setup again with " .. GOLD .. "/cf setup|r.")
  spacer(body)
  label(body, "Friends need CommunitiesForever too, so you see their professions, talents, quests and "
    .. "activity (without it you see their community characters only).")
end

-- ===== Wizard =====

local function progress()
  local dots = {}
  for i = 1, #steps do dots[i] = (i == index and GOLD or GREY) .. DOT .. "|r" end
  return table.concat(dots, " ") .. "   " .. GREY .. ns.Onboarding.progress(index, #steps) .. "|r"
end

local function leave()
  if leaveStep then leaveStep() end
  leaveStep = nil
end

local function finish()
  leave()
  ns.Onboarding.finish(settings(), selfGuid())
end

local function go(delta)
  leave()
  index = math.max(1, math.min(#steps, index + delta))
  render()
end

function render()
  wizard:ReleaseChildren()
  local step = steps[index]
  label(wizard, progress(), GameFontNormalHuge)
  label(wizard, step.title, GameFontNormalLarge)

  local body = createWidget("SimpleGroup")
  body:SetFullWidth(true)
  body:SetHeight(230)
  body.noAutoHeight = true -- AceGUI SimpleGroup: keep the height, so the buttons stay in place
  body:SetLayout("List")
  wizard:AddChild(body)
  STEP_BODIES[step.id](body)

  local row = createWidget("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")
  wizard:AddChild(row)
  local back = button(row, "Back", 0.33, function() go(-1) end)
  back:SetDisabled(index == 1)
  if step.id == "chat" and not ns.CommunityChat.tab() then
    button(row, "Not now", 0.33, function() go(1) end)
    button(row, "Create chat tab", 0.33, function()
      ns.CommunityChat.createTab()
      go(1)
    end)
  elseif index < #steps then
    button(row, "Skip", 0.33, function() wizard:Hide() end)
    button(row, "Next", 0.33, function() go(1) end)
  else
    local gap = createWidget("Label")
    gap:SetText(" ")
    gap:SetRelativeWidth(0.33)
    row:AddChild(gap)
    button(row, "Finish", 0.33, function() wizard:Hide() end)
  end
end

local function createWizard()
  wizard = createWidget("Frame")
  wizard:SetTitle(ADDON_NAME .. " setup")
  wizard:SetWidth(440)
  wizard:SetHeight(400)
  wizard:SetLayout("List")
  if wizard.statustext and wizard.statustext.GetParent then wizard.statustext:GetParent():Hide() end
  -- Closing with X, Skip and Finish all count as done: nothing in the setup is required.
  wizard:SetCallback("OnClose", finish)
end

-- Opens the wizard with these steps (default: all of them, as /cf setup does).
function Setup.open(list)
  if prompt and prompt.frame:IsShown() then prompt:Hide() end
  steps = list or ns.Onboarding.steps()
  index = 1
  if not wizard then createWizard() end
  render()
  wizard:Show()
end

function Setup.isShown()
  return wizard ~= nil and wizard.frame:IsShown()
end

-- ===== Community tab prompt (other characters) =====

-- One big Create button; closing the window (X) is the answer "no" (CF-26 feedback). Either way this
-- character is not asked again; /cf settings still has the button.
function Setup.openPrompt()
  if not prompt then
    prompt = createWidget("Frame")
    prompt:SetTitle(ADDON_NAME)
    prompt:SetWidth(420)
    prompt:SetHeight(190)
    prompt:SetLayout("List")
    if prompt.statustext and prompt.statustext.GetParent then prompt.statustext:GetParent():Hide() end
    prompt:SetCallback("OnClose", function()
      local guid = selfGuid()
      if guid then ns.Onboarding.dontAsk(settings(), guid) end
    end)
  end
  prompt:ReleaseChildren()
  label(prompt, "Create a Community tab on this character too?", GameFontNormalLarge)
  label(prompt, GREY .. "Chat tabs are saved per character. The tab shows only the community chat. "
    .. "Close this window if you don't want one.|r", GameFontHighlightSmall)
  spacer(prompt)
  local create = createWidget("Button")
  create:SetText("Yes, create a Community tab")
  create:SetFullWidth(true)
  create:SetHeight(32)
  create:SetCallback("OnClick", function()
    ns.CommunityChat.createTab()
    prompt:Hide()
  end)
  prompt:AddChild(create)
  prompt:Show()
end

function Setup.promptShown()
  return prompt ~= nil and prompt.frame:IsShown()
end

-- ===== Login =====

-- What the current character should see now (see Onboarding.plan).
function Setup.plan()
  if ns.CommunitySelection.passive() then return nil end -- no community yet: nothing to set up
  local guid = selfGuid()
  return ns.Onboarding.plan(settings(), {
    guid = guid,
    hasTab = (guid and settings().chatTab and settings().chatTab[guid]) or ns.CommunityChat.tab() ~= nil,
    inCommunity = ns.CommunitySelection.active() and true or false,
  })
end

function Setup.check()
  local plan = Setup.plan()
  if not plan then return end
  if plan.kind == "wizard" then
    Setup.open(plan.steps)
  elseif plan.kind == "chatPrompt" then
    Setup.openPrompt()
  end
end

function Setup.start(addon)
  addonRef = addon
  C_Timer.NewTimer(Setup.LOGIN_DELAY, Setup.check)
  -- Joined a community while playing: the setup opens right away (unless it is open already).
  -- Own AceEvent object: AceEvent keeps one handler per object and message.
  LibStub("AceEvent-3.0"):Embed({}):RegisterMessage(ns.CommunitySelection.PASSIVE_CHANGED, function(_, passive)
    if not passive and not Setup.isShown() then Setup.check() end
  end)
end

ns.Setup = Setup
return Setup
