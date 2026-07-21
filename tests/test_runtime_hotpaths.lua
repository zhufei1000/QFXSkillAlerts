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

function wipe(values)
    for key in pairs(values or {}) do
        values[key] = nil
    end
    return values
end

-- UNIT_AURA incremental filtering: unrelated aura changes must not issue eight
-- exhaustion lookups on a combat-hot event.
QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        EXHAUSTION_IDS = { 57723, 57724, 80354, 95809, 160455, 207400, 264689, 390435 },
        EXHAUSTION_DURATION = 600,
        FRESH_WINDOW = 5,
    },
}
local now = 100
function GetTime() return now end
local exhaustionQueries = 0
local auraByInstance = {}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        exhaustionQueries = exhaustionQueries + 1
        if spellID == 57723 then
            return { spellId = spellID, expirationTime = now + 600 }
        end
    end,
    GetAuraDataByAuraInstanceID = function(_, auraInstanceID)
        return auraByInstance[auraInstanceID]
    end,
}
dofile("QFXSkillAlerts/Core/Bloodlust.lua")
local Bloodlust = QFXSkillAlertsNS.Core.Bloodlust
local played = 0
local notifier = {
    PlayBloodlustNotification = function()
        played = played + 1
        return true
    end,
}

exhaustionQueries = 0
Assert(not Bloodlust:HandleUnitAura("player", notifier, {
    isFullUpdate = false,
    addedAuras = { { spellId = 12345 } },
}), "unrelated added aura should be ignored")
Equal(exhaustionQueries, 0, "unrelated aura update must not scan exhaustion IDs")

exhaustionQueries = 0
Assert(Bloodlust:HandleUnitAura("player", notifier, {
    isFullUpdate = false,
    addedAuras = { { spellId = 57723 } },
}), "fresh exhaustion aura should notify")
Equal(exhaustionQueries, 1, "related aura should stop after the matching exhaustion ID")
Equal(played, 1, "fresh exhaustion should play once")

auraByInstance[7] = { spellId = 12345 }
exhaustionQueries = 0
Assert(not Bloodlust:HandleUnitAura("player", notifier, {
    isFullUpdate = false,
    updatedAuraInstanceIDs = { 7 },
}), "unrelated updated aura should be ignored")
Equal(exhaustionQueries, 0, "unrelated updated aura must not scan exhaustion IDs")

-- Runtime interval lookup is cached for the active processing period instead
-- of being called on every rendered frame near the update threshold.
local runtimeFrame
function CreateFrame()
    runtimeFrame = runtimeFrame or {}
    function runtimeFrame:SetScript(name, callback)
        self[name] = callback
    end
    return runtimeFrame
end
local runtimeNow = 200
function GetTime() return runtimeNow end
function UnitAffectingCombat() return false end
QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        MODE_SOUND = "sound",
        UPDATE_INTERVAL_COMBAT = 0.10,
        UPDATE_INTERVAL_IDLE = 0.16,
    },
    Utils = {},
}
dofile("QFXSkillAlerts/Core/Runtime.lua")
local Runtime = QFXSkillAlertsNS.Core.Runtime
local intervalQueries = 0
Runtime:Configure({
    getUpdateInterval = function()
        intervalQueries = intervalQueries + 1
        return 0.16
    end,
})
Runtime:StartCooldown(1001, { [1001] = "spell:1001" }, {
    ["spell:1001"] = {
        spellId = 1001,
        objectID = 1001,
        objectType = "spell",
        spellName = "Test",
        baseCD = 10,
        chargeInput = 1,
        voiceEnabled = false,
        imageEnabled = false,
        textEnabled = false,
    },
})
Assert(type(runtimeFrame.OnUpdate) == "function", "active cooldown should install OnUpdate")
Equal(intervalQueries, 1, "StartUpdate should read the interval once")
for _ = 1, 9 do
    runtimeNow = runtimeNow + 0.016
    runtimeFrame.OnUpdate(runtimeFrame, 0.016)
end
Equal(intervalQueries, 1, "sub-threshold frames must reuse the cached interval")
runtimeNow = runtimeNow + 0.016
runtimeFrame.OnUpdate(runtimeFrame, 0.016)
Equal(intervalQueries, 2, "completed processing period should refresh interval once")

print("Runtime hot-path regression tests passed")
