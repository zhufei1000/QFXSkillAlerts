local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.ImportExportUtil = NS.ImportExportUtil or {}

local Util = NS.ImportExportUtil
local CONST = NS.Constants or {}
local Utils = NS.Utils or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"
local OBJECT_TYPE_ITEM = CONST.OBJECT_TYPE_ITEM or "item"
local ITEM_LOAD_NONE = CONST.ITEM_LOAD_NONE or "none"
local ITEM_LOAD_EQUIPPED = CONST.ITEM_LOAD_EQUIPPED or "equipped"
local ITEM_LOAD_BAGS = CONST.ITEM_LOAD_BAGS or "bags"


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

local function NormalizeConditionTime(value, fallback)
    local numeric = tonumber(value)
    if numeric == nil then
        numeric = tonumber(fallback) or 0
    end
    return math.max(0, numeric or 0)
end

local function NormalizeCastDelayMode(value)
    return "show"
end

local function NormalizeItemLoadMode(value)
    value = tostring(value or ITEM_LOAD_NONE):lower()
    if value == ITEM_LOAD_EQUIPPED or value == ITEM_LOAD_BAGS then
        return value
    end
    return ITEM_LOAD_NONE
end

local function TrimText(value)
    if Utils.TrimText then
        return Utils.TrimText(value)
    end
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function CopyBooleanMap(source)
    local copy = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            if value == true and type(key) == "string" and key ~= "" then
                copy[key] = true
            end
        end
    end
    return copy
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

local function NormalizeCustomClassMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        return nil
    end
    if copy[ALL_CLASSES_ID] == true then
        return { [ALL_CLASSES_ID] = true }
    end
    return copy
end

local function NormalizeCustomSpecMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        return nil
    end
    if copy[ALL_SPECS_ID] == true then
        return { [ALL_SPECS_ID] = true }
    end
    return copy
end

local function NormalizeCustomRaceMap(source)
    local copy = CopyNumberBoolMap(source)
    if next(copy) == nil then
        return nil
    end
    if copy[ALL_RACES_ID] == true then
        return { [ALL_RACES_ID] = true }
    end
    return copy
end

local function NormalizeCustomInterval(value)
    local n = tonumber(value) or 0.5
    if n < 0.2 then n = 0.2 end
    if n > 60 then n = 60 end
    return tonumber(string.format("%.2f", n)) or 0.5
end

local function NormalizeCustomConditionLogic(value)
    value = tostring(value or "or"):lower()
    if value == "and" or value == "all" then
        return "and"
    end
    return "or"
end

local function CopyActionMap(source)
    local copy = {}
    if type(source) == "table" then
        copy.voice = source.voice == true
        copy.image = source.image == true
        copy.text = source.text == true
    end
    return copy
end

local function IsDefaultCustomNotification(item)
    if type(item) ~= "table" then
        return true
    end
    local resultVar = TrimText(item.resultVar or "")
    local op = NormalizeConditionOp(item.conditionOp or "<=")
    local value = tostring(item.conditionValue or "0")
    return resultVar == ""
        and op == "<="
        and (value == "" or value == "0")
end

local function GetEffectiveCustomNotifyCount(source, fallback)
    local sourceCount = type(source) == "table" and #source or 0
    local requested = tonumber(fallback and fallback.customNotifyCount) or sourceCount or 1
    local count = math.max(1, math.min(8, requested))
    while count > 1 and IsDefaultCustomNotification(type(source) == "table" and source[count] or nil) do
        count = count - 1
    end
    return count
end

local function CopyCustomNotifications(source, fallbackState)
    local list = {}
    local fallbackState = fallbackState
    local count = GetEffectiveCustomNotifyCount(source, fallbackState)
    for i = 1, count do
        local item = type(source) == "table" and type(source[i]) == "table" and source[i] or nil
        list[i] = {
            resultVar = TrimText((item and item.resultVar) or (i == 1 and fallbackState and fallbackState.customResultVar) or ""),
            conditionOp = NormalizeConditionOp((item and item.conditionOp) or (i == 1 and fallbackState and fallbackState.customConditionOp) or "<="),
            conditionValue = tostring((item and item.conditionValue) or (i == 1 and fallbackState and fallbackState.customConditionValue) or "0"),
        }
    end
    return list, count
end

local function GetApi()
    return NS.API
end

local function NormalizeObjectTypeValue(value)
    value = tostring(value or OBJECT_TYPE_SPELL):lower()
    if value ~= OBJECT_TYPE_ITEM then
        value = OBJECT_TYPE_SPELL
    end
    return value
