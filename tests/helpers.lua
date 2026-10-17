-- Shared spec helpers. Loads addon files the way the WoW client does:
-- each file chunk receives (addonName, privateTable) as varargs.
local helpers = {}

helpers.ADDON_NAME = "CommunitiesForever"

function helpers.loadAddonFile(path, ns)
  local chunk = assert(loadfile(path))
  return chunk(helpers.ADDON_NAME, ns)
end

-- Addon source files listed in the TOC, in load order (libraries via embeds.xml excluded).
function helpers.tocFiles()
  local files = {}
  for line in io.lines(helpers.ADDON_NAME .. ".toc") do
    line = line:gsub("%s+$", "")
    if line:match("^src[\\/].+%.lua$") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  return files
end

-- Loads every addon file in TOC order into a fresh private table and returns it.
-- Install the WoW mock first (tests/mocks/wowapi.lua).
function helpers.loadAddon()
  local ns = {}
  for _, path in ipairs(helpers.tocFiles()) do
    helpers.loadAddonFile(path, ns)
  end
  return ns
end

return helpers
