local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS
NS.Core = NS.Core or {}

local Migration = NS.Core.LegacyDatabaseMigration or {}
NS.Core.LegacyDatabaseMigration = Migration

local MIGRATION_VERSION = 20260711
local LEGACY_ADDON_ROOT = "Interface\\AddOns\\MCDVoiceCooldown\\"
local CURRENT_ADDON_ROOT = "Interface\\AddOns\\QFXSkillAlerts\\"

local function ReplacePlain(text, oldValue, newValue)
    text = tostring(text or "")
    local parts = {}
    local startIndex = 1
    while true do
        local firstIndex, lastIndex = text:find(oldValue, startIndex, true)
        if not firstIndex then
            parts[#parts + 1] = text:sub(startIndex)
            break
        end
        parts[#parts + 1] = text:sub(startIndex, firstIndex - 1)
        parts[#parts + 1] = newValue
        startIndex = lastIndex + 1
    end
    return table.concat(parts)
end

local function DeepCopy(value, seen)
    local valueType = type(value)
    if valueType == "string" then
        return ReplacePlain(value, LEGACY_ADDON_ROOT, CURRENT_ADDON_ROOT)
    end
    if valueType ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[key] = DeepCopy(child, seen)
    end
    return copy
end

local function CopyMissing(target, source, visited)
    if type(target) ~= "table" or type(source) ~= "table" or target == source then
        return
    end
    visited = visited or {}
    if visited[source] then
        return
    end
    visited[source] = true

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = DeepCopy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            CopyMissing(target[key], value, visited)
        end
    end
end

local function NormalizeClassSpec(classID, specID)
    classID = tonumber(classID) or 0
    specID = tonumber(specID) or 0
    if classID == 0 then
        specID = 0
    end
    return classID, specID
end

local function NormalizeEntryType(value)
    value = tostring(value or "cooldown")
    if value == "cast" then
        return "cast"
    end
    return "cooldown"
end

local function NormalizeObjectType(value)
    value = tostring(value or "spell"):lower()
    if value == "item" then
        return "item"
    end
    return "spell"
end

local function BuildEntryKey(classID, specID, index)
    classID, specID = NormalizeClassSpec(classID, specID)
    return tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(tonumber(index) or 0)
end

local function ParseEntryKey(value)
    local classID, specID, index = tostring(value or ""):match("^(%-?%d+):(%-?%d+):(%-?%d+)$")
    return tonumber(classID), tonumber(specID), tonumber(index)
end

local function BuildGroupKey(classID, specID, groupID)
    classID, specID = NormalizeClassSpec(classID, specID)
    return "group:" .. tostring(classID) .. ":" .. tostring(specID) .. ":" .. tostring(groupID or "")
end

local function ParseGroupKey(value)
    local classID, specID, groupID = tostring(value or ""):match("^group:(%-?%d+):(%-?%d+):(.+)$")
    return tonumber(classID), tonumber(specID), groupID
end

local function BuildEntrySignature(classID, specID, entry)
    if type(entry) ~= "table" then
        return nil
    end
    classID, specID = NormalizeClassSpec(classID, specID)
    local spellID = tonumber(entry.spellId or entry.itemID) or 0
    if classID < 0 or specID < 0 or spellID <= 0 then
        return nil
    end
    return table.concat({
        tostring(classID),
        tostring(specID),
        NormalizeEntryType(entry.entryType),
        NormalizeObjectType(entry.objectType),
        tostring(math.floor(spellID)),
    }, ":")
end

local function CountEntries(db)
    local count = 0
    for _, classMap in pairs(type(db) == "table" and db.specConfigs or {}) do
        if type(classMap) == "table" then
            for _, entryMap in pairs(classMap) do
                if type(entryMap) == "table" then
                    for _, entry in pairs(entryMap) do
                        if type(entry) == "table" and (tonumber(entry.spellId or entry.itemID) or 0) > 0 then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

local function HasLegacyData(db)
    if type(db) ~= "table" then
        return false
    end
    if CountEntries(db) > 0 then
        return true
    end
    for _, key in ipairs({ "castSuccessConfigs", "collectionData", "bloodlustConfig", "minimap", "savedListOrder" }) do
        if type(db[key]) == "table" and next(db[key]) ~= nil then
            return true
        end
    end
    return false
end

local function EnsureEntryMap(db, classID, specID)
    classID, specID = NormalizeClassSpec(classID, specID)
    db.specConfigs = type(db.specConfigs) == "table" and db.specConfigs or {}
    db.specConfigs[classID] = type(db.specConfigs[classID]) == "table" and db.specConfigs[classID] or {}
    db.specConfigs[classID][specID] = type(db.specConfigs[classID][specID]) == "table" and db.specConfigs[classID][specID] or {}
    return db.specConfigs[classID][specID], classID, specID
end

local function FindMatchingIndex(entryMap, entry)
    local spellID = tonumber(entry and (entry.spellId or entry.itemID)) or 0
    local entryType = NormalizeEntryType(entry and entry.entryType)
    local objectType = NormalizeObjectType(entry and entry.objectType)
    for index, current in pairs(type(entryMap) == "table" and entryMap or {}) do
        if type(current) == "table"
            and (tonumber(current.spellId or current.itemID) or 0) == spellID
            and NormalizeEntryType(current.entryType) == entryType
            and NormalizeObjectType(current.objectType) == objectType then
            return tonumber(index) or 0
        end
    end
    return nil
end

local function FindFreeIndex(entryMap, preferredIndex)
    preferredIndex = tonumber(preferredIndex) or 0
    if preferredIndex > 0 and type(entryMap[preferredIndex]) ~= "table" then
        return preferredIndex
    end
    for index = 1, 999 do
        if type(entryMap[index]) ~= "table" then
            return index
        end
    end
    return nil
end

local function IsDeletedInCurrentDB(db, classID, specID, entry)
    local signature = BuildEntrySignature(classID, specID, entry)
    local signatures = type(db.deletedEntries) == "table" and db.deletedEntries.signatures or nil
    return signature and type(signatures) == "table" and signatures[signature] == true
end

local function MergeEntryRoot(working, sourceRoot, forcedEntryType, keyMap, stats)
    if type(sourceRoot) ~= "table" then
        return
    end

    for classIDKey, classMap in pairs(sourceRoot) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            for specIDKey, sourceMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(sourceMap) == "table" then
                    local targetMap, normalizedClassID, normalizedSpecID = EnsureEntryMap(working, classID, specID)
                    for oldIndexKey, oldEntry in pairs(sourceMap) do
                        local oldIndex = tonumber(oldIndexKey) or 0
                        if oldIndex > 0 and type(oldEntry) == "table" then
                            local entry = DeepCopy(oldEntry)
                            if forcedEntryType then
                                entry.entryType = forcedEntryType
                            end
                            local spellID = tonumber(entry.spellId or entry.itemID) or 0
                            if spellID > 0 then
                                stats.sourceEntries = stats.sourceEntries + 1
                                local oldKey = BuildEntryKey(normalizedClassID, normalizedSpecID, oldIndex)
                                local matchingIndex = FindMatchingIndex(targetMap, entry)
                                if matchingIndex and matchingIndex > 0 then
                                    keyMap[oldKey] = BuildEntryKey(normalizedClassID, normalizedSpecID, matchingIndex)
                                    stats.duplicates = stats.duplicates + 1
                                elseif IsDeletedInCurrentDB(working, normalizedClassID, normalizedSpecID, entry) then
                                    stats.skippedDeleted = stats.skippedDeleted + 1
                                else
                                    local targetIndex = FindFreeIndex(targetMap, oldIndex)
                                    if not targetIndex then
                                        error("no free entry index for " .. oldKey)
                                    end
                                    targetMap[targetIndex] = entry
                                    keyMap[oldKey] = BuildEntryKey(normalizedClassID, normalizedSpecID, targetIndex)
                                    stats.addedEntries = stats.addedEntries + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function EnsureCollectionScope(db, classID, specID)
    classID, specID = NormalizeClassSpec(classID, specID)
    db.collectionData = type(db.collectionData) == "table" and db.collectionData or {}
    db.collectionData[classID] = type(db.collectionData[classID]) == "table" and db.collectionData[classID] or {}
    db.collectionData[classID][specID] = type(db.collectionData[classID][specID]) == "table" and db.collectionData[classID][specID] or {}
    local scope = db.collectionData[classID][specID]
    scope.root = type(scope.root) == "table" and scope.root or {}
    scope.groups = type(scope.groups) == "table" and scope.groups or {}
    return scope, classID, specID
end

local function FindGroupByName(scope, name)
    name = tostring(name or "")
    if name == "" then
        return nil
    end
    for groupID, group in pairs(scope.groups or {}) do
        if type(group) == "table" and tostring(group.name or "") == name then
            return tostring(groupID)
        end
    end
    return nil
end

local function AllocateGroupID(db, scope, requestedID)
    requestedID = tostring(requestedID or "")
    if requestedID ~= "" and type(scope.groups[requestedID]) ~= "table" then
        return requestedID
    end
    repeat
        db.collectionSerial = (tonumber(db.collectionSerial) or 0) + 1
        requestedID = "legacy" .. tostring(db.collectionSerial)
    until type(scope.groups[requestedID]) ~= "table"
    return requestedID
end

local function MapCollectionReference(value, scopeClassID, scopeSpecID, keyMap, groupMap)
    if type(value) == "number" then
        return keyMap[BuildEntryKey(scopeClassID, scopeSpecID, value)]
    end
    local text = tostring(value or "")
    local groupClassID, groupSpecID, groupID = ParseGroupKey(text)
    if groupID then
        return groupMap[BuildGroupKey(groupClassID, groupSpecID, groupID)]
    end
    local classID, specID, index = ParseEntryKey(text)
    if classID and specID and index then
        return keyMap[BuildEntryKey(classID, specID, index)]
    end
    index = tonumber(text)
    if index and index > 0 then
        return keyMap[BuildEntryKey(scopeClassID, scopeSpecID, index)]
    end
    return nil
end

local function CollectScopeReferences(scope, classID, specID)
    local seen = {}
    for _, item in ipairs(scope.root or {}) do
        if type(item) == "table" and item.type == "entry" then
            seen[BuildEntryKey(classID, specID, item.index)] = true
        elseif type(item) == "table" and item.type == "group" then
            seen[BuildGroupKey(classID, specID, item.id)] = true
        end
    end
    for _, group in pairs(scope.groups or {}) do
        if type(group) == "table" then
            for _, value in ipairs(group.entries or {}) do
                seen[tostring(value)] = true
            end
        end
    end
    return seen
end

local function MergeCollections(working, source, keyMap, groupMap, stats)
    if type(source.collectionData) ~= "table" then
        return
    end

    for classIDKey, classMap in pairs(source.collectionData) do
        local classID = tonumber(classIDKey)
        if classID and classID >= 0 and type(classMap) == "table" then
            for specIDKey, oldScope in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and specID >= 0 and type(oldScope) == "table" then
                    local newScope, normalizedClassID, normalizedSpecID = EnsureCollectionScope(working, classID, specID)

                    for oldGroupID, oldGroup in pairs(type(oldScope.groups) == "table" and oldScope.groups or {}) do
                        if type(oldGroup) == "table" then
                            oldGroupID = tostring(oldGroupID)
                            local newGroupID = FindGroupByName(newScope, oldGroup.name)
                            if not newGroupID then
                                newGroupID = AllocateGroupID(working, newScope, oldGroupID)
                                local groupCopy = DeepCopy(oldGroup)
                                groupCopy.entries = {}
                                newScope.groups[newGroupID] = groupCopy
                                stats.addedGroups = stats.addedGroups + 1
                            else
                                CopyMissing(newScope.groups[newGroupID], oldGroup)
                                newScope.groups[newGroupID].entries = type(newScope.groups[newGroupID].entries) == "table" and newScope.groups[newGroupID].entries or {}
                            end
                            groupMap[BuildGroupKey(normalizedClassID, normalizedSpecID, oldGroupID)] = BuildGroupKey(normalizedClassID, normalizedSpecID, newGroupID)
                        end
                    end

                    local seen = CollectScopeReferences(newScope, normalizedClassID, normalizedSpecID)
                    for oldGroupID, oldGroup in pairs(type(oldScope.groups) == "table" and oldScope.groups or {}) do
                        local mappedGroupKey = groupMap[BuildGroupKey(normalizedClassID, normalizedSpecID, oldGroupID)]
                        local _, _, newGroupID = ParseGroupKey(mappedGroupKey)
                        local targetGroup = newGroupID and newScope.groups[newGroupID] or nil
                        if type(oldGroup) == "table" and type(targetGroup) == "table" then
                            for _, value in ipairs(oldGroup.entries or {}) do
                                local mapped = MapCollectionReference(value, normalizedClassID, normalizedSpecID, keyMap, groupMap)
                                if mapped and not seen[mapped] then
                                    targetGroup.entries[#targetGroup.entries + 1] = mapped
                                    seen[mapped] = true
                                    stats.addedCollectionRefs = stats.addedCollectionRefs + 1
                                end
                            end
                        end
                    end

                    for _, item in ipairs(type(oldScope.root) == "table" and oldScope.root or {}) do
                        if type(item) == "table" and item.type == "entry" then
                            local mapped = keyMap[BuildEntryKey(normalizedClassID, normalizedSpecID, item.index)]
                            local _, _, mappedIndex = ParseEntryKey(mapped)
                            if mapped and mappedIndex and mappedIndex > 0 and not seen[mapped] then
                                newScope.root[#newScope.root + 1] = { type = "entry", index = mappedIndex }
                                seen[mapped] = true
                                stats.addedCollectionRefs = stats.addedCollectionRefs + 1
                            end
                        elseif type(item) == "table" and item.type == "group" then
                            local mapped = groupMap[BuildGroupKey(normalizedClassID, normalizedSpecID, item.id)]
                            local _, _, mappedGroupID = ParseGroupKey(mapped)
                            if mapped and mappedGroupID and not seen[mapped] then
                                newScope.root[#newScope.root + 1] = { type = "group", id = mappedGroupID }
                                seen[mapped] = true
                                stats.addedCollectionRefs = stats.addedCollectionRefs + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

local function MergeSavedListOrder(working, source, keyMap, groupMap)
    working.savedListOrder = type(working.savedListOrder) == "table" and working.savedListOrder or { loaded = {}, unloaded = {} }
    for _, listName in ipairs({ "loaded", "unloaded" }) do
        local targetList = type(working.savedListOrder[listName]) == "table" and working.savedListOrder[listName] or {}
        working.savedListOrder[listName] = targetList
        local seen = {}
        for _, value in ipairs(targetList) do
            seen[tostring(value)] = true
        end
        local sourceList = type(source.savedListOrder) == "table" and source.savedListOrder[listName] or nil
        for _, value in ipairs(type(sourceList) == "table" and sourceList or {}) do
            local mapped = groupMap[tostring(value)] or keyMap[tostring(value)]
            if mapped and not seen[mapped] then
                targetList[#targetList + 1] = mapped
                seen[mapped] = true
            end
        end
    end
end

local function MergeSettings(working, source, targetWasFresh)
    for _, key in ipairs({ "bloodlustConfig", "minimap" }) do
        if type(source[key]) == "table" then
            if targetWasFresh then
                working[key] = DeepCopy(source[key])
            else
                working[key] = type(working[key]) == "table" and working[key] or {}
                CopyMissing(working[key], source[key])
            end
        end
    end
    for _, key in ipairs({ "languageMode", "uiSkinMode" }) do
        if targetWasFresh and source[key] ~= nil then
            working[key] = source[key]
        elseif working[key] == nil and source[key] ~= nil then
            working[key] = source[key]
        end
    end
    if targetWasFresh and type(source.deletedEntries) == "table" then
        working.deletedEntries = DeepCopy(source.deletedEntries)
    end
    working.collectionSerial = math.max(tonumber(working.collectionSerial) or 0, tonumber(source.collectionSerial) or 0)
end

local function CommitInPlace(target, source)
    for key in pairs(target) do
        target[key] = nil
    end
    for key, value in pairs(source) do
        target[key] = value
    end
end

function Migration:GetVersion()
    return MIGRATION_VERSION
end

function Migration:Migrate(legacyDB, currentDB)
    if type(currentDB) ~= "table" then
        return false, { error = "QFXSkillAlertsDB is unavailable" }
    end
    if (tonumber(currentDB.legacyDatabaseMigrationVersion) or 0) >= MIGRATION_VERSION then
        return true, { alreadyComplete = true, addedEntries = 0, sourceEntries = 0 }
    end

    local source = type(legacyDB) == "table" and (type(legacyDB.profile) == "table" and legacyDB.profile or legacyDB) or nil
    local stats = {
        sourceEntries = 0,
        addedEntries = 0,
        duplicates = 0,
        skippedDeleted = 0,
        addedGroups = 0,
        addedCollectionRefs = 0,
        hadLegacyData = HasLegacyData(source),
    }

    local ok, resultOrError = xpcall(function()
        local working = DeepCopy(currentDB)
        local countBefore = CountEntries(working)
        local targetWasFresh = countBefore == 0

        if stats.hadLegacyData then
            local keyMap = {}
            local groupMap = {}
            MergeSettings(working, source, targetWasFresh)
            MergeEntryRoot(working, source.specConfigs, nil, keyMap, stats)
            MergeEntryRoot(working, source.castSuccessConfigs, "cast", keyMap, stats)
            MergeCollections(working, source, keyMap, groupMap, stats)
            MergeSavedListOrder(working, source, keyMap, groupMap)
        end

        local countAfter = CountEntries(working)
        if countAfter ~= countBefore + stats.addedEntries then
            error("entry count validation failed")
        end

        working.legacyDatabaseMigrationVersion = MIGRATION_VERSION
        working.legacyDatabaseMigration = {
            completed = true,
            sourceEntries = stats.sourceEntries,
            addedEntries = stats.addedEntries,
            duplicates = stats.duplicates,
            skippedDeleted = stats.skippedDeleted,
            hadLegacyData = stats.hadLegacyData,
        }
        if type(time) == "function" then
            working.legacyDatabaseMigration.completedAt = time()
        end

        CommitInPlace(currentDB, working)
        stats.countBefore = countBefore
        stats.countAfter = countAfter
        return stats
    end, function(err)
        return tostring(err or "unknown migration error")
    end)

    if not ok then
        return false, { error = resultOrError }
    end
    return true, resultOrError
end

