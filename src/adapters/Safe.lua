-- Safe: reading values Midnight may hide from addons (secret values, `issecretvalue` exists: V37) and calling
-- APIs that may be missing or error on Forever. Shared by the adapters (CF-59); no business logic.
local _, ns = ...

local Safe = {}

-- True for a secret value (unreadable for addons).
function Safe.secret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

-- The value, or nil when it is secret.
function Safe.value(value)
  if Safe.secret(value) then return nil end
  return value
end

-- CF-108: the values with secret ones as nil, for forwarding raw event arguments (no comparison runs on a secret).
function Safe.values(...)
  local n = select("#", ...)
  if n == 0 then return end
  local out = { ... }
  for i = 1, n do out[i] = Safe.value(out[i]) end
  return unpack(out, 1, n)
end

-- CF-108: true for a readable, non-empty string. The secret check comes first: comparing a secret throws.
function Safe.text(value)
  if Safe.secret(value) then return false end
  return type(value) == "string" and value ~= ""
end

-- Calls fn(...) guarded: its results with secret ones as nil; nothing when fn is missing or errors.
function Safe.call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local results = { pcall(fn, ...) }
  if not results[1] then return nil end
  local n = table.maxn(results) - 1
  local out = {}
  for i = 1, n do out[i] = Safe.value(results[i + 1]) end
  return unpack(out, 1, n)
end

ns.Safe = Safe
return Safe
