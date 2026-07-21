local function Fail(message)
    error(message, 2)
end

local function Assert(value, message)
    if not value then
        Fail(message or "assertion failed")
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        Fail(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)))
    end
end

local SOUND = 10
local VISUAL = 20
local EVENT_AVAILABLE = 1
local EVENT_OTHER = 2
local PAYLOAD_A = -1000000001
local PAYLOAD_B = -1000000002

Enum = {
    CooldownViewerAlertType = { Sound = SOUND },
    CooldownViewerAlertEventType = { Available = EVENT_AVAILABLE, OnCooldown = EVENT_OTHER },
    CooldownViewerCategory = {
        Essential = 1,
        Utility = 2,
        TrackedBuff = 3,
        TrackedBar = 4,
    },
    CDMLayoutMode = { AccessOnly = 1 },
}

local alertsByCooldown = {}
local calls = {}
local failNextAdd = false
local failNextRead = false
local failNextSave = false

local function PushCall(name)
    calls[#calls + 1] = name
end

local manager = {}
function manager:GetAlerts(cooldownID)
    if failNextRead then
        failNextRead = false
        error("forced read failure")
    end
    alertsByCooldown[cooldownID] = alertsByCooldown[cooldownID] or {}
    return alertsByCooldown[cooldownID]
end
function manager:AddAlert(cooldownID, alert)
    PushCall("add:" .. tostring(cooldownID))
    if failNextAdd then
        failNextAdd = false
        return 1
    end
    local alerts = self:GetAlerts(cooldownID)
    alerts[#alerts + 1] = alert
    return 0
end
function manager:RemoveAlert(cooldownID, alert)
    PushCall("remove:" .. tostring(cooldownID))
    local alerts = self:GetAlerts(cooldownID)
    for index, candidate in ipairs(alerts) do
        if candidate == alert then
            table.remove(alerts, index)
            return nil
        end
    end
    return false
end
function manager:LockNotifications()
    PushCall("lock")
    return true
end
function manager:UnlockNotifications()
    PushCall("unlock")
    return true
end
function manager:SaveLayouts()
    PushCall("save")
    if failNextSave then
        failNextSave = false
        return false
    end
    return true
end

local cooldownInfo = {
    [101] = { category = 1, spellID = 1001, linkedSpellIDs = { 1003 }, isKnown = true },
    [102] = { category = 1, spellID = 1002, isKnown = true },
    [103] = { category = 1, spellID = 1003, isKnown = true },
}
local providerCategoryCalls = 0
local provider = {}
function provider:GetOrderedCooldownIDsForCategory(category)
    providerCategoryCalls = providerCategoryCalls + 1
    return category == 1 and { 101, 102, 103 } or {}
end
function provider:GetCooldownInfoForID(cooldownID)
    return cooldownInfo[cooldownID]
end

CooldownViewerSettings = {}
function CooldownViewerSettings:GetLayoutManager()
    return manager
end
function CooldownViewerSettings:GetDataProvider()
    return provider
end

C_CooldownViewer = {
    IsCooldownViewerAvailable = function() return true end,
    GetValidAlertTypes = function() return { EVENT_AVAILABLE, EVENT_OTHER } end,
    GetCooldownViewerCooldownInfo = function(cooldownID) return cooldownInfo[cooldownID] end,
}
C_AddOns = { LoadAddOn = function() return true end }
C_UI = { Reload = function() PushCall("fallback_reload") end }

function CooldownViewerAlert_Create(alertType, eventType, payload)
    return { alertType, eventType, payload }
end
function CooldownViewerAlert_GetType(alert) return alert[1] end
function CooldownViewerAlert_GetEvent(alert) return alert[2] end
function CooldownViewerAlert_GetPayload(alert) return alert[3] end
function CooldownViewerAlert_GetAlertStatus() return 0 end
function CooldownViewerAlert_GetEventText(eventType) return "Event " .. tostring(eventType) end
function UnitClass() return "Mage", "MAGE", 8 end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 62, "Arcane" end
function InCombatLockdown() return false end
function ReloadUI() PushCall("reload") end
function GetTime() return 123 end
function time() return 456 end

QFXSkillAlertsDB = {}
QFXSkillAlertsNS = {
    Core = {},
    Utils = {},
    L = function(key) return key end,
}

local voiceItems = {
    { identity = "voice:a", name = "Voice A", path = "A.ogg", payload = PAYLOAD_A },
    { identity = "voice:b", name = "Voice B", path = "B.ogg", payload = PAYLOAD_B },
}
local itemsByPayload = {
    [tostring(PAYLOAD_A)] = voiceItems[1],
    [tostring(PAYLOAD_B)] = voiceItems[2],
}
QFXSkillAlertsNS.Core.CDMVoiceRegistry = {
    GetItems = function() return voiceItems end,
    GetItemForPayload = function(_, payload) return itemsByPayload[tostring(payload)] end,
    GetPathForPayload = function(_, payload)
        local item = itemsByPayload[tostring(payload)]
        return item and item.path
    end,
    GetNameForPayload = function(_, payload)
        local item = itemsByPayload[tostring(payload)]
        return item and item.name
    end,
    IsOwnedPayload = function(_, payload) return itemsByPayload[tostring(payload)] ~= nil end,
    IsPayloadAvailable = function(_, payload) return itemsByPayload[tostring(payload)] ~= nil end,
    BuildIdentity = function(_, name, path) return tostring(name) .. ":" .. tostring(path) end,
}

dofile("QFXSkillAlerts/Core/CDMVoicePresetStore.lua")
dofile("QFXSkillAlerts/Core/CDMVoiceService.lua")
dofile("QFXSkillAlerts/Core/CDMVoicePresetSync.lua")

local Store = QFXSkillAlertsNS.Core.CDMVoicePresetStore
local Service = QFXSkillAlertsNS.Core.CDMVoiceService
local Sync = QFXSkillAlertsNS.Core.CDMVoicePresetSync
Assert(QFXSkillAlertsDB.cdmVoiceAppliedTargets == nil, "applied-target history must not be created")

local function ResetCalls()
    calls = {}
end

local function CountCalls(prefix)
    local count = 0
    for _, value in ipairs(calls) do
        if value:sub(1, #prefix) == prefix then
            count = count + 1
        end
    end
    return count
end

local function CountAlerts(cooldownID, alertType, eventType, payload)
    local count = 0
    for _, alert in ipairs(alertsByCooldown[cooldownID] or {}) do
        if (alertType == nil or alert[1] == alertType)
            and (eventType == nil or alert[2] == eventType)
            and (payload == nil or alert[3] == payload) then
            count = count + 1
        end
    end
    return count
end

local function Draft(cooldownID, payload)
    return {
        cooldownID = cooldownID,
        eventType = EVENT_AVAILABLE,
        payload = payload,
        classID = 8,
        specID = 62,
        category = "essential",
    }
end

local equivalentProbe = Service:BuildCDMVoiceDraft(101, EVENT_AVAILABLE, PAYLOAD_A, 8, 62, "essential")
local equivalentCooldowns = Sync:FindEquivalentCooldownsForRecord(
    equivalentProbe,
    Service:GetCooldownInfo(101)
)
Equal(equivalentCooldowns[1].cooldownID, 101, "preferred cooldown should be first")
Equal(#equivalentCooldowns, 2, "linked spell identifiers should find the equivalent cooldown")
Equal(equivalentCooldowns[2].cooldownID, 103, "linked equivalent cooldown should be included")

-- Local Save never touches LayoutManager and reports pending when CDM differs.
ResetCalls()
local saved, recordKey, status = Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A))
Assert(saved, "local save should succeed")
Equal(status, "pending", "local save should report pending")
Equal(#calls, 0, "local save must not call LayoutManager or reload")

-- A multi-record pending evaluation enumerates the CDM provider once per
-- category for the whole plan, not once per record.
providerCategoryCalls = 0
local catalogRecord = Store:GetEffectiveRecord(8, 62, recordKey)
Assert(catalogRecord, "catalog test requires the saved record")
Sync:BuildPendingPlan({ catalogRecord, catalogRecord }, {})
Equal(
    providerCategoryCalls,
    #Service:GetCategories(),
    "pending plan should reuse one cooldown catalog across records"
)

-- Row Apply validates, saves the current draft, applies, saves once, never unlocks,
-- and requests exactly one immediate reload.
ResetCalls()
local applied, _, applyReason = Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_A))
Assert(applied, "row apply should succeed")
Equal(applyReason, "reload_requested", "changed row apply should request reload")
Equal(CountCalls("lock"), 1, "row apply should lock once")
Equal(CountCalls("add:"), 1, "row apply should add once")
Equal(CountCalls("save"), 1, "row apply should save layouts once")
Equal(CountCalls("unlock"), 0, "row apply must never unlock notifications")
Equal(CountCalls("reload"), 1, "row apply should reload once")
Assert(Store:GetApplyState().applyInProgress, "apply state should survive until post-reload verification")
failNextRead = true
local waiting, waitingReason = Sync:VerifyPostReloadApply()
Assert(not waiting, "verification should wait when CDM data is unreadable")
Equal(waitingReason, "read_failed", "unreadable CDM data should be deferred")
Assert(Store:GetApplyState().applyInProgress, "deferred verification must keep applyInProgress")
Assert(Sync:VerifyPostReloadApply(), "post-reload verification should pass")
Assert(not Store:GetApplyState().applyInProgress, "verification should clear applyInProgress")

-- Applying the already loaded target is a no-op and does not lock, save, or reload.
ResetCalls()
local noOp, _, noOpReason = Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_A))
Assert(noOp, "already-applied row should succeed")
Equal(noOpReason, "already_applied", "already-applied row should return no-op reason")
Equal(#calls, 0, "no-op apply must not touch LayoutManager or reload")

-- Replacement preserves visual alerts and other events.
alertsByCooldown[101] = {
    { VISUAL, EVENT_AVAILABLE, 700 },
    { SOUND, EVENT_OTHER, 701 },
    { SOUND, EVENT_AVAILABLE, 702 },
    { SOUND, EVENT_AVAILABLE, 703 },
}
alertsByCooldown[102] = { { SOUND, EVENT_AVAILABLE, PAYLOAD_A } }
alertsByCooldown[103] = {
    { VISUAL, EVENT_AVAILABLE, 704 },
    { SOUND, EVENT_OTHER, 705 },
    { SOUND, EVENT_AVAILABLE, PAYLOAD_A },
}
ResetCalls()
local replaced = Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_B))
Assert(replaced, "replacement apply should succeed")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_B), 1, "replacement should leave one target sound")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE), 1, "replacement should remove all same-event sounds")
Equal(CountAlerts(101, VISUAL, EVENT_AVAILABLE), 1, "replacement must preserve visual alerts")
Equal(CountAlerts(101, SOUND, EVENT_OTHER), 1, "replacement must preserve other events")
Equal(CountAlerts(103, SOUND, EVENT_AVAILABLE), 0, "replacement should clear equivalent cooldown sounds")
Equal(CountAlerts(103, VISUAL, EVENT_AVAILABLE), 1, "equivalent cleanup must preserve visuals")
Equal(CountAlerts(103, SOUND, EVENT_OTHER), 1, "equivalent cleanup must preserve other events")
Equal(CountAlerts(102, SOUND, EVENT_AVAILABLE, PAYLOAD_A), 1, "another skill using the same payload must be preserved")
Equal(CountCalls("save"), 1, "replacement should save once")
Equal(CountCalls("reload"), 1, "replacement should reload once")
Equal(CountCalls("unlock"), 0, "replacement must not unlock")
Assert(Sync:VerifyPostReloadApply(), "replacement should verify after reload")

