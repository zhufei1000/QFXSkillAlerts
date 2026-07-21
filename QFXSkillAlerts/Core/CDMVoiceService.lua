local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceService = NS.Core.CDMVoiceService or {}

local Service = NS.Core.CDMVoiceService
local Registry = NS.Core.CDMVoiceRegistry

Service.refreshSerial = Service.refreshSerial or 0
Service.cdmMutationDepth = tonumber(Service.cdmMutationDepth) or 0

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

local function AlertMatches(alert, eventType, payload)
    return GetAlertType(alert) == GetSoundAlertType()
        and tonumber(GetAlertEvent(alert)) == tonumber(eventType)
        and tonumber(GetAlertPayload(alert)) == tonumber(payload)
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
    return result
end

function Service:GetCooldownInfo(cooldownID)
    cooldownID = tonumber(cooldownID)
    if not cooldownID then
        return nil
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
    return {
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
end

function Service:GetValidEvents(cooldownID)
    cooldownID = tonumber(cooldownID)
    if not cooldownID or type(C_CooldownViewer) ~= "table" or type(C_CooldownViewer.GetValidAlertTypes) ~= "function" then
        return {}
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

function Service:RefreshActiveCooldownViewerRuntime()
    -- Compatibility no-op. Calling Blizzard viewer/data-provider refresh methods
    -- from addon code can taint secret-value evaluation (notably hasTotem).
    return false
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

local function SnapshotSounds(alerts)
    local snapshots = {}
    for _, alert in ipairs(type(alerts) == "table" and alerts or {}) do
        local eventType = tonumber(GetAlertEvent(alert))
        local payload = tonumber(GetAlertPayload(alert))
        if not eventType or not payload then
            return nil
        end
        snapshots[#snapshots + 1] = { eventType = eventType, payload = payload }
    end
    return snapshots
end

local function SnapshotCounts(snapshots)
    local counts = {}
    for _, snapshot in ipairs(type(snapshots) == "table" and snapshots or {}) do
        local key = tostring(snapshot.payload)
        counts[key] = (counts[key] or 0) + 1
    end
    return counts
end

local function SnapshotsRestored(manager, cooldownID, eventType, snapshots)
    local sounds = GetEventSounds(manager, cooldownID, eventType)
    if type(sounds) ~= "table" or #sounds ~= #snapshots then
        return false
    end
    local wanted, actual = SnapshotCounts(snapshots), {}
    for _, alert in ipairs(sounds) do
        local payload = tonumber(GetAlertPayload(alert))
        if not payload then
            return false
        end
        local key = tostring(payload)
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

local function RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots)
    local current = GetEventSounds(manager, cooldownID, eventType)
    if type(current) ~= "table" then
        return false
    end
    for _, alert in ipairs(current) do
        if not ManagerCallSucceeded(manager.RemoveAlert, manager, cooldownID, alert) then
            return false
        end
    end
    local remaining = GetEventSounds(manager, cooldownID, eventType)
    if type(remaining) ~= "table" or #remaining ~= 0 then
        return false
    end
    for _, snapshot in ipairs(snapshots) do
        local alert = CreateAlert(snapshot.eventType, snapshot.payload)
        if not alert or not ManagerCallSucceeded(manager.AddAlert, manager, cooldownID, alert) then
            return false
        end
    end
    return SnapshotsRestored(manager, cooldownID, eventType, snapshots)
end

function Service:ReconcileSoundAlert(operation, manager)
    manager = manager or GetLayoutManager()
    local cooldownID = tonumber(operation and operation.cooldownID)
    local eventType = tonumber(operation and operation.eventType)
    local payload = tonumber(operation and operation.payload)
    local result = {
        success = false,
        changed = false,
        duplicateRemoved = 0,
        reason = "invalid_operation",
    }
    if IsInCombat()
        or type(manager) ~= "table" or type(manager.GetAlerts) ~= "function"
        or type(manager.AddAlert) ~= "function" or type(manager.RemoveAlert) ~= "function"
        or not cooldownID or cooldownID <= 0 or cooldownID ~= math.floor(cooldownID)
        or not eventType or eventType ~= math.floor(eventType)
        or not payload or payload ~= math.floor(payload)
        or not self:GetCooldownInfo(cooldownID)
        or not self:IsValidEvent(cooldownID, eventType) then
        return result
    end
    if not Registry or not Registry:IsOwnedPayload(payload)
        or not Registry:IsPayloadAvailable(payload)
        or type(Registry:GetPathForPayload(payload)) ~= "string"
        or Registry:GetPathForPayload(payload) == "" then
        result.reason = "target_alert_invalid"
        return result
    end
    local targetAlert = operation and operation.alert
    if type(targetAlert) ~= "table" or not AlertMatches(targetAlert, eventType, payload) then
        result.reason = "target_alert_invalid"
        return result
    end
    if type(CooldownViewerAlert_GetAlertStatus) == "function" then
        local ok, status = pcall(CooldownViewerAlert_GetAlertStatus, targetAlert)
        if not ok or not IsSuccessStatus(status) then
            result.reason = "target_alert_invalid"
            return result
        end
    end

    local matching, targetCount, readError = GetEventSounds(manager, cooldownID, eventType, payload)
    if type(matching) ~= "table" then
        result.reason = readError or "invalid_operation"
        return result
    end
    if #matching == 1 and targetCount == 1 then
        result.success = true
        result.mutationKind = "unchanged"
        result.reason = nil
        return result
    end

    local snapshots = SnapshotSounds(matching)
    if not snapshots then
        result.reason = "remove_failed"
        return result
    end
    result.previousSounds = snapshots
    if #matching == 0 then
        if not ManagerCallSucceeded(manager.AddAlert, manager, cooldownID, targetAlert) then
            result.reason = "add_failed"
            return result
        end
        local finalSounds, finalTargets = GetEventSounds(manager, cooldownID, eventType, payload)
        if type(finalSounds) ~= "table" or #finalSounds ~= 1 or finalTargets ~= 1 then
            RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots)
            result.reason = "add_verify_failed"
            return result
        end
        result.success = true
        result.changed = true
        result.mutationKind = "added"
        result.reason = nil
        return result
    end

    result.mutationKind = #matching >= 2 and "deduplicated" or "replaced"
    result.duplicateRemoved = result.mutationKind == "deduplicated" and math.max(0, #matching - 1) or 0
    for _, alert in ipairs(matching) do
        if not ManagerCallSucceeded(manager.RemoveAlert, manager, cooldownID, alert) then
            if not RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots) then
                result.reason = "replace_rollback_failed"
            else
                result.reason = "remove_failed"
            end
            return result
        end
    end
    local remaining = GetEventSounds(manager, cooldownID, eventType, payload)
    if type(remaining) ~= "table" or #remaining ~= 0 then
        if not RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots) then
            result.reason = "replace_rollback_failed"
        else
            result.reason = "remove_verify_failed"
        end
        return result
    end
    if not ManagerCallSucceeded(manager.AddAlert, manager, cooldownID, targetAlert) then
        if not RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots) then
            result.reason = "replace_rollback_failed"
        else
            result.reason = "add_failed"
        end
        return result
    end
    local finalSounds, finalTargets = GetEventSounds(manager, cooldownID, eventType, payload)
    if type(finalSounds) ~= "table" or #finalSounds ~= 1 or finalTargets ~= 1 then
        if not RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots) then
            result.reason = "replace_rollback_failed"
        else
            result.reason = "add_verify_failed"
        end
        return result
    end
    result.success = true
    result.changed = true
    result.reason = nil
    return result
