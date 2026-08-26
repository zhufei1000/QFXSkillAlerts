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

function InCombatLockdown() return false end

local timers = {}
C_Timer = {
    NewTimer = function(delay, callback)
        local timer = { delay = delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}

QFXSkillAlertsNS = { Core = {} }
dofile("QFXSkillAlerts/Core/Startup.lua")
dofile("QFXSkillAlerts/Core/EventHub.lua")

local Startup = QFXSkillAlertsNS.Core.Startup
local EventHub = QFXSkillAlertsNS.Core.EventHub
local inventoryEvents = {}
local alchemyOpen = false
local relevantBagStateChanged = false

Startup:Configure({
    handleItemInventoryChanged = function(event)
        inventoryEvents[#inventoryEvents + 1] = event
        return true
    end,
    isAlchemyTradeSkill = function()
        return alchemyOpen
    end,
    hasRelevantBagLoadStateChanged = function()
        local changed = relevantBagStateChanged
        relevantBagStateChanged = false
        return changed
    end,
})

local registered = {}
local frame = {}
function frame:RegisterEvent(event) registered[event] = true end
function frame:RegisterUnitEvent(event) registered[event] = true end
function frame:SetScript(_, callback) self.OnEvent = callback end

Assert(EventHub:Initialize(frame, Startup:GetEventHandlers()), "event hub should initialize")
Assert(registered.BAG_UPDATE_DELAYED, "bag changes should be registered as a refresh filter")
Assert(registered.MAIL_SHOW, "mail show should begin a bag-change correlation window")
Assert(registered.MAIL_CLOSED, "mail close should be registered")
Assert(registered.TRADE_SHOW, "trade show should begin a bag-change correlation window")
Assert(registered.TRADE_CLOSED, "trade close should be registered")
Assert(registered.TRADE_SKILL_SHOW, "profession show should be registered")
Assert(registered.TRADE_SKILL_CLOSE, "profession close should be registered")

frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
Equal(#inventoryEvents, 0, "a generic bag update must not refresh on its own")

frame.OnEvent(frame, "MAIL_SHOW")
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
frame.OnEvent(frame, "MAIL_CLOSED")
timers[#timers].callback()
Equal(#inventoryEvents, 0, "an unrelated bag change while mail is open should not refresh")

frame.OnEvent(frame, "MAIL_SHOW")
relevantBagStateChanged = true
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
frame.OnEvent(frame, "MAIL_CLOSED")
Equal(inventoryEvents[1], "MAIL_CLOSED", "changed bags should refresh when mail closes")

frame.OnEvent(frame, "TRADE_SHOW")
frame.OnEvent(frame, "TRADE_CLOSED")
local lateTradeTimer = timers[#timers]
relevantBagStateChanged = true
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
lateTradeTimer.callback()
Equal(inventoryEvents[2], "TRADE_CLOSED", "a bag update just after trade close should still refresh")

alchemyOpen = false
frame.OnEvent(frame, "TRADE_SKILL_SHOW")
frame.OnEvent(frame, "TRADE_SKILL_CLOSE")
Equal(#inventoryEvents, 2, "closing a non-alchemy profession should not refresh bags")

alchemyOpen = true
frame.OnEvent(frame, "TRADE_SKILL_SHOW")
alchemyOpen = false
frame.OnEvent(frame, "TRADE_SKILL_CLOSE")
timers[#timers].callback()
Equal(#inventoryEvents, 2, "closing Alchemy without a bag change should not refresh")

alchemyOpen = true
frame.OnEvent(frame, "TRADE_SKILL_SHOW")
relevantBagStateChanged = true
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
alchemyOpen = false
frame.OnEvent(frame, "TRADE_SKILL_CLOSE")
Equal(inventoryEvents[3], "ALCHEMY_TRADE_SKILL_CLOSED", "changed bags should refresh when Alchemy closes")

alchemyOpen = false
frame.OnEvent(frame, "TRADE_SKILL_SHOW")
relevantBagStateChanged = true
frame.OnEvent(frame, "BAG_UPDATE_DELAYED")
alchemyOpen = true
frame.OnEvent(frame, "TRADE_SKILL_CLOSE")
Equal(inventoryEvents[4], "ALCHEMY_TRADE_SKILL_CLOSED", "close-time profession data should cover a late Alchemy data source")

Startup:OnPlayerLogin()
local delayedLoginTimer
for _, timer in ipairs(timers) do
    if timer.delay == 1.0 then
        delayedLoginTimer = timer
        break
    end
end
Assert(delayedLoginTimer, "login should schedule a delayed inventory refresh")
delayedLoginTimer.callback()
Equal(inventoryEvents[5], "PLAYER_LOGIN_DELAYED", "the delayed login timer should request a bag refresh")

print("Inventory refresh event regression tests passed")
