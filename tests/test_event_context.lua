local function Assert(value, message)
    if not value then error(message or "assertion failed", 2) end
end

local function Equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

QFXSkillAlertsNS = {
    Core = {},
    L = function(key) return key end,
}

local instanceName = "Open World"
local instanceType = "none"
local instanceID = 0
local delveActive = false
local activeChallengeMapID = 0
local dungeonBuilds = 0
local raidBuilds = 0
local combatLocked = false

function GetInstanceInfo()
    return instanceName, instanceType, 0, 0, 0, 0, false, instanceID
end

function InCombatLockdown()
    return combatLocked
end

C_DelvesUI = {
    HasActiveDelve = function() return delveActive end,
}

C_ChallengeMode = {
    GetMapTable = function()
        dungeonBuilds = dungeonBuilds + 1
        return { 101, 202 }
    end,
    GetMapUIInfo = function(mapID)
        return mapID == 101 and "Ruby Life Pools" or "The Stonevault"
    end,
    GetActiveChallengeMapID = function() return activeChallengeMapID end,
}

Enum = {
    LFGListFilter = { CurrentSeason = 2, PvE = 4 },
    LFGListCategory = { Raids = 3 },
}

bit = { bor = function(left, right) return left + right end }

C_LFGList = {
    GetAvailableActivityGroups = function(categoryID, filters)
        raidBuilds = raidBuilds + 1
        Assert(categoryID == 3 and filters == 6, "raid catalog should request the current-season PvE filter")
        return { 501 }
    end,
    GetActivityGroupInfo = function(groupID)
        return groupID == 501 and "Nerub-ar Palace" or ""
    end,
    GetAvailableActivities = function() return { 9001 } end,
    GetActivityInfoTable = function()
        return { fullName = "Nerub-ar Palace (Heroic)", shortName = "Nerub-ar Palace" }
    end,
}

dofile("QFXSkillAlerts/Core/EventContext.lua")
local Context = QFXSkillAlertsNS.Core.EventContext

local defaults = Context:NormalizeLoadContexts(nil)
Assert(defaults.world and defaults.delve and defaults.dungeon and defaults.raid,
    "legacy event entries should default to every load context")
Equal(Context:NormalizeInstanceMode("season"), "season", "season mode should survive normalization")
Equal(Context:NormalizeInstanceMode("specific"), "specific", "specific mode should survive normalization")
Equal(Context:NormalizeInstanceMode("bad"), "any", "unknown instance modes should fall back to any")
local worldCondition = { eventLoadContexts = { world = true } }
local delveCondition = { eventLoadContexts = { delve = true } }
local dungeon101 = {
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [101] = true },
}
local dungeon202 = {
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [202] = true },
}
Assert(not Context:LoadConditionsOverlap(worldCondition, delveCondition),
    "different event locations should not overlap")
Assert(not Context:LoadConditionsOverlap(dungeon101, dungeon202),
    "different specific dungeons should not overlap")
Assert(Context:LoadConditionsOverlap(dungeon101, {
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [101] = true, [202] = true },
}), "specific dungeon sets sharing an ID should overlap")
Assert(Context:LoadConditionsOverlap(dungeon101, {
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "season",
}), "all-current-season should overlap every current-season specific dungeon")
Assert(Context:LoadConditionsOverlap(worldCondition, {}),
    "legacy all-location entries should overlap a world entry")
Assert(Context:BuildLoadConditionSignature(dungeon101) ~= Context:BuildLoadConditionSignature(dungeon202),
    "different load conditions need distinct identity signatures")

Assert(Context:MatchesEntry({ eventLoadContexts = { world = true } }), "world-only entry should match outdoors")
Assert(not Context:MatchesEntry({ eventLoadContexts = { raid = true } }), "raid-only entry should not match outdoors")

delveActive = true
instanceName, instanceType, instanceID = "Fungal Folly", "scenario", 1001
Assert(Context:MatchesEntry({ eventLoadContexts = { delve = true } }), "active delve should use the delve context")
Assert(not Context:MatchesEntry({ eventLoadContexts = { world = true } }), "active delve should not be treated as world")

