local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.EditorFrameBuilder = NS.UI.EditorFrameBuilder or {}

local Builder = NS.UI.EditorFrameBuilder
local Widgets = NS.UI.Widgets
local Skin = NS.UI.Skin
local PopupLayout = NS.UI.PopupLayout
local EditorLayout = NS.UI.EditorLayout or {}
local EditorSoundFields = NS.UI.EditorSoundFields or {}
local EditorActions = NS.UI.EditorActions or {}
local DialogTextArea = NS.UI.DialogTextArea or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local CreateFieldLabel = EditorLayout.CreateFieldLabel
local PlaceControl = EditorLayout.PlaceControl
local PlaceModule = EditorLayout.PlaceModule
local CreateRateSlider = EditorLayout.CreateRateSlider
local CreateValueSlider = EditorLayout.CreateValueSlider
local InstallSpellIdAutofill = EditorLayout.InstallSpellIdAutofill
local InstallTalentIdAutofill = EditorLayout.InstallTalentIdAutofill

local function SetCheckWidth(button, width)
    if not button then
        return
    end
    button.qfxsaMaxWidth = width or 180
    if button.qfxsaLabel and button.qfxsaLabel.SetWidth then
        button.qfxsaLabel:SetWidth(math.max(1, (width or 180) - 30))
    end
end

local function CreateCastConditionControls(parent, createInlineRow, createInlineText, inner, row1Y, row2Y, row3Y, rowH, delayCheckX, delayCheckW, delayLabelX, delayLabelW, delayTimeX, delayTimeW, delayAfterX, delayAfterW, delayModeX, delayModeW, execW, actionDropX, actionDropW)
    local c = {}
    c.row1 = createInlineRow(parent, row1Y)
    c.row2 = createInlineRow(parent, row2Y)
    c.row3 = createInlineRow(parent, row3Y)

    c.immediateEnabled = Widgets:CreateCheckButton(c.row1, L("LABEL_CAST_IMMEDIATE_EXECUTE"), 160)
    c.immediateEnabled:SetPoint("LEFT", c.row1, "LEFT", delayCheckX - inner, 0)
    SetCheckWidth(c.immediateEnabled, 160)

    c.delayEnabled = Widgets:CreateCheckButton(c.row2, L("LABEL_CAST_DELAY_EXECUTE"), delayCheckW)
    c.delayEnabled:SetPoint("LEFT", c.row2, "LEFT", delayCheckX - inner, 0)
    SetCheckWidth(c.delayEnabled, delayCheckW)
    c.delayLabel = createInlineText(c.row2, L("LABEL_CAST_DELAY_FIXED"), delayLabelX - inner, delayLabelW)
    c.delaySeconds = Widgets:CreateEditBox(c.row2, delayTimeW, rowH, false)
    c.delaySeconds:SetPoint("LEFT", c.row2, "LEFT", delayTimeX - inner, 0)
    c.delaySeconds:SetText("0")
    c.delayAfterLabel = createInlineText(c.row2, L("LABEL_CAST_DELAY_AFTER_EXECUTE"), delayAfterX - inner, delayAfterW)

    -- Kept only for old code/import compatibility.  The visible Show/Hide menu was
    -- removed in 1.0.158 because visual lifetime is controlled by the Image/Text
    -- duration checkboxes.
    c.delayModeDrop = Widgets:CreateDropdown(c.row2, "QFXSkillAlertsEditorCastDelayModeDropDown", delayModeW)
    c.delayModeDrop:SetPoint("LEFT", c.row2, "LEFT", delayModeX - inner, 0)
    c.delayModeDrop:Hide()

    c.executeLabel = createInlineText(c.row3, L("LABEL_CONDITION_EXECUTE"), 0, execW)
    if Widgets.CreateMultiSelectDropdown then
        c.actionsDrop = Widgets:CreateMultiSelectDropdown(c.row3, "QFXSkillAlertsEditorCastConditionActionsDropDown", actionDropW)
    else
        c.actionsDrop = Widgets:CreateDropdown(c.row3, "QFXSkillAlertsEditorCastConditionActionsDropDown", actionDropW)
    end
    c.actionsDrop:SetPoint("LEFT", c.row3, "LEFT", actionDropX - inner, 0)
    return c
end



