-- Window: the launch checklist (CF-60), opened with /fp. Per play session the items with their state: OK or
-- FAILED (with what went wrong) for what the probe judges itself, Yes / No buttons for what you check by eye.
-- Below: the test buttons and Copy report (the results as text, a fallback to sending the saved file).
local _, ns = ...

local window, content, reportFrame
local lines = {} -- per item: { status, detail }

local LABELS = { pass = "|cff40d040OK|r", fail = "|cffff5050FAILED|r", yes = "|cff40d040yes|r",
                 no = "|cffff5050no|r", info = "|cffd8c890check|r" }

local function resultOf(id)
  return FriendProbeDB and FriendProbeDB.results and FriendProbeDB.results[id]
end

local function stateText(item)
  local r = resultOf(item.id)
  if not r then return "|cff909090open|r", item.how or "" end
  return LABELS[r.status] or tostring(r.status), (r.detail or "") .. (r.later and ("  (later: " .. r.later .. ")") or "")
end

-- The results as text, per session (Copy report).
function ns.report()
  local out = { "FriendProbe launch checklist" .. (GetUnitName and (" \226\128\148 " .. tostring(GetUnitName("player",
    true))) or "") }
  for s, title in ipairs(ns.sessions) do
    out[#out + 1] = ""
    out[#out + 1] = s .. ". " .. title
    for _, item in ipairs(ns.items) do
      if item.session == s then
        local r = resultOf(item.id)
        out[#out + 1] = string.format("  %-12s %-6s %s%s", item.id, r and r.status or "open",
          r and (r.detail or "") or "", r and r.char and (" [" .. r.char .. " " .. (r.at or "") .. "]") or "")
      end
    end
  end
  return table.concat(out, "\n")
end

local function showReport()
  if not reportFrame then
    reportFrame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    reportFrame:SetSize(620, 420)
    reportFrame:SetPoint("CENTER", 40, -20)
    reportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    local title = reportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -6)
    title:SetText("Copy report: Ctrl+C, then paste it to Nico")
    local scroll = CreateFrame("ScrollFrame", nil, reportFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
    box:SetWidth(560)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() reportFrame:Hide() end)
    scroll:SetScrollChild(box)
    reportFrame.box = box
  end
  reportFrame.box:SetText(ns.report())
  reportFrame:Show()
  reportFrame.box:SetFocus()
  reportFrame.box:HighlightText()
end

local function create()
  window = CreateFrame("Frame", "FriendProbeChecklist", UIParent, "BasicFrameTemplateWithInset")
  window:SetSize(720, 580)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  local title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -6)
  title:SetText("FriendProbe: launch checklist (runs by itself until 18 Nov; send Nico the saved file)")

  local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -32)
  scroll:SetPoint("BOTTOMRIGHT", -32, 48)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(660, 10)
  scroll:SetScrollChild(content)

  local y = 0
  for s, sessionTitle in ipairs(ns.sessions) do
    local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h:SetPoint("TOPLEFT", 0, -y)
    h:SetText(s .. ". " .. sessionTitle)
    y = y + 26
    for _, item in ipairs(ns.items) do
      if item.session == s then
        local status = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        status:SetPoint("TOPLEFT", 0, -y)
        status:SetWidth(64)
        status:SetJustifyH("LEFT")
        local name = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("TOPLEFT", 68, -y)
        name:SetWidth(470)
        name:SetJustifyH("LEFT")
        name:SetText(item.id .. ": " .. item.title .. (item.friend and "  |cffd8c890(needs a friend)|r" or ""))
        local detail = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        detail:SetPoint("TOPLEFT", 68, -(y + 16))
        detail:SetWidth(470)
        detail:SetJustifyH("LEFT")
        lines[item.id] = { status = status, detail = detail, item = item }
        if not item.auto then
          for i, answer in ipairs({ "Yes", "No" }) do
            local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            b:SetSize(48, 20)
            b:SetPoint("TOPLEFT", 550 + (i - 1) * 54, -y)
            b:SetText(answer)
            b:SetScript("OnClick", function() ns.result(item.id, answer == "Yes" and "yes" or "no", "marked by hand") end)
          end
        end
        y = y + 40
      end
    end
    y = y + 6
  end
  content:SetHeight(y)

  local previous
  local buttons = { { text = "Copy report", run = showReport } }
  for _, t in ipairs(ns.tests or {}) do buttons[#buttons + 1] = t end
  for _, def in ipairs(buttons) do
    local b = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    b:SetSize(math.max(100, #def.text * 7 + 20), 24)
    if previous then b:SetPoint("LEFT", previous, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", 14, 14) end
    b:SetText(def.text)
    b:SetScript("OnClick", def.run)
    previous = b
  end
  if UISpecialFrames then table.insert(UISpecialFrames, "FriendProbeChecklist") end -- Esc closes it
end

-- Updates the states shown (after each result).
function ns.refresh()
  if not window or not window:IsShown() then return end
  for _, line in pairs(lines) do
    local state, detail = stateText(line.item)
    line.status:SetText(state)
    line.detail:SetText(detail)
  end
end

function ns.toggleWindow()
  if not window then create() end
  if window:IsShown() then
    window:Hide()
  else
    window:Show()
    ns.refresh()
  end
end