-- A target that is correct on the main cooldown is still pending when an
-- equivalent cooldown retains an old same-event sound.
alertsByCooldown[103][#alertsByCooldown[103] + 1] = { SOUND, EVENT_AVAILABLE, PAYLOAD_A }
local duplicateEvaluation = Sync:EvaluateRecord(Store:GetEffectiveRecord(8, 62, recordKey))
Equal(duplicateEvaluation.status, "pending", "equivalent old sound should make the record pending")
Equal(
    duplicateEvaluation.pendingReason,
    "duplicate_equivalent_cooldown_sound",
    "equivalent old sound should report the dedicated pending reason"
)
ResetCalls()
Assert(Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_B)), "equivalent old sound should be repaired")
Equal(CountAlerts(103, SOUND, EVENT_AVAILABLE), 0, "repair should clear equivalent old sound")

-- Post-reload verification re-resolves every equivalent cooldown and rejects a
-- sound that reappears outside the main target.
alertsByCooldown[103][#alertsByCooldown[103] + 1] = { SOUND, EVENT_AVAILABLE, PAYLOAD_A }
local verified, verifyReason = Sync:VerifyPostReloadApply()
Assert(not verified, "post-reload verification should reject an equivalent duplicate")
Equal(
    verifyReason,
    "post_reload_duplicate_sound_remaining",
    "post-reload duplicate should persist the expected failure reason"
)
ResetCalls()
Assert(Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_B)), "explicit reapply should repair post-reload failure")
Assert(Sync:VerifyPostReloadApply(), "repaired equivalent set should verify")

