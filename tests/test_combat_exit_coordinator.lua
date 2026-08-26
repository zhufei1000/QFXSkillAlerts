local function Assert(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

function wipe(values)
    for key in pairs(values or {}) do values[key] = nil end
    return values
end

local inCombat = false
function InCombatLockdown() return inCombat end

local timers = {}
C_Timer = {
    NewTimer = function(_, callback)
        local timer = { callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

QFXSkillAlertsNS = { Core = {} }
dofile("QFXSkillAlerts/Core/Startup.lua")
local Startup = QFXSkillAlertsNS.Core.Startup

local counts = {}
local inventoryEvents = {}
local resolveResult = false
local function ResetCounters()
    counts = { resolve = 0, prepare = 0, profile = 0, invalidate = 0, clear = 0 }
    inventoryEvents = {}
end

Startup:Configure({
    resolvePendingItems = function()
        counts.resolve = counts.resolve + 1
        return resolveResult
    end,
    handleItemInventoryChanged = function(event)
        inventoryEvents[#inventoryEvents + 1] = event
    end,
    invalidateTalentCache = function() counts.invalidate = counts.invalidate + 1 end,
    prepareProfileRefresh = function() counts.prepare = counts.prepare + 1 end,
    onProfileChanged = function() counts.profile = counts.profile + 1 end,
    clearDelayedCastSuccessTimers = function() counts.clear = counts.clear + 1 end,
})

-- A combat-deferred profile rebuild covers pending item and bag work.
ResetCounters()
inCombat = true
Startup:OnProfileRefresh("SPELLS_CHANGED")
inCombat = false
Startup:OnPlayerRegenEnabled()
Equal(counts.resolve, 0, "deferred profile refresh must not resolve items separately")
Equal(inventoryEvents[1], "PLAYER_REGEN_ENABLED_COVERED", "profile rebuild must consume bag flag")
Equal(#timers, 1, "profile rebuild should be scheduled once")
timers[1].callback()
Equal(counts.prepare, 1, "scheduled profile preparation should run once")
Equal(counts.profile, 1, "scheduled profile rebuild should run once")
Equal(counts.clear, 1, "cast-success timers should be cleared once")

-- If item resolution already rebuilt runtime data, do not rebuild for bags.
ResetCounters()
resolveResult = true
Startup:OnPlayerRegenEnabled()
Equal(counts.resolve, 1, "pending items should be resolved once")
Equal(inventoryEvents[1], "PLAYER_REGEN_ENABLED_COVERED", "resolved items must consume bag flag")

-- With no other work, a genuine bag-pending flag keeps its normal path.
ResetCounters()
resolveResult = false
Startup:OnPlayerRegenEnabled()
Equal(counts.resolve, 1, "empty item queue should be checked once")
Equal(inventoryEvents[1], "PLAYER_REGEN_ENABLED", "bag-only work should retain its normal path")

print("Combat-exit coordinator regression tests passed")
