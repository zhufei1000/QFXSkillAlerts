local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.EditorSoundFields = NS.UI.EditorSoundFields or {}

local SoundFields = NS.UI.EditorSoundFields
local Widgets = NS.UI.Widgets
local PopupLayout = NS.UI.PopupLayout
local Layout = NS.UI.EditorLayout or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end

local SetNativeLabelColor = Layout.SetNativeLabelColor
local SetEnabled = Layout.SetEnabled
local ClearNativeSliderExtraText = Layout.ClearNativeSliderExtraText
local UpdateRateValueText = Layout.UpdateRateValueText
local SetRateSliderLabelEnabled = Layout.SetRateSliderLabelEnabled

local DropdownItemCache = {}

local function Trim(value)
    if NS.AceOptions and NS.AceOptions.TrimText then
        return NS.AceOptions.TrimText(value or "")
    end
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function NormalizeSoundPath(value)
    if NS.AceOptions and NS.AceOptions.NormalizeSoundPath then
        return NS.AceOptions:NormalizeSoundPath(value or "")
    end
    return Trim(value)
end

local function EnsureCustomSoundPaths(state)
    state.customSoundPaths = type(state.customSoundPaths) == "table" and state.customSoundPaths or { "", "", "", "", "" }
    for i = 1, 5 do
        state.customSoundPaths[i] = NormalizeSoundPath(state.customSoundPaths[i] or "")
    end
    if Trim(state.customSoundPath or "") ~= "" and Trim(state.customSoundPaths[1] or "") == "" then
        state.customSoundPaths[1] = NormalizeSoundPath(state.customSoundPath)
    end
    return state.customSoundPaths
end

local function FirstNonEmptyPath(paths)
    if type(paths) ~= "table" then
        return ""
    end
    for i = 1, 5 do
        local path = NormalizeSoundPath(paths[i] or "")
        if Trim(path) ~= "" then
            return path
        end
    end
    return ""
end

local function SetExtraBloodlustPathControls(widgets, shown, enabled, state)
    if not widgets then
        return
    end
    local paths = EnsureCustomSoundPaths(state or {})
    for i = 2, 5 do
        local label = widgets.bloodlustCustomPathLabels and widgets.bloodlustCustomPathLabels[i]
        local input = widgets.bloodlustCustomPaths and widgets.bloodlustCustomPaths[i]
        if input and state and input.SetText then
            input:SetText(tostring(paths[i] or ""))
        end
        if label and label.SetShown then label:SetShown(shown == true) end
        if input and input.SetShown then input:SetShown(shown == true) end
        if SetEnabled then SetEnabled(input, enabled == true) end
        if SetNativeLabelColor then SetNativeLabelColor(label, enabled == true) end
    end
end

local function GetDefaultBuiltinSoundPath()
    if NS.AceOptions and NS.AceOptions.GetDefaultBuiltinSoundPath then
        return NS.AceOptions:GetDefaultBuiltinSoundPath()
    end
    return ""
end

local function BuildBuiltinSoundItems()
    local items = {}
    if not NS.AceOptions or type(NS.AceOptions.GetBuiltinSoundList) ~= "function" then
        return items
    end

    for path, name in pairs(NS.AceOptions:GetBuiltinSoundList()) do
        items[#items + 1] = {
            value = path,
            text = name,
        }
    end
    table.sort(items, function(a, b)
        return tostring(a.text or "") < tostring(b.text or "")
    end)
    return items
end

local function BuildSharedMediaSoundItems()
    local items = {}
    if not NS.AceOptions or type(NS.AceOptions.GetSharedMediaSoundList) ~= "function" then
        return items
    end

    for name in pairs(NS.AceOptions:GetSharedMediaSoundList()) do
        items[#items + 1] = {
            value = name,
            text = name,
        }
    end
    table.sort(items, function(a, b)
        return tostring(a.text or "") < tostring(b.text or "")
    end)
    return items
end

local function BuildSoundSourceItems()
    return {
        { value = "builtin", text = L("SOURCE_BUILTIN") },
        { value = "sharedmedia", text = L("SOURCE_SHAREDMEDIA") },
        { value = "custom", text = L("SOURCE_CUSTOM") },
        { value = "tts", text = L("SOURCE_TTS") },
    }
end

