local helpers = require("helpers")

describe("Store", function()
  local Store

  before_each(function()
    Store = helpers.loadAddonFile("src/core/Store.lua", {})
  end)

  it("registers itself on the private addon table", function()
    local ns = {}
    local loaded = helpers.loadAddonFile("src/core/Store.lua", ns)
    assert.are.equal(loaded, ns.Store)
  end)

  describe("defaults", function()
    it("matches the data model sections", function()
      local global = Store.defaults().global
      assert.are.same({ notifications = true, minimap = {}, window = {}, collapsed = {} }, global.settings)
      assert.are.same({ version = 0, chars = {} }, global.self)
      assert.are.same({}, global.people)
      assert.are.same({}, global.presence)
      assert.are.same({}, global.nicknames)
    end)

    it("does not default schemaVersion", function()
      assert.is_nil(Store.defaults().global.schemaVersion)
    end)

    it("returns a fresh table on every call", function()
      local a, b = Store.defaults(), Store.defaults()
      a.global.people.x = true
      assert.is_nil(b.global.people.x)
    end)
  end)

  describe("init", function()
    it("stamps the current schema version on a fresh database", function()
      local global = Store.init({})
      assert.are.equal(Store.SCHEMA_VERSION, global.schemaVersion)
    end)

    it("keeps an existing schema version", function()
      local global = Store.init({ schemaVersion = 0 })
      assert.are.equal(0, global.schemaVersion)
    end)
  end)
end)
