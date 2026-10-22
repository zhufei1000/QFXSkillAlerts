local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)), 2)
    end
end

function wipe(values)
    for key in pairs(values) do values[key] = nil end
    return values
end

local frame = { events = {} }
function CreateFrame() return frame end
function frame:SetScript(name, callback) self[name] = callback end
function frame:RegisterEvent(event) self.events[event] = true end
function frame:SendEvent(event)
    if self.events[event] and self.OnEvent then self.OnEvent(self, event) end
end

local now = 100
function GetTime() return now end
function UnitAffectingCombat() return false end
local timers = {}
C_Timer = {
    NewTimer = function(delay, callback)
        local timer = { at = now + delay, callback = callback }
        function timer:Cancel() self.cancelled = true end
        timers[#timers + 1] = timer
        return timer
    end,
}
local function Advance(seconds)
    now = now + seconds
    local due = timers
    timers = {}
    for _, timer in ipairs(due) do
        if not timer.cancelled then
            if timer.at <= now then timer.callback() else timers[#timers + 1] = timer end
        end
    end
end

local states, charges = {}, {}
local reads = 0
C_Spell = {
    GetSpellCooldown = function(id) reads = reads + 1; return states[id] end,
    GetSpellCharges = function(id) reads = reads + 1; return charges[id] end,
}
QFXSkillAlertsNS = { Core = {}, Constants = {}, Utils = {} }
dofile("QFXSkillAlerts/Core/Runtime.lua")
local Runtime = QFXSkillAlertsNS.Core.Runtime
local played = 0
Runtime:Configure({ playReady = function() played = played + 1 end })

local function State(active, gcd)
    return { isActive = active, isEnabled = true, isOnGCD = gcd == true }
end
local cfg = { gameStateCD = true, cdMode = "ready", spellId = 3001,
    triggerSpellID = 3001, voiceEnabled = true }
local cfgMap = { ["spell:3001"] = cfg }
local spellMap = { [3001] = "spell:3001" }
local function Tick()
    if frame.OnUpdate then frame.OnUpdate(frame, 0.2) end
end
local function Ready()
    states[3001] = State(false)
    Tick()
    Tick()
end

-- An armed cooldown must not interpret cleared loading-screen state as ready.
states[3001] = State(true)
Runtime:PrimeGameCooldowns(cfgMap)
Advance(5)
frame:SendEvent("LOADING_SCREEN_ENABLED")
frame:SendEvent("PLAYER_LEAVING_WORLD")
Ready()
Equal(played, 0, "loading must not turn an old watch into a ready announcement")
local beforeReads = reads
Runtime:PrimeGameCooldowns(cfgMap)
Runtime:QueueGameCooldown(3001, spellMap, cfgMap)
Runtime:EvaluateGameCooldowns(now)
Equal(reads, beforeReads, "loading must suspend cooldown reads, primes and casts")
Equal(frame.OnUpdate, nil, "loading with no fixed timers must stop polling")

-- ENTERING_WORLD can arrive before the loading screen disappears.
frame:SendEvent("PLAYER_ENTERING_WORLD")
Advance(5)
Runtime:PrimeGameCooldowns(cfgMap)
Tick()
Equal(reads, beforeReads, "world entry alone must not resume behind a loading screen")
frame:SendEvent("LOADING_SCREEN_DISABLED")
Runtime:PrimeGameCooldowns(cfgMap)
Advance(0.5)
Equal(reads, beforeReads, "world-entry data must settle before watches are rebuilt")
Advance(0.6)
Ready()
Equal(played, 0, "already-ready skills must stay silent after loading")
Equal(frame.OnUpdate, nil, "idle world entry must not leave a polling loop")

-- A genuinely running cooldown is re-armed and still announces normally.
states[3001] = State(true)
Runtime:PrimeGameCooldowns(cfgMap)
frame:SendEvent("PLAYER_LEAVING_WORLD")
frame:SendEvent("LOADING_SCREEN_ENABLED")
Ready()
frame:SendEvent("LOADING_SCREEN_DISABLED")
Advance(2)
states[3001] = State(true)
frame:SendEvent("PLAYER_ENTERING_WORLD")
Runtime:PrimeGameCooldowns(cfgMap)
Advance(1.1)
Advance(3)
Ready()
Equal(played, 1, "a cooldown still running after loading must announce on its real end")

-- A second transfer cancels the first transfer's pending recovery timer.
frame:SendEvent("PLAYER_LEAVING_WORLD")
frame:SendEvent("PLAYER_ENTERING_WORLD")
Advance(0.5)
frame:SendEvent("PLAYER_LEAVING_WORLD")
beforeReads = reads
Advance(2)
Runtime:PrimeGameCooldowns(cfgMap)
Equal(reads, beforeReads, "an old recovery timer must not resume a later transfer")
frame:SendEvent("PLAYER_ENTERING_WORLD")
Advance(1.1)
Ready()
Equal(played, 1, "consecutive transfers must stay silent")

-- Refreshing a real watch must preserve its evidence of a real cooldown.
states[3001] = State(true)
Runtime:PrimeGameCooldowns(cfgMap)
Advance(3)
Runtime:PrimeGameCooldowns(cfgMap)
Ready()
Equal(played, 2, "a config refresh must preserve a running watch's ready edge")

-- A GCD at profile refresh is not enough to arm a new ready watch.
Runtime:WipeCooldowns(false)
states[3001] = State(true, true)
Runtime:PrimeGameCooldowns(cfgMap)
Equal(frame.OnUpdate, nil, "a GCD-only prime must not start a ready watch")
Advance(3)
Ready()
Equal(played, 2, "a GCD-only prime must stay silent")

-- Loading resets charge watches and cooldown-start pending casts as well.
Runtime:WipeCooldowns(false)
local chargeCfg = { gameStateCD = true, cdMode = "charge", spellId = 3002, voiceEnabled = true }
local startCfg = { gameStateCD = true, cdMode = "cooldown", spellId = 3003, voiceEnabled = true }
local both = { ["spell:3002"] = chargeCfg, ["spell:3003"] = startCfg }
charges[3002] = { maxCharges = 2, isActive = true }
Runtime:PrimeGameCooldowns(both)
Runtime:QueueGameCooldown(3003, { [3003] = "spell:3003" }, both)
Advance(3)
frame:SendEvent("LOADING_SCREEN_ENABLED")
charges[3002] = { maxCharges = 2, isActive = false }
states[3003] = State(true)
Tick()
Equal(played, 2, "loading must silence charge watches and queued cooldown-start alerts")
frame:SendEvent("LOADING_SCREEN_DISABLED")
Advance(1.1)
Tick()
Equal(played, 2, "recovery must not replay a cooldown-start cast from the previous map")

-- Config edits during loading replace the config used by recovery.
frame:SendEvent("LOADING_SCREEN_ENABLED")
Runtime:PrimeGameCooldowns({})
frame:SendEvent("LOADING_SCREEN_DISABLED")
Advance(1.1)
charges[3002] = { maxCharges = 2, isActive = true }
Advance(3)
Tick()
charges[3002] = { maxCharges = 2, isActive = false }
Tick()
Equal(played, 2, "removed configurations must not be resurrected after loading")

-- Fixed timers retain their countdown across map changes.
Runtime:WipeCooldowns(false)
local fixed = { spellId = 3010, baseCD = 10, chargeInput = 1, voiceEnabled = true }
Runtime:StartCooldown(3010, { [3010] = "spell:3010" }, { ["spell:3010"] = fixed })
frame:SendEvent("PLAYER_LEAVING_WORLD")
Equal(Runtime:GetCooldownTable()["spell:3010"] ~= nil, true, "map changes must preserve fixed timers")
frame:SendEvent("PLAYER_ENTERING_WORLD")
Advance(11)
Tick()
Equal(played, 3, "fixed cooldown completion must still announce")

print("PASS: game cooldown world transitions")
