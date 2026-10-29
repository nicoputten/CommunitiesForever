-- Shared spec helpers. Loads addon files the way the WoW client does:
-- each file chunk receives (addonName, privateTable) as varargs.
local helpers = {}

helpers.ADDON_NAME = "CommunitiesForever"

function helpers.loadAddonFile(path, ns)
  local chunk = assert(loadfile(path))
  return chunk(helpers.ADDON_NAME, ns)
end

-- Addon source and data files listed in the TOC, in load order (libraries via embeds.xml excluded).
function helpers.tocFiles()
  local files = {}
  for line in io.lines(helpers.ADDON_NAME .. ".toc") do
    line = line:gsub("%s+$", "")
    if line:match("^src[\\/].+%.lua$") or line:match("^Data[\\/].+%.lua$") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  return files
end

-- CF-59: a private table with the core's shared modules (Calendar, Text) loaded, for specs that load core
-- files one by one.
function helpers.coreNs()
  local ns = {}
  helpers.loadAddonFile("src/core/Calendar.lua", ns)
  helpers.loadAddonFile("src/core/Text.lua", ns)
  return ns
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

--[[ CF-59: one logged-in client against the WoW mock, as most specs need it. Returns state, ns, addon.
opts = { install = options for wowapi.install, setup = function(state) before the addon's files load,
         clubId = the selected community ("23125681", the mock's; false: none) } ]]
function helpers.client(opts)
  local wowapi = require("mocks.wowapi")
  opts = opts or {}
  local state = wowapi.install(opts.install)
  if opts.setup then opts.setup(state) end
  local ns = helpers.loadAddon()
  local addon = state.addon
  addon:OnInitialize()
  if opts.clubId ~= false then addon.db.global.settings.clubId = opts.clubId or "23125681" end
  addon:OnEnable()
  return state, ns, addon
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

-- CF-55: a small JSON reader for the golden cases shared with the site (tests/fixtures/doomsday-cases.json).
-- Objects become tables with string keys, arrays 1-based lists; null becomes nil (not used in arrays there).
function helpers.json(text)
  local pos = 1
  local function fail(what) error(string.format("JSON: %s at %d", what, pos)) end
  local function skip() pos = text:find("[^ \t\r\n]", pos) or #text + 1 end
  local value
  local function str()
    local parts = {}
    pos = pos + 1
    while true do
      local c = text:sub(pos, pos)
      if c == "" then fail("unterminated string") end
      if c == '"' then pos = pos + 1; break end
      if c == "\\" then
        local e = text:sub(pos + 1, pos + 1)
        local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if e == "u" then
          local code = tonumber(text:sub(pos + 2, pos + 5), 16)
          if code < 0x80 then
            parts[#parts + 1] = string.char(code)
          elseif code < 0x800 then
            parts[#parts + 1] = string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
          else
            parts[#parts + 1] = string.char(0xE0 + math.floor(code / 4096), 0x80 + math.floor(code / 64) % 64,
              0x80 + code % 64)
          end
          pos = pos + 6
        else
          parts[#parts + 1] = map[e] or fail("bad escape")
          pos = pos + 2
        end
      else
        parts[#parts + 1] = c
        pos = pos + 1
      end
    end
    return table.concat(parts)
  end
  function value()
    skip()
    local c = text:sub(pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1
      skip()
      if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
      while true do
        skip()
        local key = str()
        skip()
        if text:sub(pos, pos) ~= ":" then fail("expected :") end
        pos = pos + 1
        obj[key] = value()
        skip()
        local sep = text:sub(pos, pos)
        pos = pos + 1
        if sep == "}" then return obj end
        if sep ~= "," then fail("expected , or }") end
      end
    elseif c == "[" then
      local list = {}
      pos = pos + 1
      skip()
      if text:sub(pos, pos) == "]" then pos = pos + 1; return list end
      while true do
        list[#list + 1] = value()
        skip()
        local sep = text:sub(pos, pos)
        pos = pos + 1
        if sep == "]" then return list end
        if sep ~= "," then fail("expected , or ]") end
      end
    elseif c == '"' then
      return str()
    elseif text:sub(pos, pos + 3) == "true" then
      pos = pos + 4; return true
    elseif text:sub(pos, pos + 4) == "false" then
      pos = pos + 5; return false
    elseif text:sub(pos, pos + 3) == "null" then
      pos = pos + 4; return nil
    end
    local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if not number or number == "" then fail("unexpected " .. c) end
    pos = pos + #number
    return tonumber(number)
  end
  local result = value()
  skip()
  if pos <= #text then fail("trailing text") end
  return result
end

function helpers.readJson(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return helpers.json(text)
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
