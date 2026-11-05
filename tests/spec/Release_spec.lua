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
    local files = { helpers.ADDON_NAME .. ".toc", "embeds.xml", "Bindings.xml", "LICENSE", "CHANGELOG.md" }
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

  -- CF-45: a file the TOC lists but that is missing at game start loads only after a restart, so the empty
  -- runs file ships before the uploader ever writes it.
  it("ships the empty planned runs file", function()
    assert.is_truthy(read(helpers.ADDON_NAME .. ".toc"):find("\nData\\Runs.lua\r?\n"))
    assert.is_truthy(read("Data/Runs.lua"):find("\nCF_RUNS = nil\r?\n"))
    assert.is_nil(read(".pkgmeta"):find("\n  %- Data"))
    assert.is_truthy(read("tools/build.ps1"):find("'Data'", 1, true))
  end)

  it("uploads to the Wago project named in the TOC", function()
    local tocId = read(helpers.ADDON_NAME .. ".toc"):match("## X%-Wago%-ID: (%w+)")
    assert.is_truthy(tocId, "no X-Wago-ID in the TOC")
    assert.are.equal(tocId, read(".github/workflows/release.yml"):match("WAGO_ID: (%w+)"))
  end)

  it("uses the hand-written notes of the tagged release, not commit messages", function()
    assert.is_truthy(read(".pkgmeta"):find("manual%-changelog:%s+filename: RELEASE_NOTES%.md"))
    assert.is_truthy(read(".github/workflows/release.yml")
      :find("lua tools/release-notes.lua \"$TAG\" > RELEASE_NOTES.md", 1, true))
  end)

  -- CF-84: the vault folder ships next to the addon, for the same game, with its own SavedVariables file.
  it("packages the CommunitiesForever_Vault folder with the addon", function()
    assert.is_truthy(read(".pkgmeta"):find("move%-folders:%s+CommunitiesForever/CommunitiesForever_Vault: "
      .. "CommunitiesForever_Vault"))
    local VAULT_TOC = "CommunitiesForever_Vault/CommunitiesForever_Vault.toc"
    local toc, vault = read(helpers.ADDON_NAME .. ".toc"), read(VAULT_TOC)
    assert.are.equal(toc:match("## Interface: (%d+)"), vault:match("## Interface: (%d+)"))
    assert.is_truthy(vault:find("## SavedVariables: CommunitiesForeverVaultDB\n", 1, true))
    assert.is_truthy(toc:find("## OptionalDeps: [^\n]*CommunitiesForever_Vault"))
    for _, path in ipairs({ VAULT_TOC, "CommunitiesForever_Vault/Vault.lua" }) do
      assert.is_nil(read(path):find("Doombringer", 1, true), path)
    end
  end)
end)
