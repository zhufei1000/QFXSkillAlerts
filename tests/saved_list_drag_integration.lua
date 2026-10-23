local root = assert(arg[1], "Pass the complete addon source parent") .. "/"
QFXSkillAlertsNS = {}
local NS = QFXSkillAlertsNS
local function load(relative) assert(loadfile(root .. relative))() end
load("QFXSkillAlerts/Core/CollectionStore.lua")
local Store = NS.CollectionStore
NS.API = {
    GetCurrentClassSpec = function() return 8, 62 end,
    GetStoredEntryMap = function(classID, specID)
        local classes = QFXSkillAlertsDB.specConfigs[classID]
        return classes and classes[specID] or {}
    end,
    GetEntry = function(map, index) return map[index] end,
    GetOrderedEntryIndices = function(map)
        local ids = {}
        for id in pairs(map) do if type(id) == "number" then ids[#ids + 1] = id end end
        table.sort(ids)
        return ids
    end,
}
load("QFXSkillAlerts_Config/Core/SavedListOrder.lua")
load("QFXSkillAlerts_Config/Core/SavedListDropKey.lua")
load("QFXSkillAlerts_Config/Core/SavedListMoveContext.lua")
load("QFXSkillAlerts_Config/Core/SavedListMoveController.lua")
local state = {}
local owner = { GetState = function() return state end }
local function reset()
    QFXSkillAlertsDB = {
        specConfigs = { [0] = { [0] = { [1] = {}, [2] = {}, [3] = {} } } },
        collectionData = { [0] = { [0] = {
            root = { { type = "group", id = "a" }, { type = "entry", index = 3 } },
            groups = { a = { entries = { "0:0:1", "0:0:2" } } },
        } } },
        savedListOrder = { loaded = { "group:0:0:a", "0:0:3" }, unloaded = {} },
    }
    state = {}
end
local function move(source, target)
    return NS.SavedListMoveController:MoveSavedListItem(owner, source, target, "loaded", true)
end
reset()
assert(move("0:0:1", "root:0:0:after"))
assert(QFXSkillAlertsDB.savedListOrder.manual and QFXSkillAlertsDB.savedListOrder.manual.loaded,
    "Moving a child to its own storage root must persist a manual root placement")
local saved = QFXSkillAlertsDB.savedListOrder.loaded
assert(saved[#saved] == "0:0:1", "Outdented child must stay at the end")

reset()
assert(move("group:0:0:a", "root:0:0:after"))
assert(QFXSkillAlertsDB.savedListOrder.manual.loaded)
assert(table.concat(QFXSkillAlertsDB.savedListOrder.loaded, ",") == "0:0:3,group:0:0:a")

reset()
assert(move("0:0:1", "0:0:2:after"))
assert(table.concat(QFXSkillAlertsDB.collectionData[0][0].groups.a.entries, ",") == "0:0:2,0:0:1")
assert(not (QFXSkillAlertsDB.savedListOrder.manual and QFXSkillAlertsDB.savedListOrder.manual.loaded),
    "Reordering children inside a collection must not disable default sorting for unrelated roots")
assert(table.concat(QFXSkillAlertsDB.savedListOrder.loaded, ",") == "group:0:0:a,0:0:3")

reset()
assert(move("0:0:3", "group:0:0:a:inside"))
assert(not QFXSkillAlertsDB.savedListOrder.manual)
assert(table.concat(QFXSkillAlertsDB.collectionData[0][0].groups.a.entries, ",") == "0:0:1,0:0:2,0:0:3")

reset()
local calls = 0
local original = NS.SavedListOrder.RecordSavedListDisplayMove
NS.SavedListOrder.RecordSavedListDisplayMove = function(self, ...)
    calls = calls + 1
    return original(self, ...)
end
QFXSkillAlertsDB.collectionData[8] = { [62] = {
    root = { { type = "group", id = "b" } }, groups = { b = { entries = {} } },
} }
QFXSkillAlertsDB.savedListOrder.loaded[#QFXSkillAlertsDB.savedListOrder.loaded + 1] = "group:8:62:b"
assert(move("0:0:3", "group:8:62:b"))
assert(calls == 1, "A successful drag must record its display position once")
assert(QFXSkillAlertsDB.savedListOrder.manual.loaded)
assert(table.concat(QFXSkillAlertsDB.savedListOrder.loaded, ",") == "group:0:0:a,0:0:3,group:8:62:b")

reset()
calls = 0
local cdmKey = "cdmpreset:8:62:essential:11:start"
NS.API.ParseCDMVoiceSavedKey = function(key)
    assert(key == cdmKey)
    return { keyType = "preset", classID = 8, specID = 62, recordKey = "essential:11:start" }
end
NS.API.GetCDMVoicePresetRecord = function() return {} end
assert(move(cdmKey, "root:8:62:after"))
assert(calls == 1 and QFXSkillAlertsDB.savedListOrder.manual.loaded)
assert(QFXSkillAlertsDB.savedListOrder.loaded[3] == cdmKey)
NS.SavedListOrder.RecordSavedListDisplayMove = original
reset()
assert(not move("0:0:1", "0:0:1"))
assert(not QFXSkillAlertsDB.savedListOrder.manual)
print("PASS: real move controller, same-scope outdent persistence, nested drag isolation, single display-order write and rejected self-drop")
