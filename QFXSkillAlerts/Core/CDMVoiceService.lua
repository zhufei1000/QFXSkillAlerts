local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceService = NS.Core.CDMVoiceService or {}

local Service = NS.Core.CDMVoiceService
local Registry = NS.Core.CDMVoiceRegistry

Service.refreshSerial = Service.refreshSerial or 0
Service.cdmMutationDepth = tonumber(Service.cdmMutationDepth) or 0
Service.cooldownCacheGeneration = tonumber(Service.cooldownCacheGeneration) or 0
Service.cooldownCategoryCache = Service.cooldownCategoryCache or {}
Service.cooldownInfoCache = Service.cooldownInfoCache or {}
Service.validEventsCache = Service.validEventsCache or {}

local function ClearCache(values)
    for key in pairs(type(values) == "table" and values or {}) do
        values[key] = nil
    end
end

local CATEGORY_DEFS = {
    { key = "essential", enumKey = "Essential", localeKey = "CDM_CATEGORY_ESSENTIAL" },
    { key = "utility", enumKey = "Utility", localeKey = "CDM_CATEGORY_UTILITY" },
    { key = "trackedBuff", enumKey = "TrackedBuff", localeKey = "CDM_CATEGORY_TRACKED_BUFF" },
    { key = "trackedBar", enumKey = "TrackedBar", localeKey = "CDM_CATEGORY_TRACKED_BAR" },
}

local function L(key, ...)
    if type(NS.L) == "function" then
        return NS.L(key, ...)
    end
    return tostring(key)
end

local function IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function IsSuccessStatus(status)
    return tonumber(status) == 0
end

local function GetSoundAlertType()
    return Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
end

local function GetAccessMode(name)
    return Enum and Enum.CDMLayoutMode and Enum.CDMLayoutMode[name]
end

local function GetAlertValue(alert, getter, index)
    if type(alert) ~= "table" then
        return nil
    end
    if type(getter) == "function" then
        local ok, value = pcall(getter, alert)
        if ok then
            return value
        end
    end
    return alert[index]
end

local function GetAlertType(alert)
    return GetAlertValue(alert, CooldownViewerAlert_GetType, 1)
end

local function GetAlertEvent(alert)
    return GetAlertValue(alert, CooldownViewerAlert_GetEvent, 2)
end

local function GetAlertPayload(alert)
    return tonumber(GetAlertValue(alert, CooldownViewerAlert_GetPayload, 3))
end

local function EnsureCooldownViewerLoaded()
    if CooldownViewerSettings and type(CooldownViewerSettings.GetLayoutManager) == "function" then
        return true
    end
    if IsInCombat() then
        return false
    end
    if type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
    elseif type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_CooldownViewer")
    end
    return CooldownViewerSettings ~= nil
        and type(CooldownViewerSettings.GetLayoutManager) == "function"
end

local function GetLayoutManager()
    if not EnsureCooldownViewerLoaded() then
        return nil
    end
    local ok, manager = pcall(CooldownViewerSettings.GetLayoutManager, CooldownViewerSettings)
    if ok and type(manager) == "table" then
        return manager
    end
    return nil
end

local function GetDataProvider()
    if not EnsureCooldownViewerLoaded() then
        return nil
    end
    if type(CooldownViewerSettings.GetDataProvider) == "function" then
        local ok, provider = pcall(CooldownViewerSettings.GetDataProvider, CooldownViewerSettings)
        if ok and type(provider) == "table" then
            return provider
        end
    end
    local manager = GetLayoutManager()
    if manager and type(manager.GetDataProvider) == "function" then
        local ok, provider = pcall(manager.GetDataProvider, manager)
        if ok and type(provider) == "table" then
            return provider
        end
    end
    return nil
end

local function ResolveCategory(category)
    local enumTable = Enum and Enum.CooldownViewerCategory
    if type(enumTable) ~= "table" then
        return nil
    end
    for _, def in ipairs(CATEGORY_DEFS) do
        local enumValue = enumTable[def.enumKey]
        if category == def.key or tonumber(category) == tonumber(enumValue) then
            return enumValue, def
        end
    end
    return nil
end

local function CreateAlert(eventType, payload)
    local soundType = GetSoundAlertType()
    if soundType == nil then
        return nil
    end
    if type(CooldownViewerAlert_Create) == "function" then
        local ok, alert = pcall(CooldownViewerAlert_Create, soundType, eventType, payload)
        if ok and type(alert) == "table" then
            return alert
        end
        return nil
    end
    return { soundType, eventType, payload }
end

local function GetSpellName(spellID)
    if spellID and type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if spellID and type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

local function GetSpellIcon(spellID)
    if spellID and type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function" then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then
            return icon
        end
    end
    if spellID and type(GetSpellTexture) == "function" then
        local ok, icon = pcall(GetSpellTexture, spellID)
        if ok and icon then
            return icon
        end
    end
    return 134400
end

function Service:GetCurrentClassSpec()
    local className, _, classID
    if type(UnitClass) == "function" then
        className, _, classID = UnitClass("player")
    end
    local specIndex = type(GetSpecialization) == "function" and GetSpecialization() or nil
    local specID, specName
    if specIndex and type(GetSpecializationInfo) == "function" then
        specID, specName = GetSpecializationInfo(specIndex)
    end
    return tonumber(classID), tonumber(specID), className, specName
end

function Service:GetLayoutManager()
    return GetLayoutManager()
end

local function EnsureCooldownCacheScope(self)
    local classID, specID = self:GetCurrentClassSpec()
    local scope = tostring(tonumber(classID) or 0) .. ":" .. tostring(tonumber(specID) or 0)
    if self.cooldownCacheScope ~= scope then
        ClearCache(self.cooldownCategoryCache)
        ClearCache(self.cooldownInfoCache)
        ClearCache(self.validEventsCache)
        self.cooldownCacheScope = scope
        self.cooldownCacheGeneration = (tonumber(self.cooldownCacheGeneration) or 0) + 1
    end
    return scope
end

function Service:InvalidateCooldownCache(reason)
    ClearCache(self.cooldownCategoryCache)
    ClearCache(self.cooldownInfoCache)
    ClearCache(self.validEventsCache)
    self.cooldownCacheScope = nil
    self.cooldownCacheReason = tostring(reason or "unknown")
    self.cooldownCacheGeneration = (tonumber(self.cooldownCacheGeneration) or 0) + 1
end

function Service:GetCooldownCacheGeneration()
    EnsureCooldownCacheScope(self)
    return tonumber(self.cooldownCacheGeneration) or 0
end

function Service:BeginCDMMutation(source)
    self.cdmMutationDepth = (tonumber(self.cdmMutationDepth) or 0) + 1
    if self.cdmMutationDepth == 1 then
        self.cdmMutationSource = tostring(source or "qfx")
    end
    return self.cdmMutationDepth
end

function Service:EndCDMMutation()
    self.cdmMutationDepth = math.max(0, (tonumber(self.cdmMutationDepth) or 0) - 1)
    if self.cdmMutationDepth == 0 then
        self.cdmMutationSource = nil
    end
    return self.cdmMutationDepth
end

function Service:IsInternalCDMMutation()
    return (tonumber(self.cdmMutationDepth) or 0) > 0
end

