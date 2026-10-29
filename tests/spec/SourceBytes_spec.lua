-- CF-62: no control characters in the addon's source (a tool once wrote "\001" bytes for "\194\183" escapes, and
-- the game showed "▯94▯83"). Tabs, line feeds and carriage returns are fine.
describe("source files", function()
  local function luaFiles()
    local files = {}
    local cmd = package.config:sub(1, 1) == "\\" and 'dir /s /b src\\*.lua tools\\*.lua tests\\*.lua 2>nul'
      or 'find src tools tests -name "*.lua" 2>/dev/null'
    local pipe = io.popen(cmd)
    for line in pipe:lines() do files[#files + 1] = line end
    pipe:close()
    return files
  end

  it("have no control characters", function()
    local files = luaFiles()
    assert.is_true(#files > 20)
    for _, path in ipairs(files) do
      local f = assert(io.open(path, "rb"))
      local data = f:read("*a")
      f:close()
      local at = data:find("[%z\1-\8\11\12\14-\31]")
      assert.is_nil(at, path .. ": control character at byte " .. tostring(at))
    end
  end)
end)
