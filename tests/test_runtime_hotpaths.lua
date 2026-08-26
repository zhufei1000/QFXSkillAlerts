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
        voiceEnabled = true,
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

-- A cast event must use the direct spellID mapping and touch only that saved
-- runtime entry. Unrelated saved entries are not scanned or activated.
Runtime:WipeCooldowns(false)
runtimeNow = 250
local unrelatedReads = 0
local targetKey = "spell:1101"
local directConfig = setmetatable({
    [targetKey] = {
        spellId = 1101,
        objectID = 1101,
        objectType = "spell",
        spellName = "Direct Target",
        baseCD = 10,
        chargeInput = 1,
        voiceEnabled = true,
        imageEnabled = false,
        textEnabled = false,
    },
}, {
    __index = function(_, key)
        if key ~= targetKey then
            unrelatedReads = unrelatedReads + 1
        end
    end,
})
Runtime:StartCooldown(1101, { [1101] = targetKey, [1102] = "spell:1102" }, directConfig)
Equal(unrelatedReads, 0, "a cast must not read unrelated saved cooldown configs")
Assert(Runtime:GetCooldownTable()[targetKey], "the matching cooldown should be activated")
Equal(Runtime:GetCooldownTable()["spell:1102"], nil, "an unrelated cooldown must remain inactive")

-- Completely disabled records must not create background update work.
Runtime:WipeCooldowns(false)
runtimeFrame.OnUpdate = nil
Runtime:StartCooldown(1201, { [1201] = "spell:1201" }, {
    ["spell:1201"] = {
        spellId = 1201,
        objectID = 1201,
        objectType = "spell",
        spellName = "Disabled",
        baseCD = 10,
        chargeInput = 1,
        voiceEnabled = false,
        imageEnabled = false,
        textEnabled = false,
    },
})
Equal(next(Runtime:GetCooldownTable()), nil, "disabled cooldown must not allocate an active timer")
Equal(runtimeFrame.OnUpdate, nil, "disabled cooldown must not install OnUpdate")

