local helpers = require("helpers")

describe("Clubs", function()
  local Clubs
  local CHARACTER = 1

  local clubs = {
    { clubId = "3", name = "Zeta", clubType = 1 },
    { clubId = "1", name = "Alpha", clubType = 1 },
    { clubId = "2", name = "Guild", clubType = 2 },
    { clubId = "4", name = "BNet", clubType = 0 },
    { clubId = "5", name = "Alpha", clubType = 1 },
  }

  before_each(function()
    Clubs = helpers.loadAddonFile("src/core/Clubs.lua", {})
  end)

  describe("selectable", function()
    it("keeps only character communities, sorted by name then id", function()
      assert.are.same({
        { clubId = "1", name = "Alpha" },
        { clubId = "5", name = "Alpha" },
        { clubId = "3", name = "Zeta" },
      }, Clubs.selectable(clubs, CHARACTER))
    end)

    it("falls back to the clubId when a club has no name", function()
      assert.are.same({ { clubId = "7", name = "7" } },
        Clubs.selectable({ { clubId = "7", clubType = 1 } }, CHARACTER))
    end)

    it("handles nil and empty lists", function()
      assert.are.same({}, Clubs.selectable(nil, CHARACTER))
      assert.are.same({}, Clubs.selectable({}, CHARACTER))
    end)
  end)

  describe("status", function()
    it("is none without a stored club", function()
      assert.are.equal("none", Clubs.status(nil, clubs, CHARACTER, true))
    end)

    it("is ok when the stored club is selectable", function()
      assert.are.equal("ok", Clubs.status("3", clubs, CHARACTER, false))
    end)

    it("is missing when the loaded list does not contain it", function()
      assert.are.equal("missing", Clubs.status("42", clubs, CHARACTER, false))
    end)

    it("is missing when the stored club is no longer a character community", function()
      assert.are.equal("missing", Clubs.status("2", clubs, CHARACTER, false))
    end)

    it("is unknown when the list is empty and not known to be loaded", function()
      assert.are.equal("unknown", Clubs.status("3", {}, CHARACTER, false))
    end)

    it("is missing when the list is empty but known to be loaded", function()
      assert.are.equal("missing", Clubs.status("3", {}, CHARACTER, true))
    end)
  end)
end)
