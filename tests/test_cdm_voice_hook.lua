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
local AVAILABLE = 1
local PANDEMIC_TIME = 2
local ON_COOLDOWN = 3
local CHARGE_GAINED = 4
local AURA_APPLIED = 5
local AURA_REMOVED = 6
local PAYLOAD = -123456789
local FOREIGN_PAYLOAD = -555555

local prints = {}
local realPrint = print
print = function(...)
    prints[#prints + 1] = table.concat({ ... }, " ")
end

local now = 100
function GetTime()
    return now
end

local playCalls = {}
local playResult = true
function PlaySoundFile(path, channel)
    playCalls[#playCalls + 1] = { path = path, channel = channel }
    return playResult
end

Enum = {
    CooldownViewerAlertType = { Sound = SOUND, Visual = VISUAL },
    CooldownViewerAlertEventType = {
        Available = AVAILABLE,
        PandemicTime = PANDEMIC_TIME,
        OnCooldown = ON_COOLDOWN,
        ChargeGained = CHARGE_GAINED,
        OnAuraApplied = AURA_APPLIED,
        OnAuraRemoved = AURA_REMOVED,
    },
}

function CooldownViewerAlert_GetType(alert) return alert[1] end
function CooldownViewerAlert_GetPayload(alert) return alert[3] end
function CooldownViewerAlert_GetEvent(alert) return alert[2] end
function CooldownViewerAlert_PlayAlert() end

local hookedCallbacks = {}
function hooksecurefunc(name, callback)
    hookedCallbacks[name] = callback
end

QFXSkillAlertsDB = {}

QFXSkillAlertsNS = {
    Core = {},
    L = function(key, ...)
        local count = select("#", ...)
        if count > 0 then
            return tostring(key) .. ":" .. tostring((...))
        end
        return tostring(key)
    end,
}

local itemsByPayload = {
    [PAYLOAD] = { path = "Interface\\AddOns\\Test\\a.ogg" },
}
QFXSkillAlertsNS.Core.CDMVoiceRegistry = {
    GetItemForPayload = function(_, payload) return itemsByPayload[payload] end,
    IsOwnedPayload = function(_, payload) return itemsByPayload[payload] ~= nil end,
}
QFXSkillAlertsNS.Core.CDMNativeEvents = {
    IsNativeAlertEventType = function(_, eventType)
        return tonumber(eventType) == AVAILABLE
            or tonumber(eventType) == ON_COOLDOWN
            or tonumber(eventType) == AURA_APPLIED
            or tonumber(eventType) == AURA_REMOVED
    end,
}

dofile("QFXSkillAlerts/Core/CDMVoiceHook.lua")

local Hook = QFXSkillAlertsNS.Core.CDMVoiceHook
Assert(Hook, "hook module should load")

Assert(Hook:Install(), "install should succeed once hooksecurefunc and PlayAlert exist")
Assert(type(hookedCallbacks["CooldownViewerAlert_PlayAlert"]) == "function", "PlayAlert hook should be registered")

local function Fire(alert, cooldownItem)
    hookedCallbacks["CooldownViewerAlert_PlayAlert"](cooldownItem, nil, alert)
end

local function Alert(payload, eventType, alertType)
    return { alertType or SOUND, eventType or CHARGE_GAINED, payload }
end

-- Foreign payloads never play and never print.
Fire(Alert(FOREIGN_PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 0, "foreign payload should not play")
Equal(#prints, 0, "foreign payload should not print")

-- Non-sound alerts are ignored.
Fire(Alert(PAYLOAD, CHARGE_GAINED, VISUAL))
Equal(#playCalls, 0, "visual alerts should be ignored")

-- Native events are played by the addon runtimes and must stay silent here.
for _, nativeEvent in ipairs({ AVAILABLE, ON_COOLDOWN, AURA_APPLIED, AURA_REMOVED }) do
    Fire(Alert(PAYLOAD, nativeEvent))
end
Equal(#playCalls, 0, "native events should not play from the CDM hook")

-- Charge and pandemic alerts keep playing from the hook.
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 1, "charge alert should play")
Equal(playCalls[1].channel, "Master", "voice should play on the Master channel")

-- Repeat within the duplicate window is suppressed.
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 1, "repeat inside the duplicate window should be suppressed")

-- After the window the same payload and event play again.
now = now + 0.3
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 2, "repeat after the duplicate window should play")

-- A different event is not suppressed by the previous event.
Fire(Alert(PAYLOAD, PANDEMIC_TIME))
Equal(#playCalls, 3, "different event should play immediately")

-- Playback failure is reported once per payload.
playResult = nil
now = now + 1
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 4, "failed play still attempts playback")
Equal(#prints, 1, "playback failure should print once")
Assert(prints[1]:find("CDM_PLAY_FAILED", 1, true), "failure message should use the localized key")

now = now + 1
Fire(Alert(PAYLOAD, PANDEMIC_TIME))
Equal(#prints, 1, "second playback failure should not print again")

-- The duplicate window can be configured through the database.
playResult = true
QFXSkillAlertsDB.cdmVoiceUI = { duplicateWindow = 0 }
now = now + 1
Fire(Alert(PAYLOAD, CHARGE_GAINED))
now = now + 0.01
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#playCalls, 7, "a zero window should disable suppression")
QFXSkillAlertsDB.cdmVoiceUI = nil

-- Errors inside the handler are swallowed by the hook wrapper and reported once.
QFXSkillAlertsNS.Core.CDMVoiceRegistry.GetItemForPayload = function()
    error("boom")
end
local printsBefore = #prints
Fire(Alert(PAYLOAD, CHARGE_GAINED))
Equal(#prints, printsBefore + 1, "handler error should be reported once")
Fire(Alert(PAYLOAD, PANDEMIC_TIME))
Equal(#prints, printsBefore + 1, "later handler errors should stay quiet")

print = realPrint
print("CDM voice hook regression tests passed")
