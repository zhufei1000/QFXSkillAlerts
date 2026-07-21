local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoicePresetStore = NS.Core.CDMVoicePresetStore or {}

local Store = NS.Core.CDMVoicePresetStore
local Registry = NS.Core.CDMVoiceRegistry
local Utils = NS.Utils or {}

local VALID_CATEGORIES = {
    essential = true,
    utility = true,
    trackedBuff = true,
    trackedBar = true,
}

local EVENT_DEFS = {
    { key = "AVAILABLE", enumNames = { "Available" } },
    { key = "PANDEMIC_TIME", enumNames = { "PandemicTime" } },
    { key = "ON_COOLDOWN", enumNames = { "OnCooldown", "CooldownStarted" } },
    { key = "CHARGE_GAINED", enumNames = { "ChargeGained" } },
    { key = "AURA_APPLIED", enumNames = { "OnAuraApplied", "AuraApplied" } },
    { key = "AURA_REMOVED", enumNames = { "OnAuraRemoved", "AuraRemoved" } },
}

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function CanonicalPath(value)
    if type(Utils.CanonicalPath) == "function" then
        return Utils.CanonicalPath(value)
    end
    return (Trim(value):gsub("/", "\\"))
end

local function EnsureDatabase()
    QFXSkillAlertsDB = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or {}
    local db = QFXSkillAlertsDB
    db.cdmVoiceProfiles = type(db.cdmVoiceProfiles) == "table" and db.cdmVoiceProfiles or {}
    db.cdmVoiceDisabledPresets = type(db.cdmVoiceDisabledPresets) == "table" and db.cdmVoiceDisabledPresets or {}
    db.cdmVoiceSyncState = type(db.cdmVoiceSyncState) == "table" and db.cdmVoiceSyncState or {}
    db.cdmVoiceSyncState.importedVersion = tonumber(db.cdmVoiceSyncState.importedVersion) or 0
    if db.cdmVoiceSyncState.pendingRuntimeReload == nil then
        db.cdmVoiceSyncState.pendingRuntimeReload = false
    end
    return db
end

local function EnsureScope(root, classID, specID)
    classID, specID = tonumber(classID), tonumber(specID)
    if not classID or not specID then
        return nil
    end
    root[classID] = type(root[classID]) == "table" and root[classID] or {}
    root[classID][specID] = type(root[classID][specID]) == "table" and root[classID][specID] or {}
    return root[classID][specID]
end

local function GetScope(root, classID, specID)
    classID, specID = tonumber(classID), tonumber(specID)
    return type(root) == "table"
        and type(root[classID]) == "table"
        and type(root[classID][specID]) == "table"
        and root[classID][specID] or nil
end

local function CopyRecord(record)
    local copy = {}
    for key, value in pairs(type(record) == "table" and record or {}) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

local function GetAlertValue(alert, functionName, index)
    if type(alert) ~= "table" then
        return nil
    end
    local getter = rawget(_G, functionName)
    if type(getter) == "function" then
        local ok, value = pcall(getter, alert)
        if ok then
            return value
        end
    end
    return alert[index]
end

local function IsSoundAlert(alert)
    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    return soundType ~= nil and GetAlertValue(alert, "CooldownViewerAlert_GetType", 1) == soundType
end

function Store:EventTypeToKey(eventType)
    eventType = tonumber(eventType)
    if not eventType then
        return nil
    end
    local enumTable = Enum and Enum.CooldownViewerAlertEventType
    for _, def in ipairs(EVENT_DEFS) do
        for _, enumName in ipairs(def.enumNames) do
            if type(enumTable) == "table" and tonumber(enumTable[enumName]) == eventType then
                return def.key
            end
        end
    end
    return "EVENT_" .. tostring(math.floor(eventType))
end

