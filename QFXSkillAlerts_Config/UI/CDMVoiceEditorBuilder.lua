local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.CDMVoiceEditorBuilder = NS.UI.CDMVoiceEditorBuilder or {}

local Builder = NS.UI.CDMVoiceEditorBuilder
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local Controller = NS.Core.CDMVoiceEditorController
local L = NS.L or function(key) return tostring(key) end

local function Label(parent, text, template)
    return Widgets:CreateLabel(parent, text, template or "GameFontHighlight")
end

function Builder:Ensure()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "QFXSkillAlertsCDMVoiceEditorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1040, 650)
    frame:SetPoint("CENTER", UIParent, "CENTER", 70, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(130)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    Widgets:ApplyPanelChrome(frame, { footerHeight = 34 })
    tinsert(UISpecialFrames, frame:GetName())

    frame.title = Label(frame, L("CDM_VOICE_EDITOR_TITLE"), "GameFontNormalLarge")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -18)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() frame:Hide() end)
    if Skin and Skin.SkinCloseButton then Skin:SkinCloseButton(close) end

    frame.classLabel = Label(frame, L("CDM_CURRENT_CLASS"))
    frame.classLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -54)
    frame.classValue = Label(frame, "", "GameFontNormal")
    frame.classValue:SetPoint("LEFT", frame.classLabel, "RIGHT", 6, 0)

    frame.specLabel = Label(frame, L("CDM_CURRENT_SPEC"))
    frame.specLabel:SetPoint("LEFT", frame.classValue, "RIGHT", 32, 0)
    frame.specValue = Label(frame, "", "GameFontNormal")
    frame.specValue:SetPoint("LEFT", frame.specLabel, "RIGHT", 6, 0)

    frame.categoryLabel = Label(frame, L("CDM_CATEGORY"))
    frame.categoryLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -86)
    frame.categoryDropdown = Widgets:CreateDropdown(frame, nil, 260)
    frame.categoryDropdown:SetPoint("LEFT", frame.categoryLabel, "RIGHT", 10, 0)
    frame.categoryDropdown.qfxsaOnValueChanged = function(value)
        Controller:OnCategoryChanged(value)
    end

    local headerY = -126
    local headers = {
        { text = L("CDM_SKILL"), x = 28, width = 215 },
        { text = L("CDM_EVENT"), x = 255, width = 175 },
        { text = L("CDM_CUSTOM_VOICE"), x = 440, width = 260 },
        { text = L("CDM_ACTION"), x = 700, width = 200 },
    }
    frame.headers = {}
    for _, item in ipairs(headers) do
        local header = Label(frame, item.text, "GameFontNormal")
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", item.x, headerY)
        header:SetWidth(item.width)
        header:SetJustifyH("LEFT")
        frame.headers[#frame.headers + 1] = header
    end

    frame.RefreshLocale = function(selfFrame)
        selfFrame.title:SetText(L("CDM_VOICE_EDITOR_TITLE"))
        selfFrame.classLabel:SetText(L("CDM_CURRENT_CLASS"))
        selfFrame.specLabel:SetText(L("CDM_CURRENT_SPEC"))
        selfFrame.categoryLabel:SetText(L("CDM_CATEGORY"))
        selfFrame.headers[1]:SetText(L("CDM_SKILL"))
        selfFrame.headers[2]:SetText(L("CDM_EVENT"))
        selfFrame.headers[3]:SetText(L("CDM_CUSTOM_VOICE"))
        selfFrame.headers[4]:SetText(L("CDM_ACTION"))
        selfFrame.syncButton:SetText(L("CDM_APPLY_ALL_RELOAD"))
        selfFrame.exportButton:SetText(L("CDM_EXPORT_PRESETS"))
        selfFrame.closeButton:SetText(L("BTN_CLOSE"))
    end

    frame.scrollHost, frame.scrollContent, frame.scrollFrame, frame.scrollSlider = Widgets:CreateScrollableContent(frame, {
        contentHeight = 1,
        bottomPadding = 0,
        wheelStep = 50,
    })
    frame.scrollHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -148)
    frame.scrollHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 82)

    frame.statusText = Label(frame, "", "GameFontHighlightSmall")
    frame.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 55)
    frame.statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 55)
    frame.statusText:SetJustifyH("LEFT")

    frame.syncButton = Widgets:CreateButton(frame, L("CDM_APPLY_ALL_RELOAD"), 190, 30)
    frame.syncButton:SetPoint("BOTTOM", frame, "BOTTOM", -210, 14)
    frame.syncButton:SetScript("OnClick", function()
        Controller:ApplyAllAndReload()
    end)

    frame.exportButton = Widgets:CreateButton(frame, L("CDM_EXPORT_PRESETS"), 190, 30)
    frame.exportButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    frame.exportButton:SetScript("OnClick", function()
        Controller:ExportPresets()
    end)

    frame.closeButton = Widgets:CreateButton(frame, L("BTN_CLOSE"), 100, 30)
    frame.closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 170, 14)
    frame.closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnShow", function()
        Controller:Refresh("show")
    end)
    self.frame = frame
    return frame
end
