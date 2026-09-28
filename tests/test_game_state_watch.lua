-- Game-cooldown-state watch: non-fixed-CD entries announce from the
-- NeverSecret API readiness booleans (isActive / isOnGCD / charges) instead of
-- a fixed number, because cooldown numbers are secret in restricted combat.
-- CD modes: "fixed" (fixed timer), "ready" (spell-cooldown readiness edge),
-- "cooldown" (real cooldown start) and "charge" (charge recharge finished).
-- Casts are queued from
-- UNIT_SPELLCAST_SUCCEEDED; the watch must never listen for Blizzard's
-- secret-sensitive SPELL_UPDATE_COOLDOWN/SPELL_UPDATE_CHARGES events, because
-- sharing those events taints the CooldownViewer handlers.

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

local runtimeFrame
function CreateFrame()
    runtimeFrame = runtimeFrame or {}
    function runtimeFrame:SetScript(name, callback)
        self[name] = callback
    end
    return runtimeFrame
end

local now = 100
function GetTime() return now end
function UnitAffectingCombat() return true end

QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        MODE_SOUND = "sound",
        UPDATE_INTERVAL_COMBAT = 0.10,
        UPDATE_INTERVAL_IDLE = 0.16,
    },
    Utils = {},
}

local cooldownState = {}
local chargeState = {}
C_Spell = {
    GetSpellCooldown = function(spellID) return cooldownState[spellID] end,
    GetSpellCharges = function(spellID) return chargeState[spellID] end,
}

dofile("QFXSkillAlerts/Core/Runtime.lua")
local Runtime = QFXSkillAlertsNS.Core.Runtime

