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

-- CF-40: the native Friends tab (src/ui/FriendsTab.lua) as the specs see it.
function helpers.friendsTab(ns)
  local tab = {}
  function tab.rows() return ns.FriendsTab.rows() end
  -- Paths of the visible list rows of one kind ("group" or "char"), in order.
  function tab.paths(kind)
    local list = {}
    for _, r in ipairs(tab.rows()) do
      if not kind or r.kind == kind then list[#list + 1] = r.path end
    end
    return list
  end
  function tab.row(path)
    for _, r in ipairs(tab.rows()) do
      if r.path == path then return r.frame end
    end
  end
  function tab.texts() return ns.FriendsTab.cardTexts() end
  function tab.cardLines() return ns.FriendsTab.cardLines() end
  function tab.has(text)
    for _, t in ipairs(tab.texts()) do
      if t:find(text, 1, true) then return true end
    end
    return false
  end
  function tab.click(frame) frame:RunScript("OnClick", "LeftButton") end
  function tab.rightClick(frame) frame:RunScript("OnMouseUp", "RightButton") end
  -- Types into the search box, as the player does.
  function tab.type(text)
    local box = ns.FriendsTab.searchBox()
    box:SetText(text)
    box:RunScript("OnTextChanged", true)
  end
  return tab
end

-- CF-41: the native Activity tab (src/ui/ActivityTab.lua): its visible texts without colour codes, one per
-- line, and clicking a "Show all" / "Show less" link by the start of its text.
function helpers.activityTab(ns)
  local tab = {}
  function tab.text()
    local list = {}
    for i, text in ipairs(ns.ActivityTab.texts()) do
      list[i] = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    return "\n" .. table.concat(list, "\n") .. "\n"
  end
  function tab.click(prefix)
    for _, link in ipairs(ns.ActivityTab.links()) do
      if link.text:GetText():sub(1, #prefix) == prefix then return link:RunScript("OnClick") end
    end
    error("no link " .. prefix)
  end
  return tab
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