function Service:IsAvailable()
    if type(C_CooldownViewer) ~= "table" or type(C_CooldownViewer.GetValidAlertTypes) ~= "function" then
        return false, "not_available"
    end
    if type(C_CooldownViewer.IsCooldownViewerAvailable) == "function" then
        local ok, available = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
        if not ok or available ~= true then
            return false, "data_not_ready"
        end
    end
    if not EnsureCooldownViewerLoaded() then
        return false, "not_loaded"
    end
    local manager, provider = GetLayoutManager(), GetDataProvider()
    if not manager or not provider
        or type(manager.GetAlerts) ~= "function"
        or type(manager.AddAlert) ~= "function"
        or type(manager.RemoveAlert) ~= "function"
        or type(manager.LockNotifications) ~= "function"
        or type(manager.SaveLayouts) ~= "function"
        or (type(provider.GetOrderedCooldownIDsForCategory) ~= "function"
            and type(provider.GetOrderedCooldownIDs) ~= "function") then
        return false, "data_not_ready"
    end
    local _, specID = self:GetCurrentClassSpec()
    if not specID then
        return false, "no_spec"
    end
    return true
end

function Service:GetCategories()
    local categories = {}
    local enumTable = Enum and Enum.CooldownViewerCategory
    for _, def in ipairs(CATEGORY_DEFS) do
        local enumValue = enumTable and enumTable[def.enumKey]
        if enumValue ~= nil then
            categories[#categories + 1] = {
                key = def.key,
                category = enumValue,
                name = L(def.localeKey),
            }
        end
    end
    return categories
end