-- Manual deletion immediately removes every same-event Sound from all equivalent
-- cooldowns, saves once, and does not reload. The synchronous verification clears
-- the temporary tombstone before returning.
alertsByCooldown[103][#alertsByCooldown[103] + 1] = { SOUND, EVENT_AVAILABLE, 900 }
alertsByCooldown[103][#alertsByCooldown[103] + 1] = { SOUND, EVENT_AVAILABLE, 901 }
ResetCalls()
local deleted, deleteReason = Service:DeleteSoundAlertByKey(
    "cdmpreset:8:62:essential:1001:AVAILABLE"
)
Assert(deleted, "saved entry deletion should succeed")
Equal(deleteReason, "deleted", "manual deletion should apply immediately")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_B), 0, "target payload should be removed")
Equal(CountAlerts(103, SOUND, EVENT_AVAILABLE), 0, "manual deletion should clear equivalent sounds")
Equal(CountAlerts(101, VISUAL, EVENT_AVAILABLE), 1, "manual deletion must preserve visual alerts")
Equal(CountAlerts(101, SOUND, EVENT_OTHER), 1, "manual deletion must preserve other events")
Equal(CountCalls("save"), 1, "manual deletion should save once")
Equal(CountCalls("reload"), 0, "manual deletion must not reload")
Equal(CountCalls("lock"), 0, "manual deletion must not leave notifications locked")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "manual deletion should clear its tombstone")

