-- Release notes for one version: the "## <version>" section of CHANGELOG.md, so a release on CurseForge
-- shows what changed in THAT release only (not the whole history).
--   lua tools/release-notes.lua v0.2.0-beta2 [CHANGELOG.md] > RELEASE_NOTES.md
-- Exits with an error when the changelog has no section (or an empty one) for the version: the release
-- workflow then stops before anything is uploaded. Lua 5.1, no dependencies.
local ReleaseNotes = {}

local function escape(text)
  return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- The section for version (heading included, surrounding blank lines trimmed), or nil and a reason.
-- A heading matches "## v1.2.0", "## v1.2.0 (2026-10-19)"; "## v1.2.0-beta1" is not "## v1.2.0".
function ReleaseNotes.section(text, version)
  local heading = "^## " .. escape(version) .. "%f[%s%z]"
  local lines, found = {}, false
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r$", "")
    if found then
      if line:match("^## ") then break end
      lines[#lines + 1] = line
    elseif line:match(heading) then
      found = true
      lines[1] = line
    end
  end
  if not found then return nil, "CHANGELOG.md has no \"## " .. version .. "\" section" end
  while #lines > 1 and lines[#lines]:match("^%s*$") do lines[#lines] = nil end
  if #lines < 2 then return nil, "the \"## " .. version .. "\" section in CHANGELOG.md is empty" end
  return table.concat(lines, "\n") .. "\n"
end

local running = arg and arg[0] and arg[0]:match("release%-notes%.lua$")
if running then
  local version, path = arg[1], arg[2] or "CHANGELOG.md"
  if not version or version == "" then
    io.stderr:write("usage: lua tools/release-notes.lua <version tag> [CHANGELOG.md]\n")
    os.exit(2)
  end
  local file = assert(io.open(path, "rb"))
  local notes, reason = ReleaseNotes.section(file:read("*a"), version)
  file:close()
  if not notes then
    io.stderr:write(reason .. ": add one before tagging.\n")
    os.exit(1)
  end
  io.write(notes)
end

return ReleaseNotes
