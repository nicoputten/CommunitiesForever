-- ProbeReport (CF-82): the hidden /cf fp dialog. The launch probe's report in a text field to copy (Ctrl+A, Ctrl+C).
-- Only opens on /cf fp; the probe itself never shows anything.
local _, ns = ...

local ProbeReport = {}
local Theme, Kit = ns.Theme, ns.Kit

local dialog, box

local function create()
  dialog = Kit.dialog({ title = "Launch probe", width = 640, height = 460 })
  -- UIPanelScrollFrameTemplate is Blizzard's (VERIFY.md CF-82); without it the field still copies everything.
  local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, dialog.content, "UIPanelScrollFrameTemplate")
  box = CreateFrame("EditBox", nil, ok and scroll or dialog.content)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  Theme.font(box, "small")
  box:SetTextColor(Theme.color("text"))
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if ok and scroll then
    scroll:SetPoint("TOPLEFT", 16, -12)
    scroll:SetPoint("BOTTOMRIGHT", -36, 12)
    box:SetWidth(580)
    scroll:SetScrollChild(box)
  else
    box:SetPoint("TOPLEFT", 16, -12)
    box:SetPoint("BOTTOMRIGHT", -16, 12)
  end
end

-- Shows the report lines, selected for copying.
function ProbeReport.show(lines)
  if not dialog then create() end
  box:SetText(table.concat(lines, "\n"))
  dialog:Show()
  box:SetFocus()
  box:HighlightText()
end

-- The text shown (specs).
function ProbeReport.text() return box and box:GetText() end

ns.ProbeReport = ProbeReport
return ProbeReport
