local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.CDMVoiceEditorRows = NS.UI.CDMVoiceEditorRows or {}

local Rows = NS.UI.CDMVoiceEditorRows
local Widgets = NS.UI.Widgets
local Controller = NS.Core.CDMVoiceEditorController
local L = NS.L or function(key) return tostring(key) end

local ROW_HEIGHT = 50

local function CreateRow(frame)
    local row = CreateFrame("Frame", nil, frame.scrollContent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", frame.scrollContent, "LEFT", 2, 0)
    row:SetPoint("RIGHT", frame.scrollContent, "RIGHT", -2, 0)
    if row.SetBackdrop then
        row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
        row:SetBackdropColor(0, 0, 0, 0.28)
    end

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(32, 32)
    row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)

    row.skillName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.skillName:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.skillName:SetWidth(205)
    row.skillName:SetJustifyH("LEFT")
    row.skillName:SetWordWrap(false)

    row.eventDropdown = Widgets:CreateDropdown(row, nil, 175)
    row.eventDropdown:SetPoint("LEFT", row, "LEFT", 255, 0)

    row.voiceDropdown = Widgets:CreateDropdown(row, nil, 260)
    row.voiceDropdown:SetPoint("LEFT", row, "LEFT", 440, 0)
    -- Keep the searchable voice list above this editor but below WoW's IME
    -- composition/candidate layer.
    row.voiceDropdown.qfxsaPopupStrata = "FULLSCREEN_DIALOG"
    row.voiceDropdown.qfxsaPopupFrameLevel = 260
    Widgets:SetDropdownSearchable(row.voiceDropdown, true, L("CDM_SEARCH_VOICE"))

    row.testButton = Widgets:CreateButton(row, L("CDM_TEST"), 62, 30)
    row.testButton:SetPoint("LEFT", row, "LEFT", 700, 0)

    row.saveButton = Widgets:CreateButton(row, L("CDM_SAVE"), 62, 30)
    row.saveButton:SetPoint("LEFT", row, "LEFT", 768, 0)

    row.applyButton = Widgets:CreateButton(row, L("CDM_APPLY"), 62, 30)
    row.applyButton:SetPoint("LEFT", row, "LEFT", 836, 0)

    row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.hint:SetPoint("LEFT", row, "LEFT", 904, 0)
    row.hint:SetWidth(110)
    row.hint:SetJustifyH("LEFT")
    row.hint:SetWordWrap(true)

    row.eventDropdown.qfxsaOnValueChanged = function(value)
        Controller:OnEventChanged(row, value)
    end
    row.voiceDropdown.qfxsaOnValueChanged = function(value)
        Controller:OnVoiceChanged(row, value)
    end
    row.testButton:SetScript("OnClick", function()
        Controller:TestRow(row)
    end)
    row.saveButton:SetScript("OnClick", function()
        Controller:SaveRow(row)
    end)
    row.applyButton:SetScript("OnClick", function()
        Controller:ApplyRow(row)
    end)
    row.saveButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("CDM_SAVE_TOOLTIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.saveButton:SetScript("OnLeave", GameTooltip_Hide)
    row.applyButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("CDM_APPLY_TOOLTIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row.applyButton:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

function Rows:Acquire(frame, index)
    frame.rowPool = frame.rowPool or {}
    if not frame.rowPool[index] then
        frame.rowPool[index] = CreateRow(frame)
    end
    return frame.rowPool[index]
end

function Rows:ReleaseAll(frame)
    for _, row in ipairs(frame.rowPool or {}) do
        row:Hide()
    end
end

function Rows:Render(frame, cooldowns, pendingEdit)
    self:ReleaseAll(frame)
    local api = NS.API or {}
    local targetIndex
    for index, info in ipairs(type(cooldowns) == "table" and cooldowns or {}) do
        local row = self:Acquire(frame, index)
        local previousCooldownID = row.cooldownInfo and row.cooldownInfo.cooldownID
        if tonumber(previousCooldownID) ~= tonumber(info.cooldownID) then
            row.recordKey = nil
            row.originalRecordKey = nil
        end
        row.cooldownInfo = info
        row.testButton:SetText(L("CDM_TEST"))
        row.saveButton:SetText(L("CDM_SAVE"))
        row.applyButton:SetText(L("CDM_APPLY"))
        row.icon:SetTexture(info.icon or 134400)
        row.skillName:SetText(tostring(info.spellName or ""))

        local events = type(api.GetCDMVoiceValidEvents) == "function" and api.GetCDMVoiceValidEvents(info.cooldownID) or {}
        local eventItems = {}
        local dirtyDraft = Controller:GetDirtyDraft(Controller.category, info.cooldownID)
        local selectedEvent = dirtyDraft and dirtyDraft.eventType
            or (tonumber(previousCooldownID) == tonumber(info.cooldownID) and row.selectedEvent or nil)
        for _, eventInfo in ipairs(type(events) == "table" and events or {}) do
            eventItems[#eventItems + 1] = { value = eventInfo.eventType, text = eventInfo.name }
        end
        if pendingEdit and tonumber(pendingEdit.cooldownID) == tonumber(info.cooldownID) then
            selectedEvent = pendingEdit.eventType
            targetIndex = index
            row.recordKey = pendingEdit.recordKey
            row.originalRecordKey = pendingEdit.recordKey
        end
        local validSelection = nil
        for _, item in ipairs(eventItems) do
            if tonumber(item.value) == tonumber(selectedEvent) then
                validSelection = item.value
                break
            end
        end
        selectedEvent = validSelection or (eventItems[1] and eventItems[1].value)
        Widgets:SetDropdownItems(row.eventDropdown, eventItems)
        Widgets:SetDropdownValue(row.eventDropdown, selectedEvent, L("CDM_EVENT"))
        Widgets:SetDropdownEnabled(row.eventDropdown, #eventItems > 0)
        row.selectedEvent = selectedEvent
        local requestedPayload = dirtyDraft and dirtyDraft.payload
            or (pendingEdit and targetIndex == index and pendingEdit.payload)
            or (tonumber(previousCooldownID) == tonumber(info.cooldownID) and row.selectedPayload)
        Controller:RefreshRowSelection(row, requestedPayload)
        row.dirty = dirtyDraft ~= nil
        row:ClearAllPoints()
        local rowOffset = -((index - 1) * ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame.scrollContent, "TOPLEFT", 2, rowOffset)
        row:SetPoint("TOPRIGHT", frame.scrollContent, "TOPRIGHT", -2, rowOffset)
        row:Show()
    end
    frame.scrollHost:SetContentHeight(math.max(1, #cooldowns * ROW_HEIGHT))
    frame.scrollHost:UpdateScrollRange()
    if targetIndex and frame.scrollSlider then
        frame.scrollSlider:SetValue(math.max(0, (targetIndex - 1) * ROW_HEIGHT))
    end
end