function SoundFields:ClearDropdownItemCache()
    for key in pairs(DropdownItemCache) do
        DropdownItemCache[key] = nil
    end
end

function SoundFields:GetSoundSourceItems()
    if not DropdownItemCache.soundSourceItems then
        DropdownItemCache.soundSourceItems = BuildSoundSourceItems()
    end
    return DropdownItemCache.soundSourceItems
end

function SoundFields:GetBuiltinSoundItems()
    if not DropdownItemCache.builtinSoundItems then
        DropdownItemCache.builtinSoundItems = BuildBuiltinSoundItems()
    end
    return DropdownItemCache.builtinSoundItems
end

function SoundFields:GetSharedMediaSoundItems()
    if not DropdownItemCache.sharedMediaSoundItems then
        DropdownItemCache.sharedMediaSoundItems = BuildSharedMediaSoundItems()
    end
    return DropdownItemCache.sharedMediaSoundItems
end

function SoundFields:ResolveState(state, modeTts, modeSound)
    local soundFields = NS.AceOptions:ResolveSoundSourceFields(state, modeTts, modeSound)
    local source = tostring(soundFields.soundSource or state.soundSource or "builtin")
    if tostring(state.soundSource or "") == "" then
        NS.AceOptions:ApplySoundSourceToState(soundFields)
    end
    local isTts = source == "tts" or tostring(state.notifyMode or "") == tostring(modeTts)
    return soundFields, source, isTts
end

function SoundFields:PullFromWidgets(widgets, state, modeTts, modeSound)
    if not widgets or not state then
        return
    end

    state.ttsText = tostring((widgets.ttsText and widgets.ttsText:GetText()) or "")
    state.ttsRate = math.max(-10, math.min(10, tonumber(widgets.ttsRateSlider and widgets.ttsRateSlider:GetValue()) or 0))
    state.customSoundPath = NormalizeSoundPath((widgets.soundPath and widgets.soundPath:GetText()) or "")
    state.customSoundPaths = type(state.customSoundPaths) == "table" and state.customSoundPaths or { "", "", "", "", "" }
    state.customSoundPaths[1] = state.customSoundPath
    for i = 2, 5 do
        local input = widgets.bloodlustCustomPaths and widgets.bloodlustCustomPaths[i]
        state.customSoundPaths[i] = NormalizeSoundPath((input and input:GetText()) or state.customSoundPaths[i] or "")
    end
    state.builtinSoundPath = NormalizeSoundPath((Widgets and Widgets.GetDropdownValue and Widgets:GetDropdownValue(widgets.builtinDrop)) or GetDefaultBuiltinSoundPath())
    state.sharedMediaSound = Trim((Widgets and Widgets.GetDropdownValue and Widgets:GetDropdownValue(widgets.sharedMediaDrop)) or state.sharedMediaSound or "")

    local selectedSource = tostring((Widgets and Widgets.GetDropdownValue and Widgets:GetDropdownValue(widgets.sourceDrop)) or state.soundSource or "builtin")
    if selectedSource == "tts" then
        state.notifyMode = modeTts
        state.soundSource = "tts"
        state.useSharedMediaSound = false
        state.useCustomSound = false
        state.soundPath = ""
    elseif selectedSource == "custom" then
        state.notifyMode = modeSound
        state.soundSource = "custom"
        state.useSharedMediaSound = false
        state.useCustomSound = true
        state.soundPath = FirstNonEmptyPath(state.customSoundPaths) ~= "" and FirstNonEmptyPath(state.customSoundPaths) or state.customSoundPath
    elseif selectedSource == "sharedmedia" then
        local sharedPath = NS.AceOptions:FetchSharedMediaSoundPath(state.sharedMediaSound)
        state.notifyMode = modeSound
        state.soundSource = "sharedmedia"
        state.useCustomSound = false
        state.useSharedMediaSound = state.sharedMediaSound ~= ""
        state.soundPath = NormalizeSoundPath(sharedPath)
    else
        state.notifyMode = modeSound
        state.soundSource = "builtin"
        state.useCustomSound = false
        state.useSharedMediaSound = false
        state.soundPath = state.builtinSoundPath
    end
end

