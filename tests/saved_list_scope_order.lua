local root = (arg[1] or "."):gsub("\\", "/"):gsub("/*$", "/")
local config = root .. "QFXSkillAlerts_Config/"
local layouts, cdmEntries = {}, {}
QFXSkillAlertsNS = {
    API = {
        GetCurrentClassSpec = function() return 8, 62 end,
        GetCDMVoiceSavedEntries = function() return cdmEntries end,
    },
    AceOptions = {
        GetSavedListLayoutForScope = function(_, classID, specID)
            local result = {}
            for _, source in ipairs(layouts[classID .. ":" .. specID] or {}) do
                local row = {}
                for key, value in pairs(source) do row[key] = value end
                result[#result + 1] = row
            end
            return result
        end,
        GetBloodlustSavedEntry = function()
            return { key = "bloodlust", itemType = "entry", entryType = "bloodlust" }
        end,
    },
}
assert(loadfile(config .. "Core/SavedListOrder.lua"))()
assert(loadfile(config .. "UI/SavedListBuilder.lua"))()
local NS = QFXSkillAlertsNS

local function entry(index, classIDs, specIDs, loaded)
    return {
        key = "0:0:" .. index, itemType = "entry", classID = 0, specID = 0,
        alertClassIDs = classIDs, alertSpecIDs = specIDs, isLoaded = loaded ~= false,
    }
end

local function reset()
    QFXSkillAlertsDB = {
        specConfigs = { [0] = { [0] = {} } },
        collectionData = {
            [2] = { [0] = { groups = { paladin = { entries = { "0:0:99" } } } } },
            [1] = { [73] = { groups = { protection = { entries = { "0:0:98" } } } } },
        },
    }
    layouts = {
        ["0:0"] = {
            entry(1, { [8] = true }, { [62] = true }),
            entry(2, { [1] = true }, { [72] = true }),
            entry(3, { [0] = true }, { [0] = true }),
            entry(4, { [1] = true }, { [0] = true }),
            entry(5, { [1] = true }, { [71] = true }),
            entry(6, { [8] = true }, { [0] = true }),
            entry(7, { [8] = true }, { [62] = true }),
            entry(8, { [8] = true }, { [63] = true }, false),
            entry(9, { [1] = true }, { [0] = true }, false),
            entry(10, { [0] = true }, { [0] = true }, false),
        },
        ["2:0"] = {
            { key = "group:2:0:paladin", itemType = "group", classID = 2, specID = 0,
              depth = 0, count = 1, loadState = "yellow" },
            { key = "0:0:99", itemType = "entry", classID = 8, specID = 62,
              depth = 1, groupID = "paladin", isLoaded = false },
        },
        ["1:73"] = {
            { key = "group:1:73:protection", itemType = "group", classID = 1, specID = 73,
              depth = 0, count = 1, loadState = "red" },
            { key = "0:0:98", itemType = "entry", classID = 1, specID = 73,
              depth = 1, groupID = "protection", isLoaded = false },
        },
    }
    cdmEntries = {
        { key = "cdmpreset:mage", classID = 8, specID = 62, isLoaded = true },
        { key = "cdmpreset:warrior", classID = 1, specID = 71, isLoaded = false },
        { key = "cdmpreset:bridged", classID = 8, specID = 62, isCDAlert = true },
    }
end

local function keys(rows)
    local result = {}
    for _, row in ipairs(rows) do result[#result + 1] = row.key end
    return table.concat(result, ",")
end

local defaultLoaded = "0:0:3,bloodlust,0:0:4,0:0:5,0:0:2,group:2:0:paladin,0:0:99,0:0:6,0:0:1,0:0:7,cdmpreset:mage"
local defaultUnloaded = "0:0:10,0:0:9,cdmpreset:warrior,group:1:73:protection,0:0:98,0:0:8"
reset()
local loaded, unloaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded) == defaultLoaded, keys(loaded))
assert(keys(unloaded) == defaultUnloaded, keys(unloaded))
assert(loaded[7].displaySection == "loaded" and loaded[7].isLoaded == false)
for _ = 1, 3 do
    loaded, unloaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
    assert(keys(loaded) == defaultLoaded and keys(unloaded) == defaultUnloaded)
end
assert(not QFXSkillAlertsDB.savedListOrder.manual, "Automatic refresh must not mark the list as manually arranged")

-- Old snapshots used to contain automatic layouts. They must not block the
-- new default; their relative ordering within a single scope still survives.
QFXSkillAlertsDB.savedListOrder.loaded = { "0:0:7", "0:0:2", "0:0:1", "0:0:3", "stale", "0:0:7" }
loaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded) == defaultLoaded:gsub("0:0:1,0:0:7", "0:0:7,0:0:1"), keys(loaded))

-- A user move can cross class/spec boundaries and even precede globals.
assert(NS.SavedListOrder:RecordSavedListDisplayMove("0:0:1", "0:0:3:after", "loaded", false))
loaded, unloaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded):match("^0:0:1,0:0:3,"), keys(loaded))
assert(keys(unloaded) == defaultUnloaded, "Each section keeps its own ordering mode")
assert(NS.SavedListOrder:RecordSavedListDisplayMove("group:2:0:paladin", "0:0:1", "loaded", false))
loaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded):match("^group:2:0:paladin,0:0:99,0:0:1,"), keys(loaded))
local manualLoaded = keys(loaded)

-- Recreate the modules using only persisted DB state, as after /reload.
NS.UI.SavedListBuilder = nil
NS.Core.SavedListOrder = nil
assert(loadfile(config .. "Core/SavedListOrder.lua"))()
assert(loadfile(config .. "UI/SavedListBuilder.lua"))()
loaded, unloaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded) == manualLoaded and keys(unloaded) == defaultUnloaded)
assert(NS.SavedListOrder:RecordSavedListDisplayMove("0:0:8", "0:0:10", "unloaded", false))
loaded, unloaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(unloaded):match("^0:0:8,0:0:10,"), keys(unloaded))
assert(keys(loaded) == manualLoaded)

reset()
NS.UI.SavedListBuilder.BuildLayout({}, {})
layouts["0:0"][#layouts["0:0"] + 1] = entry(11, { [1] = true }, { [0] = true })
loaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded):match("0:0:4,0:0:11,0:0:5"), keys(loaded))

reset()
layouts["0:0"] = {
    entry(1, { [8] = true, [1] = true }, { [72] = true, [71] = true }),
    entry(2, { [8] = false, ["1"] = true }, { ["0"] = true }),
    entry(3, { [8] = true, [0] = true }, { [62] = true, [0] = true }),
}
cdmEntries = {}
loaded = NS.UI.SavedListBuilder.BuildLayout({}, {})
assert(keys(loaded):match("^0:0:3,bloodlust,0:0:2,0:0:1,"), keys(loaded))
assert(not NS.SavedListOrder:RecordSavedListDisplayMove("", "0:0:3", "loaded", false))
assert(not QFXSkillAlertsDB.savedListOrder.manual)
print("PASS: default class/spec order, global and all-spec priority, effective filters, stable categories, collection blocks, loaded/unloaded isolation, drag overrides, refresh/reload persistence, legacy snapshots and new entries")
