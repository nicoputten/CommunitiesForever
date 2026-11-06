local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-38: the profession scan against the WoW mock, and the Friends tab's profession links (RC07).
describe("RecipeTracker and profession links (CF-38)", function()
  local state, ns, addon, trade, calls

  local VES = "Player-4619-01627852"
  local LINK = "trade:" .. VES .. ":2550:185"
  local FULL = "|cffffd000|H" .. LINK .. "|h[Cooking]|h|r"

  local function char() return addon.db.global.self.chars[VES] end

  local function fire(event, ...) wowapi.fireEvent(state, event, ...) end

  before_each(function()
    calls = { itemRef = {}, insert = {} }
    trade = { linked = false, profession = 185, link = FULL,
              recipes = { { id = 2538, learned = true, item = 2679 }, { id = 2963, learned = true, item = 2996 },
                          { id = 3914, learned = false, item = 4307 } } }
    state, ns, addon = helpers.client({ setup = function()
      wowapi.activate({
        C_TradeSkillUI = {
          IsTradeSkillLinked = function() return trade.linked end,
          GetAllRecipeIDs = function()
            local ids = {}
            for _, r in ipairs(trade.recipes) do ids[#ids + 1] = r.id end
            return ids
          end,
          GetRecipeInfo = function(id)
            for _, r in ipairs(trade.recipes) do
              if r.id == id then return { recipeID = id, learned = r.learned } end
            end
          end,
          GetRecipeOutputItemData = function(id)
            for _, r in ipairs(trade.recipes) do
              if r.id == id then return { itemID = r.item } end
            end
          end,
          GetBaseProfessionInfo = function() return { professionID = trade.profession } end,
          GetTradeSkillListLink = function() return trade.link end,
        },
        SetItemRef = function(link, text, button) calls.itemRef[#calls.itemRef + 1] = { link, text, button } end,
        ChatEdit_InsertLink = function(text)
          calls.insert[#calls.insert + 1] = text
          return true
        end,
        IsShiftKeyDown = function() return calls.shift == true end,
      })
    end })
  end)

  after_each(function()
    wowapi.uninstall()
  end)

  it("stores the learned recipes, the link and scannedAt on TRADE_SKILL_SHOW, and bumps the version", function()
    local before = addon.db.global.self.version
    state.time = 100
    state.serverTime = state.serverTime + 60
    fire("TRADE_SKILL_SHOW")
    assert.same({ [2538] = 2679, [2963] = 2996 }, char().recipes)
    assert.equals(state.serverTime, char().recipesAt)
    assert.equals(LINK, char().professions[185].link)
    assert.equals("short", char().professions[185].linkType)
    assert.equals(state.serverTime, char().professions[185].scannedAt)
    assert.is_nil(char().professions[186].link) -- Mining: untouched, and gathering has no link
    assert.is_true(addon.db.global.self.version > before)
  end)

  it("keeps the scan fields when the snapshot refreshes (a skill-up)", function()
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    fire("PLAYER_LEVEL_UP", 12)
    assert.equals(LINK, char().professions[185].link)
    assert.same({ [2538] = 2679, [2963] = 2996 }, char().recipes)
  end)

  it("scans at most once per second, with one later scan", function()
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    trade.recipes[3].learned = true
    state.time = 100.4
    fire("NEW_RECIPE_LEARNED", 3914)
    fire("TRADE_SKILL_LIST_UPDATE")
    assert.is_nil(char().recipes[3914])
    state.time = 101
    wowapi.runTimers(state)
    assert.equals(4307, char().recipes[3914])
  end)

  it("learns a recipe with the window closed without touching the link", function()
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    fire("TRADE_SKILL_CLOSE")
    trade.recipes[3].learned = true
    trade.link = nil
    state.time = 105
    fire("NEW_RECIPE_LEARNED", 3914)
    assert.equals(4307, char().recipes[3914])
    assert.equals(LINK, char().professions[185].link)
  end)

  it("never stores a friend's linked view, also not after it closed", function()
    trade.linked = true
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    assert.is_nil(char().recipes)
    fire("TRADE_SKILL_CLOSE")
    trade.linked = false
    state.time = 110
    fire("SKILL_LINES_CHANGED")
    assert.is_nil(char().recipes)
  end)

  it("keeps the stored set when the list is still empty (CF-100)", function()
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    trade.recipes = {}
    state.time = 110
    fire("TRADE_SKILL_LIST_UPDATE")
    assert.same({ [2538] = 2679, [2963] = 2996 }, char().recipes)
  end)

  it("leaves the recipe set out of the record but sends the link", function()
    state.time = 100
    fire("TRADE_SKILL_SHOW")
    local record = ns.Merge.outgoingRecord(addon.db.global.self)
    assert.is_nil(record.chars[VES].recipes)
    assert.equals(LINK, record.chars[VES].professions[185].link)
    assert.is_not_nil(char().recipes)
  end)

  describe("Friends tab (RC07)", function()
    local function cells()
      local out = {}
      for _, b in ipairs(ns.FriendsTab.professionLinks()) do out[b.text:GetText()] = b end
      return out
    end

    local function openVes()
      ns.MainFrame.toggle()
      local tab = helpers.friendsTab(ns)
      tab.click(tab.row("Vestras#1000\001" .. VES))
    end

    it("shows not scanned with its tooltip before the first scan, nothing for Mining", function()
      openVes()
      local c = cells()
      assert.is_not_nil(c["not scanned"])
      assert.same({ "Opens once Vestras opens Cooking in game" }, c["not scanned"].cell.tip.lines)
      assert.equals(1, #ns.FriendsTab.professionLinks())
    end)

    it("shows the link; a click opens it, a shift-click puts it in chat", function()
      state.time = 100
      fire("TRADE_SKILL_SHOW")
      openVes()
      local link = cells()["[Cooking]"]
      assert.is_not_nil(link)
      assert.same({ "Click: open in game", "Shift-click: link in chat" }, link.cell.tip.lines)
      link:RunScript("OnClick", "LeftButton")
      assert.same({ { LINK, FULL, "LeftButton" } }, calls.itemRef)
      calls.shift = true
      link:RunScript("OnClick", "LeftButton")
      assert.same({ FULL }, calls.insert)
      assert.equals(1, #calls.itemRef)
    end)
  end)
end)
