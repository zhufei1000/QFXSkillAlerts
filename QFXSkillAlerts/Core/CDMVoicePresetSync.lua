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
    if tonumber(info.baseSpellID) == spellID or tonumber(info.spellID) == spellID then
        return 1
    end
    if tonumber(info.overrideSpellID) == spellID or tonumber(info.overrideTooltipSpellID) == spellID then
        return 2
    end
    if ContainsSpellID(info.linkedSpellIDs, spellID) then
        return 3
    end
    if tonumber(record.cooldownIDHint)
        and tonumber(info.cooldownID) == tonumber(record.cooldownIDHint) then
        return 4
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

function Sync:FindCooldownForRecord(record)
    local service = GetService()
    if not service or type(record) ~= "table" then
        return nil, "skillMissing"
    end
    local bestScore
    local candidates = {}
    for _, info in ipairs(service:GetCooldownsForCategory(record.category) or {}) do
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

function Sync:EvaluateRecord(record)
    local evaluation = {
        record = record,
        status = "skillMissing",
        hasAnySound = false,
        hasTargetSound = false,
        soundCount = 0,
    }
    local service = GetService()
    local store = GetStore()
    if not service or not store or type(record) ~= "table" then
        return evaluation
    end

    local info, matchError = self:FindCooldownForRecord(record)
    if not info then
        evaluation.status = matchError or "skillMissing"
        return evaluation
    end
    evaluation.info = info
    evaluation.cooldownID = tonumber(info.cooldownID)

    local eventType = store:EventKeyToType(record.eventKey, record.eventTypeHint)
    evaluation.eventType = tonumber(eventType)
    if not eventType or not service:IsValidEvent(info.cooldownID, eventType) then
        evaluation.status = "eventUnsupported"
        return evaluation
    end

    local voiceItem = store:ResolveVoice(record)
    evaluation.voiceItem = voiceItem
    if not voiceItem then
        evaluation.status = "voiceMissing"
        return evaluation
    end
    evaluation.targetPayload = tonumber(voiceItem.payload)

    local alerts, readError = service:GetAlerts(info.cooldownID)
    if type(alerts) ~= "table" then
        evaluation.status = "dataNotReady"
        evaluation.failureReason = readError or "data_not_ready"
        return evaluation
    end
    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    for _, alert in ipairs(alerts) do
        local alertType = AlertValue(alert, "CooldownViewerAlert_GetType", 1)
        local alertEvent = tonumber(AlertValue(alert, "CooldownViewerAlert_GetEvent", 2))
        local alertPayload = tonumber(AlertValue(alert, "CooldownViewerAlert_GetPayload", 3))
        if alertType == soundType and alertEvent == tonumber(eventType) then
            evaluation.soundCount = evaluation.soundCount + 1
            evaluation.hasAnySound = true
            evaluation.currentPayload = evaluation.currentPayload or alertPayload
            if alertPayload == evaluation.targetPayload then
                evaluation.hasTargetSound = true
                evaluation.targetCount = (evaluation.targetCount or 0) + 1
                evaluation.currentPayload = alertPayload
            end
        end
    end

    local applyState = store:GetApplyState()
    local failureKey = RuntimeFailureKey(record)
    local failedKeys = type(applyState.failedRecordKeys) == "table" and applyState.failedRecordKeys or {}
    if evaluation.hasTargetSound and evaluation.soundCount == 1 then
        evaluation.status = "loaded"
        failedKeys[failureKey] = nil
    elseif failureKey and failedKeys[failureKey] then
        evaluation.status = "applyFailed"
        evaluation.failureReason = failedKeys[failureKey]
    else
        evaluation.status = "pending"
    end

    if evaluation.status == "pending" or evaluation.status == "applyFailed" then
        if evaluation.soundCount == 0 then
            evaluation.action = "add"
        elseif evaluation.soundCount > 1 then
            evaluation.action = "deduplicate"
        else
            evaluation.action = "replace"
        end
    else
        evaluation.action = "unchanged"
    end
    return evaluation
end

