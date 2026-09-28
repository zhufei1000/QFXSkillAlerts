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

-- Secret mode: any registered value reports true from issecretvalue, and the
-- poison aura errors if a secret aura field is ever read. The Bloodlust
-- handlers must detect the secret first and skip it untouched.
local secretValues = {}
local function MarkSecret(value)
    secretValues[value] = true
    return value
end

function issecretvalue(value)
    return secretValues[value] == true
end

local poisonAura = setmetatable({}, {
    __index = function(_, key)
        Fail("secret aura field '" .. tostring(key) .. "' must not be read")
    end,
})
MarkSecret(poisonAura)

local now = 1000
function GetTime() return now end

local secretMode = false
local aurasBySpellID = {}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        if secretMode then
            return poisonAura
        end
        return aurasBySpellID[spellID]
    end,
    GetAuraDataByAuraInstanceID = function(_unit, auraInstanceID)
        if secretMode then
            return poisonAura
        end
        return { spellId = auraInstanceID }
    end,
}

local notified = {}
local notifier = {
    PlayBloodlustNotification = function(_, cfg)
        notified[#notified + 1] = cfg
        return true
    end,
}

QFXSkillAlertsNS = {
    Core = {},
    Utils = {},
    Constants = {
        EXHAUSTION_IDS = { 57723 },
        EXHAUSTION_DURATION = 600,
        FRESH_WINDOW = 5,
        MODE_SOUND = "sound",
    },
}

dofile("QFXSkillAlerts/Core/Bloodlust.lua")
local Bloodlust = QFXSkillAlertsNS.Core.Bloodlust

Assert(Bloodlust:Rebuild({ bloodlustConfig = { voiceEnabled = true } }, nil), "bloodlust alert should be active")

-- 1) A fresh exhaustion aura announces normally when values are readable.
aurasBySpellID[57723] = { expirationTime = now + 595, spellId = 57723 }
local played = Bloodlust:HandleUnitAura("player", notifier, { addedAuras = { { spellId = 57723 } } })
Equal(played, true, "a readable fresh exhaustion aura should announce")
Equal(#notified, 1, "the readable path must announce exactly once")

-- 2) A secret player aura is skipped without reading any of its fields.
secretMode = true
local okSecretAura, secretAuraResult = pcall(Bloodlust.HandleUnitAura, Bloodlust, "player", notifier, { addedAuras = {} })
Assert(okSecretAura, "a secret player aura must not raise an error")
Equal(secretAuraResult, false, "a secret player aura must stay silent")
Equal(#notified, 1, "a secret player aura must not announce")

-- 3) updateInfo.updatedAuraInstanceIDs resolving to a secret aura is skipped.
local okUpdated, updatedResult = pcall(Bloodlust.HandleUnitAura, Bloodlust, "player", notifier, { updatedAuraInstanceIDs = { 42 } })
Assert(okUpdated, "a secret updated aura must not raise an error")
Equal(updatedResult, false, "a secret updated aura must stay silent")

-- 4) A whole secret addedAuras payload is treated as possibly containing exhaustion.
secretMode = false
aurasBySpellID[57723] = nil
local okSecretList, secretListResult = pcall(Bloodlust.HandleUnitAura, Bloodlust, "player", notifier, { addedAuras = poisonAura })
Assert(okSecretList, "a secret addedAuras payload must not raise an error")
Equal(secretListResult, false, "a secret addedAuras payload must stay silent")

-- 5) A secret isFullUpdate flag is treated as a full update.
local secretFlag = MarkSecret("secret-flag")
Equal(Bloodlust:UpdateMayContainExhaustion({ isFullUpdate = secretFlag }), true,
    "a secret isFullUpdate must be treated as a full update")
Equal(Bloodlust:UpdateMayContainExhaustion({ isFullUpdate = true }), true,
    "a plain full update must be treated as a full update")

-- 6) A secret spellId on an added aura is treated as possibly containing exhaustion.
local auraWithSecretSpellID = { spellId = secretFlag, spellID = 57723 }
Equal(Bloodlust:UpdateMayContainExhaustion({ addedAuras = { auraWithSecretSpellID } }), true,
    "a secret spellId must be treated as possibly containing exhaustion")

-- 7) Unrelated readable auras still short-circuit to silent.
Equal(Bloodlust:UpdateMayContainExhaustion({ addedAuras = { { spellId = 12345 } } }), false,
    "unrelated readable auras must not arm a Bloodlust lookup")

-- 8) A readable but stale exhaustion aura stays silent.
aurasBySpellID[57723] = { expirationTime = now + 100, spellId = 57723 }
local staleResult = Bloodlust:HandleUnitAura("player", notifier, { addedAuras = { { spellId = 57723 } } })
Equal(staleResult, false, "a stale exhaustion aura must stay silent")
Equal(#notified, 1, "a stale exhaustion aura must not announce")

print("PASS: bloodlust secret guards")
