local NS = rawget(_G, "QFXSkillAlertsNS") or {}
_G.QFXSkillAlertsNS = NS

NS.ImportCDMVoicePresetProcessor = NS.ImportCDMVoicePresetProcessor or {}

local Processor = NS.ImportCDMVoicePresetProcessor

function Processor:Import(payload)
    payload = type(payload) == "table" and payload or {}
    if payload.type ~= "cdmVoicePreset" or tonumber(payload.version) ~= 1 or type(payload.profiles) ~= "table" then
        return false, 0, nil, "invalid_version"
    end
    local api = NS.API
    if not api or type(api.ImportCDMVoicePresetPayload) ~= "function" then
        return false, 0, nil, "not_available"
    end
    return api.ImportCDMVoicePresetPayload(payload)
end
