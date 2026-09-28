local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.EditorActions = NS.UI.EditorActions or {}

local Actions = NS.UI.EditorActions
local Widgets = NS.UI.Widgets
local VisualPreview = NS.UI.VisualPositionPreview or {}
local Layout = NS.UI.EditorLayout or {}
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local Utils = NS.Utils or {}
local CONST = NS.Constants or {}
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0

-- Reads a multi-select scope dropdown into a saved map. "Nothing concrete
-- selected" means the whole scope (all races / classes / specs).
local function ReadScopeDropdownMap(dropdown, allID)
    local concrete = {}
    local hasConcrete = false
    if dropdown and Widgets and type(Widgets.GetMultiDropdownValues) == "function" then
        for value, enabled in pairs(Widgets:GetMultiDropdownValues(dropdown) or {}) do
            value = tonumber(value) or 0
            if enabled == true and value > 0 then
                concrete[value] = true
                hasConcrete = true
            end
        end
    end
    if not hasConcrete then
        return { [allID] = true }
    end
    return concrete
end

local function GetState()
    if NS.AceOptions and type(NS.AceOptions.GetState) == "function" then
        return NS.AceOptions:GetState()
    end
    return {}
end

local function Pull(owner)
    if owner and type(owner.PullFromWidgets) == "function" then
        owner:PullFromWidgets()
    end
end

local function Refresh(owner)
    if owner and type(owner.Refresh) == "function" then
        owner:Refresh()
    end
end

local function RefreshScrollRange(owner, revealBottom)
    local frame = owner and owner.frame
    local host = frame and frame.contentHost
    if not host then
        return
    end

    local function Apply()
        if host.UpdateScrollRange then
            host:UpdateScrollRange()
        end
        if revealBottom and host.slider and host.slider.GetMinMaxValues then
            local _, maxValue = host.slider:GetMinMaxValues()
            maxValue = tonumber(maxValue) or 0
            if maxValue > 0 and host.slider.SetValue then
                host.slider:SetValue(maxValue)
            end
        end
    end

    Apply()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, Apply)
    end
end