local function CreateNotifyControls(content, ctx)
    local modules = ctx.modules or {}
    local INNER = ctx.INNER or 16
    local MODULE_CONTENT_W = ctx.MODULE_CONTENT_W or 648
    local MODULE_RIGHT = ctx.MODULE_RIGHT or 16
    local ENABLE_Y = ctx.ENABLE_Y or -44
    local LABEL_OFFSET = ctx.LABEL_OFFSET or 0
    local CONTROL_OFFSET = ctx.CONTROL_OFFSET or -24
    local ROW_GAP = ctx.ROW_GAP or 72
    local SOURCE_X, SOURCE_W = ctx.SOURCE_X or INNER, ctx.SOURCE_W or 286
    local BUILTIN_X, BUILTIN_W = ctx.BUILTIN_X or INNER, ctx.BUILTIN_W or 286
    local SHAREDMEDIA_X, SHAREDMEDIA_W = ctx.SHAREDMEDIA_X or 342, ctx.SHAREDMEDIA_W or 286
    local CUSTOM_X, CUSTOM_W = ctx.CUSTOM_X or INNER, ctx.CUSTOM_W or MODULE_CONTENT_W
    local TTS_X, TTS_W = ctx.TTS_X or INNER, ctx.TTS_W or 286
    local SLIDER_LABEL_X, SLIDER_X = ctx.SLIDER_LABEL_X or SHAREDMEDIA_X, ctx.SLIDER_X or SHAREDMEDIA_X
    local NOTIFY_SOURCE_LABEL_Y, NOTIFY_SOURCE_CONTROL_Y = ctx.NOTIFY_SOURCE_LABEL_Y or -88, ctx.NOTIFY_SOURCE_CONTROL_Y or -112
    local NOTIFY_SOUND_LABEL_Y, NOTIFY_SOUND_CONTROL_Y = ctx.NOTIFY_SOUND_LABEL_Y or -160, ctx.NOTIFY_SOUND_CONTROL_Y or -184
    local NOTIFY_CUSTOM_LABEL_Y, NOTIFY_CUSTOM_CONTROL_Y = ctx.NOTIFY_CUSTOM_LABEL_Y or -232, ctx.NOTIFY_CUSTOM_CONTROL_Y or -256
    local NOTIFY_TTS_LABEL_Y, NOTIFY_TTS_CONTROL_Y = ctx.NOTIFY_TTS_LABEL_Y or -304, ctx.NOTIFY_TTS_CONTROL_Y or -328
    local NOTIFY_HINT_Y = ctx.NOTIFY_HINT_Y or -386
    local NOTIFY_ROW4_Y = ctx.NOTIFY_ROW4_Y or -304
    local notifyTop = modules.notifyTop or -8
    local notifyHeight = modules.notifyHeight or 420
    local notifySection = PlaceModule(content, L("SECTION_NOTIFY"), notifyTop, notifyHeight)
    local positionTop = notifyTop - notifyHeight - 18
    local imagePositionSection = PlaceModule(content, L("LABEL_IMAGE_POSITION"), positionTop, 156)
    imagePositionSection:Hide()
    local textPositionSection = PlaceModule(content, L("LABEL_TEXT_POSITION"), positionTop, 156)
    textPositionSection:Hide()
    local visualLayoutSection = PlaceModule(content, L("LABEL_TEXT_LAYOUT"), positionTop, 220)
    visualLayoutSection:Hide()
    local nw = {}

    nw.voiceEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_ENABLE_VOICE_ALERT"), 220)
    nw.voiceEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", INNER, ENABLE_Y)
    SetCheckWidth(nw.voiceEnabled, 220)
    nw.sourceLabel = CreateFieldLabel(notifySection, L("LABEL_SOUND_SOURCE"), SOURCE_X, NOTIFY_SOURCE_LABEL_Y, SOURCE_W)
    nw.sourceDrop = PlaceControl(Widgets:CreateDropdown(notifySection, "QFXSkillAlertsEditorSoundSourceDropDown", SOURCE_W), notifySection, SOURCE_X, NOTIFY_SOURCE_CONTROL_Y)
    nw.builtinLabel = CreateFieldLabel(notifySection, L("LABEL_BUILTIN_SOUND"), BUILTIN_X, NOTIFY_SOUND_LABEL_Y, BUILTIN_W)
    nw.builtinDrop = PlaceControl(Widgets:CreateDropdown(notifySection, "QFXSkillAlertsEditorBuiltinDropDown", BUILTIN_W), notifySection, BUILTIN_X, NOTIFY_SOUND_CONTROL_Y)
    nw.sharedMediaLabel = CreateFieldLabel(notifySection, L("LABEL_SHAREDMEDIA_SOUND"), SHAREDMEDIA_X, NOTIFY_SOUND_LABEL_Y, SHAREDMEDIA_W)
    nw.sharedMediaDrop = PlaceControl(Widgets:CreateDropdown(notifySection, "QFXSkillAlertsEditorSharedMediaDropDown", SHAREDMEDIA_W), notifySection, SHAREDMEDIA_X, NOTIFY_SOUND_CONTROL_Y)
    nw.customPathLabel = CreateFieldLabel(notifySection, L("LABEL_CUSTOM_SOUND_PATH"), CUSTOM_X, NOTIFY_CUSTOM_LABEL_Y, CUSTOM_W)
    nw.soundPath = PlaceControl(Widgets:CreateEditBox(notifySection, CUSTOM_W, 30, false), notifySection, CUSTOM_X, NOTIFY_CUSTOM_CONTROL_Y)
    nw.bloodlustCustomPathLabels = {}
    nw.bloodlustCustomPaths = {}
    for i = 2, 5 do
        local rowY = NOTIFY_ROW4_Y - ((i - 2) * 54)
        local label = CreateFieldLabel(notifySection, L("LABEL_SOUND_PATH_N", i), CUSTOM_X, rowY + LABEL_OFFSET, CUSTOM_W)
        local input = PlaceControl(Widgets:CreateEditBox(notifySection, CUSTOM_W, 30, false), notifySection, CUSTOM_X, rowY + CONTROL_OFFSET)
        label:Hide()
        input:Hide()
        nw.bloodlustCustomPathLabels[i] = label
        nw.bloodlustCustomPaths[i] = input
    end
    nw.ttsTextLabel = CreateFieldLabel(notifySection, L("LABEL_TTS_TEXT"), TTS_X, NOTIFY_TTS_LABEL_Y, TTS_W)
    nw.ttsText = PlaceControl(Widgets:CreateEditBox(notifySection, TTS_W, 30, false), notifySection, TTS_X, NOTIFY_TTS_CONTROL_Y)
    nw.rateLabel = CreateFieldLabel(notifySection, L("LABEL_TTS_RATE"), SLIDER_LABEL_X, NOTIFY_TTS_LABEL_Y, TTS_W)
    nw.ttsRateSlider = CreateRateSlider(notifySection)
    PlaceControl(nw.ttsRateSlider, notifySection, SLIDER_X, NOTIFY_TTS_CONTROL_Y)
    nw.ttsRateValue = nw.ttsRateSlider.qfxsaValueText

    local IMAGE_ROW1_LABEL_Y, IMAGE_ROW1_CONTROL_Y = NOTIFY_SOURCE_LABEL_Y, NOTIFY_SOURCE_CONTROL_Y
    local IMAGE_ROW2_LABEL_Y, IMAGE_ROW2_CONTROL_Y = NOTIFY_SOUND_LABEL_Y, NOTIFY_SOUND_CONTROL_Y
    local IMAGE_ROW3_LABEL_Y, IMAGE_ROW3_CONTROL_Y = NOTIFY_CUSTOM_LABEL_Y, NOTIFY_CUSTOM_CONTROL_Y
    local IMAGE_ROW4_LABEL_Y, IMAGE_ROW4_CONTROL_Y = NOTIFY_TTS_LABEL_Y, NOTIFY_TTS_CONTROL_Y
    local IMAGE_ROW5_LABEL_Y, IMAGE_ROW5_CONTROL_Y = IMAGE_ROW4_LABEL_Y - ROW_GAP, IMAGE_ROW4_CONTROL_Y - ROW_GAP
    local IMAGE_NUDGE_BTN_W = 28
    local IMAGE_NUDGE_BTN_H = 24

    local function CreateInlineSecondsLabel(parent, anchor)
        local label = Widgets:CreateLabel(parent, L("LABEL_SECONDS_SHORT"), "GameFontHighlight")
        label:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        label:SetSize(42, 24)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        if Skin then Skin:StyleFont(label, "body") end
        return label
    end

    nw.imageEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_ENABLE_IMAGE_ALERT"), 220)
    nw.imageEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", INNER, ENABLE_Y)
    SetCheckWidth(nw.imageEnabled, 220)
    nw.imageSourceLabel = CreateFieldLabel(notifySection, L("LABEL_IMAGE_SOURCE"), BUILTIN_X, IMAGE_ROW1_LABEL_Y, BUILTIN_W)
    nw.imageSourceDrop = PlaceControl(Widgets:CreateDropdown(notifySection, "QFXSkillAlertsEditorImageSourceDropDown", BUILTIN_W), notifySection, BUILTIN_X, IMAGE_ROW1_CONTROL_Y)
    nw.imageIconLabel = CreateFieldLabel(notifySection, L("LABEL_IMAGE_ICON_ID"), SHAREDMEDIA_X, IMAGE_ROW1_LABEL_Y, SHAREDMEDIA_W)
    nw.imageIconID = PlaceControl(Widgets:CreateEditBox(notifySection, 120, 30, true), notifySection, SHAREDMEDIA_X, IMAGE_ROW1_CONTROL_Y)
    nw.imageIconPreview = CreateFrame("Frame", nil, notifySection, "BackdropTemplate")
    nw.imageIconPreview:SetSize(34, 34)
    nw.imageIconPreview:SetPoint("LEFT", nw.imageIconID, "RIGHT", 10, 0)
    if nw.imageIconPreview.SetBackdrop then
        nw.imageIconPreview:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        nw.imageIconPreview:SetBackdropColor(0, 0, 0, 0.80)
        nw.imageIconPreview:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.85)
    end
    nw.imageIconPreviewTexture = nw.imageIconPreview:CreateTexture(nil, "ARTWORK")
    nw.imageIconPreviewTexture:SetPoint("TOPLEFT", nw.imageIconPreview, "TOPLEFT", 4, -4)
    nw.imageIconPreviewTexture:SetPoint("BOTTOMRIGHT", nw.imageIconPreview, "BOTTOMRIGHT", -4, 4)
    nw.imageIconPreviewTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    nw.imageIconPreview:Hide()
    nw.imagePathLabel = CreateFieldLabel(notifySection, L("LABEL_IMAGE_PATH"), CUSTOM_X, IMAGE_ROW2_LABEL_Y, CUSTOM_W)
    nw.imagePath = PlaceControl(Widgets:CreateEditBox(notifySection, CUSTOM_W, 30, false), notifySection, CUSTOM_X, IMAGE_ROW2_CONTROL_Y)
    nw.imageSizeLabel = CreateFieldLabel(notifySection, L("LABEL_IMAGE_SIZE"), BUILTIN_X, IMAGE_ROW3_LABEL_Y, BUILTIN_W)
    nw.imageSize = CreateValueSlider and CreateValueSlider(notifySection, 16, 256, 1, 96) or Widgets:CreateEditBox(notifySection, 120, 30, true)
    PlaceControl(nw.imageSize, notifySection, BUILTIN_X, IMAGE_ROW3_CONTROL_Y)
    nw.imageDurationEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_LIMIT_IMAGE_DURATION"), 150)
    nw.imageDurationEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", SHAREDMEDIA_X, IMAGE_ROW3_CONTROL_Y - 3)
    SetCheckWidth(nw.imageDurationEnabled, 150)
    nw.imageDuration = Widgets:CreateEditBox(notifySection, 72, 30, false)
    nw.imageDuration:SetPoint("LEFT", nw.imageDurationEnabled, "LEFT", 178, 0)
    nw.imageDurationLabel = CreateInlineSecondsLabel(notifySection, nw.imageDuration)
    local POS_ROW1_LABEL_Y, POS_ROW1_CONTROL_Y = -42, -66
    local POS_ROW2_LABEL_Y, POS_ROW2_CONTROL_Y = -104, -128

    nw.imageXLabel = CreateFieldLabel(imagePositionSection, L("LABEL_POSITION_X"), BUILTIN_X, POS_ROW1_LABEL_Y, BUILTIN_W)
    nw.imageX = PlaceControl(Widgets:CreateEditBox(imagePositionSection, 120, 30, false), imagePositionSection, BUILTIN_X, POS_ROW1_CONTROL_Y)
    nw.imageYLabel = CreateFieldLabel(imagePositionSection, L("LABEL_POSITION_Y"), BUILTIN_X + 132, POS_ROW1_LABEL_Y, BUILTIN_W)
    nw.imageY = PlaceControl(Widgets:CreateEditBox(imagePositionSection, 120, 30, false), imagePositionSection, BUILTIN_X + 132, POS_ROW1_CONTROL_Y)
    nw.imagePreviewButton = Widgets:CreateButton(imagePositionSection, L("BTN_SHOW_PREVIEW"), 150, 26)
    nw.imagePreviewButton:SetPoint("TOPLEFT", imagePositionSection, "TOPLEFT", BUILTIN_X, POS_ROW2_CONTROL_Y)
    nw.imageHidePreviewButton = Widgets:CreateButton(imagePositionSection, L("BTN_HIDE_PREVIEW"), 110, 26)
    nw.imageHidePreviewButton:SetPoint("LEFT", nw.imagePreviewButton, "RIGHT", 8, 0)
    nw.imageNudgeLabel = CreateFieldLabel(imagePositionSection, L("LABEL_IMAGE_NUDGE"), SHAREDMEDIA_X, POS_ROW2_LABEL_Y, SHAREDMEDIA_W)
    nw.imageNudgeUp = Widgets:CreateButton(imagePositionSection, "↑", IMAGE_NUDGE_BTN_W, IMAGE_NUDGE_BTN_H)
    nw.imageNudgeUp:SetPoint("TOPLEFT", imagePositionSection, "TOPLEFT", SHAREDMEDIA_X, POS_ROW2_CONTROL_Y)
    nw.imageNudgeDown = Widgets:CreateButton(imagePositionSection, "↓", IMAGE_NUDGE_BTN_W, IMAGE_NUDGE_BTN_H)
    nw.imageNudgeDown:SetPoint("LEFT", nw.imageNudgeUp, "RIGHT", 4, 0)
    nw.imageNudgeLeft = Widgets:CreateButton(imagePositionSection, "←", IMAGE_NUDGE_BTN_W, IMAGE_NUDGE_BTN_H)
    nw.imageNudgeLeft:SetPoint("LEFT", nw.imageNudgeDown, "RIGHT", 4, 0)
    nw.imageNudgeRight = Widgets:CreateButton(imagePositionSection, "→", IMAGE_NUDGE_BTN_W, IMAGE_NUDGE_BTN_H)
    nw.imageNudgeRight:SetPoint("LEFT", nw.imageNudgeLeft, "RIGHT", 4, 0)
    nw.imageNudgeReset = Widgets:CreateButton(imagePositionSection, L("BTN_RESET"), 54, IMAGE_NUDGE_BTN_H)
    nw.imageNudgeReset:SetPoint("LEFT", nw.imageNudgeRight, "RIGHT", 4, 0)

    nw.textEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_ENABLE_TEXT_ALERT"), 220)
    nw.textEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", INNER, ENABLE_Y)
    SetCheckWidth(nw.textEnabled, 220)
    nw.textAlertLabel = CreateFieldLabel(notifySection, L("LABEL_TEXT_CONTENT"), CUSTOM_X, NOTIFY_SOURCE_LABEL_Y, CUSTOM_W)
    nw.textAlert = PlaceControl(Widgets:CreateEditBox(notifySection, CUSTOM_W, 30, false), notifySection, CUSTOM_X, NOTIFY_SOURCE_CONTROL_Y)
    nw.textSizeLabel = CreateFieldLabel(notifySection, L("LABEL_TEXT_SIZE"), BUILTIN_X, NOTIFY_SOUND_LABEL_Y, BUILTIN_W)
    nw.textSize = CreateValueSlider and CreateValueSlider(notifySection, 8, 64, 1, 24) or Widgets:CreateEditBox(notifySection, 120, 30, true)
    PlaceControl(nw.textSize, notifySection, BUILTIN_X, NOTIFY_SOUND_CONTROL_Y)
    nw.textDurationEnabled = Widgets:CreateCheckButton(notifySection, L("LABEL_LIMIT_TEXT_DURATION"), 150)
    nw.textDurationEnabled:SetPoint("TOPLEFT", notifySection, "TOPLEFT", SHAREDMEDIA_X, NOTIFY_SOUND_CONTROL_Y - 3)
    SetCheckWidth(nw.textDurationEnabled, 150)
    nw.textDuration = Widgets:CreateEditBox(notifySection, 72, 30, false)
    nw.textDuration:SetPoint("LEFT", nw.textDurationEnabled, "LEFT", 178, 0)
    nw.textDurationLabel = CreateInlineSecondsLabel(notifySection, nw.textDuration)
    nw.textXLabel = CreateFieldLabel(textPositionSection, L("LABEL_POSITION_X"), BUILTIN_X, POS_ROW1_LABEL_Y, BUILTIN_W)
    nw.textX = PlaceControl(Widgets:CreateEditBox(textPositionSection, 120, 30, false), textPositionSection, BUILTIN_X, POS_ROW1_CONTROL_Y)
    nw.textYLabel = CreateFieldLabel(textPositionSection, L("LABEL_POSITION_Y"), BUILTIN_X + 132, POS_ROW1_LABEL_Y, BUILTIN_W)
    nw.textY = PlaceControl(Widgets:CreateEditBox(textPositionSection, 120, 30, false), textPositionSection, BUILTIN_X + 132, POS_ROW1_CONTROL_Y)
    nw.textPreviewButton = Widgets:CreateButton(textPositionSection, L("BTN_SHOW_PREVIEW"), 150, 26)
    nw.textPreviewButton:SetPoint("TOPLEFT", textPositionSection, "TOPLEFT", BUILTIN_X, POS_ROW2_CONTROL_Y)
    nw.textHidePreviewButton = Widgets:CreateButton(textPositionSection, L("BTN_HIDE_PREVIEW"), 110, 26)
    nw.textHidePreviewButton:SetPoint("LEFT", nw.textPreviewButton, "RIGHT", 8, 0)
    nw.textSingleNudgeLabel = CreateFieldLabel(textPositionSection, L("LABEL_TEXT_POSITION_NUDGE"), SHAREDMEDIA_X, POS_ROW2_LABEL_Y, SHAREDMEDIA_W)
    nw.textSingleNudgeUp = Widgets:CreateButton(textPositionSection, "↑", 28, 24)
    nw.textSingleNudgeUp:SetPoint("TOPLEFT", textPositionSection, "TOPLEFT", SHAREDMEDIA_X, POS_ROW2_CONTROL_Y)
    nw.textSingleNudgeDown = Widgets:CreateButton(textPositionSection, "↓", 28, 24)
    nw.textSingleNudgeDown:SetPoint("LEFT", nw.textSingleNudgeUp, "RIGHT", 4, 0)
    nw.textSingleNudgeLeft = Widgets:CreateButton(textPositionSection, "←", 28, 24)
    nw.textSingleNudgeLeft:SetPoint("LEFT", nw.textSingleNudgeDown, "RIGHT", 4, 0)
    nw.textSingleNudgeRight = Widgets:CreateButton(textPositionSection, "→", 28, 24)
    nw.textSingleNudgeRight:SetPoint("LEFT", nw.textSingleNudgeLeft, "RIGHT", 4, 0)
    nw.textSingleNudgeReset = Widgets:CreateButton(textPositionSection, L("BTN_RESET"), 54, 24)
    nw.textSingleNudgeReset:SetPoint("LEFT", nw.textSingleNudgeRight, "RIGHT", 4, 0)

    nw.textAttachLabel = CreateFieldLabel(visualLayoutSection, L("LABEL_TEXT_ATTACH_MODE"), BUILTIN_X, -42, BUILTIN_W)
    nw.textAttachDrop = PlaceControl(Widgets:CreateDropdown(visualLayoutSection, "QFXSkillAlertsEditorTextAttachDropDown", BUILTIN_W), visualLayoutSection, BUILTIN_X, -66)
    nw.textVAlignLabel = CreateFieldLabel(visualLayoutSection, L("LABEL_TEXT_VALIGN"), SHAREDMEDIA_X, -42, SHAREDMEDIA_W)
    nw.textVAlignDrop = PlaceControl(Widgets:CreateDropdown(visualLayoutSection, "QFXSkillAlertsEditorTextVAlignDropDown", SHAREDMEDIA_W), visualLayoutSection, SHAREDMEDIA_X, -66)
    nw.textHAlignLabel = CreateFieldLabel(visualLayoutSection, L("LABEL_TEXT_HALIGN"), BUILTIN_X, -104, BUILTIN_W)
    nw.textHAlignDrop = PlaceControl(Widgets:CreateDropdown(visualLayoutSection, "QFXSkillAlertsEditorTextHAlignDropDown", BUILTIN_W), visualLayoutSection, BUILTIN_X, -128)
    nw.layoutPreviewButton = Widgets:CreateButton(visualLayoutSection, L("BTN_SHOW_PREVIEW"), 140, 24)
    nw.layoutPreviewButton:SetPoint("TOPLEFT", visualLayoutSection, "TOPLEFT", BUILTIN_X, -178)
    nw.layoutHidePreviewButton = Widgets:CreateButton(visualLayoutSection, L("BTN_HIDE_PREVIEW"), 100, 24)
    nw.layoutHidePreviewButton:SetPoint("LEFT", nw.layoutPreviewButton, "RIGHT", 8, 0)
    nw.textNudgeLabel = CreateFieldLabel(visualLayoutSection, L("LABEL_TEXT_NUDGE"), SHAREDMEDIA_X, -154, SHAREDMEDIA_W)
    nw.textNudgeUp = Widgets:CreateButton(visualLayoutSection, "↑", 28, 24)
    nw.textNudgeUp:SetPoint("TOPLEFT", visualLayoutSection, "TOPLEFT", SHAREDMEDIA_X, -178)
    nw.textNudgeDown = Widgets:CreateButton(visualLayoutSection, "↓", 28, 24)
    nw.textNudgeDown:SetPoint("LEFT", nw.textNudgeUp, "RIGHT", 4, 0)
    nw.textNudgeLeft = Widgets:CreateButton(visualLayoutSection, "←", 28, 24)
    nw.textNudgeLeft:SetPoint("LEFT", nw.textNudgeDown, "RIGHT", 4, 0)
    nw.textNudgeRight = Widgets:CreateButton(visualLayoutSection, "→", 28, 24)
    nw.textNudgeRight:SetPoint("LEFT", nw.textNudgeLeft, "RIGHT", 4, 0)
    nw.textNudgeReset = Widgets:CreateButton(visualLayoutSection, L("BTN_RESET"), 54, 24)
    nw.textNudgeReset:SetPoint("LEFT", nw.textNudgeRight, "RIGHT", 4, 0)
    nw.textOffsetX = Widgets:CreateEditBox(visualLayoutSection, 54, 30, false)
    nw.textOffsetX:Hide()
    nw.textOffsetY = Widgets:CreateEditBox(visualLayoutSection, 54, 30, false)
    nw.textOffsetY:Hide()

    nw.editorHint = Widgets:CreateLabel(notifySection, "", "GameFontHighlightSmall")
    nw.editorHint:SetPoint("TOPLEFT", notifySection, "TOPLEFT", INNER, NOTIFY_HINT_Y)
    nw.editorHint:SetPoint("RIGHT", notifySection, "RIGHT", -MODULE_RIGHT, 0)
    nw.editorHint:SetJustifyH("LEFT")
    nw.editorHint:Hide()

    nw.notifySection = notifySection
    nw.imagePositionSection = imagePositionSection
    nw.textPositionSection = textPositionSection
    nw.visualLayoutSection = visualLayoutSection
    nw.notifySectionHeight = notifyHeight
    nw.bloodlustCustomSoundNotifyHeight = 610
    return nw
