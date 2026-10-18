local helpers = require("helpers")

-- CF-02: the released zip must not contain personal info (real names, BattleTags, character names of the
-- developer and friends). This spec is not packaged (tests/ is ignored in .pkgmeta).
describe("release contents (CF-02)", function()
  -- Case-sensitive on purpose: "Marks Man" must not match "Marksmanship".
  local BANNED = { "Sjaak", "Garraka", "Doombringer", "Kawkartha", "Marks Man", "#2232", "#2858",
                   "Putten", "nico.putten" }

  local function read(path)
    local file = assert(io.open(path, "rb"), "missing " .. path)
    local text = file:read("*a")
    file:close()
    return text
  end

  -- Files the packager ships besides Libs/ (third-party): the TOC, its source files and the root files.
  local function releasedFiles()
    local files = { helpers.ADDON_NAME .. ".toc", "embeds.xml", "LICENSE", "CHANGELOG.md" }
    for _, path in ipairs(helpers.tocFiles()) do files[#files + 1] = path end
    return files
  end

  it("ships no personal names", function()
    for _, path in ipairs(releasedFiles()) do
      local text = read(path)
      for _, word in ipairs(BANNED) do
        assert.is_nil(text:find(word, 1, true), string.format("%s contains %q", path, word))
      end
    end
  end)

  it("keeps development files out of the package", function()
    local pkgmeta = read(".pkgmeta")
    for _, path in ipairs({ "tests", "tools", "docs", "CLAUDE.md", "VERIFY.md" }) do
      assert.is_truthy(pkgmeta:find("\n  %- " .. path:gsub("%.", "%%.") .. "\n"), path .. " is not ignored")
    end
  end)

  it("uses the hand-written changelog, not one from commit messages", function()
    assert.is_truthy(read(".pkgmeta"):find("manual%-changelog:%s+filename: CHANGELOG%.md"))
  end)
end)