-- The explicitly named compatibility API still supports local-only staging for
-- import/automation callers that intentionally want a later batch apply.
Assert(Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A)))
alertsByCooldown[101] = { { SOUND, EVENT_AVAILABLE, PAYLOAD_A } }
ResetCalls()
local staged, stagedReason = Service:DeleteSoundAlertByKeyLocalOnly(
    "cdmpreset:8:62:essential:1001:AVAILABLE"
)
Assert(staged, "local-only deletion staging should succeed")
Equal(stagedReason, "pending_removal", "local-only API should return pending removal")
Equal(#calls, 0, "local-only deletion must not touch LayoutManager or reload")
Assert(Store:GetPendingRemoval(8, 62, recordKey), "local-only tombstone should persist")
local tombstone = Store:GetPendingRemoval(8, 62, recordKey)
Assert(tombstone.payloadHint == nil, "pending-removal tombstone must not persist the old payload")
Assert(tombstone.voicePath == nil, "pending-removal tombstone must not persist the old voice path")
ResetCalls()
Assert(Sync:ApplyAllPendingCurrentSpecAndReload("test_staged_remove"), "staged removal should apply")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE), 0, "staged removal should clear the sound")
Equal(CountCalls("save"), 1, "staged removal should save once")
Equal(CountCalls("reload"), 0, "removal-only batch must not reload")
Equal(CountCalls("lock"), 0, "removal-only batch must not lock notifications")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "removal-only batch should clear its tombstone")

