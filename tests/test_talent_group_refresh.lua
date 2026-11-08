local function Assert(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ",
            tostring(expected), tostring(actual)), 2)
    end
end

function wipe(values)
    for key in pairs(values or {}) do values[key] = nil end
    return values
end

local now = 100
function GetTime() return now end
local inCombat = false
function InCombatLockdown() return inCombat end
function IsPlayerSpell() return false end

local timers = {}
C_Timer = {
    NewTimer = function(delay, callback)
        local timer = { delay = delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

QFXSkillAlertsNS = { Core = {}, Constants = {}, Utils = {} }
dofile("QFXSkillAlerts/Core/Startup.lua")
dofile("QFXSkillAlerts/Core/EventHub.lua")
local Startup = QFXSkillAlertsNS.Core.Startup
local EventHub = QFXSkillAlertsNS.Core.EventHub

local invalidated, refreshes = 0, {}
Startup:Configure({
    invalidateTalentCache = function() invalidated = invalidated + 1 end,
    prepareProfileRefresh = function() end,
    onProfileChanged = function(reset) refreshes[#refreshes + 1] = reset end,
})

local registered = {}
local frame = {}
function frame:RegisterEvent(event) registered[event] = true end
function frame:RegisterUnitEvent(event) registered[event] = true end
function frame:SetScript(_, callback) self.OnEvent = callback end
Assert(EventHub:Initialize(frame, Startup:GetEventHandlers()), "event hub should initialize")

-- Forever switches dual talent groups with SetActiveSpecGroup, which reports
-- ACTIVE_TALENT_GROUP_CHANGED instead of PLAYER_SPECIALIZATION_CHANGED.
Assert(registered.ACTIVE_TALENT_GROUP_CHANGED, "talent group switches must be registered")
frame.OnEvent(frame, "ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
Equal(invalidated, 1, "a group switch must invalidate the talent cache")
Equal(#timers, 1, "a group switch must schedule a profile refresh")
timers[1].callback()
Equal(#refreshes, 1, "the scheduled refresh must run")
Equal(refreshes[1], true, "a group switch changes scope and must reset cooldowns")

-- In combat the refresh is deferred, and the reset must survive the deferral.
inCombat = true
frame.OnEvent(frame, "ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
Equal(#refreshes, 1, "combat must not refresh immediately")
inCombat = false
frame.OnEvent(frame, "PLAYER_REGEN_ENABLED")
Equal(#timers, 2, "combat exit must schedule the deferred refresh")
timers[2].callback()
Equal(#refreshes, 2, "combat exit must apply the deferred refresh")
Equal(refreshes[2], true, "the deferred group-switch refresh must still reset")

-- A trait config that is not loaded yet must stay retryable: caching the failure
-- would pin every talent condition to "not selected" for the whole session.
local configID = nil
local configReads = 0
C_ClassTalents = { GetActiveConfigID = function()
    configReads = configReads + 1
    return configID
end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 10 } } end,
    GetTreeNodes = function() return { 20 } end,
    GetNodeInfo = function() return { activeRank = 1, activeEntry = { entryID = 30 } } end,
    GetEntryInfo = function() return { definitionID = 40 } end,
    GetDefinitionInfo = function() return { spellID = 12345 } end,
}
dofile("QFXSkillAlerts/Core/Resolver.lua")
local Resolver = QFXSkillAlertsNS.Core.Resolver

Assert(not Resolver:IsTalentSelectedCached(12345), "unready trait data must not report a selected talent")
Equal(Resolver.talentCacheValid, false, "a failed build must not settle the cache")
local readsAfterFirst = configReads
Resolver:IsTalentSelectedCached(12345)
Resolver:IsTalentSelectedCached(54321)
Equal(configReads, readsAfterFirst, "one refresh must not query the config per entry")

now = now + 2
Assert(not Resolver:IsTalentSelectedCached(12345), "the retry still sees unready data")
Assert(configReads > readsAfterFirst, "the retry boundary must allow a later attempt")

configID = 101
Resolver:InvalidateTalentCache()
Assert(Resolver:IsTalentSelectedCached(12345), "once trait data loads the real talent must be selected")
Assert(not Resolver:IsTalentSelectedCached(54321), "an unselected talent must stay unselected")
Equal(Resolver.talentCacheValid, true, "a readable config must settle the cache")
local settledReads = configReads
Resolver:IsTalentSelectedCached(12345)
Equal(configReads, settledReads, "a settled cache must not re-query")

print("PASS: talent group event routing, combat-deferred reset and retryable unready trait cache")