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
      assert.are.same({ notifications = true, minimap = {}, window = {}, tree = {}, sendInterval = 0.2,
                        shareActivity = true, chatAlert = true, chatSound = false, chatKeepGeneral = true,
                        chatTab = {}, openOnLogin = false, ambientEffects = true },
        global.settings)
      assert.are.same({ version = 0, chars = {} }, global.self)
      assert.are.same({}, global.people)
      assert.are.same({}, global.presence)
      assert.are.same({}, global.locations)
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

    it("keeps the current schema version", function()
      local global = Store.init({ schemaVersion = Store.SCHEMA_VERSION })
      assert.are.equal(Store.SCHEMA_VERSION, global.schemaVersion)
    end)
  end)

  describe("migrations (rule 8)", function()
    it("stamps fresh data with the current schema", function()
      assert.are.equal(Store.SCHEMA_VERSION, Store.init({}).schemaVersion)
    end)

    it("runs every step from the stored schema up to the current one, in order", function()
      Store.SCHEMA_VERSION = 3
      Store.MIGRATIONS[1] = function(g) g.renamed = g.old; g.old = nil end
      Store.MIGRATIONS[2] = function(g) g.count = g.renamed and #g.renamed or 0 end -- derived, else empty
      local global = Store.init({ schemaVersion = 1, old = { "a", "b" } })
      assert.are.same({ schemaVersion = 3, renamed = { "a", "b" }, count = 2 }, global)
      assert.are.same({ schemaVersion = 3, count = 0 }, Store.init({ schemaVersion = 2 }))
    end)

    it("leaves data from a newer schema untouched", function()
      local global, reason = Store.init({ schemaVersion = Store.SCHEMA_VERSION + 1, x = 1 })
      assert.are.equal("newer", reason)
      assert.are.same({ schemaVersion = Store.SCHEMA_VERSION + 1, x = 1 }, global)
    end)

    it("has a step for every schema below the current one", function()
      for version = 1, Store.SCHEMA_VERSION - 1 do
        assert.is_function(Store.MIGRATIONS[version], "no migration from schema " .. version)
      end
    end)
  end)
end)
