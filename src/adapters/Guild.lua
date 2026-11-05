-- Guild: the WoW calls behind automatic guild invites (CF-84). Thin, guarded wrappers; the rules are in
-- core/GuildInvite.lua and services/GuildInvites.lua. Unverified on Forever (VERIFY.md V127 to V132):
-- `GUILD_INVITE_REQUEST` and its arguments, addon messages on "GUILD", `ERR_GUILD_INVITE_S`; the name forms (V131)
-- and the refusal texts (V132).
-- CF-87: no guild invite or accept from addon code, in any form: the invite functions (V126), a secure /ginvite
-- macro button (V134) and /ginvite in a chat input the addon filled (V135) are all refused on Forever
-- (API-FINDINGS.md "Guild invites"). The member copies /ginvite from ui/GuildInvitePopup.lua into chat by hand; the
-- alt clicks Blizzard's Accept. Nothing here opens or fills the chat input.
local ADDON_NAME, ns = ...

local Guild = {}

-- Internal messages.
-- (text, senderName, rawSender): senderName without "-Realm" (as the community lists names), rawSender exactly as
-- the game reported it, used as it is to whisper back and to invite (names have a space: never built, V131).
Guild.WHISPER_RECEIVED = "CF_GUILD_WHISPER_RECEIVED"
Guild.GUILD_RECEIVED = "CF_GUILD_CHANNEL_RECEIVED"   -- (text, senderName, rawSender) on the guild channel
Guild.INVITED = "CF_GUILD_INVITED"                   -- (inviterName, guildName): GUILD_INVITE_REQUEST
Guild.BLOCKED = "CF_GUILD_BLOCKED"                   -- (functionName): the game blocked one of our calls
Guild.INVITE_SENT = "CF_GUILD_INVITE_SENT"           -- (name): "You have invited <name> to join your guild."
Guild.INVITE_FAILED = "CF_GUILD_INVITE_FAILED"       -- (kind, name or nil): the game refused an invite (V132)

-- The game's messages when a guild invite fails, by kind (core/GuildInvite.inviteError). Read at the moment of use;
-- each one guarded (V132): missing ones are simply not recognised.
local function inviteErrorFormats()
  local formats = {}
  local function add(kind, value) if type(value) == "string" and value ~= "" then formats[kind] = value end end
  add("rights", ERR_GUILD_PERMISSIONS)
  add("faction", ERR_GUILD_NOT_ALLIED)
  add("member", ERR_ALREADY_IN_GUILD_S)
  add("invited", ERR_ALREADY_INVITED_TO_GUILD_S)
  add("notfound", ERR_GUILD_PLAYER_NOT_FOUND_S)
  return formats
end

-- C_ChatInfo.RegisterAddonMessagePrefix is verified (API-FINDINGS.md).
function Guild.registerPrefix(prefix)
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
  end
end

-- An addon whisper (verified, V50) through Transport, whose chat filter hides "No player named ... is currently
-- playing" for names whispered seconds ago and reports them as Transport.WHISPER_FAILED (VERIFY.md V53, V129).
function Guild.whisper(name, prefix, text)
  ns.Transport.whisper(name, prefix, text)
end

-- One addon message to every guild member online running the addon (V128). Returns the send result (0: sent) or nil
-- when the call is missing or failed.
function Guild.send(prefix, text)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return nil end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, text, "GUILD")
  return ok and (result or 0) or nil
end

-- This character's faction and realm, from the same verified calls the snapshot uses (UnitFactionGroup, GetRealmName):
-- members store the guild's, an alt compares with its own (core/GuildInvite.placeMismatch).
function Guild.place()
  return { faction = UnitFactionGroup and (UnitFactionGroup("player")) or nil, realm = GetRealmName and GetRealmName() }
end