function Service:GetCooldownsForCategory(category)
    local categoryValue, def = ResolveCategory(category)
    local provider = GetDataProvider()
    if categoryValue == nil or not provider then
        return {}
    end

    EnsureCooldownCacheScope(self)
    local cacheKey = tostring(categoryValue)
    local cached = self.cooldownCategoryCache[cacheKey]
    if type(cached) == "table" then
        return cached
    end

    local ids
    if type(provider.GetOrderedCooldownIDsForCategory) == "function" then
        local ok, result = pcall(provider.GetOrderedCooldownIDsForCategory, provider, categoryValue, false)
        if ok and type(result) == "table" then
            ids = result
        end
    end
    if type(ids) ~= "table" then
        ids = {}
        if type(provider.GetOrderedCooldownIDs) == "function" then
            local ok, ordered = pcall(provider.GetOrderedCooldownIDs, provider)
            if ok and type(ordered) == "table" then
                for _, cooldownID in ipairs(ordered) do
                    local info = self:GetCooldownInfo(cooldownID)
                    if info and tonumber(info.category) == tonumber(categoryValue) then
                        ids[#ids + 1] = cooldownID
                    end
                end
            end
        end
    end

    local result = {}
    for _, cooldownID in ipairs(ids) do
        local ok, info = pcall(self.GetCooldownInfo, self, cooldownID)
        if ok and type(info) == "table" then
            info.categoryKey = def and def.key or nil
            result[#result + 1] = info
        end
    end
    self.cooldownCategoryCache[cacheKey] = result
    if def and def.key then
        self.cooldownCategoryCache[tostring(def.key)] = result
    end
    return result
end

function Service:GetCooldownInfo(cooldownID)
    cooldownID = tonumber(cooldownID)
    if not cooldownID then
        return nil
    end
    EnsureCooldownCacheScope(self)
    if self.cooldownInfoCache[cooldownID] then
        return self.cooldownInfoCache[cooldownID]
    end
    local provider = GetDataProvider()
    local rawInfo
    if provider and type(provider.GetCooldownInfoForID) == "function" then
        local ok, result = pcall(provider.GetCooldownInfoForID, provider, cooldownID)
        if ok and type(result) == "table" then
            rawInfo = result
        end
    end
    if not rawInfo and type(C_CooldownViewer) == "table" and type(C_CooldownViewer.GetCooldownViewerCooldownInfo) == "function" then
        local ok, result = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
        if ok and type(result) == "table" then
            rawInfo = result
        end
    end
    if not rawInfo then
        return nil
    end

    local spellID = tonumber(rawInfo.overrideTooltipSpellID)
        or tonumber(rawInfo.overrideSpellID)
        or tonumber(rawInfo.spellID)
    local name = GetSpellName(spellID) or L("CDM_UNKNOWN_SKILL", cooldownID)
    local info = {
        cooldownID = cooldownID,
        category = rawInfo.category,
        spellID = spellID,
        baseSpellID = tonumber(rawInfo.spellID),
        overrideSpellID = tonumber(rawInfo.overrideSpellID),
        overrideTooltipSpellID = tonumber(rawInfo.overrideTooltipSpellID),
        linkedSpellIDs = type(rawInfo.linkedSpellIDs) == "table" and rawInfo.linkedSpellIDs or nil,
        spellName = name,
        icon = GetSpellIcon(spellID),
        isKnown = rawInfo.isKnown ~= false,
        rawInfo = rawInfo,
    }
    self.cooldownInfoCache[cooldownID] = info
    return info
end

function Service:GetValidEvents(cooldownID)
    cooldownID = tonumber(cooldownID)
    if not cooldownID or type(C_CooldownViewer) ~= "table" or type(C_CooldownViewer.GetValidAlertTypes) ~= "function" then
        return {}
    end
    EnsureCooldownCacheScope(self)
    if self.validEventsCache[cooldownID] then
        return self.validEventsCache[cooldownID]
    end
    local ok, values = pcall(C_CooldownViewer.GetValidAlertTypes, cooldownID)
    if not ok or type(values) ~= "table" then
        return {}
    end
    local result = {}
    for _, eventType in ipairs(values) do
        eventType = tonumber(eventType)
        if eventType then
            local text
            if type(CooldownViewerAlert_GetEventText) == "function" then
                local textOK, value = pcall(CooldownViewerAlert_GetEventText, eventType)
                if textOK and type(value) == "string" and value ~= "" then
                    text = value
                end
            end
            result[#result + 1] = {
                eventType = eventType,
                name = text or L("CDM_EVENT_FALLBACK", eventType),
            }
        end
    end
    self.validEventsCache[cooldownID] = result
    return result
end

function Service:IsValidEvent(cooldownID, eventType)
    for _, eventInfo in ipairs(self:GetValidEvents(cooldownID)) do
        if tonumber(eventInfo.eventType) == tonumber(eventType) then
            return true
        end
    end
    return false
end

function Service:GetAlerts(cooldownID)
    local manager = GetLayoutManager()
    if not manager or type(manager.GetAlerts) ~= "function" then
        return nil, "data_not_ready"
    end
    local ok, alerts = pcall(manager.GetAlerts, manager, tonumber(cooldownID), GetAccessMode("AccessOnly"))
    if not ok then
        return nil, "read_failed"
    end
    return type(alerts) == "table" and alerts or {}
end

function Service:CanConfigureSound(cooldownID, eventType, payload)
    if not self:GetCooldownInfo(cooldownID) then
        return false, "invalid_cooldown"
    end
    if not self:IsValidEvent(cooldownID, eventType) then
        return false, "invalid_event"
    end
    if not Registry or not Registry:IsOwnedPayload(payload) then
        return false, "invalid_payload"
    end
    if not Registry:IsPayloadAvailable(payload) then
        return false, "invalid_payload"
    end
    local alert = CreateAlert(eventType, payload)
    if not alert then
        return false, "unsupported"
    end
    if type(CooldownViewerAlert_GetAlertStatus) == "function" then
        local ok, status = pcall(CooldownViewerAlert_GetAlertStatus, alert)
        if not ok or not IsSuccessStatus(status) then
            return false, "unsupported"
        end
    end
    return true, alert
end

function Service:GetSoundAlert(cooldownID, eventType)
    local alerts = self:GetAlerts(cooldownID)
    if type(alerts) ~= "table" then
        return nil
    end
    local firstNative
    for _, alert in ipairs(alerts) do
        if GetAlertType(alert) == GetSoundAlertType() and tonumber(GetAlertEvent(alert)) == tonumber(eventType) then
            local payload = GetAlertPayload(alert)
            if Registry and Registry:IsOwnedPayload(payload) then
                return {
                    alert = alert,
                    payload = payload,
                    voiceName = Registry:GetNameForPayload(payload),
                    path = Registry:GetPathForPayload(payload),
                    missing = not Registry:IsPayloadAvailable(payload),
                    isCustom = true,
                }
            end
            firstNative = firstNative or alert
        end
    end
    if firstNative then
        return {
            alert = firstNative,
            payload = GetAlertPayload(firstNative),
            isCustom = false,
            hasNative = true,
        }
    end
    return nil
end

function Service:FindCategoryForCooldown(cooldownID)
    cooldownID = tonumber(cooldownID)
    for _, category in ipairs(self:GetCategories()) do
        for _, info in ipairs(self:GetCooldownsForCategory(category.key)) do
            if tonumber(info.cooldownID) == cooldownID then
                return category.key, category.category
            end
        end
    end
    return nil
end

local function NewBatchSummary(seed)
    local summary = {
        added = 0,
        replaced = 0,
        deduplicated = 0,
        duplicateRemoved = 0,
        alreadyLoaded = 0,
        missingSkill = 0,
        missingVoice = 0,
        unsupportedEvent = 0,
        ambiguousSkill = 0,
        failed = 0,
        removed = 0,
    }
    for key in pairs(summary) do
        summary[key] = tonumber(type(seed) == "table" and seed[key]) or 0
    end
    return summary
end

local function ReadManagerAlerts(manager, cooldownID)
    if type(manager) ~= "table" or type(manager.GetAlerts) ~= "function" then
        return nil, "data_not_ready"
    end
    local ok, alerts = pcall(manager.GetAlerts, manager, tonumber(cooldownID), GetAccessMode("AccessOnly"))
    if not ok then
        return nil, "read_failed"
    end
    return type(alerts) == "table" and alerts or {}
end

local function GetEventSounds(manager, cooldownID, eventType, payload)
    local alerts, reason = ReadManagerAlerts(manager, cooldownID)
    if type(alerts) ~= "table" then
        return nil, nil, reason
    end
    local matching, targetCount = {}, 0
    for _, alert in ipairs(alerts) do
        if GetAlertType(alert) == GetSoundAlertType()
            and tonumber(GetAlertEvent(alert)) == tonumber(eventType) then
            matching[#matching + 1] = alert
            if tonumber(GetAlertPayload(alert)) == tonumber(payload) then
                targetCount = targetCount + 1
            end
        end
    end
    return matching, targetCount
end

local function ManagerCallSucceeded(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, status = pcall(fn, ...)
    if not ok or status == false then
        return false
    end
    if type(status) == "number" and not IsSuccessStatus(status) then
        return false
    end
    return true
end

local function AddAlertSucceeded(manager, cooldownID, alert)
    local ok, status = pcall(manager.AddAlert, manager, cooldownID, alert)
    return ok and (status == true or (type(status) == "number" and IsSuccessStatus(status)))
end

local function PairKey(cooldownID, eventType)
    return tostring(tonumber(cooldownID) or "") .. ":" .. tostring(tonumber(eventType) or "")
end

local function CopyEquivalentCooldownIDs(values)
    local result, seen = {}, {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        value = tonumber(value)
        if value and not seen[value] then
            seen[value] = true
            result[#result + 1] = value
        end
    end
    return result
end

local function CopyApplyPlan(plan, includeTargetAlert)
    local copy = {}
    for _, operation in ipairs(type(plan) == "table" and plan or {}) do
        copy[#copy + 1] = {
            kind = operation.kind,
            action = operation.action,
            classID = tonumber(operation.classID),
            specID = tonumber(operation.specID),
            cooldownID = tonumber(operation.cooldownID),
            eventType = tonumber(operation.eventType),
            payload = tonumber(operation.payload),
            recordKey = operation.recordKey,
            runtimeKey = operation.runtimeKey,
            category = operation.category,
            spellID = tonumber(operation.spellID),
            eventKey = operation.eventKey,
            equivalentCooldownIDs = CopyEquivalentCooldownIDs(operation.equivalentCooldownIDs),
            targetAlert = includeTargetAlert and operation.targetAlert or nil,
        }
    end
    return copy
end

local function StablePlanSignature(plan)
    local parts = {}
    for _, operation in ipairs(CopyApplyPlan(plan)) do
        parts[#parts + 1] = table.concat({
            tostring(operation.kind or "set"),
            tostring(operation.classID or ""),
            tostring(operation.specID or ""),
            tostring(operation.cooldownID or ""),
            tostring(operation.eventType or ""),
            tostring(operation.payload or ""),
            tostring(operation.recordKey or ""),
            tostring(operation.originalRecordKey or ""),
        }, ":")
        for _, cooldownID in ipairs(operation.equivalentCooldownIDs or {}) do
            parts[#parts + 1] = "equivalent:" .. tostring(cooldownID)
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function ReloadNow()
    if type(ReloadUI) == "function" then
        ReloadUI()
        return true
    end
    if type(C_UI) == "table" and type(C_UI.Reload) == "function" then
        C_UI.Reload()
        return true
    end
    return false
end

local function SetApplyFailure(store, plan, reason, mutationStarted)
    local state = store:GetApplyState()
    state.applyInProgress = false
    state.plan = nil
    state.lastApplyError = tostring(reason or "apply_failed")
    state.errorNeedsReport = mutationStarted == true
    state.failedRecordKeys = type(state.failedRecordKeys) == "table" and state.failedRecordKeys or {}
    for _, operation in ipairs(type(plan) == "table" and plan or {}) do
        if operation.kind == "set" then
            state.failedRecordKeys[operation.runtimeKey or tostring(operation.recordKey)] = state.lastApplyError
        end
    end
end

function Service:RemoveAllSoundAlertsForEvent(manager, cooldownID, eventType)
    local alerts, readReason = ReadManagerAlerts(manager, cooldownID)
    if type(alerts) ~= "table" then
        return false, 0, readReason or "read_failed"
    end
    local removeList = {}
    for _, alert in ipairs(alerts) do
        if GetAlertType(alert) == GetSoundAlertType()
            and tonumber(GetAlertEvent(alert)) == tonumber(eventType) then
            removeList[#removeList + 1] = alert
        end
    end
    for _, alert in ipairs(removeList) do
        local ok = pcall(manager.RemoveAlert, manager, tonumber(cooldownID), alert)
        if not ok then
            return false, #removeList, "remove_failed"
        end
    end
    local remaining, _, verifyReason = GetEventSounds(manager, cooldownID, eventType)
    if type(remaining) ~= "table" then
        return false, #removeList, verifyReason or "read_failed"
    end
    if #remaining ~= 0 then
        return false, #removeList, "cleanup_verify_failed"
    end
    return true, #removeList
end

function Service:BuildSoundCleanupGroups(plan)
    local manager = GetLayoutManager()
    if not manager then
        return nil, "data_not_ready"
    end
    local groups, groupsByKey, claims = {}, {}, {}
    for _, operation in ipairs(type(plan) == "table" and plan or {}) do
        if operation.kind == "set" then
            for _, cooldownID in ipairs(operation.equivalentCooldownIDs or {}) do
                local key = PairKey(cooldownID, operation.eventType)
                local claim = claims[key]
                if claim and (tonumber(claim.payload) ~= tonumber(operation.payload)
                    or tonumber(claim.cooldownID) ~= tonumber(operation.cooldownID)) then
                    return nil, "conflicting_local_targets"
                end
                claims[key] = operation
            end
        end
        for _, cooldownID in ipairs(operation.equivalentCooldownIDs or {}) do
            local key = PairKey(cooldownID, operation.eventType)
            if not groupsByKey[key] then
                local alerts, _, readReason = GetEventSounds(manager, cooldownID, operation.eventType)
                if type(alerts) ~= "table" then
                    return nil, readReason or "read_failed"
                end
                local group = {
                    cooldownID = tonumber(cooldownID),
                    eventType = tonumber(operation.eventType),
                    alerts = alerts,
                }
                groupsByKey[key] = group
                groups[#groups + 1] = group
            end
        end
    end
    table.sort(groups, function(left, right)
        if left.cooldownID == right.cooldownID then
            return left.eventType < right.eventType
        end
        return left.cooldownID < right.cooldownID
    end)
    return groups
end

local function SnapshotCleanupGroups(groups)
    local snapshots = {}
    for _, group in ipairs(groups) do
        local sounds = {}
        for _, alert in ipairs(group.alerts or {}) do
            local payload = tonumber(GetAlertPayload(alert))
            if not payload then
                return nil, "snapshot_failed"
            end
            sounds[#sounds + 1] = { eventType = group.eventType, payload = payload }
        end
        snapshots[PairKey(group.cooldownID, group.eventType)] = {
            cooldownID = group.cooldownID,
            eventType = group.eventType,
            sounds = sounds,
        }
    end
    return snapshots
end

local function SnapshotCounts(sounds)
    local counts = {}
    for _, sound in ipairs(type(sounds) == "table" and sounds or {}) do
        local key = tostring(sound.payload)
        counts[key] = (counts[key] or 0) + 1
    end
    return counts
end

local function SnapshotRestored(manager, snapshot)
    local sounds = GetEventSounds(manager, snapshot.cooldownID, snapshot.eventType)
    if type(sounds) ~= "table" or #sounds ~= #snapshot.sounds then
        return false
    end
    local wanted, actual = SnapshotCounts(snapshot.sounds), {}
    for _, alert in ipairs(sounds) do
        local key = tostring(GetAlertPayload(alert))
        actual[key] = (actual[key] or 0) + 1
    end
    for key, count in pairs(wanted) do
        if actual[key] ~= count then
            return false
        end
        actual[key] = nil
    end
    return next(actual) == nil
end

local function RestoreSnapshot(service, manager, snapshot)
    local removed = service:RemoveAllSoundAlertsForEvent(
        manager, snapshot.cooldownID, snapshot.eventType
    )
    if not removed then
        return false
    end
    for _, sound in ipairs(snapshot.sounds) do
        local alert = CreateAlert(sound.eventType, sound.payload)
        if not alert or not AddAlertSucceeded(manager, snapshot.cooldownID, alert) then
            return false
        end
    end
    return SnapshotRestored(manager, snapshot)
end

local function VerifySetOperation(manager, operation)
    for _, cooldownID in ipairs(operation.equivalentCooldownIDs or {}) do
        local sounds, targetCount, readReason = GetEventSounds(
            manager, cooldownID, operation.eventType,
            tonumber(cooldownID) == tonumber(operation.cooldownID) and operation.payload or nil
        )
        if type(sounds) ~= "table" then
            return false, readReason or "read_failed"
        end
        if tonumber(cooldownID) == tonumber(operation.cooldownID) then
            if #sounds ~= 1 or targetCount ~= 1 then
                return false, "add_verify_failed"
            end
        elseif #sounds ~= 0 then
            return false, "add_verify_failed"
        end
    end
    return true
end

local function VerifyRemoveOperation(manager, operation)
    for _, cooldownID in ipairs(operation.equivalentCooldownIDs or {}) do
        local sounds, _, readReason = GetEventSounds(manager, cooldownID, operation.eventType)
        if type(sounds) ~= "table" then
            return false, readReason or "read_failed"
        end
        if #sounds ~= 0 then
            return false, "cleanup_verify_failed"
        end
    end
    return true
end

function Service:ApplyCDMRemovalPlanWithoutReload(plan, options)
    plan = type(plan) == "table" and plan or {}
    options = type(options) == "table" and options or {}
    local summary = NewBatchSummary(options.summary)
    if IsInCombat() then
        return false, summary, "combat"
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local manager = GetLayoutManager()
    if not store or not manager or type(manager.GetAlerts) ~= "function"
        or type(manager.AddAlert) ~= "function"
        or type(manager.RemoveAlert) ~= "function"
        or type(manager.SaveLayouts) ~= "function" then
        return false, summary, "data_not_ready"
    end
    local classID, specID = self:GetCurrentClassSpec()
    local scopeToken = options.scopeToken
    if type(scopeToken) == "table"
        and (tonumber(scopeToken.classID) ~= tonumber(classID)
            or tonumber(scopeToken.specID) ~= tonumber(specID)) then
        return false, summary, "stale_scope"
    end
    if #plan == 0 then
        return true, summary, "no_changes"
    end

    local validated = CopyApplyPlan(plan, false)
    for _, operation in ipairs(validated) do
        if operation.kind ~= "remove"
            or tonumber(operation.classID) ~= tonumber(classID)
            or tonumber(operation.specID) ~= tonumber(specID)
            or not operation.cooldownID or operation.cooldownID <= 0
            or operation.cooldownID ~= math.floor(operation.cooldownID)
            or not operation.eventType or operation.eventType ~= math.floor(operation.eventType)
            or not self:GetCooldownInfo(operation.cooldownID)
            or not self:IsValidEvent(operation.cooldownID, operation.eventType)
            or #operation.equivalentCooldownIDs == 0 then
            return false, summary, "invalid_operation"
        end
        local containsTarget = false
        for _, cooldownID in ipairs(operation.equivalentCooldownIDs) do
            if cooldownID <= 0 or cooldownID ~= math.floor(cooldownID)
                or not self:GetCooldownInfo(cooldownID) then
                return false, summary, "invalid_equivalent_cooldown"
            end
            containsTarget = containsTarget or cooldownID == operation.cooldownID
            local alerts, readReason = ReadManagerAlerts(manager, cooldownID)
            if type(alerts) ~= "table" then
                return false, summary, readReason or "read_failed"
            end
        end
        if not containsTarget then
            return false, summary, "invalid_equivalent_cooldown"
        end
    end

    local cleanupGroups, cleanupReason = self:BuildSoundCleanupGroups(validated)
    if type(cleanupGroups) ~= "table" then
        return false, summary, cleanupReason or "cleanup_plan_failed"
    end
    local snapshots, snapshotReason = SnapshotCleanupGroups(cleanupGroups)
    if type(snapshots) ~= "table" then
        return false, summary, snapshotReason or "snapshot_failed"
    end

    local hasChanges = false
    for _, operation in ipairs(validated) do
        local correct, verifyReason = VerifyRemoveOperation(manager, operation)
        if not correct then
            if verifyReason == "read_failed" or verifyReason == "data_not_ready" then
                return false, summary, verifyReason
            end
            hasChanges = true
        end
    end
    if not hasChanges then
        for _, operation in ipairs(validated) do
            store:ClearPendingRemoval(classID, specID, operation.recordKey)
        end
        self.lastBatchResults = {}
        self.lastBatchSummary = summary
        self:RefreshRuntimeData(options.reason or "manual_delete_noop")
        return true, summary, "no_changes"
    end

    self:BeginCDMMutation("qfx_manual_delete")
    local mutationStarted, failureReason = false, nil
    for _, group in ipairs(cleanupGroups) do
        if #(group.alerts or {}) > 0 then
            mutationStarted = true
        end
        local removed, removedCount, removeReason = self:RemoveAllSoundAlertsForEvent(
            manager, group.cooldownID, group.eventType
        )
        if not removed then
            failureReason = removeReason or "cleanup_verify_failed"
            break
        end
        summary.removed = summary.removed + removedCount
    end
    if not failureReason then
        for _, operation in ipairs(validated) do
            local verified, verifyReason = VerifyRemoveOperation(manager, operation)
            if not verified then
                failureReason = verifyReason
                break
            end
        end
    end
    if not failureReason and not ManagerCallSucceeded(manager.SaveLayouts, manager) then
        failureReason = "save_failed"
    end

    if failureReason then
        local rollbackOK = true
        if mutationStarted then
            for _, snapshot in pairs(snapshots) do
                if not RestoreSnapshot(self, manager, snapshot) then
                    rollbackOK = false
                end
            end
        end
        if mutationStarted and not rollbackOK then
            failureReason = "rollback_failed"
        end
        summary.failed = summary.failed + 1
        self.lastBatchResults = {}
        self.lastBatchSummary = summary
        self:EndCDMMutation()
        return false, summary, failureReason
    end

    local results = {}
    for _, operation in ipairs(validated) do
        store:ClearPendingRemoval(classID, specID, operation.recordKey)
        results[#results + 1] = {
            success = true,
            changed = true,
            operation = operation,
            mutationKind = "removed",
        }
    end
    self.lastBatchResults = results
    self.lastBatchSummary = summary
    self:EndCDMMutation()
    self:RefreshRuntimeData(options.reason or "manual_delete")
    return true, summary, "deleted"
end

function Service:ApplyCDMPlanAndReload(plan, options)
    plan = type(plan) == "table" and plan or {}
    options = type(options) == "table" and options or {}
    local summary = NewBatchSummary(options.summary)
    if IsInCombat() then
        return false, summary, "combat"
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local manager = GetLayoutManager()
    if not store or not manager or type(manager.GetAlerts) ~= "function"
        or type(manager.AddAlert) ~= "function" or type(manager.RemoveAlert) ~= "function"
        or type(manager.LockNotifications) ~= "function" or type(manager.SaveLayouts) ~= "function"
        or (type(ReloadUI) ~= "function"
            and (type(C_UI) ~= "table" or type(C_UI.Reload) ~= "function")) then
        return false, summary, "data_not_ready"
    end
    local classID, specID = self:GetCurrentClassSpec()
    local scopeToken = options.scopeToken
    if type(scopeToken) == "table"
        and (tonumber(scopeToken.classID) ~= tonumber(classID)
            or tonumber(scopeToken.specID) ~= tonumber(specID)) then
        return false, summary, "stale_scope"
    end
    if #plan == 0 then
        return true, summary, "no_changes"
    end

    local validated = CopyApplyPlan(plan, true)
    for _, operation in ipairs(validated) do
        if tonumber(operation.classID) ~= tonumber(classID)
            or tonumber(operation.specID) ~= tonumber(specID)
            or not operation.cooldownID or operation.cooldownID <= 0
            or operation.cooldownID ~= math.floor(operation.cooldownID)
            or not operation.eventType or operation.eventType ~= math.floor(operation.eventType)
            or not self:GetCooldownInfo(operation.cooldownID)
            or not self:IsValidEvent(operation.cooldownID, operation.eventType)
            or #operation.equivalentCooldownIDs == 0 then
            return false, summary, "invalid_operation"
        end
        local containsTarget = false
        for _, cooldownID in ipairs(operation.equivalentCooldownIDs) do
            if cooldownID <= 0 or cooldownID ~= math.floor(cooldownID)
                or not self:GetCooldownInfo(cooldownID) then
                return false, summary, "invalid_equivalent_cooldown"
            end
            containsTarget = containsTarget or cooldownID == operation.cooldownID
            local alerts, readReason = ReadManagerAlerts(manager, cooldownID)
            if type(alerts) ~= "table" then
                return false, summary, readReason or "read_failed"
            end
        end
        if not containsTarget then
            return false, summary, "invalid_equivalent_cooldown"
        end
        if operation.kind == "set" then
            local path = Registry and Registry:GetPathForPayload(operation.payload)
            if not operation.payload or not Registry or not Registry:IsOwnedPayload(operation.payload)
                or not Registry:IsPayloadAvailable(operation.payload)
                or type(path) ~= "string" or path == "" then
                return false, summary, "target_alert_invalid"
            end
            local canConfigure, targetAlert = self:CanConfigureSound(
                operation.cooldownID, operation.eventType, operation.payload
            )
            if not canConfigure or type(targetAlert) ~= "table" then
                return false, summary, targetAlert or "target_alert_invalid"
            end
            operation.targetAlert = targetAlert
        elseif operation.kind ~= "remove" then
            return false, summary, "invalid_operation"
        end
    end

    local cleanupGroups, cleanupReason = self:BuildSoundCleanupGroups(validated)
    if type(cleanupGroups) ~= "table" then
        return false, summary, cleanupReason or "cleanup_plan_failed"
    end
    local snapshots, snapshotReason = SnapshotCleanupGroups(cleanupGroups)
    if type(snapshots) ~= "table" then
        return false, summary, snapshotReason or "snapshot_failed"
    end

    local hasChanges = false
    for _, operation in ipairs(validated) do
        local correct, verifyReason
        if operation.kind == "set" then
            correct, verifyReason = VerifySetOperation(manager, operation)
        else
            correct, verifyReason = VerifyRemoveOperation(manager, operation)
        end
        if not correct then
            if verifyReason == "read_failed" or verifyReason == "data_not_ready" then
                return false, summary, verifyReason
            end
            hasChanges = true
        end
    end
    if not hasChanges then
        for _, operation in ipairs(validated) do
            if operation.kind == "remove" then
                store:ClearPendingRemoval(classID, specID, operation.recordKey)
            end
        end
        self.lastBatchResults = {}
        self.lastBatchSummary = summary
        self:RefreshRuntimeData(options.reason or "apply_noop")
        return true, summary, "no_changes"
    end

    local applyState = store:GetApplyState()
    applyState.applyInProgress = true
    applyState.classID = classID
    applyState.specID = specID
    applyState.signature = StablePlanSignature(validated)
    applyState.startedAt = type(time) == "function" and time() or 0
    applyState.lastApplyError = nil
    applyState.errorNeedsReport = false
    applyState.lastApplySummary = summary
    applyState.plan = CopyApplyPlan(validated, false)

    self:BeginCDMMutation("qfx_explicit_apply")
    if not ManagerCallSucceeded(manager.LockNotifications, manager) then
        self:EndCDMMutation()
        SetApplyFailure(store, validated, "lock_failed", false)
        return false, summary, "lock_failed"
    end

    local mutationStarted, failureReason = false, nil
    for _, group in ipairs(cleanupGroups) do
        if #(group.alerts or {}) > 0 then
            mutationStarted = true
        end
        local removed, removedCount, removeReason = self:RemoveAllSoundAlertsForEvent(
            manager, group.cooldownID, group.eventType
        )
        if not removed then
            failureReason = removeReason or "cleanup_verify_failed"
            break
        end
        summary.removed = summary.removed + removedCount
    end

    if not failureReason then
        for _, operation in ipairs(validated) do
            if operation.kind == "set" then
                mutationStarted = true
                if not AddAlertSucceeded(
                    manager, operation.cooldownID, operation.targetAlert
                ) then
                    failureReason = "add_failed"
                    break
                end
            end
        end
    end
    if not failureReason then
        for _, operation in ipairs(validated) do
            local verified, verifyReason = operation.kind == "set"
                and VerifySetOperation(manager, operation)
                or VerifyRemoveOperation(manager, operation)
            if not verified then
                failureReason = verifyReason
                break
            end
        end
    end
    if not failureReason and not ManagerCallSucceeded(manager.SaveLayouts, manager) then
        failureReason = "save_failed"
    end

    if failureReason then
        local rollbackOK = true
        if mutationStarted then
            for _, snapshot in pairs(snapshots) do
                if not RestoreSnapshot(self, manager, snapshot) then
                    rollbackOK = false
                end
            end
        end
        if mutationStarted and not rollbackOK then
            failureReason = "rollback_failed"
        end
        summary.failed = summary.failed + 1
        self.lastBatchResults = {}
        self.lastBatchSummary = summary
        SetApplyFailure(store, validated, failureReason, mutationStarted)
        self:EndCDMMutation()
        if mutationStarted then
            ReloadNow()
        end
        return false, summary, failureReason
    end

    local results = {}
    for _, operation in ipairs(validated) do
        results[#results + 1] = {
            success = true,
            changed = true,
            operation = operation,
            mutationKind = operation.kind == "set" and (operation.action or "replaced") or "removed",
        }
        if operation.kind == "set" then
            local kind = operation.action == "add" and "added"
                or (operation.action == "deduplicate" and "deduplicated" or "replaced")
            summary[kind] = (tonumber(summary[kind]) or 0) + 1
        end
    end
    self.lastBatchResults = results
    self.lastBatchSummary = summary
    self:EndCDMMutation()
    ReloadNow()
    return true, summary, "reload_requested"
end

function Service:ApplySoundAlertsBatch(operations, options)
    options = type(options) == "table" and options or {}
    if options.explicit ~= true then
        return false, NewBatchSummary(options.summary), "explicit_apply_required"
    end
    return self:ApplyCDMPlanAndReload(operations, options)
end

function Service:BuildCDMVoiceDraft(cooldownID, eventType, payload, expectedClassID, expectedSpecID, expectedCategory)
    local classID, specID = self:GetCurrentClassSpec()
    if (expectedClassID and tonumber(expectedClassID) ~= classID)
        or (expectedSpecID and tonumber(expectedSpecID) ~= specID) then
        return nil, "spec_changed"
    end
    local currentCategory = self:FindCategoryForCooldown(cooldownID)
    if not currentCategory or (expectedCategory and tostring(expectedCategory) ~= tostring(currentCategory)) then
        return nil, "invalid_cooldown"
    end
    local canConfigure, reason = self:CanConfigureSound(cooldownID, eventType, payload)
    if not canConfigure then
        return nil, reason
    end
    local cooldownInfo = self:GetCooldownInfo(cooldownID)
    local voiceItem = Registry and Registry:GetItemForPayload(payload)
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if not cooldownInfo or not voiceItem or not store or type(store.SaveAppliedRecord) ~= "function" then
        return nil, "data_not_ready"
    end
    return store:SanitizeRecord({
        classID = classID,
        specID = specID,
        category = currentCategory,
        spellID = cooldownInfo.spellID,
        eventKey = store:EventTypeToKey(eventType),
        eventTypeHint = eventType,
        voiceIdentity = voiceItem.identity,
        voiceName = voiceItem.name,
        voicePath = voiceItem.path,
        cooldownIDHint = cooldownID,
        payloadHint = payload,
        source = "user",
    }, "user")
end

function Service:ValidateCDMVoiceDraft(draft, _options)
    if type(draft) ~= "table" then
        return nil, "invalid_record"
    end
    return self:BuildCDMVoiceDraft(
        draft.cooldownID,
        draft.eventType or draft.eventTypeHint,
        draft.payload or draft.payloadHint,
        draft.classID,
        draft.specID,
        draft.category
    )
end

function Service:SaveVoicePresetOnly(cooldownID, eventType, payload, expectedClassID, expectedSpecID, expectedCategory)
    local record, reason, originalRecordKey
    if type(cooldownID) == "table" then
        originalRecordKey = cooldownID.originalRecordKey
        record, reason = self:ValidateCDMVoiceDraft(cooldownID)
    else
        record, reason = self:BuildCDMVoiceDraft(
            cooldownID, eventType, payload,
            expectedClassID, expectedSpecID, expectedCategory
        )
    end
    if not record then
        return false, reason or "invalid_record"
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local originalRecord = originalRecordKey and store
        and store:GetEffectiveRecord(record.classID, record.specID, originalRecordKey) or nil
    local recordKey, savedRecord = store and store:SaveAppliedRecord(record)
    if not recordKey then
        return false, savedRecord or "save_failed"
    end
    if originalRecordKey and originalRecordKey ~= recordKey and originalRecord then
        local removed, removeReason = store:RemoveOrDisableRecord(
            record.classID, record.specID, originalRecordKey,
            { createPendingRemoval = true }
        )
        if not removed then
            return false, removeReason or "save_failed"
        end
    end
    local status = "pending"
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if sync and type(sync.EvaluateRecord) == "function" then
        local evaluation = sync:EvaluateRecord(savedRecord)
        if type(evaluation) == "table" and evaluation.status == "loaded" then
            status = "loaded"
        end
    end
    self:RefreshRuntimeData("preset_saved_local")
    return true, recordKey, status, savedRecord
end

function Service:SaveAndSyncVoicePreset(...)
    return self:SaveVoicePresetOnly(...)
end

function Service:ApplySoundAlert(cooldownID, eventType, payload, expectedClassID, expectedSpecID, expectedCategory)
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if not sync or type(sync.ApplyCurrentDraftAndReload) ~= "function" then
        return false, nil, "not_available"
    end
    return sync:ApplyCurrentDraftAndReload({
        cooldownID = cooldownID,
        eventType = eventType,
        payload = payload,
        classID = expectedClassID,
        specID = expectedSpecID,
        category = expectedCategory,
    })
end

function Service:ClearPendingRuntimeReload()
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local state = store and type(store.GetSyncState) == "function" and store:GetSyncState() or nil
    if type(state) == "table" then
        state.pendingRuntimeReload = false
    end
    return true
end

local CDM_SAVED_STATUS_DISPLAY = {
    loaded = { loadState = "green", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_APPLIED" },
    pending = { loadState = "yellow", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_PENDING" },
    applyFailed = { loadState = "orange", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_APPLY_FAILED" },
    eventUnsupported = { loadState = "orange", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_EVENT_UNSUPPORTED" },
    voiceMissing = { loadState = "gray", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_VOICE_MISSING" },
    skillMissing = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_STATUS_SKILL_MISSING" },
    ambiguousSkill = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_STATUS_AMBIGUOUS_SKILL" },
    dataNotReady = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_DATA_NOT_READY" },
    scopeUnloaded = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_STATUS_SCOPE_UNLOADED" },
}

local function ResolveCDMScopeText(classID, specID, isLoaded)
    local scope = NS.Core and NS.Core.Scope
    local className = type(scope) == "table" and type(scope.ResolveClassName) == "function"
        and scope:ResolveClassName(classID) or L("FALLBACK_CLASS", tostring(classID))
    local specName = type(scope) == "table" and type(scope.ResolveSpecName) == "function"
        and scope:ResolveSpecName(classID, specID) or L("FALLBACK_SPEC", tostring(specID))
    return string.format("%s / %s%s", className, specName, isLoaded and L("LOADED_TAG") or L("UNLOADED_TAG"))
end

local function BuildCDMSavedEntry(store, record, evaluation, display, includeScopeText)
    evaluation = type(evaluation) == "table" and evaluation or {}
    display = type(display) == "table" and display or CDM_SAVED_STATUS_DISPLAY.skillMissing
    local info = type(evaluation.info) == "table" and evaluation.info or {}
    local classID = tonumber(record.classID) or 0
    local specID = tonumber(record.specID) or 0
    local spellID = tonumber(record.spellID) or 0
    local eventType = tonumber(evaluation.eventType)
        or (store and type(store.EventKeyToType) == "function"
            and tonumber(store:EventKeyToType(record.eventKey, record.eventTypeHint)) or nil)
    local eventText = tostring(record.eventKey or "")
    if eventType then
        eventText = L("CDM_EVENT_FALLBACK", eventType)
        if type(CooldownViewerAlert_GetEventText) == "function" then
            local ok, value = pcall(CooldownViewerAlert_GetEventText, eventType)
            if ok and type(value) == "string" and value ~= "" then
                eventText = value
            end
        end
    end
    local voiceItem = evaluation.voiceItem
    if not voiceItem and store and type(store.ResolveVoice) == "function" then
        voiceItem = store:ResolveVoice(record)
    end
    local voiceName = tostring(record.voiceName or "")
    if voiceName == "" and voiceItem then
        voiceName = tostring(voiceItem.name or "")
    end
    if voiceName == "" then
        voiceName = L("CDM_MISSING_VOICE")
    end
    local runtimeStatus = tostring(evaluation.status or "skillMissing")
    return {
        key = string.format("cdmpreset:%d:%d:%s:%d:%s", classID, specID, record.category, spellID, record.eventKey),
        entryType = "cdmVoice",
        itemType = "entry",
        classID = classID,
        specID = specID,
        recordKey = record.recordKey,
        category = record.category,
        spellId = spellID,
        eventKey = record.eventKey,
        alertEvent = eventType,
        voiceIdentity = record.voiceIdentity,
        voiceName = voiceName,
        voicePath = record.voicePath,
        cooldownID = evaluation.cooldownID,
        voicePayload = voiceItem and tonumber(voiceItem.payload) or nil,
        currentPayload = evaluation.currentPayload,
        spellName = info.spellName or GetSpellName(spellID) or L("CDM_UNKNOWN_SKILL", spellID),
        icon = info.icon or GetSpellIcon(spellID),
        eventText = eventText,
        statusText = L(display.localeKey),
        soundDetail = eventText .. " | " .. voiceName,
        scopeText = includeScopeText and ResolveCDMScopeText(classID, specID, display.isLoaded) or "",
        runtimeStatus = runtimeStatus,
        runtimeReason = runtimeStatus,
        loadState = display.loadState,
        isLoaded = display.isLoaded,
        displaySection = display.displaySection,
        isVirtual = true,
        canDrag = false,
        isCurrentScope = includeScopeText ~= true,
    }
end

function Service:GetCurrentSpecSavedEntries()
    local classID, specID = self:GetCurrentClassSpec()
    if not classID or not specID then
        return {}
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if not store or not sync or type(sync.EvaluateRecord) ~= "function" then
        return {}
    end
    local result = {}
    for _, record in ipairs(store:GetEffectiveRecords(classID, specID)) do
        local evaluation = sync:EvaluateRecord(record)
        local display = CDM_SAVED_STATUS_DISPLAY[evaluation.status] or CDM_SAVED_STATUS_DISPLAY.skillMissing
        result[#result + 1] = BuildCDMSavedEntry(store, record, evaluation, display, false)
    end
    return result
end

function Service:GetSavedEntries()
    local currentClassID, currentSpecID = self:GetCurrentClassSpec()
    if not currentClassID or not currentSpecID then
        return {}
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if not store then
        return {}
    end

    local result = self:GetCurrentSpecSavedEntries()
    local profiles = type(store.GetAllProfilesForExport) == "function" and store:GetAllProfilesForExport() or {}
    local inactiveRecords = {}
    for classIDKey, classMap in pairs(type(profiles) == "table" and profiles or {}) do
        local classID = tonumber(classIDKey)
        if classID and type(classMap) == "table" then
            for specIDKey, specMap in pairs(classMap) do
                local specID = tonumber(specIDKey)
                if specID and type(specMap) == "table"
                    and (classID ~= currentClassID or specID ~= currentSpecID) then
                    for _, record in pairs(specMap) do
                        if type(record) == "table" and record.enabled ~= false then
                            inactiveRecords[#inactiveRecords + 1] = record
                        end
                    end
                end
            end
        end
    end
    table.sort(inactiveRecords, function(left, right)
        local leftClass, rightClass = tonumber(left.classID) or 0, tonumber(right.classID) or 0
        if leftClass ~= rightClass then
            return leftClass < rightClass
        end
        local leftSpec, rightSpec = tonumber(left.specID) or 0, tonumber(right.specID) or 0
        if leftSpec ~= rightSpec then
            return leftSpec < rightSpec
        end
        return tostring(left.recordKey or "") < tostring(right.recordKey or "")
    end)
    for _, record in ipairs(inactiveRecords) do
        result[#result + 1] = BuildCDMSavedEntry(
            store,
            record,
            { status = "scopeUnloaded" },
            CDM_SAVED_STATUS_DISPLAY.scopeUnloaded,
            true
        )
    end
    return result
end

function Service:ParseSavedEntryKey(key)
    local classID, specID, category, spellID, eventKey = tostring(key or ""):match(
        "^cdmpreset:(%d+):(%d+):([^:]+):(%d+):([^:]+)$"
    )
    if classID then
        local store = NS.Core and NS.Core.CDMVoicePresetStore
        local recordKey = store and store:BuildRecordKey(category, spellID, eventKey)
        if not recordKey then
            return nil
        end
        return {
            keyType = "preset",
            classID = tonumber(classID),
            specID = tonumber(specID),
            category = category,
            spellID = tonumber(spellID),
            eventKey = tostring(eventKey):upper(),
            recordKey = recordKey,
        }
    end
    local cooldownID, eventType, payload
    classID, specID, cooldownID, eventType, payload = tostring(key or ""):match(
        "^cdm:(%d+):(%d+):(%d+):(%d+):(-?%d+)$"
    )
    if not classID then
        return nil
    end
    return {
        keyType = "legacyRuntime",
        classID = tonumber(classID),
        specID = tonumber(specID),
        cooldownID = tonumber(cooldownID),
        eventType = tonumber(eventType),
        payload = tonumber(payload),
    }
end

function Service:StageSoundAlertRemovalByKey(key, options)
    options = type(options) == "table" and options or {}
    local parsed = self:ParseSavedEntryKey(key)
    if not parsed then
        return false, "invalid_key"
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if parsed.keyType == "preset" then
        local classID, specID = self:GetCurrentClassSpec()
        if parsed.classID ~= classID or parsed.specID ~= specID then
            return false, "spec_changed"
        end
        local record = store and store:GetEffectiveRecord(parsed.classID, parsed.specID, parsed.recordKey)
        if not record then
            return false, "not_found"
        end
        local sync = NS.Core and NS.Core.CDMVoicePresetSync
        local snapshot, mutationError = store:RemoveOrDisableRecord(
            parsed.classID,
            parsed.specID,
            parsed.recordKey,
            { createPendingRemoval = true }
        )
        if not snapshot then
            return false, mutationError or "delete_failed"
        end
        self:RefreshRuntimeData("preset_deleted_local")
        if options.scheduleEvaluation ~= false
            and sync and type(sync.ScheduleEvaluation) == "function" then
            sync:ScheduleEvaluation("preset_deleted_local")
        end
        return true,
            snapshot.pendingRemoval and "pending_removal" or "local_deleted",
            parsed.recordKey,
            snapshot
    end

    local category = self:FindCategoryForCooldown(parsed.cooldownID)
    local info = self:GetCooldownInfo(parsed.cooldownID)
    local recordKey
    if store and info and category then
        local _record
        _record, recordKey = store:GetRecordForAlert(
            parsed.classID,
            parsed.specID,
            category,
            info.spellID,
            parsed.eventType
        )
    end
    local snapshot
    if store and recordKey then
        local existing = store:GetEffectiveRecord(parsed.classID, parsed.specID, recordKey)
        if existing then
            local reason
            snapshot, reason = store:RemoveOrDisableRecord(
                parsed.classID,
                parsed.specID,
                recordKey,
                { createPendingRemoval = true }
            )
            if not snapshot then
                return false, reason or "delete_failed"
            end
        elseif info and category then
            local pendingKey = store:SetPendingRemoval({
                classID = parsed.classID,
                specID = parsed.specID,
                category = category,
                spellID = info.spellID,
                eventKey = store:EventTypeToKey(parsed.eventType),
                eventTypeHint = parsed.eventType,
                cooldownIDHint = parsed.cooldownID,
                source = "user",
            })
            recordKey = pendingKey or recordKey
        end
    end
    if not store or not recordKey
        or not store:GetPendingRemoval(parsed.classID, parsed.specID, recordKey) then
        return false, "delete_failed"
    end
    self:RefreshRuntimeData("preset_deleted_local")
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if options.scheduleEvaluation ~= false
        and sync and type(sync.ScheduleEvaluation) == "function" then
        sync:ScheduleEvaluation("preset_deleted_local")
    end
    return true, "pending_removal", recordKey, snapshot
end

function Service:DeleteSoundAlertByKeyLocalOnly(key)
    return self:StageSoundAlertRemovalByKey(key)
end

function Service:DeletePresetEntriesLocalBatch(keys)
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if not store or type(store.RemoveOrDisableRecord) ~= "function" then
        return false, 0, "not_available"
    end

    local records = {}
    local seen = {}
    for _, key in ipairs(type(keys) == "table" and keys or {}) do
        key = tostring(key or "")
        if key ~= "" and not seen[key] then
            seen[key] = true
            local parsed = self:ParseSavedEntryKey(key)
            if not parsed or parsed.keyType ~= "preset"
                or not store:GetEffectiveRecord(parsed.classID, parsed.specID, parsed.recordKey) then
                return false, 0, "not_found"
            end
            records[#records + 1] = parsed
        end
    end
    if #records == 0 then
        return true, 0, "empty"
    end

    local snapshots = {}
    for _, parsed in ipairs(records) do
        local snapshot, reason = store:RemoveOrDisableRecord(
            parsed.classID,
            parsed.specID,
            parsed.recordKey,
            { createPendingRemoval = true }
        )
        if not snapshot then
            for index = #snapshots, 1, -1 do
                store:RestoreRecordMutation(snapshots[index])
            end
            return false, 0, reason or "delete_failed"
        end
        snapshots[#snapshots + 1] = snapshot
    end

    self:RefreshRuntimeData("preset_collection_deleted_local")
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if sync and type(sync.ScheduleEvaluation) == "function" then
        sync:ScheduleEvaluation("preset_collection_deleted_local")
    end
    return true, #snapshots, "deleted"
end

function Service:DeleteSoundAlertByKey(key)
    if IsInCombat() then
        return false, "combat"
    end
    local staged, stageReason, recordKey, snapshot = self:StageSoundAlertRemovalByKey(
        key,
        { scheduleEvaluation = false }
    )
    if not staged then
        return false, stageReason
    end
    if stageReason ~= "pending_removal" then
        return true, "deleted"
    end

    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if not sync or type(sync.ApplyPendingRemovalByKey) ~= "function" then
        if snapshot and store and type(store.RestoreRecordMutation) == "function" then
            store:RestoreRecordMutation(snapshot)
        end
        self:RefreshRuntimeData("preset_delete_rollback")
        return false, "not_available"
    end

    local applied, summary, applyReason = sync:ApplyPendingRemovalByKey(recordKey)
    if not applied then
        if snapshot and store and type(store.RestoreRecordMutation) == "function" then
            store:RestoreRecordMutation(snapshot)
        end
        self:RefreshRuntimeData("preset_delete_rollback")
        return false, applyReason or "delete_failed"
    end
    return true, applyReason or "deleted", summary
end

function Service:GetLastCategory()
    if type(QFXSkillAlertsDB) ~= "table" then
        return nil
    end
    return type(QFXSkillAlertsDB.cdmVoiceUI) == "table" and QFXSkillAlertsDB.cdmVoiceUI.lastCategory or nil
end

function Service:SetLastCategory(category)
    local _, def = ResolveCategory(category)
    if not def then
        return false
    end
    QFXSkillAlertsDB = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or {}
    QFXSkillAlertsDB.cdmVoiceUI = type(QFXSkillAlertsDB.cdmVoiceUI) == "table" and QFXSkillAlertsDB.cdmVoiceUI or {}
    QFXSkillAlertsDB.cdmVoiceUI.lastCategory = def.key
    return true
end

function Service:SetUIRefreshCallback(callback)
    self.uiRefreshCallback = type(callback) == "function" and callback or nil
end

function Service:RefreshRuntimeData(reason)
    self.refreshSerial = self.refreshSerial + 1
    if type(self.uiRefreshCallback) == "function" then
        pcall(self.uiRefreshCallback, reason or "data")
    end
    return self.refreshSerial
end

function Service:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
end

Service:Initialize()