function Sync:EvaluatePendingRemoval(record)
    local evaluation = {
        record = record,
        status = "pendingRemoval",
        targetPresent = false,
    }
    local service = GetService()
    local store = GetStore()
    if not service or not store or type(record) ~= "table" then
        evaluation.status = "invalidRemoval"
        return evaluation
    end
    local info, matchError = self:FindCooldownForRecord(record)
    if not info then
        evaluation.status = matchError or "skillMissing"
        return evaluation
    end
    evaluation.info = info
    evaluation.cooldownID = tonumber(info.cooldownID)
    evaluation.eventType = tonumber(store:EventKeyToType(record.eventKey, record.eventTypeHint))
    if not evaluation.eventType or not service:IsValidEvent(evaluation.cooldownID, evaluation.eventType) then
        evaluation.status = "eventUnsupported"
        return evaluation
    end
    local voiceItem = store:ResolveVoice(record)
    evaluation.voiceItem = voiceItem
    evaluation.payload = voiceItem and tonumber(voiceItem.payload) or tonumber(record.payloadHint)
    if not evaluation.payload then
        evaluation.status = "voiceMissing"
        return evaluation
    end
    local alerts, readReason = service:GetAlerts(evaluation.cooldownID)
    if type(alerts) ~= "table" then
        evaluation.status = "dataNotReady"
        evaluation.failureReason = readReason or "data_not_ready"
        return evaluation
    end
    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    for _, alert in ipairs(alerts) do
        if AlertValue(alert, "CooldownViewerAlert_GetType", 1) == soundType
            and tonumber(AlertValue(alert, "CooldownViewerAlert_GetEvent", 2)) == evaluation.eventType
            and tonumber(AlertValue(alert, "CooldownViewerAlert_GetPayload", 3)) == evaluation.payload then
            evaluation.targetPresent = true
            evaluation.targetCount = (evaluation.targetCount or 0) + 1
        end
    end
    if not evaluation.targetPresent then
        evaluation.action = "unchanged"
    else
        evaluation.action = "remove_saved_target"
    end
    return evaluation
end