end

function Builder:EnsureFrame(owner)
    local self = owner
    if self.frame then
        return self.frame
    end

    local layout = PopupLayout and PopupLayout.Editor or nil
    local frameCfg = layout and layout.Frame or { width = 760, footerHeight = 54, contentTopY = -146, contentBottom = 66, sideInset = 24, tabY = -70, subTabY = -106, headerTitleY = -14 }

    local frame = CreateFrame("Frame", "QFXSkillAlertsEditorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(frameCfg.width or 760, 720)
    frame:SetPoint("CENTER", UIParent, "CENTER", 100, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    local function UpdateFrameHeight()
        if PopupLayout and PopupLayout.UpdatePopupHeight then
            PopupLayout:UpdatePopupHeight(frame)
            return
        end
        local parentHeight = UIParent and UIParent.GetHeight and (UIParent:GetHeight() or 720) or 720
        local targetHeight = math.min(780, math.max(620, parentHeight - 80))
        frame:SetHeight(targetHeight)
        if frame.contentHost and frame.contentHost.UpdateScrollRange then
            frame.contentHost:UpdateScrollRange()
        end
    end

    frame:SetScript("OnShow", function(selfFrame)
        UpdateFrameHeight()
        selfFrame:SetFrameLevel(100)
        selfFrame:Raise()
    end)
    frame:Hide()
    Widgets:ApplyPanelChrome(frame, { footerHeight = frameCfg.footerHeight or 54 })
    tinsert(UISpecialFrames, frame:GetName())

    local title = Widgets:CreateLabel(frame, L("TITLE_EDIT_CONFIG"), "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, frameCfg.headerTitleY or -14)
    title:SetWidth(560)
    title:SetJustifyH("CENTER")
    if Skin then
        Skin:StyleFont(title, "title")
    end
    frame.title = title

    local description = PopupLayout and PopupLayout.CreateHeaderDescription and PopupLayout:CreateHeaderDescription(frame, L("EDITOR_DESC")) or Widgets:CreateLabel(frame, L("EDITOR_DESC"), "GameFontHighlightSmall")
    if description and not description:GetPoint() then
        description:SetPoint("TOP", title, "BOTTOM", 0, -4)
    end
    frame.description = description

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    if Skin and Skin.SkinCloseButton then
        Skin:SkinCloseButton(close)
    end
    close:SetScript("OnClick", function()
        self:Close()
    end)

    -- Type selection now happens before this editor opens. Keep the old type-tab
    -- widgets hidden for compatibility with existing refresh/action code, but do
    -- not show a second-level "CD / Cast / Bloodlust" tab row inside the editor.
    local tabTypeLabel = Widgets:CreateLabel(frame, L("TAB_GROUP_TYPE"), "GameFontNormalSmall")
    tabTypeLabel:Hide()

    local tabCooldown = Widgets:CreateButton(frame, L("TAB_COOLDOWN"), 1, 1)
    tabCooldown:Hide()
    tabCooldown:Disable()

    local tabCast = Widgets:CreateButton(frame, L("TAB_CAST"), 1, 1)
    tabCast:Hide()
    tabCast:Disable()

    local tabBloodlust = Widgets:CreateButton(frame, L("TAB_BLOODLUST"), 1, 1)
    tabBloodlust:Hide()
    tabBloodlust:Disable()

    local subTabLabel = Widgets:CreateLabel(frame, L("TAB_GROUP_PAGE"), "GameFontNormalSmall")
    subTabLabel:Hide()

    local tabSettings = Widgets:CreateButton(frame, L("TAB_SETTINGS"), 78, 24)
    tabSettings:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, frameCfg.tabY or -70)

    local tabVoice = Widgets:CreateButton(frame, L("TAB_VOICE"), 78, 24)
    tabVoice:SetPoint("LEFT", tabSettings, "RIGHT", 8, 0)

    local tabImage = Widgets:CreateButton(frame, L("TAB_IMAGE"), 78, 24)
    tabImage:SetPoint("LEFT", tabVoice, "RIGHT", 8, 0)

    local tabText = Widgets:CreateButton(frame, L("TAB_TEXT"), 78, 24)
    tabText:SetPoint("LEFT", tabImage, "RIGHT", 8, 0)

    local contentHost, content = Widgets:CreateScrollableContent(frame, { contentHeight = (PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Rows.contentHeight) or 880, contentWidth = 700, topHeight = 16, noTopLine = true, wheelStep = 86 })
    contentHost:SetPoint("TOPLEFT", frame, "TOPLEFT", frameCfg.sideInset or 24, (frameCfg.contentTopY or -146) + 38)
    contentHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(frameCfg.sideInset or 24), frameCfg.contentBottom or 66)
    contentHost:SetContentHeight((PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Rows.contentHeight) or 880)
    frame.contentHost = contentHost

    local grid = (PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Grid) or {}
    local modules = (PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Modules) or {}
    local INNER = grid.moduleInnerLeft or 16
    local MODULE_W = modules.width or 680
    local MODULE_RIGHT = grid.moduleInnerRight or 16
    local MODULE_CONTENT_W = MODULE_W - INNER - MODULE_RIGHT

    local LABEL_OFFSET = 0
    local CONTROL_OFFSET = -24
    local ROW_GAP = 72
    local ID_X, ID_W = INNER, grid.idW or 112
    local NAME_X, NAME_W = 152, grid.nameW or 220
    local CD_X, CD_W = 392, grid.cdW or 112
    local CHECK_X, CHECK_W = 520, grid.checkW or 126
    local CLASS_LABEL_X, DROP_CLASS_X, DROP_CLASS_W = INNER, INNER, grid.classDropW or 286
    local SPEC_LABEL_X, DROP_SPEC_X, DROP_SPEC_W = 342, 342, grid.specDropW or 286
    local SOURCE_X, SOURCE_W = INNER, grid.sourceW or 286
    local BUILTIN_X, BUILTIN_W = INNER, grid.halfW or 286
    local SHAREDMEDIA_X, SHAREDMEDIA_W = 342, grid.halfW or 286
    local CUSTOM_X, CUSTOM_W = INNER, MODULE_CONTENT_W
    local TTS_X, TTS_W = INNER, grid.halfW or 286
    local SLIDER_LABEL_X, SLIDER_X = SHAREDMEDIA_X, SHAREDMEDIA_X
    local CONDITION_LABEL_X, CONDITION_DROP_X, CONDITION_TIME_X = SHAREDMEDIA_X, 436, 536
    local CONDITION_LABEL_W, CONDITION_DROP_W, CONDITION_TIME_W = 88, 76, 92
    local SETTING_COND_NAME_X, SETTING_COND_NAME_W = INNER, 92
    local SETTING_COND_CD_X, SETTING_COND_CD_W = 136, 96
    local SETTING_COND_DROP_X, SETTING_COND_DROP_W = 244, 76
    local SETTING_COND_TIME_X, SETTING_COND_TIME_W = 336, 92
    local SETTING_COND_SEC_X, SETTING_COND_SEC_W = 438, 42
    local COND_WHEN_X, COND_WHEN_W = INNER, 28
    local COND_SPELL_X, COND_SPELL_W = 48, 176
    local COND_REMAIN_X, COND_REMAIN_W = 236, 126
    local COND_OP_X, COND_OP_W = 370, 76
    local COND_TIME_X, COND_TIME_W = 458, 92
    local COND_SEC_X, COND_SEC_W = 560, 42
    local COND_EXEC_X, COND_EXEC_W = INNER, 44
    local COND_ACTION_DROP_X, COND_ACTION_DROP_W = 72, 300
    local COND_ACTION_HINT_X, COND_ACTION_HINT_W = 0, 0
    local CAST_DELAY_CHECK_X, CAST_DELAY_CHECK_W = INNER, 88
    local CAST_DELAY_LABEL_X, CAST_DELAY_LABEL_W = 108, 44
    local CAST_DELAY_TIME_X, CAST_DELAY_TIME_W = 158, 76
    local CAST_DELAY_AFTER_X, CAST_DELAY_AFTER_W = 244, 56
    local CAST_DELAY_MODE_X, CAST_DELAY_MODE_W = 310, 116
    local CAST_ACTION_DROP_X, CAST_ACTION_DROP_W = 72, 300

    local CLASS_LABEL_Y, CLASS_CONTROL_Y = -38, -62
    local SPELL_ROW1_Y = -46
    local SPELL_ROW2_Y = SPELL_ROW1_Y - ROW_GAP
    local SPELL_LABEL1_Y, SPELL_CONTROL1_Y = SPELL_ROW1_Y + LABEL_OFFSET, SPELL_ROW1_Y + CONTROL_OFFSET
    local SPELL_LABEL2_Y, SPELL_CONTROL2_Y = SPELL_ROW2_Y + LABEL_OFFSET, SPELL_ROW2_Y + CONTROL_OFFSET

    local ENABLE_Y = -44
    local NOTIFY_ROW1_Y = -88
    local NOTIFY_ROW2_Y = NOTIFY_ROW1_Y - ROW_GAP
    local NOTIFY_ROW3_Y = NOTIFY_ROW2_Y - ROW_GAP
    local NOTIFY_ROW4_Y = NOTIFY_ROW3_Y - ROW_GAP
    local NOTIFY_SOURCE_LABEL_Y, NOTIFY_SOURCE_CONTROL_Y = NOTIFY_ROW1_Y + LABEL_OFFSET, NOTIFY_ROW1_Y + CONTROL_OFFSET
    local NOTIFY_SOUND_LABEL_Y, NOTIFY_SOUND_CONTROL_Y = NOTIFY_ROW2_Y + LABEL_OFFSET, NOTIFY_ROW2_Y + CONTROL_OFFSET
    local NOTIFY_CUSTOM_LABEL_Y, NOTIFY_CUSTOM_CONTROL_Y = NOTIFY_ROW3_Y + LABEL_OFFSET, NOTIFY_ROW3_Y + CONTROL_OFFSET
    local NOTIFY_TTS_LABEL_Y, NOTIFY_TTS_CONTROL_Y = NOTIFY_ROW4_Y + LABEL_OFFSET, NOTIFY_ROW4_Y + CONTROL_OFFSET
    local NOTIFY_HINT_Y = NOTIFY_TTS_CONTROL_Y - 58

    local actionSave = Widgets:CreateButton(frame, L("BTN_SAVE"), 120, 32)
    actionSave:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 16)

    local actionTest = Widgets:CreateButton(frame, L("BTN_TEST"), 120, 32)
    actionTest:SetPoint("LEFT", actionSave, "RIGHT", 8, 0)

    local classSection = PlaceModule(content, L("SECTION_CLASS_SPEC"), modules.classTop or -8, modules.classHeight or 104)
    local classLabel = CreateFieldLabel(classSection, L("LABEL_CLASS"), CLASS_LABEL_X, CLASS_LABEL_Y, DROP_CLASS_W)
    local specLabel = CreateFieldLabel(classSection, L("LABEL_SPEC"), SPEC_LABEL_X, CLASS_LABEL_Y, DROP_SPEC_W)
    local classDrop = PlaceControl(Widgets:CreateDropdown(classSection, "QFXSkillAlertsEditorClassDropDown", DROP_CLASS_W), classSection, DROP_CLASS_X, CLASS_CONTROL_Y)
    local specDrop = PlaceControl(Widgets:CreateDropdown(classSection, "QFXSkillAlertsEditorSpecDropDown", DROP_SPEC_W), classSection, DROP_SPEC_X, CLASS_CONTROL_Y)
    local customClassDrop = nil
    local customSpecDrop = nil
    if Widgets.CreateMultiSelectDropdown then
        customClassDrop = PlaceControl(Widgets:CreateMultiSelectDropdown(classSection, "QFXSkillAlertsEditorCustomClassDropDown", DROP_CLASS_W), classSection, DROP_CLASS_X, CLASS_CONTROL_Y)
        customSpecDrop = PlaceControl(Widgets:CreateMultiSelectDropdown(classSection, "QFXSkillAlertsEditorCustomSpecDropDown", DROP_SPEC_W), classSection, DROP_SPEC_X, CLASS_CONTROL_Y)
    else
        customClassDrop = PlaceControl(Widgets:CreateDropdown(classSection, "QFXSkillAlertsEditorCustomClassDropDown", DROP_CLASS_W), classSection, DROP_CLASS_X, CLASS_CONTROL_Y)
        customSpecDrop = PlaceControl(Widgets:CreateDropdown(classSection, "QFXSkillAlertsEditorCustomSpecDropDown", DROP_SPEC_W), classSection, DROP_SPEC_X, CLASS_CONTROL_Y)
    end
    local scopeLabel = CreateFieldLabel(classSection, L("LABEL_SCOPE"), CLASS_LABEL_X, CLASS_LABEL_Y, 180)
    local scopeSummary = Widgets:CreateLabel(classSection, "", "GameFontHighlightSmall")
    scopeSummary:SetPoint("TOPLEFT", classSection, "TOPLEFT", CLASS_LABEL_X, CLASS_CONTROL_Y - 2)
    scopeSummary:SetSize(430, 30)
    scopeSummary:SetJustifyH("LEFT")
    scopeSummary:SetJustifyV("MIDDLE")
    if scopeSummary.SetWordWrap then scopeSummary:SetWordWrap(false) end
    if scopeSummary.SetMaxLines then scopeSummary:SetMaxLines(1) end
    local scopeButton = Widgets:CreateButton(classSection, L("BTN_SCOPE_SELECT"), 146, 28)
    scopeButton:SetPoint("TOPLEFT", classSection, "TOPLEFT", DROP_SPEC_X + 140, CLASS_CONTROL_Y)
    classLabel:Hide()
    specLabel:Hide()
    classDrop:Hide()
    specDrop:Hide()
    customClassDrop:Hide()
    customSpecDrop:Hide()

    -- Custom Lua / custom variable trigger editor was removed.
    -- Keep nil widget slots below for compatibility with shared refresh code.

    local spellSection = PlaceModule(content, L("SECTION_SPELL_PARAMS"), modules.spellTop or -124, modules.spellHeight or 240)
    local OBJECT_CHECK_X, OBJECT_CHECK_W = ID_X, 70
    local PRIMARY_ID_X, PRIMARY_ID_W = ID_X + 76, 84
    local PRIMARY_NAME_X, PRIMARY_NAME_W = NAME_X + 52, NAME_W - 52
    local objectTypeItem = Widgets:CreateCheckButton(spellSection, L("LABEL_IS_ITEM"), OBJECT_CHECK_W)
    objectTypeItem:SetPoint("TOPLEFT", spellSection, "TOPLEFT", OBJECT_CHECK_X, SPELL_CONTROL1_Y - 3)
    SetCheckWidth(objectTypeItem, OBJECT_CHECK_W)
    local spellIdLabel = CreateFieldLabel(spellSection, L("LABEL_OBJECT_SPELL_ID"), PRIMARY_ID_X, SPELL_LABEL1_Y, PRIMARY_ID_W)
    local spellNameLabel = CreateFieldLabel(spellSection, L("LABEL_SPELL_NAME"), PRIMARY_NAME_X, SPELL_LABEL1_Y, PRIMARY_NAME_W)
    local baseCDLabel = CreateFieldLabel(spellSection, L("LABEL_FIXED_CD_SEC"), CD_X, SPELL_LABEL1_Y, CD_W)
    local spellId = PlaceControl(Widgets:CreateEditBox(spellSection, PRIMARY_ID_W, 30, true), spellSection, PRIMARY_ID_X, SPELL_CONTROL1_Y)
    local spellName = PlaceControl(Widgets:CreateEditBox(spellSection, PRIMARY_NAME_W, 30, false), spellSection, PRIMARY_NAME_X, SPELL_CONTROL1_Y)
    local baseCD = PlaceControl(Widgets:CreateEditBox(spellSection, CD_W, 30, false), spellSection, CD_X, SPELL_CONTROL1_Y)

    local checkTalent = Widgets:CreateCheckButton(spellSection, L("LABEL_CHECK_TALENT"), CHECK_W - 30)
    checkTalent:SetPoint("TOPLEFT", spellSection, "TOPLEFT", CHECK_X, SPELL_CONTROL1_Y - 3)
    SetCheckWidth(checkTalent, CHECK_W)

    local itemLoadEquipped = Widgets:CreateCheckButton(spellSection, L("LABEL_ITEM_LOAD_EQUIPPED"), 118)
    itemLoadEquipped:SetPoint("TOPLEFT", spellSection, "TOPLEFT", ID_X, SPELL_CONTROL2_Y - 3)
    SetCheckWidth(itemLoadEquipped, 118)
    local itemLoadBags = Widgets:CreateCheckButton(spellSection, L("LABEL_ITEM_LOAD_BAGS"), 118)
    itemLoadBags:SetPoint("TOPLEFT", spellSection, "TOPLEFT", ID_X + 132, SPELL_CONTROL2_Y - 3)
    SetCheckWidth(itemLoadBags, 118)
    local itemLoadSameName = Widgets:CreateCheckButton(spellSection, L("LABEL_ITEM_LOAD_SAME_NAME"), 146)
    itemLoadSameName:SetPoint("TOPLEFT", spellSection, "TOPLEFT", ID_X + 264, SPELL_CONTROL2_Y - 3)
    SetCheckWidth(itemLoadSameName, 146)

    local talentIdLabel = CreateFieldLabel(spellSection, L("LABEL_TALENT_ID"), ID_X, SPELL_LABEL2_Y, ID_W)
    local talentNameLabel = CreateFieldLabel(spellSection, L("LABEL_TALENT_NAME"), NAME_X, SPELL_LABEL2_Y, NAME_W)
    local talentCDLabel = CreateFieldLabel(spellSection, L("LABEL_TALENT_CD_SEC"), CD_X, SPELL_LABEL2_Y, CD_W)
    local talentId = PlaceControl(Widgets:CreateEditBox(spellSection, ID_W, 30, true), spellSection, ID_X, SPELL_CONTROL2_Y)
    local talentName = PlaceControl(Widgets:CreateEditBox(spellSection, NAME_W, 30, false), spellSection, NAME_X, SPELL_CONTROL2_Y)
    local talentCD = PlaceControl(Widgets:CreateEditBox(spellSection, CD_W, 30, false), spellSection, CD_X, SPELL_CONTROL2_Y)

    -- Legacy cast-delay controls used to live in the spell section.  They stay
    -- allocated for compatibility with older code paths, but the visible cast
    -- condition UI now lives in the Notification Conditions section below.
    local delayEnabled = Widgets:CreateCheckButton(spellSection, L("LABEL_DELAY_CAST_SUCCESS"), 220)
    delayEnabled:SetPoint("TOPLEFT", spellSection, "TOPLEFT", ID_X, SPELL_CONTROL2_Y - 3)
    SetCheckWidth(delayEnabled, 220)
    local delaySecondsLabel = CreateFieldLabel(spellSection, L("LABEL_DELAY_SECONDS"), CD_X, SPELL_LABEL2_Y, CD_W)
    local delaySeconds = PlaceControl(Widgets:CreateEditBox(spellSection, CD_W, 30, false), spellSection, CD_X, SPELL_CONTROL2_Y)
    delayEnabled:Hide()
    delaySecondsLabel:Hide()
    delaySeconds:Hide()

    local conditionSection = PlaceModule(content, L("SECTION_NOTIFY_CONDITIONS"), modules.conditionTop or -382, modules.conditionHeight or 150)
    local COND_ROW1_Y = -44
    local COND_ROW2_Y = -76
    local COND_ROW3_Y = -108
    local COND_ROW_H = 30

    local function CreateInlineRow(parent, y)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", INNER, y)
        row:SetSize(MODULE_CONTENT_W, COND_ROW_H)
        return row
    end

    local function CreateInlineText(parent, text, x, width)
        local label = Widgets:CreateLabel(parent, text, "GameFontHighlight")
        label:SetPoint("LEFT", parent, "LEFT", x, 0)
        label:SetSize(width or 80, COND_ROW_H)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        if label.SetWordWrap then label:SetWordWrap(false) end
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(false) end
        if label.SetMaxLines then label:SetMaxLines(1) end
        if Skin then Skin:StyleFont(label, "body") end
        return label
    end

    local conditionRow1 = CreateInlineRow(conditionSection, COND_ROW1_Y)
    local conditionRow2 = CreateInlineRow(conditionSection, COND_ROW2_Y)

    local conditionWhenLabel = CreateInlineText(conditionRow1, L("LABEL_CONDITION_WHEN"), 0, COND_WHEN_W)
    local conditionSpellNameText = CreateInlineText(conditionRow1, L("LABEL_SPELL_NAME"), COND_SPELL_X - INNER, COND_SPELL_W)
    local conditionRemainingLabel = CreateInlineText(conditionRow1, L("LABEL_COOLDOWN_REMAINING"), COND_REMAIN_X - INNER, COND_REMAIN_W)
    local conditionOp = Widgets:CreateDropdown(conditionRow1, "QFXSkillAlertsEditorConditionDropDown", COND_OP_W)
    conditionOp:SetPoint("LEFT", conditionRow1, "LEFT", COND_OP_X - INNER, 0)
    local conditionTime = Widgets:CreateEditBox(conditionRow1, COND_TIME_W, COND_ROW_H, false)
    conditionTime:SetPoint("LEFT", conditionRow1, "LEFT", COND_TIME_X - INNER, 0)
    conditionTime:SetText("0")
    local conditionSecLabel = CreateInlineText(conditionRow1, L("LABEL_SECONDS_SHORT"), COND_SEC_X - INNER, COND_SEC_W)

    local conditionExecuteLabel = CreateInlineText(conditionRow2, L("LABEL_CONDITION_EXECUTE"), 0, COND_EXEC_W)
    local conditionActionsDrop = nil
    if Widgets.CreateMultiSelectDropdown then
        conditionActionsDrop = Widgets:CreateMultiSelectDropdown(conditionRow2, "QFXSkillAlertsEditorConditionActionsDropDown", COND_ACTION_DROP_W)
    else
        conditionActionsDrop = Widgets:CreateDropdown(conditionRow2, "QFXSkillAlertsEditorConditionActionsDropDown", COND_ACTION_DROP_W)
    end
    conditionActionsDrop:SetPoint("LEFT", conditionRow2, "LEFT", COND_ACTION_DROP_X - INNER, 0)
    local conditionActionHint = nil

    local castConditionControls = CreateCastConditionControls(conditionSection, CreateInlineRow, CreateInlineText, INNER, COND_ROW1_Y, COND_ROW2_Y, COND_ROW3_Y, COND_ROW_H, CAST_DELAY_CHECK_X, CAST_DELAY_CHECK_W, CAST_DELAY_LABEL_X, CAST_DELAY_LABEL_W, CAST_DELAY_TIME_X, CAST_DELAY_TIME_W, CAST_DELAY_AFTER_X, CAST_DELAY_AFTER_W, CAST_DELAY_MODE_X, CAST_DELAY_MODE_W, COND_EXEC_W, CAST_ACTION_DROP_X, CAST_ACTION_DROP_W)

    if spellName and spellName.HookScript then
        spellName:HookScript("OnTextChanged", function(box)
            local text = tostring((box and box.GetText and box:GetText()) or "")
            if text == "" then text = L("LABEL_SPELL_NAME") end
            if conditionSpellNameText and conditionSpellNameText.SetText then
                conditionSpellNameText:SetText(text)
            end
        end)
    end

    local bloodlustInfoSection = PlaceModule(content, L("SECTION_BLOODLUST_BUILTIN"), modules.bloodlustTop or -8, 134)
    local bloodlustInfoText = Widgets:CreateLabel(bloodlustInfoSection, L("BLOODLUST_BUILTIN_HINT"), "GameFontHighlight")
    bloodlustInfoText:SetPoint("TOPLEFT", bloodlustInfoSection, "TOPLEFT", INNER, -42)
    bloodlustInfoText:SetWidth(MODULE_CONTENT_W)
    bloodlustInfoText:SetJustifyH("LEFT")
    bloodlustInfoText:SetJustifyV("TOP")
    if bloodlustInfoText.SetWordWrap then bloodlustInfoText:SetWordWrap(true) end
    if Skin then Skin:StyleFont(bloodlustInfoText, "muted") end

    local notifyData = CreateNotifyControls(content, {
        modules = modules,
        INNER = INNER,
        MODULE_CONTENT_W = MODULE_CONTENT_W,
        MODULE_RIGHT = MODULE_RIGHT,
        ENABLE_Y = ENABLE_Y,
        LABEL_OFFSET = LABEL_OFFSET,
        CONTROL_OFFSET = CONTROL_OFFSET,
        ROW_GAP = ROW_GAP,
        SOURCE_X = SOURCE_X,
        SOURCE_W = SOURCE_W,
        BUILTIN_X = BUILTIN_X,
        BUILTIN_W = BUILTIN_W,
        SHAREDMEDIA_X = SHAREDMEDIA_X,
        SHAREDMEDIA_W = SHAREDMEDIA_W,
        CUSTOM_X = CUSTOM_X,
        CUSTOM_W = CUSTOM_W,
        TTS_X = TTS_X,
        TTS_W = TTS_W,
        SLIDER_LABEL_X = SLIDER_LABEL_X,
        SLIDER_X = SLIDER_X,
        NOTIFY_SOURCE_LABEL_Y = NOTIFY_SOURCE_LABEL_Y,
        NOTIFY_SOURCE_CONTROL_Y = NOTIFY_SOURCE_CONTROL_Y,
        NOTIFY_SOUND_LABEL_Y = NOTIFY_SOUND_LABEL_Y,
        NOTIFY_SOUND_CONTROL_Y = NOTIFY_SOUND_CONTROL_Y,
        NOTIFY_CUSTOM_LABEL_Y = NOTIFY_CUSTOM_LABEL_Y,
        NOTIFY_CUSTOM_CONTROL_Y = NOTIFY_CUSTOM_CONTROL_Y,
        NOTIFY_TTS_LABEL_Y = NOTIFY_TTS_LABEL_Y,
        NOTIFY_TTS_CONTROL_Y = NOTIFY_TTS_CONTROL_Y,
        NOTIFY_HINT_Y = NOTIFY_HINT_Y,
        NOTIFY_ROW4_Y = NOTIFY_ROW4_Y,
    })

    frame.widgets = {
        tabTypeLabel = tabTypeLabel,
        subTabLabel = subTabLabel,
        tabCooldown = tabCooldown,
        tabCast = tabCast,
        tabBloodlust = tabBloodlust,
        tabSettings = tabSettings,
        tabVoice = tabVoice,
        tabImage = tabImage,
        tabText = tabText,
        classSection = classSection,
        spellSection = spellSection,
        customSection = nil,
        customCodeSection = nil,
        conditionSection = conditionSection,
        conditionRow1 = conditionRow1,
        conditionRow2 = conditionRow2,
        castConditionRow1 = castConditionControls.row1,
        castConditionRow2 = castConditionControls.row2,
        bloodlustInfoSection = bloodlustInfoSection,
        bloodlustInfoText = bloodlustInfoText,
        notifySection = notifyData.notifySection,
        imagePositionSection = notifyData.imagePositionSection,
        textPositionSection = notifyData.textPositionSection,
        visualLayoutSection = notifyData.visualLayoutSection,
        classLabel = classLabel,
        specLabel = specLabel,
        scopeLabel = scopeLabel,
        scopeSummary = scopeSummary,
        scopeButton = scopeButton,
        customNameLabel = nil,
        customName = nil,
        customEventEnabled = nil,
        customEventsLabel = nil,
        customEventsDrop = nil,
        customEventTextLabel = nil,
        customEventText = nil,
        customTickerEnabled = nil,
        customIntervalLabel = nil,
        customInterval = nil,
        customIntervalSecLabel = nil,
        customCodeLabel = nil,
        customCodeScroll = nil,
        customCode = nil,
        customTestButton = nil,
        spellIdLabel = spellIdLabel,
        objectTypeItem = objectTypeItem,
        itemLoadEquipped = itemLoadEquipped,
        itemLoadBags = itemLoadBags,
        itemLoadSameName = itemLoadSameName,
        spellNameLabel = spellNameLabel,
        talentIdLabel = talentIdLabel,
        talentNameLabel = talentNameLabel,
        talentCDLabel = talentCDLabel,
        classDrop = classDrop,
        specDrop = specDrop,
        customClassDrop = customClassDrop,
        customSpecDrop = customSpecDrop,
        spellId = spellId,
        spellName = spellName,
        checkTalent = checkTalent,
        talentId = talentId,
        talentName = talentName,
        talentCDLabel = talentCDLabel,
        talentCD = talentCD,
        delayEnabled = delayEnabled,
        delaySecondsLabel = delaySecondsLabel,
        delaySeconds = delaySeconds,
        castImmediateEnabled = castConditionControls.immediateEnabled,
        castDelayEnabled = castConditionControls.delayEnabled,
        castDelayLabel = castConditionControls.delayLabel,
        castDelaySeconds = castConditionControls.delaySeconds,
        castDelayAfterLabel = castConditionControls.delayAfterLabel,
        castDelayModeDrop = castConditionControls.delayModeDrop,
        castConditionExecuteLabel = castConditionControls.executeLabel,
        castConditionActionsDrop = castConditionControls.actionsDrop,
        castConditionRow1 = castConditionControls.row1,
        castConditionRow2 = castConditionControls.row2,
        castConditionRow3 = castConditionControls.row3,
        baseCDLabel = baseCDLabel,
        baseCD = baseCD,
        voiceEnabled = notifyData.voiceEnabled,
        conditionWhenLabel = conditionWhenLabel,
        conditionSpellNameText = conditionSpellNameText,
        conditionRemainingLabel = conditionRemainingLabel,
        conditionOp = conditionOp,
        conditionTime = conditionTime,
        conditionSecLabel = conditionSecLabel,
        conditionExecuteLabel = conditionExecuteLabel,
        conditionActionsDrop = conditionActionsDrop,
        conditionActionHint = conditionActionHint,
        customConditionVarLabel = nil,
        customConditionVarDrop = nil,
        customConditionValueLabel = nil,
        customConditionValue = nil,
        customNotifyRows = nil,
        customConditionLogicDrop = nil,
        customConditionLogicLabel = nil,
        customNotifyAddButton = nil,
        customNotifyExecuteRow = nil,
        customNotifyExecuteLabel = nil,
        customNotifyActionsDrop = nil,
        maxCustomNotify = 0,
        voiceConditionLabel = nil,
        voiceConditionCdLabel = nil,
        voiceConditionOp = conditionOp,
        voiceConditionTime = conditionTime,
        voiceConditionSecLabel = conditionSecLabel,
        sourceLabel = notifyData.sourceLabel,
        sourceDrop = notifyData.sourceDrop,
        builtinLabel = notifyData.builtinLabel,
        builtinDrop = notifyData.builtinDrop,
        sharedMediaLabel = notifyData.sharedMediaLabel,
        sharedMediaDrop = notifyData.sharedMediaDrop,
        customPathLabel = notifyData.customPathLabel,
        bloodlustCustomPathLabels = notifyData.bloodlustCustomPathLabels,
        bloodlustCustomPaths = notifyData.bloodlustCustomPaths,
        ttsTextLabel = notifyData.ttsTextLabel,
        rateLabel = notifyData.rateLabel,
        ttsText = notifyData.ttsText,
        ttsRateSlider = notifyData.ttsRateSlider,
        ttsRateValue = notifyData.ttsRateValue,
        ttsRateMinText = notifyData.ttsRateSlider.qfxsaMinText,
        ttsRateMaxText = notifyData.ttsRateSlider.qfxsaMaxText,
        soundPath = notifyData.soundPath,
        imageEnabled = notifyData.imageEnabled,
        imageConditionLabel = nil,
        imageConditionCdLabel = nil,
        imageConditionOp = conditionOp,
        imageConditionTime = conditionTime,
        imageConditionSecLabel = conditionSecLabel,
        imageSourceLabel = notifyData.imageSourceLabel,
        imageSourceDrop = notifyData.imageSourceDrop,
        imageIconLabel = notifyData.imageIconLabel,
        imageIconID = notifyData.imageIconID,
        imageIconPreview = notifyData.imageIconPreview,
        imageIconPreviewTexture = notifyData.imageIconPreviewTexture,
        imagePathLabel = notifyData.imagePathLabel,
        imagePath = notifyData.imagePath,
        imageSizeLabel = notifyData.imageSizeLabel,
        imageSize = notifyData.imageSize,
        imageDurationEnabled = notifyData.imageDurationEnabled,
        imageDurationLabel = notifyData.imageDurationLabel,
        imageDuration = notifyData.imageDuration,
        imageXLabel = notifyData.imageXLabel,
        imageX = notifyData.imageX,
        imageYLabel = notifyData.imageYLabel,
        imageY = notifyData.imageY,
        imagePreviewButton = notifyData.imagePreviewButton,
        imageHidePreviewButton = notifyData.imageHidePreviewButton,
        imageNudgeLabel = notifyData.imageNudgeLabel,
        imageNudgeUp = notifyData.imageNudgeUp,
        imageNudgeDown = notifyData.imageNudgeDown,
        imageNudgeLeft = notifyData.imageNudgeLeft,
        imageNudgeRight = notifyData.imageNudgeRight,
        imageNudgeReset = notifyData.imageNudgeReset,
        textEnabled = notifyData.textEnabled,
        textConditionLabel = nil,
        textConditionCdLabel = nil,
        textConditionOp = conditionOp,
        textConditionTime = conditionTime,
        textConditionSecLabel = conditionSecLabel,
        textAlertLabel = notifyData.textAlertLabel,
        textAlert = notifyData.textAlert,
        textSizeLabel = notifyData.textSizeLabel,
        textSize = notifyData.textSize,
        textDurationEnabled = notifyData.textDurationEnabled,
        textDurationLabel = notifyData.textDurationLabel,
        textDuration = notifyData.textDuration,
        textXLabel = notifyData.textXLabel,
        textX = notifyData.textX,
        textYLabel = notifyData.textYLabel,
        textY = notifyData.textY,
        textSingleNudgeLabel = notifyData.textSingleNudgeLabel,
        textSingleNudgeUp = notifyData.textSingleNudgeUp,
        textSingleNudgeDown = notifyData.textSingleNudgeDown,
        textSingleNudgeLeft = notifyData.textSingleNudgeLeft,
        textSingleNudgeRight = notifyData.textSingleNudgeRight,
        textSingleNudgeReset = notifyData.textSingleNudgeReset,
        textLayoutLabel = notifyData.textLayoutLabel,
        textAttachLabel = notifyData.textAttachLabel,
        textAttachDrop = notifyData.textAttachDrop,
        textVAlignLabel = notifyData.textVAlignLabel,
        textVAlignDrop = notifyData.textVAlignDrop,
        textHAlignLabel = notifyData.textHAlignLabel,
        textHAlignDrop = notifyData.textHAlignDrop,
        textNudgeLabel = notifyData.textNudgeLabel,
        textOffsetX = notifyData.textOffsetX,
        textOffsetY = notifyData.textOffsetY,
        textNudgeUp = notifyData.textNudgeUp,
        textNudgeDown = notifyData.textNudgeDown,
        textNudgeLeft = notifyData.textNudgeLeft,
        textNudgeRight = notifyData.textNudgeRight,
        textNudgeReset = notifyData.textNudgeReset,
        layoutPreviewButton = notifyData.layoutPreviewButton,
        layoutHidePreviewButton = notifyData.layoutHidePreviewButton,
        textPreviewButton = notifyData.textPreviewButton,
        textHidePreviewButton = notifyData.textHidePreviewButton,
        actionSave = actionSave,
        actionTest = actionTest,
        editorHint = notifyData.editorHint,
        normalNotifyTop = modules.notifyTop or -8,
        bloodlustNotifyTop = modules.bloodlustTop or -8,
        normalSettingsContentHeight = 640,
        castSettingsContentHeight = 640,
        customSettingsContentHeight = 1040,
        normalConditionTop = modules.conditionTop or -382,
        customConditionTop = modules.customConditionTop or -742,
        normalNotifyContentHeight = 780,
        textOnlyVisualContentHeight = 820,
        linkedVisualContentHeight = 860,
        bloodlustContentHeight = 780,
        bloodlustCustomSoundContentHeight = 900,
        notifySectionHeight = notifyData.notifySectionHeight,
        bloodlustCustomSoundNotifyHeight = notifyData.bloodlustCustomSoundNotifyHeight,
    }

    InstallSpellIdAutofill(self, spellId)
    InstallTalentIdAutofill(self, talentId)
    if EditorSoundFields and type(EditorSoundFields.InstallHandlers) == "function" then
        EditorSoundFields:InstallHandlers(self, frame)
    end
    if EditorActions and type(EditorActions.Install) == "function" then
        EditorActions:Install(self, frame)
    end

    self.frame = frame
    return frame
end
