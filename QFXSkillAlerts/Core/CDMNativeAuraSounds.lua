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
-- Registrations are in-memory: they are rebuilt after loading screens, zone
-- changes and spec changes. AddAuraSound is restricted during encounters and
-- M+/PvP matches, so a failed sync is retried when combat ends or the player
-- zones.
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

-- Aura alerts come from the aura entries saved by the alert editor (the old
-- CDM records are migrated into them). They are not limited to the Cooldown
-- Manager skill list, so no availability check is applied.
function AuraSounds:BuildDesired()
    local desired = {}
    local bridge = NS.Core and NS.Core.CDMAlertBridge
    if not bridge or type(bridge.BuildAuraEntries) ~= "function" then
        return desired
    end
    local classID, specID = Native:GetCurrentClassSpec()
    if not classID or not specID then
        return desired
    end
    for _, entry in ipairs(bridge:BuildAuraEntries(classID, specID)) do
        local spellID = tonumber(entry.spellID)
        local path = entry.voicePath
        if type(path) ~= "string" or path == "" then
            path = Native:ResolveRecordPath({ voiceName = entry.voiceName })
        end
        if spellID and spellID > 0 and type(path) == "string" and path ~= "" then
            desired[entry.recordKey] = {
                recordKey = entry.recordKey,
                spellID = spellID,
                trigger = GetTrigger(entry.trigger),
                unit = entry.auraUnit or UNIT_TOKEN,
                path = path,
            }
        end
    end
    return desired
end

-- Removes every known registration. Used on loading screens, where the client
-- may reset the registrations before the next sync.
function AuraSounds:Teardown()
    local remove = GetRemoveAuraSound()
    if remove then
        for _, entry in pairs(self.registered) do
            pcall(remove, entry.id)
        end
    end
    self.registered = {}
end

function AuraSounds:Sync()
    local add, remove = GetAddAuraSound(), GetRemoveAuraSound()
    if not add or not remove then
        return false, "api_unavailable"
    end

    local desired = self:BuildDesired()

    for recordKey, entry in pairs(self.registered) do
        local wanted = desired[recordKey]
        if not wanted
            or wanted.spellID ~= entry.spellID
            or wanted.trigger ~= entry.trigger
            or wanted.unit ~= entry.unit
            or wanted.path ~= entry.path then
            pcall(remove, entry.id)
            self.registered[recordKey] = nil
        end
    end

    local failed = false
    for recordKey, wanted in pairs(desired) do
        if not self.registered[recordKey] then
            local ok, id = pcall(add, wanted.trigger, {
                unitToken = wanted.unit or UNIT_TOKEN,
                spellID = wanted.spellID,
                soundFileName = wanted.path,
                outputChannel = "Master",
            })
            if ok and tonumber(id) then
                self.registered[recordKey] = {
                    id = tonumber(id),
                    spellID = wanted.spellID,
                    trigger = wanted.trigger,
                    unit = wanted.unit,
                    path = wanted.path,
                }
            else
                failed = true
            end
        end
    end

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
        "LOADING_SCREEN_ENABLED",
    }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "LOADING_SCREEN_ENABLED" then
            AuraSounds:Teardown()
            return
        end
        if event == "PLAYER_REGEN_ENABLED" and not next(AuraSounds.registered) then
            -- Only worth retrying when a previous sync failed; skip the common
            -- case where nothing is registered because nothing is configured.
            local desired = AuraSounds:BuildDesired()
            if not next(desired) then
                return
            end
        end
        AuraSounds:Sync()
    end)
    self.eventFrame = frame
end

AuraSounds:Initialize()
