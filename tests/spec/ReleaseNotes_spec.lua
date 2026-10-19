-- Release notes per release: only the tag's section of CHANGELOG.md goes to CurseForge.
local ReleaseNotes = dofile("tools/release-notes.lua")

describe("release notes (CF-02)", function()
  local CHANGELOG = table.concat({
    "# Changelog",
    "Intro text.",
    "",
    "## Unreleased",
    "- next thing",
    "",
    "## v1.1.0-beta1 (2026-10-20)",
    "- beta fix",
    "",
    "## v1.1.0 (2026-10-21)",
    "- **Feature:** new",
    "  continued line",
    "",
    "",
    "## v1.0.0",
    "- first",
  }, "\n")

  it("returns only the section of that version, heading included", function()
    assert.are.equal("## v1.1.0 (2026-10-21)\n- **Feature:** new\n  continued line\n",
      ReleaseNotes.section(CHANGELOG, "v1.1.0"))
    assert.are.equal("## v1.0.0\n- first\n", ReleaseNotes.section(CHANGELOG, "v1.0.0"))
  end)

  it("does not mistake a pre-release for the release", function()
    assert.are.equal("## v1.1.0-beta1 (2026-10-20)\n- beta fix\n", ReleaseNotes.section(CHANGELOG, "v1.1.0-beta1"))
    assert.is_nil(ReleaseNotes.section("## v1.1.0-beta1\n- x\n", "v1.1.0"))
  end)

  it("fails without a section or with an empty one", function()
    local notes, reason = ReleaseNotes.section(CHANGELOG, "v2.0.0")
    assert.is_nil(notes)
    assert.is_truthy(reason:find("no \"## v2.0.0\" section", 1, true))
    notes, reason = ReleaseNotes.section("## v2.0.0\n\n## v1.0.0\n- x\n", "v2.0.0")
    assert.is_nil(notes)
    assert.is_truthy(reason:find("empty", 1, true))
  end)

  it("reads CRLF files", function()
    assert.are.equal("## v1.0.0\n- first\n", ReleaseNotes.section("## v1.0.0\r\n- first\r\n", "v1.0.0"))
  end)
end)