function Sync:BuildPendingPlan(records, pendingRemovals)
    local summary = NewSummary()
    local operations = {}
    for _, record in ipairs(type(records) == "table" and records or {}) do
        local evaluation = self:EvaluateRecord(record)
        if evaluation.status == "loaded" then
            summary.alreadyLoaded = summary.alreadyLoaded + 1
        elseif evaluation.status == "pending" or evaluation.status == "applyFailed" then
            operations[#operations + 1] = {
                kind = "set",
                action = evaluation.action,
                classID = tonumber(record.classID),
                specID = tonumber(record.specID),
                cooldownID = evaluation.cooldownID,
                eventType = evaluation.eventType,
                payload = evaluation.targetPayload,
                recordKey = record.recordKey,
                runtimeKey = RuntimeFailureKey(record),
            }
            summary.pending = summary.pending + 1
            if evaluation.status == "applyFailed" then
                summary.applyFailed = summary.applyFailed + 1
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

    for recordKey, record in pairs(type(pendingRemovals) == "table" and pendingRemovals or {}) do
        local evaluation = self:EvaluatePendingRemoval(record)
        summary.pendingRemoval = summary.pendingRemoval + 1
        if evaluation.action == "remove_saved_target" or evaluation.action == "unchanged" then
            operations[#operations + 1] = {
                kind = "remove",
                action = evaluation.action,
                classID = tonumber(record.classID),
                specID = tonumber(record.specID),
                cooldownID = evaluation.cooldownID,
                eventType = evaluation.eventType,
                payload = evaluation.payload,
                recordKey = record.recordKey or recordKey,
                runtimeKey = RuntimeFailureKey(record),
            }
        elseif evaluation.status == "skillMissing" then
            summary.missingSkill = summary.missingSkill + 1
        elseif evaluation.status == "voiceMissing" then
            summary.missingVoice = summary.missingVoice + 1
        elseif evaluation.status == "eventUnsupported" then
            summary.unsupportedEvent = summary.unsupportedEvent + 1
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

    local failedKeys = type(state.failedRecordKeys) == "table" and state.failedRecordKeys or {}
    local allValid = true
    for _, operation in ipairs(type(state.plan) == "table" and state.plan or {}) do
        if operation.kind == "set" then
            local record = store:GetEffectiveRecord(classID, specID, operation.recordKey)
            local evaluation = record and self:EvaluateRecord(record) or nil
            if evaluation and evaluation.status == "dataNotReady" then
                return false, evaluation.failureReason or "data_not_ready"
            end
            if not evaluation or evaluation.status ~= "loaded" then
                allValid = false
                failedKeys[operation.runtimeKey or tostring(operation.recordKey)] = "post_reload_verify_failed"
            end
        elseif operation.kind == "remove" then
            local targetPresent = false
            local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
            local alerts, readReason = service:GetAlerts(operation.cooldownID)
            if type(alerts) ~= "table" then
                return false, readReason or "data_not_ready"
            end
            for _, alert in ipairs(alerts) do
                if AlertValue(alert, "CooldownViewerAlert_GetType", 1) == soundType
                    and tonumber(AlertValue(alert, "CooldownViewerAlert_GetEvent", 2)) == tonumber(operation.eventType)
                    and tonumber(AlertValue(alert, "CooldownViewerAlert_GetPayload", 3)) == tonumber(operation.payload) then
                    targetPresent = true
                    break
                end
            end
            if targetPresent then
                allValid = false
            else
                store:ClearPendingRemoval(classID, specID, operation.recordKey)
            end
        end
    end
    state.applyInProgress = false
    state.plan = nil
    if allValid then
        state.lastApplyError = nil
        state.failedRecordKeys = failedKeys
        if not self.postReloadSuccessReported then
            self.postReloadSuccessReported = true
            print("[QFX-SA] " .. L("CDM_APPLY_RESULT_AFTER_RELOAD"))
        end
        return true, "verified"
    end
    state.lastApplyError = "post_reload_verify_failed"
    state.failedRecordKeys = failedKeys
    if not self.postReloadFailureReported then
        self.postReloadFailureReported = true
        print("[QFX-SA] " .. L("CDM_APPLY_VERIFY_FAILED"))
    end
    return false, "post_reload_verify_failed"
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
    local candidates = {}
    for index, draft in ipairs(type(drafts) == "table" and drafts or {}) do
        local candidate, reason = service:ValidateCDMVoiceDraft(draft, { forApply = true })
        if not candidate then
            return nil, reason or "invalid_record", index
        end
        candidates[#candidates + 1] = candidate
    end
    local saved = {}
    for _, candidate in ipairs(candidates) do
        local recordKey, record = store:SaveAppliedRecord(candidate)
        if not recordKey then
            return nil, record or "save_failed"
        end
        saved[#saved + 1] = record
    end
    return saved
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
    local saved, reason, failedIndex = self:ValidateAndSaveDrafts({ draft })
    if not saved then
        return false, nil, reason, failedIndex
    end
    local plan, summary = self:BuildPendingPlan(saved, {})
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
    return self:ApplyPlanAndReload(plan, summary, reason or "apply_all")
end

function Sync:AdvanceScope()
    self.scopeSerial = (tonumber(self.scopeSerial) or 0) + 1
    return self.scopeSerial
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
    self.scheduleSerial = (tonumber(self.scheduleSerial) or 0) + 1
    local token = self.scheduleSerial
    local runReason = reason or "event"
    local runOptions = type(options) == "table" and options or {}
    local scopeToken = self:CaptureScopeToken()
    local function Run()
        if token ~= Sync.scheduleSerial then
            return
        end
        runOptions.scopeToken = scopeToken
        Sync:EvaluateCurrentSpec(runReason, runOptions)
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
        Sync:InstallLayoutManagerHooks()
        Sync:ScheduleEvaluation(event, {
            prompt = scopeEvent,
            promptKind = scopeEvent and "scope" or nil,
        })
    end)
    self.eventFrame = frame
end

Sync:Initialize()
