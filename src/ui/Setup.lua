-- Setup: the onboarding wizard and the Community tab prompt for other characters (CF-26), in the revamp's
-- look (CF-43; design docs/design/revamp-2026-10/settings-setup.html). Every switch here is the matching
-- settings option (get/set from Settings.options): the wizard only presents the settings. Which steps to
-- show comes from core/Onboarding.lua. Native kit dialogs, built once; each step is drawn from pools.
local ADDON_NAME, ns = ...

local Setup = {}
local Theme, Kit = ns.Theme, ns.Kit

Setup.LOGIN_DELAY = 5 -- seconds after login, so the community list and chat channels are there

local WIDTH, HEIGHT = 600, 460
local PAD = 24
local BODY_WIDTH = WIDTH - 2 * PAD

local addonRef
local wizard, prompt         -- kit dialogs, created once and reused
local wizardEscape           -- CF-32: Esc handler set up (not possible in combat: retried on the next open)
local steps, index = {}, 1
local leaveStep               -- saves what the current step holds (the name field) before moving on
local pools, bars, buttons, nameField, communitySelect
local checkboxes = {}         -- option name -> checkbox on the current step

-- The big line on top of each step.
local HEADLINES = {
  welcome = "Who is who in your community",
  community = "Pick your community",
  name = "How friends see you",
  chat = "Community chat",
  notifications = "Sharing and notifications",
  done = "All set",
}

-- The three tiles on the welcome step.
local FEATURES = {
  { "Friends", "Every friend's characters: class, level, gear, professions, talents." },
  { "Activity", "Who levelled, where they quested, what you ran together." },
  { "Dungeons", "Which dungeons fit, who can come, which quests you share." },
}

local function settings() return addonRef.db.global.settings end

local function selfGuid() return ns.SelfInfo.read().guid end

local function option(key) return ns.Settings.option(key) end

local function gold(text) return Theme.code("goldLight") .. text .. "|r" end

-- ===== Drawing helpers =====

local y -- where the next element of the step goes

local function text(content, role, colorName, gap)
  local holder = Kit.take(pools[role or "body"], wizard.body)
  holder:SetPoint("TOPLEFT", 0, -y)
  holder.text:SetWidth(BODY_WIDTH)
  holder.text:SetText(content)
  holder.text:SetTextColor(Theme.color(colorName or "textDim"))
  local height = holder.text.GetStringHeight and holder.text:GetStringHeight() or 0
  y = y + math.max(height, role == "name" and 30 or 16) + (gap or 10)
  return holder
end

-- A switch bound to a settings option, with one line on what it does.
local function toggle(key, help)
  local opt = option(key)
  local box = Kit.take(pools.checks, wizard.body)
  box:SetPoint("TOPLEFT", 0, -y)
  box:SetWidth(BODY_WIDTH)
  box.text:SetText(opt.name)
  box.help:SetText(help or opt.help or "")
  box:SetChecked(opt.get())
  box.onChange = function(value) opt.set({}, value) end
  checkboxes[opt.name] = box
  y = y + 40
  return box
end

-- ===== Steps =====

local render -- defined below

local STEP_BODIES = {}

function STEP_BODIES.welcome()
  text("Friends who run the addon share their characters with you, including alts outside the community. "
    .. "Everything stays inside your group.", "body", "textDim", 16)
  local w = math.floor((BODY_WIDTH - 20) / 3)
  for i, feature in ipairs(FEATURES) do
    local tile = Kit.take(pools.tiles, wizard.body)
    tile:SetPoint("TOPLEFT", (i - 1) * (w + 10), -y)
    tile:SetWidth(w)
    tile.title:SetText(feature[1])
    tile.text:SetWidth(w - 24)
    tile.text:SetText(feature[2])
  end
  y = y + 110
end

