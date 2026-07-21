local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoicePresetSync = NS.Core.CDMVoicePresetSync or {}

local Sync = NS.Core.CDMVoicePresetSync

local function GetService()
    return NS.Core and NS.Core.CDMVoiceService
end

local function GetStore()
    return NS.Core and NS.Core.CDMVoicePresetStore
end

local function L(key, ...)
    if type(NS.L) == "function" then
        return NS.L(key, ...)
    end
    return tostring(key)
end

local function IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function NewSummary()
    return {
        added = 0,
        replaced = 0,
        deduplicated = 0,
        removed = 0,
        duplicateRemoved = 0,
        alreadyLoaded = 0,
        missingSkill = 0,
        missingVoice = 0,
        unsupportedEvent = 0,
        ambiguousSkill = 0,
        applyFailed = 0,
        failed = 0,
        pending = 0,
        pendingRemoval = 0,
        pendingCount = 0,
    }
end

local function AlertValue(alert, functionName, index)
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

local function ContainsSpellID(values, spellID)
    if type(values) ~= "table" then
        return false
    end
    for key, value in pairs(values) do
        if tonumber(value) == spellID or (value == true and tonumber(key) == spellID) then
            return true
        end
    end
    return false
end

local function MatchScore(info, record)
    local spellID = tonumber(record and record.spellID)
    if not spellID or type(info) ~= "table" then
        return nil
    end
    if tonumber(record.cooldownIDHint)
        and tonumber(info.cooldownID) == tonumber(record.cooldownIDHint) then
        return 0
    end
    if tonumber(info.baseSpellID) == spellID or tonumber(info.spellID) == spellID then
        return 1
    end
    if tonumber(info.overrideSpellID) == spellID or tonumber(info.overrideTooltipSpellID) == spellID then
        return 2
    end
    if ContainsSpellID(info.linkedSpellIDs, spellID) then
        return 3
    end
    return nil
end

local function RuntimeFailureKey(record)
    if type(record) ~= "table" or not record.recordKey then
        return nil
    end
    return string.format(
        "%s:%s:%s",
        tostring(tonumber(record.classID) or "?"),
        tostring(tonumber(record.specID) or "?"),
        tostring(record.recordKey)
    )
end

local function ScopeKey(classID, specID)
    return string.format("%s:%s", tostring(tonumber(classID) or "?"), tostring(tonumber(specID) or "?"))
end

local function CountTable(values)
    local count = 0
    for _ in pairs(type(values) == "table" and values or {}) do
        count = count + 1
    end
    return count
end

local function PendingSignature(plan)
    local parts = {}
    for _, operation in ipairs(type(plan) == "table" and plan or {}) do
        parts[#parts + 1] = table.concat({
            tostring(operation.kind or "set"),
            tostring(operation.recordKey or ""),
            tostring(operation.action or ""),
            tostring(operation.payload or ""),
        }, ":")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function Sync:BuildCooldownCatalog()
    local service = GetService()
    local catalog = { byCategory = {}, all = {} }
    if not service then
        return catalog
    end
    local seen = {}
    for _, category in ipairs(service:GetCategories() or {}) do
        local cooldowns = service:GetCooldownsForCategory(category.key) or {}
        catalog.byCategory[tostring(category.key or "")] = cooldowns
        if category.category ~= nil then
            catalog.byCategory[tostring(category.category)] = cooldowns
        end
        for _, info in ipairs(cooldowns) do
            local cooldownID = tonumber(info and info.cooldownID)
            if cooldownID and not seen[cooldownID] then
                seen[cooldownID] = true
                catalog.all[#catalog.all + 1] = info
            end
        end
    end
    return catalog
end

function Sync:FindCooldownForRecord(record, cooldownCatalog)
    local service = GetService()
    if not service or type(record) ~= "table" then
        return nil, "skillMissing"
    end
    local bestScore
    local candidates = {}
    local cooldowns = type(cooldownCatalog) == "table"
        and type(cooldownCatalog.byCategory) == "table"
        and cooldownCatalog.byCategory[tostring(record.category or "")]
        or nil
    if type(cooldowns) ~= "table" then
        cooldowns = service:GetCooldownsForCategory(record.category) or {}
    end
    for _, info in ipairs(cooldowns) do
        local score = MatchScore(info, record)
        if score and (not bestScore or score < bestScore) then
            bestScore = score
            candidates = { info }
        elseif score and score == bestScore then
            candidates[#candidates + 1] = info
        end
    end
    if #candidates == 0 then
        return nil, "skillMissing"
    end
    if #candidates > 1 then
        return nil, "ambiguousSkill"
    end
    return candidates[1]
end

local function AddSpellID(set, value)
    value = tonumber(value)
    if value then
        set[value] = true
    end
end

local function BuildSpellIDSet(info, recordSpellID)
    local result = {}
    if type(info) == "table" then
        AddSpellID(result, info.spellID)
        AddSpellID(result, info.baseSpellID)
        AddSpellID(result, info.overrideSpellID)
        AddSpellID(result, info.overrideTooltipSpellID)
        for key, value in pairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}) do
            AddSpellID(result, value)
            if value == true then
                AddSpellID(result, key)
            end
        end
    end
    AddSpellID(result, recordSpellID)
    return result
