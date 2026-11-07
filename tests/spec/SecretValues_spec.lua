local helpers = require("helpers")
local wowapi = require("mocks.wowapi")

-- CF-108: in combat Midnight hands some event arguments to addons as secret values. Any comparison, concatenation,
-- arithmetic or string function on one throws ("attempt to compare ... a secret string value"). The stand-in below
-- throws on everything Lua 5.1 lets a value hook: <, <=, .., #, indexing, calls, arithmetic and string functions
-- (they reject a table). Lua never calls __eq between a table and a string, so `secret == "x"` cannot throw here;
-- Safe.text covers that order directly.
describe("Secret event arguments (CF-108)", function()
  local realType = type
  local SECRET, secretType

  local function throws(what) return function() error("attempt to " .. what .. " a secret value", 2) end end
  SECRET = setmetatable({}, {
    __eq = throws("compare"), __lt = throws("compare"), __le = throws("compare"), __concat = throws("concatenate"),
    __len = throws("get length of"), __index = throws("index"), __newindex = throws("index"),
    __call = throws("call"), __add = throws("perform arithmetic on"), __sub = throws("perform arithmetic on"),
    __mul = throws("perform arithmetic on"), __div = throws("perform arithmetic on"),
    __mod = throws("perform arithmetic on"), __unm = throws("perform arithmetic on"),
    __tostring = function() return "<secret>" end,
  })

  local function isSecret(v) return rawequal(v, SECRET) end

  before_each(function()
    secretType = "string"
    _G.issecretvalue = isSecret
    -- On Midnight type() of a secret gives the hidden value's type.
    _G.type = function(v)
      if rawequal(v, SECRET) then return secretType end
      return realType(v)
    end
  end)

  after_each(function()
    _G.type = realType
    _G.issecretvalue = nil
    wowapi.uninstall()
  end)

  local function secrets(n)
    local list = {}
    for i = 1, n do list[i] = SECRET end
    return list
  end

  -- Names of the internal messages that carried a secret value on.
  local function forwarded(state, from)
    local list = {}
    for i = from + 1, #state.sent do
      local entry = state.sent[i]
      for j = 2, table.maxn(entry) do
        if rawequal(entry[j], SECRET) then list[#list + 1] = entry[1] end
      end
    end
    return list
  end

  local function fireAll(state, args)
    local failures = {}
    local events = {}
    for event in pairs(state.eventHandlers) do events[#events + 1] = event end
    table.sort(events)
    for _, event in ipairs(events) do
      local ok, err = pcall(wowapi.fireEvent, state, event, unpack(args, 1, 15))
      if not ok then failures[#failures + 1] = event .. ": " .. tostring(err) end
    end
    local ok, err = pcall(wowapi.runTimers, state)
    if not ok then failures[#failures + 1] = "timers: " .. tostring(err) end
    return failures
  end

  for _, kind in ipairs({ "string", "number" }) do
    it("no event handler throws on secret " .. kind .. " arguments or forwards them", function()
      local state = helpers.client()
      secretType = kind
      assert.is_not_nil(state.eventHandlers.CHAT_MSG_SKILL) -- the reported error's event (WorldEvents onSkill)
      local from = #state.sent
      local failures = fireAll(state, secrets(15))
      local carried = forwarded(state, from)
      _G.type = realType
      assert.are.same({}, failures)
      assert.are.same({}, carried)
    end)
  end

  it("handles a secret chat message as CHAT_MSG_SKILL's first argument", function()
    local state = helpers.client()
    local ok, err = pcall(wowapi.fireEvent, state, "CHAT_MSG_SKILL", SECRET)
    _G.type = realType
    assert.is_true(ok, tostring(err))
  end)

  describe("Safe", function()
    local Safe

    before_each(function()
      local ns = {}
      Safe = helpers.loadAddonFile("src/adapters/Safe.lua", ns)
    end)

    it("text checks for a secret before comparing", function()
      local seen = {}
      _G.issecretvalue = function(v)
        seen[#seen + 1] = v
        return v == "hidden"
      end
      -- A secret that is a real string: had the comparison come first, "hidden" ~= "" would run and the secret
      -- check would be second.
      assert.is_false(Safe.text("hidden"))
      assert.are.same({ "hidden" }, seen)
      _G.issecretvalue = isSecret
      assert.is_false(Safe.text(SECRET))
      assert.is_true(Safe.text("Your Swords skill has increased to 12."))
      assert.is_false(Safe.text(""))
      assert.is_false(Safe.text(nil))
    end)

    it("values turns secret arguments into nil and keeps the rest", function()
      local a, b, c, d = Safe.values("x", SECRET, nil, 4)
      assert.are.equal("x", a)
      assert.is_nil(b)
      assert.is_nil(c)
      assert.are.equal(4, d)
      assert.are.equal(0, select("#", Safe.values()))
      assert.are.equal(3, select("#", Safe.values(SECRET, SECRET, SECRET)))
    end)
  end)
end)
