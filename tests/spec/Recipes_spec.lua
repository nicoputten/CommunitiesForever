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
      assert.is_true(synced) -- new recipes travel to friends
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

    it("keeps the learn order: the first scan in ID order, new recipes appended, same base", function()
      local c = char()
      assert.is_true((Recipes.apply(c, { entries = entries() }, 500)))
      assert.same({ 2963, 7421, 1229504 }, c.recipeOrder)
      assert.equals(500, c.recipesBase)
      local list = entries()
      list[4].learned = true
      list[5] = { id = 100, learned = true, itemID = 5 }
      assert.is_true((Recipes.apply(c, { entries = list }, 600)))
      assert.same({ 2963, 7421, 1229504, 100, 3914 }, c.recipeOrder)
      assert.equals(500, c.recipesBase)
      assert.is_false((Recipes.apply(c, { entries = list }, 700))) -- nothing new
    end)

    it("starts a new order and base when a recipe is gone", function()
      local c = char()
      Recipes.apply(c, { entries = entries() }, 500)
      local list = entries()
      table.remove(list, 1)
      assert.is_true((Recipes.apply(c, { entries = list }, 600)))
      assert.same({ 7421, 1229504 }, c.recipeOrder)
      assert.equals(600, c.recipesBase)
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
      previous.recipeOrder, previous.recipesBase = { 2963 }, 90
      local fresh = { professions = { [333] = { name = "Enchanting", rank = 290, max = 300 } } }
      Recipes.carry(previous, fresh)
      assert.same({ [2963] = 2996 }, fresh.recipes)
      assert.same({ 2963 }, fresh.recipeOrder)
      assert.equals(90, fresh.recipesBase)
      assert.equals(100, fresh.recipesAt)
      assert.same({ name = "Enchanting", rank = 290, max = 300, link = "trade:x:1:333", linkType = "long",
                    scannedAt = 100 }, fresh.professions[333])
    end)
  end)

  describe("recipes on the wire", function()
    local function scanned()
      local c = char()
      Recipes.apply(c, { entries = entries() }, 500)
      c.recipeLines = { [2963] = 197 }
      return c
    end

    it("sends the full list to someone who holds nothing, without the stored fields", function()
      local c = scanned()
      local out = Recipes.outgoing(c)
      assert.is_nil(out.recipes)
      assert.is_nil(out.recipeOrder)
      assert.is_nil(out.recipeLines)
      assert.equals(0, out.recipesFrom)
      assert.same({ 2963, 7421, 1229504 }, out.recipeIds)
      assert.same({ 2996, 0, 279972 }, out.recipeItems)
      assert.equals(3, out.recipeCount)
      assert.equals(500, out.recipesBase)
      assert.equals(500, out.recipesAt)
      assert.equals(c.professions, out.professions)
      assert.is_not_nil(c.recipes) -- the stored character keeps them
    end)

    it("sends only the tail after the asker's count of the same base", function()
      local out = Recipes.outgoing(scanned(), { 2, 500 })
      assert.equals(2, out.recipesFrom)
      assert.same({ 1229504 }, out.recipeIds)
      assert.same({ 279972 }, out.recipeItems)
      assert.equals(0, Recipes.outgoing(scanned(), { 2, 499 }).recipesFrom) -- another base
      assert.equals(0, Recipes.outgoing(scanned(), { 4, 500 }).recipesFrom) -- more than we have
      local all = Recipes.outgoing(scanned(), { 3, 500 })
      assert.equals(3, all.recipesFrom)
      assert.same({}, all.recipeIds)
    end)

    it("sends no recipe fields for a character without recipes", function()
      local out = Recipes.outgoing(char())
      assert.is_nil(out.recipesFrom)
      assert.is_nil(out.recipesBase)
    end)

    it("tells what it holds per character for a REQ", function()
      assert.same({ G1 = { 3, 500 } }, Recipes.have({ G1 = scanned(), G2 = char() }))
      assert.is_nil(Recipes.have({ G2 = char() }))
      assert.same({ G1 = { 3, 500 } }, Recipes.cleanHave({ G1 = { 3, 500 }, G2 = { -1, 5 }, G3 = "x", [4] = { 1, 1 } }))
      assert.is_nil(Recipes.cleanHave("x"))
    end)

    -- What a receiver stores from what it held (stored) and a received character.
    local function receive(stored, sent)
      Recipes.clean(sent)
      Recipes.receive(stored, sent)
      return sent
    end

    it("stores a full list, then appends a tail that fits", function()
      local owner = scanned()
      local got = receive(nil, Recipes.outgoing(owner))
      assert.same(owner.recipes, got.recipes)
      assert.same(owner.recipeOrder, got.recipeOrder)
      assert.equals(500, got.recipesBase)
      assert.is_nil(got.recipeIds)
      assert.is_nil(got.recipesFrom)
      local list = entries()
      list[4].learned = true
      Recipes.apply(owner, { entries = list }, 600)
      local tail = Recipes.outgoing(owner, Recipes.have({ g = got }).g)
      assert.same({ 3914 }, tail.recipeIds)
      local next = receive(got, tail)
      assert.same(owner.recipes, next.recipes)
      assert.same(owner.recipeOrder, next.recipeOrder)
      assert.equals(600, next.recipesAt)
    end)

    it("keeps what it holds when a tail doesn't fit", function()
      local owner = scanned()
      local got = receive(nil, Recipes.outgoing(owner))
      local held = { recipes = { [1] = 0, [2] = 0 }, recipeOrder = { 1, 2 }, recipesBase = 500, recipesAt = 1 }
      local tail = Recipes.outgoing(owner, { 1, 500 }) -- made for someone else's count
      local kept = receive(held, tail)
      assert.same({ [1] = 0, [2] = 0 }, kept.recipes)
      assert.same({ 1, 2 }, kept.recipeOrder)
      local other = receive(got, Recipes.outgoing(owner, { 3, 500 }))
      assert.same(owner.recipes, other.recipes)
    end)

    it("keeps what it holds when a record has no recipes (an older client)", function()
      local got = receive(nil, Recipes.outgoing(scanned()))
      local kept = receive(got, { name = "x" })
      assert.same(got.recipes, kept.recipes)
      assert.same(got.recipeOrder, kept.recipeOrder)
    end)

    it("replaces everything on a new base", function()
      local owner = scanned()
      local got = receive(nil, Recipes.outgoing(owner))
      local list = entries()
      table.remove(list, 1)
      Recipes.apply(owner, { entries = list }, 600)
      local full = Recipes.outgoing(owner, Recipes.have({ g = got }).g)
      assert.equals(0, full.recipesFrom)
      local next = receive(got, full)
      assert.same({ [7421] = 0, [1229504] = 279972 }, next.recipes)
      assert.equals(600, next.recipesBase)
    end)
  end)

  describe("clean", function()
    it("keeps valid fields and recomputes the link type; never keeps recipeLines", function()
      local c = { professions = { [197] = { name = "Tailoring", link = SHORT, linkType = "long", scannedAt = 5,
                                            spec = "Mooncloth Tailor" } },
                  recipes = { [2963] = 2996, [7421] = 0 }, recipeOrder = { 7421, 2963 }, recipesBase = 4,
                  recipesAt = 5, recipeLines = { [2963] = 197 } }
      Recipes.clean(c)
      assert.equals("short", c.professions[197].linkType)
      assert.equals(SHORT, c.professions[197].link)
      assert.same({ [2963] = 2996, [7421] = 0 }, c.recipes)
      assert.same({ 7421, 2963 }, c.recipeOrder)
      assert.is_nil(c.recipeLines)
    end)

    it("drops bad links, times, specs and recipe fields", function()
      local c = { professions = { [197] = { link = "item:1", linkType = "short", scannedAt = "x",
                                            spec = string.rep("a", 60) } },
                  recipes = { [2963] = "bolt" }, recipeOrder = { 2963 }, recipesBase = 1, recipesAt = "x" }
      Recipes.clean(c)
      assert.same({}, c.professions[197])
      assert.is_nil(c.recipes)
      assert.is_nil(c.recipeOrder)
      assert.is_nil(c.recipesBase)
      assert.is_nil(c.recipesAt)
    end)

    it("drops a tail of the wrong shape", function()
      local bad = {
        { recipesFrom = 0, recipeIds = { 1, 2 }, recipeItems = { 0 }, recipeCount = 2, recipesBase = 1 },
        { recipesFrom = 0, recipeIds = { 1 }, recipeItems = { 0 }, recipeCount = 5, recipesBase = 1 },
        { recipesFrom = -1, recipeIds = { 1 }, recipeItems = { 0 }, recipeCount = 0, recipesBase = 1 },
        { recipesFrom = 0, recipeIds = { "x" }, recipeItems = { 0 }, recipeCount = 1, recipesBase = 1 },
        { recipesFrom = 0, recipeIds = { 1 }, recipeItems = { 0 }, recipeCount = 1 },
      }
      for _, c in ipairs(bad) do
        Recipes.clean(c)
        assert.is_nil(c.recipesFrom)
        assert.is_nil(c.recipeIds)
      end
    end)

    it("drops a list that is too big", function()
      local ids, items = {}, {}
      for i = 1, Recipes.MAX_RECIPES + 1 do ids[i], items[i] = i, 0 end
      local c = { recipesFrom = 0, recipeIds = ids, recipeItems = items, recipeCount = #ids, recipesBase = 1 }
      Recipes.clean(c)
      assert.is_nil(c.recipeIds)
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
