local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

QFXSkillAlertsNS = { Core = {}, Constants = {}, Utils = {} }
dofile("QFXSkillAlerts/Core/Notifier.lua")
local Notifier = QFXSkillAlertsNS.Core.Notifier

Equal(Notifier:FormatCooldownCountdown(65), "1m5s", "65 seconds format")
Equal(Notifier:FormatCooldownCountdown(60), "1m", "whole minute format")
Equal(Notifier:FormatCooldownCountdown(59.01), "1m", "remaining time rounds upward")
Equal(Notifier:FormatCooldownCountdown(58.99), "59s", "sub-minute format")
Equal(Notifier:FormatCooldownCountdown(0), "0s", "zero format")

print("countdown format regression tests passed")
