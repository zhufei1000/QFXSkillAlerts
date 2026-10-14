local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMNativeAuraSounds = NS.Core.CDMNativeAuraSounds or {}

local AuraSounds = NS.Core.CDMNativeAuraSounds
local Native = NS.Core.CDMNativeEvents

-- Cooldown Manager AURA_APPLIED / AURA_REMOVED events registered with the
-- client through C_UnitAuras.AddAuraSound. The client performs the aura edge
-- detection and plays the file, so the addon never reads secret aura data and
-- nothing is written into the Cooldown Manager layout.
--
-- Keep accepted registrations through loading screens. A refused replacement
-- must not discard the working sound; retry after combat or a zone change.
local UNIT_TOKEN = "player"

AuraSounds.registered = AuraSounds.registered or {}
AuraSounds.eventFrame = AuraSounds.eventFrame or nil

local function GetAddAuraSound()
    if type(C_UnitAuras) == "table" and type(C_UnitAuras.AddAuraSound) == "function" then
        return C_UnitAuras.AddAuraSound
    end
    return nil
end

local function GetRemoveAuraSound()
    if type(C_UnitAuras) == "table" and type(C_UnitAuras.RemoveAuraSound) == "function" then
        return C_UnitAuras.RemoveAuraSound
    end
    return nil
end

local function GetTrigger(auraTrigger)
    local enumTable = Enum and Enum.UnitAuraSoundTrigger
    if tostring(auraTrigger or ""):lower() == "applications" then
        return (enumTable and enumTable.ApplicationsIncreased) or 1
    end
    if tostring(auraTrigger or ""):lower() == "removed" then
        return (enumTable and enumTable.Removed) or 2
    end
    return (enumTable and enumTable.Added) or 0
end

local function IsCombatLocked()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local AURA_UNIT_TOKENS = { player = true, target = true, focus = true }

local function GetExplicitRecordUnit(record)
    if type(record) ~= "table" then
        return nil
    end
    local unit = tostring(record.auraUnit or ""):lower()
    if AURA_UNIT_TOKENS[unit] then
        return unit
    end
    return nil
end

local function SameRegistration(left, right)
    return left and right and left.spellID == right.spellID
        and left.trigger == right.trigger and left.unit == right.unit and left.path == right.path
end

-- Aura alerts come from the aura entries saved by the alert editor (the old
-- CDM records are migrated into them). They are not limited to the Cooldown
-- Manager skill list, so no availability check is applied.
function AuraSounds:BuildDesired()
    local desired = {}
    local function AddDesired(spellID, trigger, unit, path)
        for _, auraID in ipairs(Native:GetAuraSoundSpellIDs(spellID)) do
            local key = string.format("aura:%s:%d:%s", unit, auraID, trigger)
            desired[key] = {
                recordKey = key, sourceSpellID = spellID, spellID = auraID,
                trigger = GetTrigger(trigger), unit = unit, path = path,
            }
        end
    end
    local bridge = NS.Core and NS.Core.CDMAlertBridge
    if not bridge or type(bridge.BuildAuraEntries) ~= "function" then
        return desired
    end
    local classID, specID = Native:GetCurrentClassSpec()
    if not classID or not specID then
        return desired
    end
    -- CDM editor saves and imports can still produce legacy aura records after
    -- the one-time migration. They must participate in native registration.
    -- Those records do not know whether their aura lands on the player or the
    -- target (an enemy debuff like Garrote or Rupture), so both units are
    -- registered, matching Blizzard's own CooldownViewer aura tracking which
    -- scans player and target. An explicit unit, when present, wins.
    local store = NS.Core and NS.Core.CDMVoicePresetStore
    if store and type(store.GetEffectiveRecords) == "function" then
        for _, record in ipairs(store:GetEffectiveRecords(classID, specID)) do
            local trigger = bridge:GetAuraTriggerForEventKey(record.eventKey)
            local spellID = tonumber(record.spellID)
            local path = Native:ResolveRecordPath(record)
            if trigger and record.enabled ~= false and spellID and spellID > 0
                and type(path) == "string" and path ~= "" then
                local unit = GetExplicitRecordUnit(record)
                if unit then
                    AddDesired(spellID, trigger, unit, path)
                else
                    AddDesired(spellID, trigger, "player", path)
                    AddDesired(spellID, trigger, "target", path)
                end
            end
        end
    end
    for _, entry in ipairs(bridge:BuildAuraEntries(classID, specID)) do
        local spellID = tonumber(entry.spellID)
        local path = entry.voicePath
        if type(path) ~= "string" or path == "" then
            path = Native:ResolveRecordPath({ voiceName = entry.voiceName })
        end
        if spellID and spellID > 0 and type(path) == "string" and path ~= "" then
            AddDesired(spellID, entry.trigger, entry.auraUnit or UNIT_TOKEN, path)
        end
    end
    return desired
