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

local function CopyApplyPlan(plan)
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
        }, ":")
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
    state.lastApplyError = tostring(reason or "apply_failed")
    state.errorNeedsReport = mutationStarted == true
    state.failedRecordKeys = type(state.failedRecordKeys) == "table" and state.failedRecordKeys or {}
    for _, operation in ipairs(type(plan) == "table" and plan or {}) do
        if operation.kind == "set" then
            state.failedRecordKeys[operation.runtimeKey or tostring(operation.recordKey)] = state.lastApplyError
        end
    end
end

local function SnapshotKey(operation)
    return string.format("%s:%s", tostring(operation.cooldownID), tostring(operation.eventType))
end

function Service:ApplyCDMPlanAndReload(plan, options)
    plan = type(plan) == "table" and plan or {}
    options = type(options) == "table" and options or {}
    local summary = NewBatchSummary(options.summary)
    summary.removed = tonumber(options.summary and options.summary.removed) or 0
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

    local validated = {}
    local setTargets = {}
    local removalTargets = {}
    local snapshots = {}
    local changedCount = 0
    for _, rawOperation in ipairs(plan) do
        local operation = CopyApplyPlan({ rawOperation })[1]
        if not operation or tonumber(operation.classID) ~= tonumber(classID)
            or tonumber(operation.specID) ~= tonumber(specID)
            or not operation.cooldownID or not self:GetCooldownInfo(operation.cooldownID)
            or not operation.eventType or not self:IsValidEvent(operation.cooldownID, operation.eventType)
            or not operation.payload then
            return false, summary, "invalid_operation"
        end
        local pairKey = SnapshotKey(operation)
        if operation.kind == "set" then
            if setTargets[pairKey] and setTargets[pairKey] ~= operation.payload then
                return false, summary, "conflicting_targets"
            end
            if removalTargets[pairKey] and removalTargets[pairKey][operation.payload] then
                return false, summary, "conflicting_targets"
            end
            setTargets[pairKey] = operation.payload
            local canConfigure, alertOrReason = self:CanConfigureSound(
                operation.cooldownID,
                operation.eventType,
                operation.payload
            )
            if not canConfigure then
                return false, summary, alertOrReason or "target_alert_invalid"
            end
            operation.alert = alertOrReason
        elseif operation.kind == "remove" and Registry and Registry:IsOwnedPayload(operation.payload) then
            if setTargets[pairKey] == operation.payload then
                return false, summary, "conflicting_targets"
            end
            removalTargets[pairKey] = removalTargets[pairKey] or {}
            removalTargets[pairKey][operation.payload] = true
        else
            return false, summary, "invalid_operation"
        end
        if not snapshots[pairKey] then
            local eventSounds, _, readReason = GetEventSounds(
                manager, operation.cooldownID, operation.eventType, operation.payload
            )
            local snapshot = SnapshotSounds(eventSounds)
            if type(snapshot) ~= "table" then
                return false, summary, readReason or "read_failed"
            end
            snapshots[pairKey] = {
                cooldownID = operation.cooldownID,
                eventType = operation.eventType,
                sounds = snapshot,
            }
        end
        local currentSounds, targetCount = GetEventSounds(
            manager, operation.cooldownID, operation.eventType, operation.payload
        )
        if type(currentSounds) ~= "table" then
            return false, summary, "read_failed"
        end
        if operation.kind == "set" then
            operation.changed = not (#currentSounds == 1 and targetCount == 1)
        else
            operation.changed = targetCount > 0
        end
        operation.currentSounds = currentSounds
        if operation.changed then
            changedCount = changedCount + 1
        end
        validated[#validated + 1] = operation
    end

    if changedCount == 0 then
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
    applyState.plan = CopyApplyPlan(validated)

    self:BeginCDMMutation("qfx_explicit_apply")
    if type(manager.LockNotifications) == "function"
        and not ManagerCallSucceeded(manager.LockNotifications, manager) then
        self:EndCDMMutation()
        SetApplyFailure(store, validated, "lock_failed", false)
        return false, summary, "lock_failed"
    end

    local mutationStarted = false
    local results = {}
    local failureReason

    -- Removal phase. Keeping every RemoveAlert ahead of every AddAlert makes the
    -- mutation boundary deterministic and prevents a later record from seeing a
    -- partially rebuilt target as its input state.
    local removedAlerts = {}
    for _, operation in ipairs(validated) do
        if operation.changed then
            local removed = 0
            for _, alert in ipairs(operation.currentSounds or {}) do
                local shouldRemove = operation.kind == "set"
                    or tonumber(GetAlertPayload(alert)) == tonumber(operation.payload)
                if shouldRemove and not removedAlerts[alert] then
                    mutationStarted = true
                    if not ManagerCallSucceeded(manager.RemoveAlert, manager, operation.cooldownID, alert) then
                        failureReason = "remove_failed"
                        break
                    end
                    removedAlerts[alert] = true
                    removed = removed + 1
                end
            end
            if failureReason then
                break
            end
            local remainingSounds, remainingTargets = GetEventSounds(
                manager, operation.cooldownID, operation.eventType, operation.payload
            )
            if type(remainingSounds) ~= "table"
                or (operation.kind == "set" and #remainingSounds ~= 0)
                or (operation.kind == "remove" and tonumber(remainingTargets) ~= 0) then
                failureReason = "remove_verify_failed"
                break
            end
            if operation.kind == "remove" then
                summary.removed = summary.removed + removed
            end
        end
    end

    -- Addition phase. Target alerts were created and validated before the
    -- notification lock, so this phase only performs the already-approved writes.
    if not failureReason then
        local addedPairs = {}
        for _, operation in ipairs(validated) do
            local pairKey = SnapshotKey(operation)
            if operation.kind == "set" and operation.changed and not addedPairs[pairKey] then
                mutationStarted = true
                if not ManagerCallSucceeded(
                    manager.AddAlert, manager, operation.cooldownID, operation.alert
                ) then
                    failureReason = "add_failed"
                    break
                end
                addedPairs[pairKey] = true
            end
        end
    end

    if not failureReason then
        for _, operation in ipairs(validated) do
            local sounds, targetCount = GetEventSounds(
                manager, operation.cooldownID, operation.eventType, operation.payload
            )
            if operation.kind == "set" and (type(sounds) ~= "table" or #sounds ~= 1 or targetCount ~= 1) then
                failureReason = "add_verify_failed"
                break
            elseif operation.kind == "remove" and tonumber(targetCount) ~= 0 then
                failureReason = "remove_verify_failed"
                break
            end
        end
    end

    if not failureReason then
        for _, operation in ipairs(validated) do
            local result = {
                success = true,
                changed = operation.changed == true,
                operation = operation,
            }
            if not operation.changed then
                summary.alreadyLoaded = summary.alreadyLoaded + 1
            elseif operation.kind == "set" then
                local previousCount = #(operation.currentSounds or {})
                result.mutationKind = previousCount == 0 and "added"
                    or (previousCount > 1 and "deduplicated" or "replaced")
                result.duplicateRemoved = result.mutationKind == "deduplicated"
                    and math.max(0, previousCount - 1) or 0
                summary[result.mutationKind] = (tonumber(summary[result.mutationKind]) or 0) + 1
                summary.duplicateRemoved = summary.duplicateRemoved + result.duplicateRemoved
            end
            results[#results + 1] = result
        end
    end

    if not failureReason and not ManagerCallSucceeded(manager.SaveLayouts, manager) then
        failureReason = "save_failed"
    end

    if failureReason then
        local rollbackOK = true
        if mutationStarted then
            for _, snapshot in pairs(snapshots) do
                if not RestoreSoundSnapshots(manager, snapshot.cooldownID, snapshot.eventType, snapshot.sounds) then
                    rollbackOK = false
                end
            end
        end
        if not rollbackOK then
            failureReason = "rollback_failed"
        end
        summary.failed = summary.failed + 1
        self.lastBatchResults = results
        self.lastBatchSummary = summary
        SetApplyFailure(store, validated, failureReason, mutationStarted)
        self:EndCDMMutation()
        if mutationStarted then
            ReloadNow()
        end
        return false, summary, failureReason
    end

    self.lastBatchResults = results
    self.lastBatchSummary = summary
    ReloadNow()
    self:EndCDMMutation()
    return true, summary, "reload_requested"
end

function Service:ApplySoundAlertsBatch(operations, options)
    options = type(options) == "table" and options or {}
    if options.explicit ~= true then
        return false, NewBatchSummary(options.summary), "explicit_apply_required"
    end
    return self:ApplyCDMPlanAndReload(operations, options)
end

function Service:GetLastBatchSummary()
    return self.lastBatchSummary or NewBatchSummary()
end

function Service:GetLastBatchResults()
    return self.lastBatchResults or {}
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
    local record, reason
    if type(cooldownID) == "table" then
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
    local recordKey, savedRecord = store and store:SaveAppliedRecord(record)
    if not recordKey then
        return false, savedRecord or "save_failed"
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

function Service:DeleteSoundAlert(cooldownID, eventType, payload, expectedClassID, expectedSpecID)
    local classID, specID = self:GetCurrentClassSpec()
    if (expectedClassID and tonumber(expectedClassID) ~= classID)
        or (expectedSpecID and tonumber(expectedSpecID) ~= specID) then
        return false, "spec_changed"
    end
    if not cooldownID or not eventType or not payload then
        return false, "invalid_operation"
    end
    return false, "explicit_apply_required"
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
        loaded = { loadState = "green", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_APPLIED" },
        pending = { loadState = "yellow", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_PENDING" },
        applyFailed = { loadState = "orange", isLoaded = true, displaySection = "loaded", localeKey = "CDM_STATUS_APPLY_FAILED" },
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
        local snapshot, mutationError = store:RemoveOrDisableRecord(
            parsed.classID,
            parsed.specID,
            parsed.recordKey,
            { createPendingRemoval = evaluation.hasTargetSound == true }
        )
        if not snapshot then
            return false, mutationError or "delete_failed"
        end
        self:RefreshRuntimeData("preset_deleted_local")
        if sync and type(sync.ScheduleEvaluation) == "function" then
            sync:ScheduleEvaluation("preset_deleted_local")
        end
        return true, snapshot.pendingRemoval and "pending_removal" or "local_deleted"
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
    if store and recordKey then
        local existing = store:GetEffectiveRecord(parsed.classID, parsed.specID, recordKey)
        if existing then
            local snapshot, reason = store:RemoveOrDisableRecord(
                parsed.classID,
                parsed.specID,
                recordKey,
                { createPendingRemoval = true }
            )
            if not snapshot then
                return false, reason or "delete_failed"
            end
        elseif info and category and Registry then
            local voice = Registry:GetItemForPayload(parsed.payload)
            if voice then
                store:SetPendingRemoval({
                    classID = parsed.classID,
                    specID = parsed.specID,
                    category = category,
                    spellID = info.spellID,
                    eventKey = store:EventTypeToKey(parsed.eventType),
                    eventTypeHint = parsed.eventType,
                    voiceIdentity = voice.identity,
                    voiceName = voice.name,
                    voicePath = voice.path,
                    payloadHint = parsed.payload,
                    cooldownIDHint = parsed.cooldownID,
                    source = "user",
                })
            end
        end
    end
    self:RefreshRuntimeData("preset_deleted_local")
    local sync = NS.Core and NS.Core.CDMVoicePresetSync
    if sync and type(sync.ScheduleEvaluation) == "function" then
        sync:ScheduleEvaluation("preset_deleted_local")
    end
    return true, "pending_removal"
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