function Store:EventKeyToType(eventKey, eventTypeHint)
    eventKey = Trim(eventKey):upper()
    local enumTable = Enum and Enum.CooldownViewerAlertEventType
    for _, def in ipairs(EVENT_DEFS) do
        if eventKey == def.key then
            for _, enumName in ipairs(def.enumNames) do
                local value = type(enumTable) == "table" and tonumber(enumTable[enumName]) or nil
                if value then
                    return value
                end
            end
        end
    end
    local numeric = tonumber(eventKey:match("^EVENT_(-?%d+)$"))
    return numeric or tonumber(eventTypeHint)
end

function Store:BuildRecordKey(category, spellID, eventKey)
    category = Trim(category)
    spellID = tonumber(spellID)
    eventKey = Trim(eventKey):upper()
    if not VALID_CATEGORIES[category] or not spellID or spellID <= 0 or eventKey == "" then
        return nil
    end
    return string.format("%s:%d:%s", category, math.floor(spellID), eventKey)
end

function Store:SanitizeRecord(data, forcedSource)
    if type(data) ~= "table" then
        return nil
    end
    local classID = tonumber(data.classID)
    local specID = tonumber(data.specID)
    local category = Trim(data.category)
    local spellID = tonumber(data.spellID)
    local eventKey = Trim(data.eventKey):upper()
    if eventKey == "" then
        eventKey = self:EventTypeToKey(data.eventTypeHint)
    end
    local eventTypeHint = self:EventKeyToType(eventKey, data.eventTypeHint)
    local voiceName = Trim(data.voiceName)
    local voicePath = CanonicalPath(data.voicePath)
    local voiceIdentity = Trim(data.voiceIdentity):lower()
    if voiceIdentity == "" and Registry and type(Registry.BuildIdentity) == "function" then
        voiceIdentity = Registry:BuildIdentity(voiceName, voicePath) or ""
    end
    local recordKey = self:BuildRecordKey(category, spellID, eventKey)
    if not classID or not specID or not recordKey or not eventTypeHint
        or (voiceIdentity == "" and voiceName == "" and voicePath == "") then
        return nil
    end
    return {
        version = 1,
        classID = math.floor(classID),
        specID = math.floor(specID),
        category = category,
        spellID = math.floor(spellID),
        eventKey = eventKey,
        eventTypeHint = math.floor(eventTypeHint),
        voiceIdentity = voiceIdentity,
        voiceName = voiceName,
        voicePath = voicePath,
        cooldownIDHint = tonumber(data.cooldownIDHint),
        payloadHint = tonumber(data.payloadHint),
        source = Trim(forcedSource or data.source or "user"),
        enabled = data.enabled ~= false,
        recordKey = recordKey,
    }
end

function Store:SaveAppliedRecord(data)
    data = CopyRecord(type(data) == "table" and data or {})
    data.pendingApply = nil
    local record = self:SanitizeRecord(data, data.source or "user")
    if not record then
        return nil, "invalid_record"
    end
    local db = EnsureDatabase()
    local scope = EnsureScope(db.cdmVoiceProfiles, record.classID, record.specID)
    scope[record.recordKey] = record
    local disabled = GetScope(db.cdmVoiceDisabledPresets, record.classID, record.specID)
    if disabled then
        disabled[record.recordKey] = nil
    end
    return record.recordKey, record
end

function Store:GetUserRecords(classID, specID)
    return GetScope(EnsureDatabase().cdmVoiceProfiles, classID, specID) or {}
end

function Store:GetBuiltInRecords(classID, specID)
    return GetScope(NS.CDMVoiceBuiltInPresets or {}, classID, specID) or {}
end

function Store:IsBuiltInRecord(classID, specID, recordKey)
    return type(self:GetBuiltInRecords(classID, specID)[recordKey]) == "table"
end