-- CF-88: what decides whether the invite window's copy box may take the keyboard focus (core/GuildInvite.canFocus).
-- own: the copy box (focus on it is not "other").
-- InCombatLockdown is verified (V24); GetUnitSpeed, ChatEdit_GetActiveWindow (or ChatFrameUtil.GetActiveWindow) and
-- GetCurrentKeyBoardFocus are unverified (V136): a missing one counts as "no".
function Guild.focusContext(own)
  local active = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
  local chat = active and select(2, pcall(active))
  local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  return {
    combat = InCombatLockdown and InCombatLockdown() or false,
    speed = GetUnitSpeed and GetUnitSpeed("player") or 0,
    chatOpen = chat and true or false,
    otherFocus = (focus and focus ~= own) and true or false,
  }
end

-- CF-88: Ctrl held (IsControlKeyDown, unverified, V136).
function Guild.controlDown()
  return IsControlKeyDown and IsControlKeyDown() and true or false
end

-- CF-88: calls fn(text) after the text of a chat input changes (the Ctrl+V step). A post-hook on the chat frames'
-- edit boxes (ChatFrame<i>EditBox, HookScript "OnTextChanged"); it only reads the text, never sets it. Unverified
-- whether the hook taints the send (V137): the window can switch it off. Hooks once; returns how many boxes.
local textWatchers, hooked = {}, false
function Guild.watchChatInput(fn)
  textWatchers[#textWatchers + 1] = fn
  if hooked then return 0 end
  hooked = true
  local count = 0
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local box = _G["ChatFrame" .. i .. "EditBox"]
    if box and box.HookScript and box.GetText then
      box:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        for _, watcher in ipairs(textWatchers) do watcher(text) end
      end)
      count = count + 1
    end
  end
  return count
end

function Guild.watch(addon, prefix)
  local events = LibStub("AceEvent-3.0"):Embed({})
  -- CHAT_MSG_ADDON(prefix, text, channel, sender) is verified (V50); the "GUILD" channel is V128.
  ns.Events.register(events, "CHAT_MSG_ADDON", function(_, messagePrefix, text, channel, sender)
    if messagePrefix ~= prefix then return end
    if channel == "WHISPER" then
      addon:SendMessage(Guild.WHISPER_RECEIVED, text, ns.Transport.shortName(sender), sender)
    elseif channel == "GUILD" then
      addon:SendMessage(Guild.GUILD_RECEIVED, text, ns.Transport.shortName(sender), sender)
    end
  end)
  -- GUILD_INVITE_REQUEST(inviter, guildName, ...) as on Retail (V127).
  ns.Events.register(events, "GUILD_INVITE_REQUEST", function(_, inviter, guildName)
    addon:SendMessage(Guild.INVITED, inviter, guildName)
  end)
  -- A protected call from our code: ADDON_ACTION_BLOCKED / _FORBIDDEN(addonName, function). Logged in /cf sync
  -- debug only; nothing of ours should cause it (CF-87).
  for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    ns.Events.register(events, event, function(_, addonName, functionName)
      if addonName == ADDON_NAME then addon:SendMessage(Guild.BLOCKED, functionName) end
    end)
  end
  -- "You have invited <name> to join your guild." (ERR_GUILD_INVITE_S): the invite went out. Or one of the game's
  -- refusals (no rights, other faction, already in a guild, ...), as a system line or a UI error (V132).
  local function onText(message)
    if type(message) ~= "string" then return end
    local args = type(ERR_GUILD_INVITE_S) == "string" and ns.GameText.parse(message, ERR_GUILD_INVITE_S)
    if args and args[1] then
      addon:SendMessage(Guild.INVITE_SENT, args[1])
      return
    end
    local kind, name = ns.GuildInvite.inviteError(message, inviteErrorFormats())
    if kind then addon:SendMessage(Guild.INVITE_FAILED, kind, name) end
  end
  ns.Events.register(events, "CHAT_MSG_SYSTEM", function(_, message) onText(message) end)
  ns.Events.register(events, "UI_ERROR_MESSAGE", function(_, _, message) onText(message) end)
end

ns.Guild = Guild
return Guild
