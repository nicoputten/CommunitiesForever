--[[ TradeSkill (CF-38): reads the own open profession window and opens or links a profession link. Thin wrapper:
raw values only, the rules are in core/Recipes.lua.
Verified on Forever (API-FINDINGS "Forever launch probe" V60, V60b, V104): C_TradeSkillUI.GetAllRecipeIDs (every
profession at once), GetRecipeInfo(id).learned, GetRecipeOutputItemData(id).itemID, GetBaseProfessionInfo()
.professionID, GetTradeSkillListLink, IsTradeSkillLinked, NEW_RECIPE_LEARNED, SKILL_LINES_CHANGED, IsSpellKnown.
Unverified, guarded (VERIFY.md CF-38): GetTradeSkillLineForRecipe (V60c), TRADE_SKILL_CLOSE, the specialisation
spells, ChatEdit_InsertLink / ChatFrameUtil.InsertLink and ChatFrame_OpenChat, SetItemRef on a friend offline. ]]
local _, ns = ...

local TradeSkill = {}

local call = ns.Safe.call

-- Events that may change what a scan reads. TRADE_SKILL_CLOSE only marks the window closed.
TradeSkill.EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED",
                      "TRADE_SKILL_CLOSE" }

-- Vanilla specialisations by skill line: { spell ID, English name }, the most specific first (a Master Swordsmith is
-- also a Weaponsmith). Read with IsSpellKnown (verified, V82); the spell IDs are unverified on Forever (VERIFY.md).
TradeSkill.SPECS = {
  [164] = { { 17039, "Master Swordsmith" }, { 17040, "Master Hammersmith" }, { 17041, "Master Axesmith" },
            { 9787, "Weaponsmith" }, { 9788, "Armorsmith" } },
  [165] = { { 10656, "Dragonscale Leatherworking" }, { 10658, "Elemental Leatherworking" },
            { 10660, "Tribal Leatherworking" } },
  [202] = { { 20219, "Gnomish Engineer" }, { 20222, "Goblin Engineer" } },
}

-- C_TradeSkillUI[name] when it is a function (looked up guarded: the table may be odd on a new client).
local function api(name)
  local T = C_TradeSkillUI
  if type(T) ~= "table" then return nil end
  local ok, fn = pcall(function() return T[name] end)
  return ok and type(fn) == "function" and fn or nil
end

-- The skill line of a recipe from GetTradeSkillLineForRecipe (V60c): the parent line when it gives one, else the
-- line; nil when it is missing or answers nothing.
local function recipeLine(id)
  local fn = api("GetTradeSkillLineForRecipe")
  if not fn then return nil end
  local line, _, parent = call(fn, id)
  if type(parent) == "number" and parent > 0 then return parent end
  if type(line) == "number" and line > 0 then return line end
  return nil
end

local function spec(line)
  local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
  if not known then return nil end
  for _, s in ipairs(TradeSkill.SPECS[line] or {}) do
    if call(known, s[1]) == true then return s[2] end
  end
  return nil
end

--[[ What the profession window shows now, for Recipes.apply: { entries, profession, link, spec }, or nil for a
linked view (someone else's recipes, IsTradeSkillLinked) or without C_TradeSkillUI.
open: the own window is open (TRADE_SKILL_SHOW seen since the last TRADE_SKILL_CLOSE); without it only the recipe
list is read (a recipe learned with the window closed), never a profession or link. ]]
function TradeSkill.read(open)
  local linked = api("IsTradeSkillLinked")
  if not linked or call(linked) == true then return nil end
  local scan = {}
  local ids = api("GetAllRecipeIDs") and call(api("GetAllRecipeIDs"))
  local infoOf, outputOf = api("GetRecipeInfo"), api("GetRecipeOutputItemData")
  if type(ids) == "table" and infoOf then
    scan.entries = {}
    for _, id in ipairs(ids) do
      local info = call(infoOf, id)
      if type(info) == "table" and info.learned == true then
        local output = outputOf and call(outputOf, id)
        scan.entries[#scan.entries + 1] = { id = id, learned = true,
          itemID = type(output) == "table" and output.itemID or nil, line = recipeLine(id) }
      end
    end
  end
  if open then
    local base = api("GetBaseProfessionInfo") and call(api("GetBaseProfessionInfo"))
    scan.profession = type(base) == "table" and base.professionID or nil
    scan.link = api("GetTradeSkillListLink") and call(api("GetTradeSkillListLink"))
    if type(scan.profession) == "number" then scan.spec = spec(scan.profession) end
  end
  return scan
end

-- Calls handler(event) on each of EVENTS the client knows.
function TradeSkill.watch(handler)
  local events = LibStub("AceEvent-3.0"):Embed({})
  for _, event in ipairs(TradeSkill.EVENTS) do
    ns.Events.register(events, event, function() handler(event) end)
  end
end

-- A click on a profession link: Blizzard's own window with that character's recipes (V60b: works while they are
-- online; offline is VERIFY.md V60b).
function TradeSkill.open(link, text)
  if not (SetItemRef and type(link) == "string") then return false end
  return pcall(SetItemRef, link, text, "LeftButton") == true
end

-- Shift-click: the link into the open chat box, or a new one opened with it. True when one of them exists.
function TradeSkill.insert(chatLink)
  if type(chatLink) ~= "string" then return false end
  local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
  if insert and call(insert, chatLink) then return true end
  local openChat = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if openChat then
    call(openChat, chatLink)
    return true
  end
  return false
end

ns.TradeSkill = TradeSkill
return TradeSkill
