local helpers = require("helpers")

describe("Version (CF-35)", function()
  local Version

  before_each(function()
    Version = helpers.loadAddonFile("src/core/Version.lua", helpers.coreNs())
  end)

  it("parses release tags only", function()
    assert.are.same({ major = 0, minor = 3, patch = 0, stage = 2, n = 1 }, Version.parse("v0.3.0-beta1"))
    assert.are.same({ major = 1, minor = 2, patch = 3, stage = 3, n = 0 }, Version.parse("v1.2.3"))
    assert.are.equal(1, Version.parse("v1.0.0-alpha4").stage)
    for _, dev in ipairs({ "0.1.155", "@project-version@", "v0.3.0-beta1-6-gde31d17", "v0.3", "v0.3.0-rc1",
                           "", "unknown" }) do
      assert.is_nil(Version.parse(dev), dev)
    end
    assert.is_nil(Version.parse(nil))
    assert.is_nil(Version.parse(3))
  end)

  it("orders alpha before beta before the release, and by number", function()
    local order = { "v0.2.9", "v0.3.0-alpha1", "v0.3.0-beta1", "v0.3.0-beta2", "v0.3.0-beta10", "v0.3.0",
                    "v0.3.1", "v0.10.0", "v1.0.0" }
    for i = 1, #order - 1 do
      assert.is_true(Version.isNewer(order[i], order[i + 1]), order[i] .. " < " .. order[i + 1])
      assert.is_false(Version.isNewer(order[i + 1], order[i]), order[i + 1] .. " not < " .. order[i])
    end
    assert.is_false(Version.isNewer("v0.3.0", "v0.3.0"))
  end)

  it("never compares dev builds, and ignores versions more than one major ahead", function()
    assert.is_false(Version.isNewer("0.1.155", "v9.0.0"))
    assert.is_false(Version.isNewer("v0.3.0", "0.1.200"))
    assert.is_false(Version.isNewer("v0.3.0", "v2.0.0"))
    assert.is_true(Version.isNewer("v0.3.0", "v1.0.0"))
    assert.is_false(Version.isNewer("v0.3.0", nil)) -- an older client's HELLO has no av (rule 8)
  end)
end)
