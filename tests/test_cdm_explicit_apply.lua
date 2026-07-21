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
        return false
    end
    local alerts = self:GetAlerts(cooldownID)
    alerts[#alerts + 1] = alert
    return true
end
function manager:RemoveAlert(cooldownID, alert)
    PushCall("remove:" .. tostring(cooldownID))
    local alerts = self:GetAlerts(cooldownID)
    for index, candidate in ipairs(alerts) do
        if candidate == alert then
            table.remove(alerts, index)
            return true
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
    return true
end

local cooldownInfo = {
    [101] = { category = 1, spellID = 1001, isKnown = true },
    [102] = { category = 1, spellID = 1002, isKnown = true },
}
local provider = {}
function provider:GetOrderedCooldownIDsForCategory(category)
    return category == 1 and { 101, 102 } or {}
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

-- Local Save never touches LayoutManager and reports pending when CDM differs.
ResetCalls()
local saved, recordKey, status = Service:SaveVoicePresetOnly(Draft(101, PAYLOAD_A))
Assert(saved, "local save should succeed")
Equal(status, "pending", "local save should report pending")
Equal(#calls, 0, "local save must not call LayoutManager or reload")

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
ResetCalls()
local replaced = Sync:ApplyCurrentDraftAndReload(Draft(101, PAYLOAD_B))
Assert(replaced, "replacement apply should succeed")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_B), 1, "replacement should leave one target sound")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE), 1, "replacement should remove all same-event sounds")
Equal(CountAlerts(101, VISUAL, EVENT_AVAILABLE), 1, "replacement must preserve visual alerts")
Equal(CountAlerts(101, SOUND, EVENT_OTHER), 1, "replacement must preserve other events")
Equal(CountCalls("save"), 1, "replacement should save once")
Equal(CountCalls("reload"), 1, "replacement should reload once")
Equal(CountCalls("unlock"), 0, "replacement must not unlock")
Assert(Sync:VerifyPostReloadApply(), "replacement should verify after reload")

-- Deleting a saved row is local-only and creates a tombstone. Explicit Apply All
-- removes only that payload, then verification clears the tombstone.
ResetCalls()
local deleted, deleteReason = Service:DeleteSoundAlertByKey(
    "cdmpreset:8:62:essential:1001:AVAILABLE"
)
Assert(deleted, "saved entry deletion should succeed")
Equal(deleteReason, "pending_removal", "applied deletion should create a tombstone")
Equal(#calls, 0, "local deletion must not touch LayoutManager or reload")
Assert(Store:GetPendingRemoval(8, 62, recordKey), "pending removal should be persisted")
ResetCalls()
local removed = Sync:ApplyAllPendingCurrentSpecAndReload("test_remove")
Assert(removed, "pending removal apply should succeed")
Equal(CountAlerts(101, SOUND, EVENT_AVAILABLE, PAYLOAD_B), 0, "target payload should be removed")
Equal(CountAlerts(101, VISUAL, EVENT_AVAILABLE), 1, "pending removal must preserve visual alerts")
Equal(CountAlerts(101, SOUND, EVENT_OTHER), 1, "pending removal must preserve other events")
Equal(CountCalls("save"), 1, "pending removal batch should save once")
Equal(CountCalls("reload"), 1, "pending removal batch should reload once")
Assert(Store:GetPendingRemoval(8, 62, recordKey), "tombstone should remain until post-reload verification")
Assert(Sync:VerifyPostReloadApply(), "pending removal should verify")
Assert(not Store:GetPendingRemoval(8, 62, recordKey), "verification should clear the tombstone")

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

print("CDM explicit apply regression tests passed")