function SoundFields:PushToWidgets(widgets, state, soundFields, source, isTts)
    if not widgets or not state then
        return
    end

    local resolved = soundFields or {}
    local selectedSource = tostring(source or resolved.soundSource or state.soundSource or "builtin")
    local customSound = selectedSource == "custom" and not isTts
    local sharedMediaSound = selectedSource == "sharedmedia" and not isTts and not customSound and Trim(resolved.sharedMediaSound or state.sharedMediaSound or "") ~= ""

    state.useCustomSound = customSound
    state.useSharedMediaSound = sharedMediaSound

    Widgets:SetDropdownItems(widgets.sourceDrop, self:GetSoundSourceItems())
    Widgets:SetDropdownValue(widgets.sourceDrop, selectedSource, L("SOURCE_BUILTIN"))

    Widgets:SetDropdownItems(widgets.builtinDrop, self:GetBuiltinSoundItems())
    Widgets:SetDropdownValue(
        widgets.builtinDrop,
        Trim(state.builtinSoundPath) ~= "" and state.builtinSoundPath or GetDefaultBuiltinSoundPath(),
        L("PLACEHOLDER_SELECT_BUILTIN_SOUND")
    )

    local sharedItems = self:GetSharedMediaSoundItems()
    Widgets:SetDropdownItems(widgets.sharedMediaDrop, sharedItems)
    Widgets:SetDropdownValue(
        widgets.sharedMediaDrop,
        Trim(state.sharedMediaSound or ""),
        L("PLACEHOLDER_SELECT_SHAREDMEDIA_SOUND")
    )

    if widgets.ttsText then
        widgets.ttsText:SetText(tostring(state.ttsText or ""))
    end
    if widgets.ttsRateSlider then
        widgets.ttsRateSlider:SetValue(math.max(-10, math.min(10, tonumber(state.ttsRate) or 0)))
        if ClearNativeSliderExtraText then
            ClearNativeSliderExtraText(widgets.ttsRateSlider)
        end
        if UpdateRateValueText then
            UpdateRateValueText(widgets.ttsRateSlider)
        end
    end
    local customPaths = EnsureCustomSoundPaths(state)
    if widgets.soundPath then
        widgets.soundPath:SetText(tostring(customPaths[1] or state.customSoundPath or ""))
    end
    local showBloodlustMultiCustom = tostring(state.entryType or "") == "bloodlust" and selectedSource == "custom" and tostring(state.activeAlertTab or "") == "voice"
    SetExtraBloodlustPathControls(widgets, showBloodlustMultiCustom, customSound, state)

    SetEnabled(widgets.ttsText, isTts == true)
    SetEnabled(widgets.ttsRateSlider, isTts == true)
    if SetRateSliderLabelEnabled then
        SetRateSliderLabelEnabled(widgets.ttsRateSlider, isTts == true)
    end
    if widgets.rateLabel then
        if isTts then
            SetNativeLabelColor(widgets.rateLabel, true)
        else
            widgets.rateLabel:SetTextColor(0.50, 0.50, 0.50, 1)
        end
    end
    if PopupLayout and PopupLayout.SetLabelEnabled then
        PopupLayout:SetLabelEnabled(widgets.customPathLabel, customSound)
        PopupLayout:SetLabelEnabled(widgets.ttsTextLabel, isTts == true)
    end

    SetEnabled(widgets.soundPath, customSound)

    if isTts then
        state.useCustomSound = false
        state.useSharedMediaSound = false
    end
    if customSound then
        state.useSharedMediaSound = false
    end

    local builtinEnabled = selectedSource == "builtin"
    local sharedEnabled = selectedSource == "sharedmedia" and #sharedItems > 0
    Widgets:SetDropdownEnabled(widgets.builtinDrop, builtinEnabled)
    Widgets:SetDropdownEnabled(widgets.sharedMediaDrop, sharedEnabled)
    if widgets.builtinLabel then
        SetNativeLabelColor(widgets.builtinLabel, builtinEnabled)
    end
    if widgets.sharedMediaLabel then
        SetNativeLabelColor(widgets.sharedMediaLabel, sharedEnabled)
    end

    if widgets.ttsRateSlider and not widgets.ttsRateSlider.qfxsaHooked then
        widgets.ttsRateSlider:SetScript("OnValueChanged", function(slider, value)
            local normalized = math.max(-10, math.min(10, math.floor((tonumber(value) or 0) + 0.5)))
            if ClearNativeSliderExtraText then
                ClearNativeSliderExtraText(slider)
            end
            if UpdateRateValueText then
                UpdateRateValueText(slider, normalized)
            end
            NS.AceOptions:GetState().ttsRate = normalized
        end)
        widgets.ttsRateSlider.qfxsaHooked = true
    end