delveActive = false
instanceName, instanceType, instanceID = "Ruby Life Pools", "party", 2097
Assert(Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "season" }),
    "current-season dungeon should match the dynamic challenge catalog")
Equal(dungeonBuilds, 1, "dungeon catalog should be cached after its first build")
Assert(Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "season" }),
    "cached current-season dungeon should continue to match")
Equal(dungeonBuilds, 1, "cached dungeon catalog should not rebuild on each event")

instanceName = "Legacy Dungeon"
Assert(not Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "season" }),
    "non-season dungeon should be rejected")
Assert(Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "any" }),
    "any-dungeon mode should not consult the season catalog")

activeChallengeMapID = 202
Assert(Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "season" }),
    "active challenge map ID should match even when the instance display name differs")
activeChallengeMapID = 0

local dungeonOptions = Context:GetSeasonInstanceOptions("dungeon")
Equal(#dungeonOptions, 2, "specific dungeon options should contain only the current season catalog")
local filteredDungeons = Context:FilterCurrentSeasonSelections("dungeon", { [101] = true, [999] = true })
Assert(filteredDungeons["101"] and not filteredDungeons["999"],
    "old-season dungeon IDs should be removed from specific selections")
instanceName = "Ruby Life Pools"
Assert(Context:MatchesEntry({
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [101] = true, [202] = true },
}), "specific dungeon mode should match any selected current-season dungeon")
Assert(not Context:MatchesEntry({
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [202] = true },
}), "specific dungeon mode should reject an unselected current-season dungeon")
Assert(not Context:MatchesEntry({
    eventLoadContexts = { dungeon = true }, eventDungeonMode = "specific",
    eventDungeonSelectionIDs = { [999] = true }, eventDungeonSelectionNames = { [999] = "Ruby Life Pools" },
}), "old-season IDs must not match through a saved fallback name")

instanceName, instanceType, instanceID = "Nerub-ar Palace", "raid", 2769
Assert(Context:MatchesEntry({ eventLoadContexts = { raid = true }, eventRaidMode = "season" }),
    "current-season raid should match the filtered group-finder catalog")
Equal(raidBuilds, 1, "raid catalog should be cached after its first build")
instanceName = "Legacy Raid"
Assert(not Context:MatchesEntry({ eventLoadContexts = { raid = true }, eventRaidMode = "season" }),
    "non-season raid should be rejected")
Equal(raidBuilds, 1, "cached raid catalog should not rebuild on each event")
local raidOptions = Context:GetSeasonInstanceOptions("raid")
Equal(#raidOptions, 1, "specific raid options should contain only current-season groups")
instanceName = "Nerub-ar Palace"
Assert(Context:MatchesEntry({
    eventLoadContexts = { raid = true }, eventRaidMode = "specific",
    eventRaidSelectionIDs = { [501] = true },
}), "specific raid mode should match a selected current-season raid")
Assert(not Context:MatchesEntry({
    eventLoadContexts = { raid = true }, eventRaidMode = "specific",
    eventRaidSelectionIDs = { [999] = true }, eventRaidSelectionNames = { [999] = "Nerub-ar Palace" },
}), "old-season raid IDs must not match through a saved fallback name")

C_ChallengeMode = nil
combatLocked = true
instanceName, instanceType = "Unknown Dungeon", "party"
QFXSkillAlertsNS.Core.EventContext = nil
dofile("QFXSkillAlerts/Core/EventContext.lua")
Context = QFXSkillAlertsNS.Core.EventContext
Assert(Context:MatchesEntry({ eventLoadContexts = { dungeon = true }, eventDungeonMode = "season" }),
    "missing catalog data in combat should fail open instead of dropping an alert")

local source = assert(io.open("QFXSkillAlerts/Core/EventContext.lua", "rb")):read("*a")
Assert(not source:find("OnUpdate", 1, true), "event context matching must not install an OnUpdate loop")
Assert(not source:find("NewTicker", 1, true), "event context matching must not install a ticker")

print("event context/load-condition tests passed")
