local function Assert(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

_G.GetLocale = function() return "enUS" end
_G.QFXSkillAlertsNS = nil

dofile("QFXSkillAlerts/Core/Constants.lua")
dofile("QFXSkillAlerts/Localization.lua")

local NS = _G.QFXSkillAlertsNS
local C = NS.Constants
local L = NS.L

-- Display layers: unique, and the default must be one of the offered options.
local strataSeen = {}
local strataDefaultFound = false
for _, strata in ipairs(C.VISUAL_STRATA_OPTIONS or {}) do
    Assert(type(strata) == "string" and strata ~= "", "strata option must be a non-empty string")
    Assert(not strataSeen[strata], "strata options must be unique: " .. tostring(strata))
    strataSeen[strata] = true
    local label = L("STRATA_" .. strata)
    Assert(label ~= ("STRATA_" .. strata), "every strata option needs a localized label: " .. strata)
    if strata == C.VISUAL_STRATA_DEFAULT then
        strataDefaultFound = true
    end
end
Assert(strataDefaultFound, "the default strata must be part of the option list")

-- End-display events: unique, every event has a localized label, and the
-- player state events the feature is built around are present.
local eventSeen = {}
local requiredEvents = {
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}
for _, def in ipairs(C.VISUAL_END_EVENTS or {}) do
    local eventName = type(def) == "table" and def.event or def
    Assert(type(eventName) == "string" and eventName ~= "", "end event must be a non-empty string")
    Assert(not eventSeen[eventName], "end events must be unique: " .. tostring(eventName))
    eventSeen[eventName] = true
    local label = L("END_EVENT_" .. eventName)
    Assert(label ~= ("END_EVENT_" .. eventName), "every end event needs a localized label: " .. eventName)
end
for _, eventName in ipairs(requiredEvents) do
    Assert(eventSeen[eventName], "required end event missing: " .. eventName)
end

-- Unit-filtered events must be marked so other units cannot end the display.
local specDef = nil
for _, def in ipairs(C.VISUAL_END_EVENTS or {}) do
    if type(def) == "table" and def.event == "PLAYER_SPECIALIZATION_CHANGED" then
        specDef = def
    end
end
Assert(specDef and specDef.unit == true, "PLAYER_SPECIALIZATION_CHANGED must be unit-filtered")

print("visual end event / strata definition tests passed")