end

local function SameEntryIdentity(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end
    local leftID = tonumber(left.spellId or left.itemID) or 0
    local rightID = tonumber(right.spellId or right.itemID) or 0
    if leftID <= 0 or rightID <= 0 or math.floor(leftID) ~= math.floor(rightID) then
        return false
    end
    local leftType = tostring(left.entryType or "cooldown")
    local rightType = tostring(right.entryType or "cooldown")
    if leftType ~= rightType then
        return false
    end
    local objectType = NormalizeObjectTypeValue(left.objectType)
    if objectType ~= NormalizeObjectTypeValue(right.objectType) then
        return false
    end
    if objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(left.itemLoadMode) ~= NormalizeItemLoadMode(right.itemLoadMode) then
        return false
    end
    return true
end

local function FindMatchingEntryIndex(map, entry)
    if type(map) ~= "table" or type(entry) ~= "table" then
        return nil
    end
    for index, candidate in pairs(map) do
        local numericIndex = tonumber(index) or 0
        if numericIndex > 0 and SameEntryIdentity(candidate, entry) then
            return numericIndex
        end
    end
    return nil
end

local function FindFirstFreeIndex(map, preferredIndex)
    map = type(map) == "table" and map or {}
    preferredIndex = tonumber(preferredIndex) or 0
    if preferredIndex > 0 and type(map[preferredIndex]) ~= "table" then
        return preferredIndex
    end
    for index = 1, 999 do
        if type(map[index]) ~= "table" then
            return index
        end
    end
    return nil
end

function Util:MergeLegacyCastSuccessConfigsIntoSpecConfigs(db, keepLegacy)
    if type(db) ~= "table" or type(db.castSuccessConfigs) ~= "table" then
        return 0
    end
    if type(db.specConfigs) ~= "table" then
        db.specConfigs = {}
    end

    local migrated = 0
    for classIDKey, classMap in pairs(db.castSuccessConfigs) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            if type(db.specConfigs[classID]) ~= "table" then
                db.specConfigs[classID] = {}
            end
            for specIDKey, legacyMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(legacyMap) == "table" then
                    if classID == ALL_CLASSES_ID then
                        specID = ALL_SPECS_ID
                    end
                    if type(db.specConfigs[classID][specID]) ~= "table" then
                        db.specConfigs[classID][specID] = {}
                    end
                    local targetMap = db.specConfigs[classID][specID]
                    for legacyIndex, legacyEntry in pairs(legacyMap) do
                        local index = tonumber(legacyIndex) or 0
                        if index > 0 and type(legacyEntry) == "table" then
                            local entry = self:DeepCopyTable(legacyEntry)
                            entry.entryType = "cast"
                            local sanitized = self:SanitizeEntryForImport(entry)
                            if sanitized then
                                local targetIndex = FindMatchingEntryIndex(targetMap, sanitized) or FindFirstFreeIndex(targetMap, index)
                                if targetIndex and targetIndex > 0 then
                                    targetMap[targetIndex] = sanitized
                                    migrated = migrated + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not keepLegacy then
        db.castSuccessConfigs = {}
    end
    return migrated
end

function Util:DeepCopyTable(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[self:DeepCopyTable(k, seen)] = self:DeepCopyTable(v, seen)
    end
    return copy
end

function Util:SanitizeEntryForImport(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local entryType = tostring(entry.entryType or "cooldown")
    if entryType == "custom" then
        return nil
    end
    if entryType ~= "cast" then
        entryType = "cooldown"
    end
    local spellId = tonumber(entry.spellId) or 0
    if spellId <= 0 then
        return nil
    end
    local modeTts, modeSound = "tts", "sound"
    local api = GetApi()
    if api and type(api.GetModes) == "function" then
        modeTts, modeSound = api.GetModes()
    end
    local notifyMode = tostring(entry.notifyMode or modeSound)
    if notifyMode ~= modeTts then
        notifyMode = modeSound
    end
    local soundFields
    if NS.AceOptions and type(NS.AceOptions.ResolveSoundSourceFields) == "function" then
        local sourceEntry = self:DeepCopyTable(entry)
        sourceEntry.notifyMode = notifyMode
        soundFields = NS.AceOptions:ResolveSoundSourceFields(sourceEntry, modeTts, modeSound)
    else
        local soundPath = tostring(entry.soundPath or ""):gsub("/", "\\")
        local soundSource = tostring(entry.soundSource or "")
        soundFields = {
            notifyMode = notifyMode,
            soundSource = (notifyMode == modeTts and "tts") or (soundSource ~= "" and soundSource or "custom"),
            soundPath = soundPath,
            sharedMediaSound = TrimText(entry.sharedMediaSound or entry.sharedMediaName or ""),
        }
    end
    notifyMode = soundFields.notifyMode

    local objectType = tostring(entry.objectType or "")
    if api and type(api.ResolveObjectType) == "function" then
        objectType = api.ResolveObjectType(spellId, objectType)
    end
    if objectType ~= OBJECT_TYPE_ITEM then
        objectType = OBJECT_TYPE_SPELL
    end

    local hasIndependentLoadTalent = entry.loadTalentEnabled ~= nil
        or entry.loadTalentId ~= nil or entry.loadTalentName ~= nil
    local loadTalentEnabled = entry.loadTalentEnabled == true
    local loadTalentId = tonumber(entry.loadTalentId) or 0
    local loadTalentName = TrimText(entry.loadTalentName or "")
    if not hasIndependentLoadTalent and entry.talentLoadFilter == true
        and entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0 then
        loadTalentEnabled = true
        loadTalentId = tonumber(entry.talentId) or 0
        loadTalentName = TrimText(entry.talentName or "")
    end

    local sanitized = {
        entryType = entryType,
        objectType = objectType,
        spellName = TrimText(entry.spellName or ""),
        spellId = math.floor(spellId),
        itemID = (objectType == OBJECT_TYPE_ITEM) and math.floor(tonumber(entry.itemID or spellId) or spellId) or nil,
        itemLoadMode = (objectType == OBJECT_TYPE_ITEM) and NormalizeItemLoadMode(entry.itemLoadMode) or nil,
        itemLoadSameName = (objectType == OBJECT_TYPE_ITEM and NormalizeItemLoadMode(entry.itemLoadMode) == ITEM_LOAD_BAGS and entry.itemLoadSameName == true) or nil,
        triggerSpellID = math.floor(tonumber(entry.triggerSpellID or entry.triggerSpellId) or 0),
        triggerSpellName = TrimText(entry.triggerSpellName or ""),
        baseCD = entryType == "cooldown" and (tonumber(string.format("%.2f", tonumber(entry.baseCD) or 0)) or 0) or 0,
        fixedCD = true,
        checkTalent = objectType ~= OBJECT_TYPE_ITEM and entryType == "cooldown"
            and entry.checkTalent == true and (tonumber(entry.talentId) or 0) > 0,
        talentId = objectType ~= OBJECT_TYPE_ITEM and math.floor(tonumber(entry.talentId) or 0) or 0,
        talentName = objectType ~= OBJECT_TYPE_ITEM and TrimText(entry.talentName or "") or "",
        talentCD = objectType ~= OBJECT_TYPE_ITEM and entryType == "cooldown"
            and (tonumber(string.format("%.2f", tonumber(entry.talentCD) or 0)) or 0) or 0,
        talentLoadFilter = false,
        loadTalentEnabled = objectType ~= OBJECT_TYPE_ITEM and loadTalentEnabled and loadTalentId > 0,
        loadTalentId = objectType ~= OBJECT_TYPE_ITEM and loadTalentEnabled and math.floor(loadTalentId) or 0,
        loadTalentName = objectType ~= OBJECT_TYPE_ITEM and loadTalentEnabled and loadTalentName or "",
        chargeInput = 1,
        notifyMode = notifyMode,
        ttsText = tostring(entry.ttsText or ""),
        ttsRate = math.max(-10, math.min(10, tonumber(entry.ttsRate) or 0)),
        delayEnabled = entryType == "cast" and entry.delayEnabled == true,
        delaySeconds = entryType == "cast" and math.max(0, tonumber(string.format("%.2f", tonumber(entry.delaySeconds) or 0)) or 0) or 0,
        castDelayMode = entryType == "cast" and NormalizeCastDelayMode(entry.castDelayMode) or "show",
        cooldownAlertTime = entryType == "cooldown" and math.max(0, tonumber(string.format("%.2f", tonumber(entry.cooldownAlertTime or entry.alertLeadTime) or 0)) or 0) or 0,
        soundPath = soundFields.soundPath or "",
        soundSource = soundFields.soundSource or nil,
        builtinSoundPath = soundFields.builtinSoundPath or entry.builtinSoundPath or nil,
        customSoundPath = soundFields.customSoundPath or entry.customSoundPath or nil,
        customSoundPaths = type(entry.customSoundPaths) == "table" and self:DeepCopyTable(entry.customSoundPaths) or nil,
        sharedMediaSound = (soundFields.soundSource == "sharedmedia" and TrimText(soundFields.sharedMediaSound or "") ~= "") and soundFields.sharedMediaSound or nil,
        voiceEnabled = entry.voiceEnabled ~= false,
        voiceConditionOp = entryType == "cooldown" and NormalizeConditionOp(entry.voiceConditionOp) or "<=",
        voiceConditionTime = entryType == "cooldown" and NormalizeConditionTime(entry.voiceConditionTime, entry.cooldownAlertTime or entry.alertLeadTime) or 0,
        imageEnabled = entry.imageEnabled == true,
        imageConditionOp = entryType == "cooldown" and NormalizeConditionOp(entry.imageConditionOp) or "<=",
        imageConditionTime = entryType == "cooldown" and NormalizeConditionTime(entry.imageConditionTime, entry.cooldownAlertTime or entry.alertLeadTime) or 0,
        imageSource = tostring(entry.imageSource or "auto"),
        imageIconID = math.max(0, tonumber(entry.imageIconID) or 0),
        imagePath = TrimText(entry.imagePath or ""),
        imageSize = math.max(16, tonumber(entry.imageSize) or 96),
        imageDurationEnabled = entry.imageDurationEnabled == true,
        imageDuration = math.max(0.1, tonumber(entry.imageDuration) or 2),
        imageX = tonumber(entry.imageX) or 0,
        imageY = tonumber(entry.imageY) or 120,
        textEnabled = entry.textEnabled == true,
        textCooldownCountdown = entryType == "cooldown" and entry.textEnabled == true
            and entry.textCooldownCountdown == true,
        textConditionOp = entryType == "cooldown" and NormalizeConditionOp(entry.textConditionOp) or "<=",
        textConditionTime = entryType == "cooldown" and NormalizeConditionTime(entry.textConditionTime, entry.cooldownAlertTime or entry.alertLeadTime) or 0,
        textAlert = tostring(entry.textAlert or ""),
        textSize = math.max(8, tonumber(entry.textSize) or 24),
        textDurationEnabled = entry.textDurationEnabled == true,
        textDuration = math.max(0.1, tonumber(entry.textDuration) or 2),
        textX = tonumber(entry.textX) or 0,
        textY = tonumber(entry.textY) or 120,
        textAttachMode = tostring(entry.textAttachMode or "outside"),
        textVAlign = tostring(entry.textVAlign or "bottom"),
        textHAlign = tostring(entry.textHAlign or "center"),
        textOffsetX = tonumber(entry.textOffsetX) or 0,
        textOffsetY = tonumber(entry.textOffsetY) or 0,
        customName = nil,
        customCode = nil,
        customUseEvents = nil,
        customEvents = nil,
        customEventText = nil,
        customUseTicker = nil,
        customInterval = nil,
        customResultVar = nil,
        customConditionOp = nil,
        customConditionValue = nil,
        customConditionLogic = nil,
        customResultVars = nil,
        customNotifications = nil,
        customNotifyCount = nil,
        alertRaceIDs = entry.alertRaceIDs and NormalizeCustomRaceMap(entry.alertRaceIDs) or nil,
        alertClassIDs = (entry.alertClassIDs or entry.customClassIDs) and NormalizeCustomClassMap(entry.alertClassIDs or entry.customClassIDs) or nil,
        alertSpecIDs = (entry.alertSpecIDs or entry.customSpecIDs) and NormalizeCustomSpecMap(entry.alertSpecIDs or entry.customSpecIDs) or nil,
        customClassIDs = nil,
        customSpecIDs = nil,
    }

    if Utils.SyncLinkedVisualDurations then
        Utils.SyncLinkedVisualDurations(sanitized)
    end

    if sanitized.imageSource ~= "spell" and sanitized.imageSource ~= "item" and sanitized.imageSource ~= "icon" and sanitized.imageSource ~= "path" then
        sanitized.imageSource = "auto"
    end
    if sanitized.textAttachMode ~= "inside" then sanitized.textAttachMode = "outside" end
    if sanitized.textVAlign ~= "top" and sanitized.textVAlign ~= "middle" then sanitized.textVAlign = "bottom" end
    if sanitized.textHAlign ~= "left" and sanitized.textHAlign ~= "right" then sanitized.textHAlign = "center" end

    if objectType == OBJECT_TYPE_ITEM and (tonumber(sanitized.triggerSpellID) or 0) <= 0 then
        sanitized.triggerSpellID = 0
    end

    return sanitized
end