function Actions:Install(owner, frame)
    if not owner or not frame or not frame.widgets then
        return
    end

    local widgets = frame.widgets
    local tabCooldown = widgets.tabCooldown
    local tabCast = widgets.tabCast
    local tabBloodlust = widgets.tabBloodlust
    local tabSettings = widgets.tabSettings
    local tabVoice = widgets.tabVoice
    local tabImage = widgets.tabImage
    local tabText = widgets.tabText
    local scopeRaceDrop = widgets.scopeRaceDrop
    local scopeClassDrop = widgets.scopeClassDrop
    local scopeSpecDrop = widgets.scopeSpecDrop
    local actionSave = widgets.actionSave
    local actionTest = widgets.actionTest
    local checkTalent = widgets.checkTalent
    local cdModeDrop = widgets.cdModeDrop
    local cdmSkillDrop = widgets.cdmSkillDrop
    local skillFilterDrop = widgets.skillFilterDrop
    local loadTalentEnabled = widgets.loadTalentEnabled
    local delayEnabled = widgets.delayEnabled
    local voiceEnabled = widgets.voiceEnabled
    local imageEnabled = widgets.imageEnabled
    local textEnabled = widgets.textEnabled
    local conditionActionsDrop = widgets.conditionActionsDrop
    local castConditionActionsDrop = widgets.castConditionActionsDrop
    local castDelayModeDrop = widgets.castDelayModeDrop
    local castImmediateEnabled = widgets.castImmediateEnabled
    local castDelayEnabled = widgets.castDelayEnabled
    local imageSourceDrop = widgets.imageSourceDrop
    local imageIconID = widgets.imageIconID
    local imagePath = widgets.imagePath
    local imageSize = widgets.imageSize
    local textSize = widgets.textSize
    local textAlert = widgets.textAlert
    local spellId = widgets.spellId
    local eventTypeDrop = widgets.eventTypeDrop
    local eventLoadWorld = widgets.eventLoadWorld
    local eventLoadDelve = widgets.eventLoadDelve
    local eventLoadDungeon = widgets.eventLoadDungeon
    local eventLoadRaid = widgets.eventLoadRaid
    local eventDungeonModeDrop = widgets.eventDungeonModeDrop
    local eventRaidModeDrop = widgets.eventRaidModeDrop
    local eventDungeonSpecificDrop = widgets.eventDungeonSpecificDrop
    local eventRaidSpecificDrop = widgets.eventRaidSpecificDrop
    local objectTypeDrop = widgets.objectTypeDrop
    local itemLoadEquipped = widgets.itemLoadEquipped
    local itemLoadBags = widgets.itemLoadBags
    local itemLoadSameName = widgets.itemLoadSameName
    local imageDurationEnabled = widgets.imageDurationEnabled
    local textDurationEnabled = widgets.textDurationEnabled
    local textCooldownCountdown = widgets.textCooldownCountdown
    local textAttachDrop = widgets.textAttachDrop
    local textVAlignDrop = widgets.textVAlignDrop
    local textHAlignDrop = widgets.textHAlignDrop
    local customEventEnabled = widgets.customEventEnabled
    local customTickerEnabled = widgets.customTickerEnabled
    local customEventsDrop = widgets.customEventsDrop
    local customConditionVarDrop = widgets.customConditionVarDrop
    local customTestButton = widgets.customTestButton
    local customNotifyRows = widgets.customNotifyRows
    local customNotifyAddButton = widgets.customNotifyAddButton
    local customNotifyActionsDrop = widgets.customNotifyActionsDrop
    local customConditionLogicDrop = widgets.customConditionLogicDrop

    -- Main type selection is now handled by the add-type selector before the editor opens.
    -- These compatibility widgets are hidden in EditorFrameBuilder, so keep them inert.
    if tabCooldown then tabCooldown:SetScript("OnClick", nil) end
    if tabCast then tabCast:SetScript("OnClick", nil) end
    if tabBloodlust then tabBloodlust:SetScript("OnClick", nil) end

    local function SwitchAlertTab(alertTab)
        Pull(owner)
        local state = GetState()
        alertTab = tostring(alertTab or "settings")
        if alertTab ~= "settings" and alertTab ~= "voice" and alertTab ~= "image" and alertTab ~= "text" then
            alertTab = "settings"
        end
        state.activeAlertTab = alertTab
        if frame then
            frame.qfxsaLastActiveAlertTab = nil
        end
        Refresh(owner)
        if frame and frame.contentHost then
            if frame.contentHost.slider then frame.contentHost.slider:SetValue(0) end
            if frame.contentHost.scrollFrame then frame.contentHost.scrollFrame:SetVerticalScroll(0) end
            if frame.contentHost.UpdateScrollRange then frame.contentHost:UpdateScrollRange() end
        end
    end


    local function RefreshPreview()
        if VisualPreview and type(VisualPreview.Refresh) == "function" then
            VisualPreview:Refresh(owner)
        end
    end

    local function RefreshRuntimeVisualFromEditor()
        local state = GetState()
        local selectedKey = tostring(state.selectedKey or "")
        if selectedKey == "" then
            return false
        end
        local bridge = NS.Core and NS.Core.RuntimeBridge
        local applied = false
        if bridge and type(bridge.ApplyEditorVisualState) == "function" then
            applied = bridge:ApplyEditorVisualState(selectedKey, state) == true
        end
        if applied then
            return true
        end

        -- The cooldown timer may already have been deleted after its final
        -- Remaining=0 pass, while its visual alert is still on screen.  In that
        -- case refresh the currently visible visual for this saved entry instead
        -- of hiding everything.
        local notifierBridge = NS.Core and NS.Core.NotifierBridge
        if notifierBridge and type(notifierBridge.RefreshActiveVisualForKey) == "function" then
            return notifierBridge:RefreshActiveVisualForKey(selectedKey, state) == true
        end
        return false
    end

    local function RefreshImageIconPreview()
        Pull(owner)
        if NS.UI and NS.UI.EditorFields and type(NS.UI.EditorFields.UpdateImageIconPreview) == "function" then
            NS.UI.EditorFields:UpdateImageIconPreview(owner)
        end
        RefreshPreview()
    end

    local function ShowPreview()
        if VisualPreview and type(VisualPreview.Show) == "function" then
            VisualPreview:Show(owner)
        end
    end

    local function HidePreview()
        if VisualPreview and type(VisualPreview.Hide) == "function" then
            VisualPreview:Hide()
        end
    end

    local function RefreshEditablePreview()
        local state = GetState()
        if state.imageEnabled == true or state.textEnabled == true then
            ShowPreview()
        else
            HidePreview()
        end
    end

    local function RefreshDurationChecksFromState(state)
        state = state or GetState()
        if imageDurationEnabled then imageDurationEnabled:SetChecked(state.imageDurationEnabled == true) end
        if textDurationEnabled then textDurationEnabled:SetChecked(state.textDurationEnabled == true) end
    end

    local function SyncLinkedDurationState(state)
        state = state or GetState()
        if Utils.SyncLinkedVisualDurations then
            Utils.SyncLinkedVisualDurations(state)
        end
        RefreshDurationChecksFromState(state)
    end

    local function SetLinkedDurationEnabled(checked, singleKey)
        Pull(owner)
        local state = GetState()
        checked = checked == true
        if state.imageEnabled == true and state.textEnabled == true then
            state.imageDurationEnabled = checked
            state.textDurationEnabled = checked
        elseif singleKey == "image" then
            state.imageDurationEnabled = checked
        elseif singleKey == "text" then
            state.textDurationEnabled = checked
        end
        SyncLinkedDurationState(state)
        Refresh(owner)
        RefreshPreview()
    end

    local function SetBoxNumber(box, value)
        value = tonumber(value) or 0
        value = value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
        if box then box:SetText(tostring(value)) end
        return value
    end

    local function RoundPixel(value, fallback)
        local n = tonumber(value)
        if n == nil then n = tonumber(fallback) or 0 end
        return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
    end

    local function ApplyDefaultLinkedLayout(state)
        state.textAttachMode = "outside"
        state.textVAlign = "bottom"
        state.textHAlign = "center"
        state.textOffsetX = 0
        state.textOffsetY = 0
    end

    local function GetLinkedTextOffset(state)
        local imageSize = math.max(16, tonumber(state.imageSize) or 96)
        local textSize = math.max(8, tonumber(state.textSize) or 24)
        local attach = tostring(state.textAttachMode or "outside")
        if attach ~= "inside" then attach = "outside" end
        local v = tostring(state.textVAlign or "bottom")
        if v ~= "top" and v ~= "middle" then v = "bottom" end
        local h = tostring(state.textHAlign or "center")
        if h ~= "left" and h ~= "right" then h = "center" end
        local ox = tonumber(state.textOffsetX) or 0
        local oy = tonumber(state.textOffsetY) or 0
        local gap = 6
        local x = ox
        local y = oy
        if h == "left" then
            x = x - math.floor(imageSize / 2)
        elseif h == "right" then
            x = x + math.floor(imageSize / 2)
        end
        if attach == "inside" then
            if v == "top" then
                y = y + math.floor(imageSize / 2) - math.floor(textSize / 2)
            elseif v == "bottom" then
                y = y - math.floor(imageSize / 2) + math.floor(textSize / 2)
            end
        else
            if v == "top" then
                y = y + math.floor(imageSize / 2) + gap + math.floor(textSize / 2)
            elseif v == "bottom" then
                y = y - math.floor(imageSize / 2) - gap - math.floor(textSize / 2)
            end
        end
        return RoundPixel(x, 0), RoundPixel(y, 0)
    end

    local function GetLinkedTextPosition(state)
        local dx, dy = GetLinkedTextOffset(state)
        return RoundPixel((tonumber(state.imageX) or 0) + dx, 0), RoundPixel((tonumber(state.imageY) or 120) + dy, 120)
    end

    local function AnchorImageToCurrentTextPosition(state)
        local dx, dy = GetLinkedTextOffset(state)
        state.imageX = RoundPixel((tonumber(state.textX) or 0) - dx, 0)
        state.imageY = RoundPixel((tonumber(state.textY) or 120) - dy, 120)
    end

    local function ApplyVisualModeTransition(oldImage, oldText, newImage, newText)
        oldImage = oldImage == true
        oldText = oldText == true
        newImage = newImage == true
        newText = newText == true
        if oldImage == newImage and oldText == newText then
            return false
        end
        local state = GetState()
        if oldImage and oldText then
            if newText and not newImage then
                local tx, ty = GetLinkedTextPosition(state)
                state.textX = tx
                state.textY = ty
            end
            return true
        end
        if newImage and newText then
            if oldImage and not oldText then
                ApplyDefaultLinkedLayout(state)
            elseif oldText and not oldImage then
                ApplyDefaultLinkedLayout(state)
                AnchorImageToCurrentTextPosition(state)
            else
                ApplyDefaultLinkedLayout(state)
            end
            return true
        end
        return true
    end


    local function NudgePosition(xBox, yBox, dx, dy, stateXKey, stateYKey)
        Pull(owner)
        local state = GetState()
        local x = SetBoxNumber(xBox, (tonumber(xBox and xBox:GetText()) or tonumber(state[stateXKey]) or 0) + (dx or 0))
        local y = SetBoxNumber(yBox, (tonumber(yBox and yBox:GetText()) or tonumber(state[stateYKey]) or 0) + (dy or 0))
        state[stateXKey] = x
        state[stateYKey] = y
        RefreshPreview()
    end


    local function ResetEditorVisualPosition(kind, xBox, yBox, stateXKey, stateYKey)
        Pull(owner)
        if VisualPreview and type(VisualPreview.ResetEditorPosition) == "function" then
            VisualPreview:ResetEditorPosition(owner, kind)
            RefreshPreview()
            return
        end
        local state = GetState()
        local fallbackX, fallbackY = -360, 220
        local x = SetBoxNumber(xBox, fallbackX)
        local y = SetBoxNumber(yBox, fallbackY)
        state[stateXKey] = x
        state[stateYKey] = y
        RefreshPreview()
    end

    local function NormalizeCustomInterval(value)
        local n = tonumber(value) or 0.5
        if n < 0.2 then n = 0.2 end
        if n > 60 then n = 60 end
        return tonumber(string.format("%.2f", n)) or 0.5
    end

    local function ChooseFirstCustomVar(vars)
        local keys = {}
        if type(vars) == "table" then
            for key, enabled in pairs(vars) do
                if enabled == true and type(key) == "string" and key ~= "" then
                    keys[#keys + 1] = key
                end
            end
        end
        table.sort(keys)
        return keys[1] or ""
    end

    local function PrintAddonMessage(message)
        print("[QFX-SA] " .. tostring(message or ""))
    end

    if tabSettings then
        tabSettings:SetScript("OnClick", function()
            SwitchAlertTab("settings")
        end)
    end

    if tabVoice then
        tabVoice:SetScript("OnClick", function()
            SwitchAlertTab("voice")
        end)
    end
    if tabImage then
        tabImage:SetScript("OnClick", function()
            SwitchAlertTab("image")
        end)
    end
    if tabText then
        tabText:SetScript("OnClick", function()
            SwitchAlertTab("text")
        end)
    end

    if eventTypeDrop then
        eventTypeDrop.qfxsaOnValueChanged = function(value)
            local state = GetState()
            state.eventKey = tostring(value or "")
        end
    end

    local function RefreshEventLoadContexts(clicked)
        Pull(owner)
        local state = GetState()
        local selected = state.eventLoadContexts or {}
        if not (selected.world or selected.delve or selected.dungeon or selected.raid) and clicked then
            clicked:SetChecked(true)
            Pull(owner)
        end
        Refresh(owner)
    end

    for _, check in ipairs({ eventLoadWorld, eventLoadDelve, eventLoadDungeon, eventLoadRaid }) do
        if check then
            check:SetScript("OnClick", function(self)
                RefreshEventLoadContexts(self)
            end)
        end
    end

    if eventDungeonModeDrop then
        eventDungeonModeDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().eventDungeonMode = tostring(value or "any")
            Refresh(owner)
        end
    end
    if eventRaidModeDrop then
        eventRaidModeDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().eventRaidMode = tostring(value or "any")
            Refresh(owner)
        end
    end
    if eventDungeonSpecificDrop then
        eventDungeonSpecificDrop.qfxsaOnValueChanged = function()
            Pull(owner)
        end
    end
    if eventRaidSpecificDrop then
        eventRaidSpecificDrop.qfxsaOnValueChanged = function()
            Pull(owner)
        end
    end

    -- Always-visible scope dropdowns. Handlers update the saved maps directly
    -- (without a full refresh) so toggling one entry keeps the popup open.
    local function RefreshSpecScopeDropdown()
        local state = GetState()
        local classMap = state.alertClassIDs or { [ALL_CLASSES_ID] = true }
        local selector = NS.UI and NS.UI.ScopeSelector
        local items = selector and selector.GetScopeSpecItems and selector:GetScopeSpecItems(classMap) or {}
        local allowed = {}
        for _, item in ipairs(items) do
            local specID = tonumber(item and item.value) or 0
            if specID > 0 then
                allowed[specID] = true
            end
        end
        local specMap = {}
        for specID, enabled in pairs(state.alertSpecIDs or {}) do
            specID = tonumber(specID) or 0
            if enabled == true and (specID == 0 or allowed[specID]) then
                specMap[specID] = true
            end
        end
        if specMap[ALL_SPECS_ID] == true then
            specMap = { [ALL_SPECS_ID] = true }
        end
        local hasConcrete = false
        for specID, enabled in pairs(specMap) do
            if enabled == true and (tonumber(specID) or 0) > 0 then
                hasConcrete = true
            end
        end
        if not hasConcrete then
            specMap = { [ALL_SPECS_ID] = true }
        end
        state.alertSpecIDs = specMap
        state.customSpecIDs = specMap
        if scopeSpecDrop and Widgets and Widgets.SetMultiDropdownValues then
            Widgets:SetDropdownItems(scopeSpecDrop, items)
            Widgets:SetMultiDropdownValues(scopeSpecDrop, specMap, L("PLACEHOLDER_SELECT_SPECS"))
        end
    end

    if scopeRaceDrop then
        scopeRaceDrop.qfxsaOnValueChanged = function()
            Pull(owner)
            local state = GetState()
            local map = ReadScopeDropdownMap(scopeRaceDrop, ALL_RACES_ID)
            state.alertRaceIDs = map
            state.customRaceIDs = map
        end
    end

    if scopeClassDrop then
        scopeClassDrop.qfxsaOnValueChanged = function()
            Pull(owner)
            local state = GetState()
            local map = ReadScopeDropdownMap(scopeClassDrop, ALL_CLASSES_ID)
            state.alertClassIDs = map
            state.customClassIDs = map
            RefreshSpecScopeDropdown()
        end
    end

    if scopeSpecDrop then
        scopeSpecDrop.qfxsaOnValueChanged = function()
            Pull(owner)
            local state = GetState()
            local map = ReadScopeDropdownMap(scopeSpecDrop, ALL_SPECS_ID)
            state.alertSpecIDs = map
            state.customSpecIDs = map
        end
    end

    if objectTypeDrop then
        objectTypeDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            local state = GetState()
            state.objectType = tostring(value or "") == "item" and "item" or "spell"
            if state.objectType == "item" then
                state.checkTalent = false
                state.loadTalentEnabled = false
                state.itemLoadMode = state.itemLoadMode or ITEM_LOAD_NONE
                state.cdMode = "fixed"
                state.gameStateCD = false
            else
                state.itemLoadMode = ITEM_LOAD_NONE
                state.itemLoadSameName = false
            end
            Refresh(owner)
            RefreshImageIconPreview()
        end
    end


    local function SetActionDropdownValues(dropdown)
        if not (dropdown and Widgets and Widgets.SetMultiDropdownValues) then
            return
        end
        local state = GetState()
        Widgets:SetMultiDropdownValues(dropdown, {
            voice = state.voiceEnabled == true,
            image = state.imageEnabled == true,
            text = state.textEnabled == true,
        }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
    end

    local function SyncDropdownFromActionChecks()
        SetActionDropdownValues(conditionActionsDrop)
        SetActionDropdownValues(castConditionActionsDrop)
    end

    local function SyncActionChecksFromDropdown(dropdown)
        if not (dropdown and Widgets and Widgets.GetMultiDropdownValues) then
            return
        end
        local selectedActions = Widgets:GetMultiDropdownValues(dropdown)
        local state = GetState()
        state.voiceEnabled = selectedActions.voice == true
        state.imageEnabled = selectedActions.image == true
        state.textEnabled = selectedActions.text == true
        if voiceEnabled then voiceEnabled:SetChecked(state.voiceEnabled == true) end
        if imageEnabled then imageEnabled:SetChecked(state.imageEnabled == true) end
        if textEnabled then textEnabled:SetChecked(state.textEnabled == true) end
        SyncLinkedDurationState(state)
        SyncDropdownFromActionChecks()
    end

    local function InstallActionDropdownHandler(dropdown)
        if not dropdown then
            return
        end
        dropdown.qfxsaOnValueChanged = function()
            -- Keep the multi-select dropdown open while toggling multiple actions.
            -- The state is pulled immediately; a full refresh would close the popup.
            local stateBefore = GetState()
            local oldImage = stateBefore.imageEnabled == true
            local oldText = stateBefore.textEnabled == true
            Pull(owner)
            -- Keep the action selector and the actual Voice/Image/Text enable checkboxes linked.
            SyncActionChecksFromDropdown(dropdown)
            local state = GetState()
            ApplyVisualModeTransition(oldImage, oldText, state.imageEnabled == true, state.textEnabled == true)
            RefreshRuntimeVisualFromEditor()
            Refresh(owner)
            RefreshEditablePreview()
        end
    end

    InstallActionDropdownHandler(conditionActionsDrop)
    InstallActionDropdownHandler(castConditionActionsDrop)


    local function InstallSizeSlider(slider, stateKey, minValue, maxValue)
        if not (slider and slider.HookScript and slider.GetValue) then
            return
        end
        slider:HookScript("OnValueChanged", function(self, value)
            value = math.floor((tonumber(value) or 0) + 0.5)
            value = math.max(tonumber(minValue) or value, math.min(tonumber(maxValue) or value, value))
            if Layout.UpdateValueSliderText then
                Layout.UpdateValueSliderText(self, value)
            end
            local state = GetState()
            state[stateKey] = value
            RefreshPreview()
        end)
    end

    InstallSizeSlider(imageSize, "imageSize", 16, 256)
    InstallSizeSlider(textSize, "textSize", 8, 64)

    if imageSourceDrop then
        imageSourceDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            local state = GetState()
            state.imageSource = tostring(value or "auto")
            Refresh(owner)
            if NS.UI and NS.UI.EditorFields and type(NS.UI.EditorFields.UpdateImageIconPreview) == "function" then
                NS.UI.EditorFields:UpdateImageIconPreview(owner)
            end
            RefreshPreview()
        end
    end

    if imageIconID and imageIconID.HookScript then
        imageIconID:HookScript("OnTextChanged", function()
            RefreshImageIconPreview()
        end)
    end
    if imagePath and imagePath.HookScript then
        imagePath:HookScript("OnTextChanged", function()
            RefreshImageIconPreview()
        end)
    end
    if spellId and spellId.HookScript then
        spellId:HookScript("OnTextChanged", function()
            local state = GetState()
            if tostring(state.imageSource or "auto") == "auto" then
                RefreshImageIconPreview()
            end
        end)
    end

    if textAlert and textAlert.HookScript then
        textAlert:HookScript("OnTextChanged", function()
            local state = GetState()
            state.textAlert = tostring(textAlert:GetText() or "")
            RefreshPreview()
        end)
    end

    local function SetItemLoadMode(mode)
        Pull(owner)
        local state = GetState()
        state.objectType = "item"
        state.checkTalent = false
        state.itemLoadMode = mode or ITEM_LOAD_NONE
        if state.itemLoadMode ~= ITEM_LOAD_BAGS then
            state.itemLoadSameName = false
        end
        Refresh(owner)
        RefreshImageIconPreview()
    end

    if itemLoadEquipped then
        itemLoadEquipped:SetScript("OnClick", function(self)
            SetItemLoadMode((self and self.GetChecked and self:GetChecked() == true) and ITEM_LOAD_EQUIPPED or ITEM_LOAD_NONE)
        end)
    end
    if itemLoadBags then
        itemLoadBags:SetScript("OnClick", function(self)
            SetItemLoadMode((self and self.GetChecked and self:GetChecked() == true) and ITEM_LOAD_BAGS or ITEM_LOAD_NONE)
        end)
    end
    if itemLoadSameName then
        itemLoadSameName:SetScript("OnClick", function(self)
            Pull(owner)
            local state = GetState()
            state.objectType = "item"
            state.checkTalent = false
            state.itemLoadMode = ITEM_LOAD_BAGS
            state.itemLoadSameName = self and self.GetChecked and self:GetChecked() == true or false
            Refresh(owner)
            RefreshImageIconPreview()
        end)
    end

    if textAttachDrop then
        textAttachDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().textAttachMode = tostring(value or "outside")
            RefreshPreview()
        end
    end
    if textVAlignDrop then
        textVAlignDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().textVAlign = tostring(value or "bottom")
            RefreshPreview()
        end
    end
    if textHAlignDrop then
        textHAlignDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().textHAlign = tostring(value or "center")
            RefreshPreview()
        end
    end

    if customEventEnabled then
        customEventEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.customUseEvents = button and button.GetChecked and button:GetChecked() == true or false
            Refresh(owner)
        end)
    end

    if customTickerEnabled then
        customTickerEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.customUseTicker = button and button.GetChecked and button:GetChecked() == true or false
            state.customInterval = NormalizeCustomInterval(state.customInterval)
            Refresh(owner)
        end)
    end


    if customEventsDrop then
        customEventsDrop.qfxsaOnValueChanged = function()
            Pull(owner)
            local state = GetState()
            if Widgets and type(Widgets.GetMultiDropdownValues) == "function" then
                state.customEvents = Widgets:GetMultiDropdownValues(customEventsDrop)
            end
        end
    end

    if customConditionVarDrop then
        customConditionVarDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            GetState().customResultVar = tostring(value or "")
            Refresh(owner)
        end
    end

    if type(customNotifyRows) == "table" then
        for i, row in ipairs(customNotifyRows) do
            local rowIndex = i
            if row.varDrop then
                row.varDrop.qfxsaOnValueChanged = function()
                    Pull(owner)
                end
            end
            if row.opDrop then
                row.opDrop.qfxsaOnValueChanged = function()
                    Pull(owner)
                end
            end
            if row.addButton then
                row.addButton:SetScript("OnClick", function()
                    Pull(owner)
                    local state = GetState()
                    local maxCount = tonumber(widgets.maxCustomNotify) or 8
                    local count = math.max(1, math.min(maxCount, tonumber(state._mcdCustomNotifyVisibleCount) or tonumber(state.customNotifyCount) or 1))
                    if count >= maxCount then
                        return
                    end
                    state.customNotifications = type(state.customNotifications) == "table" and state.customNotifications or {}
                    state.customNotifications[count + 1] = state.customNotifications[count + 1] or {
                        resultVar = "",
                        conditionOp = "<=",
                        conditionValue = "0",
                    }
                    state.customNotifyCount = count + 1
                    state._mcdCustomNotifyVisibleCount = count + 1
                    state._mcdCustomNotifyManualCount = count + 1
                    Refresh(owner)
                    RefreshScrollRange(owner, true)
                end)
            end
            if row.deleteButton and rowIndex > 1 then
                row.deleteButton:SetScript("OnClick", function()
                    Pull(owner)
                    local state = GetState()
                    local maxCount = tonumber(widgets.maxCustomNotify) or 8
                    local count = math.max(1, math.min(maxCount, tonumber(state._mcdCustomNotifyVisibleCount) or tonumber(state.customNotifyCount) or 1))
                    if count <= 1 or rowIndex > count then
                        return
                    end
                    local list = type(state.customNotifications) == "table" and state.customNotifications or {}
                    table.remove(list, rowIndex)
                    state.customNotifications = list
                    state.customNotifyCount = math.max(1, count - 1)
                    state._mcdCustomNotifyVisibleCount = state.customNotifyCount
                    state._mcdCustomNotifyManualCount = state.customNotifyCount
                    Refresh(owner)
                    RefreshScrollRange(owner, false)
                end)
            end
        end
    end

    if customConditionLogicDrop then
        customConditionLogicDrop.qfxsaOnValueChanged = function()
            Pull(owner)
        end
    end

    if customNotifyActionsDrop then
        customNotifyActionsDrop.qfxsaOnValueChanged = function()
            Pull(owner)
        end
    end

    if customNotifyAddButton then
        customNotifyAddButton:SetScript("OnClick", nil)
        if customNotifyAddButton.Hide then customNotifyAddButton:Hide() end
    end

    if customTestButton then
        customTestButton:SetScript("OnClick", function()
            Pull(owner)
            local state = GetState()
            local runtime = NS.Core and NS.Core.CustomRuntime
            if not (runtime and type(runtime.TestCode) == "function") then
                PrintAddonMessage(L("MSG_CUSTOM_TEST_FAILED", "Custom runtime missing"))
                return
            end
            local ok, varsOrErr = runtime:TestCode(state.customCode or "", "CUSTOM_TEST")
            if not ok then
                PrintAddonMessage(L("MSG_CUSTOM_TEST_FAILED", tostring(varsOrErr or "")))
                return
            end
            state.customResultVars = varsOrErr or {}
            if tostring(state.customResultVar or "") == "" or not state.customResultVars[state.customResultVar] then
                state.customResultVar = ChooseFirstCustomVar(state.customResultVars)
            end
            local count = 0
            for _, enabled in pairs(state.customResultVars or {}) do
                if enabled == true then count = count + 1 end
            end
            PrintAddonMessage(L("MSG_CUSTOM_TEST_OK", count))
            Refresh(owner)
        end)
    end

    if actionSave then
        actionSave:SetScript("OnClick", function()
            Pull(owner)
            local state = GetState()
            if tostring(state.entryType or "") == "bloodlust" then
                if NS.AceOptions and type(NS.AceOptions.SaveBloodlustConfig) == "function" and NS.AceOptions:SaveBloodlustConfig() then
                    if type(owner.Close) == "function" then
                        owner:Close()
                        HidePreview()
                    end
                end
                return
            end

            if NS.AceOptions and type(NS.AceOptions.SaveEntry) == "function" and NS.AceOptions:SaveEntry() then
                if type(owner.Close) == "function" then
                    owner:Close()
                        HidePreview()
                end
            end
        end)
    end

    if actionTest then
        actionTest:SetScript("OnClick", function()
            Pull(owner)
            local state = GetState()
            if tostring(state.entryType or "") == "bloodlust" then
                if NS.AceOptions and type(NS.AceOptions.TestBloodlustConfig) == "function" then
                    NS.AceOptions:TestBloodlustConfig()
                end
                return
            end
            if NS.AceOptions and type(NS.AceOptions.TestCurrent) == "function" then
                NS.AceOptions:TestCurrent()
            end
        end)
    end

    if checkTalent then
        checkTalent:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.checkTalent = button:GetChecked() == true
            if not state.checkTalent then
                state.talentId = 0
                state.talentName = ""
                state.talentCD = 0
            end
            Refresh(owner)
        end)
    end

    if cdModeDrop then
        cdModeDrop.qfxsaOnValueChanged = function(value)
            Pull(owner)
            local state = GetState()
            local mode = tostring(value or "")
            if mode ~= "ready" and mode ~= "cooldown" then
                mode = "fixed"
            end
            state.cdMode = mode
            state.gameStateCD = mode ~= "fixed"
            Refresh(owner)
        end
    end

    if cdmSkillDrop then
        -- Picking a Cooldown Manager skill just fills the spell ID and name
        -- (and the base CD through the normal autofill); everything else stays
        -- editable as before.
        cdmSkillDrop.qfxsaOnValueChanged = function(value)
            local spellID = tonumber(value)
            if not spellID or spellID <= 0 then
                return
            end
            Pull(owner)
            local state = GetState()
            state.spellId = spellID
            local ace = NS.AceOptions
            if ace and type(ace.AutofillFromSpellId) == "function" then
                ace:AutofillFromSpellId()
            end
            Refresh(owner)
        end
    end

    if skillFilterDrop then
        -- Selects which spec's skills the quick picker lists; only the picker
        -- is rebuilt so the editor is not fully refreshed on each change.
        skillFilterDrop.qfxsaOnValueChanged = function(value)
            local frame = owner.frame
            if not (frame and cdmSkillDrop) then
                return
            end
            local selectedSpec = tonumber(value) or 0
            frame.qfxsaSkillFilter = selectedSpec
            local fields = NS.UI and NS.UI.EditorFields
            local items = fields and type(fields.FilterSkillItems) == "function"
                and fields:FilterSkillItems(frame.qfxsaCdmSkillItems or {}, selectedSpec) or {}
            Widgets:SetDropdownItems(cdmSkillDrop, items)
            local fallback = #items > 0 and L("PLACEHOLDER_CDM_PICK") or L("PLACEHOLDER_NO_MATCH_SKILL")
            local state = GetState()
            Widgets:SetDropdownValue(cdmSkillDrop, tonumber(state.spellId) or 0, fallback)
            Widgets:SetDropdownEnabled(cdmSkillDrop, #items > 0)
        end
    end

    if loadTalentEnabled then
        loadTalentEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.loadTalentEnabled = button:GetChecked() == true
            state.talentLoadFilter = state.loadTalentEnabled
            if not state.loadTalentEnabled then
                state.loadTalentId = 0
                state.loadTalentName = ""
            end
            Refresh(owner)
        end)
    end

    if textCooldownCountdown then
        textCooldownCountdown:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.textCooldownCountdown = button:GetChecked() == true
            Refresh(owner)
        end)
    end

    if delayEnabled then
        delayEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.delayEnabled = button:GetChecked() == true
            Refresh(owner)
        end)
    end

    if castImmediateEnabled then
        castImmediateEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            local checked = button:GetChecked() == true
            if checked then
                state.delayEnabled = false
            else
                -- Keep exactly one execution mode selected.  If Immediate is
                -- unchecked manually, fall back to delayed execution.
                state.delayEnabled = true
            end
            state.castDelayMode = "show"
            Refresh(owner)
        end)
    end

    if castDelayEnabled then
        castDelayEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.delayEnabled = button:GetChecked() == true
            state.castDelayMode = "show"
            Refresh(owner)
        end)
    end

    if castDelayModeDrop then
        castDelayModeDrop.qfxsaOnValueChanged = function()
            Pull(owner)
            GetState().castDelayMode = "show"
            Refresh(owner)
        end
        if castDelayModeDrop.Hide then castDelayModeDrop:Hide() end
    end


    if voiceEnabled then
        voiceEnabled:SetScript("OnClick", function(button)
            Pull(owner)
            local state = GetState()
            state.voiceEnabled = button:GetChecked() == true
            SyncDropdownFromActionChecks()
            Refresh(owner)
        end)
    end

    if imageEnabled then
        imageEnabled:SetScript("OnClick", function(button)
            local stateBefore = GetState()
            local oldImage = stateBefore.imageEnabled == true
            local oldText = stateBefore.textEnabled == true
            Pull(owner)
            local state = GetState()
            state.imageEnabled = button:GetChecked() == true
            ApplyVisualModeTransition(oldImage, oldText, state.imageEnabled == true, state.textEnabled == true)
            SyncLinkedDurationState(state)
            SyncDropdownFromActionChecks()
            RefreshRuntimeVisualFromEditor()
            Refresh(owner)
            RefreshEditablePreview()
        end)
    end

    if textEnabled then
        textEnabled:SetScript("OnClick", function(button)
            local stateBefore = GetState()
            local oldImage = stateBefore.imageEnabled == true
            local oldText = stateBefore.textEnabled == true
            Pull(owner)
            local state = GetState()
            state.textEnabled = button:GetChecked() == true
            ApplyVisualModeTransition(oldImage, oldText, state.imageEnabled == true, state.textEnabled == true)
            SyncLinkedDurationState(state)
            SyncDropdownFromActionChecks()
            RefreshRuntimeVisualFromEditor()
            Refresh(owner)
            RefreshEditablePreview()
        end)
    end

    if imageDurationEnabled then
        imageDurationEnabled:SetScript("OnClick", function(button)
            SetLinkedDurationEnabled(button:GetChecked() == true, "image")
        end)
    end

    if textDurationEnabled then
        textDurationEnabled:SetScript("OnClick", function(button)
            SetLinkedDurationEnabled(button:GetChecked() == true, "text")
        end)
    end

    if widgets.imagePreviewButton then widgets.imagePreviewButton:SetScript("OnClick", ShowPreview) end
    if widgets.textPreviewButton then widgets.textPreviewButton:SetScript("OnClick", ShowPreview) end
    if widgets.layoutPreviewButton then widgets.layoutPreviewButton:SetScript("OnClick", ShowPreview) end
    if widgets.imageHidePreviewButton then widgets.imageHidePreviewButton:SetScript("OnClick", HidePreview) end
    if widgets.textHidePreviewButton then widgets.textHidePreviewButton:SetScript("OnClick", HidePreview) end
    if widgets.layoutHidePreviewButton then widgets.layoutHidePreviewButton:SetScript("OnClick", HidePreview) end

    if widgets.imageNudgeUp then widgets.imageNudgeUp:SetScript("OnClick", function() NudgePosition(widgets.imageX, widgets.imageY, 0, 1, "imageX", "imageY") end) end
    if widgets.imageNudgeDown then widgets.imageNudgeDown:SetScript("OnClick", function() NudgePosition(widgets.imageX, widgets.imageY, 0, -1, "imageX", "imageY") end) end
    if widgets.imageNudgeLeft then widgets.imageNudgeLeft:SetScript("OnClick", function() NudgePosition(widgets.imageX, widgets.imageY, -1, 0, "imageX", "imageY") end) end
    if widgets.imageNudgeRight then widgets.imageNudgeRight:SetScript("OnClick", function() NudgePosition(widgets.imageX, widgets.imageY, 1, 0, "imageX", "imageY") end) end
    if widgets.imageNudgeReset then widgets.imageNudgeReset:SetScript("OnClick", function() ResetEditorVisualPosition("image", widgets.imageX, widgets.imageY, "imageX", "imageY") end) end

    if widgets.textSingleNudgeUp then widgets.textSingleNudgeUp:SetScript("OnClick", function() NudgePosition(widgets.textX, widgets.textY, 0, 1, "textX", "textY") end) end
    if widgets.textSingleNudgeDown then widgets.textSingleNudgeDown:SetScript("OnClick", function() NudgePosition(widgets.textX, widgets.textY, 0, -1, "textX", "textY") end) end
    if widgets.textSingleNudgeLeft then widgets.textSingleNudgeLeft:SetScript("OnClick", function() NudgePosition(widgets.textX, widgets.textY, -1, 0, "textX", "textY") end) end
    if widgets.textSingleNudgeRight then widgets.textSingleNudgeRight:SetScript("OnClick", function() NudgePosition(widgets.textX, widgets.textY, 1, 0, "textX", "textY") end) end
    if widgets.textSingleNudgeReset then widgets.textSingleNudgeReset:SetScript("OnClick", function() ResetEditorVisualPosition("text", widgets.textX, widgets.textY, "textX", "textY") end) end

    local function NudgeTextOffset(dx, dy)
        Pull(owner)
        local state = GetState()
        state.textOffsetX = SetBoxNumber(widgets.textOffsetX, (tonumber(widgets.textOffsetX and widgets.textOffsetX:GetText()) or tonumber(state.textOffsetX) or 0) + (dx or 0))
        state.textOffsetY = SetBoxNumber(widgets.textOffsetY, (tonumber(widgets.textOffsetY and widgets.textOffsetY:GetText()) or tonumber(state.textOffsetY) or 0) + (dy or 0))
        RefreshPreview()
    end
    if widgets.textNudgeUp then widgets.textNudgeUp:SetScript("OnClick", function() NudgeTextOffset(0, 1) end) end
    if widgets.textNudgeDown then widgets.textNudgeDown:SetScript("OnClick", function() NudgeTextOffset(0, -1) end) end
    if widgets.textNudgeLeft then widgets.textNudgeLeft:SetScript("OnClick", function() NudgeTextOffset(-1, 0) end) end
    if widgets.textNudgeRight then widgets.textNudgeRight:SetScript("OnClick", function() NudgeTextOffset(1, 0) end) end
    if widgets.textNudgeReset then widgets.textNudgeReset:SetScript("OnClick", function() NudgeTextOffset(-(tonumber(widgets.textOffsetX and widgets.textOffsetX:GetText()) or 0), -(tonumber(widgets.textOffsetY and widgets.textOffsetY:GetText()) or 0)) end) end

    -- The CDM skill picker is only usable out of combat (Cooldown Manager data
    -- is not readable there). Rebuild it when combat ends or CDM data loads
    -- while the editor is open.
    if type(CreateFrame) == "function" and not Actions.cdmPickerEventFrame then
        local pickerEventFrame = CreateFrame("Frame")
        pickerEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        pickerEventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
        pickerEventFrame:SetScript("OnEvent", function()
            if frame and frame:IsShown() then
                Refresh(owner)
            end
        end)
        Actions.cdmPickerEventFrame = pickerEventFrame
    end
end