function STEP_BODIES.community()
  local opt = option("community")
  local values, order = opt.values(), opt.sorting()
  if #order == 0 then
    text("This character is not in a character community yet.")
    text("To join one, ask a friend in it for the invite link (Communities window, Invite, link). "
      .. "Friends who run CommunitiesForever can share it: on a character that is not a member, the "
      .. "window then shows the link to click.")
    text("Guilds and Battle.net communities are not supported. You can pick the community later in "
      .. "/cf settings.", "small", "faint")
    return
  end
  text("Pick the community whose members you want to see. It is the same on all your characters.")
  local list = {}
  for _, clubId in ipairs(order) do list[#list + 1] = { value = clubId, text = values[clubId] } end
  communitySelect:ClearAllPoints()
  communitySelect:SetPoint("TOPLEFT", 0, -y)
  communitySelect:SetChoices("Community", list, opt.get())
  communitySelect:Show()
  y = y + 38
  text("Only character communities are listed.", "small", "faint")
end

function STEP_BODIES.name()
  local opt = option("displayName")
  local own = addonRef.db.global.self
  text("How your friends see you in their window, tooltips and chat lines.")
  local current = ns.Linker.displayName(own.battleTag or "", own.displayName)
  nameField:ClearAllPoints()
  nameField:SetPoint("TOPLEFT", 0, -y)
  nameField:SetValue(current)
  nameField:Show()
  y = y + 38
  text("Plain text, up to 24 characters. Empty: the first part of your BattleTag.", "small", "faint")
  -- Saved when leaving the step; unchanged text keeps the stored value (no needless sync).
  leaveStep = function()
    local value = nameField:GetText() or ""
    if value ~= current then opt.set({}, value) end
  end
end

function STEP_BODIES.chat()
  local color = ns.Chat.color(settings())
  text("Community chat in its own color and its own chat tab, so you never miss it.")
  text(string.format("%s[%s] Alice Example: anyone up for Deadmines?|r", Theme.rgbCode(color.r, color.g, color.b),
    ns.CommunityChat.tabName()), "body", "text")
  if ns.CommunityChat.tab() then
    text("This character has a " .. ns.CommunityChat.tabName() .. " chat tab.", "body", "goldLight")
  else
    -- The Create button sits where Next is (see render), so clicking on through the wizard creates it.
    text(gold("Create chat tab") .. " makes a " .. ns.CommunityChat.tabName()
      .. " tab and goes on; Not now goes on without one.")
  end
  toggle("keepGeneral", "Off: with a Community tab, the community chat shows only there.")
  toggle("alert", "Chat tabs that show it flash (not the one you look at).")
  toggle("sound")
  text("Chat tabs are saved per character: your other characters ask once.", "small", "faint")
end

function STEP_BODIES.notifications()
  toggle("notifications", "A chat line when a friend comes online in Forever or switches character.")
  toggle("levelUps", "A chat line when a friend's character reaches a new level.")
  toggle("levelUpToast", "A note at the top of the screen when a friend levels up.") -- CF-44
  toggle("minimap", "Opens the window; you can always use /cf.")
end

function STEP_BODIES.done()
  text("Open CommunitiesForever with " .. gold("/cf") .. ", change these later with " .. gold("/cf settings")
    .. ", and run this setup again with " .. gold("/cf setup") .. ".")
  text("Friends need CommunitiesForever too, so you see their professions, talents, quests and activity "
    .. "(without it you see their community characters only).")
end

-- ===== Wizard =====

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

-- "Step 2 of 6 · Welcome → Community → ..." (the arrow needs the bundled font).
local function progressText()
  local titles = {}
  for i, step in ipairs(steps) do titles[i] = step.title end
  local arrow = Theme.bundledFonts() and " \226\134\146 " or " \194\183 "
  return ns.Onboarding.progress(index, #steps) .. " \194\183 " .. table.concat(titles, arrow)
end

-- The buttons at the bottom: Back on the left; on the right Skip setup and Next, Not now and Create chat
-- tab on the chat step without a tab, Finish on the last step.
local function layoutButtons(step)
  for _, b in pairs(buttons) do b:Hide() end
  local right
  local function place(b)
    b:Show()
    b:ClearAllPoints()
    if right then b:SetPoint("RIGHT", right, "LEFT", -8, 0) else b:SetPoint("BOTTOMRIGHT", -PAD, 16) end
    right = b
  end
  if step.id == "chat" and not ns.CommunityChat.tab() then
    place(buttons.create)
    place(buttons.notNow)
  elseif index < #steps then
    place(buttons.next)
    place(buttons.skip)
  else
    place(buttons.finish)
  end
  buttons.back:Show()
  buttons.back:SetEnabled(index > 1)
end

function render()
  for _, p in pairs(pools) do Kit.release(p) end
  checkboxes = {}
  nameField:Hide()
  communitySelect:Hide()
  local step = steps[index]
  wizard.titleText:SetText(step.title)
  for i, bar in ipairs(bars) do
    if i <= #steps then
      bar:Show()
      bar:SetColorTexture(Theme.color(i <= index and "gold" or "track"))
    else
      bar:Hide()
    end
  end
  wizard.progress:ClearAllPoints()
  wizard.progress:SetPoint("LEFT", bars[#steps] or bars[1], "RIGHT", 10, 0)
  wizard.progress:SetText(progressText())
  wizard.headline:SetText(HEADLINES[step.id] or step.title)
  y = 0
  STEP_BODIES[step.id]()
  layoutButtons(step)
end

local function tile(parent)
  local t = CreateFrame("Frame", nil, parent)
  t:SetHeight(100)
  local bg = t:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(Theme.color("white", 0.03))
  t.edges = Kit.edges(t, "divider")
  t.title = Theme.text(t, "group", "goldLight")
  t.title:SetPoint("TOPLEFT", 12, -12)
  t.text = Theme.text(t, "tiny", "textDim")
  t.text:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -6)
  t.text:SetJustifyH("LEFT")
  return t
end

local function check(parent)
  local c
  c = Kit.checkbox(parent, "", "", false, function(value) if c.onChange then c.onChange(value) end end)
  return c
end

local function createWizard()
  -- Closing with X, Skip setup and Finish all count as done: nothing in the setup is required.
  wizard = Kit.dialog({ title = "Welcome", width = WIDTH, height = HEIGHT, onClose = finish })
  wizard.footer:Hide() -- the buttons sit where the footer would be
  local content = wizard.content
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", wizard.titleBar, "BOTTOMLEFT")
  content:SetPoint("BOTTOMRIGHT", -1, 1)

  bars = {}
  for i = 1, 8 do
    local bar = content:CreateTexture(nil, "ARTWORK")
    bar:SetSize(22, 4)
    bar:SetPoint("TOPLEFT", PAD + (i - 1) * 28, -24)
    bars[i] = bar
  end
  wizard.progress = Theme.text(content, "small", "muted")
  wizard.headline = Theme.text(content, "name", "heading")
  wizard.headline:SetPoint("TOPLEFT", PAD, -44)
  wizard.body = CreateFrame("Frame", nil, content)
  wizard.body:SetPoint("TOPLEFT", PAD, -88)
  wizard.body:SetPoint("BOTTOMRIGHT", -PAD, 60)

  pools = {
    body = Kit.pool(Kit.textHolder("body")), small = Kit.pool(Kit.textHolder("small")),
    tiles = Kit.pool(tile), checks = Kit.pool(check),
  }
  nameField = Kit.input(wizard.body, { width = 280, maxLetters = 24 })
  communitySelect = Kit.select(wizard.body, function(clubId) option("community").set({}, clubId) end)
  communitySelect:SetWidth(280)

  buttons = {
    back = Kit.button(content, "Back", function() go(-1) end, "ghost"),
    skip = Kit.button(content, "Skip setup", function() wizard:Hide() end, "ghost"),
    next = Kit.button(content, "Next", function() go(1) end, "primary"),
    notNow = Kit.button(content, "Not now", function() go(1) end, "ghost"),
    create = Kit.button(content, "Create chat tab", function()
      ns.CommunityChat.createTab()
      go(1)
    end, "primary"),
    finish = Kit.button(content, "Finish", function() wizard:Hide() end, "primary"),
  }
  buttons.back:SetPoint("BOTTOMLEFT", PAD, 16)
end

-- Opens the wizard with these steps (default: all of them, as /cf setup does).
function Setup.open(list)
  if prompt and prompt:IsShown() then prompt:Hide() end
  steps = list or ns.Onboarding.steps()
  index = 1
  if not wizard then createWizard() end
  render()
  wizard:Show()
  if not wizardEscape then wizardEscape = ns.Keys.closeOnEscape(wizard, function() wizard:Hide() end) end
end

function Setup.isShown()
  return wizard ~= nil and wizard:IsShown()
end

-- ===== Community tab prompt (other characters) =====

-- One big Create button; closing the window (X) is the answer "no" (CF-26 feedback). Either way this
-- character is not asked again; /cf settings still has the button.
function Setup.openPrompt()
  if not prompt then
    prompt = Kit.dialog({ title = ADDON_NAME, width = 420, height = 200, onClose = function()
      local guid = selfGuid()
      if guid then ns.Onboarding.dontAsk(settings(), guid) end
    end })
    prompt.footer:Hide()
    local question = Theme.text(prompt.content, "group", "goldLight")
    question:SetPoint("TOPLEFT", 20, -18)
    question:SetText("Create a Community tab on this character too?")
    local help = Theme.text(prompt.content, "small", "textDim")
    help:SetPoint("TOPLEFT", question, "BOTTOMLEFT", 0, -8)
    help:SetWidth(380)
    help:SetJustifyH("LEFT")
    help:SetText("Chat tabs are saved per character. The tab shows only the community chat. Close this window "
      .. "if you don't want one.")
    prompt.create = Kit.button(prompt.content, "Yes, create a Community tab", function()
      ns.CommunityChat.createTab()
      prompt:Hide()
    end, "primary")
    prompt.create:SetPoint("BOTTOM", 0, 20)
    prompt.texts = { question, help }
  end
  prompt:Show()
end

function Setup.promptShown()
  return prompt ~= nil and prompt:IsShown()
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

-- After login: the setup or the prompt when due; else CF-43's Open on login (not while passive).
local function afterLogin()
  Setup.check()
  if Setup.isShown() or Setup.promptShown() then return end
  if settings().openOnLogin and not ns.CommunitySelection.passive() and not ns.MainFrame.isShown() then
    ns.MainFrame.toggle()
  end
end

function Setup.start(addon)
  addonRef = addon
  C_Timer.NewTimer(Setup.LOGIN_DELAY, afterLogin)
  -- Joined a community while playing: the setup opens right away (unless it is open already).
  -- Own AceEvent object: AceEvent keeps one handler per object and message.
  LibStub("AceEvent-3.0"):Embed({}):RegisterMessage(ns.CommunitySelection.PASSIVE_CHANGED, function(_, passive)
    if not passive and not Setup.isShown() then Setup.check() end
  end)
end

-- For the specs: the wizard and prompt frames, the texts on the current step, its buttons and switches.
function Setup.wizard() return wizard end
function Setup.prompt() return prompt end

function Setup.texts()
  local out = { wizard.titleText:GetText(), wizard.progress:GetText(), wizard.headline:GetText() }
  for _, name in ipairs({ "body", "small" }) do
    for i = 1, pools[name].used do out[#out + 1] = pools[name].items[i].text:GetText() end
  end
  for i = 1, pools.tiles.used do
    out[#out + 1] = pools.tiles.items[i].title:GetText()
    out[#out + 1] = pools.tiles.items[i].text:GetText()
  end
  return out
end

function Setup.buttons()
  local out = {}
  for _, b in pairs(buttons or {}) do
    if b:IsShown() then out[b.label:GetText()] = b end
  end
  return out
end

function Setup.checkbox(name) return checkboxes[name] end
function Setup.nameField() return nameField end
function Setup.communitySelect() return communitySelect end

ns.Setup = Setup
return Setup
