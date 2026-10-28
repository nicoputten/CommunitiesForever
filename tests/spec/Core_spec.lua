local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

describe("Core", function()
  local state, ns

  local function load(opts)
    state = wowapi.install(opts)
    ns = helpers.loadAddon()
    state.addon:OnInitialize()
  end

  after_each(function()
    wowapi.uninstall()
  end)

  it("uses the private table as the addon object and global", function()
    load()
    assert.are.equal(ns, state.addon)
    assert.are.equal(ns, _G.CommunitiesForever)
    assert.are.equal("CommunitiesForever", ns.name)
  end)

  it("creates the database with a schema version", function()
    load()
    assert.are.equal("CommunitiesForeverDB", state.svName)
    assert.are.equal(ns.Store.SCHEMA_VERSION, ns.db.global.schemaVersion)
  end)

  describe("/cf", function()
    it("prints the version from the TOC", function()
      load({ metadata = { Version = "0.1.7" } })
      state.slash.cf("version")
      assert.are.same({ "Version 0.1.7" }, state.printed)
    end)

    it("accepts the version command in any case", function()
      load()
      state.slash.cf("  VERSION ")
      assert.are.same({ "Version 0.1.0" }, state.printed)
    end)

    it("prints unknown when the metadata API is missing", function()
      load({ missing = { C_AddOns = true } })
      state.slash.cf("version")
      assert.are.same({ "Version unknown" }, state.printed)
    end)

    it("prints unknown when the TOC has no version", function()
      load({ metadata = {} })
      state.slash.cf("version")
      assert.are.same({ "Version unknown" }, state.printed)
    end)

    it("prints help for /cf help", function()
      load()
      state.slash.cf("help")
      assert.are.equal("Commands:", state.printed[1])
      assert.matches("/cf - open or close the window", state.printed[2], 1, true)
      assert.matches("/cf version", state.printed[3], 1, true)
    end)

    it("prints the own record for /cf self", function()
      load()
      state.slash.cf("self")
      assert.are.same({ "BattleTag nil, version 0, 0 character(s)" }, state.printed)
    end)

    it("lists /cf self in the help", function()
      load()
      state.slash.cf("help")
      assert.matches("/cf self", state.printed[4], 1, true)
    end)

    it("prints help for unknown commands", function()
      load()
      state.slash.cf("bogus")
      assert.are.equal("Commands:", state.printed[1])
    end)

    it("lists every command once in the help, not the hidden debug ones", function()
      load()
      state.slash.cf("help")
      local all = table.concat(state.printed, " | ")
      for _, command in ipairs({ "version", "self", "members", "friends", "people", "sync", "ping", "activity",
                                 "settings", "setup", "ask", "doomsday" }) do
        assert.is_truthy(all:find("/cf " .. command, 1, true), command)
      end
      assert.is_falsy(all:find("debugon", 1, true))
      assert.are.equal(16, #state.printed) -- the header and 15 lines
    end)
  end)
end)