end

function SoundFields:ApplySourceToState(state, source, widgets)
    local modeTts, modeSound = NS.API.GetModes()
    source = tostring(source or "builtin")
    state.soundSource = source
    state.notifyMode = (source == "tts") and modeTts or modeSound

    if source == "builtin" then
        state.soundPath = state.builtinSoundPath or GetDefaultBuiltinSoundPath()
        state.useCustomSound = false
        state.useSharedMediaSound = false
    elseif source == "sharedmedia" then
        state.useCustomSound = false
        state.useSharedMediaSound = Trim(state.sharedMediaSound or "") ~= ""
        state.soundPath = NS.AceOptions:ResolveSharedMediaSoundPath(state.sharedMediaSound, "")
    elseif source == "custom" then
        state.useCustomSound = true
        state.useSharedMediaSound = false
        EnsureCustomSoundPaths(state)
        state.soundPath = FirstNonEmptyPath(state.customSoundPaths) ~= "" and FirstNonEmptyPath(state.customSoundPaths) or NormalizeSoundPath(state.customSoundPath or (widgets and widgets.soundPath and widgets.soundPath:GetText()) or "")
    elseif source == "tts" then
        state.soundPath = ""
        state.useCustomSound = false
        state.useSharedMediaSound = false
    else
        state.soundSource = "builtin"
        state.soundPath = state.builtinSoundPath or GetDefaultBuiltinSoundPath()
    end
end

function SoundFields:SelectBuiltinSound(state, value)
    local _, modeSound = NS.API.GetModes()
    state.notifyMode = modeSound
    state.soundSource = "builtin"
    state.builtinSoundPath = NormalizeSoundPath(value or "")
    if state.builtinSoundPath == "" then
        state.builtinSoundPath = GetDefaultBuiltinSoundPath()
    end
    state.soundPath = state.builtinSoundPath
    state.useCustomSound = false
    state.customSoundPath = ""
    state.useSharedMediaSound = false
    state.sharedMediaSound = ""

    if state.soundPath ~= "" then
        NS.API.PlayReadyNotification({
            notifyMode = modeSound,
            soundPath = state.soundPath,
        })
    end
end

function SoundFields:SelectSharedMediaSound(state, value)
    value = Trim(value or "")
    state.sharedMediaSound = value
    state.useSharedMediaSound = value ~= ""
    if not state.useSharedMediaSound then
        return
    end

    local _, modeSound = NS.API.GetModes()
    local path = NS.AceOptions:FetchSharedMediaSoundPath(value)
    state.notifyMode = modeSound
    state.soundSource = "sharedmedia"
    state.useCustomSound = false
    state.customSoundPath = ""
    state.soundPath = NormalizeSoundPath(path)
    if state.soundPath ~= "" then
        NS.API.PlayReadyNotification({
            notifyMode = modeSound,
            soundPath = state.soundPath,
        })
    end
end

function SoundFields:InstallHandlers(editor, frame)
    if not editor or not frame or not frame.widgets then
        return
    end

    local widgets = frame.widgets
    if widgets.sourceDrop then
        widgets.sourceDrop.qfxsaOnValueChanged = function(value)
            if editor and type(editor.PullFromWidgets) == "function" then
                editor:PullFromWidgets()
            end
            local state = NS.AceOptions:GetState()
            self:ApplySourceToState(state, value, widgets)
            editor:Refresh()
        end
    end

    if widgets.builtinDrop then
        widgets.builtinDrop.qfxsaOnValueChanged = function(value)
            if editor and type(editor.PullFromWidgets) == "function" then
                editor:PullFromWidgets()
            end
            local state = NS.AceOptions:GetState()
            self:SelectBuiltinSound(state, value)
            editor:Refresh()
        end
    end

    if widgets.sharedMediaDrop then
        widgets.sharedMediaDrop.qfxsaOnValueChanged = function(value)
            if editor and type(editor.PullFromWidgets) == "function" then
                editor:PullFromWidgets()
            end
            local state = NS.AceOptions:GetState()
            self:SelectSharedMediaSound(state, value)
            editor:Refresh()
        end
    end
end
