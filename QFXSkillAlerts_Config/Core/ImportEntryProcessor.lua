local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.ImportEntryProcessor = NS.ImportEntryProcessor or {}

local Processor = NS.ImportEntryProcessor
local CONST = NS.Constants or {}
local CollectionStore = NS.CollectionStore or {}
local ImportExportUtil = NS.ImportExportUtil or {}

local ALL_CLASSES_ID = CONST.ALL_CLASSES_ID or 0
local ALL_SPECS_ID = CONST.ALL_SPECS_ID or 0
local ALL_RACES_ID = CONST.ALL_RACES_ID or 0
local OBJECT_TYPE_SPELL = CONST.OBJECT_TYPE_SPELL or "spell"

local function GetApi()
    return NS.API
end

local function BuildEntryKey(classID, specID, index)
    if CollectionStore.BuildEntryKey then
        return CollectionStore.BuildEntryKey(classID, specID, index)
    end
    return string.format("%d:%d:%d", tonumber(classID) or 0, tonumber(specID) or 0, tonumber(index) or 0)
end

local function DeepCopyTable(value, seen)
    if ImportExportUtil and type(ImportExportUtil.DeepCopyTable) == "function" then
        return ImportExportUtil:DeepCopyTable(value, seen)
    end
    return value
end

local function SanitizeEntryForImport(entry)
    if ImportExportUtil and type(ImportExportUtil.SanitizeEntryForImport) == "function" then
        return ImportExportUtil:SanitizeEntryForImport(entry)
    end
    return nil
end

local function ClearDeletedEntryMarker(classID, specID, entry, index)
    local api = GetApi()
    if api and type(api.ClearEntryDeletedMarker) == "function" then
        api.ClearEntryDeletedMarker(classID, specID, entry, index)
    end
end

local function NumberBoolMapSignature(source, allID, fallbackID)
    local keys = {}
    local seen = {}
    if type(source) == "table" then
        for key, enabled in pairs(source) do
            local numericKey = tonumber(key)
            if enabled == true and numericKey and numericKey >= 0 and not seen[numericKey] then
                if numericKey == allID then
                    return tostring(allID)
                end
                seen[numericKey] = true
                keys[#keys + 1] = numericKey
            end
        end
    end
    if #keys == 0 then
        return tostring(tonumber(fallbackID) or allID)
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function EventScopeSignature(entry, classID, specID)
    entry = type(entry) == "table" and entry or {}
    return table.concat({
        NumberBoolMapSignature(entry.alertRaceIDs, ALL_RACES_ID, ALL_RACES_ID),
        NumberBoolMapSignature(entry.alertClassIDs or entry.customClassIDs, ALL_CLASSES_ID, classID),
        NumberBoolMapSignature(entry.alertSpecIDs or entry.customSpecIDs, ALL_SPECS_ID, specID),
    }, "|")
end

function Processor:FindMatchingEntryIndexBySpell(map, spellId, entryType, objectType, eventKey, scopeEntry, classID, specID)
    spellId = tonumber(spellId) or 0
    entryType = tostring(entryType or "cooldown")
    objectType = tostring(objectType or OBJECT_TYPE_SPELL)
    if type(map) ~= "table" then
        return nil
    end
    if entryType == "event" then
        eventKey = tostring(eventKey or "")
        if eventKey == "" then
            return nil
        end
        local importedScope = EventScopeSignature(scopeEntry, classID, specID)
        local api = GetApi()
        local indices = api and type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(map) or {}
        for _, index in ipairs(indices) do
            local entry = api.GetEntry(map, index)
            if entry and tostring(entry.entryType or "") == "event"
                and tostring(entry.eventKey or "") == eventKey
                and EventScopeSignature(entry, classID, specID) == importedScope then
                return tonumber(index) or 0
            end
        end
        return nil
    end
    if spellId <= 0 then
        return nil
    end
    local api = GetApi()
    if api and type(api.ResolveObjectType) == "function" then
        objectType = api.ResolveObjectType(spellId, objectType)
    end
    local indices = api and type(api.GetOrderedEntryIndices) == "function" and api.GetOrderedEntryIndices(map) or {}
    for _, index in ipairs(indices) do
        local entry = api.GetEntry(map, index)
        local existingID = tonumber(entry and entry.spellId) or 0
        local existingType = api and type(api.ResolveObjectType) == "function" and api.ResolveObjectType(existingID, entry and entry.objectType) or tostring(entry and entry.objectType or OBJECT_TYPE_SPELL)
        if entry
            and (tonumber(entry.spellId) or 0) == spellId
            and tostring(entry.entryType or "cooldown") == entryType
            and tostring(existingType) == tostring(objectType) then
            return tonumber(index) or 0
        end
    end
    return nil
end

function Processor:FindFirstFreeIndexInMap(map)
    local api = GetApi()
    if api and type(api.FindFirstFreeIndex) == "function" then
        return api.FindFirstFreeIndex(map)
    end
    for i = 1, 999 do
        local entry = map[i]
        if type(entry) ~= "table" then
            return i
        end
        local spellId = tonumber(entry.spellId) or 0
        local isEvent = tostring(entry.entryType or "") == "event" and tostring(entry.eventKey or "") ~= ""
        if spellId <= 0 and not isEvent then
            return i
        end
    end
    return nil
end

function Processor:ImportEntryRecord(record, preferImportedIndex)
    local api = GetApi()
    if not api or type(record) ~= "table" then
        return nil
    end
    local classID = tonumber(record.classID) or 0
    local specID = tonumber(record.specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    local importIndex = tonumber(record.index) or 0
    local entry = SanitizeEntryForImport(record.entry)
    if classID < 0 or specID < 0 or not entry then
        return nil
    end

    local map = api.EnsureEntryMap(classID, specID)
    if type(map) ~= "table" then
        return nil
    end

    local targetIndex = self:FindMatchingEntryIndexBySpell(
        map, entry.spellId, entry.entryType, entry.objectType, entry.eventKey,
        entry, classID, specID
    )
    if not targetIndex and preferImportedIndex and importIndex > 0 then
        local existing = api.GetEntry(map, importIndex)
        if not existing then
            targetIndex = importIndex
        end
    end
    if not targetIndex then
        targetIndex = self:FindFirstFreeIndexInMap(map)
    end
    if not targetIndex or targetIndex <= 0 then
        return nil
    end

    ClearDeletedEntryMarker(classID, specID, entry, targetIndex)
    map[targetIndex] = entry
    return BuildEntryKey(classID, specID, targetIndex), targetIndex
end

function Processor:BuildEntryExportRecord(classID, specID, index)
    local api = GetApi()
    if not api then
        return nil
    end
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == ALL_CLASSES_ID then
        specID = ALL_SPECS_ID
    end
    index = tonumber(index) or 0
    if classID < 0 or specID < 0 or index <= 0 then
        return nil
    end
    local map = api.GetStoredEntryMap(classID, specID)
    local entry = api.GetEntry(map, index)
    if not entry then
        return nil
    end

    local exportEntry = SanitizeEntryForImport(entry)
    if not exportEntry then
        return nil
    end

    return {
        classID = classID,
        specID = specID,
        index = index,
        entry = exportEntry,
    }
end
