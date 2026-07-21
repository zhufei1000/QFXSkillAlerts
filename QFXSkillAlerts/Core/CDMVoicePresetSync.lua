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

local function IsInCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function NewSummary()
    return {
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
    local spellID = tonumber(record.spellID)
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

function Sync:FindCooldownForRecord(record)
    local service = GetService()
    if not service or type(record) ~= "table" then
        return nil, "missingSkill"
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
        return nil, "missingSkill"
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
    }
    local service = GetService()
    local store = GetStore()
    if not service or not store or type(record) ~= "table" then
        return evaluation
    end

    local info, matchError = self:FindCooldownForRecord(record)
    if not info then
        evaluation.status = matchError == "missingSkill" and "skillMissing" or (matchError or "skillMissing")
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

    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    evaluation.soundCount = 0
    for _, alert in ipairs(service:GetAlerts(info.cooldownID) or {}) do
        local alertType = AlertValue(alert, "CooldownViewerAlert_GetType", 1)
        local alertEvent = tonumber(AlertValue(alert, "CooldownViewerAlert_GetEvent", 2))
        local alertPayload = tonumber(AlertValue(alert, "CooldownViewerAlert_GetPayload", 3))
        if alertType == soundType and alertEvent == tonumber(eventType) then
            evaluation.soundCount = evaluation.soundCount + 1
            evaluation.hasAnySound = true
            evaluation.currentPayload = evaluation.currentPayload or alertPayload
            if alertPayload == tonumber(voiceItem.payload) then
                evaluation.hasTargetSound = true
                evaluation.currentPayload = alertPayload
            end
        end
    end
    if evaluation.hasTargetSound and evaluation.soundCount == 1 then
        evaluation.status = "loaded"
        local runtimeKey = RuntimeFailureKey(record)
        if type(self.runtimeFailures) == "table" and runtimeKey then
            self.runtimeFailures[runtimeKey] = nil
        end
    else
        local runtimeKey = RuntimeFailureKey(record)
        local runtimeFailure = type(self.runtimeFailures) == "table"
            and runtimeKey and self.runtimeFailures[runtimeKey]
        evaluation.status = runtimeFailure and "syncFailed" or "pending"
        evaluation.failureReason = runtimeFailure
        evaluation.action = evaluation.hasAnySound and "replace" or "add"
    end
    return evaluation
end

function Sync:BuildSyncPlan(records)
    local summary = NewSummary()
    local operations = {}
    if not GetService() or not GetStore() then
        summary.failed = 1
        return operations, summary
    end

    for _, record in ipairs(type(records) == "table" and records or {}) do
        local evaluation = self:EvaluateRecord(record)
        if evaluation.status == "loaded" then
            summary.alreadyLoaded = summary.alreadyLoaded + 1
        elseif evaluation.status == "pending" or evaluation.status == "syncFailed" then
            operations[#operations + 1] = {
                cooldownID = evaluation.cooldownID,
                eventType = evaluation.eventType,
                payload = evaluation.voiceItem and evaluation.voiceItem.payload,
                recordKey = record.recordKey,
                runtimeKey = RuntimeFailureKey(record),
                action = evaluation.action,
            }
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
    return operations, summary
end

function Sync:ApplySyncPlan(plan, summary, reason)
    local service = GetService()
    if not service then
        summary = summary or NewSummary()
        summary.failed = summary.failed + #(plan or {})
        return false, summary, "not_available"
    end
    local ok, result, errorReason = service:ApplySoundAlertsBatch(plan, {
        summary = summary,
        reason = reason or "preset_sync",
        mutationSource = "qfx_reconcile",
        deferRefresh = true,
    })
    self.runtimeFailures = self.runtimeFailures or {}
    for _, batchResult in ipairs(service:GetLastBatchResults() or {}) do
        local runtimeKey = batchResult.operation and batchResult.operation.runtimeKey
        if runtimeKey then
            if batchResult.success then
                self.runtimeFailures[runtimeKey] = nil
            else
                self.runtimeFailures[runtimeKey] = batchResult.reason or "sync_failed"
            end
        end
    end
    if type(service.RefreshRuntimeData) == "function" then
        service:RefreshRuntimeData(reason or "preset_sync")
    end
    return ok, result, errorReason
end

function Sync:RunCurrentSpecSync(reason, options)
    options = type(options) == "table" and options or {}
    if IsInCombat() then
        return false, self.lastSummary or NewSummary(), "combat"
    end
    local service = GetService()
    local store = GetStore()
    if not service or not store then
        return false, NewSummary(), "not_available"
    end
    self:InstallLayoutManagerHooks()
    local available, availabilityReason = service:IsAvailable()
    if not available then
        return false, NewSummary(), availabilityReason
    end
    local classID, specID = service:GetCurrentClassSpec()
    if not classID or not specID then
        return false, NewSummary(), "no_spec"
    end
    local scopeToken = options.scopeToken
    if type(scopeToken) == "table"
        and (tonumber(scopeToken.serial) ~= tonumber(self.scopeSerial)
            or tonumber(scopeToken.classID) ~= classID
            or tonumber(scopeToken.specID) ~= specID) then
        return false, NewSummary(), "stale_scope"
    end

    if options.capture == true then
        store:CaptureCurrentSpecFromLayout()
    end
    local records = store:GetEffectiveRecords(classID, specID)
    local plan, summary = self:BuildSyncPlan(records)
    local ok, result, errorReason = self:ApplySyncPlan(plan, summary, reason)
    self.lastSummary = result or summary
    self.lastReason = reason
    self.lastRunAt = type(GetTime) == "function" and GetTime() or 0
    return ok, self.lastSummary, errorReason
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
        if currentService and type(currentService.IsInternalCDMMutation) == "function"
            and currentService:IsInternalCDMMutation() then
            return
        end
        Sync:ScheduleSync("cdm_layout_saved", { capture = false })
    end)
    if ok then
        self.hookedLayoutManagers[manager] = true
    end
    return ok
end

function Sync:ScheduleSync(reason, options)
    self.scheduleSerial = (tonumber(self.scheduleSerial) or 0) + 1
    local token = self.scheduleSerial
    self.scheduledReason = reason or "event"
    self.scheduledOptions = type(options) == "table" and options or {}
    self.scheduledScopeToken = self:CaptureScopeToken()
    if IsInCombat() then
        return token
    end
    local function Run()
        if token ~= Sync.scheduleSerial then
            return
        end
        local runReason = Sync.scheduledReason
        local runOptions = Sync.scheduledOptions
        local scopeToken = Sync.scheduledScopeToken
        Sync.scheduledReason = nil
        Sync.scheduledOptions = nil
        Sync.scheduledScopeToken = nil
        runOptions.scopeToken = scopeToken
        Sync:RunCurrentSpecSync(runReason, runOptions)
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.35, Run)
    else
        Run()
    end
    return token
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
        if event == "PLAYER_SPECIALIZATION_CHANGED"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_LOGIN" then
            Sync:AdvanceScope()
        end
        Sync:InstallLayoutManagerHooks()
        Sync:ScheduleSync(event)
    end)
    self.eventFrame = frame
end

Sync:Initialize()