end

function AuraSounds:PrintDiagnostics(spellID)
    spellID = tonumber(spellID) or 0
    local L = NS.L or function(key, ...) return key end
    print("[QFX-SA] " .. L("AURA_DIAG_HEADER", spellID,
        tostring(GetAddAuraSound() ~= nil), tostring(IsCombatLocked()), tostring(self.pendingSync == true)))
    local found = false
    for key, wanted in pairs(self:BuildDesired()) do
        if spellID == 0 or wanted.sourceSpellID == spellID or wanted.spellID == spellID then
            found = true
            local active = self.registered[key]
            local registered = SameRegistration(active, wanted) and tostring(active.id) or "-"
            print("[QFX-SA] " .. L("AURA_DIAG_ENTRY", wanted.sourceSpellID, wanted.spellID,
                wanted.unit, wanted.trigger, registered, wanted.path))
        end
    end
    if not found then
        print("[QFX-SA] " .. L("AURA_DIAG_EMPTY"))
    end
end

function AuraSounds:Sync()
    local add, remove = GetAddAuraSound(), GetRemoveAuraSound()
    if not add or not remove then
        self.pendingSync = true
        return false, "api_unavailable"
    end
    if IsCombatLocked() then
        self.pendingSync = true
        return false, "restricted"
    end

    local desired = self:BuildDesired()

    local failed = false
    for recordKey, wanted in pairs(desired) do
        local previous = self.registered[recordKey]
        if not SameRegistration(previous, wanted) then
            local ok, id = pcall(add, wanted.trigger, {
                unitToken = wanted.unit or UNIT_TOKEN,
                spellID = wanted.spellID,
                soundFileName = wanted.path,
                outputChannel = "Master",
            })
            if ok and tonumber(id) then
                if previous and not pcall(remove, previous.id) then
                    pcall(remove, tonumber(id))
                    failed = true
                else
                    self.registered[recordKey] = {
                        id = tonumber(id),
                        spellID = wanted.spellID,
                        trigger = wanted.trigger,
                        unit = wanted.unit,
                        path = wanted.path,
                    }
                end
            else
                failed = true
            end
        end
    end
    for recordKey, entry in pairs(self.registered) do
        if not desired[recordKey] then
            if pcall(remove, entry.id) then
                self.registered[recordKey] = nil
            else
                failed = true
            end
        end
    end
    self.pendingSync = failed

    if failed and not self.failureNotified then
        self.failureNotified = true
        local message = type(NS.L) == "function" and NS.L("MSG_AURA_REGISTER_FAILED")
            or "Aura alert registration failed."
        print("[QFX-SA] " .. tostring(message))
    elseif not failed then
        self.failureNotified = false
    end
    return not failed, failed and "restricted" or nil
end

function AuraSounds:Initialize()
    if self.initialized or type(CreateFrame) ~= "function" then
        return
    end
    self.initialized = true

    local frame = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_SPECIALIZATION_CHANGED",
        "ADDON_LOADED",
    }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not AuraSounds.pendingSync then
            return
        end
        AuraSounds:Sync()
    end)
    self.eventFrame = frame
end

AuraSounds:Initialize()