-- Countdown text stays on the shared cooldown loop, updates only when the
-- displayed whole second changes, and does not execute the ordinary text
-- condition notification at the same time.
Runtime:WipeCooldowns(false)
runtimeNow = 260
local countdownUpdates = {}
local countdownHides = 0
local countdownReadyPlays = 0
Runtime:Configure({
    getUpdateInterval = function() return 0.16 end,
    playReady = function() countdownReadyPlays = countdownReadyPlays + 1 end,
    updateCountdown = function(_, remaining)
        countdownUpdates[#countdownUpdates + 1] = math.ceil(remaining - 0.001)
        return true
    end,
    hideCountdown = function()
        countdownHides = countdownHides + 1
        return true
    end,
})
local countdownKey = "spell:1251"
Runtime:StartCooldown(1251, { [1251] = countdownKey }, {
    [countdownKey] = {
        spellId = 1251, objectID = 1251, objectType = "spell", spellName = "Countdown",
        baseCD = 65, chargeInput = 1, voiceEnabled = false, imageEnabled = false,
        textEnabled = true, textCooldownCountdown = true,
        textDurationEnabled = true, textConditionOp = ">", textConditionTime = 0,
    },
})
Equal(countdownUpdates[1], 65, "countdown must appear immediately from the configured fixed CD")
Equal(countdownReadyPlays, 0, "countdown mode must bypass the ordinary text condition notification")
Runtime:ProcessCooldownRecord(countdownKey, Runtime:GetCooldownTable()[countdownKey], 260.2, true)
Equal(#countdownUpdates, 1, "countdown must not rebuild text within the same displayed second")
Runtime:ProcessCooldownRecord(countdownKey, Runtime:GetCooldownTable()[countdownKey], 261.1, true)
Equal(countdownUpdates[2], 64, "countdown must update when the displayed second changes")
Runtime:ProcessCooldownRecord(countdownKey, Runtime:GetCooldownTable()[countdownKey], 325, true)
Equal(countdownHides, 2, "countdown is cleared once at start and once when the cooldown completes")
Equal(Runtime:GetCooldownTable()[countdownKey], nil, "completed countdown must leave the shared hot loop")

-- Once every finite channel has fired, the record has no future work and can
-- leave the hot loop before the underlying fixed cooldown reaches zero.
Runtime:WipeCooldowns(false)
runtimeNow = 275
Runtime:StartCooldown(1301, { [1301] = "spell:1301" }, {
    ["spell:1301"] = {
        spellId = 1301,
        objectID = 1301,
        objectType = "spell",
        spellName = "Early Complete",
        baseCD = 10,
        chargeInput = 1,
        voiceEnabled = true,
        voiceConditionOp = ">",
        voiceConditionTime = 0,
        imageEnabled = false,
        textEnabled = false,
    },
})
Equal(Runtime:GetCooldownTable()["spell:1301"], nil, "completed finite alerts should leave the hot loop early")

-- Disabling visual channels during a live cooldown must clear an already
-- visible untimed alert before the disabled-channel hot-path guard returns.
Runtime:WipeCooldowns(false)
runtimeNow = 300
local visualPlays = 0
local visualHides = 0
Runtime:Configure({
    getUpdateInterval = function() return 0.16 end,
    playReady = function(_, channel)
        if channel == "image" then
            visualPlays = visualPlays + 1
        end
        return true
    end,
    hideVisual = function()
        visualHides = visualHides + 1
    end,
})
local visualKey = "spell:2001"
local visualConfig = {
    spellId = 2001,
    objectID = 2001,
    objectType = "spell",
    spellName = "Visual Test",
    baseCD = 10,
    chargeInput = 1,
    voiceEnabled = true,
    imageEnabled = true,
    imageDurationEnabled = false,
    imageConditionOp = "<=",
    imageConditionTime = 20,
    textEnabled = false,
}
Runtime:StartCooldown(2001, { [2001] = visualKey }, { [visualKey] = visualConfig })
Equal(visualPlays, 1, "untimed image should become active")
local hidesAfterStart = visualHides

local disabledVisualConfig = {
    spellId = 2001,
    objectID = 2001,
    objectType = "spell",
    spellName = "Visual Test",
    baseCD = 10,
    chargeInput = 1,
    voiceEnabled = true,
    imageEnabled = false,
    imageDurationEnabled = false,
    imageConditionOp = "<=",
    imageConditionTime = 20,
    textEnabled = false,
}
Runtime:RefreshRuntimeCooldowns({ [visualKey] = disabledVisualConfig })
local disabledVisual = Runtime:GetCooldownTable()[visualKey]
Equal(visualHides, hidesAfterStart + 1, "disabling all visual channels must hide the active visual")
Assert(disabledVisual and disabledVisual.visualActive == false, "disabled visual must not remain active")
Equal(disabledVisual and disabledVisual.visualChannel, nil, "disabled visual channel must be cleared")

-- The finite-channel completion guard must not skip cleanup when another live
-- channel is disabled by a config refresh.
disabledVisual.visualActive = true
disabledVisual.visualChannel = "image"
disabledVisual.imageNotified = false
disabledVisual.textNotified = true
local mixedVisualConfig = {
    spellId = 2001,
    objectID = 2001,
    objectType = "spell",
    spellName = "Visual Test",
    baseCD = 10,
    chargeInput = 1,
    voiceEnabled = true,
    imageEnabled = false,
    imageDurationEnabled = false,
    imageConditionOp = "<=",
    imageConditionTime = 20,
    textEnabled = true,
    textDurationEnabled = true,
    textConditionOp = "<=",
    textConditionTime = 20,
}
local hidesBeforeMixedRefresh = visualHides
Runtime:RefreshRuntimeCooldowns({ [visualKey] = mixedVisualConfig })
local mixedVisual = Runtime:GetCooldownTable()[visualKey]
Equal(visualHides, hidesBeforeMixedRefresh + 1, "completed-channel guard must first hide a disabled active visual")
Assert(mixedVisual and mixedVisual.visualActive == false, "mixed refresh must clear the disabled active visual")

-- The single-charge fast path must restore the charge and clear its timer at
-- the same boundary as the former general-purpose loop.
Runtime:WipeCooldowns(false)
runtimeNow = 400
local chargeKey = "spell:3001"
Runtime:StartCooldown(3001, { [3001] = chargeKey }, {
    [chargeKey] = {
        spellId = 3001,
        objectID = 3001,
        objectType = "spell",
        spellName = "Charge Test",
        baseCD = 10,
        chargeInput = 1,
        voiceEnabled = true,
        imageEnabled = false,
        textEnabled = false,
    },
})
local chargeCooldown = Runtime:GetCooldownTable()[chargeKey]
Equal(chargeCooldown and chargeCooldown.currentCharge, 0, "single charge should be spent at cooldown start")
runtimeNow = 410
Runtime:SyncCooldownState(chargeKey, runtimeNow)
Equal(chargeCooldown.currentCharge, 1, "single-charge fast path should restore the charge at expiry")
Equal(chargeCooldown.nextChargeAt, nil, "single-charge fast path should clear the completed timer")

-- Inventory events should only trigger rebuilds when an active entry actually
-- uses the corresponding dynamic item-load rule.
QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        ALL_CLASSES_ID = 0,
        ALL_SPECS_ID = 0,
        ALL_RACES_ID = 0,
        OBJECT_TYPE_ITEM = "item",
        OBJECT_TYPE_SPELL = "spell",
        ITEM_LOAD_EQUIPPED = "equipped",
        ITEM_LOAD_BAGS = "bags",
        MODE_SOUND = "sound",
    },
    Utils = {},
}
function UnitRace() return nil, nil, 1 end
local scopedEntries = {
    [1] = {
        entryType = "cooldown",
        spellId = 4001,
        objectType = "item",
        itemLoadMode = "bags",
        baseCD = 10,
    },
}
local function Ordered(map)
    local result = {}
    for index in pairs(map or {}) do result[#result + 1] = index end
    table.sort(result)
    return result
end
dofile("QFXSkillAlerts/Core/RuntimeConfigBuilder.lua")
local ConfigBuilder = QFXSkillAlertsNS.Core.RuntimeConfigBuilder
ConfigBuilder:Configure({
    getCurrentClassSpec = function() return 1, 2 end,
    getStoredEntryMap = function(classID, specID)
        if classID == 1 and specID == 2 then return scopedEntries end
        return {}
    end,
    getOrderedEntryIndices = Ordered,
    getEntry = function(map, index) return map[index] end,
    resolveObjectType = function(_, objectType) return objectType end,
    isItemLoadRequirementMet = function() return false end,
})
ConfigBuilder:Rebuild({}, {})
local needsEquipped, needsBags = ConfigBuilder:GetItemLoadEventNeeds()
Equal(needsEquipped, false, "bag-only cooldown config must not request equipment refreshes")
Equal(needsBags, true, "bag-loaded cooldown config must request bag refreshes")

scopedEntries[1].itemLoadMode = "none"
ConfigBuilder:Rebuild({}, {})
needsEquipped, needsBags = ConfigBuilder:GetItemLoadEventNeeds()
Equal(needsEquipped, false, "static cooldown config must not request equipment refreshes")
Equal(needsBags, false, "static cooldown config must not request bag refreshes")

print("Runtime hot-path regression tests passed")