-- If immediate deletion cannot even build a readable CDM plan, the local record
-- is restored so the user never lands in a half-deleted state.
Assert(Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A)))
alertsByCooldown[101] = { { SOUND, EVENT_AVAILABLE, PAYLOAD_A } }
failNextRead = true
ResetCalls()
local failedDelete, failedDeleteReason = Service:DeleteSoundAlertByKey(
    "cdmpreset:8:62:essential:1001:AVAILABLE"
)
Assert(not failedDelete, "unreadable CDM data should fail immediate deletion")
Equal(failedDeleteReason, "delete_failed", "failed deletion should report a stable reason")
Assert(Store:GetEffectiveRecord(8, 62, recordKey), "failed deletion should restore the local record")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "failed deletion should remove its tombstone")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_A), 1, "failed deletion should preserve CDM")
Equal(#calls, 0, "failed deletion prevalidation must not mutate or reload")

-- A save failure after removal restores both the runtime alert and local record,
-- without reloading or leaving a pending tombstone.
failNextSave = true
ResetCalls()
local unsavedDelete, unsavedDeleteReason = Service:DeleteSoundAlertByKey(
    "cdmpreset:8:62:essential:1001:AVAILABLE"
)
Assert(not unsavedDelete, "SaveLayouts failure should fail immediate deletion")
Equal(unsavedDeleteReason, "save_failed", "save failure should be reported")
Assert(Store:GetEffectiveRecord(8, 62, recordKey), "save failure should restore the local record")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "save failure should clear its tombstone")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_A), 1, "save failure should restore CDM")
Equal(CountCalls("save"), 1, "failed deletion should attempt one save")
Equal(CountCalls("reload"), 0, "failed deletion must not reload")

-- Changing the record key keeps the old logical skill/event as a payload-free
-- tombstone and applies old cleanup plus the new target in one transaction.
local oldKey102 = "essential:1002:AVAILABLE"
Assert(Service:SaveVoicePresetOnly(Draft(102, PAYLOAD_A)))
alertsByCooldown[102] = { { SOUND, EVENT_AVAILABLE, PAYLOAD_A } }
ResetCalls()
local keyChanged, _, keyChangeReason, newKey102 = Sync:ApplyCurrentDraftAndReload({
    cooldownID = 102,
    eventType = EVENT_OTHER,
    payload = PAYLOAD_B,
    classID = 8,
    specID = 62,
    category = "essential",
    originalRecordKey = oldKey102,
})
Assert(keyChanged, "record-key change should apply")
Equal(keyChangeReason, "reload_requested", "record-key change should request one reload")
Equal(newKey102, "essential:1002:ON_COOLDOWN", "new event should produce the new record key")
Assert(not Store:GetEffectiveRecord(8, 62, oldKey102), "old record key must no longer be effective")
Assert(Store:GetPendingRemoval(8, 62, oldKey102), "old record key should create a tombstone")
Equal(CountAlerts(102, SOUND, EVENT_AVAILABLE), 0, "old record event should be cleared")
Equal(CountAlerts(102, SOUND, EVENT_OTHER, PAYLOAD_B), 1, "new record event should contain one target")
Equal(CountCalls("save"), 1, "record-key change should save layouts once")
Equal(CountCalls("reload"), 1, "record-key change should reload once")
Assert(Sync:VerifyPostReloadApply(), "record-key change should verify after reload")
Assert(not Store:GetPendingRemoval(8, 62, oldKey102), "verified old-key tombstone should clear")

