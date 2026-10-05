local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMNativeEvents = NS.Core.CDMNativeEvents or {}

local Native = NS.Core.CDMNativeEvents

-- Cooldown Manager events that QFX handles inside the addon instead of writing
-- them into the Cooldown Manager layout:
--   AVAILABLE / ON_COOLDOWN : stored as regular cooldown alert entries and
--                             played by the main runtime.
--   AURA_APPLIED / AURA_REMOVED : registered with the client through
--                             C_UnitAuras.AddAuraSound by CDMNativeAuraSounds.
-- CHARGE_GAINED and PANDEMIC_TIME stay on the Cooldown Manager path because
-- the underlying data (current charges, aura remaining time) is secret while
-- cooldowns are restricted.
local NATIVE_EVENT_KEYS = {
    AVAILABLE = true,
    ON_COOLDOWN = true,
    AURA_APPLIED = true,
    AURA_REMOVED = true,
}

local function NormalizeEventKey(eventKey)
    return tostring(eventKey or ""):upper()
end

function Native:IsNativeEventKey(eventKey)
    return NATIVE_EVENT_KEYS[NormalizeEventKey(eventKey)] == true
end

-- Matches Blizzard's CooldownViewerAlertEventType enum values for the native
-- events. Used by the legacy Cooldown Manager hook (stale alerts must stay
-- silent) and by the one-time layout cleanup.
local NATIVE_ALERT_EVENT_NAMES = {
    "Available",
    "OnCooldown",
    "OnAuraApplied",
    "OnAuraRemoved",
}

function Native:IsNativeAlertEventType(eventType)
    local enumTable = Enum and Enum.CooldownViewerAlertEventType
    if not enumTable then
        return false
    end
    eventType = tonumber(eventType)
    if not eventType then
        return false
    end
    for _, name in ipairs(NATIVE_ALERT_EVENT_NAMES) do
        local value = enumTable[name]
        if value ~= nil and tonumber(value) == eventType then
            return true
        end
    end
    return false
end

function Native:IsNativeRecord(record)
    return type(record) == "table" and self:IsNativeEventKey(record.eventKey)
end

function Native:GetCurrentClassSpec()
    local service = NS.Core and NS.Core.CDMVoiceService
    if service and type(service.GetCurrentClassSpec) == "function" then
        local classID, specID = service:GetCurrentClassSpec()
        return tonumber(classID), tonumber(specID)
    end
    return nil, nil
end

function Native:ResolveRecordPath(record)
    if type(record) ~= "table" then
        return nil
    end
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if store and type(store.ResolveVoice) == "function" then
        local voice = store:ResolveVoice(record)
        if voice and type(voice.path) == "string" and voice.path ~= "" then
            return voice.path
        end
    end
    local path = record.voicePath
    if type(path) == "string" and path ~= "" then
        return path
    end
    return nil
end

-- A native record is only loaded while its spell is present in the current
-- Cooldown Manager data (learned and part of a category), matching the old
-- layout-based behaviour. The category set is read through the C API and
-- cached per cooldown-cache generation.
local CATEGORY_ENUM_KEYS = { "Essential", "Utility", "TrackedBuff", "TrackedBar" }

local function AddSpellID(set, value)
    value = tonumber(value)
    if value and value > 0 then
        set[value] = true
    end
end

function Native:BuildAvailableSpellIDSet()
    if type(C_CooldownViewer) ~= "table"
        or type(C_CooldownViewer.GetCooldownViewerCategorySet) ~= "function"
        or type(C_CooldownViewer.GetCooldownViewerCooldownInfo) ~= "function" then
        return nil
    end
    local enumTable = Enum and Enum.CooldownViewerCategory
    if type(enumTable) ~= "table" then
        return nil
    end
    local set = {}
    for _, enumKey in ipairs(CATEGORY_ENUM_KEYS) do
        local categoryValue = enumTable[enumKey]
        if categoryValue ~= nil then
            local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, categoryValue, false)
            if ok and type(ids) == "table" then
                for _, cooldownID in ipairs(ids) do
                    local infoOK, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                    if infoOK and type(info) == "table" then
                        AddSpellID(set, info.spellID)
                        AddSpellID(set, info.overrideSpellID)
                        AddSpellID(set, info.overrideTooltipSpellID)
                        local linked = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}
                        for _, linkedSpellID in ipairs(linked) do
                            AddSpellID(set, linkedSpellID)
                        end
                    end
                end
            end
        end
    end
    return set
end

function Native:GetAvailableSpellIDSet()
    local service = NS.Core and NS.Core.CDMVoiceService
    local generation = service and type(service.GetCooldownCacheGeneration) == "function"
        and tonumber(service:GetCooldownCacheGeneration()) or 0
    if self.availableSpellBuilt == true and self.availableSpellGeneration == generation then
        return self.availableSpellSet
    end
    local set = self:BuildAvailableSpellIDSet()
    self.availableSpellSet = set
    self.availableSpellGeneration = generation
    self.availableSpellBuilt = true
    return set
end

-- Fails open when the Cooldown Manager data cannot be read, so a transient
-- API problem never silently disables the configured voices.
function Native:IsRecordAvailable(record)
    if type(record) ~= "table" then
        return false
    end
    local spellID = tonumber(record.spellID)
    if not spellID then
        return false
    end
    local set = self:GetAvailableSpellIDSet()
    if set == nil then
        return true
    end
    return set[spellID] == true
end

-- Rebuilds the aura sound registrations. Ready / cooldown records are played
-- by the main runtime from the shared cooldown alert entries, so only the
-- aura path is synced here.
function Native:SyncAll()
    local auraSounds = NS.Core and NS.Core.CDMNativeAuraSounds
    if auraSounds and type(auraSounds.Sync) == "function" then
        pcall(auraSounds.Sync, auraSounds)
    end
end
