-- Shared spec helpers. Loads addon files the way the WoW client does:
-- each file chunk receives (addonName, privateTable) as varargs.
local helpers = {}

helpers.ADDON_NAME = "CommunitiesForever"

function helpers.loadAddonFile(path, ns)
  local chunk = assert(loadfile(path))
  return chunk(helpers.ADDON_NAME, ns)
end

return helpers
