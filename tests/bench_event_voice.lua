function wipe(values)
    for key in pairs(values or {}) do values[key] = nil end
end

function UnitRace() return "Human", "Human", 1 end

QFXSkillAlertsNS = {
    Core = {},
    Constants = {
        ALL_CLASSES_ID = 0, ALL_SPECS_ID = 0, ALL_RACES_ID = 0,
        ENTRY_MIN = 1, MODE_SOUND = "sound",
    },
    L = function(key) return key end,
}

local entryMap = {
    [1] = {
        entryType = "event", eventKey = "combat_start", eventThrottle = 0,
        voiceEnabled = true, notifyMode = "sound", soundPath = "test.ogg",
        alertClassIDs = { [0] = true }, alertSpecIDs = { [0] = true }, alertRaceIDs = { [0] = true },
    },
}

local frame = { registered = {} }
function frame:SetScript(name, callback) self[name] = callback end
function frame:RegisterEvent(event) self.registered[event] = true end
function frame:UnregisterAllEvents() wipe(self.registered) end

dofile("QFXSkillAlerts/Core/EntryMap.lua")
dofile("QFXSkillAlerts/Core/EventVoice.lua")
local EntryMap = QFXSkillAlertsNS.Core.EntryMap
local EventVoice = QFXSkillAlertsNS.Core.EventVoice
local now = 100
local played = 0
EventVoice:Configure({
    getCurrentClassSpec = function() return 1, 101 end,
    getStoredEntryMap = function(classID, specID)
        return classID == 0 and specID == 0 and entryMap or {}
    end,
    getOrderedEntryIndices = function(map) return EntryMap:GetOrderedEntryIndices(map) end,
    getEntry = function(map, index) return EntryMap:GetEntry(map, index) end,
    resolveEntrySoundPath = function(entry) return entry.soundPath end,
    playNotification = function() played = played + 1 return true end,
    getTime = function() now = now + 0.001 return now end,
    createFrame = function() return frame end,
})
EventVoice:Rebuild()

local iterations = 1000000
local started = os.clock()
for _ = 1, iterations do
    EventVoice:Dispatch("PLAYER_REGEN_DISABLED")
end
local elapsed = os.clock() - started
print(string.format("事件语音实际触发 x %d: %.3f s，单次 %.2f 微秒", iterations, elapsed, elapsed * 1000000 / iterations))
print(string.format("回调次数: %d；无 OnUpdate / C_Timer / ticker", played))
