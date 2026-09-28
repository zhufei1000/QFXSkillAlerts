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

function wipe(values)
    for key in pairs(values or {}) do
        values[key] = nil
    end
    return values
end

QFXSkillAlertsNS = { Core = {} }
dofile("QFXSkillAlerts/Core/GroupDeathMonitor.lua")

local Monitor = QFXSkillAlertsNS.Core.GroupDeathMonitor
local grouped = true
local raid = true
local groupCount = 3
local units = {
    raid1 = { guid = "Player-1", player = true, connected = true, dead = false, feign = false },
    raid2 = { guid = "Player-2", connected = true, dead = false, feign = false },
    raid3 = { guid = "Player-3", connected = true, dead = false, feign = false },
}
local deaths = {}
local watcher
local tick
local tickerCancelled = false
local tickerCount = 0

Monitor:Configure({
    onGroupMemberDeath = function(unit) deaths[#deaths + 1] = unit end,
    createFrame = function()
        watcher = { registered = {} }
        function watcher:SetScript(name, callback) self[name] = callback end
        function watcher:RegisterEvent(event) self.registered[event] = true end
        function watcher:UnregisterAllEvents() wipe(self.registered) end
        return watcher
    end,
    newTicker = function(interval, callback)
        Equal(interval, 0.35, "group deaths should use the 0.35s polling interval")
        tickerCount = tickerCount + 1
        tick = callback
        return { Cancel = function() tickerCancelled = true end }
    end,
    isInGroup = function() return grouped end,
    isInRaid = function() return raid end,
    getNumGroupMembers = function() return groupCount end,
    unitExists = function(unit) return units[unit] ~= nil end,
    unitIsUnit = function(unit, other) return other == "player" and units[unit] and units[unit].player == true end,
    unitGUID = function(unit) return units[unit] and units[unit].guid end,
    unitIsConnected = function(unit) return units[unit] and units[unit].connected == true end,
    unitIsDeadOrGhost = function(unit) return units[unit] and units[unit].dead == true end,
    unitIsFeignDeath = function(unit) return units[unit] and units[unit].feign == true end,
})

Assert(Monitor:SetEnabled(true), "configured group-death monitoring should start while grouped")
Equal(tickerCount, 1, "group-death monitoring should own one ticker while grouped")
Assert(watcher.registered.GROUP_ROSTER_UPDATE and watcher.registered.PLAYER_ENTERING_WORLD,
    "group-death monitoring should follow roster and world transitions")
Equal(#deaths, 0, "initial state should be primed without announcing existing members")

units.raid2.dead = true
Assert(tick(), "an alive-to-dead raid transition should be detected")
Equal(deaths[1], "raid2", "the dead raid member should be reported")
Assert(not tick(), "the same corpse should not be announced twice")

units.raid2.dead = false
tick()
units.raid2.dead = true
Assert(tick(), "a member should be reportable again after returning alive")
Equal(#deaths, 2, "a second genuine death should create one more notification")

units.raid3.feign = true
units.raid3.dead = true
Assert(not tick(), "feign death must not count as a group-member death")
Equal(#deaths, 2, "feign death should not notify")

raid = false
units = { party1 = { guid = "Player-4", connected = true, dead = false, feign = false } }
tick()
units.party1.dead = true
Assert(tick(), "party members should use the same alive-to-dead transition")
Equal(deaths[3], "party1", "the dead party member should be reported")

Monitor:SetEnabled(false)
Assert(tickerCancelled, "disabling the trigger should cancel its ticker")
Assert(next(watcher.registered) == nil, "disabling should unregister roster events")

grouped = false
tickerCancelled = false
Assert(not Monitor:SetEnabled(true), "the monitor should stay idle while solo")
Equal(tickerCount, 1, "enabling while solo must not allocate another ticker")
Monitor:SetEnabled(false)

print("group death monitor tests passed")