local played = {}
Runtime:Configure({
    getUpdateInterval = function() return 0.10 end,
    playReady = function(cd, channel)
        played[#played + 1] = { cd = cd, channel = channel }
        return true
    end,
})

local function MakeCfg(spellID, name, mode)
    return {
        gameStateCD = true,
        cdMode = mode or "ready",
        triggerSpellID = spellID,
        spellId = spellID,
        objectID = spellID,
        objectType = "spell",
        spellName = name or ("Spell" .. tostring(spellID)),
        baseCD = 0,
        chargeInput = 1,
        voiceEnabled = true,
        imageEnabled = false,
        textEnabled = false,
    }
end

local function Reset()
    Runtime:WipeCooldowns(false)
    wipe(cooldownState)
    wipe(chargeState)
    runtimeFrame.OnUpdate = nil
end

-- 1) A cast is queued, waits for the client to report the real cooldown, and
--    stays silent while the real cooldown is running.
Reset()
local cfgA = MakeCfg(3001)
local mapsA = { [3001] = "spell:3001" }
local cfgMapA = { ["spell:3001"] = cfgA }
cooldownState[3001] = { isActive = false, isEnabled = true, isOnGCD = false }
Assert(Runtime:QueueGameCooldown(3001, mapsA, cfgMapA), "cast should queue a game watch")
Assert(type(runtimeFrame.OnUpdate) == "function", "queued watch should start the update loop")
Equal(Runtime:EvaluateGameCooldowns(now), true, "queued cast stays alive while waiting")
Equal(#played, 0, "queued cast must not announce")

cooldownState[3001] = { isActive = true, isEnabled = true, isOnGCD = false }
Equal(Runtime:EvaluateGameCooldowns(now), true, "the real cooldown should arm from the queue")
Equal(#played, 0, "an active cooldown must not announce")

-- 2) The ready edge must announce even while a post-ready GCD is still running
--    (isActive stays true through the GCD; only a real non-GCD cooldown should
--    hold the announcement back).
now = now + 2.0
cooldownState[3001] = { isActive = true, isEnabled = true, isOnGCD = true }
Equal(Runtime:EvaluateGameCooldowns(now), true, "first ready tick should confirm readiness")
runtimeFrame.OnUpdate(runtimeFrame, 0.2)
Equal(#played, 1, "the ready edge must announce exactly once, even during a GCD")
Equal(played[1].channel, "voice", "the game-state watch announces on the voice channel")
Equal(played[1].cd and played[1].cd.spellName, "Spell3001", "the announcement carries the saved spell name")
Equal(runtimeFrame.OnUpdate, nil, "an empty watch must stop the update loop")

-- 3) An arm that resolves faster than the min-arm guard (a short/GCD-only race)
--    must be dropped without announcing.
now = now + 10
cooldownState[3001] = nil
Runtime:QueueGameCooldown(3001, mapsA, cfgMapA)
cooldownState[3001] = { isActive = true, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
now = now + 0.5
cooldownState[3001] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
Runtime:EvaluateGameCooldowns(now)
Equal(#played, 1, "sub-threshold arms must not announce")

-- 4) A GCD-only cast (no real cooldown ever reported) must never announce.
now = now + 10
cooldownState[3001] = nil
Runtime:QueueGameCooldown(3001, mapsA, cfgMapA)
cooldownState[3001] = { isActive = true, isEnabled = true, isOnGCD = true }
Runtime:EvaluateGameCooldowns(now)
now = now + 0.5
cooldownState[3001] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
now = now + 4.0
Equal(Runtime:EvaluateGameCooldowns(now), false, "a GCD-only cast should expire silently")
Equal(#played, 1, "a GCD-only cast must not announce")

-- 5) A cooldown already running at login/reload is primed from the config.
now = now + 10
local cfgB = MakeCfg(3002, "Primed")
local mapsB = { [3002] = "spell:3002" }
local cfgMapB = { ["spell:3002"] = cfgB }
cooldownState[3002] = { isActive = true, isEnabled = true, isOnGCD = false }
Runtime:PrimeGameCooldowns(cfgMapB)
now = now + 2.0
cooldownState[3002] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
Runtime:EvaluateGameCooldowns(now)
Equal(#played, 2, "a primed mid-cooldown entry must announce on its ready edge")

-- 6) "ready" mode uses the spell-cooldown predicate even for charge spells, so
--    a charge in hand announces while the remaining charges still recharge.
now = now + 10
local cfgR = MakeCfg(3005, "ReadyCharges", "ready")
local mapsR = { [3005] = "spell:3005" }
local cfgMapR = { ["spell:3005"] = cfgR }
cooldownState[3005] = { isActive = true, isEnabled = true, isOnGCD = false }
chargeState[3005] = { maxCharges = 2, isActive = true }
Runtime:QueueGameCooldown(3005, mapsR, cfgMapR)
Runtime:EvaluateGameCooldowns(now)
now = now + 2.0
cooldownState[3005] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
Runtime:EvaluateGameCooldowns(now)
Equal(#played, 3, "ready mode must announce from the cooldown predicate regardless of charges")

-- 7) "charge" mode announces when the recharge returns to max.
now = now + 10
local cfgC = MakeCfg(3003, "Charged", "charge")
local mapsC = { [3003] = "spell:3003" }
local cfgMapC = { ["spell:3003"] = cfgC }
chargeState[3003] = { maxCharges = 2, isActive = true }
Runtime:QueueGameCooldown(3003, mapsC, cfgMapC)
Equal(Runtime:EvaluateGameCooldowns(now), true, "a recharging charge spell should arm")
now = now + 2.0
chargeState[3003] = { maxCharges = 2, isActive = false }
Runtime:EvaluateGameCooldowns(now)
Equal(#played, 4, "a charge refill to max must announce")
Equal(played[4].cd and played[4].cd.spellName, "Charged", "the charge announcement carries the saved spell name")

-- 8) gameStateCD entries never start the fixed-CD timer, even when a cast
--    success arrives for the same spell.
Reset()
cooldownState[3001] = { isActive = true, isEnabled = true, isOnGCD = false }
Runtime:StartCooldown(3001, mapsA, cfgMapA)
Equal(next(Runtime:GetCooldownTable()), nil, "game-state entries must not create a fixed timer")

-- 9) Wiping cooldowns also drops queued casts and armed watches.
Reset()
cooldownState[3004] = nil
local cfgD = MakeCfg(3004, "Wiped")
local mapsD = { [3004] = "spell:3004" }
local cfgMapD = { ["spell:3004"] = cfgD }
Runtime:QueueGameCooldown(3004, mapsD, cfgMapD)
Runtime:WipeCooldowns(false)
cooldownState[3004] = { isActive = true, isEnabled = true, isOnGCD = false }
Assert(not Runtime:EvaluateGameCooldowns(now + 1), "a wiped queued cast must not arm")
cooldownState[3004] = { isActive = false, isEnabled = true, isOnGCD = false }
Equal(Runtime:EvaluateGameCooldowns(now + 2), false, "a wiped watch must not announce")
Equal(#played, 4, "wiping must clear queued casts and armed watches")

-- 10) "cooldown" mode announces at the real cooldown start (after the cast
--     GCD clears), never at the ready edge, and stays silent for GCD-only casts.
local playedBase = #played
now = now + 10
local cfgOn = MakeCfg(3006, "OnCooldown", "cooldown")
local mapsOn = { [3006] = "spell:3006" }
local cfgMapOn = { ["spell:3006"] = cfgOn }
cooldownState[3006] = { isActive = true, isEnabled = true, isOnGCD = true }
Runtime:QueueGameCooldown(3006, mapsOn, cfgMapOn)
Runtime:EvaluateGameCooldowns(now)
Equal(#played, playedBase, "cooldown mode must wait for the non-GCD cooldown")

cooldownState[3006] = { isActive = true, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
Equal(#played, playedBase + 1, "cooldown mode announces when the real cooldown starts")
Equal(played[playedBase + 1].cd and played[playedBase + 1].cd.spellName, "OnCooldown",
    "the cooldown-start announcement carries the saved spell name")

now = now + 2.0
cooldownState[3006] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
Equal(#played, playedBase + 1, "cooldown mode must not announce again at the ready edge")

now = now + 10
Runtime:QueueGameCooldown(3006, mapsOn, cfgMapOn)
cooldownState[3006] = { isActive = true, isEnabled = true, isOnGCD = true }
Runtime:EvaluateGameCooldowns(now)
cooldownState[3006] = { isActive = false, isEnabled = true, isOnGCD = false }
Runtime:EvaluateGameCooldowns(now)
now = now + 4.0
Runtime:EvaluateGameCooldowns(now)
Equal(#played, playedBase + 1, "cooldown mode must stay silent for a GCD-only cast")

-- 11) A "cooldown" entry already cooling at login/reload must not be primed
--     into a retroactive announcement.
now = now + 10
local cfgPrime = MakeCfg(3007, "PrimedCooldown", "cooldown")
local mapsPrime = { [3007] = "spell:3007" }
local cfgMapPrime = { ["spell:3007"] = cfgPrime }
cooldownState[3007] = { isActive = true, isEnabled = true, isOnGCD = false }
Runtime:PrimeGameCooldowns(cfgMapPrime)
Equal(#played, playedBase + 1, "priming a mid-cooldown 'cooldown' entry must not announce")
Equal(Runtime:EvaluateGameCooldowns(now), false, "priming must not leave a watch behind")

print("PASS: game cooldown state watch")
