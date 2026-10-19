-- Invite: community invite codes shared through records (CF-21). Pure Lua, no WoW globals.
local _, ns = ...

local Invite = {}

-- Community roles that may set the invite link: Owner 1, Leader 2, Moderator 3 (Member is 4).
local MANAGER_ROLES = { [1] = true, [2] = true, [3] = true }

-- The invite code from a full invite link or a bare code: the last path segment, alphanumeric.
-- Returns nil for anything else.
function Invite.parseCode(text)
  if type(text) ~= "string" then return nil end
  text = text:match("^%s*(.-)%s*$")
  local code = text:match("([%w]+)$")
  if not code or #code < 4 or #code > 64 then return nil end
  -- Either the whole text is the code, or it is the last segment of a link.
  if code ~= text and not text:find("/", 1, true) then return nil end
  return code
end

function Invite.canManage(role)
  return MANAGER_ROLES[role] == true
end

-- A record's invite if it is well formed and for clubId.
local function validFor(invite, clubId)
  return type(invite) == "table" and invite.clubId == clubId and type(invite.code) == "string"
    and type(invite.setAt) == "number"
end

-- Newest invite for clubId: sources = { { battleTag, displayName, invite }, ... }.
-- Returns { code, setAt, setBy = battleTag, setByName = displayName } or nil.
function Invite.newest(sources, clubId)
  local best
  for _, source in ipairs(sources) do
    local invite = source.invite
    if validFor(invite, clubId) and (not best or invite.setAt > best.setAt) then
      best = { code = invite.code, setAt = invite.setAt, setBy = source.battleTag, setByName = source.displayName }
    end
  end
  return best
end

ns.Invite = Invite
return Invite
