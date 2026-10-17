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

-- Pure-Lua libraries from Libs/ (fetched by tools/fetch-libs.ps1). Without LibStub they
-- return themselves. Cached, so a spec gets the same instance as the addon would.
local libs = {}
local LIB_PATHS = {
  LibSerialize = "Libs/LibSerialize/LibSerialize.lua",
  LibDeflate = "Libs/LibDeflate/LibDeflate.lua",
}

function helpers.lib(name)
  if not libs[name] then
    local path = assert(LIB_PATHS[name], "unknown lib " .. name)
    local chunk = loadfile(path)
    assert(chunk, path .. " not found: run tools/fetch-libs.ps1")
    libs[name] = chunk()
  end
  return libs[name]
end

return helpers
