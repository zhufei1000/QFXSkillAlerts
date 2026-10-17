local function Equal(actual, expected, message)
    assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

QFXSkillAlertsNS = { Core = {}, Constants = {}, L = function(key) return key end }
Enum = { TtsVoiceType = { Standard = 0 } }
local selectedVoiceID = 9
local voices = { { voiceID = 7 }, { voiceID = 9 } }
local calls, messages = {}, {}
C_TTSSettings = {
    GetVoiceOptionID = function(voiceType)
        Equal(voiceType, Enum.TtsVoiceType.Standard, "standard voice type is required")
        return selectedVoiceID
    end,
}
C_VoiceChat = {
    GetTtsVoices = function() return voices end,
    SpeakText = function(...) calls[#calls + 1] = { ... } end,
}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
dofile("QFXSkillAlerts/Core/Notifier.lua")
local notifier = QFXSkillAlertsNS.Notifier
notifier.ShowVisualAlerts = function() return false end

Equal(notifier:GetSelectedVoiceID(), 9, "preserve an available selected voice even when it is not first")
selectedVoiceID = 999
Equal(notifier:GetSelectedVoiceID(), 7, "stale voice must fall back to an installed voice")
for _, method in ipairs({ "PlayReadyNotification", "PlayCastSuccessNotification", "PlayEventNotification", "PlayBloodlustNotification" }) do
    Equal(notifier[method](notifier, {
        notifyMode = "tts", soundSource = "tts", ttsText = "  自定义播报文本  ", ttsRate = 3, voiceEnabled = true,
    }), true, method .. " must submit speech")
    local call = calls[#calls]
    Equal(call[1], 7, method .. " voice")
    Equal(call[2], "自定义播报文本", method .. " text")
    Equal(call[3], 3, method .. " rate")
    Equal(call[4], 100, method .. " volume")
    Equal(call[5], false, method .. " overlap")
end
Equal(#messages, 0, "successful submissions must not report an error")

selectedVoiceID = 0
voices = { { voiceID = 0 } }
Equal(notifier:GetSelectedVoiceID(), 0, "voice zero is valid")
voices = {}
local callCount = #calls
Equal(notifier:SpeakTextTTS("test", 0), false, "no installed voices must fail")
Equal(#calls, callCount, "empty voice list must not submit an invalid saved voice")
Equal(messages[#messages], " MSG_NO_TTS", "missing voices must be reported")
voices = { { voiceID = 7 } }
Equal(notifier:SpeakTextTTS("test", 99), true)
Equal(calls[#calls][3], 10, "clamp rate")
Equal(notifier:SpeakTextTTS("  ", 0), false, "empty text must not play")

C_TTSSettings.GetVoiceOptionID = function() error("settings unavailable") end
Equal(notifier:GetSelectedVoiceID(), 7, "settings failure must use an installed voice")
C_TTSSettings = nil
Equal(notifier:GetSelectedVoiceID(), 7, "missing settings API must use an installed voice")
C_TTSSettings = { GetVoiceOptionID = function() return 9 end }
C_VoiceChat.GetTtsVoices = function() error("enumeration unavailable") end
Equal(notifier:GetSelectedVoiceID(), 9, "retain selected voice if enumeration fails")
C_VoiceChat.GetTtsVoices = nil
Equal(notifier:GetSelectedVoiceID(), 9, "retain selected voice if enumeration is unsupported")
C_VoiceChat.SpeakText = function() error("playback failed") end
Equal(notifier:SpeakTextTTS("test", 0), false, "submission failure must be reported")
Equal(messages[#messages], " MSG_TTS_FAILED", "report playback failure")
print("test_tts_playback: OK")
