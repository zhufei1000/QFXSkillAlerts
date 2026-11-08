local function equal(actual, expected, message)
    assert(actual == expected, (message or "values differ")..": "..tostring(actual).." ~= "..tostring(expected))
end
function wipe(t) for key in pairs(t) do t[key] = nil end return t end
local frame = {events = {}}
function CreateFrame() return frame end
function frame:RegisterEvent(event) self.events[event] = true end
function frame:SetScript(event, callback) self[event] = callback end
local now, inCooldownEvent, played, reads = 100, false, 0, 0
function GetTime() return now end
function UnitAffectingCombat() return true end
local active, gcd = true, false
C_Spell = {GetSpellCooldown = function()
    reads = reads + 1
    return setmetatable({isActive = active, isEnabled = true}, {__index = function(_, key)
        if key == "isOnGCD" then
            assert(inCooldownEvent, "isOnGCD must never be read by polling/priming")
            return gcd
        end
    end})
end}
QFXSkillAlertsNS = {Core = {}, Constants = {}, Utils = {}}
dofile("QFXSkillAlerts/Core/Runtime.lua")
local runtime = QFXSkillAlertsNS.Core.Runtime
runtime:Configure({playReady = function() played = played + 1 end})
local cfg = {gameStateCD = true, cdMode = "ready", spellId = 2825, voiceEnabled = true}
local configs = {["spell:2825"] = cfg}
local function event(name)
    assert(frame.events[name])
    inCooldownEvent = name == "SPELL_UPDATE_COOLDOWN"
    frame.OnEvent(frame, name, setmetatable({}, {__index = function() error("Ignore event payload") end}))
    inCooldownEvent = false
end
runtime:PrimeGameCooldowns(configs)
equal(frame.OnUpdate, nil, "unknown GCD state must wait for an event")
event("SPELL_UPDATE_COOLDOWN")
now = 102
-- A stale provider flag outside its documented event must not announce.
gcd = true
runtime:EvaluateGameCooldowns(now)
runtime:EvaluateGameCooldowns(now + .2)
equal(played, 0, "polling ignores a stale GCD field")
event("SPELL_UPDATE_COOLDOWN")
runtime:EvaluateGameCooldowns(now + .2)
equal(played, 1, "a trusted GCD-only state confirms the real ready edge")

runtime:WipeCooldowns(false)
gcd = false
local rebuilds = 0
QFXSkillAlertsNS.Utils.SyncLinkedVisualDurations = function() rebuilds = rebuilds + 1 end
runtime:PrimeGameCooldowns(configs)
event("SPELL_UPDATE_COOLDOWN")
equal(rebuilds, 1, "arming a watch builds its alert fields once")
now = now + 3
gcd = true
event("SPELL_UPDATE_COOLDOWN")
equal(rebuilds, 1, "a cooldown event must not rebuild an already-armed record")
equal(played, 1, "first trusted ready tick waits for confirmation")
assert(runtime:QueueGameCooldown(2825, {[2825] = "spell:2825"}, configs))
active = false -- the cooldown API can lag behind the cast-success event
runtime:EvaluateGameCooldowns(now + .2)
equal(played, 1, "new cast invalidates old ready evidence even before its cooldown is reported")
active = true
runtime:WipeCooldowns(false)
cfg.cdMode = "cooldown"
runtime:PrimeGameCooldowns(configs)
event("SPELL_UPDATE_COOLDOWN")
equal(played, 1, "priming does not replay an old cooldown-start edge")
assert(runtime:QueueGameCooldown(2825, {[2825] = "spell:2825"}, configs))
runtime:EvaluateGameCooldowns(now)
equal(played, 1, "cast queue waits for trusted state")
gcd = false
event("SPELL_UPDATE_COOLDOWN")
equal(played, 2, "real cooldown start announces once")
event("SPELL_UPDATE_COOLDOWN")
equal(played, 2)
runtime:WipeCooldowns(false)
local beforeReads = reads
event("SPELL_UPDATE_COOLDOWN")
equal(reads, beforeReads, "idle events must perform no spell reads")

print("PASS: event-only GCD reads, cached polling, cast-driven start, idle events and ignored payloads")
