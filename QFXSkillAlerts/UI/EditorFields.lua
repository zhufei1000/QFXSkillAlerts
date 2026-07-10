local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.UI = NS.UI or {}
NS.UI.EditorFields = NS.UI.EditorFields or {}

local Fields = NS.UI.EditorFields
local Widgets = NS.UI.Widgets
local Layout = NS.UI.EditorLayout or {}
local SoundFields = NS.UI.EditorSoundFields or {}
local PopupLayout = NS.UI.PopupLayout
local L = NS.L or function(key, ...) if select("#", ...) > 0 then return string.format(tostring(key), ...) end return tostring(key) end
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"

local SetNativeLabelColor = Layout.SetNativeLabelColor
local SetEnabled = Layout.SetEnabled
local SetTabVisual = Layout.SetTabVisual
local SetManyShown = Layout.SetManyShown

local function BuildDropdownItems(values)
    local items = {}
    for value, text in pairs(values or {}) do
        items[#items + 1] = { value = value, text = text }
    end
    table.sort(items, function(a, b)
        if tonumber(a.value) == 0 and tonumber(b.value) ~= 0 then return true end
        if tonumber(b.value) == 0 and tonumber(a.value) ~= 0 then return false end
        return tostring(a.text or "") < tostring(b.text or "")
    end)
    return items
end

local DropdownItemCache = {}

local function ClearDropdownItemCache()
    for key in pairs(DropdownItemCache) do
        DropdownItemCache[key] = nil
    end
end

local function GetCachedClassItems()
    if not DropdownItemCache.classItems then
        DropdownItemCache.classItems = BuildDropdownItems(NS.AceOptions:GetClassValues())
    end
    return DropdownItemCache.classItems
end

local function GetCachedSpecItems(classID)
    local key = "spec:" .. tostring(classID or 0)
    if not DropdownItemCache[key] then
        DropdownItemCache[key] = BuildDropdownItems(NS.AceOptions:GetSpecValues(classID))
    end
    return DropdownItemCache[key]
end

local function CopyNumberBoolMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            local numberKey = tonumber(key)
            if value == true and numberKey and numberKey >= 0 then
                copy[numberKey] = true
            end
        end
    end
    return copy
end

local function HasAnySelected(map)
    return type(map) == "table" and next(map) ~= nil
end

local NormalizeCustomClassMap
local NormalizeCustomSpecMap
local NormalizeCustomRaceMap

local function GetAllConcreteClassIDs()
    local ids = {}
    local classOptions = NS.AceOptions and NS.AceOptions.GetClassOptionList and NS.AceOptions:GetClassOptionList() or {}
    for _, classInfo in ipairs(classOptions or {}) do
        local classID = tonumber(classInfo and classInfo.classID) or 0
        if classID > 0 then
            ids[#ids + 1] = classID
        end
    end
    table.sort(ids)
    return ids
end

local function GetAllConcreteSpecIDsForClasses(classMap)
    local specs = {}
    local seen = {}
    local classIDs = {}
    if type(classMap) == "table" and classMap[0] == true then
        classIDs = GetAllConcreteClassIDs()
    else
        for classID, enabled in pairs(classMap or {}) do
            classID = tonumber(classID) or 0
            if enabled == true and classID > 0 then
                classIDs[#classIDs + 1] = classID
            end
        end
        table.sort(classIDs)
    end
    for _, classID in ipairs(classIDs) do
        local specValues = NS.AceOptions and NS.AceOptions.GetSpecValues and NS.AceOptions:GetSpecValues(classID) or {}
        for specID in pairs(specValues or {}) do
            specID = tonumber(specID) or 0
            if specID > 0 and not seen[specID] then
                seen[specID] = true
                specs[#specs + 1] = specID
            end
        end
    end
    table.sort(specs)
    return specs
end

local function ExpandAllClassesForEditor(map, fallbackClassID)
    local normalized = NormalizeCustomClassMap(map, fallbackClassID)
    if normalized[0] ~= true then
        return normalized
    end
    local expanded = {}
    for _, classID in ipairs(GetAllConcreteClassIDs()) do
        expanded[classID] = true
    end
    if next(expanded) == nil then
        expanded[0] = true
    end
    return expanded
end

local function ExpandAllSpecsForEditor(map, classMap, fallbackSpecID)
    local normalized = NormalizeCustomSpecMap(map, fallbackSpecID)
    if normalized[0] ~= true then
        return normalized
    end
    local expanded = {}
    for _, specID in ipairs(GetAllConcreteSpecIDsForClasses(classMap)) do
        expanded[specID] = true
    end
    if next(expanded) == nil then
        expanded[0] = true
    end
    return expanded
end

function NormalizeCustomClassMap(map, fallbackClassID)
    local copy = CopyNumberBoolMap(map)
    if next(copy) == nil then
        local classID = tonumber(fallbackClassID) or 0
        copy[classID > 0 and classID or 0] = true
    end
    if copy[0] == true then
        return { [0] = true }
    end
    return copy
end

function NormalizeCustomSpecMap(map, fallbackSpecID)
    local copy = CopyNumberBoolMap(map)
    if next(copy) == nil then
        local specID = tonumber(fallbackSpecID) or 0
        copy[specID > 0 and specID or 0] = true
    end
    if copy[0] == true then
        return { [0] = true }
    end
    return copy
end

function NormalizeCustomRaceMap(map)
    local copy = CopyNumberBoolMap(map)
    if next(copy) == nil or copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
end

local function CountConcreteSelections(map)
    local count = 0
    for key, enabled in pairs(map or {}) do
        if enabled == true and (tonumber(key) or 0) > 0 then
            count = count + 1
        end
    end
    return count
end

local function BuildScopeSummary(state)
    if NS.UI and NS.UI.ScopeSelector and type(NS.UI.ScopeSelector.BuildSummary) == "function" then
        return NS.UI.ScopeSelector:BuildSummary(state)
    end
    local raceMap = NormalizeCustomRaceMap(state and state.alertRaceIDs)
    local classMap = NormalizeCustomClassMap(state and (state.alertClassIDs or state.customClassIDs), state and state.classID)
    local specMap = NormalizeCustomSpecMap(state and (state.alertSpecIDs or state.customSpecIDs), state and state.specID)
    local raceText = raceMap[ALL_RACES_ID] and L("SCOPE_ALL_RACES") or L("SCOPE_RACE_COUNT", CountConcreteSelections(raceMap))
    local classText = classMap[0] and L("SCOPE_ALL_CLASSES") or L("SCOPE_CLASS_COUNT", CountConcreteSelections(classMap))
    local specText = specMap[0] and L("SCOPE_ALL_SPECS") or L("SCOPE_SPEC_COUNT", CountConcreteSelections(specMap))
    return string.format("%s / %s / %s", raceText, classText, specText)
end

local function GetCustomClassItems()
    local key = "customClass:noAll"
    if DropdownItemCache[key] then
        return DropdownItemCache[key]
    end
    local items = {}
    for _, item in ipairs(GetCachedClassItems() or {}) do
        if tonumber(item.value) ~= 0 then
            items[#items + 1] = item
        end
    end
    DropdownItemCache[key] = items
    return items
end

local function GetCustomSpecItems(classMap)
    classMap = NormalizeCustomClassMap(classMap, 0)
    if classMap[0] == true then
        local key = "customSpec:allNoAll"
        if DropdownItemCache[key] then
            return DropdownItemCache[key]
        end
        local items = {}
        local classValues = NS.AceOptions:GetClassValues()
        local classOptions = NS.AceOptions:GetClassOptionList()
        for _, classInfo in ipairs(classOptions or {}) do
            local classID = tonumber(classInfo.classID) or 0
            if classID > 0 then
                local specValues = NS.AceOptions:GetSpecValues(classID)
                for specID, specText in pairs(specValues or {}) do
                    specID = tonumber(specID) or 0
                    if specID > 0 then
                        items[#items + 1] = { value = specID, text = tostring(classValues[classID] or classID) .. " - " .. tostring(specText or specID) }
                    end
                end
            end
        end
        table.sort(items, function(a, b)
            return tostring(a.text or "") < tostring(b.text or "")
        end)
        DropdownItemCache[key] = items
        return items
    end

    local classKeys = {}
    for classID, enabled in pairs(classMap or {}) do
        if enabled == true and tonumber(classID) and tonumber(classID) > 0 then
            classKeys[#classKeys + 1] = tonumber(classID)
        end
    end
    table.sort(classKeys)
    local key = "customSpec:"
    for _, classID in ipairs(classKeys) do key = key .. tostring(classID) .. "," end
    if DropdownItemCache[key] then
        return DropdownItemCache[key]
    end

    local items = {}
    local classValues = NS.AceOptions:GetClassValues()
    local multiClass = #classKeys > 1
    for _, classID in ipairs(classKeys) do
        local specValues = NS.AceOptions:GetSpecValues(classID)
        for specID, specText in pairs(specValues or {}) do
            specID = tonumber(specID) or 0
            if specID > 0 then
                items[#items + 1] = {
                    value = specID,
                    text = multiClass and (tostring(classValues[classID] or classID) .. " - " .. tostring(specText or specID)) or tostring(specText or specID),
                }
            end
        end
    end
    table.sort(items, function(a, b)
        return tostring(a.text or "") < tostring(b.text or "")
    end)
    DropdownItemCache[key] = items
    return items
end

local function NormalizeAlertTab(value)
    value = tostring(value or "settings")
    if value == "settings" or value == "voice" or value == "image" or value == "text" then
        return value
    end
    return "settings"
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

local function NormalizeConditionOp(value)
    value = tostring(value or "<=")
    if value == "<" or value == "<=" or value == ">" or value == ">=" or value == "==" or value == "~=" then
        return value
    end
    if value == "=" then
        return "=="
    end
    return "<="
end

local function NormalizeCastDelayMode(value)
    -- 1.0.158: the visible Show/Hide dropdown for cast-success was removed.
    -- Cast success either executes immediately or after a delay; visual lifetime is
    -- now controlled only by the Image/Text duration checkboxes.
    return "show"
end

local function NormalizeImageSource(value)
    value = tostring(value or "auto")
    if value == "spell" or value == "item" or value == "icon" or value == "path" then
        return value
    end
    return "auto"
end

local function NormalizeTextAttachMode(value)
    value = tostring(value or "outside")
    if value == "inside" then
        return value
    end
    return "outside"
end

local function NormalizeTextVAlign(value)
    value = tostring(value or "bottom")
    if value == "top" or value == "middle" then
        return value
    end
    return "bottom"
end

local function NormalizeTextHAlign(value)
    value = tostring(value or "center")
    if value == "left" or value == "right" then
        return value
    end
    return "center"
end

local CONDITION_OPERATOR_ITEMS = {
    { value = "<=", text = "<=" },
    { value = "<", text = "<" },
    { value = "==", text = "=" },
    { value = ">=", text = ">=" },
    { value = ">", text = ">" },
    { value = "~=", text = "≠" },
}

local function GetConditionOperatorItems()
    return CONDITION_OPERATOR_ITEMS
end

local function GetConditionActionItems()
    return {
        { value = "voice", text = L("TAB_VOICE") },
        { value = "image", text = L("TAB_IMAGE") },
        { value = "text", text = L("TAB_TEXT") },
    }
end

local CUSTOM_CONDITION_LOGIC_ITEMS = {
    { value = "or", text = L("CUSTOM_CONDITION_OR") },
    { value = "and", text = L("CUSTOM_CONDITION_AND") },
}

local function NormalizeCustomConditionLogic(value)
    value = tostring(value or "or"):lower()
    if value == "and" or value == "all" then
        return "and"
    end
    return "or"
end

local function GetCustomConditionLogicItems()
    return CUSTOM_CONDITION_LOGIC_ITEMS
end

local function GetCastDelayModeItems()
    return {
        { value = "show", text = L("CAST_DELAY_MODE_SHOW") },
    }
end

local BuildCustomResultVarItems
local MAX_CUSTOM_NOTIFY_ROWS = 8
local CUSTOM_NOTIFY_ROW_HEIGHT = 30
local CUSTOM_NOTIFY_ROW_GAP = 10
local CUSTOM_NOTIFY_TOP_PAD = 82
local CUSTOM_NOTIFY_EXECUTE_GAP = 14
local CUSTOM_NOTIFY_EXECUTE_HEIGHT = 30
local CUSTOM_NOTIFY_ADD_AND_BOTTOM = 22

local function CopyActionMap(source)
    local copy = {}
    if type(source) == "table" then
        copy.voice = source.voice == true
        copy.image = source.image == true
        copy.text = source.text == true
    end
    return copy
end

local function TrimCustomText(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function IsDefaultCustomNotification(item, defaultResultVar)
    if type(item) ~= "table" then
        return true
    end
    local resultVar = TrimCustomText(item.resultVar)
    local defaultVar = TrimCustomText(defaultResultVar)
    local op = NormalizeConditionOp(item.conditionOp or "<=")
    local value = TrimCustomText(item.conditionValue)
    local defaultVarOnly = defaultVar ~= "" and resultVar == defaultVar
    return (resultVar == "" or defaultVarOnly)
        and op == "<="
        and (value == "" or value == "0")
end

local function GetCustomNotifyCountFromState(state, respectManualExpansion)
    local list = state and state.customNotifications
    local sourceCount = type(list) == "table" and #list or 0
    local requested = tonumber(state and state.customNotifyCount) or sourceCount or 1
    local count = math.max(1, math.min(MAX_CUSTOM_NOTIFY_ROWS, requested))

    -- Old 1.0.176/1.0.177 data could persist customNotifyCount = 5 because the
    -- editor used to pre-create five rows.  When opening an existing entry we
    -- collapse trailing empty default rows.  Manual expansion is tracked only by
    -- the transient _mcdCustomNotifyVisibleCount below; saved customNotifyCount
    -- is never trusted by the editor as a reason to show blank legacy cards.
    if not respectManualExpansion then
        local defaultResultVar = type(list) == "table" and type(list[1]) == "table" and list[1].resultVar or state and state.customResultVar
        while count > 1 and IsDefaultCustomNotification(type(list) == "table" and list[count] or nil, defaultResultVar) do
            count = count - 1
        end
    end

    if state then
        state.customNotifyCount = count
    end
    return count
end

local function GetCustomNotifyVisibleCount(state)
    state = type(state) == "table" and state or nil
    if not state then
        return 1
    end
    local visible = tonumber(state._mcdCustomNotifyVisibleCount)
    if visible then
        visible = math.max(1, math.min(MAX_CUSTOM_NOTIFY_ROWS, visible))
        state._mcdCustomNotifyVisibleCount = visible
        state.customNotifyCount = visible
        return visible
    end

    local count = GetCustomNotifyCountFromState(state, false)
    state._mcdCustomNotifyVisibleCount = count
    state._mcdCustomNotifyManualCount = nil
    return count
end

local function SetCustomNotifyVisibleCount(state, count)
    if type(state) ~= "table" then
        return 1
    end
    count = math.max(1, math.min(MAX_CUSTOM_NOTIFY_ROWS, tonumber(count) or 1))
    state._mcdCustomNotifyVisibleCount = count
    state.customNotifyCount = count
    return count
end

local function NormalizeCustomNotifyCount(state)
    return GetCustomNotifyVisibleCount(state)
end

local function GetCustomNotifySectionHeight(state)
    local count = NormalizeCustomNotifyCount(state)
    return CUSTOM_NOTIFY_TOP_PAD + (count * CUSTOM_NOTIFY_ROW_HEIGHT) + (math.max(0, count - 1) * CUSTOM_NOTIFY_ROW_GAP) + CUSTOM_NOTIFY_EXECUTE_GAP + CUSTOM_NOTIFY_EXECUTE_HEIGHT + CUSTOM_NOTIFY_ADD_AND_BOTTOM
end

local function NormalizeCustomNotifications(state)
    state = type(state) == "table" and state or {}
    local src = type(state.customNotifications) == "table" and state.customNotifications or nil
    local list = {}
    local count = GetCustomNotifyVisibleCount(state)
    for i = 1, count do
        local item = type(src) == "table" and type(src[i]) == "table" and src[i] or nil
        local actions = CopyActionMap(item and item.actions)
        if item == nil and i == 1 then
            actions.voice = state.voiceEnabled ~= false
            actions.image = state.imageEnabled == true
            actions.text = state.textEnabled == true
        elseif not actions.voice and not actions.image and not actions.text then
            actions.voice = true
        end
        list[i] = {
            resultVar = tostring((item and item.resultVar) or (i == 1 and state.customResultVar) or ""),
            conditionOp = NormalizeConditionOp((item and item.conditionOp) or (i == 1 and state.customConditionOp) or "<="),
            conditionValue = tostring((item and item.conditionValue) or (i == 1 and state.customConditionValue) or "0"),
            actions = actions,
        }
    end
    state.customNotifications = list
    state.customConditionLogic = NormalizeCustomConditionLogic(state.customConditionLogic)
    SetCustomNotifyVisibleCount(state, count)
    if list[1] then
        state.customResultVar = list[1].resultVar
        state.customConditionOp = list[1].conditionOp
        state.customConditionValue = list[1].conditionValue
    end
    return list, count
end

local function ReadCustomNotifyRows(widgets, state)
    local rows = widgets and widgets.customNotifyRows
    local list = {}
    local count = GetCustomNotifyVisibleCount(state)

    -- Do not collapse blank trailing rows while the editor is open.  The user may
    -- click Add first and fill the new condition afterwards; collapsing here makes
    -- the UI get stuck at condition 2 and also prevents Delete from seeing the
    -- visible row.  Save/export code still compacts truly blank trailing rows.
    count = math.max(1, math.min(MAX_CUSTOM_NOTIFY_ROWS, count))

    for i = 1, count do
        local row = rows and rows[i]
        if row and (not row.IsShown or row:IsShown()) then
            list[i] = {
                resultVar = tostring((row.varDrop and Widgets:GetDropdownValue(row.varDrop)) or ""),
                conditionOp = NormalizeConditionOp(row.opDrop and Widgets:GetDropdownValue(row.opDrop)),
                conditionValue = tostring((row.value and row.value:GetText()) or "0"),
            }
        else
            local existing = type(state.customNotifications) == "table" and type(state.customNotifications[i]) == "table" and state.customNotifications[i] or nil
            list[i] = {
                resultVar = tostring((existing and existing.resultVar) or (i == 1 and state.customResultVar) or ""),
                conditionOp = NormalizeConditionOp((existing and existing.conditionOp) or (i == 1 and state.customConditionOp) or "<="),
                conditionValue = tostring((existing and existing.conditionValue) or (i == 1 and state.customConditionValue) or "0"),
            }
        end
    end

    state.customNotifications = list
    SetCustomNotifyVisibleCount(state, count)
    state._mcdCustomNotifyManualCount = count
    if list[1] then
        state.customResultVar = list[1].resultVar
        state.customConditionOp = list[1].conditionOp
        state.customConditionValue = list[1].conditionValue
    end

    if widgets and widgets.customConditionLogicDrop and Widgets.GetDropdownValue then
        state.customConditionLogic = NormalizeCustomConditionLogic(Widgets:GetDropdownValue(widgets.customConditionLogicDrop))
    else
        state.customConditionLogic = NormalizeCustomConditionLogic(state.customConditionLogic)
    end
    if widgets and widgets.customNotifyActionsDrop and Widgets.GetMultiDropdownValues then
        local actions = Widgets:GetMultiDropdownValues(widgets.customNotifyActionsDrop) or {}
        state.voiceEnabled = actions.voice == true
        state.imageEnabled = actions.image == true
        state.textEnabled = actions.text == true
    end
    if (not state.voiceEnabled) and (not state.imageEnabled) and (not state.textEnabled) then
        state.voiceEnabled = true
    end
    return list
end

local function ApplyCustomNotifyRows(widgets, state, isShown)
    local rows = widgets and widgets.customNotifyRows
    if type(rows) ~= "table" then
        return
    end
    local notifications, count = NormalizeCustomNotifications(state)
    state.customConditionLogic = NormalizeCustomConditionLogic(state.customConditionLogic)
    if widgets.customConditionLogicDrop then
        Widgets:SetDropdownItems(widgets.customConditionLogicDrop, GetCustomConditionLogicItems())
        Widgets:SetDropdownValue(widgets.customConditionLogicDrop, state.customConditionLogic, "or")
    end
    if widgets.customConditionLogicLabel then
        widgets.customConditionLogicLabel:SetText(L("LABEL_CUSTOM_CONDITION_LOGIC"))
    end
    if widgets.customConditionLogicDrop and widgets.customConditionLogicDrop.SetShown then widgets.customConditionLogicDrop:SetShown(isShown == true) end
    if widgets.customConditionLogicLabel and widgets.customConditionLogicLabel.SetShown then widgets.customConditionLogicLabel:SetShown(isShown == true) end
    local varItems = BuildCustomResultVarItems(state.customResultVars)
    local opItems = GetConditionOperatorItems()
    for i, row in ipairs(rows) do
        local shown = isShown == true and i <= count
        if row.ClearAllPoints and row.SetPoint then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 16, -CUSTOM_NOTIFY_TOP_PAD - (i - 1) * (CUSTOM_NOTIFY_ROW_HEIGHT + CUSTOM_NOTIFY_ROW_GAP))
        end
        if row.SetShown then row:SetShown(shown) elseif shown then row:Show() else row:Hide() end
        if row.title and row.title.SetText then row.title:SetText(L("LABEL_CUSTOM_NOTIFY_N", i)) end
        if row.varDrop then
            Widgets:SetDropdownItems(row.varDrop, varItems)
            Widgets:SetDropdownValue(row.varDrop, (notifications[i] and notifications[i].resultVar) or "", L("PLACEHOLDER_SELECT_VARIABLE"))
        end
        if row.opDrop then
            Widgets:SetDropdownItems(row.opDrop, opItems)
            Widgets:SetDropdownValue(row.opDrop, (notifications[i] and notifications[i].conditionOp) or "<=", "<=")
        end
        if row.value then row.value:SetText(tostring((notifications[i] and notifications[i].conditionValue) or "0")) end
        if row.addButton then row.addButton:SetShown(shown and i == count and count < MAX_CUSTOM_NOTIFY_ROWS) end
        if row.deleteButton then row.deleteButton:SetShown(shown and i > 1) end
    end

    local executeY = -CUSTOM_NOTIFY_TOP_PAD - (count * CUSTOM_NOTIFY_ROW_HEIGHT) - (math.max(0, count - 1) * CUSTOM_NOTIFY_ROW_GAP) - CUSTOM_NOTIFY_EXECUTE_GAP
    if widgets.customNotifyExecuteRow then
        widgets.customNotifyExecuteRow:ClearAllPoints()
        widgets.customNotifyExecuteRow:SetPoint("TOPLEFT", widgets.conditionSection or widgets.customNotifyExecuteRow:GetParent(), "TOPLEFT", 16, executeY)
        widgets.customNotifyExecuteRow:SetShown(isShown == true)
    end
    if widgets.customNotifyActionsDrop and Widgets.SetMultiDropdownValues then
        Widgets:SetDropdownItems(widgets.customNotifyActionsDrop, GetConditionActionItems())
        Widgets:SetMultiDropdownValues(widgets.customNotifyActionsDrop, {
            voice = state.voiceEnabled == true,
            image = state.imageEnabled == true,
            text = state.textEnabled == true,
        }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
    end
    if widgets.customNotifyAddButton then
        widgets.customNotifyAddButton:SetShown(false)
    end
end

local function GetCustomRuntime()
    return NS.Core and NS.Core.CustomRuntime
end

local function GetCustomEventItems()
    local runtime = GetCustomRuntime()
    if runtime and type(runtime.GetEventItems) == "function" then
        return runtime:GetEventItems()
    end
    return {
        { value = "PLAYER_ENTERING_WORLD", text = "PLAYER_ENTERING_WORLD" },
        { value = "SPELL_UPDATE_COOLDOWN", text = "SPELL_UPDATE_COOLDOWN" },
        { value = "UNIT_AURA", text = "UNIT_AURA" },
    }
end

function BuildCustomResultVarItems(vars)
    local items = {}
    if type(vars) == "table" then
        for key, enabled in pairs(vars) do
            if enabled == true and type(key) == "string" and key ~= "" then
                items[#items + 1] = { value = key, text = key }
            end
        end
    end
    table.sort(items, function(a, b) return tostring(a.text or "") < tostring(b.text or "") end)
    return items
end

local function NormalizeCustomInterval(value)
    local n = tonumber(value) or 0.5
    if n < 0.2 then n = 0.2 end
    if n > 60 then n = 60 end
    return tonumber(string.format("%.2f", n)) or 0.5
end

local function GetImageSourceItems()
    return {
        { value = "auto", text = L("IMAGE_SOURCE_AUTO") },
        { value = "spell", text = L("IMAGE_SOURCE_SPELL") },
        { value = "item", text = L("IMAGE_SOURCE_ITEM") },
        { value = "icon", text = L("IMAGE_SOURCE_ICON") },
        { value = "path", text = L("IMAGE_SOURCE_PATH") },
    }
end

local function GetImageIDLabel(source)
    source = NormalizeImageSource(source)
    if source == "spell" then
        return L("LABEL_IMAGE_SPELL_ID")
    elseif source == "item" then
        return L("LABEL_IMAGE_ITEM_ID")
    end
    return L("LABEL_IMAGE_ICON_ID")
end

local function GetTextAttachItems()
    return {
        { value = "outside", text = L("TEXT_ATTACH_OUTSIDE") },
        { value = "inside", text = L("TEXT_ATTACH_INSIDE") },
    }
end

local function GetTextVAlignItems()
    return {
        { value = "top", text = L("TEXT_VALIGN_TOP") },
        { value = "middle", text = L("TEXT_VALIGN_MIDDLE") },
        { value = "bottom", text = L("TEXT_VALIGN_BOTTOM") },
    }
end

local function GetTextHAlignItems()
    return {
        { value = "left", text = L("TEXT_HALIGN_LEFT") },
        { value = "center", text = L("TEXT_HALIGN_CENTER") },
        { value = "right", text = L("TEXT_HALIGN_RIGHT") },
    }
end


local function GetNumericControlValue(control, fallback)
    if not control then
        return fallback
    end
    if control.GetValue then
        return tonumber(control:GetValue()) or fallback
    end
    if control.GetText then
        return tonumber(control:GetText() or "") or fallback
    end
    return fallback
end

local function SetNumericControlValue(control, value)
    if not control then
        return
    end
    value = math.floor((tonumber(value) or 0) + 0.5)
    if control.SetValue then
        control:SetValue(value)
        if Layout.UpdateValueSliderText then
            Layout.UpdateValueSliderText(control, value)
        end
        return
    end
    if control.SetText then
        control:SetText(tostring(value))
    end
end

local function ForceShowInlineCondition(widgets)
    if not widgets then
        return
    end
    local items = {
        widgets.conditionSection, widgets.conditionRow1, widgets.conditionRow2,
        widgets.conditionWhenLabel, widgets.conditionSpellNameText, widgets.conditionRemainingLabel,
        widgets.conditionOp, widgets.conditionTime, widgets.conditionSecLabel,
        widgets.conditionExecuteLabel, widgets.conditionActionsDrop, widgets.conditionActionHint,
    }
    SetManyShown(items, true)
    if widgets.conditionRow1 and widgets.conditionRow1.SetAlpha then widgets.conditionRow1:SetAlpha(1) end
    if widgets.conditionRow2 then
        if widgets.conditionSection and widgets.conditionRow2.ClearAllPoints and widgets.conditionRow2.SetPoint then
            widgets.conditionRow2:ClearAllPoints()
            widgets.conditionRow2:SetPoint("TOPLEFT", widgets.conditionSection, "TOPLEFT", 16, -76)
        end
        if widgets.conditionRow2.SetAlpha then widgets.conditionRow2:SetAlpha(1) end
    end
    if widgets.conditionActionsDrop then
        if widgets.conditionActionsDrop.Show then widgets.conditionActionsDrop:Show() end
        if widgets.conditionActionsDrop.SetAlpha then widgets.conditionActionsDrop:SetAlpha(1) end
        if widgets.conditionActionsDrop.EnableMouse then widgets.conditionActionsDrop:EnableMouse(true) end
    end
end

local function ForceShowCastCondition(widgets)
    if not widgets then
        return
    end
    local items = {
        widgets.conditionSection, widgets.castConditionRow1, widgets.castConditionRow2, widgets.castConditionRow3,
        widgets.castImmediateEnabled, widgets.castDelayEnabled, widgets.castDelayLabel, widgets.castDelaySeconds,
        widgets.castDelayAfterLabel, widgets.castConditionExecuteLabel, widgets.castConditionActionsDrop,
    }
    SetManyShown(items, true)
    if widgets.castDelayModeDrop and widgets.castDelayModeDrop.Hide then widgets.castDelayModeDrop:Hide() end
    for _, row in ipairs({ widgets.castConditionRow1, widgets.castConditionRow2, widgets.castConditionRow3 }) do
        if row and row.SetAlpha then row:SetAlpha(1) end
    end
    if widgets.castConditionActionsDrop then
        if widgets.castConditionActionsDrop.Show then widgets.castConditionActionsDrop:Show() end
        if widgets.castConditionActionsDrop.SetAlpha then widgets.castConditionActionsDrop:SetAlpha(1) end
        if widgets.castConditionActionsDrop.EnableMouse then widgets.castConditionActionsDrop:EnableMouse(true) end
    end
end

local function ForceShowCustomCondition(widgets)
    if not widgets then
        return
    end
    SetManyShown({ widgets.conditionSection }, true)
    SetManyShown({
        widgets.conditionRow1, widgets.conditionRow2, widgets.conditionWhenLabel, widgets.conditionSpellNameText,
        widgets.conditionRemainingLabel, widgets.conditionOp, widgets.conditionTime, widgets.conditionSecLabel,
        widgets.conditionExecuteLabel, widgets.conditionActionsDrop, widgets.conditionActionHint,
        widgets.customConditionVarLabel, widgets.customConditionVarDrop, widgets.customConditionValueLabel, widgets.customConditionValue,
    }, false)
    if type(widgets.customNotifyRows) == "table" then
        for _, row in ipairs(widgets.customNotifyRows) do
            if row and row.SetAlpha then row:SetAlpha(1) end
        end
    end
end

local function Trim(value)
    if NS.AceOptions and NS.AceOptions.TrimText then
        return NS.AceOptions.TrimText(value or "")
    end
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function SetControlsEnabled(items, enabled)
    for _, item in ipairs(items or {}) do
        SetEnabled(item, enabled == true)
    end
end

local function SetLabelsEnabled(items, enabled)
    for _, item in ipairs(items or {}) do
        SetNativeLabelColor(item, enabled == true)
    end
end


local function ResolveSpellIcon(spellId)
    spellId = tonumber(spellId) or 0
    if spellId <= 0 then return nil end
    local api = NS.API or {}
    if type(api.ResolveSpellIcon) == "function" then
        local ok, icon = pcall(api.ResolveSpellIcon, spellId)
        if ok and icon then return icon end
    end
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellId)
        if ok and icon then return icon end
    end
    if type(GetSpellTexture) == "function" then
        local ok, icon = pcall(GetSpellTexture, spellId)
        if ok and icon then return icon end
    end
    return nil
end

local function ResolveItemIcon(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return nil end
    local api = NS.API or {}
    if type(api.ResolveItemIcon) == "function" then
        local ok, icon = pcall(api.ResolveItemIcon, itemID)
        if ok and icon then return icon end
    end
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then return icon end
    end
    if type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then return icon end
    end
    return nil
end

local function ResolveImagePreviewTexture(state)
    state = state or {}
    local source = NormalizeImageSource(state.imageSource)
    local value = tonumber(state.imageIconID) or 0
    if source == "spell" then
        return ResolveSpellIcon(value)
    elseif source == "item" then
        return ResolveItemIcon(value)
    elseif source == "icon" then
        return value > 0 and math.floor(value) or nil
    elseif source == "path" then
        local path = Trim(state.imagePath or "")
        return path ~= "" and (tonumber(path) or path) or nil
    end
    local objectID = state.spellId or state.objectID or state.triggerSpellID
    if tostring(state.objectType or "") == OBJECT_TYPE_ITEM then
        return ResolveItemIcon(objectID)
            or (value > 0 and math.floor(value) or nil)
            or nil
    end
    return ResolveSpellIcon(objectID)
        or (value > 0 and math.floor(value) or nil)
        or nil
end

function Fields:UpdateImageIconPreview(editor)
    local frame = editor and editor.frame
    local widgets = frame and frame.widgets
    if not widgets or not widgets.imageIconPreview or not widgets.imageIconPreviewTexture then
        return
    end
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    if tostring(state.activeAlertTab or "") ~= "image" or state.imageEnabled ~= true then
        widgets.imageIconPreviewTexture:SetTexture(nil)
        widgets.imageIconPreview:Hide()
        return
    end
    local texture = ResolveImagePreviewTexture(state)
    if texture then
        widgets.imageIconPreviewTexture:SetTexture(texture)
        widgets.imageIconPreview:Show()
    else
        widgets.imageIconPreviewTexture:SetTexture(nil)
        widgets.imageIconPreview:Hide()
    end
end

function Fields:ClearDropdownItemCache()
    ClearDropdownItemCache()
    if SoundFields and type(SoundFields.ClearDropdownItemCache) == "function" then
        SoundFields:ClearDropdownItemCache()
    end
end

function Fields:PullFromWidgets(editor)
    if not editor.frame or not editor.frame:IsShown() then
        return
    end

    local widgets = editor.frame.widgets
    local state = NS.AceOptions:GetState()
    local modeTts, modeSound = NS.API.GetModes()
    local isBloodlust = tostring(state.entryType or "") == "bloodlust"
    local isCooldownEntry = tostring(state.entryType or "cooldown") == "cooldown"
    local isCastEntry = tostring(state.entryType or "") == "cast"
    local isCustomEntry = tostring(state.entryType or "") == "custom"

    state.activeAlertTab = NormalizeAlertTab(state.activeAlertTab)
    if isCooldownEntry and widgets.conditionActionsDrop and Widgets.GetMultiDropdownValues then
        local selectedActions = Widgets:GetMultiDropdownValues(widgets.conditionActionsDrop)
        if state.activeAlertTab == "voice" and widgets.voiceEnabled then
            selectedActions.voice = widgets.voiceEnabled:GetChecked() == true
        elseif state.activeAlertTab == "image" and widgets.imageEnabled then
            selectedActions.image = widgets.imageEnabled:GetChecked() == true
        elseif state.activeAlertTab == "text" and widgets.textEnabled then
            selectedActions.text = widgets.textEnabled:GetChecked() == true
        end
        state.voiceEnabled = selectedActions.voice == true
        state.imageEnabled = selectedActions.image == true
        state.textEnabled = selectedActions.text == true
        if widgets.voiceEnabled then widgets.voiceEnabled:SetChecked(state.voiceEnabled == true) end
        if widgets.imageEnabled then widgets.imageEnabled:SetChecked(state.imageEnabled == true) end
        if widgets.textEnabled then widgets.textEnabled:SetChecked(state.textEnabled == true) end
        if Widgets.SetMultiDropdownValues then
            Widgets:SetMultiDropdownValues(widgets.conditionActionsDrop, {
                voice = state.voiceEnabled == true,
                image = state.imageEnabled == true,
                text = state.textEnabled == true,
            }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
        end
        local conditionOp = NormalizeConditionOp(Widgets:GetDropdownValue(widgets.conditionOp or widgets.voiceConditionOp))
        local conditionTime = math.max(0, tonumber(((widgets.conditionTime or widgets.voiceConditionTime) and (widgets.conditionTime or widgets.voiceConditionTime):GetText()) or "") or 0)
        state.voiceConditionOp = conditionOp
        state.voiceConditionTime = conditionTime
        state.imageConditionOp = conditionOp
        state.imageConditionTime = conditionTime
        state.textConditionOp = conditionOp
        state.textConditionTime = conditionTime
        state.cooldownAlertTime = conditionTime
    elseif isCastEntry and widgets.castConditionActionsDrop and Widgets.GetMultiDropdownValues then
        local selectedActions = Widgets:GetMultiDropdownValues(widgets.castConditionActionsDrop)
        if state.activeAlertTab == "voice" and widgets.voiceEnabled then
            selectedActions.voice = widgets.voiceEnabled:GetChecked() == true
        elseif state.activeAlertTab == "image" and widgets.imageEnabled then
            selectedActions.image = widgets.imageEnabled:GetChecked() == true
        elseif state.activeAlertTab == "text" and widgets.textEnabled then
            selectedActions.text = widgets.textEnabled:GetChecked() == true
        end
        state.voiceEnabled = selectedActions.voice == true
        state.imageEnabled = selectedActions.image == true
        state.textEnabled = selectedActions.text == true
        if widgets.voiceEnabled then widgets.voiceEnabled:SetChecked(state.voiceEnabled == true) end
        if widgets.imageEnabled then widgets.imageEnabled:SetChecked(state.imageEnabled == true) end
        if widgets.textEnabled then widgets.textEnabled:SetChecked(state.textEnabled == true) end
        if Widgets.SetMultiDropdownValues then
            Widgets:SetMultiDropdownValues(widgets.castConditionActionsDrop, {
                voice = state.voiceEnabled == true,
                image = state.imageEnabled == true,
                text = state.textEnabled == true,
            }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
        end
        local delayChecked = widgets.castDelayEnabled and widgets.castDelayEnabled:GetChecked() == true or false
        local immediateChecked = widgets.castImmediateEnabled and widgets.castImmediateEnabled:GetChecked() == true or false
        state.delayEnabled = delayChecked and (not immediateChecked or delayChecked == true) or false
        state.delaySeconds = math.max(0, tonumber((widgets.castDelaySeconds and widgets.castDelaySeconds:GetText()) or "") or 0)
        state.castDelayMode = "show"
        if widgets.castImmediateEnabled then widgets.castImmediateEnabled:SetChecked(state.delayEnabled ~= true) end
        if widgets.castDelayEnabled then widgets.castDelayEnabled:SetChecked(state.delayEnabled == true) end
        state.voiceConditionOp = "<="
        state.voiceConditionTime = 0
        state.imageConditionOp = "<="
        state.imageConditionTime = 0
        state.textConditionOp = "<="
        state.textConditionTime = 0
        state.cooldownAlertTime = 0
    elseif isCustomEntry then
        ReadCustomNotifyRows(widgets, state)
        if widgets.voiceEnabled then widgets.voiceEnabled:SetChecked(state.voiceEnabled == true) end
        if widgets.imageEnabled then widgets.imageEnabled:SetChecked(state.imageEnabled == true) end
        if widgets.textEnabled then widgets.textEnabled:SetChecked(state.textEnabled == true) end
        state.voiceConditionOp = "<="
        state.voiceConditionTime = 0
        state.imageConditionOp = "<="
        state.imageConditionTime = 0
        state.textConditionOp = "<="
        state.textConditionTime = 0
        state.cooldownAlertTime = 0
    else
        state.voiceEnabled = (not widgets.voiceEnabled) or widgets.voiceEnabled:GetChecked() == true
        state.voiceConditionOp = NormalizeConditionOp(Widgets:GetDropdownValue(widgets.voiceConditionOp))
        state.voiceConditionTime = math.max(0, tonumber((widgets.voiceConditionTime and widgets.voiceConditionTime:GetText()) or "") or 0)
        state.imageEnabled = widgets.imageEnabled and widgets.imageEnabled:GetChecked() == true or false
        state.imageConditionOp = NormalizeConditionOp(Widgets:GetDropdownValue(widgets.imageConditionOp))
        state.imageConditionTime = math.max(0, tonumber((widgets.imageConditionTime and widgets.imageConditionTime:GetText()) or "") or 0)
    end
    state.imageSource = NormalizeImageSource(Widgets:GetDropdownValue(widgets.imageSourceDrop) or state.imageSource)
    state.imageIconID = math.max(0, tonumber((widgets.imageIconID and widgets.imageIconID:GetText()) or "") or 0)
    state.imagePath = Trim((widgets.imagePath and widgets.imagePath:GetText()) or "")
    state.imageSize = math.max(16, GetNumericControlValue(widgets.imageSize, 96))
    state.imageDurationEnabled = widgets.imageDurationEnabled and widgets.imageDurationEnabled:GetChecked() == true or false
    state.imageDuration = math.max(0.1, tonumber((widgets.imageDuration and widgets.imageDuration:GetText()) or "") or 2)
    state.imageX = math.floor((tonumber((widgets.imageX and widgets.imageX:GetText()) or "") or 0) + 0.5)
    state.imageY = math.floor((tonumber((widgets.imageY and widgets.imageY:GetText()) or "") or 120) + 0.5)
    if not ((isCooldownEntry and widgets.conditionActionsDrop and Widgets.GetMultiDropdownValues) or (isCastEntry and widgets.castConditionActionsDrop and Widgets.GetMultiDropdownValues) or isCustomEntry) then
        state.textEnabled = widgets.textEnabled and widgets.textEnabled:GetChecked() == true or false
        state.textConditionOp = NormalizeConditionOp(Widgets:GetDropdownValue(widgets.textConditionOp))
        state.textConditionTime = math.max(0, tonumber((widgets.textConditionTime and widgets.textConditionTime:GetText()) or "") or 0)
    end
    state.textAlert = tostring((widgets.textAlert and widgets.textAlert:GetText()) or "")
    state.textSize = math.max(8, GetNumericControlValue(widgets.textSize, 24))
    state.textDurationEnabled = widgets.textDurationEnabled and widgets.textDurationEnabled:GetChecked() == true or false
    state.textDuration = math.max(0.1, tonumber((widgets.textDuration and widgets.textDuration:GetText()) or "") or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(state)
    end
    state.textX = math.floor((tonumber((widgets.textX and widgets.textX:GetText()) or "") or 0) + 0.5)
    state.textY = math.floor((tonumber((widgets.textY and widgets.textY:GetText()) or "") or 120) + 0.5)
    state.textAttachMode = NormalizeTextAttachMode(Widgets:GetDropdownValue(widgets.textAttachDrop) or state.textAttachMode)
    state.textVAlign = NormalizeTextVAlign(Widgets:GetDropdownValue(widgets.textVAlignDrop) or state.textVAlign)
    state.textHAlign = NormalizeTextHAlign(Widgets:GetDropdownValue(widgets.textHAlignDrop) or state.textHAlign)
    state.textOffsetX = math.floor((tonumber((widgets.textOffsetX and widgets.textOffsetX:GetText()) or "") or 0) + 0.5)
    state.textOffsetY = math.floor((tonumber((widgets.textOffsetY and widgets.textOffsetY:GetText()) or "") or 0) + 0.5)

    if not isBloodlust then
        state.alertRaceIDs = NormalizeCustomRaceMap(state.alertRaceIDs or state.customRaceIDs)
        if widgets.scopeButton then
            state.alertClassIDs = NormalizeCustomClassMap(state.alertClassIDs or state.customClassIDs, state.classID)
        elseif widgets.customClassDrop and Widgets.GetMultiDropdownValues then
            state.alertClassIDs = NormalizeCustomClassMap(Widgets:GetMultiDropdownValues(widgets.customClassDrop), state.classID)
        else
            state.alertClassIDs = NormalizeCustomClassMap(state.alertClassIDs or state.customClassIDs, state.classID)
        end
        if widgets.scopeButton then
            state.alertSpecIDs = NormalizeCustomSpecMap(state.alertSpecIDs or state.customSpecIDs, state.specID)
        elseif widgets.customSpecDrop and Widgets.GetMultiDropdownValues then
            state.alertSpecIDs = NormalizeCustomSpecMap(Widgets:GetMultiDropdownValues(widgets.customSpecDrop), state.specID)
        else
            state.alertSpecIDs = NormalizeCustomSpecMap(state.alertSpecIDs or state.customSpecIDs, state.specID)
        end
        state.customRaceIDs = state.alertRaceIDs
        state.customClassIDs = state.alertClassIDs
        state.customSpecIDs = state.alertSpecIDs
        state.classID = 0
        state.specID = 0

        if isCustomEntry then
            state.customName = tostring((widgets.customName and widgets.customName:GetText()) or state.customName or "")
            state.spellName = state.customName
            state.spellId = 0
            state.objectType = OBJECT_TYPE_SPELL
            state.itemLoadMode = ITEM_LOAD_NONE
            state.itemLoadSameName = false
            state.baseCD = 0
            state.fixedCD = true
            state.checkTalent = false
            state.talentId = 0
            state.talentName = ""
            state.talentCD = 0
            state.delayEnabled = false
            state.delaySeconds = 0
            state.castDelayMode = "show"
            state.customUseEvents = widgets.customEventEnabled and widgets.customEventEnabled:GetChecked() == true or false
            if widgets.customEventsDrop and Widgets.GetMultiDropdownValues then
                state.customEvents = Widgets:GetMultiDropdownValues(widgets.customEventsDrop)
            end
            state.customEventText = tostring((widgets.customEventText and widgets.customEventText:GetText()) or state.customEventText or "")
            state.customUseTicker = widgets.customTickerEnabled and widgets.customTickerEnabled:GetChecked() == true or false
            state.customInterval = NormalizeCustomInterval((widgets.customInterval and widgets.customInterval:GetText()) or state.customInterval)
            state.customCode = tostring((widgets.customCode and widgets.customCode:GetText()) or state.customCode or "")
        else
            state.objectType = (widgets.objectTypeItem and widgets.objectTypeItem:GetChecked() == true) and OBJECT_TYPE_ITEM or OBJECT_TYPE_SPELL
            if state.objectType == OBJECT_TYPE_ITEM then
                local itemLoadEquippedChecked = widgets.itemLoadEquipped and widgets.itemLoadEquipped:GetChecked() == true
                local itemLoadBagsChecked = widgets.itemLoadBags and widgets.itemLoadBags:GetChecked() == true
                if itemLoadEquippedChecked then
                    state.itemLoadMode = ITEM_LOAD_EQUIPPED
                    state.itemLoadSameName = false
                elseif itemLoadBagsChecked then
                    state.itemLoadMode = ITEM_LOAD_BAGS
                    state.itemLoadSameName = widgets.itemLoadSameName and widgets.itemLoadSameName:GetChecked() == true or false
                else
                    state.itemLoadMode = ITEM_LOAD_NONE
                    state.itemLoadSameName = false
                end
            else
                state.itemLoadMode = ITEM_LOAD_NONE
                state.itemLoadSameName = false
            end
            state.spellId = tonumber(widgets.spellId:GetText() or "") or 0
            state.spellName = tostring(widgets.spellName:GetText() or "")
            state.baseCD = tonumber(widgets.baseCD:GetText() or "") or 0
            state.fixedCD = true
            state.checkTalent = (state.objectType ~= OBJECT_TYPE_ITEM) and widgets.checkTalent and widgets.checkTalent:GetChecked() == true or false
            state.talentId = tonumber((widgets.talentId and widgets.talentId:GetText()) or "") or 0
            state.talentName = tostring((widgets.talentName and widgets.talentName:GetText()) or "")
            state.talentCD = tonumber((widgets.talentCD and widgets.talentCD:GetText()) or "") or 0
            if isCastEntry then
                local delayChecked = widgets.castDelayEnabled and widgets.castDelayEnabled:GetChecked() == true or false
                state.delayEnabled = delayChecked == true
                state.delaySeconds = math.max(0, tonumber((widgets.castDelaySeconds and widgets.castDelaySeconds:GetText()) or "") or 0)
                state.castDelayMode = "show"
                if widgets.castImmediateEnabled then widgets.castImmediateEnabled:SetChecked(state.delayEnabled ~= true) end
                if widgets.castDelayEnabled then widgets.castDelayEnabled:SetChecked(state.delayEnabled == true) end
            else
                state.delayEnabled = false
                state.delaySeconds = 0
                state.castDelayMode = "show"
            end
        end
    end

    if SoundFields and type(SoundFields.PullFromWidgets) == "function" then
        SoundFields:PullFromWidgets(widgets, state, modeTts, modeSound)
    end
end

function Fields:PushToWidgets(editor)
    local frame = editor:EnsureFrame()
    local widgets = frame.widgets
    local state = NS.AceOptions:GetState()
    local modeTts, modeSound = NS.API.GetModes()
    local soundFields, source, isTts = nil, tostring(state.soundSource or "builtin"), false
    if SoundFields and type(SoundFields.ResolveState) == "function" then
        soundFields, source, isTts = SoundFields:ResolveState(state, modeTts, modeSound)
    else
        soundFields = NS.AceOptions:ResolveSoundSourceFields(state, modeTts, modeSound)
        source = tostring(soundFields.soundSource or state.soundSource or "builtin")
        isTts = source == "tts" or tostring(state.notifyMode or "") == tostring(modeTts)
    end

    state.activeAlertTab = NormalizeAlertTab(state.activeAlertTab)
    state.delayEnabled = state.delayEnabled == true
    state.delaySeconds = math.max(0, tonumber(state.delaySeconds) or 0)
    state.castDelayMode = NormalizeCastDelayMode(state.castDelayMode)
    state.voiceEnabled = state.voiceEnabled ~= false
    local legacyAlertTime = math.max(0, tonumber(state.cooldownAlertTime or state.alertLeadTime) or 0)
    local unifiedConditionOp = NormalizeConditionOp(state.voiceConditionOp or state.imageConditionOp or state.textConditionOp)
    local unifiedConditionTime = math.max(0, tonumber(state.voiceConditionTime) or tonumber(state.imageConditionTime) or tonumber(state.textConditionTime) or legacyAlertTime)
    state.voiceConditionOp = unifiedConditionOp
    state.voiceConditionTime = unifiedConditionTime
    state.cooldownAlertTime = unifiedConditionTime
    state.imageEnabled = state.imageEnabled == true
    state.imageConditionOp = unifiedConditionOp
    state.imageConditionTime = unifiedConditionTime
    state.textEnabled = state.textEnabled == true
    state.textConditionOp = unifiedConditionOp
    state.textConditionTime = unifiedConditionTime
    state.imageSource = NormalizeImageSource(state.imageSource)
    state.imageIconID = math.max(0, tonumber(state.imageIconID) or 0)
    state.imageSize = math.max(16, tonumber(state.imageSize) or 96)
    state.imageDurationEnabled = state.imageDurationEnabled == true
    state.imageDuration = math.max(0.1, tonumber(state.imageDuration) or 2)
    state.imageX = math.floor((tonumber(state.imageX) or 0) + 0.5)
    state.imageY = math.floor((tonumber(state.imageY) or 120) + 0.5)
    state.textSize = math.max(8, tonumber(state.textSize) or 24)
    state.textDurationEnabled = state.textDurationEnabled == true
    state.textDuration = math.max(0.1, tonumber(state.textDuration) or 2)
    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(state)
    end
    state.textX = math.floor((tonumber(state.textX) or 0) + 0.5)
    state.textY = math.floor((tonumber(state.textY) or 120) + 0.5)
    state.textAttachMode = NormalizeTextAttachMode(state.textAttachMode)
    state.textVAlign = NormalizeTextVAlign(state.textVAlign)
    state.textHAlign = NormalizeTextHAlign(state.textHAlign)
    state.textOffsetX = math.floor((tonumber(state.textOffsetX) or 0) + 0.5)
    state.textOffsetY = math.floor((tonumber(state.textOffsetY) or 0) + 0.5)

    if NS.UI and NS.UI.VisualPositionPreview and type(NS.UI.VisualPositionPreview.ApplyEditorDefaultPositions) == "function" then
        NS.UI.VisualPositionPreview:ApplyEditorDefaultPositions(editor, state)
    end
    state.imageX = math.floor((tonumber(state.imageX) or 0) + 0.5)
    state.imageY = math.floor((tonumber(state.imageY) or 120) + 0.5)
    state.textX = math.floor((tonumber(state.textX) or 0) + 0.5)
    state.textY = math.floor((tonumber(state.textY) or 120) + 0.5)

    local isCooldown = tostring(state.entryType or "cooldown") == "cooldown"
    local isBloodlust = tostring(state.entryType or "") == "bloodlust"
    local isCast = tostring(state.entryType or "") == "cast"
    local isCustom = tostring(state.entryType or "") == "custom"
    local activeTab = state.activeAlertTab
    local showSettings = activeTab == "settings"
    local showVoice = activeTab == "voice"
    local showImage = activeTab == "image"
    local showText = activeTab == "text"

    local typeTitle = isBloodlust and L("TAB_BLOODLUST") or (isCustom and L("TAB_CUSTOM") or (isCast and L("TAB_CAST") or L("TAB_COOLDOWN")))
    frame.title:SetText((editor.mode == "new" and L("TITLE_NEW_CONFIG") or L("TITLE_EDIT_CONFIG")) .. " - " .. typeTitle)

    SetManyShown({ widgets.classSection }, showSettings and not isBloodlust)
    SetManyShown({ widgets.spellSection }, showSettings and not isBloodlust and not isCustom)
    SetManyShown({ widgets.customSection, widgets.customCodeSection }, showSettings and isCustom)
    SetManyShown({ widgets.conditionSection }, showSettings and (isCooldown or isCast or isCustom))
    SetManyShown({ widgets.bloodlustInfoSection }, showSettings and isBloodlust)
    SetManyShown({ widgets.notifySection }, not showSettings)
    if showSettings then
        if widgets.classSection then widgets.classSection:SetShown(not isBloodlust) end
        if widgets.spellSection then widgets.spellSection:SetShown((not isBloodlust) and (not isCustom)) end
        if widgets.customSection then widgets.customSection:SetShown(isCustom) end
        if widgets.customCodeSection then widgets.customCodeSection:SetShown(isCustom) end
        if widgets.conditionSection then widgets.conditionSection:SetShown(isCooldown or isCast or isCustom) end
        if widgets.bloodlustInfoSection then widgets.bloodlustInfoSection:SetShown(isBloodlust) end
    end
    if widgets.conditionSection then
        widgets.conditionSection:ClearAllPoints()
        widgets.conditionSection:SetPoint("TOPLEFT", widgets.conditionSection:GetParent(), "TOPLEFT", (PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Modules.left) or 8, isCustom and (widgets.customConditionTop or -660) or (widgets.normalConditionTop or -382))
        if widgets.conditionSection.SetHeight then
            local conditionHeight = isCustom and GetCustomNotifySectionHeight(state) or ((PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Modules.conditionHeight) or 150)
            widgets.conditionSection:SetHeight(conditionHeight)
        end
        local title = isCustom and L("SECTION_CUSTOM_EXECUTE_NOTIFY") or L("SECTION_NOTIFY_CONDITIONS")
        local label = widgets.conditionSection.qfxsaLabel or widgets.conditionSection.label
        if label and label.SetText then label:SetText(title) end
    end

    if widgets.notifySection then
        widgets.notifySection:ClearAllPoints()
        widgets.notifySection:SetPoint("TOPLEFT", widgets.notifySection:GetParent(), "TOPLEFT", (PopupLayout and PopupLayout.Editor and PopupLayout.Editor.Modules.left) or 8, isBloodlust and (widgets.bloodlustNotifyTop or -8) or (widgets.normalNotifyTop or -8))
        if widgets.notifySection.SetHeight then
            local customBloodlustVoice = isBloodlust and showVoice and tostring(source or state.soundSource or "") == "custom"
            widgets.notifySection:SetHeight(customBloodlustVoice and (widgets.bloodlustCustomSoundNotifyHeight or 610) or (widgets.notifySectionHeight or 420))
        end
    end
    local imageEnabledForLayout = state.imageEnabled == true
    local textEnabledForLayout = state.textEnabled == true
    local linkedVisualLayout = showText and textEnabledForLayout and imageEnabledForLayout
    local textOnlyPositionLayout = showText and textEnabledForLayout and (not imageEnabledForLayout)
    local imagePositionLayout = showImage and imageEnabledForLayout
    if frame.contentHost and frame.contentHost.SetContentHeight then
        local contentHeight = widgets.normalNotifyContentHeight or 540
        if showSettings then
            if isBloodlust then
                contentHeight = 180
            elseif isCooldown then
                contentHeight = widgets.normalSettingsContentHeight or 650
            elseif isCast then
                contentHeight = widgets.castSettingsContentHeight or widgets.normalSettingsContentHeight or 650
            elseif isCustom then
                contentHeight = math.max(widgets.customSettingsContentHeight or 760, math.abs(tonumber(widgets.customConditionTop) or 742) + GetCustomNotifySectionHeight(state) + 72)
            else
                contentHeight = 420
            end
        elseif isBloodlust then
            if showVoice and tostring(source or state.soundSource or "") == "custom" then
                contentHeight = widgets.bloodlustCustomSoundContentHeight or widgets.bloodlustContentHeight or 520
            else
                contentHeight = widgets.bloodlustContentHeight or 520
            end
        elseif linkedVisualLayout then
            contentHeight = widgets.linkedVisualContentHeight or 820
        elseif textOnlyPositionLayout then
            contentHeight = widgets.textOnlyVisualContentHeight or 820
        elseif imagePositionLayout then
            contentHeight = widgets.imagePositionContentHeight or widgets.normalNotifyContentHeight or 540
        end
        local tabChanged = frame.qfxsaLastActiveAlertTab ~= activeTab
        frame.qfxsaLastActiveAlertTab = activeTab
        frame.contentHost:SetContentHeight(contentHeight)
        if tabChanged and frame.contentHost.slider then
            frame.contentHost.slider:SetValue(0)
            if frame.contentHost.scrollFrame then
                frame.contentHost.scrollFrame:SetVerticalScroll(0)
            end
        end
        if frame.contentHost.UpdateScrollRange then
            frame.contentHost:UpdateScrollRange()
        end
    end

    if not isBloodlust then
        if widgets.classDrop then widgets.classDrop:SetShown(false) end
        if widgets.specDrop then widgets.specDrop:SetShown(false) end
        if widgets.classLabel then widgets.classLabel:SetShown(false) end
        if widgets.specLabel then widgets.specLabel:SetShown(false) end
        if widgets.customClassDrop then widgets.customClassDrop:SetShown(false) end
        if widgets.customSpecDrop then widgets.customSpecDrop:SetShown(false) end
        if widgets.scopeLabel then widgets.scopeLabel:SetShown(true) end
        if widgets.scopeButton then widgets.scopeButton:SetShown(true) end
        if widgets.scopeSummary then widgets.scopeSummary:SetShown(true) end

        state.alertRaceIDs = NormalizeCustomRaceMap(state.alertRaceIDs or state.customRaceIDs)
        state.alertClassIDs = NormalizeCustomClassMap(state.alertClassIDs or state.customClassIDs, state.classID)
        state.alertSpecIDs = NormalizeCustomSpecMap(state.alertSpecIDs or state.customSpecIDs, state.specID)
        state.customRaceIDs = state.alertRaceIDs
        state.customClassIDs = state.alertClassIDs
        state.customSpecIDs = state.alertSpecIDs
        if widgets.customClassDrop and Widgets.SetMultiDropdownValues then
            Widgets:SetDropdownItems(widgets.customClassDrop, GetCustomClassItems())
            Widgets:SetMultiDropdownValues(widgets.customClassDrop, state.alertClassIDs, L("PLACEHOLDER_SELECT_CLASSES"))
        end
        if widgets.customSpecDrop and Widgets.SetMultiDropdownValues then
            Widgets:SetDropdownItems(widgets.customSpecDrop, GetCustomSpecItems(state.alertClassIDs))
            Widgets:SetMultiDropdownValues(widgets.customSpecDrop, state.alertSpecIDs, L("PLACEHOLDER_SELECT_SPECS"))
        end
        if widgets.scopeSummary then
            widgets.scopeSummary:SetText(BuildScopeSummary(state))
        end
        if widgets.scopeButton then
            widgets.scopeButton:SetText(L("BTN_SCOPE_SELECT"))
        end
        if widgets.specLabel then SetNativeLabelColor(widgets.specLabel, true) end

        if isCustom then
            state.customName = tostring(state.customName or state.spellName or "")
            state.customUseEvents = state.customUseEvents ~= false
            if type(state.customEvents) ~= "table" then state.customEvents = { PLAYER_ENTERING_WORLD = true } end
            state.customUseTicker = state.customUseTicker == true
            state.customInterval = NormalizeCustomInterval(state.customInterval)
            state.customEventText = tostring(state.customEventText or "")
            state.customCode = tostring(state.customCode or "")
            state.customResultVar = tostring(state.customResultVar or "")
            state.customConditionOp = NormalizeConditionOp(state.customConditionOp)
            state.customConditionValue = tostring(state.customConditionValue or "0")
            state.customConditionLogic = NormalizeCustomConditionLogic(state.customConditionLogic)
            if type(state.customResultVars) ~= "table" then state.customResultVars = {} end
            NormalizeCustomNotifications(state)
            if widgets.customName then widgets.customName:SetText(state.customName) end
            if widgets.customEventEnabled then widgets.customEventEnabled:SetChecked(state.customUseEvents == true) end
            if widgets.customEventsDrop and Widgets.SetMultiDropdownValues then
                Widgets:SetDropdownItems(widgets.customEventsDrop, GetCustomEventItems())
                Widgets:SetMultiDropdownValues(widgets.customEventsDrop, state.customEvents, L("PLACEHOLDER_SELECT_EVENTS"))
            end
            if widgets.customEventText then widgets.customEventText:SetText(state.customEventText or "") end
            if widgets.customTickerEnabled then widgets.customTickerEnabled:SetChecked(state.customUseTicker == true) end
            if widgets.customInterval then widgets.customInterval:SetText(tostring(state.customInterval or 0.5)) end
            if widgets.customCode then widgets.customCode:SetText(state.customCode) end
            Widgets:SetDropdownEnabled(widgets.customEventsDrop, state.customUseEvents == true)
            SetEnabled(widgets.customEventText, state.customUseEvents == true)
            SetLabelsEnabled({ widgets.customEventTextLabel }, state.customUseEvents == true)
            SetEnabled(widgets.customInterval, state.customUseTicker == true)
            SetLabelsEnabled({ widgets.customIntervalSecLabel }, state.customUseTicker == true)
            SetManyShown({ widgets.itemLoadEquipped, widgets.itemLoadBags, widgets.itemLoadSameName }, false)
        else
            state.objectType = tostring(state.objectType or OBJECT_TYPE_SPELL)
            if state.objectType ~= OBJECT_TYPE_ITEM then state.objectType = OBJECT_TYPE_SPELL end
            local isItemObject = state.objectType == OBJECT_TYPE_ITEM
            if isItemObject then state.checkTalent = false end
            if widgets.objectTypeItem then widgets.objectTypeItem:SetChecked(isItemObject) end
            if widgets.spellIdLabel then widgets.spellIdLabel:SetText(isItemObject and L("LABEL_ITEM_ID") or L("LABEL_OBJECT_SPELL_ID")) end
            state.itemLoadMode = isItemObject and NormalizeItemLoadMode(state.itemLoadMode) or ITEM_LOAD_NONE
            state.itemLoadSameName = isItemObject and state.itemLoadMode == ITEM_LOAD_BAGS and state.itemLoadSameName == true
            if widgets.itemLoadEquipped then widgets.itemLoadEquipped:SetChecked(isItemObject and state.itemLoadMode == ITEM_LOAD_EQUIPPED) end
            if widgets.itemLoadBags then widgets.itemLoadBags:SetChecked(isItemObject and state.itemLoadMode == ITEM_LOAD_BAGS) end
            if widgets.itemLoadSameName then widgets.itemLoadSameName:SetChecked(state.itemLoadSameName == true) end
            SetManyShown({ widgets.itemLoadEquipped, widgets.itemLoadBags, widgets.itemLoadSameName }, isItemObject)
            SetEnabled(widgets.itemLoadSameName, isItemObject and state.itemLoadMode == ITEM_LOAD_BAGS)
            widgets.spellId:SetText((tonumber(state.spellId) or 0) > 0 and tostring(state.spellId) or "")
            widgets.spellName:SetText(tostring(state.spellName or ""))
            widgets.checkTalent:SetChecked((not isItemObject) and state.checkTalent == true)
            widgets.talentId:SetText((tonumber(state.talentId) or 0) > 0 and tostring(state.talentId) or "")
            widgets.talentName:SetText(tostring(state.talentName or ""))
            widgets.talentCD:SetText((tonumber(state.talentCD) or 0) > 0 and tostring(state.talentCD) or "")
            if widgets.delayEnabled then widgets.delayEnabled:SetChecked(false) end
            if widgets.delaySeconds then widgets.delaySeconds:SetText("") end
            if widgets.castImmediateEnabled then widgets.castImmediateEnabled:SetChecked(isCast and state.delayEnabled ~= true) end
            if widgets.castDelayEnabled then widgets.castDelayEnabled:SetChecked(isCast and state.delayEnabled == true) end
            if widgets.castDelaySeconds then widgets.castDelaySeconds:SetText((isCast and (tonumber(state.delaySeconds) or 0) > 0) and tostring(state.delaySeconds) or "") end
            widgets.baseCD:SetText((tonumber(state.baseCD) or 0) > 0 and tostring(state.baseCD) or "")
            state.fixedCD = true

            local talentControlsVisible = isCooldown and (not isItemObject)
            SetManyShown({ widgets.talentIdLabel, widgets.talentNameLabel, widgets.talentCDLabel, widgets.checkTalent, widgets.talentId, widgets.talentName, widgets.talentCD }, talentControlsVisible)
            SetManyShown({ widgets.baseCDLabel, widgets.baseCD }, isCooldown)
            SetManyShown({ widgets.delayEnabled, widgets.delaySecondsLabel, widgets.delaySeconds }, false)

            local talentEnabled = talentControlsVisible and (state.checkTalent == true)
            SetEnabled(widgets.checkTalent, talentControlsVisible)
            SetEnabled(widgets.talentId, talentEnabled)
            SetEnabled(widgets.talentName, talentEnabled)
            SetEnabled(widgets.talentCD, talentEnabled)
            SetLabelsEnabled({ widgets.talentIdLabel, widgets.talentNameLabel, widgets.talentCDLabel }, talentEnabled)

            local delayInputEnabled = isCast and (state.delayEnabled == true)
            SetEnabled(widgets.delayEnabled, false)
            SetEnabled(widgets.delaySeconds, false)
            SetNativeLabelColor(widgets.delaySecondsLabel, false)
            SetEnabled(widgets.castImmediateEnabled, isCast)
            SetEnabled(widgets.castDelayEnabled, isCast)
            SetEnabled(widgets.castDelaySeconds, delayInputEnabled)
            if widgets.castDelayModeDrop and widgets.castDelayModeDrop.Hide then widgets.castDelayModeDrop:Hide() end
            SetLabelsEnabled({ widgets.castDelayLabel, widgets.castDelayAfterLabel }, delayInputEnabled)
            SetEnabled(widgets.baseCD, isCooldown)
        end
    end

    if SoundFields and type(SoundFields.PushToWidgets) == "function" then
        SoundFields:PushToWidgets(widgets, state, soundFields, source, isTts)
    end

    if widgets.voiceEnabled then widgets.voiceEnabled:SetChecked(state.voiceEnabled == true) end
    if widgets.imageEnabled then widgets.imageEnabled:SetChecked(state.imageEnabled == true) end
    if widgets.textEnabled then widgets.textEnabled:SetChecked(state.textEnabled == true) end
    if widgets.conditionSpellNameText then
        local displaySpellName = Trim(state.spellName or "")
        if displaySpellName == "" then displaySpellName = L("LABEL_SPELL_NAME") end
        widgets.conditionSpellNameText:SetText(displaySpellName)
    end
    if widgets.conditionOp then
        Widgets:SetDropdownItems(widgets.conditionOp, GetConditionOperatorItems())
        Widgets:SetDropdownValue(widgets.conditionOp, isCustom and state.customConditionOp or state.voiceConditionOp, "<=")
    else
        Widgets:SetDropdownItems(widgets.voiceConditionOp, GetConditionOperatorItems())
        Widgets:SetDropdownValue(widgets.voiceConditionOp, state.voiceConditionOp, "<=")
        Widgets:SetDropdownItems(widgets.imageConditionOp, GetConditionOperatorItems())
        Widgets:SetDropdownValue(widgets.imageConditionOp, state.imageConditionOp, "<=")
        Widgets:SetDropdownItems(widgets.textConditionOp, GetConditionOperatorItems())
        Widgets:SetDropdownValue(widgets.textConditionOp, state.textConditionOp, "<=")
    end
    local function FormatConditionTime(value)
        local numeric = tonumber(value)
        if numeric == nil then
            numeric = 0
        end
        if math.abs(numeric - math.floor(numeric + 0.5)) < 0.001 then
            return tostring(math.floor(numeric + 0.5))
        end
        return tostring(numeric)
    end
    local conditionText = isCustom and tostring(state.customConditionValue or "0") or FormatConditionTime(state.voiceConditionTime)
    if widgets.customConditionVarDrop then
        Widgets:SetDropdownItems(widgets.customConditionVarDrop, BuildCustomResultVarItems(state.customResultVars))
        Widgets:SetDropdownValue(widgets.customConditionVarDrop, state.customResultVar, L("PLACEHOLDER_SELECT_VARIABLE"))
    end
    if widgets.conditionTime then
        widgets.conditionTime:SetText(conditionText)
    else
        if widgets.voiceConditionTime then widgets.voiceConditionTime:SetText(conditionText) end
        if widgets.imageConditionTime then widgets.imageConditionTime:SetText(FormatConditionTime(state.imageConditionTime)) end
        if widgets.textConditionTime then widgets.textConditionTime:SetText(FormatConditionTime(state.textConditionTime)) end
    end
    if widgets.conditionActionsDrop and Widgets.SetMultiDropdownValues then
        Widgets:SetDropdownItems(widgets.conditionActionsDrop, GetConditionActionItems())
        Widgets:SetMultiDropdownValues(widgets.conditionActionsDrop, {
            voice = state.voiceEnabled == true,
            image = state.imageEnabled == true,
            text = state.textEnabled == true,
        }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
    end
    if widgets.customNotifyActionsDrop and Widgets.SetMultiDropdownValues then
        Widgets:SetDropdownItems(widgets.customNotifyActionsDrop, GetConditionActionItems())
        Widgets:SetMultiDropdownValues(widgets.customNotifyActionsDrop, {
            voice = state.voiceEnabled == true,
            image = state.imageEnabled == true,
            text = state.textEnabled == true,
        }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
    end
    ApplyCustomNotifyRows(widgets, state, showSettings and isCustom)
    if widgets.castDelayModeDrop then
        Widgets:SetDropdownItems(widgets.castDelayModeDrop, GetCastDelayModeItems())
        Widgets:SetDropdownValue(widgets.castDelayModeDrop, "show", L("CAST_DELAY_MODE_SHOW"))
        if widgets.castDelayModeDrop.Hide then widgets.castDelayModeDrop:Hide() end
    end
    if widgets.castConditionActionsDrop and Widgets.SetMultiDropdownValues then
        Widgets:SetDropdownItems(widgets.castConditionActionsDrop, GetConditionActionItems())
        Widgets:SetMultiDropdownValues(widgets.castConditionActionsDrop, {
            voice = state.voiceEnabled == true,
            image = state.imageEnabled == true,
            text = state.textEnabled == true,
        }, L("PLACEHOLDER_SELECT_ALERT_ACTIONS"))
    end
    if widgets.imageSourceDrop then
        Widgets:SetDropdownItems(widgets.imageSourceDrop, GetImageSourceItems())
        Widgets:SetDropdownValue(widgets.imageSourceDrop, state.imageSource, L("IMAGE_SOURCE_AUTO"))
    end
    if widgets.imageIconLabel then widgets.imageIconLabel:SetText(GetImageIDLabel(state.imageSource)) end
    if widgets.imageIconID then widgets.imageIconID:SetText((tonumber(state.imageIconID) or 0) > 0 and tostring(math.floor(tonumber(state.imageIconID) or 0)) or "") end
    if widgets.imagePath then widgets.imagePath:SetText(tostring(state.imagePath or "")) end
    SetNumericControlValue(widgets.imageSize, state.imageSize or 96)
    if widgets.imageDurationEnabled then widgets.imageDurationEnabled:SetChecked(state.imageDurationEnabled == true) end
    if widgets.imageDuration then widgets.imageDuration:SetText(tostring(state.imageDuration or 2)) end
    if widgets.imageX then widgets.imageX:SetText(tostring(state.imageX or 0)) end
    if widgets.imageY then widgets.imageY:SetText(tostring(state.imageY or 120)) end
    if widgets.textAlert then widgets.textAlert:SetText(tostring(state.textAlert or "")) end
    SetNumericControlValue(widgets.textSize, state.textSize or 24)
    if widgets.textDurationEnabled then widgets.textDurationEnabled:SetChecked(state.textDurationEnabled == true) end
    if widgets.textDuration then widgets.textDuration:SetText(tostring(state.textDuration or 2)) end
    if widgets.textX then widgets.textX:SetText(tostring(state.textX or 0)) end
    if widgets.textY then widgets.textY:SetText(tostring(state.textY or 120)) end
    if widgets.textAttachDrop then
        Widgets:SetDropdownItems(widgets.textAttachDrop, GetTextAttachItems())
        Widgets:SetDropdownValue(widgets.textAttachDrop, state.textAttachMode, L("TEXT_ATTACH_OUTSIDE"))
    end
    if widgets.textVAlignDrop then
        Widgets:SetDropdownItems(widgets.textVAlignDrop, GetTextVAlignItems())
        Widgets:SetDropdownValue(widgets.textVAlignDrop, state.textVAlign, L("TEXT_VALIGN_BOTTOM"))
    end
    if widgets.textHAlignDrop then
        Widgets:SetDropdownItems(widgets.textHAlignDrop, GetTextHAlignItems())
        Widgets:SetDropdownValue(widgets.textHAlignDrop, state.textHAlign, L("TEXT_HALIGN_CENTER"))
    end
    if widgets.textOffsetX then widgets.textOffsetX:SetText(tostring(state.textOffsetX or 0)) end
    if widgets.textOffsetY then widgets.textOffsetY:SetText(tostring(state.textOffsetY or 0)) end

    local unifiedConditionControls = { widgets.conditionRow1, widgets.conditionRow2, widgets.conditionWhenLabel, widgets.conditionSpellNameText, widgets.conditionRemainingLabel, widgets.conditionOp, widgets.conditionTime, widgets.conditionSecLabel, widgets.conditionExecuteLabel, widgets.conditionActionsDrop, widgets.conditionActionHint }
    local customConditionControls = { widgets.customNotifyAddButton, widgets.customNotifyExecuteRow, widgets.customNotifyExecuteLabel, widgets.customNotifyActionsDrop }
    if type(widgets.customNotifyRows) == "table" then
        for _, row in ipairs(widgets.customNotifyRows) do
            customConditionControls[#customConditionControls + 1] = row
        end
    end
    local castConditionControls = { widgets.castConditionRow1, widgets.castConditionRow2, widgets.castConditionRow3, widgets.castImmediateEnabled, widgets.castDelayEnabled, widgets.castDelayLabel, widgets.castDelaySeconds, widgets.castDelayAfterLabel, widgets.castConditionExecuteLabel, widgets.castConditionActionsDrop }
    local voiceConditionControls = { widgets.voiceConditionLabel, widgets.voiceConditionCdLabel }
    local imageConditionControls = { widgets.imageConditionLabel, widgets.imageConditionCdLabel }
    local textConditionControls = { widgets.textConditionLabel, widgets.textConditionCdLabel }
    SetManyShown(unifiedConditionControls, showSettings and isCooldown)
    SetManyShown(customConditionControls, showSettings and isCustom)
    SetManyShown(castConditionControls, showSettings and isCast)
    if showSettings and isCooldown then
        -- Force the inline condition/action controls visible after returning from Voice/Image/Text tabs.
        -- Some native dropdown frames keep their previous hidden state when their parent row was hidden.
        ForceShowInlineCondition(widgets)
    elseif showSettings and isCast then
        ForceShowCastCondition(widgets)
    elseif showSettings and isCustom then
        ForceShowCustomCondition(widgets)
    end
    SetManyShown(voiceConditionControls, false)
    SetManyShown(imageConditionControls, false)
    SetManyShown(textConditionControls, false)

    local voiceControls = {
        widgets.voiceEnabled, widgets.sourceLabel, widgets.sourceDrop, widgets.builtinLabel, widgets.builtinDrop,
        widgets.sharedMediaLabel, widgets.sharedMediaDrop, widgets.customPathLabel, widgets.soundPath,
        widgets.ttsTextLabel, widgets.ttsText, widgets.rateLabel, widgets.ttsRateSlider,
    }
    local imageControls = {
        widgets.imageEnabled, widgets.imageSourceLabel, widgets.imageSourceDrop, widgets.imageIconLabel, widgets.imageIconID, widgets.imageIconPreview,
        widgets.imagePathLabel, widgets.imagePath, widgets.imageSizeLabel, widgets.imageSize, widgets.imageDurationEnabled,
        widgets.imageDurationLabel, widgets.imageDuration,
    }
    local imagePositionControls = {
        widgets.imagePositionSection, widgets.imageXLabel, widgets.imageX, widgets.imageYLabel, widgets.imageY,
        widgets.imagePreviewButton, widgets.imageHidePreviewButton, widgets.imageNudgeLabel, widgets.imageNudgeUp, widgets.imageNudgeDown,
        widgets.imageNudgeLeft, widgets.imageNudgeRight, widgets.imageNudgeReset,
    }
    local textControls = {
        widgets.textEnabled, widgets.textAlertLabel, widgets.textAlert, widgets.textSizeLabel, widgets.textSize, widgets.textDurationEnabled,
        widgets.textDurationLabel, widgets.textDuration,
    }
    local textPositionControls = {
        widgets.textPositionSection, widgets.textXLabel, widgets.textX, widgets.textYLabel, widgets.textY,
        widgets.textPreviewButton, widgets.textHidePreviewButton, widgets.textSingleNudgeLabel, widgets.textSingleNudgeUp,
        widgets.textSingleNudgeDown, widgets.textSingleNudgeLeft, widgets.textSingleNudgeRight, widgets.textSingleNudgeReset,
    }
    local visualLayoutControls = {
        widgets.visualLayoutSection, widgets.textAttachLabel, widgets.textAttachDrop, widgets.textVAlignLabel, widgets.textVAlignDrop,
        widgets.textHAlignLabel, widgets.textHAlignDrop, widgets.textNudgeLabel,
        widgets.textNudgeUp, widgets.textNudgeDown, widgets.textNudgeLeft, widgets.textNudgeRight, widgets.textNudgeReset,
        widgets.layoutPreviewButton, widgets.layoutHidePreviewButton,
    }
    SetManyShown(voiceControls, showVoice)
    local bloodlustCustomVoice = showVoice and isBloodlust and tostring(source or state.soundSource or "") == "custom"
    if bloodlustCustomVoice then
        SetManyShown({ widgets.ttsTextLabel, widgets.ttsText, widgets.rateLabel, widgets.ttsRateSlider }, false)
        if widgets.customPathLabel and widgets.customPathLabel.SetText then
            widgets.customPathLabel:SetText(L("LABEL_SOUND_PATH_N", 1))
        end
    elseif widgets.customPathLabel and widgets.customPathLabel.SetText then
        widgets.customPathLabel:SetText(L("LABEL_CUSTOM_SOUND_PATH"))
    end
    SetManyShown(imageControls, showImage)
    SetManyShown(imagePositionControls, imagePositionLayout)
    SetManyShown(textControls, showText)
    SetManyShown(textPositionControls, textOnlyPositionLayout and (not linkedVisualLayout))
    SetManyShown(visualLayoutControls, linkedVisualLayout and (not textOnlyPositionLayout))
    if widgets.textPositionSection and widgets.visualLayoutSection then
        if linkedVisualLayout then
            widgets.textPositionSection:Hide()
            widgets.visualLayoutSection:Show()
        elseif textOnlyPositionLayout then
            widgets.visualLayoutSection:Hide()
            widgets.textPositionSection:Show()
        else
            widgets.textPositionSection:Hide()
            widgets.visualLayoutSection:Hide()
        end
    end
    if widgets.imagePositionSection then
        widgets.imagePositionSection:SetShown(imagePositionLayout == true)
    end
    if widgets.textOffsetX then widgets.textOffsetX:Hide() end
    if widgets.textOffsetY then widgets.textOffsetY:Hide() end
    if widgets.editorHint and widgets.editorHint.Hide then
        widgets.editorHint:Hide()
    end

    if showSettings then
        if widgets.conditionOp then
            local conditionEnabled = isCooldown or isCustom
            Widgets:SetDropdownEnabled(widgets.conditionOp, conditionEnabled)
            SetEnabled(widgets.conditionTime, conditionEnabled)
            Widgets:SetDropdownEnabled(widgets.conditionActionsDrop, conditionEnabled and not isCustom)
            Widgets:SetDropdownEnabled(widgets.customNotifyActionsDrop, isCustom)
            Widgets:SetDropdownEnabled(widgets.customConditionLogicDrop, isCustom)
            Widgets:SetDropdownEnabled(widgets.customConditionVarDrop, false)
            SetLabelsEnabled({ widgets.conditionWhenLabel, widgets.conditionSpellNameText, widgets.conditionRemainingLabel, widgets.conditionSecLabel, widgets.conditionExecuteLabel, widgets.conditionActionHint }, isCooldown)
            SetLabelsEnabled({ widgets.customConditionVarLabel, widgets.customConditionValueLabel }, false)
            if type(widgets.customNotifyRows) == "table" then
                for _, row in ipairs(widgets.customNotifyRows) do
                    Widgets:SetDropdownEnabled(row.varDrop, isCustom)
                    Widgets:SetDropdownEnabled(row.opDrop, isCustom)
                    SetEnabled(row.value, isCustom)
                    SetEnabled(row.addButton, isCustom)
                    SetEnabled(row.deleteButton, isCustom)
                end
            end
            local castDelayInputEnabled = isCast and state.delayEnabled == true
            SetEnabled(widgets.castImmediateEnabled, isCast)
            SetEnabled(widgets.castDelayEnabled, isCast)
            SetEnabled(widgets.castDelaySeconds, castDelayInputEnabled)
            if widgets.castDelayModeDrop and widgets.castDelayModeDrop.Hide then widgets.castDelayModeDrop:Hide() end
            Widgets:SetDropdownEnabled(widgets.castConditionActionsDrop, isCast)
            SetLabelsEnabled({ widgets.castDelayLabel, widgets.castDelayAfterLabel }, castDelayInputEnabled)
            SetLabelsEnabled({ widgets.castConditionExecuteLabel }, isCast)
        else
            local voiceEnabled = state.voiceEnabled == true
            local imageEnabled = state.imageEnabled == true
            local textEnabled = state.textEnabled == true
            Widgets:SetDropdownEnabled(widgets.voiceConditionOp, voiceEnabled and isCooldown)
            SetEnabled(widgets.voiceConditionTime, voiceEnabled and isCooldown)
            SetLabelsEnabled({ widgets.voiceConditionLabel, widgets.voiceConditionCdLabel, widgets.voiceConditionSecLabel }, voiceEnabled and isCooldown)
            Widgets:SetDropdownEnabled(widgets.imageConditionOp, imageEnabled and isCooldown)
            SetEnabled(widgets.imageConditionTime, imageEnabled and isCooldown)
            SetLabelsEnabled({ widgets.imageConditionLabel, widgets.imageConditionCdLabel, widgets.imageConditionSecLabel }, imageEnabled and isCooldown)
            Widgets:SetDropdownEnabled(widgets.textConditionOp, textEnabled and isCooldown)
            SetEnabled(widgets.textConditionTime, textEnabled and isCooldown)
            SetLabelsEnabled({ widgets.textConditionLabel, widgets.textConditionCdLabel, widgets.textConditionSecLabel }, textEnabled and isCooldown)
        end
    elseif showVoice then
        local voiceEnabled = state.voiceEnabled == true
        Widgets:SetDropdownEnabled(widgets.sourceDrop, voiceEnabled)
        SetNativeLabelColor(widgets.sourceLabel, voiceEnabled)
        if not voiceEnabled then
            Widgets:SetDropdownEnabled(widgets.builtinDrop, false)
            Widgets:SetDropdownEnabled(widgets.sharedMediaDrop, false)
            SetControlsEnabled({ widgets.soundPath, widgets.ttsText, widgets.ttsRateSlider }, false)
            SetLabelsEnabled({ widgets.builtinLabel, widgets.sharedMediaLabel, widgets.customPathLabel, widgets.ttsTextLabel, widgets.rateLabel }, false)
            if Layout.SetRateSliderLabelEnabled then Layout.SetRateSliderLabelEnabled(widgets.ttsRateSlider, false) end
        end
    elseif showImage then
        local enabled = state.imageEnabled == true
        local imageSource = NormalizeImageSource(state.imageSource)
        local usesID = imageSource == "spell" or imageSource == "item" or imageSource == "icon"
        local usesPath = imageSource == "path"
        SetControlsEnabled({ widgets.imageSourceDrop, widgets.imageSize, widgets.imageDurationEnabled }, enabled)
        if Layout.SetValueSliderLabelEnabled then Layout.SetValueSliderLabelEnabled(widgets.imageSize, enabled) end
        SetControlsEnabled({ widgets.imageX, widgets.imageY, widgets.imagePreviewButton, widgets.imageHidePreviewButton, widgets.imageNudgeUp, widgets.imageNudgeDown, widgets.imageNudgeLeft, widgets.imageNudgeRight, widgets.imageNudgeReset }, enabled and imagePositionLayout)
        SetControlsEnabled({ widgets.imageIconID }, enabled and usesID)
        SetControlsEnabled({ widgets.imagePath }, enabled and usesPath)
        SetControlsEnabled({ widgets.imageDuration }, enabled and state.imageDurationEnabled == true)
        Widgets:SetDropdownEnabled(widgets.imageSourceDrop, enabled)
        SetLabelsEnabled({ widgets.imageSourceLabel, widgets.imageSizeLabel }, enabled)
        SetLabelsEnabled({ widgets.imageXLabel, widgets.imageYLabel, widgets.imageNudgeLabel }, enabled and imagePositionLayout)
        SetManyShown({ widgets.imageIconLabel, widgets.imageIconID }, showImage and usesID)
        SetManyShown({ widgets.imagePathLabel, widgets.imagePath }, showImage and usesPath)
        SetLabelsEnabled({ widgets.imageIconLabel }, enabled and usesID)
        if widgets.imageIconPreview then
            if showImage and enabled then
                self:UpdateImageIconPreview(editor)
            else
                widgets.imageIconPreview:Hide()
            end
        end
        SetLabelsEnabled({ widgets.imagePathLabel }, enabled and usesPath)
        SetLabelsEnabled({ widgets.imageDurationLabel }, enabled and state.imageDurationEnabled == true)
    elseif showText then
        local enabled = state.textEnabled == true
        local linked = linkedVisualLayout == true
        local textOnly = textOnlyPositionLayout == true
        SetControlsEnabled({ widgets.textAlert, widgets.textSize, widgets.textDurationEnabled }, enabled)
        if Layout.SetValueSliderLabelEnabled then Layout.SetValueSliderLabelEnabled(widgets.textSize, enabled) end
        SetControlsEnabled({ widgets.textDuration }, enabled and state.textDurationEnabled == true)
        SetControlsEnabled({ widgets.textX, widgets.textY, widgets.textPreviewButton, widgets.textHidePreviewButton, widgets.textSingleNudgeUp, widgets.textSingleNudgeDown, widgets.textSingleNudgeLeft, widgets.textSingleNudgeRight, widgets.textSingleNudgeReset }, enabled and textOnly)
        SetControlsEnabled({ widgets.textAttachDrop, widgets.textVAlignDrop, widgets.textHAlignDrop, widgets.textNudgeUp, widgets.textNudgeDown, widgets.textNudgeLeft, widgets.textNudgeRight, widgets.textNudgeReset, widgets.layoutPreviewButton, widgets.layoutHidePreviewButton }, enabled and linked)
        Widgets:SetDropdownEnabled(widgets.textAttachDrop, enabled and linked)
        Widgets:SetDropdownEnabled(widgets.textVAlignDrop, enabled and linked)
        Widgets:SetDropdownEnabled(widgets.textHAlignDrop, enabled and linked)
        SetLabelsEnabled({ widgets.textAlertLabel, widgets.textSizeLabel }, enabled)
        SetLabelsEnabled({ widgets.textDurationLabel }, enabled and state.textDurationEnabled == true)
        SetLabelsEnabled({ widgets.textXLabel, widgets.textYLabel, widgets.textSingleNudgeLabel }, enabled and textOnly)
        SetLabelsEnabled({ widgets.textAttachLabel, widgets.textVAlignLabel, widgets.textHAlignLabel, widgets.textNudgeLabel }, enabled and linked)
    end

    SetManyShown({ widgets.tabTypeLabel, widgets.tabCooldown, widgets.tabCast, widgets.tabBloodlust, widgets.subTabLabel }, false)
    if widgets.actionTest then
        if showVoice then widgets.actionTest:Show() else widgets.actionTest:Hide() end
    end

    if showSettings and isCooldown then
        if widgets.conditionSection and widgets.conditionSection.SetHeight then
            widgets.conditionSection:SetHeight(150)
        end
        ForceShowInlineCondition(widgets)
    elseif showSettings and isCast then
        if widgets.conditionSection and widgets.conditionSection.SetHeight then
            widgets.conditionSection:SetHeight(170)
        end
        ForceShowCastCondition(widgets)
    elseif showSettings and isCustom then
        if widgets.conditionSection and widgets.conditionSection.SetHeight then
            widgets.conditionSection:SetHeight(GetCustomNotifySectionHeight(state))
        end
        ForceShowCustomCondition(widgets)
    end
    SetTabVisual(widgets.tabSettings, showSettings)
    SetTabVisual(widgets.tabVoice, showVoice)
    SetTabVisual(widgets.tabImage, showImage)
    SetTabVisual(widgets.tabText, showText)
    if frame.contentHost and frame.contentHost.UpdateScrollRange then
        frame.contentHost:UpdateScrollRange()
    end
end

local function SetLocaleText(target, text)
    if target and target.SetText then
        target:SetText(text)
    end
end

local function SetSectionLocaleText(section, text)
    if not section then return end
    if section.label and section.label.SetText then
        section.label:SetText(text)
    elseif section.qfxsaLabel and section.qfxsaLabel.SetText then
        section.qfxsaLabel:SetText(text)
    end
end

local function SetCheckButtonLocaleText(button, text)
    if not button then return end
    local label = (type(button.qfxsaLabel) == "table" and button.qfxsaLabel) or (type(button.Text) == "table" and button.Text) or (type(button.text) == "table" and button.text)
    if label and label.SetText then
        label:SetText(text)
        if label.SetWordWrap then label:SetWordWrap(false) end
        if label.SetMaxLines then label:SetMaxLines(1) end
        if label.SetWidth then label:SetWidth(math.max(1, (tonumber(button.qfxsaMaxWidth) or 180) - 30)) end
    end
    if button.SetSize then button:SetSize(24, 24) end
    if button.SetHitRectInsets then button:SetHitRectInsets(0, -math.max(0, (tonumber(button.qfxsaMaxWidth) or 180) - 30), 0, 0) end
end

function Fields:RefreshLocale(editor)
    if not editor.frame then
        return
    end

    ClearDropdownItemCache()
    if SoundFields and type(SoundFields.ClearDropdownItemCache) == "function" then
        SoundFields:ClearDropdownItemCache()
    end

    local frame = editor.frame
    local widgets = frame.widgets or {}
    local state = NS.AceOptions and NS.AceOptions.GetState and NS.AceOptions:GetState() or {}
    local entryType = tostring(state.entryType or "cooldown")

    if frame.title then
        local typeTitle = entryType == "bloodlust" and L("TAB_BLOODLUST") or (entryType == "custom" and L("TAB_CUSTOM") or (entryType == "cast" and L("TAB_CAST") or L("TAB_COOLDOWN")))
        frame.title:SetText((editor.mode == "new" and L("TITLE_NEW_CONFIG") or L("TITLE_EDIT_CONFIG")) .. " - " .. typeTitle)
    end
    SetLocaleText(frame.description, L("EDITOR_DESC"))
    SetLocaleText(widgets.tabTypeLabel, L("TAB_GROUP_TYPE"))
    SetLocaleText(widgets.subTabLabel, L("TAB_GROUP_PAGE"))
    SetLocaleText(widgets.tabCooldown, L("TAB_COOLDOWN"))
    SetLocaleText(widgets.tabCast, L("TAB_CAST"))
    SetLocaleText(widgets.tabBloodlust, L("TAB_BLOODLUST"))
    SetLocaleText(widgets.tabSettings, L("TAB_SETTINGS"))
    SetLocaleText(widgets.tabVoice, L("TAB_VOICE"))
    SetLocaleText(widgets.tabImage, L("TAB_IMAGE"))
    SetLocaleText(widgets.tabText, L("TAB_TEXT"))
    SetManyShown({ widgets.tabTypeLabel, widgets.tabCooldown, widgets.tabCast, widgets.tabBloodlust, widgets.subTabLabel }, false)
    SetLocaleText(widgets.actionSave, L("BTN_SAVE"))
    SetLocaleText(widgets.actionTest, L("BTN_TEST"))

    SetSectionLocaleText(widgets.classSection, L("SECTION_CLASS_SPEC"))
    SetSectionLocaleText(widgets.spellSection, L("SECTION_SPELL_PARAMS"))
    SetSectionLocaleText(widgets.conditionSection, L("SECTION_NOTIFY_CONDITIONS"))
    SetSectionLocaleText(widgets.bloodlustInfoSection, L("SECTION_BLOODLUST_BUILTIN"))
    SetLocaleText(widgets.bloodlustInfoText, L("BLOODLUST_BUILTIN_HINT"))
    SetSectionLocaleText(widgets.notifySection, L("SECTION_NOTIFY"))
    SetSectionLocaleText(widgets.imagePositionSection, L("LABEL_IMAGE_POSITION"))
    SetSectionLocaleText(widgets.textPositionSection, L("LABEL_TEXT_POSITION"))
    SetSectionLocaleText(widgets.visualLayoutSection, L("LABEL_TEXT_LAYOUT"))

    SetLocaleText(widgets.classLabel, L("LABEL_CLASS"))
    SetLocaleText(widgets.specLabel, L("LABEL_SPEC"))
    SetCheckButtonLocaleText(widgets.objectTypeItem, L("LABEL_IS_ITEM"))
    SetCheckButtonLocaleText(widgets.itemLoadEquipped, L("LABEL_ITEM_LOAD_EQUIPPED"))
    SetCheckButtonLocaleText(widgets.itemLoadBags, L("LABEL_ITEM_LOAD_BAGS"))
    SetCheckButtonLocaleText(widgets.itemLoadSameName, L("LABEL_ITEM_LOAD_SAME_NAME"))
    SetLocaleText(widgets.spellIdLabel, tostring(state.objectType or "") == OBJECT_TYPE_ITEM and L("LABEL_ITEM_ID") or L("LABEL_OBJECT_SPELL_ID"))
    SetLocaleText(widgets.spellNameLabel, L("LABEL_SPELL_NAME"))
    SetLocaleText(widgets.baseCDLabel, L("LABEL_FIXED_CD_SEC"))
    SetLocaleText(widgets.talentIdLabel, L("LABEL_TALENT_ID"))
    SetLocaleText(widgets.talentNameLabel, L("LABEL_TALENT_NAME"))
    SetLocaleText(widgets.talentCDLabel, L("LABEL_TALENT_CD_SEC"))
    SetLocaleText(widgets.delaySecondsLabel, L("LABEL_DELAY_SECONDS"))
    SetLocaleText(widgets.sourceLabel, L("LABEL_SOUND_SOURCE"))
    SetLocaleText(widgets.builtinLabel, L("LABEL_BUILTIN_SOUND"))
    SetLocaleText(widgets.sharedMediaLabel, L("LABEL_SHAREDMEDIA_SOUND"))
    SetLocaleText(widgets.customPathLabel, L("LABEL_CUSTOM_SOUND_PATH"))
    for i = 2, 5 do
        if widgets.bloodlustCustomPathLabels and widgets.bloodlustCustomPathLabels[i] then
            SetLocaleText(widgets.bloodlustCustomPathLabels[i], L("LABEL_SOUND_PATH_N", i))
        end
    end
    SetLocaleText(widgets.ttsTextLabel, L("LABEL_TTS_TEXT"))
    SetLocaleText(widgets.rateLabel, L("LABEL_TTS_RATE"))
    SetLocaleText(widgets.imageSourceLabel, L("LABEL_IMAGE_SOURCE"))
    SetLocaleText(widgets.imageIconLabel, L("LABEL_IMAGE_ICON_ID"))
    SetLocaleText(widgets.imagePathLabel, L("LABEL_IMAGE_PATH"))
    SetLocaleText(widgets.imageSizeLabel, L("LABEL_IMAGE_SIZE"))
    SetLocaleText(widgets.imageDurationLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.imageXLabel, L("LABEL_POSITION_X"))
    SetLocaleText(widgets.imageYLabel, L("LABEL_POSITION_Y"))
    SetLocaleText(widgets.imagePreviewButton, L("BTN_SHOW_PREVIEW"))
    SetLocaleText(widgets.imageHidePreviewButton, L("BTN_HIDE_PREVIEW"))
    SetLocaleText(widgets.imageNudgeLabel, L("LABEL_IMAGE_NUDGE"))
    SetLocaleText(widgets.imageNudgeReset, L("BTN_RESET"))
    SetLocaleText(widgets.textAlertLabel, L("LABEL_TEXT_CONTENT"))
    SetLocaleText(widgets.textSizeLabel, L("LABEL_TEXT_SIZE"))
    SetLocaleText(widgets.textDurationLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.textXLabel, L("LABEL_POSITION_X"))
    SetLocaleText(widgets.textYLabel, L("LABEL_POSITION_Y"))
    SetLocaleText(widgets.textSingleNudgeLabel, L("LABEL_TEXT_POSITION_NUDGE"))
    SetLocaleText(widgets.textSingleNudgeReset, L("BTN_RESET"))
    SetLocaleText(widgets.textLayoutLabel, L("LABEL_TEXT_LAYOUT"))
    SetLocaleText(widgets.textAttachLabel, L("LABEL_TEXT_ATTACH_MODE"))
    SetLocaleText(widgets.textVAlignLabel, L("LABEL_TEXT_VALIGN"))
    SetLocaleText(widgets.textHAlignLabel, L("LABEL_TEXT_HALIGN"))
    SetLocaleText(widgets.textNudgeLabel, L("LABEL_TEXT_NUDGE"))
    SetLocaleText(widgets.textNudgeReset, L("BTN_RESET"))
    SetLocaleText(widgets.layoutPreviewButton, L("BTN_SHOW_PREVIEW"))
    SetLocaleText(widgets.layoutHidePreviewButton, L("BTN_HIDE_PREVIEW"))
    SetLocaleText(widgets.textPreviewButton, L("BTN_SHOW_PREVIEW"))
    SetLocaleText(widgets.textHidePreviewButton, L("BTN_HIDE_PREVIEW"))
    SetLocaleText(widgets.conditionWhenLabel, L("LABEL_CONDITION_WHEN"))
    SetSectionLocaleText(widgets.customSection, L("SECTION_CUSTOM_CODE"))
    SetLocaleText(widgets.customNameLabel, L("LABEL_CUSTOM_NAME"))
    SetCheckButtonLocaleText(widgets.customEventEnabled, L("LABEL_CUSTOM_EVENT_TRIGGER"))
    SetLocaleText(widgets.customEventsLabel, L("LABEL_CUSTOM_EVENTS"))
    SetLocaleText(widgets.customEventTextLabel, L("LABEL_CUSTOM_EVENT_TEXT"))
    SetCheckButtonLocaleText(widgets.customTickerEnabled, L("LABEL_CUSTOM_TICKER_TRIGGER"))
    SetLocaleText(widgets.customIntervalLabel, L("LABEL_CUSTOM_INTERVAL"))
    SetLocaleText(widgets.customIntervalSecLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.customCodeLabel, L("LABEL_CUSTOM_CODE"))
    SetLocaleText(widgets.customTestButton, L("BTN_CUSTOM_TEST"))
    SetLocaleText(widgets.customConditionVarLabel, L("LABEL_CUSTOM_RESULT_VAR"))
    SetLocaleText(widgets.customConditionValueLabel, L("LABEL_CUSTOM_COMPARE_VALUE"))
    SetLocaleText(widgets.conditionRemainingLabel, L("LABEL_COOLDOWN_REMAINING"))
    SetLocaleText(widgets.conditionSecLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.conditionExecuteLabel, L("LABEL_CONDITION_EXECUTE"))
    SetLocaleText(widgets.customConditionLogicLabel, L("LABEL_CUSTOM_CONDITION_LOGIC"))
    SetLocaleText(widgets.conditionActionHint, L("HINT_MULTI_SELECT_ACTIONS"))
    SetLocaleText(widgets.castDelayLabel, L("LABEL_CAST_DELAY_FIXED"))
    SetLocaleText(widgets.castDelayAfterLabel, L("LABEL_CAST_DELAY_AFTER_EXECUTE"))
    SetLocaleText(widgets.castConditionExecuteLabel, L("LABEL_CONDITION_EXECUTE"))
    SetLocaleText(widgets.voiceConditionLabel, L("LABEL_VOICE_CONDITION"))
    SetLocaleText(widgets.imageConditionLabel, L("LABEL_IMAGE_CONDITION"))
    SetLocaleText(widgets.textConditionLabel, L("LABEL_TEXT_CONDITION"))
    SetLocaleText(widgets.voiceConditionCdLabel, L("LABEL_SKILL_CD"))
    SetLocaleText(widgets.imageConditionCdLabel, L("LABEL_SKILL_CD"))
    SetLocaleText(widgets.textConditionCdLabel, L("LABEL_SKILL_CD"))
    SetLocaleText(widgets.voiceConditionSecLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.imageConditionSecLabel, L("LABEL_SECONDS_SHORT"))
    SetLocaleText(widgets.textConditionSecLabel, L("LABEL_SECONDS_SHORT"))

    SetCheckButtonLocaleText(widgets.checkTalent, L("LABEL_CHECK_TALENT"))
    SetCheckButtonLocaleText(widgets.delayEnabled, L("LABEL_DELAY_CAST_SUCCESS"))
    SetCheckButtonLocaleText(widgets.castImmediateEnabled, L("LABEL_CAST_IMMEDIATE_EXECUTE"))
    SetCheckButtonLocaleText(widgets.castDelayEnabled, L("LABEL_CAST_DELAY_EXECUTE"))
    SetCheckButtonLocaleText(widgets.voiceEnabled, L("LABEL_ENABLE_VOICE_ALERT"))
    SetCheckButtonLocaleText(widgets.imageEnabled, L("LABEL_ENABLE_IMAGE_ALERT"))
    SetCheckButtonLocaleText(widgets.imageDurationEnabled, L("LABEL_LIMIT_IMAGE_DURATION"))
    SetCheckButtonLocaleText(widgets.textEnabled, L("LABEL_ENABLE_TEXT_ALERT"))
    SetCheckButtonLocaleText(widgets.textDurationEnabled, L("LABEL_LIMIT_TEXT_DURATION"))

    if frame:IsShown() then
        self:PushToWidgets(editor)
        frame:Raise()
    end
end
