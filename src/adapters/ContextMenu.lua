-- ContextMenu: Blizzard's right-click menu and opening a whisper (CF-37). Thin, guarded wrappers.
-- Verified (API-FINDINGS V57): MenuUtil.CreateContextMenu with root:CreateTitle / root:CreateButton opens
-- from a button or an AceGUI tree row and its callbacks arrive; it draws at FULLSCREEN_DIALOG, so the main
-- window sits one strata lower (DIALOG). ChatFrameUtil.SendTell(name) opens the chat input as a whisper.
-- Disabling a button (element:SetEnabled(false)) greys it out (V58).
local _, ns = ...

local ContextMenu = {}

-- model = { title (optional, CF-63), items = { { label, enabled, ... } } }; onItem(item) runs on a click. Returns
-- true when the menu opened.
function ContextMenu.open(owner, model, onItem)
  if not (MenuUtil and MenuUtil.CreateContextMenu and owner and model) then return false end
  local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
    if model.title then root:CreateTitle(model.title) end
    for _, item in ipairs(model.items) do
      local element = root:CreateButton(item.label, function() onItem(item) end)
      if not item.enabled and element and element.SetEnabled then element:SetEnabled(false) end
    end
  end)
  return ok
end

-- Opens the chat input as a whisper to `name`. Returns true when a function for it existed.
function ContextMenu.whisper(name)
  if ChatFrameUtil and ChatFrameUtil.SendTell then
    ChatFrameUtil.SendTell(name)
    return true
  end
  if ChatFrame_SendTell then
    ChatFrame_SendTell(name)
    return true
  end
  return false
end

-- CF-48: opens the chat input as a whisper to `name` with `text` filled in, to edit before sending.
-- ChatFrameUtil.OpenChat / ChatFrame_OpenChat are unverified on Forever (VERIFY.md V72); without them the
-- whisper opens empty. Returns true when the chat input opened.
function ContextMenu.whisperText(name, text)
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open and pcall(open, "/w " .. tostring(name) .. " " .. tostring(text)) then return true end
  return ContextMenu.whisper(name)
end

ns.ContextMenu = ContextMenu
return ContextMenu
