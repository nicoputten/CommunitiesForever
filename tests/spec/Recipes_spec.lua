local helpers = require("helpers")

describe("Recipes (CF-38)", function()
  local Recipes, ns

  local SHORT = "trade:Player-4619-0A1B2C3D:3908:197"
  local LONG = "trade:Player-4619-0A1B2C3D:3908:197:AAAAgP8HAAAAAAAA"
  local FULL = "|cffffd000|H" .. SHORT .. "|h[Tailoring]|h|r"

  local function char()
    return { guid = "Player-4619-0A1B2C3D",
             professions = { [197] = { name = "Tailoring", rank = 300, max = 300 },
                             [333] = { name = "Enchanting", rank = 285, max = 300, link = "trade:x:1:333",
                                       linkType = "long", scannedAt = 100 },
                             [186] = { name = "Mining", rank = 120, max = 150 },
                             [185] = { name = "Cooking", rank = 150, max = 225 } } }
  end

  local function entries()
    return { { id = 2963, learned = true, itemID = 2996 }, { id = 1229504, learned = true, itemID = 279972 },
             { id = 7421, learned = true, itemID = nil }, { id = 3914, learned = false, itemID = 4307 } }
  end

  before_each(function()
    ns = helpers.coreNs()
    Recipes = helpers.loadAddonFile("src/core/Recipes.lua", ns)
    Recipes.IN_RECORD = false
  end)

  describe("payload and linkType", function()
    it("takes the trade part of a full link or a bare one", function()
      assert.equals(SHORT, Recipes.payload(FULL))
      assert.equals(SHORT, Recipes.payload(SHORT))
    end)

    it("refuses anything else", function()
      assert.is_nil(Recipes.payload("|cff9d9d9d|Hitem:2996::|h[Bolt]|h|r"))
      assert.is_nil(Recipes.payload("trade:"))
      assert.is_nil(Recipes.payload("trade:a [b]"))
      assert.is_nil(Recipes.payload(42))
      assert.is_nil(Recipes.payload("trade:" .. string.rep("A", 2000)))
    end)

    it("calls a link with 4 colon-separated fields short, else long", function()
      assert.equals("short", Recipes.linkType(SHORT))
      assert.equals("short", Recipes.linkType(FULL))
      assert.equals("long", Recipes.linkType(LONG))
      assert.equals("long", Recipes.linkType("trade:Player-4619-0A1B2C3D:3908"))
      assert.is_nil(Recipes.linkType(nil))
    end)

    it("builds the chat link in Blizzard's colour", function()
      assert.equals(FULL, Recipes.chatLink(SHORT, "Tailoring"))
    end)
  end)

  describe("fromScan", function()
    it("keeps learned recipes with their item, 0 for none", function()
      local set, lines = Recipes.fromScan(entries())
      assert.same({ [2963] = 2996, [1229504] = 279972, [7421] = 0 }, set)
      assert.is_nil(lines)
    end)

    it("keeps the skill line of each recipe when it was read", function()
      local list = entries()
      list[1].line = 197
      local _, lines = Recipes.fromScan(list)
      assert.same({ [2963] = 197 }, lines)
    end)

    it("gives nothing for an empty or failed read", function()
      assert.is_nil(Recipes.fromScan({}))
      assert.is_nil(Recipes.fromScan(nil))
      assert.is_nil(Recipes.fromScan({ { id = 1, learned = false } }))
    end)
  end)

  describe("apply", function()
    it("stores the set, the open profession's link and scannedAt", function()
      local c = char()
      local synced, stored = Recipes.apply(c, { entries = entries(), profession = 197, link = FULL }, 500)
      assert.is_true(synced)
      assert.is_true(stored)
      assert.same({ [2963] = 2996, [1229504] = 279972, [7421] = 0 }, c.recipes)
      assert.equals(500, c.recipesAt)
      assert.equals(SHORT, c.professions[197].link)
      assert.equals("short", c.professions[197].linkType)
      assert.equals(500, c.professions[197].scannedAt)
    end)

    it("never touches another profession", function()
      local c = char()
      Recipes.apply(c, { entries = entries(), profession = 197, link = FULL }, 500)
      assert.same({ name = "Enchanting", rank = 285, max = 300, link = "trade:x:1:333", linkType = "long",
                    scannedAt = 100 }, c.professions[333])
      assert.is_nil(c.professions[185].scannedAt)
    end)

    it("replaces the set on a complete scan", function()
      local c = char()
      c.recipes = { [1] = 0, [2963] = 2996 }
      Recipes.apply(c, { entries = entries(), profession = 197, link = FULL }, 500)
      assert.is_nil(c.recipes[1])
    end)

    it("keeps the set and the link on an empty read", function()
      local c = char()
      c.recipes, c.recipesAt = { [2963] = 2996 }, 100
      c.professions[197].link, c.professions[197].scannedAt = SHORT, 100
      local synced, stored = Recipes.apply(c, { entries = {}, profession = 197, link = nil }, 500)
      assert.is_false(synced)
      assert.is_false(stored)
      assert.same({ [2963] = 2996 }, c.recipes)
      assert.equals(100, c.recipesAt)
      assert.equals(SHORT, c.professions[197].link)
      assert.equals(100, c.professions[197].scannedAt)
    end)

    it("stores no link for gathering professions", function()
      local c = char()
      local mining = "|cffffd000|Htrade:p:2575:186|h[Mining]|h|r"
      Recipes.apply(c, { entries = entries(), profession = 186, link = mining }, 500)
      assert.is_nil(c.professions[186].link)
      assert.is_nil(c.professions[186].scannedAt)
      assert.is_not_nil(c.recipes[2963]) -- Smelting still counts in the set
    end)

    it("updates only the set without an open profession (a recipe learned with the window closed)", function()
      local c = char()
      local synced, stored = Recipes.apply(c, { entries = entries() }, 500)
      assert.is_false(synced)
      assert.is_true(stored)
      assert.is_nil(c.professions[197].scannedAt)
    end)

    it("is synced only when a link, its type or the spec changes", function()
      local c = char()
      Recipes.apply(c, { entries = entries(), profession = 197, link = FULL }, 500)
      local synced, stored = Recipes.apply(c, { entries = entries(), profession = 197, link = FULL }, 600)
      assert.is_false(synced)
      assert.is_true(stored)
      assert.equals(600, c.professions[197].scannedAt)
      assert.is_true((Recipes.apply(c, { profession = 197, link = LONG }, 700)))
      assert.equals("long", c.professions[197].linkType)
      assert.is_true((Recipes.apply(c, { profession = 197, spec = "Mooncloth Tailor" }, 800)))
      assert.equals("Mooncloth Tailor", c.professions[197].spec)
    end)

    it("calls a changed set synced only when it travels in the record", function()
      local c = char()
      assert.is_false((Recipes.apply(c, { entries = entries() }, 500)))
      Recipes.IN_RECORD = true
      local list = entries()
      list[4].learned = true
      assert.is_true((Recipes.apply(c, { entries = list }, 600)))
      assert.is_false((Recipes.apply(c, { entries = list }, 700)))
    end)

    it("ignores a profession the character does not have", function()
      local c = char()
      assert.has_no.errors(function() Recipes.apply(c, { profession = 164, link = FULL }, 500) end)
      assert.is_nil(c.professions[164])
    end)
  end)

  describe("carry", function()
    it("keeps the scan fields over a snapshot rebuild", function()
      local previous = char()
      previous.recipes, previous.recipesAt = { [2963] = 2996 }, 100
      local fresh = { professions = { [333] = { name = "Enchanting", rank = 290, max = 300 } } }
      Recipes.carry(previous, fresh)
      assert.same({ [2963] = 2996 }, fresh.recipes)
      assert.equals(100, fresh.recipesAt)
      assert.same({ name = "Enchanting", rank = 290, max = 300, link = "trade:x:1:333", linkType = "long",
                    scannedAt = 100 }, fresh.professions[333])
    end)
  end)

  describe("outgoing", function()
    it("leaves the recipe set out of the record unless IN_RECORD", function()
      local c = char()
      c.recipes, c.recipesAt, c.recipeLines = { [2963] = 2996 }, 100, { [2963] = 197 }
      local out = Recipes.outgoing(c)
      assert.is_nil(out.recipes)
      assert.is_nil(out.recipesAt)
      assert.is_nil(out.recipeLines)
      assert.equals(c.professions, out.professions)
      assert.same({ [2963] = 2996 }, c.recipes) -- the stored character keeps it
      Recipes.IN_RECORD = true
      assert.equals(c, Recipes.outgoing(c))
    end)
  end)

  describe("clean", function()
    it("keeps valid fields and recomputes the link type", function()
      local c = { professions = { [197] = { name = "Tailoring", link = SHORT, linkType = "long", scannedAt = 5,
                                            spec = "Mooncloth Tailor" } },
                  recipes = { [2963] = 2996, [7421] = 0 }, recipesAt = 5, recipeLines = { [2963] = 197 } }
      Recipes.clean(c)
      assert.equals("short", c.professions[197].linkType)
      assert.equals(SHORT, c.professions[197].link)
      assert.same({ [2963] = 2996, [7421] = 0 }, c.recipes)
      assert.same({ [2963] = 197 }, c.recipeLines)
    end)

    it("drops bad links, times, specs and recipe maps", function()
      local c = { professions = { [197] = { link = "item:1", linkType = "short", scannedAt = "x",
                                            spec = string.rep("a", 60) } },
                  recipes = { [2963] = "bolt" }, recipesAt = "x", recipeLines = { [2963] = 0 } }
      Recipes.clean(c)
      assert.same({}, c.professions[197])
      assert.is_nil(c.recipes)
      assert.is_nil(c.recipesAt)
      assert.is_nil(c.recipeLines)
    end)

    it("drops a set that is too big", function()
      local big = {}
      for i = 1, Recipes.MAX_RECIPES + 1 do big[i] = 0 end
      local c = { recipes = big }
      Recipes.clean(c)
      assert.is_nil(c.recipes)
    end)
  end)

  describe("throttle", function()
    it("scans at most once per second, with one later scan for events inside it", function()
      local state = {}
      assert.equals(0, Recipes.throttle(state, 10, 1))
      assert.equals(0.5, Recipes.throttle(state, 10.5, 1))
      assert.is_nil(Recipes.throttle(state, 10.7, 1)) -- already planned
      Recipes.ran(state, 11)
      assert.equals(1, Recipes.throttle(state, 11, 1))
      Recipes.ran(state, 12)
      assert.equals(0, Recipes.throttle(state, 13.5, 1))
    end)
  end)

  describe("cell (RC07)", function()
    it("is a link in the game's colour with the board's tooltip", function()
      local cell = Recipes.cell(197, { name = "Tailoring", link = SHORT }, "Mira")
      assert.equals("link", cell.state)
      assert.equals("[Tailoring]", cell.text)
      assert.equals(SHORT, cell.link)
      assert.equals(FULL, cell.chatLink)
      assert.equals("Mira\226\128\153s Tailoring", cell.tip.title)
      assert.same({ "Click: open in game", "Shift-click: link in chat" }, cell.tip.lines)
    end)

    it("says not scanned without a link", function()
      local cell = Recipes.cell(185, { name = "Cooking" }, "Mira")
      assert.equals("notScanned", cell.state)
      assert.equals("not scanned", cell.text)
      assert.same({ "Opens once Mira opens Cooking in game" }, cell.tip.lines)
    end)

    it("has nothing for gathering professions and Fishing", function()
      for _, line in ipairs({ 186, 182, 393, 356 }) do
        assert.is_nil(Recipes.cell(line, { name = "x", link = SHORT }, "Mira"))
      end
    end)
  end)
end)
