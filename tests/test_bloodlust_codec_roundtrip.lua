local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

QFXSkillAlertsNS = {
    L = function(key, ...)
        if select("#", ...) > 0 then
            return string.format(tostring(key), ...)
        end
        return tostring(key)
    end,
}

dofile("QFXSkillAlerts/Ace3/LibStub/LibStub.lua")
dofile("QFXSkillAlerts_Config/Ace3/AceSerializer-3.0/AceSerializer-3.0.lua")
dofile("QFXSkillAlerts_Config/Libs/LibDeflate/LibDeflate.lua")
dofile("QFXSkillAlerts_Config/Core/ImportCodec.lua")

local payload = {
    type = "bloodlust",
    version = 1,
    bloodlustConfig = {
        voiceEnabled = true,
        notifyMode = "sound",
        soundSource = "sharedmedia",
        sharedMediaSound = "Raid Horn",
        customSoundPaths = {
            "Interface\\AddOns\\SharedMedia\\RaidHorn.ogg",
            "",
            "",
            "",
            "",
        },
        imageEnabled = true,
        textEnabled = true,
        textAlert = "Bloodlust!",
    },
}

local encoded = QFXSkillAlertsNS.ImportCodec:Encode(payload)
Assert(type(encoded) == "string" and encoded:sub(1, 9) == "!QFXSA:1!",
    "the real codec must encode a Bloodlust payload")

local decoded, err = QFXSkillAlertsNS.ImportCodec:Decode(encoded)
Assert(type(decoded) == "table", "the real codec must decode the Bloodlust payload: " .. tostring(err))
Assert(decoded.type == "bloodlust", "the payload type must survive the codec")
Assert(decoded.bloodlustConfig.soundSource == "sharedmedia", "the sound source must survive the codec")
Assert(decoded.bloodlustConfig.sharedMediaSound == "Raid Horn", "the SharedMedia name must survive the codec")
Assert(decoded.bloodlustConfig.customSoundPaths[1] == payload.bloodlustConfig.customSoundPaths[1],
    "custom voice paths must survive the codec")
Assert(decoded.bloodlustConfig.textAlert == "Bloodlust!", "visual/text settings must survive the codec")

print("bloodlust real-codec roundtrip tests passed")