-- Import is store-only and re-saving a record cancels its matching tombstone.
local importedRecord = {
    classID = 8,
    specID = 62,
    category = "essential",
    spellID = 1001,
    eventKey = "AVAILABLE",
    eventTypeHint = EVENT_AVAILABLE,
    voiceIdentity = "voice:a",
    voiceName = "Voice A",
    voicePath = "A.ogg",
    cooldownIDHint = 101,
    payloadHint = PAYLOAD_A,
}
Store:SetPendingRemoval(importedRecord)
ResetCalls()
local imported, invalid = Store:ImportProfiles({ [8] = { [62] = { importedRecord } } })
Equal(imported, 1, "valid import should save one record")
Equal(invalid, 0, "valid import should have no invalid records")
Equal(#calls, 0, "import must not touch LayoutManager or reload")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "import should cancel matching tombstone")

-- Invalid row Apply fails before saving, locking, mutating, or reloading.
local oldRecord = Store:GetEffectiveRecord(8, 62, recordKey)
ResetCalls()
local invalidApply = Sync:ApplyCurrentDraftAndReload(Draft(101, -42))
Assert(not invalidApply, "invalid draft should fail")
Equal(#calls, 0, "invalid draft must not touch LayoutManager or reload")
local preserved = Store:GetEffectiveRecord(8, 62, recordKey)
Equal(preserved.voiceIdentity, oldRecord.voiceIdentity, "invalid draft must not overwrite the valid local record")

-- Read-only evaluation never writes CDM or reloads, even when data differs.
alertsByCooldown[101] = {}
ResetCalls()
local evaluated = Sync:EvaluateCurrentSpec("automatic_event")
Assert(evaluated, "read-only evaluation should succeed")
Equal(#calls, 0, "automatic evaluation must not write, save, lock, or reload")

-- Apply All performs every removal before the first addition and saves/reloads once.
alertsByCooldown[101] = { { SOUND, EVENT_AVAILABLE, 800 } }
alertsByCooldown[102] = { { SOUND, EVENT_AVAILABLE, 801 } }
Assert(Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A)))
Assert(Service:SaveVoicePresetOnly(Draft(102, PAYLOAD_B)))
ResetCalls()
local batchApplied = Sync:ApplyAllPendingCurrentSpecAndReload("test_batch")
Assert(batchApplied, "batch apply should succeed")
local firstAdd
for index, value in ipairs(calls) do
    if value:sub(1, 4) == "add:" then
        firstAdd = index
        break
    end
end
Assert(firstAdd, "batch should contain additions")
for index = firstAdd + 1, #calls do
    Assert(calls[index]:sub(1, 7) ~= "remove:", "no removal may occur after the addition phase begins")
end
Equal(CountCalls("save"), 1, "batch should call SaveLayouts once")
Equal(CountCalls("reload"), 1, "batch should reload once")
Equal(CountCalls("unlock"), 0, "batch must not unlock notifications")
Assert(Sync:VerifyPostReloadApply(), "batch should verify after reload")

-- Two local targets that claim the same equivalent cooldown/event pair but use
-- different payloads fail prevalidation before locking or mutating CDM.
local conflictPlan = {
    {
        kind = "set", classID = 8, specID = 62, recordKey = "conflict:a",
        category = "essential", spellID = 1001, eventKey = "AVAILABLE",
        cooldownID = 101, eventType = EVENT_AVAILABLE, payload = PAYLOAD_A,
        equivalentCooldownIDs = { 101, 103 },
        targetAlert = { SOUND, EVENT_AVAILABLE, PAYLOAD_A },
    },
    {
        kind = "set", classID = 8, specID = 62, recordKey = "conflict:b",
        category = "essential", spellID = 1003, eventKey = "AVAILABLE",
        cooldownID = 103, eventType = EVENT_AVAILABLE, payload = PAYLOAD_B,
        equivalentCooldownIDs = { 101, 103 },
        targetAlert = { SOUND, EVENT_AVAILABLE, PAYLOAD_B },
    },
}
ResetCalls()
local conflictOK, _, conflictReason = Service:ApplyCDMPlanAndReload(conflictPlan, {})
Assert(not conflictOK, "conflicting local targets should fail")
Equal(conflictReason, "conflicting_local_targets", "conflict should use the stable failure reason")
Equal(#calls, 0, "conflict prevalidation must not lock, mutate, save, or reload")

-- Dirty rows are validated as a group. One invalid row prevents every dirty-row
-- save and every LayoutManager call.
local beforeDirtyBatch = Store:GetEffectiveRecord(8, 62, "essential:1001:AVAILABLE")
ResetCalls()
local dirtyBatchApplied = Sync:ApplyAllPendingCurrentSpecAndReload("dirty_batch", {
    Draft(101, PAYLOAD_B),
    Draft(102, -42),
})
Assert(not dirtyBatchApplied, "an invalid dirty row should reject the whole dirty batch")
Equal(#calls, 0, "invalid dirty batch must not touch LayoutManager or reload")
Equal(
    Store:GetEffectiveRecord(8, 62, "essential:1001:AVAILABLE").voiceIdentity,
    beforeDirtyBatch.voiceIdentity,
    "invalid dirty batch must not save earlier valid rows"
)

-- Once mutation starts, an AddAlert failure rolls memory back, records the error,
-- reloads immediately, and automatic evaluation does not retry it.
alertsByCooldown[101] = { { SOUND, EVENT_AVAILABLE, PAYLOAD_A } }
Assert(Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A)))
failNextAdd = true
ResetCalls()
local failedApply = Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_B))
Assert(not failedApply, "forced AddAlert failure should fail the apply")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_A), 1, "failed apply should restore the old sound")
Equal(CountCalls("unlock"), 0, "failure path must not unlock")
Equal(CountCalls("reload"), 1, "failure after mutation should reload once")
Equal(Store:GetApplyState().lastApplyError, "add_failed", "failure should persist the apply error")
Equal(Store:GetEffectiveRecord(8, 62, recordKey).voiceIdentity, "voice:b", "latest valid draft should remain saved")
ResetCalls()
Assert(Sync:EvaluateCurrentSpec("after_failure"), "post-failure evaluation should run")
Equal(#calls, 0, "post-failure evaluation must not auto-retry or reload")

-- Debounced event bursts retain a scope prompt even when ordinary talent/spell
-- refresh events arrive after the specialization event.
local timerCallbacks = {}
C_Timer = {
    After = function(_, callback)
        timerCallbacks[#timerCallbacks + 1] = callback
    end,
}
local originalEvaluateCurrentSpec = Sync.EvaluateCurrentSpec
local scheduledEvaluations = {}
local evaluationAvailable = true
Sync.EvaluateCurrentSpec = function(_, reason, options)
    scheduledEvaluations[#scheduledEvaluations + 1] = {
        reason = reason,
        prompt = options and options.prompt,
        promptKind = options and options.promptKind,
    }
    return evaluationAvailable
end
Sync.pendingEvaluationRequest = nil
Sync.scheduleSerial = 0
Sync.scopeSerial = 10
Sync.sessionPromptedScopes = { ["scope:8:62"] = true }
Assert(Sync:ResetPromptForCurrentScope(), "current scope prompt guard should reset")
Assert(not Sync.sessionPromptedScopes["scope:8:62"],
    "re-entered specialization should be allowed to prompt again")
Sync:ScheduleEvaluation("PLAYER_SPECIALIZATION_CHANGED", {
    prompt = true,
    promptKind = "scope",
})
Sync:ScheduleEvaluation("PLAYER_TALENT_UPDATE", {
    prompt = false,
})
timerCallbacks[1]()
timerCallbacks[2]()
Equal(#scheduledEvaluations, 1, "event burst should run one coalesced evaluation")
Equal(scheduledEvaluations[1].prompt, true, "later refresh must preserve the scope prompt")
Equal(scheduledEvaluations[1].promptKind, "scope", "coalescing must preserve prompt kind")

-- If CDM is not ready, keep the prompt request and merge it into the next data
-- event instead of silently losing it.
timerCallbacks = {}
scheduledEvaluations = {}
Sync:AdvanceScope()
evaluationAvailable = false
Sync:ScheduleEvaluation("PLAYER_SPECIALIZATION_CHANGED", {
    prompt = true,
    promptKind = "scope",
})
timerCallbacks[1]()
Assert(Sync.pendingEvaluationRequest and Sync.pendingEvaluationRequest.prompt,
    "unavailable CDM data should retain the pending prompt")
evaluationAvailable = true
Sync:ScheduleEvaluation("COOLDOWN_VIEWER_DATA_LOADED", {
    prompt = false,
})
timerCallbacks[2]()
Equal(#scheduledEvaluations, 2, "CDM data event should retry the evaluation")
Equal(scheduledEvaluations[2].prompt, true, "CDM data retry should restore the prompt")

-- Combat suppresses only the immediate popup. PLAYER_REGEN_ENABLED retries the
-- retained request with prompting enabled.
timerCallbacks = {}
scheduledEvaluations = {}
local inCombat = true
InCombatLockdown = function() return inCombat end
Sync:AdvanceScope()
Sync:ScheduleEvaluation("PLAYER_SPECIALIZATION_CHANGED", {
    prompt = true,
    promptKind = "scope",
})
timerCallbacks[1]()
Equal(scheduledEvaluations[1].prompt, false, "combat evaluation must not show the popup")
Assert(Sync.pendingEvaluationRequest and Sync.pendingEvaluationRequest.prompt,
    "combat should retain the pending prompt")
inCombat = false
Sync:ScheduleEvaluation("PLAYER_REGEN_ENABLED", {
    prompt = false,
})
timerCallbacks[2]()
Equal(scheduledEvaluations[2].prompt, true, "leaving combat should retry the popup")

Sync.EvaluateCurrentSpec = originalEvaluateCurrentSpec
C_Timer = nil
InCombatLockdown = function() return false end

print("CDM explicit apply regression tests passed")