end

function Service:ApplySoundAlertsBatch(operations, options)
    operations = type(operations) == "table" and operations or {}
    options = type(options) == "table" and options or {}
    local summary = NewBatchSummary(options.summary)
    if IsInCombat() then
        summary.combat = true
        return false, summary, "combat"
    end

    local manager = GetLayoutManager()
    if not manager then
        summary.failed = summary.failed + #operations
        return false, summary, "data_not_ready"
    end

    local validated = {}
    local seen = {}
    for _, operation in ipairs(operations) do
        local cooldownID = tonumber(operation.cooldownID)
        local eventType = tonumber(operation.eventType)
        local payload = tonumber(operation.payload)
        local dedupeKey = string.format("%s:%s", tostring(cooldownID), tostring(eventType))
        if not cooldownID or not self:GetCooldownInfo(cooldownID) then
            summary.missingSkill = summary.missingSkill + 1
        elseif seen[dedupeKey] then
            summary.failed = summary.failed + 1
        elseif not self:IsValidEvent(cooldownID, eventType) then
            summary.unsupportedEvent = summary.unsupportedEvent + 1
        elseif not Registry or not Registry:IsOwnedPayload(payload) or not Registry:IsPayloadAvailable(payload) then
            summary.missingVoice = summary.missingVoice + 1
        else
            seen[dedupeKey] = true
            local canConfigure, alert = self:CanConfigureSound(cooldownID, eventType, payload)
            if canConfigure then
                validated[#validated + 1] = {
                    cooldownID = cooldownID,
                    eventType = eventType,
                    payload = payload,
                    recordKey = operation.recordKey,
                    runtimeKey = operation.runtimeKey,
                    alert = alert,
                }
            else
                summary.unsupportedEvent = summary.unsupportedEvent + 1
            end
        end
    end

    if #validated == 0 then
        self.lastBatchResults = {}
        self.lastBatchSummary = summary
        if options.deferRefresh ~= true then
            self:RefreshRuntimeData(options.reason or "batch_noop")
        end
        return summary.failed == 0, summary
    end

    self:BeginCDMMutation(options.mutationSource or "qfx_reconcile")
    local locked = false
    if type(manager.LockNotifications) == "function" then
        locked = pcall(manager.LockNotifications, manager)
    end
    local results = {}
    local changed = false
    for _, operation in ipairs(validated) do
        local result = self:ReconcileSoundAlert(operation, manager)
        result = type(result) == "table" and result or { success = false, reason = "invalid_operation" }
        result.operation = operation
        results[#results + 1] = result
        changed = changed or result.changed == true
    end
    if locked and type(manager.UnlockNotifications) == "function" then
        pcall(manager.UnlockNotifications, manager, true)
    end

    local rollbackFailed = false
    for _, result in ipairs(results) do
        if result.reason == "replace_rollback_failed" then
            rollbackFailed = true
            break
        end
    end
    if rollbackFailed then
        for index = #results, 1, -1 do
            local result = results[index]
            if result.success and result.changed then
                if not RestoreSoundSnapshots(
                    manager,
                    result.operation.cooldownID,
                    result.operation.eventType,
                    result.previousSounds or {}
                ) then
                    result.reason = "replace_rollback_failed"
                else
                    result.reason = "batch_rollback"
                end
                result.success = false
            end
        end
    end
    local saved = not rollbackFailed
    if saved and changed then
        saved = type(manager.SaveLayouts) == "function" and pcall(manager.SaveLayouts, manager)
    end
    if not saved then
        local batchFailureReason = rollbackFailed and "replace_rollback_failed" or "save_failed"
        if not rollbackFailed then
            for index = #results, 1, -1 do
                local result = results[index]
                if result.success and result.changed then
                    if not RestoreSoundSnapshots(
                        manager,
                        result.operation.cooldownID,
                        result.operation.eventType,
                        result.previousSounds or {}
                    ) then
                        result.reason = "replace_rollback_failed"
                        batchFailureReason = "replace_rollback_failed"
                    else
                        result.reason = "save_failed"
                    end
                    result.success = false
                end
            end
        end
        self:EndCDMMutation()
        for _, result in ipairs(results) do
            if not result.success or result.changed then
                summary.failed = summary.failed + 1
            end
        end
        self.lastBatchResults = results
        self.lastBatchSummary = summary
        if options.deferRefresh ~= true then
            self:RefreshRuntimeData(options.reason or "batch_save_failed")
        end
        return false, summary, batchFailureReason
    end
    self:EndCDMMutation()

    for _, result in ipairs(results) do
        local operation = result.operation
        local sounds, targetCount = GetEventSounds(manager, operation.cooldownID, operation.eventType, operation.payload)
        local soundCount = type(sounds) == "table" and #sounds or 0
        if result.success and soundCount == 1 and targetCount == 1 then
            if result.mutationKind == "unchanged" then
                summary.alreadyLoaded = summary.alreadyLoaded + 1
            elseif summary[result.mutationKind] ~= nil then
                summary[result.mutationKind] = summary[result.mutationKind] + 1
            end
            summary.duplicateRemoved = summary.duplicateRemoved + (tonumber(result.duplicateRemoved) or 0)
        else
            result.success = false
            result.reason = result.reason or "add_verify_failed"
            summary.failed = summary.failed + 1
        end
    end
    self.lastBatchResults = results
    self.lastBatchSummary = summary
    if options.deferRefresh ~= true then
        self:RefreshRuntimeData(options.reason or "batch_saved")
    end
    return summary.failed == 0, summary
end

function Service:GetLastBatchSummary()
    return self.lastBatchSummary or NewBatchSummary()
end

function Service:GetLastBatchResults()
    return self.lastBatchResults or {}
end

function Service:SaveAndSyncVoicePreset(cooldownID, eventType, payload, expectedClassID, expectedSpecID, expectedCategory)
    local classID, specID = self:GetCurrentClassSpec()
    if (expectedClassID and tonumber(expectedClassID) ~= classID)
        or (expectedSpecID and tonumber(expectedSpecID) ~= specID) then
        return false, "spec_changed"
    end
    local currentCategory = self:FindCategoryForCooldown(cooldownID)
    if not currentCategory or (expectedCategory and tostring(expectedCategory) ~= tostring(currentCategory)) then
        return false, "invalid_cooldown"
    end
    local canConfigure, reason = self:CanConfigureSound(cooldownID, eventType, payload)
    if not canConfigure then
        return false, reason
    end
    local cooldownInfo = self:GetCooldownInfo(cooldownID)
    local voiceItem = Registry and Registry:GetItemForPayload(payload)
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if not cooldownInfo or not voiceItem or not store or type(store.SaveAppliedRecord) ~= "function" then
        return false, "data_not_ready"
    end
    local recordKey, recordOrError = store:SaveAppliedRecord({
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
    })
    if not recordKey then
        return false, recordOrError or "save_failed"
    end
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if IsInCombat() then
        self:RefreshRuntimeData("preset_saved_combat")
        return true, recordKey, "combat"
    end
    if not sync or type(sync.RunCurrentSpecSync) ~= "function" then
        self:RefreshRuntimeData("preset_saved_deferred")
        return true, recordKey, "deferred", nil, "not_available"
    end
    local ok, summary, reason = sync:RunCurrentSpecSync("user_saved", { capture = false })
    if ok then
        return true, recordKey, "synced", summary
    end
    sync:ScheduleSync("user_saved_retry", { capture = false })
    self:RefreshRuntimeData("preset_saved_deferred")
    return true, recordKey, "deferred", summary, reason
end

function Service:SaveVoicePresetOnly(...)
    return self:SaveAndSyncVoicePreset(...)
end

function Service:ApplySoundAlert(cooldownID, eventType, payload, expectedClassID, expectedSpecID, expectedCategory)
    return self:SaveAndSyncVoicePreset(
        cooldownID, eventType, payload,
        expectedClassID, expectedSpecID, expectedCategory
    )
end

function Service:DeleteSoundAlert(cooldownID, eventType, payload, expectedClassID, expectedSpecID)
    if IsInCombat() then
        return false, "combat"
    end
    local classID, specID = self:GetCurrentClassSpec()
    if (expectedClassID and tonumber(expectedClassID) ~= classID)
        or (expectedSpecID and tonumber(expectedSpecID) ~= specID) then
        return false, "spec_changed"
    end
    local alerts = self:GetAlerts(cooldownID)
    local manager = GetLayoutManager()
    if type(alerts) ~= "table" or not manager then
        return false, "data_not_ready"
    end
    if not Registry or not Registry:IsOwnedPayload(payload) then
        return false, "invalid_payload"
    end
    local targets = {}
    local eventSounds = {}
    for _, alert in ipairs(alerts) do
        if GetAlertType(alert) == GetSoundAlertType()
            and tonumber(GetAlertEvent(alert)) == tonumber(eventType) then
            eventSounds[#eventSounds + 1] = alert
        end
        if AlertMatches(alert, eventType, payload) then
            targets[#targets + 1] = alert
        end
    end
    if #targets == 0 then
        return true, "already_absent"
    end

    local ownsMutation = not self:IsInternalCDMMutation()
    if ownsMutation then
        self:BeginCDMMutation("qfx_delete")
    end
    local locked = false
    if type(manager.LockNotifications) == "function" then
        locked = pcall(manager.LockNotifications, manager)
    end
    local snapshots = SnapshotSounds(eventSounds) or {}
    local removed = 0
    for _, target in ipairs(targets) do
        if ManagerCallSucceeded(manager.RemoveAlert, manager, tonumber(cooldownID), target) then
            removed = removed + 1
        end
    end
    local remaining = self:GetAlerts(cooldownID)
    local targetStillPresent = false
    for _, alert in ipairs(type(remaining) == "table" and remaining or {}) do
        if AlertMatches(alert, eventType, payload) then
            targetStillPresent = true
            break
        end
    end
    if locked and type(manager.UnlockNotifications) == "function" then
        pcall(manager.UnlockNotifications, manager, true)
    end
    if removed ~= #targets or targetStillPresent then
        local restored = RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots)
        if ownsMutation then
            self:EndCDMMutation()
        end
        return false, restored and "delete_failed" or "delete_rollback_failed"
    end
    local saved = type(manager.SaveLayouts) == "function" and pcall(manager.SaveLayouts, manager)
    if not saved then
        local restored = RestoreSoundSnapshots(manager, cooldownID, eventType, snapshots)
        if ownsMutation then
            self:EndCDMMutation()
        end
        return false, restored and "save_failed" or "delete_rollback_failed"
    end
    if ownsMutation then
        self:EndCDMMutation()
    end
    self:ClearPendingRuntimeReload()
    return true
end

function Service:ClearPendingRuntimeReload()
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    local state = store and type(store.GetSyncState) == "function" and store:GetSyncState() or nil
    if type(state) == "table" then
        state.pendingRuntimeReload = false
    end
    return true
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
    local statusDisplay = {
        loaded = { loadState = "green", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_LOADED" },
        pending = { loadState = "yellow", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_PENDING" },
        syncFailed = { loadState = "orange", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_SYNC_FAILED" },
        eventUnsupported = { loadState = "orange", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_EVENT_UNSUPPORTED" },
        voiceMissing = { loadState = "gray", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_VOICE_MISSING" },
        skillMissing = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_STATUS_SKILL_MISSING" },
        ambiguousSkill = { loadState = "red", isLoaded = false, displaySection = "unloaded", localeKey = "CDM_STATUS_AMBIGUOUS_SKILL" },
    }
    local result = {}
    for _, record in ipairs(store:GetEffectiveRecords(classID, specID)) do
        local evaluation = sync:EvaluateRecord(record)
        local display = statusDisplay[evaluation.status] or statusDisplay.skillMissing
        local info = evaluation.info or {}
        local spellID = tonumber(record.spellID) or 0
        local eventType = tonumber(evaluation.eventType)
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
        local voiceName = tostring(record.voiceName or "")
        if voiceName == "" and evaluation.voiceItem then
            voiceName = tostring(evaluation.voiceItem.name or "")
        end
        if voiceName == "" then
            voiceName = L("CDM_MISSING_VOICE")
        end
        local statusText = L(display.localeKey)
        result[#result + 1] = {
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
            voicePayload = evaluation.voiceItem and tonumber(evaluation.voiceItem.payload) or nil,
            currentPayload = evaluation.currentPayload,
            spellName = info.spellName or GetSpellName(spellID) or L("CDM_UNKNOWN_SKILL", spellID),
            icon = info.icon or GetSpellIcon(spellID),
            eventText = eventText,
            statusText = statusText,
            soundDetail = eventText .. " | " .. voiceName,
            runtimeStatus = evaluation.status,
            runtimeReason = evaluation.status,
            loadState = display.loadState,
            isLoaded = display.isLoaded,
            displaySection = display.displaySection,
            isVirtual = true,
            canDrag = false,
        }
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

function Service:DeleteSoundAlertByKey(key)
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
        local evaluation = sync and sync:EvaluateRecord(record) or { status = "skillMissing" }
        local targetPayload = evaluation.voiceItem and tonumber(evaluation.voiceItem.payload)
            or tonumber(record.payloadHint)
        if targetPayload and (not Registry or not Registry:IsOwnedPayload(targetPayload)) then
            targetPayload = nil
        end
        self:BeginCDMMutation("qfx_delete")
        local snapshot, mutationError = store:RemoveOrDisableRecord(parsed.classID, parsed.specID, parsed.recordKey)
        if not snapshot then
            self:EndCDMMutation()
            return false, mutationError or "delete_failed"
        end
        if evaluation.cooldownID and evaluation.eventType and targetPayload then
            local ok, reason = self:DeleteSoundAlert(
                evaluation.cooldownID,
                evaluation.eventType,
                targetPayload,
                parsed.classID,
                parsed.specID
            )
            if not ok then
                store:RestoreRecordMutation(snapshot)
                if sync then
                    sync.runtimeFailures = sync.runtimeFailures or {}
                    local runtimeKey = string.format(
                        "%d:%d:%s",
                        parsed.classID,
                        parsed.specID,
                        tostring(parsed.recordKey)
                    )
                    sync.runtimeFailures[runtimeKey] = reason or "sync_failed"
                end
                self:EndCDMMutation()
                self:RefreshRuntimeData("delete_rollback")
                return false, reason
            end
            self:EndCDMMutation()
            self:RefreshRuntimeData("preset_deleted")
            return true, reason
        end
        self:EndCDMMutation()
        self:RefreshRuntimeData("preset_deleted")
        return true
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
    local ok, reason = self:DeleteSoundAlert(
        parsed.cooldownID,
        parsed.eventType,
        parsed.payload,
        parsed.classID,
        parsed.specID
    )
    if not ok then
        return false, reason
    end
    if store and recordKey then
        store:RemoveRecord(parsed.classID, parsed.specID, recordKey)
        if store:IsBuiltInRecord(parsed.classID, parsed.specID, recordKey) then
            store:DisableBuiltInRecord(parsed.classID, parsed.specID, recordKey)
        end
    end
    self:RefreshRuntimeData("preset_deleted")
    return true, reason
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