end

local function SpellIDSetsOverlap(left, right)
    for spellID in pairs(left) do
        if right[spellID] then
            return true
        end
    end
    return false
end

local function CopyCooldownInfo(info, categoryKey)
    if type(info) ~= "table" or not tonumber(info.cooldownID) then
        return nil
    end
    return {
        cooldownID = tonumber(info.cooldownID),
        category = tostring(info.categoryKey or categoryKey or ""),
        spellID = tonumber(info.spellID),
        baseSpellID = tonumber(info.baseSpellID),
        overrideSpellID = tonumber(info.overrideSpellID),
        overrideTooltipSpellID = tonumber(info.overrideTooltipSpellID),
        linkedSpellIDs = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or nil,
        spellName = info.spellName,
        icon = info.icon,
    }
end

function Sync:FindEquivalentCooldownsForRecord(record, preferredInfo, cooldownCatalog)
    local service = GetService()
    if not service or type(record) ~= "table" then
        return {}
    end
    preferredInfo = type(preferredInfo) == "table" and preferredInfo
        or self:FindCooldownForRecord(record, cooldownCatalog)
    local targetIDs = BuildSpellIDSet(preferredInfo, record.spellID)
    local result, seen = {}, {}
    local function Add(info, categoryKey)
        local copy = CopyCooldownInfo(info, categoryKey)
        if copy and not seen[copy.cooldownID] then
            seen[copy.cooldownID] = true
            result[#result + 1] = copy
        end
    end
    Add(preferredInfo, record.category)
    if type(cooldownCatalog) == "table" and type(cooldownCatalog.all) == "table" then
        for _, info in ipairs(cooldownCatalog.all) do
            local directHint = tonumber(record.cooldownIDHint) == tonumber(info.cooldownID)
            local candidateIDs = BuildSpellIDSet(info)
            if directHint or SpellIDSetsOverlap(targetIDs, candidateIDs) then
                Add(info, info.categoryKey)
            end
        end
    else
        for _, category in ipairs(service:GetCategories() or {}) do
            for _, info in ipairs(service:GetCooldownsForCategory(category.key) or {}) do
                local directHint = tonumber(record.cooldownIDHint) == tonumber(info.cooldownID)
                local candidateIDs = BuildSpellIDSet(info)
                if directHint or SpellIDSetsOverlap(targetIDs, candidateIDs) then
                    Add(info, category.key)
                end
            end
        end
    end
    return result
end

local function EquivalentCooldownIDs(equivalents)
    local result = {}
    for _, info in ipairs(type(equivalents) == "table" and equivalents or {}) do
        if tonumber(info.cooldownID) then
            result[#result + 1] = tonumber(info.cooldownID)
        end
    end
    return result
end

local function CountEventSounds(service, cooldownID, eventType, targetPayload)
    local alerts, readReason = service:GetAlerts(cooldownID)
    if type(alerts) ~= "table" then
        return nil, nil, nil, readReason or "data_not_ready"
    end
    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    local soundCount, targetCount, firstPayload = 0, 0, nil
    for _, alert in ipairs(alerts) do
        if AlertValue(alert, "CooldownViewerAlert_GetType", 1) == soundType
            and tonumber(AlertValue(alert, "CooldownViewerAlert_GetEvent", 2)) == tonumber(eventType) then
            soundCount = soundCount + 1
            local payload = tonumber(AlertValue(alert, "CooldownViewerAlert_GetPayload", 3))
            firstPayload = firstPayload or payload
            if targetPayload ~= nil and payload == tonumber(targetPayload) then
                targetCount = targetCount + 1
            end
        end
    end
    return soundCount, targetCount, firstPayload
end

function Sync:BuildTargetForRecord(record)
    local store = GetStore()
    local info = self:FindCooldownForRecord(record)
    local voice = store and store:ResolveVoice(record) or nil
    local eventType = store and store:EventKeyToType(record.eventKey, record.eventTypeHint) or nil
    if not info or not voice or not tonumber(eventType) or not tonumber(voice.payload) then
        return nil
    end
    return {
        cooldownID = tonumber(info.cooldownID),
        eventType = tonumber(eventType),
        payload = tonumber(voice.payload),
    }
end

function Sync:EvaluateRecord(record, cooldownCatalog)
    local evaluation = {
        record = record,
        status = "skillMissing",
        hasAnySound = false,
        hasTargetSound = false,
        soundCount = 0,
        targetCount = 0,
        equivalentSoundCount = 0,
    }
    local service, store = GetService(), GetStore()
    if not service or not store or type(record) ~= "table" then
        return evaluation
    end
    local info, matchError = self:FindCooldownForRecord(record, cooldownCatalog)
    if not info then
        evaluation.status = matchError or "skillMissing"
        return evaluation
    end
    evaluation.info = info
    evaluation.cooldownID = tonumber(info.cooldownID)
    evaluation.eventType = tonumber(store:EventKeyToType(record.eventKey, record.eventTypeHint))
    if not evaluation.eventType or not service:IsValidEvent(info.cooldownID, evaluation.eventType) then
        evaluation.status = "eventUnsupported"
        return evaluation
    end
    evaluation.voiceItem = store:ResolveVoice(record)
    if not evaluation.voiceItem or not tonumber(evaluation.voiceItem.payload) then
        evaluation.status = "voiceMissing"
        return evaluation
    end
    evaluation.targetPayload = tonumber(evaluation.voiceItem.payload)
    evaluation.equivalentCooldowns = self:FindEquivalentCooldownsForRecord(record, info, cooldownCatalog)
    evaluation.equivalentCooldownIDs = EquivalentCooldownIDs(evaluation.equivalentCooldowns)
    if #evaluation.equivalentCooldownIDs == 0 then
        evaluation.status = "skillMissing"
        return evaluation
    end
    evaluation.soundCountsByCooldown = {}
    for _, equivalent in ipairs(evaluation.equivalentCooldowns) do
        local cooldownID = tonumber(equivalent.cooldownID)
        local soundCount, targetCount, firstPayload, readReason = CountEventSounds(
            service, cooldownID, evaluation.eventType,
            cooldownID == evaluation.cooldownID and evaluation.targetPayload or nil
        )
        if soundCount == nil then
            evaluation.status = "dataNotReady"
            evaluation.failureReason = readReason
            return evaluation
        end
        evaluation.soundCountsByCooldown[cooldownID] = soundCount
        evaluation.hasAnySound = evaluation.hasAnySound or soundCount > 0
        if cooldownID == evaluation.cooldownID then
            evaluation.soundCount = soundCount
            evaluation.targetCount = targetCount
            evaluation.hasTargetSound = targetCount > 0
            evaluation.currentPayload = firstPayload
        else
            evaluation.equivalentSoundCount = evaluation.equivalentSoundCount + soundCount
        end
    end
    local applyState = store:GetApplyState()
    local failureKey = RuntimeFailureKey(record)
    local failedKeys = type(applyState.failedRecordKeys) == "table" and applyState.failedRecordKeys or {}
    if failureKey and failedKeys[failureKey] then
        evaluation.status = "applyFailed"
        evaluation.failureReason = failedKeys[failureKey]
    elseif evaluation.soundCount == 1 and evaluation.targetCount == 1
        and evaluation.equivalentSoundCount == 0 then
        evaluation.status = "loaded"
    else
        evaluation.status = "pending"
        if evaluation.equivalentSoundCount > 0 then
            evaluation.pendingReason = "duplicate_equivalent_cooldown_sound"
        elseif evaluation.soundCount > 1 then
            evaluation.pendingReason = "duplicate_sound"
        elseif evaluation.targetCount ~= 1 then
            evaluation.pendingReason = "target_mismatch"
        end
    end
    if evaluation.status == "pending" or evaluation.status == "applyFailed" then
        if evaluation.soundCount == 0 then
            evaluation.action = "add"
        elseif evaluation.soundCount > 1 or evaluation.equivalentSoundCount > 0 then
            evaluation.action = "deduplicate"
        else
            evaluation.action = "replace"
        end
    else
        evaluation.action = "unchanged"
    end
    return evaluation
end

function Sync:EvaluatePendingRemoval(record, cooldownCatalog)
    local evaluation = { record = record, status = "pendingRemoval", targetPresent = false }
    local service, store = GetService(), GetStore()
    if not service or not store or type(record) ~= "table" then
        evaluation.status = "invalidRemoval"
        return evaluation
    end
    local info = self:FindCooldownForRecord(record, cooldownCatalog)
    if not info and tonumber(record.cooldownIDHint) then
        info = service:GetCooldownInfo(record.cooldownIDHint)
    end
    evaluation.info = info
    evaluation.cooldownID = tonumber(info and info.cooldownID) or tonumber(record.cooldownIDHint)
    evaluation.eventType = tonumber(store:EventKeyToType(record.eventKey, record.eventTypeHint))
    evaluation.equivalentCooldowns = self:FindEquivalentCooldownsForRecord(record, info, cooldownCatalog)
    evaluation.equivalentCooldownIDs = EquivalentCooldownIDs(evaluation.equivalentCooldowns)
    if not evaluation.cooldownID or not evaluation.eventType or #evaluation.equivalentCooldownIDs == 0 then
        evaluation.status = "skillMissing"
        return evaluation
    end
    evaluation.soundCount = 0
    for _, cooldownID in ipairs(evaluation.equivalentCooldownIDs) do
        local soundCount, _, _, readReason = CountEventSounds(
            service, cooldownID, evaluation.eventType
        )
        if soundCount == nil then
            evaluation.status = "dataNotReady"
            evaluation.failureReason = readReason
            return evaluation
        end
        evaluation.soundCount = evaluation.soundCount + soundCount
    end
    evaluation.targetPresent = evaluation.soundCount > 0
    evaluation.action = evaluation.targetPresent and "remove_all_sounds" or "unchanged"
    return evaluation
end

function Sync:BuildPendingPlan(records, pendingRemovals)
    local summary, operations = NewSummary(), {}
    local service = GetService()
    records = type(records) == "table" and records or {}
    pendingRemovals = type(pendingRemovals) == "table" and pendingRemovals or {}
    -- A plan may evaluate several records for the same scope. Enumerating the
    -- Blizzard Cooldown Manager once per plan avoids repeating provider calls,
    -- spell-name lookups, and icon lookups for every saved record.
    local cooldownCatalog = (next(records) ~= nil or next(pendingRemovals) ~= nil)
        and self:BuildCooldownCatalog() or nil
    for _, record in ipairs(records) do
        local evaluation = self:EvaluateRecord(record, cooldownCatalog)
        if evaluation.status == "loaded" then
            summary.alreadyLoaded = summary.alreadyLoaded + 1
        elseif evaluation.status == "pending" or evaluation.status == "applyFailed" then
            local canConfigure, targetAlert = service:CanConfigureSound(
                evaluation.cooldownID, evaluation.eventType, evaluation.targetPayload
            )
            if canConfigure and type(targetAlert) == "table" then
                operations[#operations + 1] = {
                    kind = "set",
                    action = evaluation.action,
                    classID = tonumber(record.classID),
                    specID = tonumber(record.specID),
                    recordKey = record.recordKey,
                    runtimeKey = RuntimeFailureKey(record),
                    category = record.category,
                    spellID = tonumber(record.spellID),
                    eventKey = record.eventKey,
                    cooldownID = evaluation.cooldownID,
                    eventType = evaluation.eventType,
                    payload = evaluation.targetPayload,
                    equivalentCooldownIDs = evaluation.equivalentCooldownIDs,
                    targetAlert = targetAlert,
                }
                summary.pending = summary.pending + 1
                if evaluation.status == "applyFailed" then
                    summary.applyFailed = summary.applyFailed + 1
                end
            else
                summary.failed = summary.failed + 1
            end
        elseif evaluation.status == "skillMissing" then
            summary.missingSkill = summary.missingSkill + 1
        elseif evaluation.status == "voiceMissing" then
            summary.missingVoice = summary.missingVoice + 1
        elseif evaluation.status == "eventUnsupported" then
            summary.unsupportedEvent = summary.unsupportedEvent + 1
        elseif evaluation.status == "ambiguousSkill" then
            summary.ambiguousSkill = summary.ambiguousSkill + 1
        else
            summary.failed = summary.failed + 1
        end
    end
    for recordKey, record in pairs(pendingRemovals) do
        local evaluation = self:EvaluatePendingRemoval(record, cooldownCatalog)
        summary.pendingRemoval = summary.pendingRemoval + 1
        if evaluation.action == "remove_all_sounds" or evaluation.action == "unchanged" then
            operations[#operations + 1] = {
                kind = "remove",
                action = evaluation.action,
                classID = tonumber(record.classID),
                specID = tonumber(record.specID),
                recordKey = record.recordKey or recordKey,
                runtimeKey = RuntimeFailureKey(record),
                category = record.category,
                spellID = tonumber(record.spellID),
                eventKey = record.eventKey,
                cooldownID = evaluation.cooldownID,
                eventType = evaluation.eventType,
                equivalentCooldownIDs = evaluation.equivalentCooldownIDs,
            }
        elseif evaluation.status == "skillMissing" then
            summary.missingSkill = summary.missingSkill + 1
        else
            summary.failed = summary.failed + 1
        end
    end
    summary.pendingCount = #operations
    return operations, summary
end

function Sync:BuildSyncPlan(records)
    return self:BuildPendingPlan(records, {})
end

function Sync:GetCurrentSpecPendingSummary()
    local service, store = GetService(), GetStore()
    if not service or not store then
        return NewSummary(), {}, "not_available"
    end
    local classID, specID = service:GetCurrentClassSpec()
    if not classID or not specID then
        return NewSummary(), {}, "no_spec"
    end
    local records = store:GetEffectiveRecords(classID, specID)
    local removals = store:GetPendingRemovals(classID, specID)
    local plan, summary = self:BuildPendingPlan(records, removals)
    summary.classID = classID
    summary.specID = specID
    summary.pendingRemoval = CountTable(removals)
    summary.pendingCount = #plan
    return summary, plan
end

function Sync:VerifyPostReloadApply()
    local service, store = GetService(), GetStore()
    if not service or not store then
        return false, "not_available"
    end
    local state = store:GetApplyState()
    if state.applyInProgress ~= true then
        if state.errorNeedsReport == true and state.lastApplyError then
            state.errorNeedsReport = false
            print("[QFX-SA] " .. L("CDM_APPLY_FAILED") .. " " .. tostring(state.lastApplyError))
        end
        return true, "not_pending"
    end
    local classID, specID = service:GetCurrentClassSpec()
    if tonumber(state.classID) ~= tonumber(classID) or tonumber(state.specID) ~= tonumber(specID) then
        return false, "scope_mismatch"
    end

    local persistedPlan = type(state.plan) == "table" and state.plan or {}
    local cooldownCatalog = #persistedPlan > 0 and self:BuildCooldownCatalog() or nil
    local failedKeys = type(state.failedRecordKeys) == "table" and state.failedRecordKeys or {}
    local removalClears, allValid = {}, true
    for _, operation in ipairs(persistedPlan) do
        if operation.kind == "set" then
            local record = store:GetEffectiveRecord(classID, specID, operation.recordKey)
            local info = record and self:FindCooldownForRecord(record, cooldownCatalog) or nil
            local equivalents = record and info
                and self:FindEquivalentCooldownsForRecord(record, info, cooldownCatalog) or {}
            local voice = record and store:ResolveVoice(record) or nil
            local valid = record ~= nil and info ~= nil and #equivalents > 0
                and tonumber(voice and voice.payload) == tonumber(operation.payload)
            for _, equivalent in ipairs(equivalents) do
                local cooldownID = tonumber(equivalent.cooldownID)
                local soundCount, targetCount, _, readReason = CountEventSounds(
                    service, cooldownID, operation.eventType,
                    cooldownID == tonumber(info.cooldownID) and operation.payload or nil
                )
                if soundCount == nil then
                    return false, readReason
                end
                if cooldownID == tonumber(info.cooldownID) then
                    valid = valid and soundCount == 1 and targetCount == 1
                else
                    valid = valid and soundCount == 0
                end
            end
            if not valid then
                allValid = false
                failedKeys[operation.runtimeKey or tostring(operation.recordKey)] =
                    "post_reload_duplicate_sound_remaining"
            end
        elseif operation.kind == "remove" then
            local tombstone = store:GetPendingRemoval(classID, specID, operation.recordKey) or operation
            local info = self:FindCooldownForRecord(tombstone, cooldownCatalog)
            if not info and tonumber(tombstone.cooldownIDHint or operation.cooldownID) then
                info = service:GetCooldownInfo(tombstone.cooldownIDHint or operation.cooldownID)
            end
            local equivalents = self:FindEquivalentCooldownsForRecord(tombstone, info, cooldownCatalog)
            local valid = #equivalents > 0
            for _, equivalent in ipairs(equivalents) do
                local soundCount, _, _, readReason = CountEventSounds(
                    service, equivalent.cooldownID, operation.eventType
                )
                if soundCount == nil then
                    return false, readReason
                end
                valid = valid and soundCount == 0
            end
            if not valid then
                allValid = false
            else
                removalClears[#removalClears + 1] = operation.recordKey
            end
        end
    end
    state.applyInProgress = false
    state.plan = nil
    if allValid then
        for _, operation in ipairs(persistedPlan) do
            if operation.kind == "set" then
                failedKeys[operation.runtimeKey or tostring(operation.recordKey)] = nil
            end
        end
        for _, recordKey in ipairs(removalClears) do
            store:ClearPendingRemoval(classID, specID, recordKey)
        end
        state.lastApplyError = nil
        state.failedRecordKeys = failedKeys
        if not self.postReloadSuccessReported then
            self.postReloadSuccessReported = true
            print("[QFX-SA] " .. L("CDM_APPLY_RESULT_AFTER_RELOAD"))
        end
        return true, "verified"
    end
    state.lastApplyError = "post_reload_duplicate_sound_remaining"
    state.failedRecordKeys = failedKeys
    if not self.postReloadFailureReported then
        self.postReloadFailureReported = true
        print("[QFX-SA] " .. L("CDM_APPLY_VERIFY_FAILED"))
    end
    return false, state.lastApplyError
end

local function EnsurePendingPopup()
    if type(StaticPopupDialogs) ~= "table" or StaticPopupDialogs.QFXSKILLALERTS_CDM_PENDING then
        return
    end
    StaticPopupDialogs.QFXSKILLALERTS_CDM_PENDING = {
        text = "%s",
        button1 = L("CDM_APPLY_AND_RELOAD"),
        button2 = L("CDM_APPLY_LATER"),
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data)
            Sync:ApplyAllPendingCurrentSpecAndReload(
                type(data) == "table" and data.reason or "pending_prompt"
            )
        end,
    }
end

function Sync:PromptForPending(summary, kind, signature)
    summary = type(summary) == "table" and summary or {}
    if IsInCombat() or (tonumber(summary.pendingCount) or 0) <= 0 then
        return false
    end
    local scopeKey = ScopeKey(summary.classID, summary.specID)
    self.sessionPromptedScopes = self.sessionPromptedScopes or {}
    self.sessionPromptedSignatures = self.sessionPromptedSignatures or {}
    local promptKey
    if kind == "external" then
        signature = tostring(signature or scopeKey .. ":" .. tostring(summary.pendingCount))
        if self.sessionPromptedSignatures[signature] then
            return false
        end
    elseif kind == "import" then
        -- Import processing calls this once after the complete payload has been
        -- saved. Do not suppress a later, separate import in the same session.
        promptKey = nil
    else
        promptKey = tostring(kind or "scope") .. ":" .. scopeKey
    end
    if promptKey and self.sessionPromptedScopes[promptKey] then
        return false
    end

    EnsurePendingPopup()
    if type(StaticPopup_Show) ~= "function" then
        return false
    end
    local messageKey = kind == "import" and "CDM_IMPORT_PENDING_CONFIRM"
        or (kind == "external" and "CDM_EXTERNAL_CHANGE_PENDING" or "CDM_SCOPE_PENDING_CONFIRM")
    local message = L(messageKey, tonumber(summary.pendingCount) or 0)
    local dialog = StaticPopup_Show("QFXSKILLALERTS_CDM_PENDING", message, nil, {
        reason = kind or "pending_prompt",
    })
    if not dialog then
        return false
    end
    if kind == "external" then
        self.sessionPromptedSignatures[signature] = true
    elseif promptKey then
        self.sessionPromptedScopes[promptKey] = true
    end
    return true
end

function Sync:EvaluateCurrentSpec(reason, options)
    options = type(options) == "table" and options or {}
    local service, store = GetService(), GetStore()
    if not service or not store then
        return false, NewSummary(), "not_available"
    end
    self:InstallLayoutManagerHooks()
    local available, availabilityReason = service:IsAvailable()
    if not available then
        return false, NewSummary(), availabilityReason
    end
    local classID, specID = service:GetCurrentClassSpec()
    local scopeToken = options.scopeToken
    if type(scopeToken) == "table"
        and (tonumber(scopeToken.serial) ~= tonumber(self.scopeSerial)
            or tonumber(scopeToken.classID) ~= tonumber(classID)
            or tonumber(scopeToken.specID) ~= tonumber(specID)) then
        return false, NewSummary(), "stale_scope"
    end
    self:VerifyPostReloadApply()
    local summary, plan = self:GetCurrentSpecPendingSummary()
    self.lastSummary = summary
    self.lastPlan = plan
    self.lastReason = reason
    self.lastRunAt = type(GetTime) == "function" and GetTime() or 0
    if type(service.RefreshRuntimeData) == "function" then
        service:RefreshRuntimeData(reason or "cdm_evaluation")
    end
    if options.prompt == true then
        self:PromptForPending(summary, options.promptKind, options.signature or PendingSignature(plan))
    end
    return true, summary
end

function Sync:RunCurrentSpecSync(reason, options)
    return self:EvaluateCurrentSpec(reason or "compat_evaluate", options)
end

function Sync:ValidateAndSaveDrafts(drafts)
    local service, store = GetService(), GetStore()
    if not service or not store then
        return nil, "not_available"
    end
    local candidates, originalRecords = {}, {}
    for index, draft in ipairs(type(drafts) == "table" and drafts or {}) do
        local candidate, reason = service:ValidateCDMVoiceDraft(draft, { forApply = true })
        if not candidate then
            return nil, reason or "invalid_record", index
        end
        candidates[#candidates + 1] = candidate
        local originalRecordKey = type(draft) == "table" and draft.originalRecordKey or nil
        originalRecords[#originalRecords + 1] = {
            recordKey = originalRecordKey,
            record = originalRecordKey and store:GetEffectiveRecord(
                candidate.classID, candidate.specID, originalRecordKey
            ) or nil,
        }
    end
    local saved, changedKeys = {}, {}
    for index, candidate in ipairs(candidates) do
        local recordKey, record = store:SaveAppliedRecord(candidate)
        if not recordKey then
            return nil, record or "save_failed"
        end
        saved[#saved + 1] = record
        local original = originalRecords[index]
        if original.recordKey and original.recordKey ~= recordKey and original.record then
            local removed, removeReason = store:RemoveOrDisableRecord(
                candidate.classID, candidate.specID, original.recordKey,
                { createPendingRemoval = true }
            )
            if not removed then
                return nil, removeReason or "save_failed", index
            end
            changedKeys[#changedKeys + 1] = original.recordKey
        end
    end
    return saved, changedKeys
end

function Sync:ApplyPlanAndReload(plan, summary, reason)
    local service = GetService()
    if not service or type(service.ApplyCDMPlanAndReload) ~= "function" then
        return false, summary or NewSummary(), "not_available"
    end
    return service:ApplyCDMPlanAndReload(plan, {
        summary = summary,
        reason = reason or "explicit_apply",
        scopeToken = self:CaptureScopeToken(),
    })
end

function Sync:ApplySyncPlan(plan, summary, reason)
    return self:ApplyPlanAndReload(plan, summary, reason)
end

function Sync:ApplyCurrentDraftAndReload(draft)
    if IsInCombat() then
        return false, nil, "combat"
    end
    local saved, changedKeysOrReason, failedIndex = self:ValidateAndSaveDrafts({ draft })
    if not saved then
        return false, nil, changedKeysOrReason, failedIndex
    end
    local store = GetStore()
    local removals = {}
    for _, recordKey in ipairs(changedKeysOrReason or {}) do
        local tombstone = store:GetPendingRemoval(saved[1].classID, saved[1].specID, recordKey)
        if tombstone then
            removals[recordKey] = tombstone
        end
    end
    local plan, summary = self:BuildPendingPlan(saved, removals)
    if #plan == 0 then
        local service = GetService()
        if service then
            service:RefreshRuntimeData("draft_saved_already_applied")
        end
        return true, summary, "already_applied", saved[1] and saved[1].recordKey
    end
    local ok, result, applyReason = self:ApplyPlanAndReload(plan, summary, "row_apply")
    return ok, result, applyReason, saved[1] and saved[1].recordKey
end

function Sync:ApplyCurrentRecordAndReload(recordKey)
    local service, store = GetService(), GetStore()
    if not service or not store then
        return false, nil, "not_available"
    end
    local classID, specID = service:GetCurrentClassSpec()
    local record = store:GetEffectiveRecord(classID, specID, recordKey)
    if not record then
        return false, nil, "not_found"
    end
    local plan, summary = self:BuildPendingPlan({ record }, {})
    if #plan == 0 then
        return true, summary, "already_applied"
    end
    return self:ApplyPlanAndReload(plan, summary, "row_apply")
end

function Sync:ApplyPendingRemovalByKey(recordKey)
    if IsInCombat() then
        return false, nil, "combat"
    end
    local service, store = GetService(), GetStore()
    if not service or not store then
        return false, nil, "not_available"
    end
    local classID, specID = service:GetCurrentClassSpec()
    local tombstone = store:GetPendingRemoval(classID, specID, recordKey)
    if not tombstone then
        return false, nil, "not_found"
    end
    local plan, summary = self:BuildPendingPlan({}, { [recordKey] = tombstone })
    if #plan == 0 then
        return false, summary, "delete_failed"
    end
    if type(service.ApplyCDMRemovalPlanWithoutReload) ~= "function" then
        return false, summary, "not_available"
    end
    return service:ApplyCDMRemovalPlanWithoutReload(plan, {
        summary = summary,
        reason = "manual_delete",
        scopeToken = self:CaptureScopeToken(),
    })
end

function Sync:ApplyPendingRemovalByKeyAndReload(recordKey)
    return self:ApplyPendingRemovalByKey(recordKey)
end

function Sync:ApplyAllPendingCurrentSpecAndReload(reason, drafts)
    if IsInCombat() then
        return false, nil, "combat"
    end
    if type(drafts) == "table" and #drafts > 0 then
        local saved, saveReason, failedIndex = self:ValidateAndSaveDrafts(drafts)
        if not saved then
            return false, nil, saveReason, failedIndex
        end
    end
    local summary, plan = self:GetCurrentSpecPendingSummary()
    if #plan == 0 then
        return true, summary, "no_changes"
    end
    local removalOnly = true
    for _, operation in ipairs(plan) do
        if operation.kind ~= "remove" then
            removalOnly = false
            break
        end
    end
    local service = GetService()
    if removalOnly and service
        and type(service.ApplyCDMRemovalPlanWithoutReload) == "function" then
        return service:ApplyCDMRemovalPlanWithoutReload(plan, {
            summary = summary,
            reason = reason or "apply_all_removals",
            scopeToken = self:CaptureScopeToken(),
        })
    end
    return self:ApplyPlanAndReload(plan, summary, reason or "apply_all")
end

function Sync:AdvanceScope()
    self.scopeSerial = (tonumber(self.scopeSerial) or 0) + 1
    -- A queued prompt belongs to the scope that created it. The new scope event
    -- schedules its own prompt-capable evaluation immediately after this call.
    self.pendingEvaluationRequest = nil
    return self.scopeSerial
end

function Sync:ResetPromptForCurrentScope()
    local service = GetService()
    if not service then
        return false
    end
    local classID, specID = service:GetCurrentClassSpec()
    self.sessionPromptedScopes = self.sessionPromptedScopes or {}
    self.sessionPromptedScopes["scope:" .. ScopeKey(classID, specID)] = nil
    return true
end

function Sync:CaptureScopeToken()
    local service = GetService()
    local classID, specID
    if service then
        classID, specID = service:GetCurrentClassSpec()
    end
    return {
        serial = tonumber(self.scopeSerial) or 0,
        classID = tonumber(classID),
        specID = tonumber(specID),
    }
end

function Sync:InstallLayoutManagerHooks()
    local service = GetService()
    local manager = service and type(service.GetLayoutManager) == "function" and service:GetLayoutManager() or nil
    if not manager or type(manager.SaveLayouts) ~= "function" or type(hooksecurefunc) ~= "function" then
        return false
    end
    self.hookedLayoutManagers = self.hookedLayoutManagers or setmetatable({}, { __mode = "k" })
    if self.hookedLayoutManagers[manager] then
        return true
    end
    local ok = pcall(hooksecurefunc, manager, "SaveLayouts", function()
        local currentService = GetService()
        if currentService and currentService:IsInternalCDMMutation() then
            return
        end
        Sync:ScheduleEvaluation("cdm_layout_saved", {
            prompt = true,
            promptKind = "external",
        })
    end)
    if ok then
        self.hookedLayoutManagers[manager] = true
    end
    return ok
end

function Sync:ScheduleEvaluation(reason, options)
    options = type(options) == "table" and options or {}
    local scopeToken = self:CaptureScopeToken()
    local scopeSerial = tonumber(scopeToken.serial) or 0
    local request = self.pendingEvaluationRequest
    if type(request) ~= "table" or tonumber(request.scopeSerial) ~= scopeSerial then
        request = {
            scopeSerial = scopeSerial,
            reason = reason or "event",
        }
    else
        request.reason = reason or request.reason or "event"
    end
    -- Event bursts are debounced, but a later data/talent refresh must not
    -- downgrade a prompt-capable specialization/login evaluation.
    if options.prompt == true then
        request.prompt = true
        request.promptKind = options.promptKind
        request.signature = options.signature
        request.promptReason = reason or request.promptReason or "event"
    end
    self.pendingEvaluationRequest = request

    self.scheduleSerial = (tonumber(self.scheduleSerial) or 0) + 1
    local token = self.scheduleSerial
    local function Run()
        if token ~= Sync.scheduleSerial then
            return
        end
        local queued = Sync.pendingEvaluationRequest
        if type(queued) ~= "table" or tonumber(queued.scopeSerial) ~= scopeSerial then
            return
        end
        Sync.pendingEvaluationRequest = nil

        local runOptions = {
            prompt = queued.prompt == true,
            promptKind = queued.promptKind,
            signature = queued.signature,
            scopeToken = Sync:CaptureScopeToken(),
        }
        local deferredForCombat = runOptions.prompt and IsInCombat()
        if deferredForCombat then
            -- Status evaluation remains read-only and safe in combat; only the
            -- popup is deferred until PLAYER_REGEN_ENABLED.
            runOptions.prompt = false
        end
        local evaluated = Sync:EvaluateCurrentSpec(
            queued.promptReason or queued.reason or "event",
            runOptions
        )
        if queued.prompt and (deferredForCombat or not evaluated) then
            -- Preserve the prompt request until a later CDM-data event or
            -- PLAYER_REGEN_ENABLED retries it. Never carry it into a new scope.
            local currentSerial = tonumber(Sync.scopeSerial) or 0
            if currentSerial == scopeSerial then
                local pending = Sync.pendingEvaluationRequest
                if type(pending) ~= "table" or tonumber(pending.scopeSerial) ~= scopeSerial then
                    pending = {
                        scopeSerial = scopeSerial,
                        reason = queued.reason,
                    }
                end
                pending.prompt = true
                pending.promptKind = queued.promptKind
                pending.signature = queued.signature
                pending.promptReason = queued.promptReason
                Sync.pendingEvaluationRequest = pending
            end
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.35, Run)
    else
        Run()
    end
    return token
end

function Sync:ScheduleSync(reason, options)
    return self:ScheduleEvaluation(reason or "compat_evaluate", options)
end

function Sync:GetLastSummary()
    return self.lastSummary or NewSummary()
end

function Sync:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    if type(CreateFrame) ~= "function" then
        return
    end
    local frame = CreateFrame("Frame")
    for _, event in ipairs({
        "ADDON_LOADED",
        "PLAYER_LOGIN",
        "PLAYER_ENTERING_WORLD",
        "COOLDOWN_VIEWER_DATA_LOADED",
        "COOLDOWN_VIEWER_TABLE_HOTFIXED",
        "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
        "PLAYER_SPECIALIZATION_CHANGED",
        "PLAYER_TALENT_UPDATE",
        "PLAYER_REGEN_ENABLED",
        "SPELLS_CHANGED",
    }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_CooldownViewer" then
            return
        end
        local scopeEvent = event == "PLAYER_SPECIALIZATION_CHANGED"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_LOGIN"
        if scopeEvent then
            Sync:AdvanceScope()
        end
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            -- A specialization revisited later in the same login is a new
            -- opportunity to resolve its still-pending records. World-entry
            -- events deliberately do not reset this guard, avoiding prompts on
            -- every zone or instance transition.
            Sync:ResetPromptForCurrentScope()
        end
        Sync:InstallLayoutManagerHooks()
        Sync:ScheduleEvaluation(event, {
            prompt = scopeEvent,
            promptKind = scopeEvent and "scope" or nil,
        })
    end)
    self.eventFrame = frame
end

Sync:Initialize()