function Store:GetEffectiveRecords(classID, specID)
    local db = EnsureDatabase()
    local resultByKey = {}
    local disabled = GetScope(db.cdmVoiceDisabledPresets, classID, specID) or {}
    for recordKey, data in pairs(self:GetBuiltInRecords(classID, specID)) do
        if disabled[recordKey] ~= true then
            local record = self:SanitizeRecord(data, "builtIn")
            if record and record.enabled then
                resultByKey[recordKey] = record
            end
        end
    end
    for recordKey, data in pairs(self:GetUserRecords(classID, specID)) do
        local record = self:SanitizeRecord(data, data.source or "user")
        if record and record.enabled then
            resultByKey[recordKey] = record
        else
            resultByKey[recordKey] = nil
        end
    end
    local result = {}
    for _, record in pairs(resultByKey) do
        result[#result + 1] = CopyRecord(record)
    end
    table.sort(result, function(left, right)
        return tostring(left.recordKey) < tostring(right.recordKey)
    end)
    return result
end

function Store:GetEffectiveRecord(classID, specID, recordKey)
    recordKey = Trim(recordKey)
    if recordKey == "" then
        return nil
    end
    for _, record in ipairs(self:GetEffectiveRecords(classID, specID)) do
        if record.recordKey == recordKey then
            return CopyRecord(record)
        end
    end
    return nil
end

function Store:BuildSingleRecordProfiles(classID, specID, recordKey)
    classID, specID = tonumber(classID), tonumber(specID)
    local record = self:GetEffectiveRecord(classID, specID, recordKey)
    if not classID or not specID or not record then
        return nil
    end
    local result = {}
    local scope = EnsureScope(result, classID, specID)
    local exported = CopyRecord(record)
    exported.pendingApply = nil
    scope[record.recordKey] = exported
    return result
end

function Store:RemoveOrDisableRecord(classID, specID, recordKey)
    classID, specID = tonumber(classID), tonumber(specID)
    recordKey = Trim(recordKey)
    local effective = self:GetEffectiveRecord(classID, specID, recordKey)
    if not classID or not specID or recordKey == "" or not effective then
        return nil, "not_found"
    end
    local db = EnsureDatabase()
    local userScope = GetScope(db.cdmVoiceProfiles, classID, specID)
    local disabledScope = GetScope(db.cdmVoiceDisabledPresets, classID, specID)
    local snapshot = {
        classID = classID,
        specID = specID,
        recordKey = recordKey,
        record = CopyRecord(effective),
        userRecord = userScope and userScope[recordKey] and CopyRecord(userScope[recordKey]) or nil,
        disabledValue = disabledScope and disabledScope[recordKey] or nil,
    }
    if userScope then
        userScope[recordKey] = nil
    end
    if self:IsBuiltInRecord(classID, specID, recordKey) then
        EnsureScope(db.cdmVoiceDisabledPresets, classID, specID)[recordKey] = true
    end
    return snapshot
end

function Store:RestoreRecordMutation(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end
    local classID, specID = tonumber(snapshot.classID), tonumber(snapshot.specID)
    local recordKey = Trim(snapshot.recordKey)
    if not classID or not specID or recordKey == "" then
        return false
    end
    local db = EnsureDatabase()
    local userScope = EnsureScope(db.cdmVoiceProfiles, classID, specID)
    userScope[recordKey] = snapshot.userRecord and CopyRecord(snapshot.userRecord) or nil
    local disabledScope = EnsureScope(db.cdmVoiceDisabledPresets, classID, specID)
    disabledScope[recordKey] = snapshot.disabledValue
    return true
end

function Store:GetAllProfilesForExport()
    local result = {}
    for classID, classMap in pairs(EnsureDatabase().cdmVoiceProfiles) do
        if type(classMap) == "table" then
            for specID, specMap in pairs(classMap) do
                if type(specMap) == "table" then
                    for _, data in pairs(specMap) do
                        local record = self:SanitizeRecord(data, data.source or "user")
                        if record then
                            local scope = EnsureScope(result, classID, specID)
                            record.pendingApply = nil
                            scope[record.recordKey] = record
                        end
                    end
                end
            end
        end
    end
    return result
end

function Store:ResolveVoice(record)
    if type(record) ~= "table" or not Registry then
        return nil
    end
    local wantedIdentity = Trim(record.voiceIdentity):lower()
    local wantedPath = CanonicalPath(record.voicePath):lower()
    local wantedName = Trim(record.voiceName):lower()
    local pathMatch, nameMatch
    for _, item in ipairs(Registry:GetItems() or {}) do
        if wantedIdentity ~= "" and tostring(item.identity or ""):lower() == wantedIdentity then
            return item, "identity"
        end
        if not pathMatch and wantedPath ~= "" and CanonicalPath(item.path):lower() == wantedPath then
            pathMatch = item
        end
        if not nameMatch and wantedName ~= "" and Trim(item.name):lower() == wantedName then
            nameMatch = item
        end
    end
    if pathMatch then
        return pathMatch, "path"
    end
    if nameMatch then
        return nameMatch, "name"
    end
    return nil
end

function Store:CaptureCurrentSpecFromLayout()
    local service = NS.Core and NS.Core.CDMVoiceService
    if not service then
        return 0
    end
    local classID, specID = service:GetCurrentClassSpec()
    if not classID or not specID then
        return 0
    end
    local captured = 0
    for _, category in ipairs(service:GetCategories() or {}) do
        for _, info in ipairs(service:GetCooldownsForCategory(category.key) or {}) do
            for _, alert in ipairs(service:GetAlerts(info.cooldownID) or {}) do
                local payload = tonumber(GetAlertValue(alert, "CooldownViewerAlert_GetPayload", 3))
                if IsSoundAlert(alert) and payload and Registry and Registry:IsOwnedPayload(payload) then
                    local item = Registry:GetItemForPayload(payload)
                    local eventType = tonumber(GetAlertValue(alert, "CooldownViewerAlert_GetEvent", 2))
                    if item and eventType then
                        local eventKey = self:EventTypeToKey(eventType)
                        local key = self:SaveAppliedRecord({
                            classID = classID,
                            specID = specID,
                            category = category.key,
                            spellID = info.spellID,
                            eventKey = eventKey,
                            eventTypeHint = eventType,
                            voiceIdentity = item.identity,
                            voiceName = item.name,
                            voicePath = item.path,
                            cooldownIDHint = info.cooldownID,
                            payloadHint = payload,
                            source = "user",
                        })
                        if key then
                            captured = captured + 1
                        end
                    end
                end
            end
        end
    end
    return captured
end

function Store:RemoveRecord(classID, specID, recordKey)
    local db = EnsureDatabase()
    local scope = GetScope(db.cdmVoiceProfiles, classID, specID)
    local removed = scope and scope[recordKey] ~= nil or false
    if scope then
        scope[recordKey] = nil
    end
    return removed
end

function Store:DisableBuiltInRecord(classID, specID, recordKey)
    if not self:IsBuiltInRecord(classID, specID, recordKey) then
        return false
    end
    local scope = EnsureScope(EnsureDatabase().cdmVoiceDisabledPresets, classID, specID)
    scope[recordKey] = true
    return true
end

function Store:GetRecordForAlert(classID, specID, category, spellID, eventType)
    local eventKey = self:EventTypeToKey(eventType)
    local recordKey = self:BuildRecordKey(category, spellID, eventKey)
    if not recordKey then
        return nil
    end
    local user = self:GetUserRecords(classID, specID)[recordKey]
    if type(user) == "table" then
        return user, recordKey, "user"
    end
    local builtIn = self:GetBuiltInRecords(classID, specID)[recordKey]
    if type(builtIn) == "table" then
        return builtIn, recordKey, "builtIn"
    end
    return nil, recordKey
end

function Store:ImportProfiles(profiles)
    local imported = 0
    for classID, classMap in pairs(type(profiles) == "table" and profiles or {}) do
        for specID, specMap in pairs(type(classMap) == "table" and classMap or {}) do
            for _, data in pairs(type(specMap) == "table" and specMap or {}) do
                local copy = CopyRecord(data)
                copy.classID = tonumber(copy.classID) or tonumber(classID)
                copy.specID = tonumber(copy.specID) or tonumber(specID)
                copy.source = "import"
                if self:SaveAppliedRecord(copy) then
                    imported = imported + 1
                end
            end
        end
    end
    return imported
end

function Store:GetSyncState()
    return EnsureDatabase().cdmVoiceSyncState
end
