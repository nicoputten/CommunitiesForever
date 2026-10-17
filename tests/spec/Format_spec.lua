local helpers = require("helpers")

describe("Format", function()
  local Format
  local NOW = 100000

  local function charRow(overrides)
    local row = { guid = "G1", name = "Garraka", classFile = "MAGE", classID = 8, level = 11, ilvl = 20,
                  online = true, zone = "Orgrimmar", realm = "Classic Beta PvP",
                  professions = { [186] = { name = "Mining", rank = 64, max = 150 },
                                  [185] = { name = "Cooking", rank = 2, max = 75 } } }
    for k, v in pairs(overrides or {}) do row[k] = v end
    return row
  end

  local function person(overrides)
    local p = { battleTag = "Sjaakovich#2232", displayName = "Sjaak", isSelf = false, online = true,
                chars = { charRow() } }
    p.currentChar = p.chars[1]
    for k, v in pairs(overrides or {}) do p[k] = v end
    return p
  end

  local function state(overrides)
    local s = { communitySelected = true, collapsed = {}, now = NOW }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
  end

  local function kinds(rows)
    local list = {}
    for _, r in ipairs(rows) do list[#list + 1] = r.kind end
    return list
  end

  before_each(function()
    Format = helpers.loadAddonFile("src/core/Format.lua", {})
  end)

  describe("ago", function()
    it("formats durations", function()
      assert.are.equal("just now", Format.ago(NOW - 30, NOW))
      assert.are.equal("5 min ago", Format.ago(NOW - 300, NOW))
      assert.are.equal("3 h ago", Format.ago(NOW - 3 * 3600 - 10, NOW))
      assert.are.equal("2 d ago", Format.ago(NOW - 2 * 86400, NOW))
      assert.are.equal("never", Format.ago(nil, NOW))
      assert.are.equal("just now", Format.ago(NOW + 50, NOW)) -- clock skew
    end)
  end)

  describe("professions", function()
    it("lists rank/max sorted by name", function()
      assert.are.equal("Cooking 2/75, Mining 64/150", Format.professions(charRow().professions))
      assert.are.equal("", Format.professions(nil))
      assert.are.equal("", Format.professions({}))
    end)
  end)

  describe("status", function()
    it("shows online with zone, else last seen, else offline", function()
      assert.are.equal("Online - Orgrimmar", Format.status(charRow(), NOW))
      assert.are.equal("Online", Format.status(charRow({ zone = "" }), NOW))
      assert.are.equal("Seen 2 h ago", Format.status(charRow({ online = false, lastSeen = NOW - 7200 }), NOW))
      assert.are.equal("Seen 5 min ago",
        Format.status(charRow({ online = false, lastSeen = NOW - 7200, updatedAt = NOW - 300 }), NOW))
      assert.are.equal("Offline", Format.status(charRow({ online = false }), NOW))
    end)
  end)

  describe("rows", function()
    it("shows only the empty state without a selected community", function()
      local rows = Format.rows({ people = {}, unlinked = {} }, state({ communitySelected = false }))
      assert.are.same({ { kind = "empty", text = "Select a community in settings (/cf settings)." } }, rows)
    end)

    it("shows a note when no friend is linked yet", function()
      local me = person({ battleTag = "Vestras#2858", displayName = "Vestras", isSelf = true })
      local rows = Format.rows({ people = { me }, unlinked = {} }, state())
      assert.are.same({ "section", "person", "char", "note" }, kinds(rows))
      assert.are.equal("No linked friends yet.", rows[4].text)
    end)

    it("renders a person header with BattleTag and current character", function()
      local rows = Format.rows({ people = { person() }, unlinked = {} }, state())
      assert.are.same({ kind = "person", key = "Sjaakovich#2232", online = true, expanded = true, isSelf = false,
                        text = "Sjaak (Sjaakovich#2232) - on Garraka" }, rows[2])
    end)

    it("marks offline people, self, and a current character outside the community", function()
      local offline = Format.rows({ people = { person({ online = false, currentChar = false }) }, unlinked = {} },
        state())
      assert.are.equal("Sjaak (Sjaakovich#2232) - offline", offline[2].text)

      local me = Format.rows({ people = { person({ isSelf = true, displayName = "Sjaakovich#2232" }) },
                               unlinked = {} }, state())
      assert.are.equal("Sjaakovich#2232 - you - on Garraka", me[2].text)

      local outside = Format.rows({ people = { person({ currentChar = { name = "Alt", visible = false } }) },
                                    unlinked = {} }, state())
      assert.are.equal("Sjaak (Sjaakovich#2232) - on Alt (not in community)", outside[2].text)
    end)

    it("renders two-line character rows", function()
      local rows = Format.rows({ people = { person() }, unlinked = {} }, state())
      assert.are.same({ kind = "char", guid = "G1", name = "Garraka", classFile = "MAGE", classID = 8,
                        line1 = "Lvl 11  iLvl 20  Online - Orgrimmar",
                        line2 = "Cooking 2/75, Mining 64/150  -  Classic Beta PvP", online = true }, rows[3])
    end)

    it("leaves out missing ilvl, professions and realm", function()
      local p = person({ chars = { charRow({ ilvl = false, professions = {}, realm = false }) } })
      local row = Format.rows({ people = { p }, unlinked = {} }, state())[3]
      assert.are.equal("Lvl 11  Online - Orgrimmar", row.line1)
      assert.are.equal("", row.line2)
    end)

    it("hides characters of a collapsed person", function()
      local rows = Format.rows({ people = { person() }, unlinked = {} },
        state({ collapsed = { ["Sjaakovich#2232"] = true } }))
      assert.are.same({ "section", "person" }, kinds(rows))
      assert.is_false(rows[2].expanded)
    end)

    it("uses key \"self\" for own characters without a BattleTag", function()
      local rows = Format.rows({ people = { person({ battleTag = false, isSelf = true, displayName = "You" }) },
                                 unlinked = {} }, state())
      assert.are.equal("self", rows[2].key)
    end)

    it("renders the Unlinked section with community data only", function()
      local rows = Format.rows({ people = {}, unlinked = {
        { guid = "U1", name = "Stranger", classID = 8, level = 9, online = true, zone = "Durotar" },
        { guid = "U2", name = "Gone", classID = 2, level = 60, online = false, zone = "Silithus" },
      } }, state())
      assert.are.same({ "section", "note", "section", "char", "char" }, kinds(rows))
      assert.are.equal("Unlinked", rows[3].text)
      assert.are.equal("Lvl 9  Online - Durotar", rows[4].line1)
      assert.are.equal("Lvl 60  Offline", rows[5].line1) -- no zone when offline
      assert.are.equal("", rows[5].line2)
    end)
  end)
end)
