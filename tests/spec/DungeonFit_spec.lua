local helpers = require("helpers")

-- CF-106: the one fit rule, golden cases shared with the site, and the Dungeons tab's groups.
describe("Dungeon fit (CF-106)", function()
  local Dungeons

  before_each(function()
    Dungeons = helpers.coreNs().Dungeons
    Dungeons.LIST = Dungeons.STATIC
  end)

  describe("golden cases (tests/fixtures/dungeon-fit-cases.json)", function()
    local data = helpers.readJson("tests/fixtures/dungeon-fit-cases.json")
    it("uses the file's rule", function()
      assert.are.equal(data.fitBelow, helpers.coreNs().Dungeons.FIT_BELOW)
    end)
    for _, c in ipairs(data.cases) do
      it(string.format("level %d in %d-%d is %s", c.level, c.min, c.max, c.fit), function()
        local d = { min = c.min, max = c.max }
        assert.are.equal(c.fit, Dungeons.fitKind(c.level, d))
        assert.are.equal(c.fit == "fits", Dungeons.fits(d, c.level))
      end)
    end
  end)

  it("has no kind without a level", function()
    assert.is_nil(Dungeons.fitKind(nil, { min = 1, max = 2 }))
    assert.is_false(Dungeons.fits({ min = 1, max = 2 }, nil))
  end)

  it("groups every dungeon: Fits you, Higher, Lower only with dungeons, wings under their dungeon", function()
    local groups = Dungeons.grouped(16)
    assert.are.same({ "fits", "higher" }, { groups[1].key, groups[2].key })
    assert.are.equal("Fits you", groups[1].text)
    local fits = {}
    for _, item in ipairs(groups[1].items) do fits[#fits + 1] = item.dungeon.id end
    assert.are.same({ "rfc", "wc", "dm" }, fits) -- 13-18, 17-24, 17-26 (15 is 2 below 17)
    local higher, parents = {}, 0
    for _, item in ipairs(groups[2].items) do
      if item.parent then
        parents = parents + 1
        assert.are.equal("Scarlet Monastery", item.parent)
      else
        higher[#higher + 1] = item.wing or item.dungeon.id
      end
    end
    assert.are.equal(1, parents)
    -- The wings follow each other under the parent, at the first wing's place.
    local s = table.concat(higher, ",")
    assert.is_truthy(s:find("Graveyard,Library,Armory,Cathedral", 1, true))
    local lower = Dungeons.grouped(40)
    assert.are.equal("lower", lower[3].key)
    assert.are.equal("rfc", lower[3].items[1].dungeon.id)
  end)

  it("keeps Fits you when nothing fits", function()
    local groups = Dungeons.grouped(6)
    assert.are.equal("fits", groups[1].key)
    assert.are.equal(0, #groups[1].items)
    assert.are.equal("higher", groups[2].key)
  end)

  it("counts 2 below the minimum in the overview (suggestions)", function()
    local list = Dungeons.overview({ { key = "self", own = true, guid = "g", name = "Hex", level = 15 } }, "g")
    local ids = {}
    for _, e in ipairs(list) do ids[#ids + 1] = e.dungeon.id end
    table.sort(ids)
    assert.are.same({ "dm", "rfc", "wc" }, ids)
  end)
end)
