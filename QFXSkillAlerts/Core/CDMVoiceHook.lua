local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceHook = NS.Core.CDMVoiceHook or {}

local Hook = NS.Core.CDMVoiceHook
local Registry = NS.Core.CDMVoiceRegistry
local Native = NS.Core.CDMNativeEvents

Hook.missingPayloadNotified = Hook.missingPayloadNotified or {}
Hook.playFailedNotified = Hook.playFailedNotified or {}
Hook.lastPlayedAt = Hook.lastPlayedAt or {}

-- The Cooldown Manager can fire the same alert several times in a row (the
-- same spell can sit in more than one viewer, and an event can retrigger
-- across consecutive frames). Blizzard's own sound kits collapse that into
-- one audible sound; PlaySoundFile does not, so a file would stutter. Collapse
-- repeats here. A zero or negative window disables the suppression.
local DEFAULT_DUPLICATE_WINDOW = 0.25

local function GetDuplicateWindow()
    local db = type(QFXSkillAlertsDB) == "table" and QFXSkillAlertsDB or nil
    local ui = db and type(db.cdmVoiceUI) == "table" and db.cdmVoiceUI or nil
    local value = ui and tonumber(ui.duplicateWindow)
    if value and value >= 0 then
        return value
    end
    return DEFAULT_DUPLICATE_WINDOW
end

local function IsCooldownViewerLoaded()
    if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
        return C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer")
    end
    if type(IsAddOnLoaded) == "function" then
        return IsAddOnLoaded("Blizzard_CooldownViewer")
    end
    return false
end

local function GetAlertType(alert)
    if type(alert) ~= "table" then
        return nil
    end
    if type(CooldownViewerAlert_GetType) == "function" then
        local ok, value = pcall(CooldownViewerAlert_GetType, alert)
        if ok then
            return value
        end
    end
    return alert[1]
end

local function GetAlertPayload(alert)
    if type(alert) ~= "table" then
        return nil
    end
    if type(CooldownViewerAlert_GetPayload) == "function" then
        local ok, value = pcall(CooldownViewerAlert_GetPayload, alert)
        if ok then
            return tonumber(value)
        end
    end
    return tonumber(alert[3])
end

local function GetAlertEvent(alert)
    if type(alert) ~= "table" then
        return nil
    end
    if type(CooldownViewerAlert_GetEvent) == "function" then
        local ok, value = pcall(CooldownViewerAlert_GetEvent, alert)
        if ok then
            return tonumber(value)
        end
    end
    return tonumber(alert[2])
end

-- Ready / cooldown-start / aura events are played by the addon's own runtimes
-- (CDMNativeWatch and CDMNativeAuraSounds). Alerts left in the Cooldown
-- Manager layout from earlier versions must stay silent so a voice is never
-- played twice; the shared check lives in CDMNativeEvents.

function Hook:NotifyMissingOnce(payload)
    local key = tostring(payload)
    if self.missingPayloadNotified[key] then
        return
    end
    self.missingPayloadNotified[key] = true
    local message = type(NS.L) == "function" and NS.L("CDM_MISSING_VOICE") or "Missing voice"
    print("[QFX-SA] " .. tostring(message) .. " (payload: " .. key .. ")")
end

function Hook:NotifyPlayFailedOnce(payload, path)
    local key = tostring(payload)
    if self.playFailedNotified[key] then
        return
    end
    self.playFailedNotified[key] = true
    local message
    if type(NS.L) == "function" then
        message = NS.L("CDM_PLAY_FAILED", tostring(path))
    else
        message = "Could not play the Cooldown Manager voice: " .. tostring(path)
    end
    print("[QFX-SA] " .. tostring(message) .. " (payload: " .. key .. ")")
end

function Hook:IsDuplicate(payload, eventType)
    local window = GetDuplicateWindow()
    if window <= 0 then
        return false
    end
    local now = type(GetTime) == "function" and GetTime() or 0
    local key = tostring(payload) .. ":" .. tostring(eventType or "?")
    local last = self.lastPlayedAt[key]
    if last and (now - last) < window then
        return true
    end
    self.lastPlayedAt[key] = now
    return false
end

function Hook:HandleAlert(alert)
    if type(Registry) ~= "table" then
        return
    end
    local soundType = Enum and Enum.CooldownViewerAlertType and Enum.CooldownViewerAlertType.Sound
    if soundType == nil or GetAlertType(alert) ~= soundType then
        return
    end

    local payload = GetAlertPayload(alert)
    if not payload then
        return
    end

    local eventType = GetAlertEvent(alert)

    -- Native events are handled by the addon itself; stale CDM alerts must stay
    -- silent so a voice is never played twice. Charge and pandemic alerts keep
    -- playing from here.
    if Native and type(Native.IsNativeAlertEventType) == "function"
        and Native:IsNativeAlertEventType(eventType) then
        return
    end

    -- Almost every Blizzard CDM sound alert is not owned by QFX. Check the
    -- in-memory registry first so the common path never touches SavedVariables.
    local item = Registry:GetItemForPayload(payload)
    if not item then
        if not Registry:IsOwnedPayload(payload) then return end
        self:NotifyMissingOnce(payload)
        return
    end
    local path = item.path
    if type(path) ~= "string" or path == "" then
        self:NotifyMissingOnce(payload)
        return
    end

    if self:IsDuplicate(payload, eventType) then
        return
    end

    if type(PlaySoundFile) == "function" then
        local ok, willPlay = pcall(PlaySoundFile, path, "Master")
        if ok and not willPlay then
            self:NotifyPlayFailedOnce(payload, path)
        end
    end
end

function Hook:Install()
    if self.hooked then
        return true
    end
    if type(hooksecurefunc) ~= "function" or type(CooldownViewerAlert_PlayAlert) ~= "function" then
        return false
    end

    hooksecurefunc("CooldownViewerAlert_PlayAlert", function(_cooldownItem, _spellName, alert)
        local ok, err = pcall(Hook.HandleAlert, Hook, alert)
        if not ok and not Hook.errorNotified then
            Hook.errorNotified = true
            print("[QFX-SA] Cooldown Manager voice hook error: " .. tostring(err))
        end
    end)
    self.hooked = true
    return true
end

function Hook:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    if IsCooldownViewerLoaded() then
        self:Install()
    end

    if type(CreateFrame) == "function" then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(_, _, addonName)
            if addonName == "Blizzard_CooldownViewer" and Hook:Install() then
                frame:UnregisterEvent("ADDON_LOADED")
            end
        end)
        self.eventFrame = frame
    end
end

Hook:Initialize()
