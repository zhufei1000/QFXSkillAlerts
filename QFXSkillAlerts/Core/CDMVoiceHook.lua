local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.Core = NS.Core or {}
NS.Core.CDMVoiceHook = NS.Core.CDMVoiceHook or {}

local Hook = NS.Core.CDMVoiceHook
local Registry = NS.Core.CDMVoiceRegistry

Hook.missingPayloadNotified = Hook.missingPayloadNotified or {}

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

function Hook:NotifyMissingOnce(payload)
    local key = tostring(payload)
    if self.missingPayloadNotified[key] then
        return
    end
    self.missingPayloadNotified[key] = true
    local message = type(NS.L) == "function" and NS.L("CDM_MISSING_VOICE") or "Missing voice"
    print("[QFX-SA] " .. tostring(message) .. " (payload: " .. key .. ")")
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
    if not payload or not Registry:IsOwnedPayload(payload) then
        return
    end

    local path = Registry:GetPathForPayload(payload)
    if type(path) ~= "string" or path == "" then
        self:NotifyMissingOnce(payload)
        return
    end

    if type(PlaySoundFile) == "function" then
        pcall(PlaySoundFile, path, "Master")
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
        Hook:HandleAlert(alert)
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
